# ==============================
# 02_contextual_embeddings.R
# ==============================

# Init
source("R/utils.R")
clear_environment()
set.seed(42)

load_required_packages(c(
  "readr", "dplyr", "httr", "jsonlite", "gargle",
  "tidyr", "progress", "tibble", "yaml", "purrr"
))

# Config
config <- yaml::read_yaml("config/config.yml")

# Auth
sa_key_path <- Sys.getenv(config$embeddings$gcp_key_env)
gcp_project <- Sys.getenv(config$embeddings$gcp_project_env)
if (!nzchar(sa_key_path) || !nzchar(gcp_project)) {
  log_error("GCP key or project env vars missing.")
  stop("Set both {config$embeddings$gcp_key_env} and {config$embeddings$gcp_project_env}.")
}

access_token <- tryCatch({
  gargle::credentials_service_account(
    path = sa_key_path,
    scope = "https://www.googleapis.com/auth/cloud-platform"
  )$credentials$access_token
}, error = function(e) {
  log_error("Failed to obtain access token: {conditionMessage(e)}")
  NULL
})
stopifnot(!is.null(access_token))

# Ensure dirs
ensure_dir(file.path(config$paths$output_rds, "embeddings"))
ensure_dir(file.path(config$paths$output_csv, "embeddings"))

# ------------------------------
# Helpers
# ------------------------------
resp_text <- function(resp) {
  tryCatch(httr::content(resp, as = "text", encoding = "UTF-8"),
           error = function(e) rawToChar(httr::content(resp, as = "raw")))
}

vertex_predict_url <- function(project, location, model) {
  sprintf(
    "https://%s-aiplatform.googleapis.com/v1/projects/%s/locations/%s/publishers/google/models/%s:predict",
    location, project, location, model
  )
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

get_google_embeddings <- function(texts, config, access_token) {
  url <- vertex_predict_url(gcp_project, config$embeddings$location, config$embeddings$model_id)
  headers <- httr::add_headers(
    Authorization = paste("Bearer", access_token),
    `Content-Type` = "application/json"
  )
  n <- length(texts)
  out <- vector("list", n)
  pb <- progress::progress_bar$new(total = ceiling(n / config$embeddings$batch_size),
                                   format = "  [:bar] :percent | Batch :current/:total")
  
  for (start_idx in seq(1, n, by = config$embeddings$batch_size)) {
    end_idx <- min(start_idx + config$embeddings$batch_size - 1, n)
    batch <- texts[start_idx:end_idx]
    nonempty <- which(nzchar(batch) & !is.na(batch))
    empty <- setdiff(seq_along(batch), nonempty)
    
    emb_mat <- NULL
    if (length(nonempty) > 0) {
      body <- list(instances = lapply(batch[nonempty], \(x) list(content = x)))
      resp <- with_retries(quote(
        httr::POST(url, headers, body = jsonlite::toJSON(body, auto_unbox = TRUE),
                   httr::timeout(config$embeddings$timeout_secs))
      ))
      resp_txt <- resp_text(resp)
      resp_json <- jsonlite::fromJSON(resp_txt, simplifyVector = FALSE)
      emb_mat <- parse_embeddings(resp_json)
      for (i in seq_along(nonempty)) {
        out[[start_idx + nonempty[i] - 1]] <- emb_mat[i, ]
      }
    }
    # Fill empties
    if (!is.null(emb_mat)) {
      for (i in empty) {
        out[[start_idx + i - 1]] <- rep(NA_real_, ncol(emb_mat))
      }
    } else {
      for (i in empty) {
        out[[start_idx + i - 1]] <- rep(NA_real_, config$embeddings$expected_dim %||% 768)
      }
    }
    pb$tick()
  }
  do.call(rbind, out)
}

# ------------------------------
# Load data
# ------------------------------
input_file <- file.path(config$paths$output_csv, "01_translated_comments.csv")
df <- safe_read_csv(input_file)
translated_cols <- grep("_translated$", names(df), value = TRUE)
log_info("Columns to embed: {length(translated_cols)}")

# ------------------------------
# Generate + Save Embeddings (cached)
# ------------------------------
emb_list <- list()
summary_info <- list()

for (col in translated_cols) {
  log_info("Embedding column: {col}")
  texts <- df[[col]] |> tidyr::replace_na(NA_character_)
  
  key <- paste0("embeddings_", col)
  emb_matrix <- cache_result(
    key,
    file.path(config$paths$output_rds, "embeddings"),
    quote(get_google_embeddings(texts, config, access_token))
  )
  
  # Ensure alignment
  if (nrow(emb_matrix) != length(texts)) {
    emb_matrix <- rbind(
      emb_matrix,
      matrix(NA_real_, nrow = length(texts) - nrow(emb_matrix), ncol = ncol(emb_matrix))
    )
  }
  
  emb_list[[col]] <- emb_matrix
  
  # Save CSV
  emb_df <- tibble::tibble(row_id = seq_along(texts), text = texts) |>
    dplyr::bind_cols(as.data.frame(emb_matrix))
  safe_write_csv(emb_df, file.path(config$paths$output_csv, "embeddings", paste0("embeddings_", col, ".csv")))
  
  summary_info[[col]] <- tibble::tibble(
    question = col,
    total_rows = length(texts),
    valid_rows = sum(rowSums(!is.na(emb_matrix)) > 0),
    embedding_dim = ncol(emb_matrix)
  )
}

# Save combined
saveRDS(emb_list, file.path(config$paths$output_rds, "embeddings", "all_embeddings.rds"))

combined_csv <- dplyr::bind_rows(
  lapply(names(emb_list), function(col) {
    tibble::tibble(
      question = col,
      row_id   = seq_len(nrow(emb_list[[col]])),
      text     = df[[col]]
    ) |> dplyr::bind_cols(as.data.frame(emb_list[[col]]))
  })
)
safe_write_csv(combined_csv, file.path(config$paths$output_csv, "embeddings", "all_embeddings.csv"))

# Save summary
summary_df <- dplyr::bind_rows(summary_info)
safe_write_csv(summary_df, file.path(config$paths$output_csv, "02_embedding_summary.csv"))

log_info("Embeddings complete.")
