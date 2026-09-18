# Main entrypoint for Bayesian Workflow with R-INLA

# Export core helper functions to the global environment
source("scripts/diagnose_model.R")
source("scripts/calibration_check.R")
source("scripts/check_diagnostics.R")
source("scripts/check_prior_predictive.R")
source("scripts/generate_report_figures.R")
source("scripts/validate_spatial_graph.R")

message("bayesianWorkflowInla skill loaded successfully.")
message("Available functions:")
message("  - diagnose_inla_model(result)")
message("  - assess_inla_calibration(result, save_plots, plot_dir)")
message("  - evaluate_inla_diagnostics(diagnostics, calibration, comparison, sensitivity)")
message("  - check_prior_predictive(n_sim, family, beta_mean, beta_sd, save_plot, output_dir)")
message("  - generate_inla_report_figures(result, y_obs, output_dir, n_samples)")
message("  - validate_spatial_graph(spatial_obj, graph_out)")
