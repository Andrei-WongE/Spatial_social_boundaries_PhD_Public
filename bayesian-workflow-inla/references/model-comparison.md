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

Fit all candidate models with criteria computation enabled:

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
    -mean(log(x$cpo$cpo[x$cpo$cpo > 0]), na.rm = TRUE)
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

- **WAIC / DIC**: Lower is better. $\Delta \text{WAIC} > 4$ or $\Delta \text{DIC} > 5$ indicates meaningful empirical support.
- **LCPO** ($-\frac{1}{n} \sum \log(\text{CPO}_i)$): Lower is better. Measures cross-validated leave-one-out predictive error.
- **Effective parameters ($p_{\text{eff}}$)**: Quantifies model complexity. If $p_{\text{eff}}$ approaches the total number of observations $N$, the random effect may be overparameterized.
- **CPO Failure Check**: If a model has a CPO failure rate $> 1\%$, its WAIC and LCPO approximations should be treated with caution.

## Reporting comparison tables

Include DIC, WAIC, LCPO, and effective parameter counts in `<slug>/report.md`:

```markdown
## Model comparison

| Model | WAIC | ΔWAIC | DIC | ΔDIC | LCPO | p.eff (WAIC) | CPO Failures |
|-------|------|-------|-----|------|------|--------------|--------------|
| Spatial BYM2 | 312.4 | 0.0 | 311.8 | 0.0 | 1.12 | 18.4 | 0 (0.0%) |
| Base IID | 338.1 | +25.7 | 337.5 | +25.7 | 1.34 | 12.1 | 0 (0.0%) |

The Spatial BYM2 model is substantially preferred (ΔWAIC = 25.7, LCPO improvement of 0.22). Spatial autocorrelation is strongly supported by the data.
```
