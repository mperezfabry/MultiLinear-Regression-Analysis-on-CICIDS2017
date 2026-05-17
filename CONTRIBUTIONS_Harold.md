# Harold — Contributions Log

This file tracks what I (Harold) added or changed in the project, with a quick plain-language *why* for each one. The point is so the team — and the professor — can see what I personally contributed without diffing every file.

---

## My primary deliverable: Descriptive Statistics

### 1. `Descriptive.R` — finished the analysis

**What I added / changed:**
- The density plot section now overlays attack and benign distributions on the same axes, with a legend. Before, it only showed the combined distribution, which made it hard to see the difference between groups.
- New section 5: bins `Destination.Port` into the standard IANA categories (well-known / registered / dynamic) and tests the relationship with `Attack_Flag` using a chi-square test. This is what satisfies the assignment's "two categorical variables, one predictor and one response" requirement.
- New section 6: side-by-side boxplots of the top six features by `Attack_Flag` (saved to `descriptive_boxplots.pdf`), plus a printed table of means and SDs grouped by attack status.

**Why:** This is my section. The earlier version of the file was mostly a skeleton with TODOs in it, so I filled in the comparative pieces that the assignment actually asks for. The chi-square test in particular is what proves we have a real categorical predictor in the data, which the spec requires.

### 2. `Descriptive_Writeup.md` — new plain-language writeup

**What I added:** A short, student-style write-up that explains the dataset, the variable groups (packet size, rates, timing, idle/active, TCP flags, ports, flow shape), the patterns the descriptive analysis surfaced, and the files produced.

**Why:** The professor's planning feedback specifically asked for an audience-friendly rundown of the variables so the results would land for someone without a cybersecurity background. The raw data has ~80 highly technical columns and the modeling numbers won't mean anything without that context.

---

## Helping out where the other pieces had gaps

### 3. `Linear.R` — added scaled coefficients and practical-significance section

**What I added** (new sections 7 and 8 at the bottom of the file):
- A re-fit of the linear model on standardized (scaled) predictors.
- A "practical significance" table that reports each predictor's effect as a percentage of the response's standard deviation.

**Why:** The professor called this out directly in the feedback. Because our sample is around 1,600 rows, almost every coefficient comes back statistically significant — but a small effect with a small p-value isn't actually useful. Scaled coefficients let us compare predictors on equal footing ("a 1-SD change in this variable moves Flow.Bytes by X bytes"), and the practical-significance table makes it obvious which predictors actually matter and which are statistically loud but practically trivial. The rule of thumb I used: if a predictor moves Flow.Bytes by less than ~1% of its SD, flag it as not practically meaningful. Michael's underlying MLR work was solid — this is just the addition the prof asked for.

### 4. `Logistic.R` — full working version

**What I added:** A complete logistic regression script that:
- Loads `glm_data.csv` (no hardcoded paths).
- Splits the data 70/30 into train/test using one seeded index — no risk of overlap.
- Fits the full logistic model on the training set.
- Iteratively drops the worst-VIF predictor until everything is below 5.
- Reports overall model significance via the likelihood ratio test.
- Predicts on the test set, builds the ROC curve, and reports AUC.
- Saves the ROC curve to `logistic_roc.pdf`.
- Reports the confusion matrix at both the default 0.5 cutoff and the Youden-optimal cutoff, with accuracy, sensitivity, specificity, precision, and F1 for each.
- Reports odds ratios with 95% CIs for every final predictor.

**Why:** The original `Logistic.R` was an empty stub. There was a working version of the modeling in `Final log.R`, but it had several bugs that stopped it from running on my machine or Michael's (hardcoded absolute path to Katek's drive, two independent `sample()` calls that didn't guarantee disjoint train/test sets, a `predict()` call that referenced columns that didn't exist in the test data, and no ROC/AUC). I rebuilt it cleanly so anyone on the team can `source("Logistic.R")` and get a complete result. I left `Final log.R` in place as Samantha's reference — her interpretation block at the bottom is genuinely good and we should reuse it in the final report.

**One install dependency:** `Logistic.R` needs the `pROC` package. One-time setup: `install.packages("pROC")`.

---

## Files I did NOT touch

- `setup.R` — unchanged.
- `Final log.R` — left in place as Samantha's reference. The working logistic script is now `Logistic.R`.
- `mlr_data.csv`, `glm_data.csv` — unchanged.
- `Notes.md`, `README.md` — unchanged.

---

## How to run everything end-to-end

```r
source("setup.R")        # regenerate the CSVs (only needed if raw data changes)
source("Descriptive.R")  # descriptive stats + plots (my piece)
source("Linear.R")       # MLR with scaled coefs + practical-significance table
source("Logistic.R")     # logistic regression with ROC/AUC and odds ratios
```

---

## Round 2 — closing the rubric gaps

After everything above was in place, I audited the deliverables against the planning doc, the Data Description PDF, and the professor's feedback. A handful of small gaps were still open. This round closes them.

### `Descriptive_Writeup.md`

**Added a "Why this response variable?" section.**
Directly answers the professor's feedback question about whether throughput makes sense as a response. Explains why we moved from `Flow.Bytes.s` to `Flow.Bytes` on benign-only flows, and gives the cybersecurity motivation: the MLR builds a baseline of what "normal" traffic looks like, and the logistic model then learns where attacks deviate from that baseline. The two models support each other.

**Added a per-variable dictionary.**
A table listing every variable in `mlr_data.csv` and `glm_data.csv` with its source dataset, type, units, and a one-line meaning. Modeled on the format used by the Boston housing dataset that the Data Description PDF references. This is what closes the "description of all variables" line in the assignment spec.

### `Linear.R`

**Added studentized residuals to section 5.**
The planning doc names `rstudent()` explicitly under influence diagnostics. Cook's, leverage, and DFBETAS were already there, but the studentized-residual call wasn't. Two lines — flags any observation with `|rstudent| > 3`.

**Added section 9: log-transformed model as a robustness check.**
The diagnostics in section 4 flag heteroscedasticity (ncv test) and non-normal residuals (Shapiro). The planning doc says: *"if diagnostics show serious problems, consider log(...)"*. The new section fits the model on `log1p(Flow.Bytes)` and prints the new R², ncv p-value, and Shapiro p-value side-by-side with the raw model so we can see whether the log transform actually helps. The raw model stays as the primary specification because byte units are easier to interpret — log is on hand if we decide to switch.

### `Logistic.R`

**Added section 4b: separation diagnostic.**
The planning doc commits to checking for complete or quasi-complete separation. The new block flags any coefficient with `|Estimate| > 10` or `|Std. Error| > 10` after the final model is fit — both classic separation symptoms.

**Added section 10: standardized (1-SD) odds ratios.**
The MLR had a dedicated scaled-coefficient block; the logistic side needed the same treatment. Per-unit odds ratios aren't comparable across predictors (a unit of `Destination.Port` is not the same as a unit of `Down.Up.Ratio`), so this section re-fits on standardized predictors and reports each odds ratio as a 1-SD change. Each predictor is labeled `LARGE` / `moderate` / `small` / `trivial` based on the per-SD percent change in odds. This closes the practical-significance gap on the classification side.

### What this leaves us with

Every requirement I could find in the planning doc, the Data Description PDF, and the professor's feedback now maps to a concrete piece of code or a section of the writeup. Nothing in this round changes the existing modeling decisions — every addition is either a new diagnostic, a robustness check, or an additional interpretation table.

---

## Round 3 — runtime bugfix in `Logistic.R`

On the first end-to-end run, `Logistic.R` got all the way through section 8 (confusion matrices) and then crashed at the odds-ratio CI step with:
*"profiling has found a better solution, so original fit had not converged."*

**Root cause:** R's default `glm()` allows only 25 IRLS iterations. The model was hitting that cap and stopping at a near-but-not-quite optimum, which then broke `confint()` (profile likelihood) when it tried to walk to a better fit.

**Fix:** two small, targeted changes — no modeling decisions altered.
1. Added `control = glm.control(maxit = 100)` to the `glm()` fits so they actually converge instead of hitting the iteration cap. (The VIF loop's `update()` calls inherit this control, so they're covered too.)
2. Switched the odds-ratio CIs from `confint()` (profile-likelihood) to `confint.default()` (Wald-based). Wald CIs are the standard for large-sample logistic regression, are much faster, and don't depend on profile-likelihood convergence.

After this fix the script runs cleanly from `source()` to the final summary, including the new sections 9 (odds ratios with CIs) and 10 (standardized 1-SD odds ratios with practical classification).

**Side note from the first full run** — the separation check correctly flagged `Active.Std` (SE ≈ 10, p ≈ 0.95, mostly zeros in the data). Its coefficient should not be interpreted. The other 10 predictors are well-behaved and the overall model fit (AUC ≈ 0.96, LR test p ≈ 3e-181) is excellent.

---

## Round 4 — runtime bugfix in `setup.R`

`setup.R` used `rstudioapi::getSourceEditorContext()$path` to find its own directory. That works when you click "Source" on an open file in RStudio, but returns an empty string when you `source("setup.R")` from the console, which then crashes `dirname("")`.

**Fix:** wrapped the directory resolution in a `tryCatch` that checks whether the editor context actually returns a non-empty path. If it doesn't (or if anything errors), it falls back to `getwd()`. Behavior for Michael and Samantha is unchanged — when they click "Source", the editor path is non-empty and gets used exactly as before. The new fallback only kicks in for console `source()` calls.

---

## Round 5 — practical-classification threshold fix

On the first full end-to-end run, the standardized odds ratios in `Logistic.R` section 10 showed three predictors (`Fwd.Packet.Length.Min`, `Avg.Fwd.Segment.Size`, `Active.Std`) classified as "moderate" when they should have been "LARGE".

**Root cause:** when a scaled coefficient is very large and negative, `exp(coef)` underflows to 0 and `Pct_Change_per_SD` clamps to exactly `-100.0`. My check was `abs(pct_change) > 100`, which is `FALSE` at the boundary, so the underflow cases fell into the "moderate" bucket.

**Fix:** changed the threshold to `>= 100` so any predictor whose scaled OR collapses to 0 (i.e., a 1-SD increase essentially eliminates the odds of attack) is correctly tagged `LARGE`.

No modeling decisions changed — only the human-readable label for those borderline cases.

**Round 5 follow-up:** the first fix only caught one of the three affected predictors. The other two had `Pct_Change` values like `-99.9999975` (their OR underflowed close to but not exactly 0) — they *displayed* as `-100.0` after rounding but the unrounded value was still `< 100`, so the threshold check failed. Final fix: classify off the rounded (displayed) value so the table is internally consistent — what you see in the table is what gets the label.

---

## Round 6 — Decision on `Active.Std` (separation flag)

After the first full clean run, the separation diagnostic in `Logistic.R` flagged `Active.Std` (SE ≈ 10, p ≈ 0.95). The diagnostic did exactly what it's supposed to do. The question then was: drop the variable or keep it.

**Decision: keep `Active.Std` in the model. Do not interpret its odds ratio.**

### Why keep it (plain version)
`Active.Std` was selected by the team's BIC stepwise procedure in `setup.R`. Removing it now would mean overriding a decision the whole team committed to in the planning phase. The overall classifier performance (AUC = 0.9625, sensitivity at the Youden cutoff = 95.3%) is unaffected by whether we *interpret* this one coefficient — the model still uses it under the hood. So removing it is unnecessary and would muddy the team handoff.

### Why not interpret it (plain version)
`Active.Std` is mostly zero in the data — median 0, third quartile 0 — with a small number of rare large values. Those rare values can almost perfectly classify some attacks vs benign, which is what statisticians call *quasi-separation*. When that happens, the model can fit the data perfectly with a wide range of coefficient values, so it picks one but reports a huge standard error meaning "I'm not sure which value is right." Reporting the odds ratio as if it were a stable estimate would be misleading. A different random train/test split could give a completely different number.

### What I added to support this decision
An explanation block in `Logistic.R` that prints right after the separation warning. The runtime output now self-documents what the warning means and the correct way to handle it (report the variable, don't interpret its odds ratio). Anyone re-running the script sees this without having to read the contributions file.

### What this means for the writeup
In the final report, the odds-ratio interpretation should cover the other 10 predictors normally. For `Active.Std`, a single line is enough: *"`Active.Std` was retained in the model but its coefficient is not interpreted due to a quasi-separation warning — the variable is mostly zero in the data, which makes the estimate technically valid but unstable."*

---

## Round 7 — trimmed `Descriptive_Writeup.md` to fit the 2-page limit

The Data Description PDF caps the deliverable at 2 pages. With the variable dictionary added in Round 2, the writeup had grown to about 3 pages.

**What I changed:**
- Replaced the 5-column variable dictionary table with a compact Boston-housing-style paragraph format (one paragraph per category, semicolons between variables). Same information, much denser, matches the format the assignment links.
- Tightened the prose throughout (cut a redundant 2-sentence summary at the end of section 1, condensed the "What did the analysis show" intro lines, dropped the verbose "Files produced" table in favor of an inline list).
- Removed nothing the rubric actually requires — every variable is still described, every analysis finding is still reported, the categorical-relationship test and the response-variable justification both stay.

**Result:** writeup is now ~2 pages when rendered, well under the spec limit, while preserving all required content.
