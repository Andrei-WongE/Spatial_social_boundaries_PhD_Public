#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
})

#' Diagnose INLA Model Fit
#'
#' Summarizes CPO flags, LCPO and ordinary PIT values without universal pass/fail cutoffs,
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
      lcpo <- if (length(cpo_vals) && all(is.finite(cpo_vals) & cpo_vals > 0)) -mean(log(cpo_vals)) else NA_real_
    }
    
  }

  report$cpo <- list(
    lcpo = lcpo,
    failure_rate = cpo_failure_rate,
    n_failures = n_failures,
    n_severe_failures = n_severe_failures
  )

  # Ordinary PIT values are descriptive here. Uniformity tests require a
  # continuous predictive distribution and a justified dependence structure.
  pit_vals <- if (!is.null(result$cpo)) result$cpo$pit else NULL
  pit_vals <- pit_vals[is.finite(pit_vals)]
  report$pit <- list(
    n_values = length(pit_vals),
    mean = if (length(pit_vals)) mean(pit_vals) else NA_real_,
    note = "Ordinary PIT: interpret only for continuous outcomes; consider randomized PIT for discrete outcomes and account for dependence."
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

  # No automatic pass/fail conclusion follows from a flag proportion or PIT plot.
  report$overall <- list(
    n_cpo_flags = n_failures,
    recommendation = "Inspect positive CPO flags and extreme log scores; recompute questionable values with inla.cpo() or held-out refits. Interpret PIT in light of outcome type and spatial dependence."
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
