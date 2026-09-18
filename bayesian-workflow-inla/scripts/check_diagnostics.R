#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
})

#' Evaluate Diagnostic Reports and Generate Qualitative Ratings & Actions
#'
#' @param diagnostics A list parsed from diagnose_model.R JSON
#' @param calibration An optional list parsed from calibration_check.R JSON
#' @param model_comparison An optional list of model comparison metrics (DIC/WAIC/LCPO)
#' @param sensitivity An optional list of prior sensitivity metrics
#' @return A comprehensive assessment list with ratings and actionable next steps
evaluate_inla_diagnostics <- function(diagnostics, calibration = NULL, model_comparison = NULL, sensitivity = NULL) {
  report <- list()

  # 1. Evaluate CPO
  cpo_rating <- "excellent"
  cpo_issues <- c()

  if (!is.null(diagnostics$cpo)) {
    fail_rate <- diagnostics$cpo$failure_rate
    if (!is.na(fail_rate)) {
      if (fail_rate > 0.05) {
        cpo_rating <- "poor"
        cpo_issues <- c(cpo_issues, sprintf("Severe CPO failure rate: %.1f%% (> 5%% threshold)", fail_rate * 100))
      } else if (fail_rate > 0.01) {
        cpo_rating <- "fair"
        cpo_issues <- c(cpo_issues, sprintf("Moderate CPO failure rate: %.1f%% (> 1%% threshold)", fail_rate * 100))
      } else if (fail_rate > 0) {
        cpo_rating <- "good"
        cpo_issues <- c(cpo_issues, sprintf("Minor CPO failures: %.2f%% (within acceptable <= 1%% margin)", fail_rate * 100))
      }
    }
  }

  report$cpo <- list(rating = cpo_rating, issues = cpo_issues)

  # 2. Evaluate PIT Uniformity
  pit_rating <- "excellent"
  if (!is.null(diagnostics$pit)) {
    if (!is.null(diagnostics$pit$ks_pvalue) && !is.na(diagnostics$pit$ks_pvalue)) {
      pval <- diagnostics$pit$ks_pvalue
      if (pval < 0.01) {
        pit_rating <- "poor"
      } else if (pval <= 0.05) {
        pit_rating <- "fair"
      }
    }
  }

  report$pit <- list(rating = pit_rating)

  # 3. Evaluate Calibration
  if (!is.null(calibration) && !is.null(calibration$assessment)) {
    cal <- calibration$assessment
    cal_rating <- if (!is.null(cal$rating)) cal$rating else {
      if (isTRUE(cal$well_calibrated)) "excellent"
      else if (abs(cal$mean_coverage_deviation) <= 0.05) "fair"
      else "poor"
    }
    report$calibration <- list(
      rating = cal_rating, 
      diagnosis = cal$calibration_diagnosis,
      mean_coverage_deviation = cal$mean_coverage_deviation
    )
  }

  # 4. Optional Model Comparison Summary
  if (!is.null(model_comparison)) {
    report$model_comparison <- model_comparison
  }

  # 5. Optional Prior Sensitivity Summary
  if (!is.null(sensitivity)) {
    report$sensitivity <- sensitivity
  }

  # Build Summary Text
  summary_lines <- list()
  if (report$cpo$rating %in% c("excellent", "good")) {
    summary_lines$cpo <- sprintf("CPO diagnostics passed (%s).", report$cpo$rating)
  } else {
    summary_lines$cpo <- sprintf("CPO is %s — %s", report$cpo$rating, paste(report$cpo$issues, collapse = "; "))
  }

  summary_lines$pit <- sprintf("PIT uniformity: %s", report$pit$rating)

  if (!is.null(report$calibration)) {
    diag_msg <- ifelse(!is.null(report$calibration$diagnosis), sprintf(" — %s", report$calibration$diagnosis), "")
    summary_lines$calibration <- sprintf("Calibration is %s%s", report$calibration$rating, diag_msg)
  }

  report$summary <- summary_lines

  # Generate Actionable Next Steps
  next_steps <- c()
  if (report$cpo$rating %in% c("poor", "fair")) {
    next_steps <- c(next_steps, "CPO numerical failures detected: Re-fit using high-accuracy integration with control.inla = list(int.strategy = 'grid', diff.logdens = 4) and inspect high-leverage data outliers.")
  }

  if (report$pit$rating == "poor") {
    next_steps <- c(next_steps, "PIT uniformity check failed: Address likelihood misspecification. Consider overdispersed or heavy-tailed likelihoods (e.g., family='nbinomial', family='T') or add observation/group random effects (IID or BYM2).")
  }

  if (!is.null(report$calibration) && report$calibration$rating %in% c("poor", "fair")) {
    diag <- report$calibration$diagnosis
    if (grepl("over-confident", diag)) {
      next_steps <- c(next_steps, "Predictions are over-confident (intervals too narrow): Likelihood is overly restrictive. Add structured spatial effects (BYM2) or loosen overly restrictive priors.")
    } else if (grepl("under-confident", diag)) {
      next_steps <- c(next_steps, "Predictions are under-confident (intervals too wide): Model may be overparameterized. Apply stronger shrinkage via Penalized Complexity (PC) priors.")
    }
  }

  if (length(next_steps) == 0) {
    next_steps <- c("All diagnostics and calibration checks pass standard thresholds. Proceed to posterior marginal interpretation and reporting.")
  }

  report$next_steps <- next_steps
  return(report)
}

# CLI Execution block
if (sys.nframe() == 0) {
  option_list <- list(
    make_option(c("--diagnostics"), type = "character", default = NULL, 
                help = "Path to diagnostics JSON (output of diagnose_model.R)"),
    make_option(c("--calibration"), type = "character", default = NULL, 
                help = "Path to calibration JSON (output of calibration_check.R)"),
    make_option(c("--comparison"), type = "character", default = NULL,
                help = "Optional path to model comparison JSON"),
    make_option(c("--sensitivity"), type = "character", default = NULL,
                help = "Optional path to sensitivity analysis JSON"),
    make_option(c("--output"), type = "character", default = NULL, 
                help = "Path to save full JSON report (default: print to stdout)")
  )

  opt_parser <- OptionParser(option_list = option_list)
  opt <- parse_args(opt_parser)

  if (is.null(opt$diagnostics)) {
    print_help(opt_parser)
    stop("Argument --diagnostics must be supplied.", call. = FALSE)
  }

  load_optional <- function(path) {
    if (is.null(path) || !file.exists(path)) return(NULL)
    tryCatch(fromJSON(path), error = function(e) NULL)
  }

  diagnostics <- load_optional(opt$diagnostics)
  if (is.null(diagnostics)) {
    cat(toJSON(list(error = paste("Could not load required diagnostics file:", opt$diagnostics)), auto_unbox = TRUE))
    quit(status = 1)
  }

  calibration <- load_optional(opt$calibration)
  comparison <- load_optional(opt$comparison)
  sensitivity <- load_optional(opt$sensitivity)

  report <- evaluate_inla_diagnostics(diagnostics, calibration, comparison, sensitivity)

  cat("=== Per-Section Assessment ===\n")
  for (sec in names(report$summary)) {
    cat(sprintf("  %s: %s\n", sec, report$summary[[sec]]))
  }
  cat("==============================\n\n")

  cat("=== Suggested Next Steps ===\n")
  for (i in seq_along(report$next_steps)) {
    cat(sprintf("  %d. %s\n", i, report$next_steps[i]))
  }
  cat("============================\n\n")

  json_out <- toJSON(report, auto_unbox = TRUE, pretty = TRUE)

  if (!is.null(opt$output)) {
    writeLines(json_out, opt$output)
    cat(paste("Report saved to", opt$output, "\n"))
  } else {
    cat(json_out, "\n")
  }
}
