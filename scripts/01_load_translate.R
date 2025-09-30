# ==============================
# 01_load_translate.R
# ==============================

# Init
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c(
  "tidyverse", "stringr", "progressr",
  "googleLanguageR", "polyglotr", "yaml", "readr"
))

# Config
config <- yaml::read_yaml("config/config.yml")
options(progressr.delay_stdout = FALSE)
handlers("cli")

# Auth
key_path <- Sys.getenv(config$translation$google_key_env)
if (!nzchar(key_path)) {
  log_error("Environment variable '{config$translation$google_key_env}' not set.")
  stop("Missing Google Cloud credentials.")
}
gl_auth(key_path)
log_info("Authenticated with Google Cloud using key: {config$translation$google_key_env}")

# Ensure dirs
ensure_dir(config$paths$output_csv)
ensure_dir(config$paths$cache)

# ------------------------------
# Helpers
# ------------------------------
should_translate <- function(txt) {
  !is.na(txt) && stringr::str_length(stringr::str_trim(txt)) >= config$translation$min_comment_length
}

safe_translate_batch <- function(texts, src, batch_size = 100) {
  if (!length(texts)) return(character(0))
  out <- vector("character", length(texts))
  for (i in seq(1, length(texts), by = batch_size)) {
    idx <- i:min(i + batch_size - 1, length(texts))
    result <- tryCatch(
      with_retries(quote(googleLanguageR::gl_translate(texts[idx], target = "en", source = src))),
      error = function(e) e
    )
    if (inherits(result, "error")) {
      log_warn("Batch translation failed: {conditionMessage(result)}")
      out[idx] <- NA_character_
    } else {
      out[idx] <- result$translatedText
    }
  }
  out
}

# Cache paths
detect_cache_file     <- file.path(config$paths$cache, "detect_cache.rds")
translation_cache_file <- file.path(config$paths$cache, "translation_cache.rds")

detect_languages <- function(data) {
  cache <- if (file.exists(detect_cache_file)) readRDS(detect_cache_file) else 
    tibble::tibble(clean_text = character(), detected_lang = character())
  
  to_detect <- dplyr::anti_join(dplyr::distinct(data, clean_text), cache, by = "clean_text")
  if (nrow(to_detect) == 0) return(cache)
  
  detected <- tibble::tibble(
    clean_text = to_detect$clean_text,
    detected_lang = purrr::map_chr(to_detect$clean_text, function(txt) {
      if (is.na(txt) || txt == "") return(NA_character_)
      res <- tryCatch(polyglotr::language_detect(txt), error = function(e) character(0))
      if (length(res) == 0) NA_character_ else as.character(res[1])
    })
  )
  
  updated <- dplyr::bind_rows(cache, detected) %>%
    dplyr::mutate(across(where(is.character), ~ tidyr::replace_na(.x, "")))
  saveRDS(updated, detect_cache_file)
  updated
}

translate_texts <- function(data) {
  cache <- if (file.exists(translation_cache_file)) readRDS(translation_cache_file) else 
    tibble::tibble(clean_text = character(), source_lang = character(), translated = character())
  
  requests <- dplyr::distinct(data, clean_text, source_lang) %>%
    dplyr::filter(!is.na(clean_text), !is.na(source_lang)) %>%
    dplyr::anti_join(cache, by = c("clean_text", "source_lang"))
  
  if (nrow(requests) == 0) return(cache)
  
  with_progress({
    p <- progressor(steps = nrow(requests))
    new_translations <- requests %>%
      dplyr::group_by(source_lang) %>%
      dplyr::group_modify(~ {
        out <- safe_translate_batch(.x$clean_text, .y$source_lang)
        p(nrow(.x))
        tibble::tibble(clean_text = .x$clean_text, source_lang = .y$source_lang, translated = out)
      }) %>%
      dplyr::ungroup()
    
    updated <- dplyr::bind_rows(cache, new_translations) %>%
      dplyr::mutate(across(where(is.character), ~ tidyr::replace_na(.x, "")))
    saveRDS(updated, translation_cache_file)
    updated
  })
}

# ------------------------------
# Workflow
# ------------------------------
comment_cols <- if (!is.null(config$input$comment_cols)) config$input$comment_cols else paste0("Q4.", 2:10)
input_file   <- file.path(config$paths$output_csv, "00_clean_comments.csv")
final_output_file <- file.path(config$paths$output_csv, "01_translated_comments.csv")

log_info("Loading cleaned comments...")
comment_data <- safe_read_csv(input_file) %>%
  dplyr::select(ResponseId, UserLanguage, dplyr::all_of(comment_cols)) %>%
  tidyr::pivot_longer(cols = dplyr::all_of(comment_cols), names_to = "question", values_to = "text") %>%
  dplyr::mutate(clean_text = stringr::str_replace_all(text, "[\r\n]", " ") %>% stringr::str_trim()) %>%
  dplyr::filter(purrr::map_lgl(clean_text, should_translate))

log_info("Rows to process: {nrow(comment_data)}")

log_info("Detecting languages (with cache)...")
detect_cache <- detect_languages(comment_data)

comment_data <- comment_data %>%
  dplyr::left_join(detect_cache, by = "clean_text") %>%
  dplyr::mutate(source_lang = dplyr::if_else(
    is.na(clean_text) | clean_text == "", NA_character_,
    dplyr::if_else(detected_lang %in% c("", NA), UserLanguage,
                   dplyr::if_else(detected_lang == UserLanguage, UserLanguage, detected_lang))
  ))

log_info("Translating texts (with cache)...")
translation_cache <- translate_texts(comment_data)

translated_df <- comment_data %>%
  dplyr::left_join(translation_cache, by = c("clean_text", "source_lang")) %>%
  dplyr::select(ResponseId, UserLanguage, question, translated) %>%
  tidyr::pivot_wider(
    names_from = question, values_from = translated,
    names_glue = "{.name}_translated"
  ) %>%
  dplyr::filter(!dplyr::if_all(tidyselect::ends_with("_translated"), is.na)) %>%
  dplyr::mutate(across(where(is.character), ~ tidyr::replace_na(.x, "")))

log_info("Final translated rows: {nrow(translated_df)}")
safe_write_csv(translated_df, final_output_file)
log_info("Translation complete → {final_output_file}")
