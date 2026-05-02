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
