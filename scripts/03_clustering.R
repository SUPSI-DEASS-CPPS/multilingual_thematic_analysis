# ==============================
# 03_clustering.R
# ==============================

# Load utilities and configuration
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c(
  "readr", "dplyr", "dbscan", "umap", "ggplot2",
  "tidytext", "tm", "stringr", "tibble", "cluster", "yaml"
))

# Load configuration
config <- yaml::read_yaml("config/config.yml")

# ==============================
# Load Data
# ==============================
input_file <- file.path(config$paths$output_csv, "01_translated_comments.csv")
embedding_rds <- file.path(config$paths$output_rds, "embeddings", "all_embeddings.rds")

df <- read_csv(input_file, show_col_types = FALSE)
emb_list <- readRDS(embedding_rds)

translated_cols <- if (!is.null(config$clustering$embedding_columns)) {
  config$clustering$embedding_columns
} else {
  grep("_translated$", names(df), value = TRUE)
}

log_info("Columns to cluster:", paste(translated_cols, collapse = ", "))

# ==============================
# Helper Functions
# ==============================
reduce_dimensions <- function(emb_matrix, n_dims = 50) {
  max_dims <- min(n_dims, ncol(emb_matrix), nrow(emb_matrix))
  if (max_dims < n_dims) {
    log_info("Requested", n_dims, "dimensions, but only", max_dims, "available. Adjusting.")
  }
  prcomp(emb_matrix, center = TRUE, scale. = TRUE)$x[, 1:max_dims, drop = FALSE]
}

extract_labels <- function(texts, clusters) {
  dfw <- tibble(text = texts, cluster = clusters) %>%
    filter(!is.na(cluster))

  labels <- list(`0` = "Noise")

  dfw_non_noise <- dfw %>% filter(cluster != 0)
  if (nrow(dfw_non_noise) == 0) return(unlist(labels))

  tokens <- dfw_non_noise %>%
    unnest_tokens(word, text) %>%
    filter(!word %in% stopwords("en"),
           str_detect(word, "[a-z]"),
           !str_detect(word, "^[0-9]+$"))

  tfidf <- tokens %>%
    count(cluster, word, sort = TRUE) %>%
    bind_tf_idf(word, cluster, n)

  top_keywords <- tfidf %>%
    group_by(cluster) %>%
    slice_max(tf_idf, n = 3, with_ties = FALSE) %>%
    summarise(label = paste(word, collapse = ", "), .groups = "drop")

  lbl <- setNames(top_keywords$label, top_keywords$cluster)
  c(labels, as.list(lbl))
}

plot_umap <- function(layout, clusters, labels, col_name, method, output_dir) {
  plot_df <- data.frame(
    x = layout[, 1],
    y = layout[, 2],
    cluster = factor(clusters),
    label = labels[as.character(clusters)]
  )

  p <- ggplot(plot_df, aes(x, y, color = cluster)) +
    geom_point(size = 2, alpha = 0.7) +
    theme_minimal() +
    labs(title = paste(method, "Clusters for", col_name),
         x = "UMAP-1", y = "UMAP-2")

  ggsave(
    file.path(output_dir, paste0("clusters_", col_name, "_", tolower(method), "_umap.png")),
    p, width = 7, height = 5
  )
}

compute_silhouette <- function(data, clusters) {
  if (length(unique(clusters)) < 2) return(NA_real_)
  dist_matrix <- dist(data)
  sil <- silhouette(clusters, dist_matrix)
  mean(sil[, 3])
}

# ==============================
# Main Loop
# ==============================
summary_list <- list()

for (col_name in translated_cols) {
  log_info("Processing column:", col_name)

  emb_matrix <- emb_list[[col_name]]
  if (is.null(emb_matrix)) {
    log_info("Skipping", col_name, "- no embeddings.")
    next
  }

  texts <- df[[col_name]] %>% replace_na("")
  emb_matrix <- as.matrix(emb_matrix)

  valid_idx <- which(rowSums(!is.na(emb_matrix)) > 0)
  emb_matrix <- emb_matrix[valid_idx, , drop = FALSE]
  texts <- texts[valid_idx]

  if (nrow(emb_matrix) < config$clustering$min_docs) {
    log_info("Skipping", col_name, "- not enough valid responses.")
    next
  }

  reduced <- reduce_dimensions(emb_matrix, config$clustering$umap_dims)

  umap_cfg <- umap::umap.defaults
  umap_cfg$random_state <- 42
  umap_layout <- umap(reduced, config = umap_cfg)$layout

  # Try HDBSCAN
  hdb <- hdbscan(reduced, minPts = config$clustering$min_pts)
  clusters <- hdb$cluster

  if (all(clusters == 0)) {
    log_info("HDBSCAN failed - falling back to KMeans")

    best_k <- 2
    best_score <- -Inf
    upper_k <- min(config$clustering$max_kmeans_k, nrow(reduced) - 1)
    for (k in 2:upper_k) {
      km <- kmeans(reduced, centers = k, nstart = 10)
      score <- compute_silhouette(reduced, km$cluster)
      if (!is.na(score) && score > best_score) {
        best_score <- score
        best_k <- k
      }
    }

    km <- kmeans(reduced, centers = best_k, nstart = 10)
    clusters <- km$cluster
    method <- "KMeans"
    silhouette_score <- round(best_score, 3)
  } else {
    method <- "HDBSCAN"
    silhouette_score <- round(compute_silhouette(reduced, clusters), 3)
  }

  labels <- extract_labels(texts, clusters)

  clustered_df <- tibble(
    text = texts,
    cluster = clusters,
    cluster_label = labels[as.character(clusters)]
  )

  output_csv <- file.path(config$paths$output_csv, "cluster", paste0("clusters_", col_name, ".csv"))
  write_csv(clustered_df, output_csv)
  log_info("Saved to:", output_csv)

  if (config$clustering$make_plots) {
    plot_umap(umap_layout, clusters, labels, col_name, method,
              file.path(config$paths$output_png, "cluster"))
  }

  summary_list[[col_name]] <- tibble(
    question = col_name,
    cluster = names(labels),
    suggested_label = unname(labels),
    method = method,
    silhouette = silhouette_score
  )
}

# ==============================
# Save Summary
# ==============================
if (length(summary_list) > 0) {
  summary_df <- bind_rows(summary_list)
  summary_csv <- file.path(config$paths$output_csv, "cluster", "03_clusters_summary.csv")
  write_csv(summary_df, summary_csv)
  log_info("Cluster summary saved to:", summary_csv)
} else {
  log_info("No clusters generated.")
}
