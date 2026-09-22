#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(optparse)
  library(jsonlite)
  library(ggplot2)
})

#' Run Prior Predictive Simulation Check
#'
#' Illustrative one-predictor simulation. Replace its priors and design with the actual analysis model before using it as a prior check.
#'
#' @param n_sim Number of prior simulation draws
#' @param family Likelihood family ("gaussian", "poisson", "binomial")
#' @param save_plot Logical; whether to save plot
#' @param output_dir Output directory path
#' @return A summary list of prior predictive quantiles
check_prior_predictive <- function(n_sim = 1000, 
                                   family = "gaussian", 
                                   beta_mean = 0, 
                                   beta_sd = 2.5, 
                                   intercept_mean = 0, 
                                   intercept_sd = 5, 
                                   save_plot = FALSE, 
                                   output_dir = ".") {
  # Simulate prior draws
  alpha_draws <- rnorm(n_sim, mean = intercept_mean, sd = intercept_sd)
  beta_draws <- rnorm(n_sim, mean = beta_mean, sd = beta_sd)
  
  # Standard simulated predictor X in [-2, 2]
  x_seq <- seq(-2, 2, length.out = 100)
  
  # Compute linear predictor grid
  eta_matrix <- matrix(NA, nrow = n_sim, ncol = length(x_seq))
  for (i in 1:n_sim) {
    eta_matrix[i, ] <- alpha_draws[i] + beta_draws[i] * x_seq
  }
  
  # Generate outcome draws based on family
  if (family == "gaussian") {
    sigma_draws <- rexp(n_sim, rate = -log(0.01)) # P(sigma > 1) = 0.01 in this illustration
    y_sim <- rnorm(n_sim * 100, mean = as.vector(eta_matrix), sd = rep(sigma_draws, 100))
  } else if (family == "poisson") {
    rates <- exp(as.vector(eta_matrix))
    if (any(!is.finite(rates))) stop("Non-finite Poisson rates under illustrated priors; revise the prior, not the draws.")
    y_sim <- rpois(n_sim * 100, lambda = rates)
  } else if (family == "binomial") {
    prob <- 1 / (1 + exp(-as.vector(eta_matrix)))
    y_sim <- rbinom(n_sim * 100, size = 1, prob = prob)
  } else {
    stop(paste("Unsupported family:", family))
  }
  
  quantiles <- quantile(y_sim, probs = c(0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99), na.rm = TRUE)
  
  res <- list(
    family = family,
    n_sim = n_sim,
    quantiles = as.list(quantiles),
    plausible = NULL,
    note = "Illustrative prior simulation only; plausibility requires domain judgment and matching the actual model."
  )
  
  if (save_plot) {
    if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
    df_plot <- data.frame(y = y_sim[is.finite(y_sim)])
    
    p <- ggplot(df_plot, aes(x = y)) +
      geom_histogram(bins = 40, fill = "darkseagreen", color = "black", alpha = 0.7) +
      theme_minimal() +
      labs(title = "Prior Predictive Distribution", 
           subtitle = paste("Family:", family, "| Prior Beta ~ N(", beta_mean, ",", beta_sd, ")"),
           x = "Simulated Prior Outcome (Y)", y = "Frequency")
    
    plot_path <- file.path(output_dir, "prior_predictive.png")
    ggsave(plot_path, p, width = 6, height = 4, dpi = 300)
    res$plot_path <- plot_path
  }
  
  return(res)
}

if (sys.nframe() == 0) {
  option_list <- list(
    make_option(c("--family"), type = "character", default = "gaussian", 
                help = "Likelihood family (gaussian, poisson, binomial)"),
    make_option(c("--n_sim"), type = "integer", default = 1000, 
                help = "Number of simulation iterations"),
    make_option(c("--beta_sd"), type = "double", default = 2.5, 
                help = "Prior standard deviation for fixed effect coefficients"),
    make_option(c("--output_dir"), type = "character", default = ".", 
                help = "Directory to save prior_predictive.png and JSON summary"),
    make_option(c("--save_plot"), action = "store_true", default = FALSE, 
                help = "Save prior predictive plot")
  )
  
  opt_parser <- OptionParser(option_list = option_list)
  opt <- parse_args(opt_parser)
  
  res <- check_prior_predictive(
    n_sim = opt$n_sim, 
    family = opt$family, 
    beta_sd = opt$beta_sd, 
    save_plot = opt$save_plot, 
    output_dir = opt$output_dir
  )
  
  json_out <- toJSON(res, auto_unbox = TRUE, pretty = TRUE)
  if (!dir.exists(opt$output_dir)) dir.create(opt$output_dir, recursive = TRUE)
  json_file <- file.path(opt$output_dir, "prior_predictive_summary.json")
  writeLines(json_out, json_file)
  cat(paste("Prior predictive summary saved to", json_file, "\n"))
}
