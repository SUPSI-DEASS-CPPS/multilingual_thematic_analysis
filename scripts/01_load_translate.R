# Environment Clean-Up
rm(list = ls())
graphics.off()
cat("\014")

# Load Required Libraries
library(tidyverse)
library(stringr)
library(progressr)
library(googleLanguageR)
library(polyglotr)

# Progress Bar Configuration
options(progressr.delay_stdout = FALSE)
handlers("cli")  # Shows ETA and progress

# Authenticate Google Cloud using environment variable
key_path <- Sys.getenv("GOOGLE_TRANSLATE_KEY")
if (key_path == "") stop("Environment variable 'GOOGLE_TRANSLATE_KEY' not set.")
gl_auth(key_path)

# Load Dataset with One Column: comment
df <- read_csv("output/clean_comments.csv", show_col_types = FALSE)

# Translation Cache
translation_cache <- new.env()

# Heuristic: Skip texts that are too short or non-linguistic
should_translate <- function(txt) {
  if (is.na(txt) || str_trim(txt) == "") return(FALSE)
  txt <- str_trim(txt)
  if (str_length(txt) < 5) return(FALSE)
  if (!str_detect(txt, "[a-zA-Z]")) return(FALSE)
  return(TRUE)
}

# Prepare Texts for Detection and Translation
comment_data <- df %>%
  mutate(
    clean_text = str_replace_all(comment, "[\r\n]", " ") %>% str_trim(),
    detected_lang = map_chr(clean_text, ~ {
      detected <- language_detect(.x)
      if (length(detected) == 0) NA_character_ else detected[1]
    }),
    source_lang = detected_lang
  ) %>%
  filter(map_lgl(clean_text, should_translate))

# Create Unique Translation Requests
translation_requests <- comment_data %>%
  distinct(clean_text, source_lang)

# Retry Logic for Translation
safe_translate <- function(txt, src, max_attempts = 3) {
  attempt <- 1
  result <- NA_character_
  
  while (attempt <= max_attempts) {
    result <- tryCatch({
      suppressMessages(suppressWarnings(
        gl_translate(txt, target = "en", source = src)$translatedText
      ))
    }, error = function(e) NA_character_)
    
    if (!is.na(result) && length(result) >= 1 && is.character(result)) {
      return(as.character(result[1]))
    }
    
    attempt <- attempt + 1
    Sys.sleep(1)
  }
  
  return(NA_character_)
}

# Batch Translate with Progress Bar + Retry
translated_lookup <- list()

with_progress({
  p <- progressor(steps = nrow(translation_requests))
  
  for (i in seq_len(nrow(translation_requests))) {
    txt <- translation_requests$clean_text[i]
    src <- translation_requests$source_lang[i]
    
    result <- safe_translate(txt, src)
    translation_cache[[txt]] <- result
    translated_lookup[[txt]] <- result
    p()
  }
})

# Apply Translations Back to Data Frame
translated_df <- df %>%
  mutate(
    comment_clean = str_replace_all(comment, "[\r\n]", " ") %>% str_trim(),
    comment_translated = sapply(comment_clean, function(txt) {
      if (!should_translate(txt)) return(NA_character_)
      if (exists(txt, envir = translation_cache)) {
        return(translation_cache[[txt]])
      } else {
        return(NA_character_)
      }
    }),
    untranslated_flag = is.na(comment_translated),
    low_quality_flag = comment == comment_translated |
                       str_length(comment_translated) < 20 |
                       !str_detect(comment_translated, " ")
  ) %>%
  select(comment, comment_translated, untranslated_flag, low_quality_flag)

# Save Translated Dataset
write_csv(translated_df, "output/translated_comments.csv")