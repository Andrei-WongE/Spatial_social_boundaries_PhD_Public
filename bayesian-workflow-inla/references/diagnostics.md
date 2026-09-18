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

Run this immediately after fitting. If any check fails, do NOT interpret results. INLA does NOT use MCMC, so R-hat, ESS, divergences, and trace plots do NOT apply. We use cross-validated predictive density and numerical stability checks instead.

```r
# After fitting:
# result <- inla(formula, family = "gaussian", data = df, 
#                control.compute = list(cpo = TRUE, dic = TRUE, waic = TRUE))

# 1. Check CPO failures (numerical stability check)
# Standard threshold: failure rate <= 1% is pass
fail_rate <- mean(result$cpo$failure > 0, na.rm = TRUE)
cat(sprintf("CPO failure rate: %.2f%% (Pass if <= 1.00%%)\n", fail_rate * 100))

# 2. PIT histogram (should be uniform for continuous data)
hist(result$cpo$pit, breaks = 20, main = "PIT Histogram", xlab = "PIT")

# 3. LCPO (lower is better; standard negative mean log-CPO)
LCPO <- -mean(log(result$cpo$cpo[result$cpo$cpo > 0]), na.rm = TRUE)
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

- For continuous data, a well-calibrated model has uniformly distributed PIT values on $(0, 1)$.
- Results in `result$cpo$pit`.
- A U-shaped PIT histogram indicates the predictive distribution is underdispersed (intervals too narrow).
- An inverted U-shaped histogram indicates the predictive distribution is overdispersed (intervals too wide).

## CPO Failure Vector & Thresholds

INLA calculates CPO and PIT using numerical integration approximations. If the approximation is unstable for a particular observation, INLA flags it in `result$cpo$failure`.

- **Pass / Excellent**: Failure rate $\le 1\%$ ($\le 0.01$)
- **Warning / Fair**: $1\% < \text{Failure rate} \le 5\%$
- **Fail / Poor**: Failure rate $> 5\%$ (Laplace approximation is unreliable)

## LCPO

Logarithmic Conditional Predictive Ordinate. Used for model comparison.

$$\text{LCPO} = -\frac{1}{n} \sum_{i=1}^n \log(\text{CPO}_i)$$

```r
LCPO <- -mean(log(result$cpo$cpo[result$cpo$cpo > 0]), na.rm = TRUE)
```
Lower LCPO values indicate superior predictive accuracy.

## When sampling fails: the escalation ladder

When INLA diagnostics show problems — high CPO failures, non-uniform PIT, or irregular marginals — escalate in this order:

1. **Check CPO failures.** If $> 1\%$, increase integration accuracy: `control.inla = list(int.strategy = "grid", diff.logdens = 4)`.
2. **Check PIT uniformity.** If non-uniform, change likelihood family (e.g. Poisson to Negative Binomial) or add observation/group random effects (`iid`).
3. **Check spatial graph integrity.** Run `validate_spatial_graph()` to catch disconnected spatial nodes.
4. **Check marginal posteriors.** If mass piles up at boundaries, adjust PC priors or inspect sum-to-zero constraints (`constr = TRUE`).
5. **Consider `inlabru`.** For non-linear observation processes or multi-likelihood models, use `inlabru`.
