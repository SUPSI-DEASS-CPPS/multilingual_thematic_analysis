library(tidyverse)

# Load TSV with UTF-8 encoding
df <- read_tsv("data/comments.tsv", locale = locale(encoding = "UTF-8"))

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