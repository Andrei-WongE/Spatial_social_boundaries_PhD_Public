# Convergence Diagnostics

## Contents
- Quick diagnostic checklist
- CPO (Conditional Predictive Ordinates)
- PIT (Probability Integral Transform)
- CPO failure vector
- Marginal posterior inspection
- LCPO
- The escalation ladder

## Quick diagnostic checklist

Run these checks after fitting and investigate problems before relying on affected summaries. INLA does NOT use MCMC, so R-hat, ESS, divergences, and trace plots do NOT apply. We use cross-validated predictive density and numerical stability checks instead.

```r
# After fitting:
# result <- inla(formula, family = "gaussian", data = df, 
#                control.compute = list(cpo = TRUE, dic = TRUE, waic = TRUE))

# 1. Check CPO failures (numerical stability check)
# A positive flag identifies a CPO/PIT approximation to investigate
fail_rate <- mean(result$cpo$failure > 0, na.rm = TRUE)
cat(sprintf("CPO values flagged: %.2f%%\n", fail_rate * 100))

# 2. PIT histogram (should be uniform for continuous data)
hist(result$cpo$pit, breaks = 20, main = "PIT Histogram", xlab = "PIT")

# 3. LCPO (lower is better; standard negative mean log-CPO)
cpo <- result$cpo$cpo
LCPO <- if (length(cpo) && all(is.finite(cpo) & cpo > 0)) -mean(log(cpo)) else NA_real_
# Investigate missing or nonpositive CPO values before comparing scores.
cat("LCPO:", round(LCPO, 4), "\n")

# 4. Inspect marginal posteriors for key parameters (check for boundary effects or multimodality)
plot(result$marginals.fixed[["x1"]], type = "l", main = "Posterior of x1")
```

## CPO (Conditional Predictive Ordinates) & Spatial Group CV

CPO is the cross-validated predictive density: the leave-one-out probability $p(y_i \mid y_{-i})$.

- Computed via `control.compute = list(cpo = TRUE)`
- Results in `result$cpo$cpo`

### Spatial Leave-Group-Out Cross-Validation (LGOCV)
For spatial data with strong spatial autocorrelation, standard leave-one-out CPO can be overly optimistic due to nearby spatial dependence. Consider **Leave-Group-Out Cross-Validation (LGOCV)** using `inla.group.cv()`:

```r
# Define spatial groups (e.g. cluster IDs or spatial blocks)
# cv_res <- inla.group.cv(result, groups = spatial_group_list)
# Mean log-score across spatial test folds:
# mean_ls <- -mean(log(cv_res$cv))
```

## PIT (Probability Integral Transform)

PIT is a calibration check measuring $P(Y_i \le y_i \mid y_{-i})$.

- For continuous outcomes, a calibrated leave-one-out predictive distribution has approximately uniform PIT values. Dependence between areas affects formal test calibration. For counts and other discrete outcomes, the ordinary PIT is not continuously uniform; consider a randomized PIT $F_i(y_i^-)+U_i[F_i(y_i)-F_i(y_i^-)]$, where $U_i\sim\mathrm{Uniform}(0,1)$. [Dunn & Smyth (1996)](https://doi.org/10.1080/10618600.1996.10474708).
- Results in `result$cpo$pit`.
- A U-shaped PIT histogram indicates the predictive distribution is underdispersed (intervals too narrow).
- An inverted U-shaped histogram indicates the predictive distribution is overdispersed (intervals too wide).

## CPO Failure Vector & Thresholds

INLA calculates CPO and PIT using numerical integration approximations. If the approximation is unstable for a particular observation, INLA flags it in `result$cpo$failure`.

Inspect every positive flag, its magnitude, and the affected CPO/PIT value. The proportion flagged is descriptive, not an academic pass/fail cutoff. Recompute questionable values with `inla.cpo(result)` or explicit leave-one-out refits, especially when extreme CPO values drive a log score. [R-INLA FAQ](https://www.r-inla.org/faq).

## LCPO

Logarithmic Conditional Predictive Ordinate. Used for model comparison.

$$\text{LCPO} = -\frac{1}{n} \sum_{i=1}^n \log(\text{CPO}_i)$$

```r
cpo <- result$cpo$cpo
LCPO <- if (length(cpo) && all(is.finite(cpo) & cpo > 0)) -mean(log(cpo)) else NA_real_
# Investigate missing or nonpositive CPO values before comparing scores.
```
Lower LCPO values indicate superior predictive accuracy.

## When diagnostics flag issues

When INLA diagnostics show problems — high CPO failures, non-uniform PIT, or irregular marginals — escalate in this order:

1. **Check CPO flags and tails.** Recompute flagged or extreme CPO/PIT values with `inla.cpo(result)` or held-out refits. If needed, examine integration settings such as `control.inla = list(int.strategy = "grid", diff.logdens = 4)`. The flag alone does not assess every posterior quantity.
2. **Check predictive calibration.** Account for discrete outcomes and spatial dependence; use predictive replication to diagnose the pattern before changing a likelihood or random effects.
3. **Check spatial graph integrity.** Run `validate_spatial_graph()` to catch disconnected spatial nodes.
4. **Check marginal posteriors.** If mass piles up at boundaries, adjust PC priors or inspect sum-to-zero constraints (`constr = TRUE`).
5. **Consider `inlabru`.** For non-linear observation processes or multi-likelihood models, use `inlabru`.
