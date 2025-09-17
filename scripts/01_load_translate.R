library(tidyverse)
library(polyglotr)

# Load cleaned comments
df <- read_csv("output/clean_comments.csv")

# Translate using MyMemory via polyglotr
df$translated <- map_chr(df$comment, ~ mymemory_translate(.x, target_language = "en"))

# Save translated dataset
write_csv(df, "output/translated_comments.csv")