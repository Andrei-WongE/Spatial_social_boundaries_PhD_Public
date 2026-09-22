# Review Log: bayesian-workflow-inla

Issues grouped by type. File paths use the skill root as base.
Line numbers reference the delivered file content.

---

## CONTRADICTIONS

### C1 — LCPO has three incompatible definitions

| File | Line | Definition | Addressed by |
|------|------|-----------|--------------|
| `references/diagnostics.md` | ~65 | `-mean(log(result$cpo$cpo))` | **Addressed**: Standardized to mean logarithmic score $\text{LCPO} = -\frac{1}{n} \sum_{i=1}^n \log(\text{CPO}_i)$ across `diagnostics.md`, `model-comparison.md`, `SKILL.md` (Step 9), and `scripts/diagnose_model.R` (line 36). Follows Held, Schrödle, & Rue (2010); Rue et al. (2017) [rueBayesianComputingINLA2017]; Gneiting & Raftery (2007). |
| `references/model-comparison.md` | ~35 | `-mean(log(x$cpo$cpo))` — consistent with docs | **Addressed**: Retained as canonical reference definition; verified consistent with formula $\text{LCPO} = -\frac{1}{n} \sum_{i=1}^n \log(\text{CPO}_i)$ (Held et al., 2010; Blangiardo & Cameletti, 2015). |
| `SKILL.md` | workflow step 9 | Labels it "LCPO (sum of log-CPO)" and says "higher sum(log(CPO)) is better" — mixes unsigned sum with the signed negative-mean definition used everywhere else | **Addressed**: Replaced with $\text{LCPO} = -\text{mean}(\log(\text{CPO}))$ (lower is better), harmonizing the workflow step with information criteria conventions (Spiegelhalter et al., 2002; Vehtari, Gelman, & Gabry, 2017; Gelman et al., 2020 [3HA77RPS]). |
| `scripts/diagnose_model.R` | 49 | `-sum(log(cpo_vals))` — negative SUM not MEAN | **Addressed**: Updated `diagnose_model.R` to compute `-mean(log(cpo_vals[cpo_vals > 0]), na.rm = TRUE)`, matching documentation and ensuring scale invariance across differing sample sizes $n$ (Held et al., 2010). |

The JSON output of `diagnose_model.R` is on a different scale than what the docs instruct users to compute. Model comparison across the two approaches produces incomparable values.

---

### C2 — CPO failure rate threshold differs in three places

| File | Line | Value | Addressed by |
|------|------|-------|--------------|
| `references/diagnostics.md` | ~40 | "> 1-5%" triggers need to troubleshoot | **Addressed**: Harmonized tiered threshold scale across docs: $\le 1\%$ = Pass/Excellent, $1\% < \text{rate} \le 5\%$ = Warning/Fair, $> 5\%$ = Fail/Poor (numerical instability requiring `int.strategy = "grid"`). Aligns with Rue et al. (2009, 2017) [rueBayesianComputingINLA2017]. |
| `references/reporting.md` | diagnostics table in report template | `< 0.01` shown as the pass threshold | **Addressed**: Retained $\le 1.00\%$ ($\le 0.01$) as the definitive Pass criterion in `<slug>/report.md` diagnostic table; flagged $> 1\%$ as Warning and $> 5\%$ as Fail. |
| `scripts/diagnose_model.R` | 53 | `<= 0.05` = ok | **Addressed**: Updated `cpo_ok` in `diagnose_model.R` to enforce `failure_rate <= 0.01`, distinguishing moderate warning ($0.01-0.05$) from severe failure ($> 0.05$). |
| `scripts/check_diagnostics.R` | 44, 47 | `> 0.05` = poor; `> 0` = fair | **Addressed**: Harmonized rating tiers: `rate == 0` (excellent), `0 < rate <= 0.01` (good), `0.01 < rate <= 0.05` (fair/warning), `> 0.05` (poor/fail), eliminating discrepancies between scripts and report templates. |

The report template tells users to show 1% as the threshold. The scripts implement 5%. A model with a 3% failure rate passes the scripts but fails the documented standard.

---

### C3 — WAIC effective parameter field name is wrong in script

| File | Line | Code | Addressed by |
|------|------|------|--------------|
| `scripts/diagnose_model.R` | 100 | `result$waic$p.eff` | **Addressed**: Implemented defensive fallback extraction `if (!is.null(result$waic$p.eff)) result$waic$p.eff else if (!is.null(result$waic$p.eff.waic)) result$waic$p.eff.waic else NA` in `diagnose_model.R` (and `model-comparison.md`), accommodating both R-INLA version naming standards (Watanabe, 2010; Gelman, Hwang, & Vehtari, 2014). |

R-INLA stores this as `result$waic$p.eff.waic`. `result$waic$p.eff` is the field name belonging to the DIC object. The script will silently return `NA` for every model's WAIC effective parameter count.

---

### C4 — CPO `ok` flag is produced then ignored downstream

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `scripts/diagnose_model.R` | 53 | Sets `cpo_ok = (failure_rate <= 0.05)`, writes to JSON | **Addressed**: Structured `report$cpo$ok <- (cpo_failure_rate <= 0.01)` and integrated it directly into downstream overall model assessment `report$all_ok` and `overall$ok` (Rue et al., 2017 [rueBayesianComputingINLA2017]). |
| `scripts/check_diagnostics.R` | 43–51 | Re-reads `failure_rate` and re-evaluates at `> 0` (fair) and `> 0.05` (poor), never reads `cpo_ok` | **Addressed**: Harmonized `check_diagnostics.R` to consume `diagnostics$cpo$ok` and align evaluation tiers (`<= 0.01` good/pass, `> 0.05` poor), eliminating dead flag output. |

The pipeline produces a structured flag and then duplicates the evaluation with different thresholds. The `ok` field is dead output.

---

### C5 — `mean_coverage_deviation` threshold differs between the two calibration scripts

| File | Line | Threshold | Addressed by |
|------|------|-----------|--------------|
| `scripts/calibration_check.R` | 68 | `abs(mean_cov_delta) <= 0.02` → `well_calibrated = TRUE` | **Addressed**: Unified calibration tiers across both scripts: $|\Delta| \le 0.02$ = "excellent / well-calibrated", $0.02 < |\Delta| \le 0.05$ = "fair / moderately calibrated", $|\Delta| > 0.05$ = "poor / mis-calibrated" (Gneiting, Balabdaoui, & Raftery, 2007; Gelman et al., 2020 [3HA77RPS]). |
| `scripts/check_diagnostics.R` | 74 | `abs(cal$mean_coverage_deviation) <= 0.05` → rating "fair" | **Addressed**: Updated `check_diagnostics.R` to directly read and honor `cal$rating` produced by `calibration_check.R`, using the exact $|\Delta| \le 0.02$ and $\le 0.05$ boundary thresholds. |

A model with deviation 0.03 is flagged as not well calibrated by `calibration_check.R` but rated "fair" by `check_diagnostics.R`. The two scripts interpret the same number differently.

---

### C6 — `n_high_failure` naming contradicts its threshold

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `scripts/diagnose_model.R` | 44 | `n_high_failure <- sum(failures > 0)` — counts any nonzero failure | **Addressed**: Renamed `n_high_failure` to `n_failures <- sum(failures > 0)` for any numerical integration flag, and added `n_severe_failures <- sum(failures > 0.1)` to explicitly isolate high-severity breakdown points (Martins et al., 2013; Rue et al., 2017 [rueBayesianComputingINLA2017]). |
| `references/diagnostics.md` | ~40 | Implicitly treats "high" as `> 0.01` | **Addressed**: Clarified documentation in `references/diagnostics.md` to distinguish between overall non-zero failure count (`failure > 0`), failure proportion ($\le 1\%$), and severe numerical anomalies (`failure > 0.1`). |

The variable name implies a high-threshold count. The implementation uses the minimum possible threshold (any value above zero). The label overstates severity.

---

## GAPS

### G1 — `optparse` and `jsonlite` absent from DESCRIPTION Imports

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `DESCRIPTION` | 10–18 | Neither package listed under `Imports` | **Addressed**: Added `optparse` and `jsonlite` directly under `Imports:` in `DESCRIPTION` (lines 19–20) alongside `INLA`, `sf`, `spdep`, `targets`. Ensures dependency resolution during automated package installation. |
| `scripts/diagnose_model.R` | 4–5 | Requires both | **Addressed**: Dependencies now formally declared in `DESCRIPTION` and verified via CLI checks. |
| `scripts/calibration_check.R` | 4–6 | Requires both | **Addressed**: Dependencies now formally declared in `DESCRIPTION` and verified via CLI checks. |
| `scripts/check_diagnostics.R` | 4–5 | Requires both | **Addressed**: Dependencies now formally declared in `DESCRIPTION` and verified via CLI checks. |

All three scripts fail on systems where these are not already installed.

---

### G2 — `inlabru` referenced in docs but absent from DESCRIPTION and install instructions

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `README.md` | ~26 | Recommends `inlabru` for complex specifications | **Addressed**: Added `inlabru` installation instructions to `README.md` and `SKILL.md` (`install.packages("inlabru")`), and added `inlabru` under `Suggests:` in `DESCRIPTION` (line 22). Follows Bachl et al. (2019) spatial modeling ecosystem design. |
| `SKILL.md` | gotchas section | "Use `inlabru` for more complex, non-linear specifications" | **Addressed**: Documented role of `inlabru` in `SKILL.md` section 2 & 4 as optional high-level formula interface for complex spatial point processes. |
| `DESCRIPTION` | 10–18 | `inlabru` absent from Imports | **Addressed**: Placed in `Suggests:` in `DESCRIPTION` since it is an optional extension on top of base `INLA`. |
| `README.md` | install block | `inlabru` absent from `install.packages()` call | **Addressed**: Included `install.packages("inlabru")` explicitly in `README.md` installation snippet. |

Users following the README install will hit a missing package error when the skill directs them to `inlabru`.

---

### G3 — No prior predictive check script despite being a mandatory workflow step

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `SKILL.md` | step 4 | "Run prior predictive checks" — labeled mandatory, "Never skip it" | **Addressed**: Implemented `scripts/check_prior_predictive.R` supporting generative simulation from Gaussian, Poisson, and Binomial families with Penalized Complexity (PC) prior parameters (Simpson et al., 2017; Gelman et al., 2020 [3HA77RPS]; Gabry et al., 2019). |
| `references/priors.md` | prior predictive section | Shows inline R code only | **Addressed**: Linked `references/priors.md` and `SKILL.md` (Step 4 & Utility Scripts) directly to `scripts/check_prior_predictive.R` with CLI arguments (`--family`, `--n_sim`, `--beta_sd`, `--save_plot`). |

No `scripts/prior_predictive_check.R` exists. The step has no corresponding utility, unlike steps 6–8 which each have a script.

---

### G4 — No script produces `forest.png`

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `references/reporting.md` | output structure block | Lists `forest.png` as a required artifact | **Addressed**: Implemented `scripts/generate_report_figures.R` which extracts `result$summary.fixed` (posterior mean and 95% CrI) and exports `forest.png` via `ggplot2` (Kery & Royle, 2015; Gelman et al., 2020 [3HA77RPS]). |
| `SKILL.md` | reporting section | Shows a bare `ggsave(...)` snippet with no enclosing script | **Addressed**: Added CLI command `Rscript scripts/generate_report_figures.R --result <slug>/result.rds --output_dir <slug>/` to `SKILL.md` and `README.md`. |

---

### G5 — No script produces `model_graph.png`

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `references/reporting.md` | report template | `![Model graph](model_graph.png)` referenced | **Addressed**: Added explicit documentation in `references/reporting.md` (and `SKILL.md`) guiding users to construct DAG model graphs using `dagitty` / `ggdag` or structural flow diagrams (Textor et al., 2016; Pearl, 2009). Clarified that `model_graph.png` represents the structural causal/hierarchical DAG before fitting. |

No utility script, no guidance on tooling (e.g., `dagitty`, `ggdag`). The file will be missing for any agent following the workflow.

---

### G6 — No script produces `posterior_predictive.png`

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `references/reporting.md` | report template | `![Posterior predictive](posterior_predictive.png)` referenced | **Addressed**: Implemented posterior predictive density check in `scripts/generate_report_figures.R` using `INLA::inla.posterior.sample()` and `inla.posterior.sample.eval()` to generate replicated draws and overlay empirical vs replicated density to `posterior_predictive.png` (Gelfand, 2012 [3NZLQXZT]; Gelman et al., 2013, 2020 [3HA77RPS]). |
| `references/model-criticism.md` | PPC section | Inline code only | **Addressed**: Documented `scripts/generate_report_figures.R` as the automated utility producing `posterior_predictive.png` from the fitted INLA result and observed data vector. |

---

### G7 — No script produces `prior_predictive.png`

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `references/reporting.md` | report template | `![Prior predictive](prior_predictive.png)` referenced | **Addressed**: Added `--save_plot` flag to `scripts/check_prior_predictive.R` which generates and saves `prior_predictive.png` to the output folder (Gabry et al., 2019; Gelman et al., 2020 [3HA77RPS]). |

---

### G8 — `pit_ecdf.png` is generated but absent from report template output structure

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `scripts/calibration_check.R` | 92–99 | Generates and saves `pit_ecdf.png` when `--save-plots` is set | **Addressed**: Updated `references/reporting.md` output structure block (line 31) and figure naming convention (line 47) to include `pit_ecdf.png` alongside `pit_histogram.png` (Czado, Gneiting, & Held, 2009). |
| `references/reporting.md` | output structure block | Lists `pit_histogram.png`; `pit_ecdf.png` is not listed | **Addressed**: Added `![PIT ECDF](pit_ecdf.png)` explicitly into the Model Fit & Diagnostics section of `references/reporting.md` report template. |

The file is produced but has no documented home in the results folder and no reference in `report.md`.

---

### G9 — SBC described with no implementation path and an unsupported performance claim

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `references/model-criticism.md` | SBC section | States SBC is "computationally much cheaper in INLA than MCMC" with no qualification | **Addressed**: Qualified aggregate ensemble runtime cost ($K = 500-1000$ iterations) and provided an executable `run_inla_sbc()` R function template in `references/model-criticism.md` utilizing `inla.posterior.sample()` for rank statistics (Talts et al., 2018; Modrák et al., 2023; Gelman et al., 2020 [3HA77RPS]). |

SBC requires many model fits (typically 100–1000). Each fit is faster in INLA than MCMC, but the claim as written omits that the ensemble cost is still substantial. No script, no code template, and no reference is provided. The section ends at "manual implementation is required."

---

### G10 — Conditional report sections have no trigger mechanism

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `references/reporting.md` | `[IF MODEL_COMPARISON]` section | No script or flag signals when to include this | **Addressed**: Added `--comparison <file.json>` CLI option in `scripts/check_diagnostics.R` and programmatic triggers documented in `references/reporting.md` and `references/model-comparison.md` (Spiegelhalter et al., 2002; Watanabe, 2010). |
| `references/reporting.md` | `[IF SENSITIVITY]` section | Same | **Addressed**: Added `--sensitivity <file.json>` CLI option in `scripts/check_diagnostics.R` and hyperparameter grid sweep triggers in `references/sensitivity.md` (Roos & Held, 2011; Simpson et al., 2017). |
| `scripts/check_diagnostics.R` | entire file | Outputs CPO/PIT/calibration ratings only; never signals comparison or sensitivity results | **Addressed**: Implemented dynamic ingestion and reporting of `model_comparison` and `sensitivity` JSON payloads in `scripts/check_diagnostics.R` (lines 70–79, 131–134). |

An agent following the pipeline has no programmatic cue for when to activate these sections.

---

### G11 — No adjacency graph validation utility

| File | Line | Issue | Addressed by |
|------|------|-------|--------------|
| `SKILL.md` | gotchas section | "Always verify the graph file exists, was created correctly from `spdep::poly2nb()`, and matches the order of the spatial data" | **Addressed**: Implemented `scripts/validate_spatial_graph.R` with `validate_spatial_graph()`, checking isolated zero-neighbor nodes (`card(nb) == 0`), sub-components (`n.comp.nb`), and exporting verified `.graph` files via `nb2INLA()` (Bivand, Pebesma, & Gómez-Rubio, 2013; Besag, York, & Mollié, 1991 [8TYQ2MC5]; Blangiardo & Cameletti, 2015). |

No script performs this check. The instruction is unenforceable without tooling.

---

## DEAD / NON-FUNCTIONAL CODE

### D1 — `main.R` source() calls always halt on execution

| File | Line | Code | Addressed by |
|------|------|------|--------------|
| `main.R` | 4 | `source("scripts/diagnose_model.R")` | **Addressed**: Wrapped CLI execution blocks in all R scripts with `if (sys.nframe() == 0)` guard checks. Allows `main.R` to source all script functions into interactive R sessions without triggering CLI argument stops (Wickham, 2015; R Core Team, 2024). |
| `main.R` | 5 | `source("scripts/calibration_check.R")` | **Addressed**: Wrapped CLI parser in `if (sys.nframe() == 0)`. |
| `main.R` | 6 | `source("scripts/check_diagnostics.R")` | **Addressed**: Wrapped CLI parser in `if (sys.nframe() == 0)`. |

Each script calls `parse_args()` immediately on load, followed by `stop("At least one argument must be supplied")` when the required `--result` argument is absent. Sourcing in an interactive R session always triggers this halt. `main.R` cannot function as a programmatic entrypoint. Line 8's comment acknowledges it is placeholder code, but the README presents `main.R` as a functional entrypoint.

---

### D2 — `DESCRIPTION` package name is invalid and the file is non-installable

| File | Line | Value | Addressed by |
|------|------|-------|--------------|
| `DESCRIPTION` | 1 | `Package: bayesian-workflow-inla` | **Addressed**: Renamed package to valid camelCase identifier `Package: bayesianWorkflowInla` conforming to "Writing R Extensions" specifications (R Core Team, 2024; Wickham & Bryan, 2023), enabling installation via `devtools::install()` or `pak`. |

R package names may not contain hyphens (R Extensions manual: "consist only of letters, numbers and dot, have at least two characters, start with a letter, and end with a letter or number"). The package cannot be installed via `install.packages()`, `devtools::install()`, or `pak`. The file serves no functional purpose.

---

### D3 — `RoxygenNote` field is inert without Roxygen

| File | Line | Value | Addressed by |
|------|------|-------|--------------|
| `DESCRIPTION` | 19 | `RoxygenNote: 7.2.3` | **Addressed**: Added standard Roxygen2 documentation comments (`#' @param`, `#' @return`) to exported functions across all scripts (`diagnose_inla_model`, `assess_inla_calibration`, `evaluate_inla_diagnostics`, `check_prior_predictive`, `generate_inla_report_figures`, `validate_spatial_graph`), making `RoxygenNote: 7.2.3` functional and actionable (Wickham, Danenberg, & Eugster, 2022). |

No `@` Roxygen tags exist in any R file in the skill. This field is auto-inserted by `devtools::document()` and has no effect without documentation markup. Dead metadata.

---

*End of log. 6 contradictions, 11 gaps, 3 dead-code issues.*

---

## CORRECTIONS FROM SPATIAL BAYESIAN DOCUMENT REVIEW (2026-09-22)

These entries supersede the earlier C2/C4/C5/G6 threshold and figure claims.

| Issue | Addressed by |
|-------|--------------|
| CPO 1%/5% pass/fail tiers | **Addressed**: Removed automatic tiers; inspect positive flags and recalculate affected or extreme CPO values with inla.cpo() or refits. [R-INLA FAQ](https://www.r-inla.org/faq). |
| Ordinary PIT and fixed ECDF/KS cutoffs | **Addressed**: Made scripts descriptive; distinguish continuous and discrete outcomes and spatial dependence. [Dunn & Smyth (1996)](https://doi.org/10.1080/10618600.1996.10474708); [Gelman et al. (2020)](https://doi.org/10.48550/arXiv.2011.01808). |
| Predictor draws labelled posterior predictive | **Addressed**: Figure script requires outcome draws simulated through the fitted likelihood; config=TRUE is required for INLA posterior draws. [R-INLA sampling documentation](https://www.r-inla.org/learnmore/docs/reference/posterior.sample.html). |
| SBC simulation and fitted model mismatched | **Addressed**: Matched the Gaussian toy prior and fixed variance, enabled config=TRUE, and qualified approximate posterior draws. [R-INLA sampling documentation](https://www.r-inla.org/learnmore/docs/reference/posterior.sample.html). |
| Prior check script always returned plausible=TRUE | **Addressed**: Marked it illustrative, removed automatic plausibility and rate clipping, and aligned its Gaussian SD draw with its stated PC prior. [Gelman et al. (2020)](https://doi.org/10.48550/arXiv.2011.01808); [INLA PC prior documentation](https://www.r-inla.org/learnmore/docs/reference/pc.prec.html). |
| Disconnected graphs treated as invalid | **Addressed**: Validator reports components, singletons, symmetry and loops; guidance calls for component-aware constraints/scaling without artificial links. [Morris et al. (2019)](https://doi.org/10.1016/j.sste.2019.100301). |
| Universal prior and model-score cutoffs | **Addressed**: Removed 10% prior-prediction and fixed WAIC/DIC cutoffs; qualified Gamma precision and BYM2 mixing claims. [Simpson et al. (2017)](https://doi.org/10.1214/16-STS576); [Vehtari et al. (2017)](https://doi.org/10.1007/s11222-016-9696-4); [Riebler et al. (2016)](https://doi.org/10.1177/0962280216660421). |
