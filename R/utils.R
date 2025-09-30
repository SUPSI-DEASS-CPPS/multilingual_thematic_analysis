# ==============================
# Utility Functions
# ==============================

suppressPackageStartupMessages({
  library(cli)
  library(glue)
})

# --- Environment Management ---
clear_environment <- function() {
  if (!interactive()) {
    rm(list = ls(), envir = .GlobalEnv)
    graphics.off()
    cat("\014")
  } else {
    message("Interactive mode: environment not cleared.")
  }
  invisible(gc())
}

# --- Package Loader ---
load_required_packages <- function(packages) {
  missing <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(missing) > 0) {
    message("Installing missing packages: ", paste(missing, collapse = ", "))
    install.packages(missing)
  }
  invisible(lapply(packages, library, character.only = TRUE))
}

# --- Logging Helpers ---
timestamp <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

log_info <- function(...) {
  cli::cli_inform(glue("[INFO  {timestamp()}] {paste(..., collapse = ' ')}"))
}

log_warn <- function(...) {
  cli::cli_alert_warning(glue("[WARN  {timestamp()}] {paste(..., collapse = ' ')}"))
}

log_error <- function(...) {
  cli::cli_alert_danger(glue("[ERROR {timestamp()}] {paste(..., collapse = ' ')}"))
}

# --- Directory Helpers ---
ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
    log_info("Created directory: {path}")
  }
}

# --- Safe I/O ---
safe_read_csv <- function(path, ...) {
  tryCatch(
    readr::read_csv(path, show_col_types = FALSE, ...),
    error = function(e) {
      log_error("Failed to read CSV: {path} - {conditionMessage(e)}")
      tibble::tibble()
    }
  )
}

safe_write_csv <- function(df, path, ...) {
  ensure_dir(dirname(path))
  tryCatch(
    readr::write_csv(df, path, ...),
    error = function(e) log_error("Failed to write CSV: {path} - {conditionMessage(e)}")
  )
}

# --- Retry Logic for API Calls ---
with_retries <- function(expr, max_attempts = 3, wait = 2) {
  attempt <- 1
  repeat {
    result <- tryCatch(eval(expr), error = identity)
    if (!inherits(result, "error")) return(result)
    if (attempt >= max_attempts) stop(result)
    log_warn("Attempt {attempt} failed: {conditionMessage(result)}. Retrying...")
    Sys.sleep(wait ^ attempt)
    attempt <- attempt + 1
  }
}

# --- Caching Helpers ---
cache_result <- function(key, cache_dir, expr) {
  ensure_dir(cache_dir)
  cache_file <- file.path(cache_dir, paste0(key, ".rds"))
  if (file.exists(cache_file)) {
    log_info("Loaded cached result for {key}")
    return(readRDS(cache_file))
  }
  result <- eval(expr)
  saveRDS(result, cache_file)
  log_info("Cached result for {key}")
  result
}
