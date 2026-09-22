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

## When to Use

Apply this skill whenever building, fitting, criticizing, or reporting on spatial and hierarchical Bayesian models using R-INLA:
- Specifying areal disease mapping or spatial econometric models (e.g., Besag-York-Mollié / BYM2, ICAR, or IID random effects).
- Performing fast approximate Bayesian inference for Latent Gaussian Models (LGMs) where MCMC is computationally prohibitive.
- Formulating weakly informative or informative Penalized Complexity (PC) priors (`pc.prec`, `pc.cor1`, `pc.range`) for variance and spatial mixing parameters.
- Validating spatial graph contiguity and topology before constructing precision matrices (`spdep::poly2nb()`, `spdep::nb2INLA()`).
- Assessing numerical approximation stability via Conditional Predictive Ordinates (CPO) and Probability Integral Transform (PIT) calibration checks.
- Conducting Bayesian model comparison using Deviance Information Criterion (DIC), Watanabe-Akaike Information Criterion (WAIC), and Logarithmic Conditional Predictive Ordinates (LCPO).
- Producing standardized analysis reports (`<slug>/report.md`) with reproducible diagnostic figures (`forest.png`, `pit_histogram.png`, `pit_ecdf.png`, `posterior_predictive.png`).

## When NOT to Use

Do not use this skill for:
- Non-spatial Python-based Bayesian modeling workflows with PyMC, Stan, or ArviZ (use `bayesian-workflow` instead).
- Continuous-time survival processes or complex joint models where Stan/MCMC or custom Gibbs sampling is strictly mandated.
- Purely algorithmic, non-probabilistic boundary detection or spatial clustering (use algorithmic Wombling or spatial edge detection scripts directly).
- Frequentist spatial regressions (e.g., standard maximum likelihood spatial lag/error via `spatialreg` or spatial 2SLS) unless explicitly comparing against a Bayesian spatial specification.

## Workflow overview

Every Bayesian analysis follows this sequence. Do not skip steps -- especially model criticism.

1. **Formulate** — Define the generative story. What underlying process created the data?
2. **Specify priors** — See [references/priors.md](references/priors.md). Use Penalized Complexity (PC) priors as the primary default.
3. **Implement in R-INLA** — Write the model using `inla()` formula syntax. Use `f()` for random effects and spatial components (`bym2`, `iid`). Validate spatial graph integrity via `validate_spatial_graph()`.
4. **Run prior predictive checks** — Simulate from the actual analysis priors, covariates, offsets/trials, and likelihood. `scripts/check_prior_predictive.R` is only a simple one-predictor illustration and cannot validate a fitted model without adaptation.
5. **Inference** — Fit the model via `inla()`, ensuring `control.compute = list(dic=TRUE, waic=TRUE, cpo=TRUE, config=TRUE)` and `control.predictor = list(compute=TRUE, link=1)`. INLA uses fast, deterministic Laplace approximations.
6. **Diagnose** — Inspect every positive `result$cpo$failure` flag, verify influential or very small CPO values, and inspect posterior marginals. For PIT, distinguish continuous from discrete outcomes and account for spatial dependence; MCMC diagnostics do not apply.
7. **Criticize the model** — Evaluate CPO outliers and PIT in its sampling context. Draw posterior parameters with `inla.posterior.sample()`, then simulate *outcomes* through the observation likelihood for posterior predictive checks.
8. **Check prior sensitivity** — Re-fit the model across a grid of PC prior hyperparameters (`pc.prec`, `pc.cor1`) and compare posterior marginals.
9. **Compare models** (if applicable) — Use DIC, WAIC, and LCPO ($\text{LCPO} = -\text{mean}(\log(\text{CPO}))$, where lower is better).
10. **Report results** — Generate `<slug>/report.md` using the canonical template. Plot prior and posterior predictions, CPO flags, and PIT as appropriate to the likelihood. Use `scripts/check_diagnostics.R` to collect findings for review; its output does not certify model validity.

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
- **Inspect CPO approximation flags**. A positive `result$cpo$failure[i]` flags an observation for investigation; it is not a failure-rate pass/fail rule. Consider `inla.cpo(result)` or explicit held-out refits for flagged and extreme CPO values. [R-INLA FAQ](https://www.r-inla.org/faq).
- **Run posterior predictive checks**. Draw from the joint posterior and then simulate replicated observations from the fitted likelihood; a plot of `Predictor` draws alone is not a posterior predictive check. [Gelman et al.](https://doi.org/10.48550/arXiv.2011.01808).
- **Evaluate PIT in context**. Standard PIT uniformity applies to continuous predictive distributions. For discrete outcomes, use a randomized PIT or another suitable diagnostic; spatial dependence also affects formal uniformity tests. [Dunn & Smyth (1996)](https://doi.org/10.1080/10618600.1996.10474708).
- **Document every prior choice**. Prefer Penalized Complexity (PC) priors (`pc.prec`, `pc.cor1`) over diffuse inverse-gamma priors.
- **Never report point estimates alone**. Extract posterior marginal summaries (mean, standard deviation, 95% CrI).
- **Use reproducible, descriptive seeds.** `set.seed(sum(utf8ToInt("analysis-slug")))`.
- **Save result objects immediately** with `saveRDS(result, "result.rds")`.
- **Inspect connected components and singletons**. Run `validate_spatial_graph()` and use component-aware constraints and scaling where needed. Do not create artificial edges solely to make a graph connected. [Morris et al. (2019)](https://doi.org/10.1016/j.sste.2019.100301).
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

Run these in order — each script's output feeds the next:

```bash
# 1. Illustrative prior simulation; adapt priors, covariates, offsets/trials and likelihood to the actual model.
Rscript scripts/check_prior_predictive.R --family gaussian --save_plot --output_dir <slug>/

# 2. Run diagnostics (writes diagnostics.json)
Rscript scripts/diagnose_model.R --result <slug>/result.rds --output <slug>/diagnostics.json

# 3. Descriptive ordinary PIT plots; assess outcome type and spatial dependence before interpretation.
Rscript scripts/calibration_check.R --result <slug>/result.rds --output <slug>/calibration.json --save-plots --plot-dir <slug>/

# 4. Generate forest.png. For a posterior predictive figure, also supply observed outcomes
#    and an RDS matrix of replicated outcomes simulated from the fitted likelihood.
Rscript scripts/generate_report_figures.R --result <slug>/result.rds --output_dir <slug>/
Rscript scripts/generate_report_figures.R --result <slug>/result.rds --y_data <data.rds> --y_rep <replicates.rds> --output_dir <slug>/

# 5. Interpret ratings and suggest actionable next steps
Rscript scripts/check_diagnostics.R --diagnostics <slug>/diagnostics.json --calibration <slug>/calibration.json --output <slug>/check_report.json
```

Step 5 gathers diagnostics for interpretation. Assess them against the model, likelihood, sampling design, prediction target, and costs of an error; the script cannot make that judgment automatically.

## Common gotchas & troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Positive CPO flags or extreme log scores | Possible approximation or tail problem | Inspect affected observations; try `inla.cpo(result)` or held-out refits, then consider integration settings |
| Continuous PIT histogram U-shaped | Possible underdispersion | Check predictions against observations and investigate likelihood, covariates, and dependence |
| Continuous PIT histogram inverse-U | Possible overdispersion | Check outcome scale and predictive replication before revising the model |
| Disconnected graph warning | Genuine separate components or data topology error | Verify geography and ordering; set component-aware constraints/scaling and handle singletons explicitly |
| Spatial effect absorbs all variance | Missing structural covariates or scale.model=FALSE | Add covariates, ensure `scale.model=TRUE` on BYM2 |
| Posterior at boundary | Over-tight PC prior or unidentifiable variance | Relax prior baseline or inspect sum-to-zero constraints (`constr=TRUE`) |
