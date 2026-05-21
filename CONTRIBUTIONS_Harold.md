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

---

## Round 8 — Full rubric revision of the presentation deck

After the professor sent back slide-by-slide feedback on the preliminary deck, I went through every comment and worked through 12 revision passes until every single point was addressed. The final version is **`Harold's Presentation Revisions.pptx`** — 16 slides, all 17 of the professor's feedback notes closed.

### What changed, mapped to the prof's notes

**Slide 2 — Setup.** Prof said "very nice setup" — kept as-is.

**Slide 3 — Variable Grouping (NEW slide).** Prof asked for a slide describing variable groupings briefly. Added one listing every MLR and logistic predictor with a one-line definition.

**Slide 4 — Descriptive Statistics.**
- Toned down the "attack tails are heavier" framing the prof pushed back on. New title: *"Benign and attack distributions overlap — but their tails diverge."*
- Added a 3×6 numerical table with benign vs attack means, medians, and SDs for the three density variables — answers the prof's question about whether the densities actually have area = 1.
- New caption: attacks are bimodal — most flows cluster near zero, but a small subset reaches extreme right-tail values. For `Destination.Port`, the benign tail is actually heavier than the attack tail (benign 99th percentile = 61,502 vs attack 99th = 50,047).

**Slide 5 — Chi-square.** Kept as-is (prof allowed it even though not required).

**Slide 6 — Variable Selection.**
- Prof asked *"how did you get from 80 columns down to 9?"* Added a 5-chip pipeline: 79 raw → numeric + non-degenerate → \|r\| > 0.9 prune → stepwise BIC (8 MLR / 13 logistic) → VIF prune (11 logistic final). Added a small footnote noting that the intermediate counts (after zero-variance drop and correlation prune) aren't reported because the raw CICIDS files live on a teammate's drive, but the endpoints (79, 8, 13, 11) are exact.
- Removed `Flow.Bytes` from the MLR predictor correlation matrix — prof flagged this; `Flow.Bytes` is the response, shouldn't be sitting in the predictor matrix.
- Replaced the old base-R `heatmap()` plots with clean high-DPI versions. Each cell now shows the actual correlation value (e.g., 0.82 between `Bwd.Packet.Length.Std` and `Avg.Bwd.Segment.Size`, 0.75 between `Active.Max` and `Active.Std`). The "intense pockets of correlation" claim on the slide now has concrete numbers backing it up.
- Corrected the logistic matrix label from "PRE-BIC" to "POST-BIC, PRE-VIF" since 13 predictors is the *output* of stepwise BIC, not the input.

**Slide 7 — VIF check.**
- Prof said the class threshold is < 5, not 10. Added a caveat callout explaining that `Bwd.Packet.Length.Std` (VIF = 6.83) and `Avg.Bwd.Segment.Size` (VIF = 5.94) sit above the class threshold of 5 but below the broader rule-of-thumb of 10. Documented our decision to keep them — they're substantively meaningful and dropping them hurts the fit — as a known caveat.
- Updated the variable name in the code block from `mlr_model` to `m1` to match Michael's rewritten `Linear.R`.

**Slide 8 — Diagnostics.**
- Prof said *"don't blame the funnel — do Cook's analysis first."* Reframed the slide around outliers and non-normality. Cook's distance plot is now front-and-center.
- Added a console-style code block showing the actual Row 1198 data: `Flow.Bytes` = 10,716,095 vs second-largest 977,134 (11× the next value), Z-score = 312.81. Directly answers the prof's "show the rows" request.

**Slide 9 — Model Repair.**
- Prof asked for non-transformed diagnostic plots with the outliers removed first. Slide now has two rows of plots: top row is raw-scale after dropping Row 1198, bottom row is the `log1p(Flow.Bytes)` transform. The case for the transform is now visible from the plots themselves.
- Prof said no need for scale-location or residuals-vs-leverage plots. Both rows now use only Residuals vs Fitted, Q-Q, and Cook's distance.

**Slide 10 — Final Model (NEW slide).** Prof wanted raw `summary()` output on the left, takeaways on the right. New slide shows raw `summary(m_log)` and `summary(m_final)` printouts plus a Key Takeaways rail with R² = 0.6889, F = 354 on 10 and 1599 DF, the polynomial term info, and the +12 percentage points gained from adding curvature.

**Slide 11 — Interpretation.** Kept the 95% CI image. Added the concave-effect interpretation: peak marginal effect at 798.6 bytes, then the effect flips sign past that threshold.

**Slide 12 — Logistic Setup.** Removed the train/test block (prof said move it to the performance slide). Kept the partial-separation alert.

**Slide 13 — GLM Formulation (NEW slide).** Prof asked for a full GLM formulation for binary logistic regression. New slide with the formal logit equation (`log(p / (1 − p)) = β₀ + β₁x₁ + ⋯`), the binomial assumption, and the predictor glossary listing all 11 retained variables.

**Slide 14 — Performance.**
- Moved the train/test split to the top of this slide (was on Slide 12).
- On a self-review I caught that the marquee metrics were mixing classification rules — accuracy from cutoff 0.5, sensitivity from Youden's-optimal. The professor didn't flag this but it would have come up in the oral exam. Switched all three metrics to Youden's-optimal cutoff so they describe one coherent rule:
  - Accuracy 90.3%
  - Sensitivity 95.3%
  - Specificity 89.0%
- Added a footnote with the cutoff-0.5 metrics (acc 91.2%, sens 78.9%, spec 94.5%) for transparency.

**Slide 15 — Coefficient Interpretation.** Prof wanted raw `summary()` on the left, signals on the right. Pasted the full `summary(final_model)` output (Call, Coefficients table with estimates / SEs / z-values / p-values, Null/Residual deviance, AIC, Fisher iterations) on the left. Kept the High-Risk / Protective signal cards on the right.

**After-Slide-12 note — Logistic CIs.** Prof asked for confidence intervals for the logistic regression. Added inline 95% CIs to the high-risk signal cards on Slide 15 (e.g., `Idle.Min` +319.3% [+178.4%, +562.8%], `Down.Up.Ratio` +187.8% [+96.2%, +325.7%]). The MLR side already had `confint()` output on Slide 11.

**Slide 16 — Conclusions.**
- Prof asked us to quantify "Normal traffic volume is highly predictable" with actual numbers. Updated the Phase 1 paragraph to include R² = 0.69 and RSE ≈ 1.53 on the log scale.
- Updated the Phase 2 paragraph to match Slide 14's new metrics: "isolate attacks with 95.3% sensitivity at the Youden's-optimal cutoff (accuracy 90.3%, AUC = 0.9625)."

### Verification I did

For every number on the deck I cross-checked it against the actual project data, not just trusted what was there:

- **Slide 4 table:** all 18 values computed directly from `glm_data.csv` (1,997 rows; 386 attacks, 1,611 benign).
- **Slide 8 Row 1198:** verified against `mlr_data.csv` row 1198. Flow.Bytes = 10,716,095, exactly matches; Z-score 312.81, exactly matches.
- **Slide 10:** R² = 0.6889 and F = 354 on 10 and 1599 DF, verified against `summary(m_final)`. Pre-polynomial R² = 0.5686 from `summary(m_log)`. The +12 pp gain checks out arithmetically.
- **Slide 14:** Youden's-optimal metrics verified against `cm_opt` in my R workspace — accuracy 0.9033 → 90.3%, sensitivity 0.9531 → 95.3%, specificity 0.8898 → 89.0%. Default-cutoff footnote verified against `cm_05`.
- **Slide 15:** the full `summary(final_model)` printout pulled directly from my RStudio session. Confirmed `URG.Flag.Count` estimate = −8.177784e+00 (the z-value is negative, so the estimate must be negative — math has to be consistent).
- **Slide 6 correlation matrices:** rebuilt from `mlr_data.csv` and `glm_data.csv`. All cell values match the rendered heatmaps.

### Internal consistency checks

After all the changes landed, I verified the deck doesn't contradict itself anywhere:
- Slide 3's intro ("8 MLR / 13 logistic, pruned to 11 via VIF") matches the predictor lists shown.
- Slide 6's pipeline endpoints (79 → 8 / 13 → 11) match what `setup.R` outputs and what `Logistic.R` prunes to.
- Slide 12's "11 predictors" matches Slide 13's glossary count.
- Slide 15's deviance math (Null 1336.70 − Residual 458.46 = 878.24) matches Slide 14's likelihood-ratio χ² = 878.25 (rounding).
- Slide 15's residual df = 1397 − 11 − 1 = 1385 matches what `summary()` prints.
- Slide 14's Youden's metrics match Slide 16's conclusion sentence.

### Bottom line

Every original feedback point from the professor's notes now maps to a concrete fix in the deck. The internal references all stay consistent — anyone reading the deck without the feedback letter in hand sees a coherent statistical narrative end-to-end: data → variable selection → MLR (with diagnostics and repair) → logistic (with formulation, performance, and interpretation) → conclusions.

---

## Round 9 — Closing the last professor follow-ups (Slides 9 and 10)

After Round 8 went out, the professor came back with two more specific notes — both about the MLR diagnostic story.

### What the professor said

1. *"On Slide 9, 'residuals now spread evenly around 0' — they simply don't."* The wording overclaimed what the log transform actually accomplished — the residuals at that stage still showed clear curvature.
2. *"You address it on the next slide with the polynomial terms, but you don't end up showing the residuals-vs-fitted plot for the polynomial fit."* — the diagnostic plot proving the polynomials worked was missing from Slide 10. Earlier deck versions had it; somewhere in the design iterations it got dropped.

### What I changed in this round

**Slide 9 — softened the bottom-panel caption.**
The old caption claimed the log transform produced even residuals, which the plot itself contradicted. The new caption is honest:
> *"The log transform tames the worst tail behavior and partially straightens the Q‑Q line — but residuals vs fitted still show clear curvature. The polynomial terms added on Slide 10 substantially reduce both — though some residual structure remains."*

The "substantially reduce both — though some residual structure remains" phrasing flows directly into Slide 10's argument without overclaiming the log fix.

**Slide 10 — restored the polynomial diagnostic plot and rewrote its caption.**
Pulled the `m_final` diagnostic triptych (Residuals vs Fitted, Q-Q, Cook's Distance) back into Slide 10. With the plot now visible, I went back and read it carefully. Three things are clear from it:
- A downward LOWESS trend in the residuals — they're not random scatter
- A heavy left tail in the Q-Q plot (one observation around standardized residual −6)
- Two observations (627 and 1041) with Cook's distance above 1.0 — the textbook influence threshold

So the original "the repair is complete" caption was wrong. I rewrote it to be honest:
> *"After the polynomial terms, residual curvature is much milder and Cook's distance dropped from ~5,800 to ~1.2 — a substantial improvement. Some downward trend in residuals, a heavy left tail, and two points (627, 1041) with Cook's > 1 still remain. We treat this as a partial, not complete, repair."*

### Why this matters

The professor's feedback pattern has been consistent: they don't penalize honest caveats, but they catch every unsupported claim. By softening both captions and putting the polynomial diagnostic plot back in, the deck now matches what the plots actually show. The "is your final model fixed?" oral-exam answer becomes much more defensible:

*"It's substantially improved — Cook's distance dropped from ~5,800 to ~1.2 and residual curvature is much milder. But we treat it as a partial repair: there's still a mild downward trend, a heavy left tail, and two observations with Cook's > 1 worth investigating before we'd deploy the model in a real-world setting."*

### State of the deck after this round

All 17 of the professor's original feedback points are still met (no regressions). The two new feedback notes from this round are now also addressed. Internal continuity between Slide 9 and Slide 10 is fixed — they now tell the same story (substantial repair, not complete) instead of contradicting each other.

The deck is ready to present.
