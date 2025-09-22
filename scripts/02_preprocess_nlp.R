# Environment Clean-Up
rm(list = ls())        # Remove all objects from environment
graphics.off()         # Close all open graphics windows
cat("\014")            # Clear the console (works in RStudio)

# Load required libraries
library(tm)
library(text2vec)

df <- read_csv("output/translated_comments.csv")

# Preprocessing function
prep_fun <- function(text) {
  text %>%
    tolower() %>%
    removePunctuation() %>%
    removeNumbers() %>%
    stripWhitespace()
}

df$clean <- prep_fun(df$translated)

# Tokenization
tokens <- word_tokenizer(df$clean)

# Create DTM
it <- itoken(tokens, progressbar = FALSE)
vocab <- create_vocabulary(it)
vectorizer <- vocab_vectorizer(vocab)
dtm <- create_dtm(it, vectorizer)

saveRDS(dtm, "output/dtm.rds")