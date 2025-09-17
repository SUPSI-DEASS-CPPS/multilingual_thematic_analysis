library(ggplot2)
library(factoextra)

dtm <- readRDS("output/dtm.rds")
dtm_pca <- prcomp(dtm, scale. = TRUE)
df <- read_csv("output/clusters.csv")

fviz_cluster(list(data = dtm_pca$x[, 1:2], cluster = df$cluster),
             geom = "point", ellipse.type = "convex", palette = "jco")