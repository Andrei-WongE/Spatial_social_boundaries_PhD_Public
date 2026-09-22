# Reporting Bayesian Analyses

## Contents
- Canonical report artifact (`<slug>/report.md`)
- Reporting principles
- Presentation template
- Visualization standards
- Common reporting mistakes

## Canonical report artifact

After every full analysis run, generate `report.md` inside a dedicated results folder.

### Results folder naming

All artifacts for a single analysis go into `<slug>/`, where `<slug>` is a short lowercase-hyphenated descriptor of the analysis.

```r
results_dir <- "<slug>"  # e.g., "spatial-disease-model"
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)
```

### Output structure

```
<slug>/
├── result.rds                   # Full INLA result object
├── model_graph.png              # DAG visualization (e.g. via dagitty/ggdag or diagrams)
├── prior_predictive.png         # Prior predictive check distribution
├── pit_histogram.png            # PIT calibration histogram
├── pit_ecdf.png                 # PIT empirical cumulative distribution plot
├── forest.png                   # Forest plot of posterior estimates & 95% CrI
├── posterior_predictive.png     # Posterior predictive check overlay plot
├── summary_fixed.csv            # result$summary.fixed saved as CSV
├── summary_random.csv           # result$summary.random saved as CSV (if applicable)
├── diagnostics.json             # CPO/DIC/WAIC output from diagnose_model.R
├── calibration.json             # Calibration output from calibration_check.R
└── report.md                    # Structured report artifact
```

### Figure naming convention

Save figures using these exact names using `ggplot2` and `ggsave()` (or via `scripts/generate_report_figures.R` and `scripts/calibration_check.R`):

- `prior_predictive.png`
- `pit_histogram.png`
- `pit_ecdf.png`
- `forest.png`
- `posterior_predictive.png`
- `model_graph.png`

### Report template

Copy this template into `<slug>/report.md` and fill in the placeholders:

````markdown
# <Analysis Title> — Bayesian Analysis Report

## Executive Summary

<2–3 sentences summarizing the key finding with credible intervals and the most important caveat. Lead with the substantive conclusion, not the model. If the audience is non-technical, translate to intuitive probabilities.>

## Data and Question

| | |
|---|---|
| Source | <where the data came from> |
| Sample size | <N> |
| Spatial units | <Count and type of spatial areas, e.g. 150 London wards> |
| Key variables | <comma-separated list with brief descriptions> |
| Question | <one-sentence statement of what we want to learn> |

<Brief description of any notable features: missingness, outliers, spatial boundary structure, or transformations.>

## Model Specification

![Model graph](model_graph.png)

**Generative story.** <1–3 sentences describing the assumed data-generating process.>

| Parameter | Prior / Model | Justification |
|-----------|---------------|---------------|
| Fixed effects ($\beta$) | `control.fixed = list(prec = 1/2.5^2)` | Weakly informative on standardized covariates |
| Spatial variance ($\sigma_s$) | `pc.prec(u = 1, alpha = 0.01)` | Penalized Complexity prior shrinking to zero variance |
| BYM2 mixing ($\phi$) | `pc(u = 0.5, alpha = 0.5)` | Graph-specific prior controlling the structured contribution; not an exact variance fraction at each area |

## Prior Predictive Check

![Prior predictive](prior_predictive.png)

**Assessment:** <1–3 sentences — do prior predictive samples span the plausible domain range without extreme boundary mass?>

## Model Fit & Diagnostics

| Diagnostic | Value | Interpretation | Action |
|------------|-------|----------------|--------|
| Positive CPO flags | <count and proportion> | Approximation flags, no universal cutoff | <inspect / recompute affected values> |
| LCPO ($-\overline{\log \text{CPO}}$) | <e.g., 1.42> | Lower is better | — |
| DIC | <e.g., 450.2> | Lower is better | — |
| WAIC | <e.g., 452.1> | Lower is better | — |

![PIT Histogram](pit_histogram.png)
![PIT ECDF](pit_ecdf.png)

**Assessment:** <Describe flagged CPO values, any recomputation, and whether PIT is appropriate for the outcome type and spatial dependence.>

## Posterior Estimates

![Forest](forest.png)

| Parameter | Mean | SD | 95% Credible Interval |
|-----------|------|----|-----------------------|
| <param_1> | <m> | <s> | [<lo>, <hi>] |

**Substantive interpretation.** <2–4 sentences on what the posteriors mean in domain terms — effect sizes in natural units.>

## Posterior Predictive Check

![Posterior predictive](posterior_predictive.png)

Generate this figure only from replicated *outcomes* drawn through the fitted likelihood (for example, provide `--y_rep` to the figure script).

**Assessment:** <1–3 sentences — does the posterior predictive envelop the observed data? Any systematic residual clustering?>

## [IF MODEL_COMPARISON] Model Comparison

| Model | WAIC | $\Delta$WAIC | DIC | $\Delta$DIC | LCPO |
|-------|------|--------------|-----|-------------|------|
| Base Model | <waic_1> | 0.0 | <dic_1> | 0.0 | <lcpo_1> |
| Spatial BYM2 Model | <waic_2> | <diff> | <dic_2> | <diff> | <lcpo_2> |

**Assessment:** <Which model is favored by predictive criteria and parsimony.>

## [IF SENSITIVITY] Prior Sensitivity

**Assessment:** <Sensitivity sweep results across tight/moderate/loose PC prior hyperparameter specifications.>

## Limitations and Threats

1. <threat 1: e.g. unmeasured spatial confounding>
2. <threat 2: e.g. edge effect / modifiable areal unit problem>

## Suggested Next Steps

1. <step 1>
2. <step 2>
````
