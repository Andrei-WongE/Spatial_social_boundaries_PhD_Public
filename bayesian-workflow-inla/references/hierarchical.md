# Hierarchical (Multilevel) Models

## Contents
- When to use hierarchical models
- Partial pooling intuition
- Common hierarchical structures in INLA
- Diagnostics specific to hierarchical models

## When to use hierarchical models

Use hierarchical models when data has **grouped structure** — observations nested within units (students in schools, games in seasons, patients in hospitals, items in categories). 

The key question: Do groups share information? If group-level parameters are related, hierarchical models borrow strength across groups through partial pooling.

## Partial pooling intuition

Three approaches to grouped data:

- **Complete pooling**: Ignore groups, fit one model. Misses group-level variation. Maximum bias.
- **No pooling**: Fit separate models per group. Overfits small groups. Maximum variance.
- **Partial pooling** (hierarchical): Groups share a common distribution. Small groups shrink toward the global mean; large groups retain their own estimate and influence the global population. 

Partial pooling is almost always the right choice. It naturally handles imbalanced group sizes. In INLA, this is handled natively via the Laplace approximation, meaning you do not need to worry about "centered vs. non-centered" parameterizations like in MCMC.

## Common hierarchical structures in INLA

### Varying intercepts

Each group has its own baseline, partially pooled toward a global mean.

```r
# PC prior for the precision of the random intercepts
hyper_iid <- list(prec = list(prior = "pc.prec", param = c(1, 0.01)))

formula <- y ~ 1 + x + f(group_id, model = "iid", hyper = hyper_iid)
```

### Varying intercepts and slopes (Correlated)

Each group has its own baseline AND its own effect of a predictor. To allow the intercept and slope to be correlated, use `iid2d`.

```r
# Note: You need a numeric ID for the groups
# n=2 specifies a 2D random effect
formula <- y ~ 1 + f(group_id, covariate, model = "iid2d", n = 2)
```

### Spatial effects

For areal data, BYM2 (Besag-York-Mollie 2) is the standard model. It combines a structured spatial effect (ICAR) and an unstructured IID effect, with a mixing parameter.

```r
# Need a spatial graph
library(spdep)
# Assuming sf_obj is your spatial data
nb <- poly2nb(sf_obj)
nb2INLA("map.adj", nb)

formula <- y ~ 1 + x + 
  f(area_id, model = "bym2", graph = "map.adj", 
    scale.model = TRUE, constr = TRUE)
```

### Nested hierarchy

Groups within groups (students in classrooms in schools). Simply include multiple `f()` terms.

```r
formula <- y ~ 1 + x + 
  f(school_id, model = "iid") + 
  f(class_id, model = "iid") 
  # Note: class_id must be unique across all schools
```

## Diagnostics specific to hierarchical models

1. **Group-level SD posterior**: If the group variance posterior piles up near zero, the data may not support group-level variation (partial pooling → complete pooling).
2. **Identifiability**: Ensure sum-to-zero constraints are used when a global intercept and a set of random intercepts are both estimated (INLA uses `constr=TRUE` by default for many models, but verify).

```r
# Check posterior of random effect variance
marg_var <- inla.tmarginal(function(x) 1/x, result$marginals.hyperpar[[1]])
plot(marg_var, type = "l", main = "Posterior of group variance")
```

### Identifiability checks

A model component is **identifiable** only if the data can distinguish its effect from other components.

- **Overparameterized intercepts**: Group-level intercepts + a global intercept without a sum-to-zero constraint. INLA usually handles this automatically with `constr=TRUE`, but be careful when defining custom models.
- **Collinear covariates at the group level**: If a group-level predictor is nearly constant within groups, it is confounded with the group intercept. 

If you see strange posterior behavior or convergence issues, check your constraints and covariates.
