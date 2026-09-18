# Review Log: bayesian-workflow-inla

Issues grouped by type. File paths use the skill root as base.
Line numbers reference the delivered file content.

---

## CONTRADICTIONS

### C1 — LCPO has three incompatible definitions

| File | Line | Definition |
|------|------|-----------|
| `references/diagnostics.md` | ~65 | `-mean(log(result$cpo$cpo))` |
| `references/model-comparison.md` | ~35 | `-mean(log(x$cpo$cpo))` — consistent with docs |
| `SKILL.md` | workflow step 9 | Labels it "LCPO (sum of log-CPO)" and says "higher sum(log(CPO)) is better" — mixes unsigned sum with the signed negative-mean definition used everywhere else |
| `scripts/diagnose_model.R` | 49 | `-sum(log(cpo_vals))` — negative SUM not MEAN |

The JSON output of `diagnose_model.R` is on a different scale than what the docs instruct users to compute. Model comparison across the two approaches produces incomparable values.

---

### C2 — CPO failure rate threshold differs in three places

| File | Line | Value |
|------|------|-------|
| `references/diagnostics.md` | ~40 | "> 1-5%" triggers need to troubleshoot |
| `references/reporting.md` | diagnostics table in report template | `< 0.01` shown as the pass threshold |
| `scripts/diagnose_model.R` | 53 | `<= 0.05` = ok |
| `scripts/check_diagnostics.R` | 44, 47 | `> 0.05` = poor; `> 0` = fair |

The report template tells users to show 1% as the threshold. The scripts implement 5%. A model with a 3% failure rate passes the scripts but fails the documented standard.

---

### C3 — WAIC effective parameter field name is wrong in script

| File | Line | Code |
|------|------|------|
| `scripts/diagnose_model.R` | 100 | `result$waic$p.eff` |

R-INLA stores this as `result$waic$p.eff.waic`. `result$waic$p.eff` is the field name belonging to the DIC object. The script will silently return `NA` for every model's WAIC effective parameter count.

---

### C4 — CPO `ok` flag is produced then ignored downstream

| File | Line | Issue |
|------|------|-------|
| `scripts/diagnose_model.R` | 53 | Sets `cpo_ok = (failure_rate <= 0.05)`, writes to JSON |
| `scripts/check_diagnostics.R` | 43–51 | Re-reads `failure_rate` and re-evaluates at `> 0` (fair) and `> 0.05` (poor), never reads `cpo_ok` |

The pipeline produces a structured flag and then duplicates the evaluation with different thresholds. The `ok` field is dead output.

---

### C5 — `mean_coverage_deviation` threshold differs between the two calibration scripts

| File | Line | Threshold |
|------|------|-----------|
| `scripts/calibration_check.R` | 68 | `abs(mean_cov_delta) <= 0.02` → `well_calibrated = TRUE` |
| `scripts/check_diagnostics.R` | 74 | `abs(cal$mean_coverage_deviation) <= 0.05` → rating "fair" |

A model with deviation 0.03 is flagged as not well calibrated by `calibration_check.R` but rated "fair" by `check_diagnostics.R`. The two scripts interpret the same number differently.

---

### C6 — `n_high_failure` naming contradicts its threshold

| File | Line | Issue |
|------|------|-------|
| `scripts/diagnose_model.R` | 44 | `n_high_failure <- sum(failures > 0)` — counts any nonzero failure |
| `references/diagnostics.md` | ~40 | Implicitly treats "high" as `> 0.01` |

The variable name implies a high-threshold count. The implementation uses the minimum possible threshold (any value above zero). The label overstates severity.

---

## GAPS

### G1 — `optparse` and `jsonlite` absent from DESCRIPTION Imports

| File | Line | Issue |
|------|------|-------|
| `DESCRIPTION` | 10–18 | Neither package listed under `Imports` |
| `scripts/diagnose_model.R` | 4–5 | Requires both |
| `scripts/calibration_check.R` | 4–6 | Requires both |
| `scripts/check_diagnostics.R` | 4–5 | Requires both |

All three scripts fail on systems where these are not already installed.

---

### G2 — `inlabru` referenced in docs but absent from DESCRIPTION and install instructions

| File | Line | Issue |
|------|------|-------|
| `README.md` | ~26 | Recommends `inlabru` for complex specifications |
| `SKILL.md` | gotchas section | "Use `inlabru` for more complex, non-linear specifications" |
| `DESCRIPTION` | 10–18 | `inlabru` absent from Imports |
| `README.md` | install block | `inlabru` absent from `install.packages()` call |

Users following the README install will hit a missing package error when the skill directs them to `inlabru`.

---

### G3 — No prior predictive check script despite being a mandatory workflow step

| File | Line | Issue |
|------|------|-------|
| `SKILL.md` | step 4 | "Run prior predictive checks" — labeled mandatory, "Never skip it" |
| `references/priors.md` | prior predictive section | Shows inline R code only |

No `scripts/prior_predictive_check.R` exists. The step has no corresponding utility, unlike steps 6–8 which each have a script.

---

### G4 — No script produces `forest.png`

| File | Line | Issue |
|------|------|-------|
| `references/reporting.md` | output structure block | Lists `forest.png` as a required artifact |
| `SKILL.md` | reporting section | Shows a bare `ggsave(...)` snippet with no enclosing script |

---

### G5 — No script produces `model_graph.png`

| File | Line | Issue |
|------|------|-------|
| `references/reporting.md` | report template | `![Model graph](model_graph.png)` referenced |

No utility script, no guidance on tooling (e.g., `dagitty`, `ggdag`). The file will be missing for any agent following the workflow.

---

### G6 — No script produces `posterior_predictive.png`

| File | Line | Issue |
|------|------|-------|
| `references/reporting.md` | report template | `![Posterior predictive](posterior_predictive.png)` referenced |
| `references/model-criticism.md` | PPC section | Inline code only |

---

### G7 — No script produces `prior_predictive.png`

| File | Line | Issue |
|------|------|-------|
| `references/reporting.md` | report template | `![Prior predictive](prior_predictive.png)` referenced |

---

### G8 — `pit_ecdf.png` is generated but absent from report template output structure

| File | Line | Issue |
|------|------|-------|
| `scripts/calibration_check.R` | 92–99 | Generates and saves `pit_ecdf.png` when `--save-plots` is set |
| `references/reporting.md` | output structure block | Lists `pit_histogram.png`; `pit_ecdf.png` is not listed |

The file is produced but has no documented home in the results folder and no reference in `report.md`.

---

### G9 — SBC described with no implementation path and an unsupported performance claim

| File | Line | Issue |
|------|------|-------|
| `references/model-criticism.md` | SBC section | States SBC is "computationally much cheaper in INLA than MCMC" with no qualification |

SBC requires many model fits (typically 100–1000). Each fit is faster in INLA than MCMC, but the claim as written omits that the ensemble cost is still substantial. No script, no code template, and no reference is provided. The section ends at "manual implementation is required."

---

### G10 — Conditional report sections have no trigger mechanism

| File | Line | Issue |
|------|------|-------|
| `references/reporting.md` | `[IF MODEL_COMPARISON]` section | No script or flag signals when to include this |
| `references/reporting.md` | `[IF SENSITIVITY]` section | Same |
| `scripts/check_diagnostics.R` | entire file | Outputs CPO/PIT/calibration ratings only; never signals comparison or sensitivity results |

An agent following the pipeline has no programmatic cue for when to activate these sections.

---

### G11 — No adjacency graph validation utility

| File | Line | Issue |
|------|------|-------|
| `SKILL.md` | gotchas section | "Always verify the graph file exists, was created correctly from `spdep::poly2nb()`, and matches the order of the spatial data" |

No script performs this check. The instruction is unenforceable without tooling.

---

## DEAD / NON-FUNCTIONAL CODE

### D1 — `main.R` source() calls always halt on execution

| File | Line | Code |
|------|------|------|
| `main.R` | 4 | `source("scripts/diagnose_model.R")` |
| `main.R` | 5 | `source("scripts/calibration_check.R")` |
| `main.R` | 6 | `source("scripts/check_diagnostics.R")` |

Each script calls `parse_args()` immediately on load, followed by `stop("At least one argument must be supplied")` when the required `--result` argument is absent. Sourcing in an interactive R session always triggers this halt. `main.R` cannot function as a programmatic entrypoint. Line 8's comment acknowledges it is placeholder code, but the README presents `main.R` as a functional entrypoint.

---

### D2 — `DESCRIPTION` package name is invalid and the file is non-installable

| File | Line | Value |
|------|------|-------|
| `DESCRIPTION` | 1 | `Package: bayesian-workflow-inla` |

R package names may not contain hyphens (R Extensions manual: "consist only of letters, numbers and dot, have at least two characters, start with a letter, and end with a letter or number"). The package cannot be installed via `install.packages()`, `devtools::install()`, or `pak`. The file serves no functional purpose.

---

### D3 — `RoxygenNote` field is inert without Roxygen

| File | Line | Value |
|------|------|-------|
| `DESCRIPTION` | 19 | `RoxygenNote: 7.2.3` |

No `@` Roxygen tags exist in any R file in the skill. This field is auto-inserted by `devtools::document()` and has no effect without documentation markup. Dead metadata.

---

*End of log. 6 contradictions, 11 gaps, 3 dead-code issues.*
