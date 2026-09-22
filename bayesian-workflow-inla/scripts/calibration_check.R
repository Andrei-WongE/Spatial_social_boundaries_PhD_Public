#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

#' Assess INLA Model Calibration
#'
#' Summarizes ordinary PIT values and optionally plots their histogram and ECDF.
#' Uniformity requires a continuous outcome; dependence affects formal tests.
#'
#' @param result An INLA result object (loaded from .rds)
#' @param save_plots Logical; whether to save plot artifacts
#' @param plot_dir Path to output directory for plots
#' @return A named list representing calibration metrics
assess_inla_calibration <- function(result, save_plots = FALSE, plot_dir = ".") {
  if (is.null(result$cpo) || is.null(result$cpo$pit)) {
    stop("No PIT values found in INLA result. Ensure control.compute = list(cpo = TRUE) was enabled when running inla().")
  }

  pit_vals <- result$cpo$pit
  pit_vals <- pit_vals[is.finite(pit_vals) & pit_vals >= 0 & pit_vals <= 1]

  if (length(pit_vals) == 0) {
    stop("No valid PIT values found after filtering missing/extreme entries.")
  }

  # An ordinary PIT ECDF is descriptive. Its departure from the diagonal
  # is not empirical interval coverage, especially for discrete outcomes.
  empirical <- ecdf(pit_vals)
  report <- list(
    n_observations = length(pit_vals),
    assessment = list(
      mean_pit = mean(pit_vals),
      max_abs_ecdf_difference = max(abs(empirical(pit_vals) - pit_vals)),
      note = "Descriptive ordinary PIT only; no universal calibration threshold. Use randomized PIT for discrete outcomes and account for spatial dependence."
    )
  )

  if (save_plots) {
    if (!dir.exists(plot_dir)) dir.create(plot_dir, recursive = TRUE)
    
    # 1. PIT Histogram
    p_hist <- ggplot(data.frame(pit = pit_vals), aes(x = pit)) +
      geom_histogram(aes(y = after_stat(density)), bins = 20, fill = "skyblue", color = "black", alpha = 0.7) +
      geom_hline(yintercept = 1, linetype = "dashed", color = "firebrick", linewidth = 0.8) +
      theme_minimal() +
      labs(title = "PIT Calibration Histogram", subtitle = "Reference line: continuous uniform distribution", x = "PIT Value", y = "Density")
    
    hist_path <- file.path(plot_dir, "pit_histogram.png")
    ggsave(hist_path, p_hist, width = 6, height = 4, dpi = 300)
    
    # 2. PIT ECDF
    p_ecdf <- ggplot(data.frame(pit = pit_vals), aes(x = pit)) +
      stat_ecdf(geom = "step", color = "navy", linewidth = 0.8) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "firebrick", linewidth = 0.8) +
      theme_minimal() +
      labs(title = "PIT Empirical Cumulative Distribution", subtitle = "Reference line: continuous uniform CDF", x = "Theoretical Uniform Quantiles", y = "Empirical Probability")
    
    ecdf_path <- file.path(plot_dir, "pit_ecdf.png")
    ggsave(ecdf_path, p_ecdf, width = 6, height = 4, dpi = 300)
    
    report$plots <- list(
      pit_histogram = hist_path,
      pit_ecdf = ecdf_path
    )
  }

  return(report)
}

# CLI Execution block
if (sys.nframe() == 0) {
  option_list <- list(
    make_option(c("--result"), type = "character", default = NULL, 
                help = "Path to INLA result (.rds file)", metavar = "character"),
    make_option(c("--output"), type = "character", default = NULL, 
                help = "Path to save JSON report", metavar = "character"),
    make_option(c("--save-plots"), action = "store_true", default = FALSE, 
                help = "Save calibration plots (pit_histogram.png, pit_ecdf.png)"),
    make_option(c("--plot-dir"), type = "character", default = ".", 
                help = "Directory for saved plots (default: .)", metavar = "character")
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

  tryCatch({
    report <- assess_inla_calibration(
      result, 
      save_plots = opt$`save-plots`, 
      plot_dir = opt$`plot-dir`
    )
    json_out <- toJSON(report, auto_unbox = TRUE, pretty = TRUE)

    if (!is.null(opt$output)) {
      writeLines(json_out, opt$output)
      cat(paste("Report saved to", opt$output, "\n"))
    } else {
      cat(json_out, "\n")
    }
  }, error = function(e) {
    cat(toJSON(list(error = e$message), auto_unbox = TRUE))
    quit(status = 1)
  })
}
