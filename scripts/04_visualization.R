# ==============================
# 04_visualization.R (Deterministic, Quanteda + ggwordcloud)
# ==============================

# Init
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c(
  "readr", "dplyr", "purrr", "yaml", "stopwords", "stringi",
  "ggplot2", "ggwordcloud", "quanteda", "RColorBrewer", "tools"
))

# Config
config <- yaml::read_yaml("config/config.yml")
viz <- config$visualization

# Ensure output dirs
purrr::walk(config$paths, ~ensure_dir(.x))
ensure_dir(file.path(config$paths$output_png, "wordclouds"))
ensure_dir(file.path(config$paths$output_csv, "cluster"))

# ------------------------------
# Precompute stopwords & regex
# ------------------------------
global_sw <- unique(c(stopwords::stopwords("en"), tolower(viz$custom_stopwords %||% character(0))))
stopword_map <- purrr::map(config$question_stopwords, ~unique(c(global_sw, tolower(.x))))
regex_patterns <- viz$regex_stopwords %||% character(0)
has_regex <- length(regex_patterns) > 0

# ------------------------------
# Helpers
# ------------------------------
sanitize_text <- function(x) {
  stringi::stri_trim_both(
    stringi::stri_trans_general(
      stringi::stri_replace_all_regex(x, "[[:cntrl:]<>]|<[^>]*>|&[a-zA-Z0-9#]+;", " "),
      "Any-Lower"
    )
  )
}

audit_log <- function(q, before_chars, before_tokens, after_tokens, sw_global_len, sw_question_len, regex_len) {
  log_info("Audit {q} | chars:{before_chars} | tokens before:{before_tokens} | tokens after:{after_tokens} | global sw:{sw_global_len} | question sw:{sw_question_len} | regex:{regex_len}")
}

get_colors <- function(n, color_spec) {
  if (identical(color_spec, "random-dark")) {
    pal <- RColorBrewer::brewer.pal(8, "Dark2")
    rep(pal, length.out = n)
  } else {
    rep(color_spec %||% "black", n)
  }
}

get_angles <- function(n, rotate_ratio) {
  k <- round(n * rotate_ratio)
  c(rep(0, n - k), rep(90, k))
}

build_freq_table <- function(text_vec, q_key) {
  sw <- stopword_map[[q_key]] %||% global_sw
  sw_question_len <- max(length(sw) - length(global_sw), 0)
  
  toks <- quanteda::tokens(text_vec, remove_punct = TRUE)
  toks <- quanteda::tokens_remove(toks, sw, valuetype = "fixed", case_insensitive = TRUE)
  if (has_regex) {
    toks <- quanteda::tokens_remove(toks, regex_patterns, valuetype = "regex", case_insensitive = TRUE)
  }
  
  dfm <- quanteda::dfm(toks)
  freqs <- sort(Matrix::colSums(dfm), decreasing = TRUE)
  
  tibble::tibble(
    term = names(freqs),
    freq_sum = as.numeric(freqs)
  ) %>%
    dplyr::filter(freq_sum >= viz$min_freq) %>%
    dplyr::slice_head(n = viz$max_words) %>%
    dplyr::mutate(
      weight = (freq_sum ^ viz$weight_power),
      weight = weight / max(weight) * 100
    ) %>%
    {
      before_chars <- sum(nchar(text_vec), na.rm = TRUE)
      before_tokens <- sum(quanteda::ntoken(quanteda::tokens(text_vec, remove_punct = TRUE)))
      after_tokens <- sum(quanteda::ntoken(toks))
      audit_log(q_key, before_chars, before_tokens, after_tokens, length(global_sw), sw_question_len, length(regex_patterns))
      .
    }
}

render_wordcloud_png <- function(freqs_df, base_name) {
  if (!nrow(freqs_df)) {
    log_info("No terms meet thresholds for {base_name}")
    return(invisible(NULL))
  }
  colors <- get_colors(nrow(freqs_df), viz$color)
  angles <- get_angles(nrow(freqs_df), viz$rotateRatio)
  
  set.seed(42)
  p <- ggplot2::ggplot(freqs_df, ggplot2::aes(label = term, size = weight, color = term, angle = angles)) +
    ggwordcloud::geom_text_wordcloud_area() +
    ggplot2::scale_size(range = c(1, 10)) +
    ggplot2::scale_color_manual(values = colors, guide = "none") +
    ggplot2::theme_void() +
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = viz$background, color = viz$background))
  
  out_png <- file.path(config$paths$output_png, "wordclouds", paste0("04_wordclouds_", base_name, "_combined.png"))
  ggplot2::ggsave(
    filename = out_png,
    plot = p,
    width = viz$png_width / 150,
    height = viz$png_height / 150,
    dpi = 150,
    bg = viz$background
  )
  log_info("Saved PNG: {out_png}")
}

# ------------------------------
# Main
# ------------------------------
cluster_dir <- file.path(config$paths$output_csv, "cluster")
cluster_files_all <- list.files(
  cluster_dir,
  pattern = "^clusters_Q4\\.[0-9]+_translated\\.csv$",
  full.names = TRUE
)
cluster_ids <- as.numeric(sub("^clusters_Q4\\.([0-9]+)_.*", "\\1", basename(cluster_files_all)))
cluster_files <- cluster_files_all[cluster_ids %in% viz$q_range]

log_info("Found {length(cluster_files_all)} candidate files.")
log_info("Selected {length(cluster_files)} within q_range: {paste(viz$q_range, collapse = ',')}")

purrr::walk(cluster_files, function(cluster_path) {
  base_name <- gsub("^clusters_", "", tools::file_path_sans_ext(basename(cluster_path)))
  q_key <- base_name
  log_info("Processing: {base_name}")
  
  clustered_df <- suppressMessages(readr::read_csv(
    cluster_path,
    col_select = c(text, cluster, cluster_label),
    show_col_types = FALSE
  ))
  
  required_cols <- c("text", "cluster", "cluster_label")
  if (!all(required_cols %in% names(clustered_df))) {
    log_warn("Skipping {base_name} — missing required columns.")
    return()
  }
  if (all(is.na(clustered_df$text))) {
    log_warn("Skipping {base_name} — text column is empty.")
    return()
  }
  
  all_text <- sanitize_text(paste(clustered_df$text, collapse = " "))
  freqs_df <- build_freq_table(all_text, q_key)
  render_wordcloud_png(freqs_df, base_name)
})

log_info("All wordclouds generated.")
