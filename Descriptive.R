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

# --- 3. Density Plots: Attack vs Benign Overlay ---

glm_data$Label <- ifelse(glm_data$Attack_Flag == 1, "Attack", "Benign")

features_to_plot <- c("Destination.Port", "Avg.Fwd.Segment.Size",
                       "Avg.Bwd.Segment.Size", "Packet.Length.Variance")

pdf("descriptive_density_plots.pdf", width = 10, height = 8)
par(mfrow = c(2, 2))
for (feat in features_to_plot) {
  benign_vals <- glm_data[[feat]][glm_data$Attack_Flag == 0]
  attack_vals <- glm_data[[feat]][glm_data$Attack_Flag == 1]

  dens_b <- density(benign_vals, na.rm = TRUE)
  dens_a <- density(attack_vals, na.rm = TRUE)

  ymax <- max(c(dens_b$y, dens_a$y))
  xrange <- range(c(dens_b$x, dens_a$x))

  plot(dens_b, main = paste("Density of", feat), xlab = feat,
       col = "steelblue", lwd = 2,
       xlim = xrange, ylim = c(0, ymax))
  lines(dens_a, col = "firebrick", lwd = 2)
  legend("topright", legend = c("Benign", "Attack"),
         col = c("steelblue", "firebrick"), lwd = 2, bty = "n")
}
par(mfrow = c(1, 1))
dev.off()
cat("Saved attack-vs-benign density plots to descriptive_density_plots.pdf\n\n")

# --- 4. Correlation Matrix ---

pdf("descriptive_correlation_plots.pdf", width = 10, height = 8)
par(mfrow = c(1, 2))

# MLR correlation
cor_mlr <- cor(mlr_data %>% select(-Flow.Bytes))
# 1. Open the file device
png(filename = "MLR_Predictor_Correlations.png", 
    width = 900,      # Slightly wider to accommodate text
    height = 900, 
    res = 130)        # Higher resolution for sharper text

# 2. Run heatmap with internal margin scaling
heatmap(cor_mlr, 
        symm = TRUE, 
        main = "MLR Predictor Correlations\n(Benign Traffic)",
        col = colorRampPalette(c("navy", "white", "firebrick"))(100),
        margins = c(12, 12)) # Bumps up bottom and right margins internally

# 3. Save the file
dev.off()


# GLM correlation
cor_glm <- cor(glm_data %>% select(-Attack_Flag, -Label))
heatmap(cor_glm, symm = TRUE, main = "GLM Predictor Correlations\n(All Traffic)",
        col = colorRampPalette(c("navy", "white", "firebrick"))(100))

par(mfrow = c(1, 1))
dev.off()
cat("Saved correlation heatmaps to descriptive_correlation_plots.pdf\n\n")

# --- 5. Categorical Relationship: Port Category vs Attack_Flag ---
# IANA port ranges: well-known (0-1023), registered (1024-49151), dynamic (49152-65535).
# Two categorical variables: Port_Category (predictor) and Attack_Flag (response).

glm_data$Port_Category <- cut(
  glm_data$Destination.Port,
  breaks = c(-Inf, 1023, 49151, Inf),
  labels = c("Well-known", "Registered", "Dynamic")
)

port_attack_tab <- table(
  Port_Category = glm_data$Port_Category,
  Attack        = ifelse(glm_data$Attack_Flag == 1, "Yes", "No")
)
cat("--- Port Category vs Attack_Flag (counts) ---\n")
print(port_attack_tab)
cat("\n--- Row-wise attack rate by port category (%) ---\n")
print(round(prop.table(port_attack_tab, 1) * 100, 1))

chi <- chisq.test(port_attack_tab)
cat(sprintf("\nChi-square test: X^2 = %.2f, df = %d, p = %.3e\n\n",
            chi$statistic, chi$parameter, chi$p.value))

# --- 6. Comparative Benign vs Attack Distributions ---

top_features <- c("Avg.Fwd.Segment.Size", "Avg.Bwd.Segment.Size",
                  "Packet.Length.Variance", "Destination.Port",
                  "Down.Up.Ratio", "Init_Win_bytes_backward")

pdf("descriptive_boxplots.pdf", width = 10, height = 7)
par(mfrow = c(2, 3))
for (feat in top_features) {
  boxplot(glm_data[[feat]] ~ glm_data$Attack_Flag,
          names = c("Benign", "Attack"),
          main  = feat,
          ylab  = feat,
          xlab  = "",
          col   = c("steelblue", "firebrick"))
}
par(mfrow = c(1, 1))
dev.off()
cat("Saved comparative boxplots to descriptive_boxplots.pdf\n\n")

group_stats <- glm_data %>%
  group_by(Attack_Flag) %>%
  summarise(across(all_of(top_features),
                   list(mean = ~mean(.x, na.rm = TRUE),
                        sd   = ~sd(.x,   na.rm = TRUE)))) %>%
  as.data.frame()

cat("--- Group means and SDs (Attack_Flag: 0 = Benign, 1 = Attack) ---\n")
print(group_stats)

cat("\n=== Descriptive analysis complete ===\n")
