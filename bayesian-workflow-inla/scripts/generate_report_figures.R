#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(ggplot2)
})

#' Generate Standard Report Figures for INLA Workflow
#'
#' Generates forest.png (posterior coefficients) and posterior_predictive.png (PPC replication check)
#'
#' @param result An INLA result object (loaded from .rds)
#' @param y_obs Vector of observed outcomes
#' @param output_dir Output directory path
#' @param n_samples Number of posterior samples for PPC
generate_inla_report_figures <- function(result, y_obs = NULL, output_dir = ".", n_samples = 100) {
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

  # 2. Posterior Predictive Check Plot
  if (!is.null(y_obs) && is.numeric(y_obs)) {
    tryCatch({
      suppressMessages({
        samples <- INLA::inla.posterior.sample(n = n_samples, result)
      })
      
      # Extract linear predictors via inla.posterior.sample.eval
      eta_samples <- tryCatch({
        INLA::inla.posterior.sample.eval(function(...) Predictor, samples)
      }, error = function(e) {
        # Fallback to matrix indexing if eval fails
        eta_idx <- grep("^Predictor", rownames(samples[[1]]$latent))
        sapply(samples, function(s) s$latent[eta_idx])
      })
      
      if (!is.null(eta_samples) && nrow(eta_samples) == length(y_obs)) {
        # Plot density of observed vs simulated replicates
        df_obs <- data.frame(y = y_obs, type = "Observed")
        
        p_ppc <- ggplot() +
          geom_density(data = df_obs, aes(x = y), color = "black", linewidth = 1.2)
        
        # Add sample densities
        for (i in 1:min(30, n_samples)) {
          df_rep <- data.frame(y = eta_samples[, i])
          p_ppc <- p_ppc + geom_density(data = df_rep, aes(x = y), color = "steelblue", alpha = 0.15, linewidth = 0.4)
        }
        
        p_ppc <- p_ppc +
          theme_minimal() +
          labs(title = "Posterior Predictive Check",
               subtitle = "Black: Observed data | Blue: Posterior replicated latent distributions",
               x = "Outcome Value", y = "Density")
        
        ppc_path <- file.path(output_dir, "posterior_predictive.png")
        ggsave(ppc_path, p_ppc, width = 7, height = 5, dpi = 300)
        saved_files$posterior_predictive <- ppc_path
      }
    }, error = function(e) {
      warning(paste("Could not generate posterior predictive plot:", e$message))
    })
  }

  return(saved_files)
}

if (sys.nframe() == 0) {
  option_list <- list(
    make_option(c("--result"), type = "character", default = NULL, 
                help = "Path to INLA result (.rds file)"),
    make_option(c("--y_data"), type = "character", default = NULL, 
                help = "Optional path to RDS or CSV containing observed vector y"),
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
  
  figs <- generate_inla_report_figures(res_obj, y_obs = y_obs, output_dir = opt$output_dir)
  cat(paste("Generated figures:\n", paste(names(figs), unlist(figs), sep = ": ", collapse = "\n"), "\n"))
}
