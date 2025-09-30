# ==============================
# 00_validate_responses.R
# ==============================

# Init
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c("tidyverse", "stringi", "yaml", "readr"))

# Config
config <- yaml::read_yaml("config/config.yml")

# Ensure output dirs
ensure_dir(config$paths$output_csv)

# ------------------------------
# Helpers
# ------------------------------
load_tsv_detect_encoding <- function(path) {
  raw_bytes <- readBin(path, what = "raw", n = 10000)
  enc_info  <- stringi::stri_enc_detect(raw_bytes)[[1]]
  enc       <- enc_info$Encoding[which.max(enc_info$Confidence)]
  readr::read_tsv(path, locale = readr::locale(encoding = enc), show_col_types = FALSE)
}

flag_issues <- function(df, columns, min_length) {
  df %>%
    mutate(across(all_of(columns), list(
      is_missing = ~ is.na(.) | stringr::str_trim(.) == "",
      is_short   = ~ !is.na(.) & stringr::str_length(.) < min_length
    ))) %>%
    mutate(total_issues = rowSums(dplyr::select(., tidyselect::matches("_is_")), na.rm = TRUE))
}

# ------------------------------
# Workflow
# ------------------------------
log_info("Loading input: {config$paths$raw_data}")
df <- load_tsv_detect_encoding(config$paths$raw_data)

# Allow column override via config, else default Q4.2–Q4.10
comment_cols <- if (!is.null(config$input$comment_cols)) {
  config$input$comment_cols
} else {
  paste0("Q4.", 2:10)
}

df <- df %>% dplyr::select(ResponseId, UserLanguage, dplyr::all_of(comment_cols))

# Optionally remove label rows (first two rows)
if (isTRUE(config$translation$drop_label_rows) && nrow(df) >= 2) {
  df <- df[-c(1, 2), ]
  log_info("Dropped the first two label rows.")
}

log_info("Flagging issues with min length = {config$translation$min_comment_length}")
df_flagged <- flag_issues(df, comment_cols, config$translation$min_comment_length)

# Save outputs
flagged_file <- file.path(config$paths$output_csv, "00_flagged_responses.csv")
clean_file   <- file.path(config$paths$output_csv, "00_clean_comments.csv")

safe_write_csv(
  df_flagged %>% dplyr::filter(total_issues > 0),
  flagged_file
)
safe_write_csv(
  df_flagged %>% dplyr::filter(total_issues <= config$translation$max_allowed_issues),
  clean_file
)

log_info("Saved flagged: {flagged_file}")
log_info("Saved cleaned: {clean_file}")

log_info("Issue distribution table:")
print(table(df_flagged$total_issues))
