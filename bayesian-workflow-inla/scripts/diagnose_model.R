#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
})

#' Diagnose INLA Model Fit
#'
#' Computes CPO failure rates, LCPO (-mean(log(cpo))), PIT uniformity via Kolmogorov-Smirnov test,
#' and extracts DIC and WAIC with effective parameter counts.
#'
#' @param result An INLA result object (loaded from .rds)
#' @return A named list representing the diagnostic report
diagnose_inla_model <- function(result) {
  report <- list()

  # CPO checks
  cpo_failure_rate <- NA
  lcpo <- NA
  n_failures <- 0
  n_severe_failures <- 0
  cpo_ok <- FALSE

  if (!is.null(result$cpo)) {
    failures <- result$cpo$failure
    if (!is.null(failures)) {
      cpo_failure_rate <- mean(failures > 0, na.rm = TRUE)
      n_failures <- sum(failures > 0, na.rm = TRUE)
      n_severe_failures <- sum(failures > 0.1, na.rm = TRUE)
    }
    
    cpo_vals <- result$cpo$cpo
    if (!is.null(cpo_vals)) {
      # Standard LCPO: negative mean log-CPO (lower is better)
      lcpo <- -mean(log(cpo_vals[cpo_vals > 0]), na.rm = TRUE)
    }
    
    # CPO failure threshold: <= 0.01 (1%) is pass/ok, > 0.01 is warning/fail
    cpo_ok <- ifelse(!is.na(cpo_failure_rate) && cpo_failure_rate <= 0.01, TRUE, FALSE)
  }

  report$cpo <- list(
    lcpo = lcpo,
    failure_rate = cpo_failure_rate,
    n_failures = n_failures,
    n_severe_failures = n_severe_failures,
    ok = cpo_ok
  )

  # PIT checks
  pit_ks_pvalue <- NA
  pit_uniform <- FALSE
  pit_ok <- FALSE

  if (!is.null(result$cpo) && !is.null(result$cpo$pit)) {
    pit_vals <- result$cpo$pit
    pit_vals <- pit_vals[!is.na(pit_vals) & pit_vals > 0 & pit_vals < 1]
    if (length(pit_vals) > 0) {
      ks_res <- suppressWarnings(ks.test(pit_vals, "punif", 0, 1))
      pit_ks_pvalue <- ks_res$p.value
      pit_uniform <- pit_ks_pvalue > 0.05
      pit_ok <- pit_uniform
    }
  }

  report$pit <- list(
    ks_pvalue = pit_ks_pvalue,
    uniform = pit_uniform,
    ok = pit_ok
  )

  # DIC
  if (!is.null(result$dic)) {
    p_eff_dic <- if (!is.null(result$dic$p.eff)) result$dic$p.eff else NA
    report$dic <- list(
      dic = result$dic$dic,
      p_eff = p_eff_dic
    )
  } else {
    report$dic <- list(dic = NA, p_eff = NA)
  }

  # WAIC (defensive extraction: p.eff or p.eff.waic)
  if (!is.null(result$waic)) {
    p_eff_waic <- if (!is.null(result$waic$p.eff)) {
      result$waic$p.eff
    } else if (!is.null(result$waic$p.eff.waic)) {
      result$waic$p.eff.waic
    } else {
      NA
    }
    report$waic <- list(
      waic = result$waic$waic,
      p_eff = p_eff_waic
    )
  } else {
    report$waic <- list(waic = NA, p_eff = NA)
  }

  report$all_ok <- isTRUE(report$cpo$ok) && isTRUE(report$pit$ok)

  # Overall assessment
  issues <- c()
  if (!isTRUE(report$cpo$ok)) {
    if (!is.na(cpo_failure_rate) && cpo_failure_rate > 0.05) {
      issues <- c(issues, sprintf("Severe CPO failure rate (%.1f%% > 5%%)", cpo_failure_rate * 100))
    } else {
      issues <- c(issues, sprintf("CPO failure rate exceeds standard threshold (%.1f%% > 1%%)", cpo_failure_rate * 100))
    }
  }
  if (!isTRUE(report$pit$ok)) {
    issues <- c(issues, "PIT values deviate from uniformity (Kolmogorov-Smirnov p <= 0.05)")
  }

  report$overall <- list(
    ok = length(issues) == 0,
    issues = issues,
    recommendation = ifelse(
      length(issues) == 0, 
      "Model passes numerical stability and cross-validation diagnostics. Ready for interpretation.", 
      paste("Address issues before interpreting results:", paste(issues, collapse = "; "))
    )
  )

  return(report)
}

# CLI Execution block
if (sys.nframe() == 0) {
  option_list <- list(
    make_option(c("--result"), type = "character", default = NULL, 
                help = "Path to INLA result (.rds file)", metavar = "character"),
    make_option(c("--output"), type = "character", default = NULL, 
                help = "Path to save JSON report (default: print to stdout)", metavar = "character")
  )

  opt_parser <- OptionParser(option_list = option_list)
  opt <- parse_args(opt_parser)

  if (is.null(opt$result)) {
    print_help(opt_parser)
    stop("Argument --result must be supplied.", call. = FALSE)
  }

  tryCatch({
    result <- readRDS(opt$result)
  }, error = function(e) {
    cat(toJSON(list(error = paste("Could not load INLA result:", e$message)), auto_unbox = TRUE))
    quit(status = 1)
  })

  report <- diagnose_inla_model(result)
  json_out <- toJSON(report, auto_unbox = TRUE, pretty = TRUE, null = "null")

  if (!is.null(opt$output)) {
    writeLines(json_out, opt$output)
    cat(paste("Report saved to", opt$output, "\n"))
  } else {
    cat(json_out, "\n")
  }
}
