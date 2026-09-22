#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(ggplot2)
})

#' Generate Standard Report Figures for INLA Workflow
#'
#' Generates forest.png and, when observed and replicated outcomes are supplied, posterior_predictive.png
#'
#' @param result An INLA result object (loaded from .rds)
#' @param y_obs Vector of observed outcomes
#' @param output_dir Output directory path
#' @param y_rep Numeric matrix of replicated outcomes; rows match y_obs, columns are draws
generate_inla_report_figures <- function(result, y_obs = NULL, y_rep = NULL, output_dir = ".") {
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
  saved_files <- list()

  # 1. Forest Plot of Fixed Effects
  if (!is.null(result$summary.fixed) && nrow(result$summary.fixed) > 0) {
    df_fixed <- as.data.frame(result$summary.fixed)
    df_fixed$param <- rownames(df_fixed)
    
    # Identify 95% credible interval columns
    low_col <- grep("0.025quant", colnames(df_fixed), value = TRUE)[1]
    high_col <- grep("0.975quant", colnames(df_fixed), value = TRUE)[1]
    if (is.na(low_col)) low_col <- "0.025quant"
    if (is.na(high_col)) high_col <- "0.975quant"

    df_fixed$lower <- df_fixed[[low_col]]
    df_fixed$upper <- df_fixed[[high_col]]

    p_forest <- ggplot(df_fixed, aes(x = mean, y = param)) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
      geom_errorbarh(aes(xmin = lower, xmax = upper), height = 0.2, color = "midnightblue", linewidth = 0.8) +
      geom_point(color = "firebrick", size = 2.5) +
      theme_minimal() +
      labs(title = "Posterior Estimates & 95% Credible Intervals", 
           x = "Estimate (Posterior Mean & 95% CrI)", y = "Parameter")

    forest_path <- file.path(output_dir, "forest.png")
    ggsave(forest_path, p_forest, width = 7, height = 5, dpi = 300)
    saved_files$forest <- forest_path
  }

  # 2. Posterior predictive outcomes must already have been simulated
  # through the fitted likelihood, including offsets/trials and hyperparameters.
  if (!is.null(y_rep)) {
    if (is.null(y_obs) || !is.numeric(y_obs) || !is.matrix(y_rep) ||
        !is.numeric(y_rep) || nrow(y_rep) != length(y_obs) || ncol(y_rep) < 1) {
      stop("Supply numeric y_obs and a numeric y_rep matrix with one row per observation and one column per posterior draw.")
    }
    if (any(!is.finite(y_obs)) || any(!is.finite(y_rep))) {
      stop("Observed and replicated outcomes must be finite; remove missing observations consistently before plotting.")
    }
    p_ppc <- ggplot() +
      stat_ecdf(data = data.frame(y = y_obs), aes(x = y),
                geom = "step", color = "black", linewidth = 1.1)
    for (i in seq_len(min(30L, ncol(y_rep)))) {
      p_ppc <- p_ppc + stat_ecdf(
        data = data.frame(y = y_rep[, i]), aes(x = y),
        geom = "step", color = "steelblue", alpha = 0.2, linewidth = 0.4)
    }
    p_ppc <- p_ppc + theme_minimal() +
      labs(title = "Posterior Predictive Check",
           subtitle = "Black: observed outcomes | Blue: replicated outcomes",
           x = "Outcome value", y = "Cumulative probability")
    ppc_path <- file.path(output_dir, "posterior_predictive.png")
    ggsave(ppc_path, p_ppc, width = 7, height = 5, dpi = 300)
    saved_files$posterior_predictive <- ppc_path
  }

  return(saved_files)
}

if (sys.nframe() == 0) {
  option_list <- list(
    make_option(c("--result"), type = "character", default = NULL, 
                help = "Path to INLA result (.rds file)"),
    make_option(c("--y_data"), type = "character", default = NULL, 
                help = "Optional path to RDS or CSV containing observed vector y"),
    make_option(c("--y_rep"), type = "character", default = NULL,
                help = "RDS matrix of replicated outcomes from the fitted likelihood"),
    make_option(c("--output_dir"), type = "character", default = ".", 
                help = "Directory to save output figures")
  )
  
  opt_parser <- OptionParser(option_list = option_list)
  opt <- parse_args(opt_parser)
  
  if (is.null(opt$result)) {
    print_help(opt_parser)
    stop("Argument --result is required.", call. = FALSE)
  }
  
  res_obj <- readRDS(opt$result)
  y_obs <- NULL
  if (!is.null(opt$y_data) && file.exists(opt$y_data)) {
    if (grepl("\\.rds$", opt$y_data, ignore.case = TRUE)) {
      y_obs <- readRDS(opt$y_data)
    } else {
      y_df <- read.csv(opt$y_data)
      y_obs <- y_df[[1]]
    }
  }
  
  y_rep <- if (!is.null(opt$y_rep)) readRDS(opt$y_rep) else NULL
  figs <- generate_inla_report_figures(res_obj, y_obs = y_obs, y_rep = y_rep, output_dir = opt$output_dir)
  cat(paste("Generated figures:\n", paste(names(figs), unlist(figs), sep = ": ", collapse = "\n"), "\n"))
}
