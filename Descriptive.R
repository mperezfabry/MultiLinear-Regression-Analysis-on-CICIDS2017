# Descriptive.R - Descriptive Statistics and Visualizations

library(readr)
library(dplyr)
library(ggplot2)

# Load data
mlr_data <- read_csv("mlr_data.csv", show_col_types = FALSE)
glm_data <- read_csv("glm_data.csv", show_col_types = FALSE)

# --- 1. Data Description ---
cat("\n========================================\n")
cat("CICIDS2017 NETWORK INTRUSION DATASET\n")
cat("========================================\n\n")

cat(sprintf("MLR dataset (benign traffic): %d rows, %d predictors + Flow.Bytes\n",
            nrow(mlr_data), ncol(mlr_data) - 1))
cat(sprintf("GLM dataset (all traffic):   %d rows, %d predictors + Attack_Flag\n\n",
            nrow(glm_data), ncol(glm_data) - 1))

# Attack rate
attack_rate <- mean(glm_data$Attack_Flag) * 100
cat(sprintf("Attack rate in GLM dataset: %.1f%%\n\n", attack_rate))

# --- 2. Summary Statistics ---

cat("--- MLR Dataset Summary (Flow.Bytes predictors, benign only) ---\n")
print(summary(mlr_data))
cat("\n")

cat("--- GLM Dataset Summary (Attack_Flag predictors, all traffic) ---\n")
print(summary(glm_data))
cat("\n")

# --- 3. Density Plots: Attack vs Benign for Key Features ---

glm_data$Label <- ifelse(glm_data$Attack_Flag == 1, "Attack", "Benign")

features_to_plot <- c("Destination.Port", "Avg.Fwd.Segment.Size",
                       "Avg.Bwd.Segment.Size", "Packet.Length.Variance")

pdf("descriptive_density_plots.pdf", width = 10, height = 8)
par(mfrow = c(2, 2))
for (feat in features_to_plot) {
  dens <- density(glm_data[[feat]], na.rm = TRUE)
  plot(dens, main = paste("Density of", feat), xlab = feat, col = "steelblue", lwd = 2)
  # TODO: Harold — overlay separate densities for Attack vs Benign on each plot
}
par(mfrow = c(1, 1))
dev.off()
cat("Saved density plots to descriptive_density_plots.pdf\n\n")

# --- 4. Correlation Matrix ---

pdf("descriptive_correlation_plots.pdf", width = 10, height = 8)
par(mfrow = c(1, 2))

# MLR correlation
cor_mlr <- cor(mlr_data)
heatmap(cor_mlr, symm = TRUE, main = "MLR Predictor Correlations\n(Benign Traffic)",
        col = colorRampPalette(c("navy", "white", "firebrick"))(100))

# GLM correlation
cor_glm <- cor(glm_data %>% select(-Attack_Flag, -Label))
heatmap(cor_glm, symm = TRUE, main = "GLM Predictor Correlations\n(All Traffic)",
        col = colorRampPalette(c("navy", "white", "firebrick"))(100))

par(mfrow = c(1, 1))
dev.off()
cat("Saved correlation heatmaps to descriptive_correlation_plots.pdf\n\n")

# --- 5. TODO: Categorical Variable Relationship ---
# TODO: Study the relationship between two categorical variables.
#       For example: create binned categories from Destination.Port
#       (well-known / registered / dynamic) and test association with Attack_Flag
#       using a chi-square test or mosaic plot.

# --- 6. TODO: Comparative Benign vs Attack Distributions ---
# TODO: Side-by-side boxplots comparing top predictors across Attack/Benign groups.
# TODO: Add a table of means and variances split by Attack_Flag.

cat("=== Descriptive analysis complete ===\n")
