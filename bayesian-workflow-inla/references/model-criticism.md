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

Simulate data from the fitted model and compare to observed data. In INLA, we use `inla.posterior.sample()` to generate replicated datasets.

# 1. Sample from the joint posterior (requires control.compute = list(config = TRUE))
samples <- inla.posterior.sample(n = 100, result)

# 2. Extract linear predictor realizations using modern inla.posterior.sample.eval
# Automatically maps Predictor variables across sample draws
eta_samples <- inla.posterior.sample.eval(function(...) Predictor, samples)

# For a Gaussian model, extract hyperparameter precision:
prec_samples <- inla.posterior.sample.eval(function(...) theta[1], samples)
sigma_samples <- 1 / sqrt(prec_samples)

y_rep <- matrix(nrow = nrow(eta_samples), ncol = ncol(eta_samples))
for(i in 1:ncol(eta_samples)) {
  y_rep[, i] <- rnorm(nrow(eta_samples), mean = eta_samples[, i], sd = sigma_samples[i])
}

# 3. Visualize using ggplot2 or scripts/generate_report_figures.R
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
- `result$cpo$failure`: Count observations where `failure > 0`. If the failure rate exceeds 1%, investigate potential outliers or high-leverage points.

## Calibration assessment

Calibration is mandatory for every model. A well-calibrated model's $X\%$ credible intervals should contain the true value approximately $X\%$ of the time.

### PIT histograms & ECDFs

If the model is calibrated, PIT values should follow a uniform distribution on $(0, 1)$.

```r
# Generate plots via scripts/calibration_check.R
# Histograms:
# - U-shaped -> underdispersed (intervals too narrow, predictions too certain)
# - Inverted-U -> overdispersed (intervals too wide, predictions too uncertain)
# - Uniform -> well-calibrated
```

## Simulation-Based Calibration (SBC) in R-INLA

While INLA fits each single model deterministically and quickly (often seconds compared to minutes in MCMC), running an ensemble of $K = 500$ to $1000$ simulation iterations still requires noticeable aggregate runtime and should be treated as an off-line pipeline step.

```r
# SBC Template Loop
run_inla_sbc <- function(N = 100, K = 500) {
  ranks <- numeric(K)
  for (k in 1:K) {
    # 1. Draw prior parameters
    true_beta <- rnorm(1, 0, 1)
    true_prec <- rgamma(1, shape = 1, rate = 1)
    true_sd <- 1 / sqrt(true_prec)
    
    # 2. Simulate synthetic data
    x <- rnorm(N)
    y_sim <- rnorm(N, mean = true_beta * x, sd = true_sd)
    df_k <- data.frame(y = y_sim, x = x)
    
    # 3. Fit INLA model
    res_k <- inla(y ~ 1 + x, data = df_k, family = "gaussian")
    
    # 4. Compute posterior rank of true_beta
    post_samples <- inla.posterior.sample(100, res_k)
    beta_post <- sapply(post_samples, function(s) s$latent["x:1", 1])
    ranks[k] <- sum(beta_post < true_beta)
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
1. CPO Failures / Numerical Stability OK? (Failure rate <= 1%)
   NO  -> Increase integration accuracy (int.strategy='grid', diff.logdens=4).
   YES |
       v
2. Posterior predictive check pass?
   NO  -> Revise likelihood family or link function.
   YES |
       v
3. Calibration OK? (PIT histogram uniform, |Delta| <= 0.02)
   NO  -> Model is miscalibrated; add random effects (BYM2/IID).
   YES |
       v
4. Spatial residual autocorrelation remaining?
   YES -> Add spatial random effect f(id, model='bym2') or spatial lag.
   NO  |
       v
-> Model is ready for interpretation and reporting.
```
