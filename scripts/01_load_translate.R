# ==============================
# 01_load_translate.R
# ==============================

# Load utilities and configuration
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c(
  "tidyverse", "stringr", "progressr",
  "googleLanguageR", "polyglotr", "yaml"
))

# Load configuration
config <- yaml::read_yaml("config/config.yml")

options(progressr.delay_stdout = FALSE)
handlers("cli")

# ==============================
# Authentication
# ==============================
key_path <- Sys.getenv(config$translation$google_key_env)
if (key_path == "") {
  stop("Environment variable '", config$translation$google_key_env, "' not set. 
       Please set it to the path of your Google Cloud JSON key.")
}
gl_auth(key_path)

# ==============================
# Helper Functions
# ==============================
should_translate <- function(txt) {
  !is.na(txt) && str_length(str_trim(txt)) >= config$translation$min_comment_length
}

safe_translate_batch <- function(texts, src, batch_size = 100) {
  if (length(texts) == 0) return(character(0))
  out <- vector("character", length(texts))
  for (i in seq(1, length(texts), by = batch_size)) {
    idx <- i:min(i + batch_size - 1, length(texts))
    out[idx] <- tryCatch(
      gl_translate(texts[idx], target = "en", source = src)$translatedText,
      error = function(e) rep(NA_character_, length(idx))
    )
  }
  out
}

load_comments <- function(path, cols) {
  read_csv(path, show_col_types = FALSE) %>%
    select(ResponseId, UserLanguage, all_of(cols)) %>%
    pivot_longer(cols = all_of(cols), names_to = "question", values_to = "text") %>%
    mutate(clean_text = str_replace_all(text, "[\r\n]", " ") %>% str_trim()) %>%
    filter(map_lgl(clean_text, should_translate))
}

update_cache <- function(new_data, cache, path) {
  updated <- bind_rows(cache, new_data) %>%
    mutate(across(where(is.character), ~ replace_na(.x, "")))
  saveRDS(updated, path)
  updated
}

detect_languages <- function(data, cache_path) {
  cache <- if (file.exists(cache_path)) readRDS(cache_path) else 
    tibble(clean_text = character(), detected_lang = character())
  
  to_detect <- anti_join(distinct(data, clean_text), cache, by = "clean_text")
  if (nrow(to_detect) == 0) return(cache)
  
  detected <- tibble(
    clean_text = to_detect$clean_text,
    detected_lang = map_chr(to_detect$clean_text, function(txt) {
      if (is.na(txt) || txt == "") return(NA_character_)
      res <- tryCatch(language_detect(txt), error = function(e) character(0))
      if (length(res) == 0) NA_character_ else as.character(res[1])
    })
  )
  
  update_cache(detected, cache, cache_path)
}

translate_texts <- function(data, cache_path) {
  cache <- if (file.exists(cache_path)) readRDS(cache_path) else 
    tibble(clean_text = character(), source_lang = character(), translated = character())
  
  requests <- distinct(data, clean_text, source_lang) %>%
    filter(!is.na(clean_text), !is.na(source_lang)) %>%
    anti_join(cache, by = c("clean_text", "source_lang"))
  
  if (nrow(requests) == 0) return(cache)
  
  with_progress({
    p <- progressor(steps = nrow(requests))
    new_translations <- requests %>%
      group_by(source_lang) %>%
      group_modify(~ {
        out <- safe_translate_batch(.x$clean_text, .y$source_lang)
        p(nrow(.x)) # increment per batch
        tibble(clean_text = .x$clean_text, translated = out)
      }) %>%
      ungroup()
    update_cache(new_translations, cache, cache_path)
  })
}

# ==============================
# Translation Workflow
# ==============================
comment_cols <- paste0("Q4.", 2:10)
input_file   <- file.path(config$paths$output_csv, "00_clean_comments.csv")
detect_cache_file <- file.path(config$paths$cache, "detect_cache.rds")
translate_cache_file <- file.path(config$paths$cache, "translation_cache.rds")
final_output_file <- file.path(config$paths$output_csv, "01_translated_comments.csv")

log_info("Loading comments...")
comment_data <- load_comments(input_file, comment_cols)
log_info("Filtered rows:", nrow(comment_data))

log_info("Detecting languages...")
detect_cache <- detect_languages(comment_data, detect_cache_file)

comment_data <- comment_data %>%
  left_join(detect_cache, by = "clean_text") %>%
  mutate(source_lang = if_else(
    is.na(clean_text) | clean_text == "", NA_character_,
    if_else(detected_lang == UserLanguage, UserLanguage, detected_lang)
  ))

log_info("Detected languages:", sum(!is.na(comment_data$source_lang)))

log_info("Translating texts...")
translation_cache <- translate_texts(comment_data, translate_cache_file)

translated_df <- comment_data %>%
  left_join(translation_cache, by = c("clean_text", "source_lang")) %>%
  select(ResponseId, UserLanguage, question, translated) %>%
  pivot_wider(names_from = question, values_from = translated, 
              names_glue = "{.name}_translated") %>%
  filter(!if_all(ends_with("_translated"), is.na)) %>%
  mutate(
    untranslated_flag = if_any(ends_with("_translated"), ~ .x %in% c("", NA)),
    low_quality_flag  = if_any(ends_with("_translated"), ~ str_length(.x) < 20 | !str_detect(.x, " "))
  ) %>%
  mutate(across(where(is.character), ~ replace_na(.x, "")))

log_info("Final rows:", nrow(translated_df))
write_csv(translated_df, final_output_file)
log_info("Translation complete. Saved to:", final_output_file)
