# ==============================
# Utility Functions
# ==============================

# Safe environment clearing
clear_environment <- function() {
  if (!interactive()) {
    rm(list = ls())
    graphics.off()
    cat("\014")
  } else {
    message("Interactive mode: environment not cleared.")
  }
}

# Package loader
load_required_packages <- function(packages) {
  missing <- packages[!(packages %in% installed.packages()[, "Package"])]
  if (length(missing) > 0) {
    message("Installing missing packages: ", paste(missing, collapse = ", "))
    install.packages(missing)
  }
  invisible(lapply(packages, library, character.only = TRUE))
}

# Simple logger
log_info <- function(...) {
  cat("[INFO]", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "-", ..., "\n")
}

# Retry helper for API calls
retry <- function(expr, times = 3, wait = 2) {
  for (i in seq_len(times)) {
    result <- try(eval(expr), silent = TRUE)
    if (!inherits(result, "try-error")) return(result)
    Sys.sleep(wait ^ i)
  }
  stop("All retries failed.")
}