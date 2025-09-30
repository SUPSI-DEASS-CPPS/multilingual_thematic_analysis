# ==============================
# 03_clustering.R
# ==============================

# Init
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c(
  "readr", "dplyr", "dbscan", "umap", "ggplot2",
  "tidytext", "tm", "stringr", "tibble", "cluster", "yaml", "purrr"
))

# Config
config <- yaml::read_yaml("config/config.yml")

# Ensure dirs
ensure_dir(file.path(config$paths$output_csv, "cluster"))
ensure_dir(file.path(config$paths$output_png, "cluster"))

# Load data
input_file   <- file.path(config$paths$output_csv, "01_translated_comments.csv")
embedding_rds <- file.path(config$paths$output_rds, "embeddings", "all_embeddings.rds")
df <- safe_read_csv(input_file)
emb_list <- readRDS(embedding_rds)

translated_cols <- if (!is.null(config$clustering$embedding_columns)) {
  config$clustering$embedding_columns
} else {
  grep("_translated$", names(df), value = TRUE)
}

log_info("Columns to cluster: {paste(translated_cols, collapse = ', ')}")

# ------------------------------
# Helpers
# ------------------------------
reduce_dimensions <- function(emb_matrix, n_dims = 50) {
  max_dims <- min(n_dims, ncol(emb_matrix), nrow(emb_matrix))
  if (max_dims < n_dims) log_info("Adjusted dims: requested {n_dims}, using {max_dims}")
  stats::prcomp(emb_matrix, center = TRUE, scale. = TRUE)$x[, 1:max_dims, drop = FALSE]
}

extract_labels <- function(texts, clusters) {
  dfw <- tibble::tibble(text = texts, cluster = clusters) %>%
    dplyr::filter(!is.na(cluster))
  labels <- list(`0` = "Noise")
  dfw_non_noise <- dfw %>% dplyr::filter(cluster != 0)
  if (nrow(dfw_non_noise) == 0) return(unlist(labels))
  tokens <- dfw_non_noise %>%
    tidytext::unnest_tokens(word, text) %>%
    dplyr::filter(!word %in% tm::stopwords("en"),
                  stringr::str_detect(word, "[a-z]"),
                  !stringr::str_detect(word, "^[0-9]+$"))
  tfidf <- tokens %>%
    dplyr::count(cluster, word, sort = TRUE) %>%
    tidytext::bind_tf_idf(word, cluster, n)
  top_keywords <- tfidf %>%
    dplyr::group_by(cluster) %>%
    dplyr::slice_max(tf_idf, n = 3, with_ties = FALSE) %>%
    dplyr::summarise(label = paste(word, collapse = ", "), .groups = "drop")
  lbl <- setNames(top_keywords$label, top_keywords$cluster)
  c(labels, as.list(lbl))
}

plot_umap <- function(layout, clusters, labels, col_name, method, output_dir) {
  plot_df <- data.frame(
    x = layout[, 1], y = layout[, 2],
    cluster = factor(clusters),
    label = labels[as.character(clusters)]
  )
  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x, y, color = cluster)) +
    ggplot2::geom_point(size = 2, alpha = 0.7) +
    ggplot2::theme_minimal() +
    ggplot2::labs(title = paste(method, "Clusters for", col_name),
                  x = "UMAP-1", y = "UMAP-2")
  ggplot2::ggsave(
    file.path(output_dir, paste0("clusters_", col_name, "_", tolower(method), "_umap.png")),
    p, width = 7, height = 5
  )
}

compute_silhouette <- function(data, clusters) {
  if (length(unique(clusters)) < 2) return(NA_real_)
  dist_matrix <- stats::dist(data)
  sil <- cluster::silhouette(clusters, dist_matrix)
  mean(sil[, 3])
}

# ------------------------------
# Main loop
# ------------------------------
summary_list <- list()

for (col_name in translated_cols) {
  log_info("Processing column: {col_name}")
  
  emb_matrix <- emb_list[[col_name]]
  if (is.null(emb_matrix)) {
    log_warn("Skipping {col_name} — no embeddings.")
    next
  }
  texts <- df[[col_name]] %>% tidyr::replace_na("")
  emb_matrix <- as.matrix(emb_matrix)
  
  valid_idx <- which(rowSums(!is.na(emb_matrix)) > 0)
  emb_matrix <- emb_matrix[valid_idx, , drop = FALSE]
  texts <- texts[valid_idx]
  
  if (nrow(emb_matrix) < config$clustering$min_docs) {
    log_warn("Skipping {col_name} — not enough valid responses ({nrow(emb_matrix)} < {config$clustering$min_docs}).")
    next
  }
  
  reduced <- reduce_dimensions(emb_matrix, config$clustering$umap_dims)
  
  umap_cfg <- umap::umap.defaults
  umap_cfg$random_state <- 42
  umap_layout <- umap::umap(reduced, config = umap_cfg)$layout
  
  # Try HDBSCAN
  hdb <- dbscan::hdbscan(reduced, minPts = config$clustering$min_pts)
  clusters <- hdb$cluster
  
  if (all(clusters == 0)) {
    log_info("HDBSCAN produced only noise — falling back to KMeans")
    best_k <- 2
    best_score <- -Inf
    upper_k <- min(config$clustering$max_kmeans_k, nrow(reduced) - 1)
    for (k in 2:upper_k) {
      km <- stats::kmeans(reduced, centers = k, nstart = 10)
      score <- compute_silhouette(reduced, km$cluster)
      if (!is.na(score) && score > best_score) {
        best_score <- score
        best_k <- k
      }
    }
    km <- stats::kmeans(reduced, centers = best_k, nstart = 10)
    clusters <- km$cluster
    method <- "KMeans"
    silhouette_score <- round(best_score, 3)
  } else {
    method <- "HDBSCAN"
    silhouette_score <- round(compute_silhouette(reduced, clusters), 3)
  }
  
  labels <- extract_labels(texts, clusters)
  clustered_df <- tibble::tibble(
    text = texts,
    cluster = clusters,
    cluster_label = labels[as.character(clusters)]
  )
  
  output_csv <- file.path(config$paths$output_csv, "cluster", paste0("clusters_", col_name, ".csv"))
  safe_write_csv(clustered_df, output_csv)
  log_info("Saved clusters to: {output_csv}")
  
  if (isTRUE(config$clustering$make_plots)) {
    plot_umap(umap_layout, clusters, labels, col_name, method,
              file.path(config$paths$output_png, "cluster"))
  }
  
  summary_list[[col_name]] <- tibble::tibble(
    question = col_name,
    cluster = names(labels),
    suggested_label = unname(labels),
    method = method,
    silhouette = silhouette_score
  )
}

# Save summary
if (length(summary_list) > 0) {
  summary_df <- dplyr::bind_rows(summary_list)
  summary_csv <- file.path(config$paths$output_csv, "cluster", "03_clusters_summary.csv")
  safe_write_csv(summary_df, summary_csv)
  log_info("Cluster summary saved to: {summary_csv}")
} else {
  log_info("No clusters generated.")
}
