# Spatial_social_boundaries_PhD_Public
Public repository of PhD spatial data pipeline. Result of refactoring entire PhD project using use {targets} + {tarchetypes} + Duck DB spatial for large spatial data operations + spatial Bayesian dissimilarity and Bayesian INLA/Inlabru areal data modelling.

This project studies ethnic boundaries and food-purchase outcomes across London LSOAs. `_targets.R` orchestrates the analysis with **targets** and **tarchetypes**. Functions live in `R/`, source data in `Data/`, and analysis outputs in `results/`.

## Pipeline

1. Register Census, geographic, accessibility, POI and Tesco Grocery 1.0 source files.
2. Prepare London data and validate coverage, geometry and ethnic proportions.
3. Estimate canonical (Model 1), CARBayes/Leroux (Model 2) and locally adaptive CARBayes (Model 3) boundaries; produce classifications, ethnic-specific maps and area summaries.
4. Construct food-environment measures and master tables.
5. Select and transform predictors and outcomes.
6. Fit frequentist models and assess spatial dependence, shared samples, weights and spatial impacts.
7. Fit INLA BYM2 outcome models and export prior, predictive and numerical diagnostics.
8. Evaluate threshold, graph/control and exposure-uncertainty sensitivity and collect validation outputs.

Additionally, script 'run_reports.R' triggers basic reporting and diagnostic checks using outputs in 'results' folder. Script does not run if 'tar_outdated()' results in outdated targets in pipeline. 

## Documentation

- `.posit/Master_review_plan.md` coordinates `.posit/pipeline_review.md` and `.posit/Pipeline_Regression_Review.md`.
- `TARGETS_REFACTOR_LOG.md` records changes, validation and open issues.
- `AGENTS.md` begins with current guidance; older entries are historical records.
