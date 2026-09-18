# Spatial_social_boundaries_PhD_Public
Public repository of PhD spatial data pipeline, processes approximately 20 hours. Result of refactoring entire PhD project using use {targets} + {tarchetypes} + Duck DB spatial for large spatial data operations + spatial Bayesian dissimilarity and Bayesian INLA/Inlabru areal data modelling.

This project studies ethnic boundaries and food-purchase outcomes spatial variability across London LSOAs. `_targets.R` orchestrates the analysis with **targets** and **tarchetypes**. Functions live in `R/`, source data in `Data/`, and analysis outputs in `results/`.

## Pipeline

A) Main pipeline:

1. Register Census, boundary geography, POI and Tesco Grocery 1.0 source files.
2. Prepare London data and validate coverage, geometry and ethnic proportions.
3. Estimate canonical (Model 1), CARBayes/Leroux (Model 2) and locally adaptive CARBayes (Model 3) boundaries; produce classifications, ethnic-specific maps and area summaries.
4. Construct food-environment measures and master tables.
5. Select and transform predictors and outcomes.
6. Fit frequentist models and assess spatial dependence, weights and non-spatial and spatial impacts.
7. Fit INLA BYM2 outcome models and export prior, predictive and numerical diagnostics.
8. Evaluate threshold, graph/control and exposure-uncertainty sensitivity and collect validation outputs.

B) Diagnostic and Reporting:
Additionally, script `run_reports.R` triggers basic reporting and diagnostic checks using outputs in `results` folder. Script does not run if `tar_outdated()` results in outdated targets in pipeline. 

C) Diagnostic and Refitting 
Finally the following refitting sequence is implemented:

validate numerical LOO → inspect variance allocation → elicit and test one prior component at a time → run spatial holdouts → consider likelihood or mean-structure changes → reassess coefficients

This sequence follows iterative predictive criticism rather than tuning priors to obtain uniform PIT or significant boundary effects.

## Documentation

- `.posit/Master_review_plan.md` coordinates `.posit/pipeline_review.md` and `.posit/Pipeline_Regression_Review.md`.
- `TARGETS_REFACTOR_LOG.md` records changes, validation and open issues; older entries are historical records.
- `AGENTS.md` begins with current project guidance.

## Technical references

### Bayesian workflow and model criticism

- Gabry, J., Simpson, D., Vehtari, A., Betancourt, M., and Gelman, A. (2019). [Visualization in Bayesian workflow](https://sites.stat.columbia.edu/gelman/research/published/bayes-vis.pdf).

- Agresti, A., Kateri, M., Grove, W., and Mira, A. (2026). *Foundations of Bayesian Statistics for Data Scientists*. 

- Lynch, S. M. (2007). *Introduction to Applied Bayesian Statistics and Estimation for Social Scientists*. 

- [Bayesian model diagnostics notes](https://bookdown.org/marklhc/notes_bookdown/model-diagnostics.html).

- [bayesplot documentation](https://cran.r-project.org/web/packages/bayesplot/bayesplot.pdf).

- [Bayesian workflow with R-INLA](https://github.com/).

### R-INLA and spatial Bayesian modelling

- Bakka, H., Rue, H., Fuglstad, G.-A., et al. (2018). [Spatial modeling with R-INLA: A review](https://arxiv.org/abs/1802.06350).

- Rue, H., Riebler, A., Sørbye, S. H., Illian, J. B., Simpson, D. P., and Lindgren, F. K. (2017). *Bayesian Computing with INLA: A Review*. 

- [R-INLA documentation](https://www.r-inla.org/).

- [R-INLA documentation and manuals](https://www.r-inla.org/doc/inla).

- [INLA BYM2 latent model documentation](https://www.inla.r-inla-download.org/r-inla.org/doc/latent/bym2.pdf).

- [INLA PC prior for precision](https://inla.r-inla-download.org/r-inla.org/doc/prior/pc.prec.pdf).

- [INLA posterior sampling documentation](https://www.r-inla.org/learnmore/docs/reference/posterior.sample.html).

- [INLA predictor-control documentation](https://www.r-inla.org/learnmore/docs/reference/control.predictor.html).

- [INLA group cross-validation guidance](https://www.inla.r-inla-download.org/r-inla.org/doc/vignettes/AA-group-cv.html).

### Penalized Complexity priors

- Simpson, D., Rue, H., Riebler, A., Martins, T. G., and Sørbye, S. H. (2017). [Penalising model component complexity: A principled, practical approach to constructing priors](https://doi.org/10.1214/16-STS576).

- [INLA PC precision prior documentation](https://inla.r-inla-download.org/r-inla.org/doc/prior/pc.prec.pdf).

### CARBayes and spatial boundary modelling

- Lee, D. (2013). [CARBayes: An R package for Bayesian spatial modeling with conditional autoregressive models](https://www.jstatsoft.org/article/view/v055i13).

- Lee, D., and Mitchell, R. (2012). [Boundary detection in disease mapping studies](https://arxiv.org/abs/1108.1879).

- Lu, H., and Carlin, B. P. (2005). [Bayesian areal wombling for geographical boundary analysis](https://doi.org/10.1111/j.1538-4632.2005.00624.x).

- Lawson, A. B. (2021). *Using R for Bayesian Spatial and Spatio-Temporal Health Modeling*. 

- [Social-frontier modelling supplement](C:/Users/Andre/Zotero/storage/Y9XUWXI4/tesg12316-supp-0001-suppinfo1.docx).

### Boundary and multiple-testing methods

- Li, P., et al. (2012). [False discovery rate control for spatial boundary detection](https://intlpress.com/site/pub/files/_fulltext/journals/sii/2012/0005/0002/SII-2012-0005-0002-a001.pdf).

### INLA diagnostic tools

- [inlatools documentation](https://inbo.github.io/inlatools/).

- [inlatools function reference](https://inbo.r-universe.dev/inlatools/reference/).

- [inlatools distribution-checking vignette](https://inbo.github.io/inlatools/articles/distribution.html).

- [inlatools distribution documentation](https://inlatools.netlify.app/articles/distribution).

- [inlatools manual PDF](https://inbo.r-universe.dev/inlatools/doc/manual.pdf).

### Data sources

- Aiello, L. M., Schifanella, R., Quercia, D., and Del Prete, L. (2020). [Large-scale and high-resolution analysis of food purchases in London](https://doi.org/10.1038/s41597-020-0397-7).

- Broadbridge, T. [Food deserts and geographically weighted regression replication repository](https://github.com/taylabroadbridge/paper-fooddeserts-gwr.git).

- ONS Census, 2011

- Points of Interest Data. Data Creator/Publisher: Ordnance Survey & PointX. © Crown copyright and database right [2015]. Contains PointX database right [2015]. 

- ONS Digital Vector Boundaries for Lower layer Super Output Areas (December 2011) Boundaries EW BFC (V3). [The BFC boundaries are full resolution - clipped to the coastline (Mean High Water mark)](https://geoportal.statistics.gov.uk/datasets/ons::lower-layer-super-output-areas-december-2011-boundaries-ew-bfc-v3/about)

### Project-specific guidance

- [`bayesian-workflow-inla` skill](bayesian-workflow-inla) adapted skill from [An opinionated Agent Skill for building, diagnosing, and reporting on Bayesian statistical models using PyMC and ArviZ.](https://github.com/Learning-Bayesian-Statistics/baygent-skills/tree/main/bayesian-workflow).
- Gemini NotebookLM with technical documentation of [`targets package`](https://books.ropensci.org/targets/) and [`tarchetypes package`](https://docs.ropensci.org/tarchetypes/) for efficient consulting of targets and computational configuration of pipeline.
- Posit AI assistant as refactoring orchestrator and validator of workflow based on code and results of [7 scripts PhD static workflow](https://github.com/Andrei-WongE/Social_boundaries_LAC).
- My brain (novel approach in this nascent IA era), 3 years of training in spatial econometrics, Bayesian statistics and data management. See [my page](https://andrei-wonge.github.io/Andrei-Wong.github.io/) for theoretical and methodological underpinning of this workflow.


