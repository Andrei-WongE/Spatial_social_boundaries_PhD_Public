#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
})

#' Collect Diagnostic Findings and Review Steps
#'
#' @param diagnostics A list parsed from diagnose_model.R JSON
#' @param calibration An optional list parsed from calibration_check.R JSON
#' @param model_comparison An optional list of model comparison metrics (DIC/WAIC/LCPO)
#' @param sensitivity An optional list of prior sensitivity metrics
#' @return A descriptive findings list requiring model-specific interpretation
evaluate_inla_diagnostics <- function(diagnostics, calibration = NULL, model_comparison = NULL, sensitivity = NULL) {
  n_flags <- diagnostics$cpo$n_failures
  if (is.null(n_flags)) n_flags <- NA_integer_
  report <- list(
    cpo = list(n_flags = n_flags, failure_rate = diagnostics$cpo$failure_rate),
    pit = diagnostics$pit,
    calibration = if (!is.null(calibration)) calibration$assessment else NULL,
    model_comparison = model_comparison,
    sensitivity = sensitivity,
    next_steps = c(
      "Inspect positive CPO flags and extreme log scores; use inla.cpo() or held-out refits where needed.",
      "Interpret ordinary PIT plots only for continuous outcomes and account for spatial dependence; use randomized PIT for discrete outcomes.",
      "Compare posterior predictive replicated outcomes with observed data for the intended scientific question."
    )
  )
  report
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

  cat("CPO flags:", report$cpo$n_flags, "\n")
  cat("Review the JSON findings and context-specific next steps.\n")

  json_out <- toJSON(report, auto_unbox = TRUE, pretty = TRUE)

  if (!is.null(opt$output)) {
    writeLines(json_out, opt$output)
    cat(paste("Report saved to", opt$output, "\n"))
  } else {
    cat(json_out, "\n")
  }
}
