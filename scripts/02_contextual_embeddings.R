# ==============================
# 02_contextual_embeddings.R
# ==============================

# Load utilities and configuration
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c("readr", "dplyr", "httr", "jsonlite", "gargle",
                         "tidyr", "progress", "tibble", "yaml"))

# Load configuration
config <- yaml::read_yaml("config/config.yml")

# ==============================
# Authentication
# ==============================
get_access_token <- function(sa_key) {
  scope <- "https://www.googleapis.com/auth/cloud-platform"
  if (file.exists(sa_key)) {
    gargle::credentials_service_account(path = sa_key, scope = scope)$credentials$access_token
  } else {
    gargle::credentials_app_default(scope = scope)$credentials$access_token
  }
}

sa_key_path <- Sys.getenv(config$embeddings$gcp_key_env)
gcp_project <- Sys.getenv(config$embeddings$gcp_project_env)
stopifnot(nzchar(sa_key_path), nzchar(gcp_project))

access_token <- get_access_token(sa_key_path)
stopifnot(!is.null(access_token))

# ==============================
# Helpers
# ==============================
resp_text <- function(resp) {
  tryCatch(httr::content(resp, as = "text", encoding = "UTF-8"),
           error = function(e) rawToChar(httr::content(resp, as = "raw")))
}

vertex_predict_url <- function(project, location, model) {
  sprintf("https://%s-aiplatform.googleapis.com/v1/projects/%s/locations/%s/publishers/google/models/%s:predict",
          location, project, location, model)
}

`%||%` <- function(a, b) if (!is.null(a)) a else b

parse_embeddings <- function(resp_json, expected_dim = 768) {
  preds <- resp_json$predictions
  mats <- lapply(preds, function(p) {
    values <- p$embedding$values %||% p$embeddings$values
    if (!is.null(values)) as.numeric(values) else rep(NA_real_, expected_dim)
  })
  do.call(rbind, mats)
}

# ==============================
# Embedding Request
# ==============================
get_google_embeddings <- function(texts, config, access_token) {
  url <- vertex_predict_url(gcp_project, config$embeddings$location, config$embeddings$model_id)
  headers <- httr::add_headers(Authorization = paste("Bearer", access_token),
                               `Content-Type` = "application/json")
  n <- length(texts)
  out <- vector("list", n)
  pb <- progress_bar$new(total = ceiling(n / config$embeddings$batch_size),
                         format = "  [:bar] :percent | Batch :current/:total")
  
  for (start_idx in seq(1, n, by = config$embeddings$batch_size)) {
    end_idx <- min(start_idx + config$embeddings$batch_size - 1, n)
    batch <- texts[start_idx:end_idx]
    nonempty <- which(nzchar(batch) & !is.na(batch))
    empty <- setdiff(seq_along(batch), nonempty)
    
    if (length(nonempty) > 0) {
      body <- list(instances = lapply(batch[nonempty], \(x) list(content = x)))
      resp <- retry(quote(
        httr::POST(url, headers, body = toJSON(body, auto_unbox = TRUE),
                   timeout(config$embeddings$timeout_secs))
      ))
      
      resp_txt <- resp_text(resp)
      resp_json <- fromJSON(resp_txt, simplifyVector = FALSE)
      emb_mat <- parse_embeddings(resp_json)
      for (i in seq_along(nonempty)) {
        out[[start_idx + nonempty[i] - 1]] <- emb_mat[i, ]
      }
    }
    
    for (i in empty) {
      out[[start_idx + i - 1]] <- rep(NA_real_, ncol(emb_mat))
    }
    
    pb$tick()
  }
  
  do.call(rbind, out)
}

# ==============================
# Load Data
# ==============================
input_file <- file.path(config$paths$output_csv, "01_translated_comments.csv")
df <- read_csv(input_file, show_col_types = FALSE)

translated_cols <- grep("_translated$", names(df), value = TRUE)
cat("Rows:", nrow(df), "| Columns to embed:", length(translated_cols), "\n")

# ==============================
# Generate and Save Embeddings
# ==============================
emb_list <- list()
summary_info <- list()

for (col in translated_cols) {
  message("Processing:", col)
  texts <- df[[col]] |> replace_na(NA_character_)
  emb_matrix <- get_google_embeddings(texts, config, access_token)
  
  # Ensure row alignment
  if (nrow(emb_matrix) != length(texts)) {
    emb_matrix <- rbind(emb_matrix,
                        matrix(NA_real_, nrow = length(texts) - nrow(emb_matrix),
                               ncol = ncol(emb_matrix)))
  }
  
  emb_list[[col]] <- emb_matrix
  
  saveRDS(emb_matrix, file.path(config$paths$output_rds, "embeddings", paste0("embeddings_", col, ".rds")))
  
  emb_df <- tibble(row_id = seq_along(texts), text = texts) |> bind_cols(as.data.frame(emb_matrix))
  write_csv(emb_df, file.path(config$paths$output_csv, "embeddings", paste0("embeddings_", col, ".csv")))
  
  summary_info[[col]] <- tibble(
    question = col,
    total_rows = length(texts),
    valid_rows = sum(rowSums(!is.na(emb_matrix)) > 0),
    embedding_dim = ncol(emb_matrix)
  )
}

# ==============================
# Save Combined Embeddings
# ==============================
saveRDS(emb_list, file.path(config$paths$output_rds, "embeddings", "all_embeddings.rds"))

combined_csv <- bind_rows(
  lapply(names(emb_list), function(col) {
    tibble(
      question = col,
      row_id   = seq_len(nrow(emb_list[[col]])),
      text     = df[[col]]
    ) |> bind_cols(as.data.frame(emb_list[[col]]))
  })
)
write_csv(combined_csv, file.path(config$paths$output_csv, "embeddings", "all_embeddings.csv"))

# ==============================
# Save Summary
# ==============================
summary_df <- bind_rows(summary_info)
write_csv(summary_df, file.path(config$paths$output_csv, "02_embedding_summary.csv"))

# ==============================
# Completion Message
# ==============================
cat("Embeddings complete\n")
cat("CSV directory:", file.path(config$paths$output_csv, "embeddings"), "\n")
cat("RDS directory:", file.path(config$paths$output_rds, "embeddings"), "\n")
cat("Summary file: 02_embedding_summary.csv\n")
