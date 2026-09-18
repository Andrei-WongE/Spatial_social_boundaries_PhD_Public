---
name: bayesian-workflow-inla
description: >
  Opinionated spatial Bayesian modeling workflow with R-INLA. Contains critical guardrails
  (CPO/PIT calibration checks, PC priors, BYM2 spatial random effects, posterior marginals,
  DIC/WAIC/LCPO model comparison, targets pipelines) that agents won't apply unprompted — always
  consult before writing INLA model code. Trigger on: building spatial probabilistic models,
  INLA inference, convergence/diagnostic checks (CPO, PIT, DIC, WAIC, LCPO), spatial autoregression,
  BYM2 models, PC prior elicitation, targets pipeline creation, reporting Bayesian results,
  or mentions of R-INLA, spdep, sf, posterior marginals, uncertainty quantification.
license: MIT
metadata:
  author: "[Alexandre Andorra](https://alexandorra.github.io/) (Adapted for R-INLA by Agent)"
  version: "1.0.0"
---

# Bayesian Workflow with R-INLA

## Workflow overview

Every Bayesian analysis follows this sequence. Do not skip steps -- especially model criticism.

1. **Formulate** — Define the generative story. What underlying process created the data?
2. **Specify priors** — See [references/priors.md](references/priors.md). Use Penalized Complexity (PC) priors as the primary default.
3. **Implement in R-INLA** — Write the model using `inla()` formula syntax. Use `f()` for random effects and spatial components (`bym2`, `iid`). Validate spatial graph integrity via `validate_spatial_graph()`.
4. **Run prior predictive checks** — Simulate directly from prior distributions or use `scripts/check_prior_predictive.R` to verify priors produce plausible data ranges before fitting.
5. **Inference** — Fit the model via `inla()`, ensuring `control.compute = list(dic=TRUE, waic=TRUE, cpo=TRUE, config=TRUE)` and `control.predictor = list(compute=TRUE, link=1)`. INLA uses fast, deterministic Laplace approximations.
6. **Diagnose** — Check CPO failures (`result$cpo$failure <= 0.01`), PIT histogram uniformity, and inspect posterior marginals. (MCMC diagnostics like R-hat, ESS, and divergences do not apply).
7. **Criticize the model** — Check PIT calibration ECDF, evaluate CPO outliers, and run posterior predictive checks via `inla.posterior.sample()`.
8. **Check prior sensitivity** — Re-fit the model across a grid of PC prior hyperparameters (`pc.prec`, `pc.cor1`) and compare posterior marginals.
9. **Compare models** (if applicable) — Use DIC, WAIC, and LCPO ($\text{LCPO} = -\text{mean}(\log(\text{CPO}))$, where lower is better).
10. **Report results** — Generate `<slug>/report.md` using the canonical template. Produce standard report figures (`forest.png`, `pit_histogram.png`, `pit_ecdf.png`, `posterior_predictive.png`).

## Installation

```r
# Install R-INLA from the stable repository
install.packages("INLA", repos=c(getOption("repos"), INLA="https://inla.r-inla-download.org/R/stable"), dep=TRUE)

# Install spatial, data manipulation, and pipeline dependencies
install.packages(c("sf", "spdep", "ggplot2", "tidyverse", "tmap", "targets", "tarchetypes", "optparse", "jsonlite"))

# Optional high-level spatial modeling interface
install.packages("inlabru")
```

## Stack compatibility

R-INLA has stable and testing versions. Use the stable version unless a specific cutting-edge feature is required.
For complex spatial point process or domain-level predictive integration, `inlabru` provides a formula wrapper on top of INLA.

## R-INLA model template

```r
library(INLA)
library(sf)
library(spdep)

set.seed(sum(utf8ToInt("spatial-analysis-v1")))

# --- Formula specification ---
# Document WHY each prior/component was chosen
hyper_pc_prec <- list(prec = list(prior = "pc.prec", param = c(1, 0.01)))

formula <- y ~ 1 + x1 + x2 +
  f(area_id, model = "bym2", graph = "spatial.graph",
    scale.model = TRUE, constr = TRUE,
    hyper = list(
      prec = list(prior = "pc.prec", param = c(1, 0.01)),
      phi  = list(prior = "pc", param = c(0.5, 0.5))
    ))

# --- Inference ---
result <- inla(formula,
               family = "gaussian",
               data = df,
               control.compute = list(dic = TRUE, waic = TRUE, cpo = TRUE, config = TRUE),
               control.predictor = list(compute = TRUE, link = 1))

# --- Save immediately after fitting ---
saveRDS(result, "model_output.rds")

# --- Inspect summary ---
summary(result)
```

## Critical rules

- **Always run prior predictive checks** before inference using domain-bounded simulation.
- **Check convergence and approximation stability**. Verify that CPO failure rate is $\le 1\%$ (`result$cpo$failure <= 0.01`). Values $> 5\%$ indicate severe Laplace approximation instability.
- **Always run posterior predictive checks**. Use `inla.posterior.sample()` to draw from the joint posterior.
- **Always evaluate PIT calibration**. Check uniformity via Kolmogorov-Smirnov test and inspect PIT histogram and ECDF plots.
- **Document every prior choice**. Prefer Penalized Complexity (PC) priors (`pc.prec`, `pc.cor1`) over diffuse inverse-gamma priors.
- **Never report point estimates alone**. Extract posterior marginal summaries (mean, standard deviation, 95% CrI).
- **Use reproducible, descriptive seeds.** `set.seed(sum(utf8ToInt("analysis-slug")))`.
- **Save result objects immediately** with `saveRDS(result, "result.rds")`.
- **Ensure spatial graphs are connected**. Run `validate_spatial_graph()` before `spdep::nb2INLA()` to catch isolated areas.
- **Always set `scale.model = TRUE` and `constr = TRUE`** on BYM2 spatial random effects for parameter interpretability and identifiability.
- **For out-of-sample prediction, append rows with `y = NA`**. Set `control.predictor = list(compute = TRUE, link = 1)` to predict at unobserved locations.

## Common model families

| Problem | Data model | Typical priors | Reference |
|---|---|---|---|
| Continuous outcome | `family="gaussian"` | `pc.prec` on precision | [references/priors.md](references/priors.md) |
| Heavy-tailed continuous | `family="T"` (Student-t) | `pc.prec` on precision, `pc.dof` on df | [references/priors.md](references/priors.md) |
| Binary outcome | `family="binomial", Ntrials=1` | `control.fixed` on coefficients | [references/priors.md](references/priors.md) |
| Binomial aggregated | `family="binomial"` | PC priors on random effects | [references/priors.md](references/priors.md) |
| Count data | `family="poisson"` | `pc.prec` on random effects | [references/priors.md](references/priors.md) |
| Overdispersed count | `family="nbinomial"` / `nbinomial2` | `pc.prec` on overdispersion | [references/priors.md](references/priors.md) |
| Zero-inflated count | `family="zeroinflatedpoisson0"`/`1` | PC priors | [references/priors.md](references/priors.md) |
| Spatial disease mapping | BYM2 (`f(..., model="bym2")`) | `pc.prec` + `pc` mixing parameter | [references/hierarchical.md](references/hierarchical.md) |

## Utility scripts

```bash
# 1. Run prior predictive simulation
Rscript scripts/check_prior_predictive.R --family gaussian --save_plot --output_dir <slug>/

# 2. Run diagnostics (writes diagnostics.json)
Rscript scripts/diagnose_model.R --result <slug>/result.rds --output <slug>/diagnostics.json

# 3. Run calibration check (writes calibration.json, pit_histogram.png, pit_ecdf.png)
Rscript scripts/calibration_check.R --result <slug>/result.rds --output <slug>/calibration.json --save-plots --plot-dir <slug>/

# 4. Generate report figures (forest.png, posterior_predictive.png)
Rscript scripts/generate_report_figures.R --result <slug>/result.rds --y_data <data.rds> --output_dir <slug>/

# 5. Interpret ratings and suggest actionable next steps
Rscript scripts/check_diagnostics.R --diagnostics <slug>/diagnostics.json --calibration <slug>/calibration.json --output <slug>/check_report.json
```

## Common gotchas & troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| CPO failures (> 1% or severe > 5%) | Numerical instability in integration | Set `control.inla = list(int.strategy = "grid", diff.logdens = 4)` |
| PIT histogram U-shaped | Underdispersed model (intervals too narrow) | Switch to overdispersed family (`nbinomial`, `T`) or add IID/BYM2 random effect |
| PIT histogram inverse-U | Overdispersed model (intervals too wide) | Simplify random effects or tighten PC priors |
| Disconnected graph warning | Isolated spatial islands in polygon shapefile | Connect island nodes or model island units via separate IID effect |
| Spatial effect absorbs all variance | Missing structural covariates or scale.model=FALSE | Add covariates, ensure `scale.model=TRUE` on BYM2 |
| Posterior at boundary | Over-tight PC prior or unidentifiable variance | Relax prior baseline or inspect sum-to-zero constraints (`constr=TRUE`) |
