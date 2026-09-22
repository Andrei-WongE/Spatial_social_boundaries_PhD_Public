# Prior Selection Guide

## Contents
- Philosophy: why priors matter
- Penalized Complexity (PC) priors (the default)
- Prior families by parameter type
- Sparsity and variable selection
- Prior predictive checking workflow
- Common mistakes

## Philosophy: why priors matter

Priors encode domain knowledge and constrain the model to plausible regions of parameter space. The goal is NOT to be "non-informative" — it is to be **honestly informative** while avoiding undue influence on the posterior when data is sufficient.

Every prior should have a justification. If you cannot articulate why a prior is reasonable, it is not a good prior.

## Penalized Complexity (PC) priors (the default)

When in doubt, use Penalized Complexity (PC) priors. These place most mass on a simpler base model (e.g., no random effect, zero variance) while still allowing the data to pull the parameter away from the base model if necessary. 

**Principle**: A good PC prior shrinks towards a natural baseline and requires explicit evidence to move away from it.

Here are some general rules of thumb in R-INLA:

### Regression coefficients (Fixed effects)

```r
# INLA's default for fixed effects is a Normal prior with mean 0 and precision 0.001.
# If you standardize predictors first, you can use a stronger prior.
# Set via control.fixed in the standard inla() call:
control.fixed = list(
  mean = 0, 
  prec = 1 / 2.5^2  # Precision is 1/variance
)

# For intercepts specifically, center on observed data mean when possible:
control.fixed = list(
  mean.intercept = mean(y),
  prec.intercept = 1 / (2 * sd(y))^2
)

# Note for inlabru users: inlabru's bru() overrides control.fixed.
# Specify priors directly inside components:
# comp = ~ Intercept(1, mean.linear = 0, prec.linear = 1/5^2) + x(main = x, model = "linear", prec.linear = 1/2.5^2)
```

### Scale parameters (standard deviations / precisions)

```r
# PC prior for precision parameters: pc.prec
# P(sigma > u) = alpha
# E.g., prior probability that standard deviation is greater than 1 is 0.01:
hyper_pc_prec <- list(
  prec = list(prior = "pc.prec", param = c(1, 0.01))
)

# Use in a random effect:
# f(id, model = "iid", hyper = hyper_pc_prec)
```

### Correlation matrices (hierarchical models)

Unlike LKJ priors in PyMC/Stan, R-INLA does not directly sample dense correlation matrices. Instead, for correlated random effects, use `model="iid2d"` or `model="iid3d"` with Wishart-type priors, or copy mechanisms for specific correlation structures.

```r
# Correlated 2D random effects (e.g., varying intercept and slope)
# Uses a Wishart prior for the precision matrix by default
# f(id, covariate, model="iid2d", n=2)
```

## Prior families by parameter type

| Parameter type | Recommended prior in INLA | Why |
|---|---|---|
| Location (unbounded) | Normal (via `control.fixed`) | Symmetric, well-understood |
| Scale / SD / Precision | `pc.prec` | Shrinks towards zero variance (base model) |
| Spatial effects (BYM2) | `pc.prec` + graph-specific `pc` for mixing | Controls overall scale and shrinks the structured contribution toward its base model |
| Autoregressive (AR1) | `pc.cor1` | Shrinks towards independent observations |
| Degrees of freedom | `pc.dof` | Shrinks towards infinite df (Normal distribution) |

## Sparsity and variable selection

When you have many features and expect only a subset to be relevant, note that INLA does NOT natively support Horseshoe or R2-D2 spike-and-slab priors. 

### When to use sparsity priors

| Situation | Prior recommendation |
|-----------|---------------------|
| Few features (< ~10) | Normal(0, σ) via `control.fixed` |
| Smooth shrinkage / time-series | `f(x, model="rw1")` or `f(x, model="ar1")` |
| True variable selection | `inla.posterior.sample()` + Posterior Inclusion Probability |

Instead of sparse priors, in INLA we often use smooth shrinkage models (like random walks) or perform post-hoc variable selection by sampling from the joint posterior.

```r
# Posterior effect relevance, given a prespecified substantive threshold.
# Requires control.compute = list(config = TRUE) in the fit.
samples <- inla.posterior.sample(1000, result)

# inla.posterior.sample.eval evaluates expressions directly across the sample realizations
beta_samples <- inla.posterior.sample.eval(function(...) predictor_x, samples)
threshold <- 0.05
prob_relevant <- mean(abs(beta_samples) > threshold)
```

## Prior predictive checking workflow

This is mandatory. Never skip it. In R, simulate from the prior distributions directly.

```r
# Example prior predictive check in R
N <- 1000
# Simulate priors for intercept and slope
alpha <- rnorm(N, mean = 0, sd = 2.5)
beta <- rnorm(N, mean = 0, sd = 2.5)

# Simulate covariate X
X <- rnorm(N, 0, 1)

# Generate linear predictor
eta <- alpha + beta * X

# Generate observed data (e.g., Poisson count)
y_prior_pred <- rpois(N, lambda = exp(eta))

# Visualize
hist(y_prior_pred, breaks = 50, main = "Prior Predictive Distribution")

# Check: do simulated datasets look plausible?
# - Are values in a reasonable range?
# - Is the spread of outcomes reasonable?
```

**Assessment**: Compare simulated outcomes and relevant summaries with substantive constraints. Revise priors when their implied data conflict with those constraints; there is no general 10% cutoff. Very narrow predictions may also be inappropriate. Document the judgment and examine the sensitivity of conclusions. [Gelman et al. (2020)](https://doi.org/10.48550/arXiv.2011.01808).

## Common mistakes

1. **Flat / diffuse priors**: These are NOT "non-informative". They place excessive mass on extreme, implausible values. Use weakly informative or PC priors instead.
2. **Ignoring scale**: A precision of 0.001 means very different things depending on the scale of the data. Always consider the units.
3. **Forgetting to standardize predictors**: Without standardization, coefficients live on different scales, making shared priors inappropriate.
4. **No prior predictive check**: The single most common source of modeling errors. Always visualize what your priors imply before fitting.
5. **Using a diffuse Gamma precision prior without checking its implications**: `Gamma(1e-3, 1e-3)` induces a heavy-tailed prior on variance, whose impact depends on the likelihood and scale. Compare defensible priors, including a calibrated `pc.prec` where suitable, through prior predictions and sensitivity analysis. [Simpson et al. (2017)](https://doi.org/10.1214/16-STS576).
