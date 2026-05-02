# Project Notes

## 05/02/2026 — Multiple Linear Regression Results

**File:** `Linear.R`

**Model:** `Flow.Bytes ~ act_data_pkt_fwd + PSH.Flag.Count + Avg.Bwd.Segment.Size + Bwd.Packet.Length.Std + Bwd.Packet.Length.Min + min_seg_size_forward + Active.Std + Active.Max`

**Sample:** 1611 benign flows (attack traffic excluded)

### Model Fit
- **R² = 0.9911**, Adjusted R² = 0.9911
- **F(8, 1602) = 22,378.72**, p < 2.2e-16 — the model as a whole is highly significant
- Residual standard error: 25,400 bytes

### Coefficient Significance
All 8 predictors are statistically significant at α = 0.05:

| Predictor | Estimate | t-value | p-value |
|---|---|---|---|
| act_data_pkt_fwd | 4038.97 | 394.28 | < 2e-16 |
| PSH.Flag.Count | -12563.32 | -5.76 | 9.84e-09 |
| Avg.Bwd.Segment.Size | 55.48 | 10.63 | < 2e-16 |
| Bwd.Packet.Length.Std | -48.03 | -8.01 | 2.12e-15 |
| Bwd.Packet.Length.Min | -55.13 | -5.97 | 2.97e-09 |
| min_seg_size_forward | 652.13 | 6.35 | 2.79e-10 |
| Active.Std | -0.0286 | -5.13 | 3.26e-07 |
| Active.Max | 0.0045 | 3.10 | 0.002 |

**Key finding:** `act_data_pkt_fwd` is by far the strongest predictor of flow bytes — each additional active data packet forwarded increases flow size by ~4039 bytes on average.

### Multicollinearity (VIF)
- Max VIF = 6.62 (`Bwd.Packet.Length.Std`) — moderate multicollinearity, but acceptable (below 10)
- Remaining VIFs range from 1.01 to 5.24

### Assumption Diagnostics
- **Heteroscedasticity (ncv test):** χ² = 1045.36, p < 2.2e-16 — significant heteroscedasticity detected. This is expected with network traffic data where larger flows naturally have more variance.
- **Normality (Shapiro-Wilk):** W = 0.405, p < 2.2e-16 — residuals are not normally distributed. Again, this is typical for large n and heavy-tailed traffic data. The Q-Q plot shows deviations at the tails.
- **Influence points:** 68 observations exceed the Cook's distance threshold of 4/n, and 81 points show high leverage. These are likely very large flows and warrant attention when interpreting the model.

### Conclusion
The MLR model explains 99.1% of variance in Flow.Bytes for benign traffic. While assumption checks reveal heteroscedasticity and non-normality (common with this type of data), the model is highly significant and all predictors are meaningful.

---

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
