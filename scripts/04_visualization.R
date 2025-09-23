# ==============================
# 04_visualization.R
# ==============================

# Load utilities and configuration
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c(
  "readr", "RColorBrewer", "tools", "dplyr", "purrr", "stopwords",
  "htmlwidgets", "htmltools", "wordcloud2", "webshot2", "yaml"
))

# Load configuration
config <- yaml::read_yaml("config/config.yml")

# Ensure output dirs exist
walk(config$paths, ~dir.create(.x, recursive = TRUE, showWarnings = FALSE))

# ==============================
# Helpers
# ==============================
sanitize_text <- function(x) {
  gsub("[[:cntrl:]<>]|<[^>]*>|&[a-zA-Z0-9#]+;", " ", x) |> trimws()
}

sanitize_terms <- function(df, custom_stopwords, regex_stopwords) {
  sw <- unique(c(stopwords::stopwords("en"), tolower(custom_stopwords)))
  regex_combined <- paste(regex_stopwords, collapse = "|")
  df %>%
    mutate(term = tolower(sanitize_text(term)),
           term = gsub("[[:punct:]]", "", term)) %>%
    filter(nzchar(term),
           !term %in% sw,
           !grepl(regex_combined, term))
}

save_html_safely <- function(widget, out_file) {
  htmltools::save_html(widget, file = out_file, background = config$visualization$background)
}

# ==============================
# Wordcloud Generator
# ==============================
generate_combined_wordcloud <- function(data, base_name) {
  data <- sanitize_terms(data, config$visualization$custom_stopwords, config$visualization$regex_stopwords)
  if (!nrow(data)) return(invisible(NULL))
  
  freqs <- data %>%
    count(term, wt = freq, name = "freq_sum", sort = TRUE) %>%
    filter(freq_sum >= config$visualization$min_freq) %>%
    slice_head(n = config$visualization$max_words)
  
  if (!nrow(freqs)) return(invisible(NULL))
  
  freqs <- freqs %>%
    mutate(weight = (freq_sum ^ config$visualization$weight_power) /
             max(freq_sum ^ config$visualization$weight_power) * 100)
  
  wc <- wordcloud2(freqs,
                   size = config$visualization$size,
                   color = config$visualization$color,
                   backgroundColor = config$visualization$background,
                   rotateRatio = config$visualization$rotateRatio)
  
  png_file  <- file.path(config$paths$output_png, "wordclouds", paste0("04_wordclouds_", base_name, "_combined.png"))
  html_file <- file.path(config$paths$output_html, "wordclouds", paste0("04_wordclouds_", base_name, "_combined.html"))
  
  tryCatch({
    tmp_html <- tempfile(fileext = ".html")
    suppressWarnings(htmlwidgets::saveWidget(wc, tmp_html, selfcontained = TRUE))
    webshot2::webshot(tmp_html, file = png_file,
                      vwidth = config$visualization$png_width,
                      vheight = config$visualization$png_height)
    log_info("Saved PNG:", png_file)
    
    if (config$visualization$export_html_always) {
      htmltools::save_html(wc, file = html_file, background = config$visualization$background)
      log_info("Also saved HTML:", html_file)
    }
  }, error = function(e) {
    htmltools::save_html(wc, file = html_file, background = config$visualization$background)
    log_info("PNG export failed, saved HTML instead:", html_file)
  })
}

# ==============================
# Main Loop
# ==============================
cluster_dir <- file.path(config$paths$output_csv, "cluster")
cluster_files <- list.files(cluster_dir,
                            pattern = "^clusters_Q4\\.[0-9]+_translated\\.csv$",
                            full.names = TRUE) %>%
  keep(~as.numeric(sub("^clusters_Q4\\.([0-9]+)_.*", "\\1", basename(.x))) %in% config$visualization$q_range)

log_info("Found", length(cluster_files), "cluster files.")

walk(cluster_files, function(cluster_path) {
  base_name <- gsub("^clusters_", "", tools::file_path_sans_ext(basename(cluster_path)))
  clustered_df <- suppressMessages(readr::read_csv(cluster_path, show_col_types = FALSE))
  
  if (!all(c("text", "cluster", "cluster_label") %in% names(clustered_df))) {
    log_info("Skipping", base_name, "- missing required columns.")
    return()
  }
  
  wc_data <- clustered_df %>%
    mutate(text = sanitize_text(text)) %>%
    group_by(cluster) %>%
    summarise(term = unlist(strsplit(paste(text, collapse = " "), "\\s+")),
              .groups = "drop") %>%
    count(cluster, term, name = "freq") %>%
    filter(nzchar(term), !grepl("<|>", term))
  
  if (!nrow(wc_data)) {
    log_info("No terms after cleaning for", base_name)
    return()
  }
  
  generate_combined_wordcloud(wc_data, base_name)
})

log_info("All wordclouds generated.")
