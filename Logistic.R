# Logistic.R - Logistic Regression for Attack_Flag prediction
# Response: Attack_Flag (1 = malicious, 0 = benign)
# Data:     glm_data.csv (BIC-selected features exported by setup.R)
#
# Note: requires the pROC package for ROC/AUC.
#   install.packages("pROC")

library(readr)
library(dplyr)
library(car)
library(pROC)

# --- 1. Load Data ---
glm_data <- read_csv("glm_data.csv", show_col_types = FALSE)

message(sprintf("Loaded %d rows, %d columns. Attack rate: %.1f%%",
                nrow(glm_data), ncol(glm_data),
                100 * mean(glm_data$Attack_Flag)))

# --- 2. Train/Test Split (70/30, single seeded index) ---
# One sample() call, used both ways — no risk of train/test overlap.
set.seed(42)
train_idx <- sample(seq_len(nrow(glm_data)), size = floor(0.7 * nrow(glm_data)))
train <- glm_data[train_idx, ]
test  <- glm_data[-train_idx, ]

message(sprintf("Train: %d rows | Test: %d rows", nrow(train), nrow(test)))

# --- 3. Fit Full Logistic Model on Training Set ---
# maxit = 100 (vs the default 25) so update() in the VIF loop also gets enough
# iterations to fully converge. Inherited by all downstream update() calls.
full_model <- glm(Attack_Flag ~ ., data = train, family = binomial,
                  control = glm.control(maxit = 100))
message("\n--- Full Model Summary ---")
print(summary(full_model))

# --- 4. Multicollinearity Check (VIF) with Iterative Pruning ---
message("\n--- VIF (full model) ---")
print(round(vif(full_model), 2))

current_model <- full_model
while (any(vif(current_model) > 5)) {
  v <- vif(current_model)
  drop <- names(which.max(v))
  message(sprintf("Dropping %s (VIF = %.2f)", drop, max(v)))
  current_model <- update(current_model, as.formula(paste(". ~ . -", drop)))
}

final_model <- current_model
message("\n--- Final Model (after VIF pruning) ---")
print(summary(final_model))
message("\n--- VIF (final model) ---")
print(round(vif(final_model), 2))

# --- 4b. Separation Diagnostic ---
# Complete or quasi-complete separation shows up as massive coefficient estimates
# and standard errors. Flag any whose absolute value exceeds 10 — classic
# symptoms even when glm does not print an explicit warning.
sep_summary <- summary(final_model)$coefficients
big_est <- which(abs(sep_summary[, "Estimate"])  > 10)
big_se  <- which(sep_summary[, "Std. Error"]     > 10)
flagged <- union(big_est, big_se)
if (length(flagged) > 0) {
  message("\n--- Separation warning: large coefficients/SEs detected ---")
  message("Some predictors may perfectly identify attacks. Coefficients shown:")
  print(round(sep_summary[flagged, , drop = FALSE], 3))
  message("\nWhat this means in plain language:")
  message("  These predictors have so few non-zero values in the data that the")
  message("  model can split attacks from benign almost perfectly using them.")
  message("  When that happens, the coefficient estimate is technically valid")
  message("  but very unstable -- a different random train/test split could")
  message("  produce a wildly different number.")
  message("\nHow we handle it:")
  message("  We KEEP these predictors in the model (they still help the")
  message("  classifier's overall performance), but we DO NOT interpret their")
  message("  odds ratios. Report them as 'flagged for separation -- estimate")
  message("  not interpreted.'")
} else {
  message("\nNo separation indicators -- coefficients and standard errors are well-behaved.")
}

# --- 5. Overall Model Significance (Likelihood Ratio Test) ---
lr_stat <- final_model$null.deviance - final_model$deviance
lr_df   <- final_model$df.null - final_model$df.residual
lr_p    <- pchisq(lr_stat, lr_df, lower.tail = FALSE)
message(sprintf("\nLikelihood ratio test: chi-sq = %.2f on %d df, p = %.3e",
                lr_stat, lr_df, lr_p))

# --- 6. Predict on Test Set ---
# train and test came from the same glm_data, so columns match — no subsetting needed.
test_probs <- predict(final_model, newdata = test, type = "response")

# --- 7. ROC Curve and AUC ---
roc_obj <- roc(test$Attack_Flag, test_probs, quiet = TRUE)
auc_val <- as.numeric(auc(roc_obj))
message(sprintf("\nTest AUC: %.4f", auc_val))

pdf("logistic_roc.pdf", width = 7, height = 7)
plot(roc_obj, main = sprintf("ROC Curve (AUC = %.3f)", auc_val),
     col = "steelblue", lwd = 2)
abline(a = 0, b = 1, lty = 2, col = "gray60")
dev.off()
message("Saved ROC curve to logistic_roc.pdf")

# --- 8. Classification Metrics ---
compute_metrics <- function(cm) {
  TP <- cm["1", "1"]; TN <- cm["0", "0"]
  FP <- cm["1", "0"]; FN <- cm["0", "1"]
  list(
    accuracy    = (TP + TN) / sum(cm),
    sensitivity = TP / (TP + FN),     # recall on attacks
    specificity = TN / (TN + FP),
    precision   = TP / (TP + FP),
    f1          = 2 * TP / (2 * TP + FP + FN)
  )
}

print_metrics <- function(label, m) {
  message(sprintf("%s | Acc: %.3f  Sens: %.3f  Spec: %.3f  Prec: %.3f  F1: %.3f",
                  label, m$accuracy, m$sensitivity, m$specificity,
                  m$precision, m$f1))
}

# 8a. Default cutoff = 0.5
preds_05 <- ifelse(test_probs > 0.5, 1, 0)
cm_05 <- table(predicted = factor(preds_05, levels = c(0, 1)),
               actual    = factor(test$Attack_Flag, levels = c(0, 1)))
message("\n--- Confusion Matrix (cutoff = 0.5) ---")
print(cm_05)
print_metrics("cutoff 0.5", compute_metrics(cm_05))

# 8b. Youden-optimal cutoff (maximizes sensitivity + specificity)
opt <- coords(roc_obj, "best", best.method = "youden", transpose = FALSE)
opt_cut <- as.numeric(opt$threshold[1])
preds_opt <- ifelse(test_probs > opt_cut, 1, 0)
cm_opt <- table(predicted = factor(preds_opt, levels = c(0, 1)),
                actual    = factor(test$Attack_Flag, levels = c(0, 1)))
message(sprintf("\n--- Confusion Matrix (Youden-optimal cutoff = %.3f) ---", opt_cut))
print(cm_opt)
print_metrics(sprintf("cutoff %.3f", opt_cut), compute_metrics(cm_opt))

# --- 9. Coefficient Interpretation (Odds Ratios) ---
# Use Wald-based CIs (confint.default) rather than profile-likelihood (confint).
# Wald is standard for large-sample logistic regression and avoids the
# convergence-sensitive profile search that the default uses.
odds_ratios <- exp(coef(final_model))
or_ci <- exp(confint.default(final_model))

or_table <- data.frame(
  Predictor  = names(odds_ratios),
  OR         = round(odds_ratios, 4),
  CI_lower   = round(or_ci[, 1], 4),
  CI_upper   = round(or_ci[, 2], 4),
  Pct_Change = round(100 * (odds_ratios - 1), 1),
  row.names  = NULL
)

message("\n=== ODDS RATIOS (per 1-unit increase in predictor) ===")
message("Pct_Change interprets the OR as a percent change in odds of an attack.")
print(or_table)

# --- 10. Practical Significance: Standardized Odds Ratios ---
# Per-unit odds ratios above are not directly comparable across predictors
# because a unit of Destination.Port is not the same kind of thing as a unit of
# Down.Up.Ratio. Re-fit on standardized predictors so each odds ratio describes
# a 1-SD change. Mirrors the scaled-coefficient block in Linear.R.

final_terms  <- setdiff(names(coef(final_model)), "(Intercept)")
train_scaled <- train[, c("Attack_Flag", final_terms), drop = FALSE]
train_scaled[, final_terms] <- as.data.frame(scale(train_scaled[, final_terms]))

final_model_scaled <- glm(Attack_Flag ~ ., data = train_scaled, family = binomial,
                          control = glm.control(maxit = 100))

or_scaled          <- exp(coef(final_model_scaled))[-1]
pct_change_scaled  <- 100 * (or_scaled - 1)
pct_change_display <- round(pct_change_scaled, 1)

# Classify off the rounded (displayed) value so the table is internally
# consistent: anything that prints as +/-100.0 or larger is LARGE. This avoids
# the floating-point trap where exp(very_negative) yields e.g. -99.9999975
# which displays as -100.0 but technically has abs < 100.
practical_class <- ifelse(abs(pct_change_display) >= 100, "LARGE",
                   ifelse(abs(pct_change_display) >   25, "moderate",
                   ifelse(abs(pct_change_display) >    5, "small", "trivial")))

practical_table <- data.frame(
  Predictor          = names(or_scaled),
  OR_per_SD          = round(or_scaled, 3),
  Pct_Change_per_SD  = pct_change_display,
  Practical          = practical_class,
  row.names          = NULL
)

message("\n=== STANDARDIZED ODDS RATIOS (per 1-SD change in predictor) ===")
message("Class scale: LARGE > 100% | moderate 25-100% | small 5-25% | trivial < 5%")
print(practical_table)

message("\n=== Logistic regression complete ===")
