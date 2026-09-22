# Model Comparison

## Contents
- When to compare models
- DIC, WAIC, and LCPO
- Reporting comparisons

## When to compare models

Compare models when you have genuinely different modeling assumptions — not for rote subset selection. Bayesian model comparison answers: "Which model predicts unseen data better, balancing goodness-of-fit with parsimony?"

Common comparison scenarios:
- Non-spatial vs. Spatial hierarchical structure (IID vs. BYM2)
- Linear vs. smooth nonlinear effect (`f(x, model="rw2")`)
- Standard vs. overdispersed likelihood (`poisson` vs. `nbinomial`)

## Information criteria in R-INLA

Fit all candidate models on the same observations with criteria computation enabled:

```r
# control.compute = list(dic = TRUE, waic = TRUE, cpo = TRUE)

models <- list(
  "Base IID" = res_base,
  "Spatial BYM2" = res_bym2
)

comparison_df <- data.frame(
  Model = names(models),
  DIC = sapply(models, function(x) x$dic$dic),
  p_eff_DIC = sapply(models, function(x) x$dic$p.eff),
  WAIC = sapply(models, function(x) x$waic$waic),
  p_eff_WAIC = sapply(models, function(x) {
    if (!is.null(x$waic$p.eff)) x$waic$p.eff else x$waic$p.eff.waic
  }),
  LCPO = sapply(models, function(x) {
    cpo <- x$cpo$cpo
    if (length(cpo) && all(is.finite(cpo) & cpo > 0)) -mean(log(cpo)) else NA_real_
  }),
  CPO_Failures = sapply(models, function(x) {
    sum(x$cpo$failure > 0, na.rm = TRUE)
  })
)

# Compute deltas relative to best model
comparison_df$Delta_WAIC <- comparison_df$WAIC - min(comparison_df$WAIC)
comparison_df$Delta_DIC <- comparison_df$DIC - min(comparison_df$DIC)
```

### Interpretation criteria

- **WAIC / DIC**: Lower is better for the same data and likelihood target. Compare differences with their uncertainty and the intended prediction task; fixed 4/5 cutoffs do not establish substantive support. [Vehtari et al. (2017)](https://doi.org/10.1007/s11222-016-9696-4).
- **LCPO** ($-\frac{1}{n} \sum \log(\text{CPO}_i)$): Lower is better. Measures cross-validated leave-one-out predictive error.
- **Effective parameters ($p_{\text{eff}}$)**: Quantifies model complexity. If $p_{\text{eff}}$ approaches the total number of observations $N$, the random effect may be overparameterized.
- **CPO flags**: Inspect and, where needed, recompute positive CPO flags and influential log-score contributions before using LCPO. CPO flags do not by themselves validate or invalidate WAIC.

## Reporting comparison tables

Include DIC, WAIC, LCPO, and effective parameter counts in `<slug>/report.md`:

```markdown
## Model comparison

| Model | WAIC | ΔWAIC | DIC | ΔDIC | LCPO | p.eff (WAIC) | CPO Failures |
|-------|------|-------|-----|------|------|--------------|--------------|
| Spatial BYM2 | 312.4 | 0.0 | 311.8 | 0.0 | 1.12 | 18.4 | 0 (0.0%) |
| Base IID | 338.1 | +25.7 | 337.5 | +25.7 | 1.34 | 12.1 | 0 (0.0%) |

For this illustration, BYM2 has the lower scores. Assess uncertainty in score differences, spatial validation design, and residual structure before drawing a substantive conclusion.
```
