# Environment Clean-Up

rm(list = ls())        # Remove all objects from environment
graphics.off()         # Close all open graphics windows
cat("\014")            # Clear the console (works in RStudio)

# Load required libraries
library(tidyverse)
library(stringi)

# Function to detect encoding and load TSV file
load_tsv_with_detected_encoding <- function(file_path) {
  # Read raw bytes to detect encoding
  raw_bytes <- readBin(file_path, what = "raw", n = 10000)
  encoding <- tryCatch({
    stri_enc_detect(raw_bytes)[[1]]$Encoding[1]
  }, error = function(e) {
    "UTF-8"  # fallback if detection fails
  })
  cat("🔍 Detected encoding:", encoding, "\n")
  
  # Load TSV using detected encoding
  read_tsv(file_path, locale = locale(encoding = encoding))
}

# Load the comments dataset
df <- load_tsv_with_detected_encoding("data/comments.tsv")

# Check for missing responses
missing <- df %>% filter(is.na(comment) | comment == "")

# Check for suspiciously short responses
short <- df %>% filter(str_length(comment) < 20)

# Check for encoding issues (look for �)
encoding_issues <- df %>% filter(str_detect(comment, "�"))

# Combine flagged rows
flagged <- bind_rows(missing, short, encoding_issues) %>% distinct()

# Save flagged rows
write_csv(flagged, "output/flagged_responses.csv")

# Exclude flagged rows from main dataset
df_clean <- anti_join(df, flagged, by = "id")  # assumes 'id' column exists

# Save cleaned dataset for translation
write_csv(df_clean, "output/clean_comments.csv")

cat("✅ Validation complete. Cleaned data saved to output/clean_comments.csv\n")