# analysis.R - Project Analysis for CICIDS2017
# This script performs variable selection using two separate Stepwise BIC approaches:
# 1. Linear Stepwise BIC for MLR -> Target: Flow.Bytes (benign traffic only)
# 2. Logistic Stepwise BIC for Logistic Regression -> Target: Attack_Flag (binary)

library(here)
library(readr)
library(dplyr)
library(ggplot2)

# --- 1. Load Data (sample only, all_data too large for memory) ---
script_dir <- if (interactive() && requireNamespace("rstudioapi", quietly = TRUE)) {
  dirname(rstudioapi::getSourceEditorContext()$path)
} else {
  here::here()
}
file_list <- list.files(path = script_dir, pattern = "\\.csv$", full.names = TRUE)

set.seed(42)
sample_per_file <- 250

sample_data <- lapply(file_list, function(f) {
  df <- read_csv(f, show_col_types = FALSE, na = c("", "NA", "Infinity", "NaN", "inf", "Inf"))
  if (nrow(df) > sample_per_file) {
    df <- df[sample(nrow(df), sample_per_file), ]
  }
  df
}) %>% bind_rows()

# Clean column names
colnames(sample_data) <- trimws(colnames(sample_data))
colnames(sample_data) <- make.names(colnames(sample_data))

# --- 2. Data Cleaning & Feature Engineering ---
sample_data <- sample_data %>%
  mutate(Attack_Flag = ifelse(Label == "BENIGN", 0, 1)) %>%
  mutate(across(-matches("Label"), as.numeric)) %>%
  na.omit()

# Create Flow.Bytes from total forward + backward packet lengths
sample_data <- sample_data %>%
  mutate(Flow.Bytes = Total.Length.of.Fwd.Packets + Total.Length.of.Bwd.Packets)

summary(sample_data)

# --- 3. Variable Selection ---

# --- 3a. MLR Feature Set: Linear Stepwise BIC for Flow.Bytes ---

benign_sample <- sample_data[sample_data$Attack_Flag == 0, ]

mlr_features <- benign_sample %>%
  select(-Flow.Duration, -Label, -Attack_Flag, -Flow.Bytes, -Flow.Bytes.s, -Flow.Packets.s)
mlr_features <- mlr_features[, sapply(mlr_features, function(x) var(x, na.rm = TRUE) > 0)]

cor_matrix_mlr <- cor(mlr_features)
cor_matrix_mlr[upper.tri(cor_matrix_mlr)] <- 0
diag(cor_matrix_mlr) <- 0
to_drop_mlr <- apply(cor_matrix_mlr, 2, function(x) any(abs(x) > 0.9, na.rm = TRUE))
mlr_features_pruned <- mlr_features[, !to_drop_mlr]

mlr_data <- cbind(Flow.Bytes = benign_sample$Flow.Bytes, mlr_features_pruned)

base_mlr  <- lm(Flow.Bytes ~ 1, data = mlr_data)
full_mlr  <- lm(Flow.Bytes ~ ., data = mlr_data)

step_mlr_bic <- step(base_mlr, scope = list(lower = base_mlr, upper = full_mlr),
                     direction = "both", trace = 0, k = log(nrow(mlr_data)))

mlr_selected_features <- setdiff(names(coef(step_mlr_bic)), "(Intercept)")

message("\n--- MLR Feature Set (Linear Stepwise BIC for Flow.Bytes) ---")
message(sprintf("Selected %d features:", length(mlr_selected_features)))
message(paste(mlr_selected_features, collapse = ", "))

# --- 3b. Logistic Regression Feature Set: Logistic Stepwise BIC for Attack_Flag ---

log_features <- sample_data %>% select(-Flow.Duration, -Label, -Attack_Flag, -Flow.Bytes, -Flow.Bytes.s, -Flow.Packets.s)
log_features <- log_features[, sapply(log_features, function(x) var(x, na.rm = TRUE) > 0)]

cor_matrix_log <- cor(log_features)
cor_matrix_log[upper.tri(cor_matrix_log)] <- 0
diag(cor_matrix_log) <- 0
to_drop_log <- apply(cor_matrix_log, 2, function(x) any(abs(x) > 0.9, na.rm = TRUE))
log_features_pruned <- log_features[, !to_drop_log]

log_data <- cbind(Attack_Flag = sample_data$Attack_Flag, log_features_pruned)

base_log  <- glm(Attack_Flag ~ 1, data = log_data, family = binomial)
full_log  <- glm(Attack_Flag ~ ., data = log_data, family = binomial)

step_log_bic <- step(base_log, scope = list(lower = base_log, upper = full_log),
                     direction = "both", trace = 0, k = log(nrow(log_data)))

log_selected_features <- setdiff(names(coef(step_log_bic)), "(Intercept)")

message("\n--- Logistic Feature Set (Logistic Stepwise BIC for Attack_Flag) ---")
message(sprintf("Selected %d features:", length(log_selected_features)))
message(paste(log_selected_features, collapse = ", "))

# --- 4. Build Final Datasets with Selected Features ---

mlr_final <- benign_sample %>%
  select(all_of(c("Flow.Bytes", mlr_selected_features)))

glm_final <- sample_data %>%
  select(all_of(c("Attack_Flag", log_selected_features)))

write_csv(mlr_final, "mlr_data.csv")
write_csv(glm_final, "glm_data.csv")

message("\n=== DATASETS EXPORTED ===")
message(sprintf("mlr_data.csv: %d rows, %d columns", nrow(mlr_final), ncol(mlr_final)))
message(sprintf("glm_data.csv: %d rows, %d columns", nrow(glm_final), ncol(glm_final)))
