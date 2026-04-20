# analysis.R - Project Analysis for CICIDS2017
# This script performs initial variable selection using four methods:
# 1. Stepwise with AIC
# 2. Stepwise with BIC
# 3. LASSO Regression (default/lambda.min)
# 4. LASSO Regression (1SE)
# Target: binary 'Attack_Flag' (1 = Attack, 0 = Benign).

library(here)
library(readr)
library(dplyr)
library(glmnet)

# --- 1. Load Data ---
file_list <- list.files(path = here(), pattern = "*.csv", full.names = TRUE)

all_data <- lapply(file_list, function(f) {
  read_csv(f, show_col_types = FALSE, na = c("", "NA", "Infinity", "NaN", "inf", "Inf"))
}) %>% bind_rows()

# Clean column names
colnames(all_data) <- trimws(colnames(all_data))
colnames(all_data) <- make.names(colnames(all_data))

# --- 2. Data Cleaning & Feature Engineering ---
all_data <- all_data %>%
  mutate(Attack_Flag = ifelse(Label == "BENIGN", 0, 1)) %>%
  mutate(across(-matches("Label"), as.numeric)) %>%
  na.omit()

# Sampling
set.seed(42)
sample_size <- 2000 
data_sample <- all_data[sample(nrow(all_data), sample_size), ]

# Prepare features
features <- data_sample %>% select(-Flow.Duration, -Label, -Attack_Flag)
features <- features[, sapply(features, function(x) var(x, na.rm=TRUE) > 0)]

# --- Robustness Check: Remove highly correlated features to fix GLM convergence ---
cor_matrix <- cor(features)
cor_matrix[upper.tri(cor_matrix)] <- 0
diag(cor_matrix) <- 0
to_drop <- apply(cor_matrix, 2, function(x) any(abs(x) > 0.9, na.rm = TRUE))
features_pruned <- features[, !to_drop]

data_modeling <- cbind(Attack_Flag = data_sample$Attack_Flag, features_pruned)

# --- 3. Variable Selection ---

# 3a. Stepwise with AIC (Logistic)
# trace = 0 IS CRITICAL: it suppresses the step-by-step model building spam
base_model <- glm(Attack_Flag ~ 1, data = data_modeling, family = binomial)
full_model <- glm(Attack_Flag ~ ., data = data_modeling, family = binomial)

step_aic <- step(base_model, scope = list(lower = base_model, upper = full_model), 
                 direction = "both", trace = 0, k = 2)

# 3b. Stepwise with BIC (Logistic)
step_bic <- step(base_model, scope = list(lower = base_model, upper = full_model), 
                 direction = "both", trace = 0, k = log(sample_size))

# 3c/d. LASSO Regression (Logistic)
x_matrix <- as.matrix(features_pruned)
y_vector <- data_sample$Attack_Flag
cv_lasso <- cv.glmnet(x_matrix, y_vector, alpha = 1, family = "binomial")

lasso_min_coef <- coef(cv_lasso, s = "lambda.min")
lasso_1se_coef <- coef(cv_lasso, s = "lambda.1se")

# --- 4. Results Summary ---
# We use message() and print() to clearly label the final outputs only
message("\n--- MODEL 1: Stepwise AIC Summary ---")
print(summary(step_aic))

message("\n--- MODEL 2: Stepwise BIC Summary ---")
print(summary(step_bic))

message("\n--- MODEL 3: LASSO (lambda.min) Coefficients ---")
print(lasso_min_coef)

message("\n--- MODEL 4: LASSO (1SE) Coefficients ---")
print(lasso_1se_coef)

# --- 5. Future Work Outline (TODOs) ---

# TODO: Descriptive Statistics: Create visualizations (boxplots/density) for essential features.
# TODO: Relationship Study: Conduct Chi-square tests on flag counts vs Attack_Flag.
# TODO: MLR Section: Fit a model for Flow.Duration using only Benign traffic.
# TODO: Collinearity: Re-check VIF for the selected variables to ensure model stability.
# TODO: Diagnostics: If "perfect separation" persists, investigate specific variables.
# TODO: Validation: Perform a 70/30 split and evaluate classification performance (ROC/AUC).
