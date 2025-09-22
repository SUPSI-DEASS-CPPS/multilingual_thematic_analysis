# Environment Clean-Up
rm(list = ls())        # Remove all objects from environment
graphics.off()         # Close all open graphics windows
cat("\014")            # Clear the console (works in RStudio)

# Load required libraries
library(cluster)
library(factoextra)

dtm <- readRDS("output/dtm.rds")

# PCA for dimensionality reduction
dtm_pca <- prcomp(dtm, scale. = TRUE)
dtm_reduced <- dtm_pca$x[, 1:10]

# K-means clustering
set.seed(123)
km <- kmeans(dtm_reduced, centers = 5)

df <- read_csv("output/translated_comments.csv")
df$cluster <- km$cluster

write_csv(df, "output/clusters.csv")