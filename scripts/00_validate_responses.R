# ==============================
# 00_validate_responses.R
# ==============================

# Load utilities and configuration
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c("tidyverse", "stringi", "yaml"))

# Load configuration
config <- yaml::read_yaml("config/config.yml")

# ==============================
# Functions
# ==============================

# Load TSV with encoding detection
load_tsv <- function(path) {
  raw_bytes <- readBin(path, what = "raw", n = 10000)
  enc_info  <- stri_enc_detect(raw_bytes)[[1]]
  enc       <- enc_info$Encoding[which.max(enc_info$Confidence)]
  read_tsv(path, locale = locale(encoding = enc))
}

# Flag issues in comments
flag_issues <- function(df, columns, min_length) {
  df %>%
    mutate(across(all_of(columns), list(
      is_missing = ~ is.na(.) | str_trim(.) == "",
      is_short   = ~ !is.na(.) & str_length(.) < min_length
    ))) %>%
    mutate(total_issues = rowSums(select(., matches("_is_")), na.rm = TRUE))
}

# ==============================
# Workflow
# ==============================

log_info("Loading input file...")
df <- load_tsv(config$paths$raw_data)

# Select relevant columns
comment_cols <- paste0("Q4.", 2:10)
df <- df %>%
  select(ResponseId, UserLanguage, all_of(comment_cols))

# Optionally remove label rows (first two rows)
if (config$translation$max_allowed_issues > 0 && nrow(df) >= 2) {
  df <- df[-c(1, 2), ]
}

# Flag issues
log_info("Flagging issues in comments...")
df_flagged <- flag_issues(df, comment_cols, config$translation$min_comment_length)

# Ensure output directory exists
dir.create(config$paths$output_csv, showWarnings = FALSE, recursive = TRUE)

# Save flagged responses
flagged_file <- file.path(config$paths$output_csv, "00_flagged_responses.csv")
df_flagged %>%
  filter(total_issues > 0) %>%
  write_csv(flagged_file)
log_info("Saved flagged responses to:", flagged_file)

# Save cleaned responses
clean_file <- file.path(config$paths$output_csv, "00_clean_comments.csv")
df_flagged %>%
  filter(total_issues <= config$translation$max_allowed_issues) %>%
  write_csv(clean_file)
log_info("Saved cleaned responses to:", clean_file)

# Print summary
log_info("Issue distribution:")
print(table(df_flagged$total_issues))
