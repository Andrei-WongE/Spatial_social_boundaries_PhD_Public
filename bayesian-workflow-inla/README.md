# bayesianWorkflowInla

An opinionated [Agent Skill](https://agentskills.io) for building, diagnosing, and reporting on spatial Bayesian statistical models using R-INLA.

Compatible with Claude Code, Cursor, Gemini CLI, and any agent supporting the [Agent Skills spec](https://agentskills.io/specification).

## What it does

Guides your coding agent through the full spatial Bayesian workflow in R:

1. **Formulate** the generative story
2. **Specify priors** using Penalized Complexity (PC) priors (`pc.prec`, `pc.cor1`)
3. **Validate spatial data** via adjacency graph diagnostics (`spdep::poly2nb()`, `validate_spatial_graph()`)
4. **Prior predictive checks** using `check_prior_predictive.R` before fitting
5. **Inference** via deterministic Integrated Nested Laplace Approximations (`inla()`)
6. **Convergence & Approximation diagnostics** (CPO failure rates $\le 1\%$, numerical integration checks)
7. **Model criticism** (posterior predictive checks via samples, PIT calibration histogram & ECDF)
8. **Prior sensitivity** (hyperparameter grid sweeps)
9. **Model comparison** (DIC, WAIC, LCPO where $\text{LCPO} = -\overline{\log \text{CPO}}$)
10. **Reporting** with a canonical `<slug>/report.md` artifact and standard figures (`forest.png`, `pit_histogram.png`, `pit_ecdf.png`, `posterior_predictive.png`)

## Installation

### Agent Installation

Copy the skill folder into your agent's skills directory:

```bash
mkdir -p ~/.config/agents/skills/
cp -r bayesian-workflow-inla ~/.config/agents/skills/
```

### R Package dependencies

R-INLA must be installed from its official stable repository:

```r
install.packages("INLA", repos=c(getOption("repos"), INLA="https://inla.r-inla-download.org/R/stable"), dep=TRUE)
install.packages(c("sf", "spdep", "ggplot2", "tidyverse", "tmap", "targets", "tarchetypes", "optparse", "jsonlite"))

# Optional spatial formula wrapper
install.packages("inlabru")
```

## Example Prompts

- *"I have spatial disease count data across London LSOAs. Build a BYM2 spatial model with R-INLA, PC priors, and check graph connectivity."*
- *"My INLA model returned CPO failures. Run diagnostics and diagnose whether I should switch to grid integration."*
- *"Evaluate the calibration of this spatial model using PIT histograms and ECDFs."*
- *"Compare this IID random intercept model against a spatial BYM2 model using WAIC, DIC, and LCPO."*

## Included Files & Structure

```
bayesian-workflow-inla/
├── SKILL.md                          # Main workflow instructions & critical rules
├── main.R                            # Programmatic entrypoint (loads R helper functions)
├── DESCRIPTION                       # R package metadata (Imports: INLA, sf, spdep, optparse, etc.)
├── references/
│   ├── priors.md                     # PC Prior selection & elicitation guide
│   ├── diagnostics.md                # CPO, PIT, and numerical stability diagnostics
│   ├── model-criticism.md            # PPC, PIT histograms, SBC template
│   ├── model-comparison.md           # DIC, WAIC, LCPO comparison tables
│   ├── hierarchical.md               # Spatial effects (BYM2, constraints, graph files)
│   ├── sensitivity.md                # Prior sensitivity analysis sweeps
│   └── reporting.md                  # Canonical report artifact & figure standards
└── scripts/
    ├── check_prior_predictive.R      # Prior simulation check (writes prior_predictive.png)
    ├── diagnose_model.R              # CPO/PIT/DIC/WAIC diagnostic report (writes diagnostics.json)
    ├── calibration_check.R           # Calibration plots & metrics (writes calibration.json, pit_histogram.png, pit_ecdf.png)
    ├── generate_report_figures.R     # Generates forest.png and posterior_predictive.png
    ├── validate_spatial_graph.R      # Adjacency graph topology validator for INLA
    └── check_diagnostics.R           # Interprets JSON metrics into qualitative ratings & next steps
```

## License

MIT
