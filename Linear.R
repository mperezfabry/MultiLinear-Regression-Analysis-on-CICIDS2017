# Linear.R - Multiple Linear Regression for Flow.Bytes prediction

library(readr)
library(dplyr)
library(ggplot2)
library(car)

# Load data
mlr_data <- read_csv("mlr_data.csv", show_col_types = FALSE)

# --- 1. Fit the MLR Model ---

mlr_model <- lm(Flow.Bytes ~ ., data = mlr_data)

summary(mlr_model)

# Overall F-test (validates the model as a whole)
anova(mlr_model)

# --- 2. Hypothesis Tests ---

# Coefficient t-tests are in summary(mlr_model)
# Overall F-test is in summary(mlr_model) and anova()

# Individual coefficient tests
confint(mlr_model, level = 0.95)

# --- 3. Multicollinearity Check (VIF) ---

vif_values <- car::vif(mlr_model)
print(vif_values)

# VIF > 5 or 10 indicates problematic multicollinearity
message("\n--- VIF Summary ---")
message(sprintf("Max VIF: %.2f", max(vif_values)))
if (any(vif_values > 5)) {
  message("WARNING: Some predictors have VIF > 5, indicating moderate multicollinearity")
} else {
  message("All VIF values are below 5 — multicollinearity is not a concern")
}

# --- 4. Assumption Diagnostics ---

# --- 4a. Linearity & Homoscedasticity (Residuals vs Fitted, plot=1) ---

par(mfrow = c(2, 2))
plot(mlr_model, which = 1, main = "Residuals vs Fitted\n(Linearity & Homoscedasticity)")
abline(h = 0, col = "red", lty = 2)

# Formal test for heteroscedasticity
ncv_test <- car::ncvTest(mlr_model)
print(ncv_test)

# --- 4b. Normality of Residuals (Q-Q plot, plot=2) ---

plot(mlr_model, which = 2, main = "Normal Q-Q\n(Normality of Residuals)")

# Formal normality tests
shapiro_test <- shapiro.test(residuals(mlr_model))
print(shapiro_test)

# If sample is large, Shapiro may be overly sensitive — also check visually

# --- 4c. Scale-Location plot (plot=3) ---

plot(mlr_model, which = 3, main = "Scale-Location\n(Constant Variance)")

# --- 4d. Residuals vs Leverage (plot=5) ---

plot(mlr_model, which = 5, main = "Residuals vs Leverage\n(Influential Points)")

# --- 5. Influence Diagnostics ---

# Cook's distance
cooksd <- cooks.distance(mlr_model)
influential_obs <- which(cooksd > 4 / nrow(mlr_data))
message("\n--- Influence Diagnostics ---")
message(sprintf("Observations with Cook's distance > 4/n: %s",
                if (length(influential_obs) > 0) paste(influential_obs, collapse = ", ") else "None"))

# Leverage (hat values)
hat_values <- hatvalues(mlr_model)
high_leverage <- which(hat_values > 2 * length(coef(mlr_model)) / nrow(mlr_data))
message(sprintf("High leverage points (> 2p/n): %s",
                if (length(high_leverage) > 0) paste(high_leverage, collapse = ", ") else "None"))

# DFBETAS
dfbetas_vals <- dfbetas(mlr_model)
large_dfbetas <- which(abs(dfbetas_vals) > 2 / sqrt(nrow(mlr_data)), arr.ind = TRUE)
message(sprintf("Large DFBETAS (> 2/sqrt(n)): %d instances", nrow(large_dfbetas)))

# Studentized residuals (planning doc calls these out explicitly)
rstud <- rstudent(mlr_model)
extreme_rstud <- which(abs(rstud) > 3)
message(sprintf("Studentized residuals |rstudent| > 3: %s",
                if (length(extreme_rstud) > 0) paste(extreme_rstud, collapse = ", ") else "None"))

par(mfrow = c(1, 1))

# --- 6. Model Fit Summary ---

message("\n=== FINAL MLR MODEL SUMMARY ===")
message(sprintf("R-squared: %.4f", summary(mlr_model)$r.squared))
message(sprintf("Adjusted R-squared: %.4f", summary(mlr_model)$adj.r.squared))
message(sprintf("F-statistic: %.2f on %d and %d DF, p-value: < %.2e",
                summary(mlr_model)$fstatistic[1],
                summary(mlr_model)$fstatistic[2],
                summary(mlr_model)$fstatistic[3],
                pf(summary(mlr_model)$fstatistic[1],
                   summary(mlr_model)$fstatistic[2],
                   summary(mlr_model)$fstatistic[3],
                   lower.tail = FALSE)))

message("\n=== COEFFICIENTS ===")
print(coef(summary(mlr_model)))

# --- 7. Scaled Coefficients (Relative Importance) ---
# Re-fit on standardized predictors so coefficient sizes are directly comparable.
# With raw predictors, |beta| depends on units (bytes vs counts vs microseconds),
# so a big coefficient can just mean a small-unit variable. Scaling fixes that.

predictor_names <- setdiff(names(mlr_data), "Flow.Bytes")
mlr_scaled <- mlr_data
mlr_scaled[predictor_names] <- scale(mlr_data[predictor_names])

mlr_model_scaled <- lm(Flow.Bytes ~ ., data = mlr_scaled)

scaled_coefs <- coef(summary(mlr_model_scaled))[-1, , drop = FALSE]  # drop intercept
ranked <- scaled_coefs[order(-abs(scaled_coefs[, "Estimate"])), , drop = FALSE]

message("\n=== STANDARDIZED COEFFICIENTS (Ranked by |Effect|) ===")
message("A 1-SD increase in the predictor changes Flow.Bytes by this many bytes,")
message("holding all other predictors constant.")
print(round(ranked, 2))

# --- 8. Practical vs. Statistical Significance ---
# With n ~ 1600, even tiny effects produce tiny p-values. Practical significance
# asks: is the effect big enough to care about? We compare each scaled effect
# to the SD of Flow.Bytes itself.

response_mean <- mean(mlr_data$Flow.Bytes)
response_sd   <- sd(mlr_data$Flow.Bytes)

message(sprintf("\nFlow.Bytes  mean: %.0f bytes   SD: %.0f bytes",
                response_mean, response_sd))

practical_table <- data.frame(
  Predictor          = rownames(ranked),
  Scaled_Beta_bytes  = round(ranked[, "Estimate"], 1),
  Pct_of_Response_SD = round(100 * abs(ranked[, "Estimate"]) / response_sd, 2),
  p_value            = signif(ranked[, "Pr(>|t|)"], 3),
  row.names          = NULL
)

message("\n=== PRACTICAL SIGNIFICANCE TABLE ===")
message("Pct_of_Response_SD = how much a 1-SD predictor change moves Flow.Bytes,")
message("                    expressed as a % of the response's SD.")
message("Rule of thumb: < ~1% is statistically significant but practically trivial.")
print(practical_table)

# --- 9. Robustness Check: Log-Transformed Response ---
# The diagnostics in section 4 flag heteroscedasticity (ncv test) and non-normal
# residuals (Shapiro). Per the planning doc, try log(Flow.Bytes + 1) to see
# whether a log transform improves the assumption fit. We use log1p so flows
# with zero bytes (empty handshakes) do not produce -Inf.

mlr_data_log <- mlr_data
mlr_data_log$Flow.Bytes <- log1p(mlr_data$Flow.Bytes)

mlr_model_log <- lm(Flow.Bytes ~ ., data = mlr_data_log)

ncv_log     <- car::ncvTest(mlr_model_log)
shapiro_log <- shapiro.test(residuals(mlr_model_log))

message("\n=== LOG-TRANSFORMED MODEL (Robustness Check) ===")
message(sprintf("Log model R-squared: %.4f   (raw model: %.4f)",
                summary(mlr_model_log)$r.squared,
                summary(mlr_model)$r.squared))
message(sprintf("Heteroscedasticity (ncv) -- raw: p = %.3e | log: p = %.3e",
                ncv_test$p, ncv_log$p))
message(sprintf("Normality   (Shapiro)    -- raw: W = %.3f, p = %.3e | log: W = %.3f, p = %.3e",
                shapiro_test$statistic, shapiro_test$p.value,
                shapiro_log$statistic, shapiro_log$p.value))

message("\nNote: the log transform is offered as a robustness check. The raw model")
message("stays as the primary specification because its coefficients are in direct")
message("byte units and easy to interpret. If diagnostics on the log model are")
message("dramatically better in the printout above, consider switching.")
