# Model Criticism

Model criticism answers: "Is this model any good?" Convergence diagnostics only tell you the approximation worked -- they say nothing about whether the model is appropriate for the data.

## Contents
- Posterior predictive checks (PPC)
- Cross-validation (CPO/PIT)
- Calibration assessment
- Simulation-Based Calibration (SBC)
- Residual analysis
- Decision workflow

## Posterior predictive checks (PPC)

Simulate data from the fitted model and compare with observed data. `inla.posterior.sample()` draws latent predictors and parameters; replicated outcomes require an additional draw from the fitted observation likelihood for each posterior draw. [Gelman et al. (2020)](https://doi.org/10.48550/arXiv.2011.01808).

```r
# 1. Sample from the approximate joint posterior (requires config = TRUE)
samples <- inla.posterior.sample(n = 100, result)

# 2. Extract linear predictor realizations using modern inla.posterior.sample.eval
# Automatically maps Predictor variables across sample draws
eta_samples <- inla.posterior.sample.eval(function(...) Predictor, samples)

# 3. Simulate y_rep from the exact fitted likelihood using each sampled
#    predictor, link, and likelihood hyperparameter. For example, Poisson
#    log-link counts with known offsets E_i require:
# y_rep[, i] <- rpois(nrow(eta_samples), lambda = E * exp(eta_samples[, i]))
#    Gaussian sampling needs the sampled observation precision, not an
#    arbitrary entry of theta; binomial sampling needs each Ntrials value.
# 4. Pass the resulting outcome-scale matrix to scripts/generate_report_figures.R.
```
```

**What to look for**:
- Replications should envelop the observed empirical density.
- Check skewness, zero-inflation, and tail coverage.

## Cross-validation (CPO/PIT)

INLA computes leave-one-out cross-validation approximations via Conditional Predictive Ordinates (CPO).

```r
# CPO is computed natively if requested
# control.compute = list(cpo = TRUE)
summary(result$cpo$cpo)
```

**Key checks**:
- `result$cpo$failure`: Inspect observations where `failure > 0`, and recompute questionable or extreme CPO values. No universal 1% pass/fail rule is established. [R-INLA FAQ](https://www.r-inla.org/faq).

## Calibration assessment

Calibration is mandatory for every model. A well-calibrated model's $X\%$ credible intervals should contain the true value approximately $X\%$ of the time.

### PIT histograms & ECDFs

Uniform PIT applies directly to continuous predictive distributions. Count outcomes require a randomized PIT or another suitable diagnostic; spatial dependence affects simple uniformity tests. [Dunn & Smyth (1996)](https://doi.org/10.1080/10618600.1996.10474708).

```r
# Generate plots via scripts/calibration_check.R
# Histograms:
# - U-shaped -> underdispersed (intervals too narrow, predictions too certain)
# - Inverted-U -> overdispersed (intervals too wide, predictions too uncertain)
# - Uniform -> well-calibrated
```

## Simulation-Based Calibration (SBC) in R-INLA

Simulation-Based Calibration (SBC; Talts et al., 2018; Modrák et al., 2023; Gelman et al., 2020) can reveal inference problems when simulations and fitted priors/likelihoods match: prior distributions, data generation mechanisms, Laplace approximation modes, and analysis scripts. Synthetic data are simulated iteratively from the prior, the model is fit via INLA, and posterior rank statistics of the true parameters are verified for uniformity (using Kolmogorov-Smirnov or chi-squared goodness-of-fit tests).

INLA draws here come from an approximate posterior. The example below uses the same coefficient prior and observation variance in simulation and fitting. Repeated fits have substantial aggregate cost, and SBC results apply to this specific setup. [R-INLA posterior sampling documentation](https://www.r-inla.org/learnmore/docs/reference/posterior.sample.html).


```r
# SBC Template Loop
run_inla_sbc <- function(N = 100, K = 500) {
  ranks <- numeric(K)
  for (k in 1:K) {
    # 1. Draw prior parameters
    true_beta <- rnorm(1, 0, 1)
    # Match the fitted model: known observation variance 1.
    
    # 2. Simulate synthetic data
    x <- rnorm(N)
    y_sim <- rnorm(N, mean = true_beta * x, sd = 1)
    df_k <- data.frame(y = y_sim, x = x)
    
    # 3. Fit INLA model
    res_k <- inla(y ~ 0 + x, data = df_k, family = "gaussian",
                  control.fixed = list(mean = 0, prec = 1),
                  control.family = list(hyper = list(
                    prec = list(initial = 0, fixed = TRUE))),
                  control.compute = list(config = TRUE))

    # 4. Rank against approximate joint-posterior draws of the coefficient.
    draws <- inla.posterior.sample(100, res_k)
    beta_post <- inla.posterior.sample.eval(function(...) x, draws)
    ranks[k] <- sum(as.numeric(beta_post) < true_beta)
  }
  return(ranks)
}
```

## Residual analysis

For regression and spatial models, check spatial residuals for remaining autocorrelation:

```r
fitted_vals <- result$summary.fitted.values$mean
residuals <- y - fitted_vals

# Test residual spatial autocorrelation with Moran's I
# spdep::moran.test(residuals, listw_obj)
```

## Decision workflow

```
1. Positive CPO flags or extreme log scores?
   YES -> Inspect affected observations; recompute CPO with inla.cpo() or held-out refits.
   YES |
       v
2. Posterior predictive check pass?
   NO  -> Revise likelihood family or link function.
   YES |
       v
3. Predictive calibration appropriate to outcome type and dependence?
   NO  -> Diagnose the pattern with replicated data before changing the model.
   YES |
       v
4. Spatial residual autocorrelation remaining?
   YES -> Add spatial random effect f(id, model='bym2') or spatial lag.
   NO  |
       v
-> Interpret with the remaining approximation, validation, and scientific limitations recorded.
```
