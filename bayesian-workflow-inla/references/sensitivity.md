# Prior/Likelihood Sensitivity Analysis

Unlike MCMC software (like PyMC/ArviZ) which uses Pareto-smoothed importance sampling for power-scaling sensitivity analysis, INLA is fast enough that we can explicitly refit the model across a grid of prior specifications.

## Contents
- Manual sensitivity sweep
- Interpreting results
- Which variables to check
- Key principle

## Manual sensitivity sweep

To check whether your posterior conclusions are robust to reasonable changes in prior strength, refit the model with stronger or weaker PC priors and compare the resulting marginal posteriors.

```r
# Define a grid of PC prior hyperparameters for a standard deviation
# Format: param = c(u, alpha) meaning P(sigma > u) = alpha
prior_grid <- list(
  tight = list(prec = list(prior = "pc.prec", param = c(0.1, 0.01))),
  moderate = list(prec = list(prior = "pc.prec", param = c(1, 0.01))),
  loose = list(prec = list(prior = "pc.prec", param = c(10, 0.01)))
)

# Refit the model across the grid
results <- lapply(prior_grid, function(hp) {
  formula <- y ~ 1 + x + f(id, model="iid", hyper=hp)
  inla(formula, family="gaussian", data=df,
       control.compute=list(dic=TRUE, waic=TRUE, cpo=TRUE))
})

# Compare posterior marginals for a fixed effect
library(ggplot2)
marg_tight <- as.data.frame(results$tight$marginals.fixed[["x"]])
marg_tight$Prior <- "Tight"
marg_mod <- as.data.frame(results$moderate$marginals.fixed[["x"]])
marg_mod$Prior <- "Moderate"
marg_loose <- as.data.frame(results$loose$marginals.fixed[["x"]])
marg_loose$Prior <- "Loose"

all_margs <- rbind(marg_tight, marg_mod, marg_loose)

ggplot(all_margs, aes(x = x, y = y, color = Prior)) +
  geom_line(linewidth = 1) +
  theme_minimal() +
  labs(title = "Sensitivity of Fixed Effect 'x'", x = "Coefficient", y = "Density")
```

## Interpreting results

Four diagnostic patterns:

| Pattern | What it means | What to do |
|---------|---------------|------------|
| **Posteriors overlap perfectly** | Posterior is robust to prior changes | Nothing — this is the ideal outcome |
| **Posterior shifts significantly with prior** | Prior and data pull in different directions, or data is weak | Investigate whether the prior reflects genuine domain knowledge. |
| **Tight prior restricts posterior completely** | Prior dominates the posterior | Check if this is intentional. If not, weaken the prior or collect more data |
| **Loose prior causes numerical instability** | Data is too weak to constrain the model without prior information | Note the need for regularization. |

## Which variables to check

Not every parameter needs sensitivity analysis. Focus on what matters:

- **Check**: interpretable coefficients, effect sizes, predictions, derived quantities
- **Skip**: group-specific parameters in hierarchical models (check the top-level hyperpriors instead), variance components you don't interpret directly

For hierarchical models, sensitivity of the hyperprior (e.g., the group-level standard deviation) is more informative than sensitivity of individual group effects.

## Key principle

**Sensitivity warnings are not automatic problems.** An intentionally informative prior — grounded in domain knowledge or previous studies — will legitimately cause the posterior to shift if you loosen it. That's expected: if you have a strong prior and modest data, the prior *should* matter.

The correct response to sensitivity is:
1. **Document** the shifts.
2. **Justify** why your chosen prior is appropriate.
3. **Report** the sensitivity transparently — readers should know which conclusions depend on prior choices.

Do not reflexively loosen priors just to make the posterior entirely data-driven. A well-justified informative prior is better science than a vague prior that encodes no knowledge.
