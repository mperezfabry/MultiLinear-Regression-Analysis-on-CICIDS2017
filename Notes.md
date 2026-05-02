# Project Notes

## 05/02/2026 — Major Refactor

**What changed:**
- `analysis.R` renamed to `setup.R` — now handles data loading, sampling (~250 rows/file), variable selection via Stepwise BIC for two separate feature sets, and exports cleaned CSVs.
- **MLR feature set** (Linear Stepwise BIC, response = `Flow.Bytes`, benign traffic only): 8 features selected — `act_data_pkt_fwd`, `PSH.Flag.Count`, `Avg.Bwd.Segment.Size`, `Bwd.Packet.Length.Std`, `Bwd.Packet.Length.Min`, `min_seg_size_forward`, `Active.Std`, `Active.Max`
- **Logistic feature set** (Logistic Stepwise BIC, response = `Attack_Flag`, all traffic): 13 features selected — `Fwd.Packet.Length.Min`, `Packet.Length.Variance`, `Avg.Fwd.Segment.Size`, `URG.Flag.Count`, `Active.Std`, `Down.Up.Ratio`, `Destination.Port`, `Idle.Min`, `Avg.Bwd.Segment.Size`, `Bwd.IAT.Total`, `Init_Win_bytes_backward`, `PSH.Flag.Count`, `Bwd.IAT.Max`
- `README.md` updated to reflect current structure
- Exported datasets: `mlr_data.csv` (1611 rows, 9 cols), `glm_data.csv` (1997 rows, 14 cols, ~19% attack rate)

**Script execution order:**
```
setup.R → Descriptive.R → Linear.R → Logistic.R
```

## Work Assignments

**Harold - Descriptive Statistics** — `Descriptive.R`
- Summary statistics, boxplots, density plots
- Compare distributions between benign and attack traffic
- Correlation analysis

**** — pick one of the following:

**Samanth - Logistic Regression** — `Logistic.R`
- Fit glm using `glm_data.csv` (Attack_Flag as response)
- 70/30 train/test split
- Evaluate: ROC/AUC, confusion matrix
- Check VIF for collinearity
- Model diagnostics

**Michael - Linear Regression** — `Linear.R`
- Fit lm using `mlr_data.csv` (Flow.Bytes as response, benign only)
- Check assumptions: normality, homoscedasticity, linearity
- Check VIF for collinearity
- Residual diagnostics, leverage, influence

Run `source("setup.R")` first to regenerate the CSVs if needed.

---

# Variable Selection (Legacy — superseded by Stepwise BIC)

## Stepwise AIC (19 variables retained): 
AIC is relatively lenient with its penalty for adding variables. It kept 19 features, but if you look at the coefficient output, variables like Fwd.IAT.Mean ($p = 0.104$) and Flow.IAT.Min ($p = 0.119$) are not statistically significant at standard alpha levels. AIC kept them because they marginally improved the deviance of the model, but they are essentially noise.

## Stepwise BIC (15 variables retained):
BIC hits the model with a heavier penalty for complexity based on your sample size. It pruned the model down to 15 features. Notice the Pr(>|z|) column in the BIC output: every single variable retained is highly significant, with most having p-values well below 0.001.

## LASSO lambda.min (26 variables retained):
This method prioritized absolute predictive accuracy during cross-validation. It shrunk the coefficients of highly collinear variables to prevent the model from blowing up, but it still kept 26 variables, many of which likely have tiny, marginal effects (notice the incredibly small coefficients like -3.19e-06).

## LASSO lambda.1se (21 variables retained):
A more aggressive penalty than lambda.min, bringing the feature count down to 21. It completely zeroed out features like Flow.Bytes.s and ACK.Flag.Count that lambda.min retained.

## Final Result of Variable Selection:
My preference would be to use the set of 15 variables selected by BIC. They are significant, and fewer, more stable, and easier to interpret than the penalized LASSO versions. Keep it as straightforward as possible.
