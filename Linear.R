# Linear.R - Multiple Linear Regression for Flow.Bytes prediction

library(readr)
library(dplyr)
library(car)

d <- read_csv("mlr_data.csv", show_col_types = FALSE)

# --- 1. Fit Raw Model ---

m1 <- lm(Flow.Bytes ~ ., data = d)
summary(m1)
anova(m1)
confint(m1, level = 0.95)

# --- 2. VIF ---

vif(m1)

# --- 3. Diagnostic Plots for Raw Model ---

par(mfrow = c(2, 2))
plot(m1, which = 1, main = "Raw: Residuals vs Fitted")
plot(m1, which = 2, main = "Raw: Normal Q-Q")
plot(m1, which = 3, main = "Raw: Scale-Location")
plot(m1, which = 4, main = "Raw: Cook's Distance")
par(mfrow = c(1, 1))

# --- 4. Row 1198 Outlier ---

r1198 <- d[1198, ]
rest <- d[-1198, ]

vars <- c("Flow.Bytes", "act_data_pkt_fwd", "PSH.Flag.Count")
tab <- data.frame(
  Variable    = vars,
  Row_1198    = as.numeric(r1198[1, vars]),
  Second_Val  = sapply(d[vars], function(x) sort(x, decreasing = TRUE)[2]),
  Z_Score     = round((as.numeric(r1198[1, vars]) - sapply(rest[vars], mean)) / sapply(rest[vars], sd), 2),
  Times_2nd   = round(as.numeric(r1198[1, vars]) / sapply(d[vars], function(x) sort(x, decreasing = TRUE)[2]), 1)
)
cat("\n=== Row 1198 Outlier ===\n")
print(tab, row.names = FALSE)

# --- 5. Raw Plots 1-2 (justify log transform) ---
m2 <- lm(Flow.Bytes ~., data = rest)
par(mfrow = c(1, 3))
plot(m2, which = 1)
plot(m2, which = 2)
plot(m2, which = 4)

# --- 6. Log Model (without 1198) ---

rest_log <- rest
rest_log$Flow.Bytes <- log1p(rest_log$Flow.Bytes)
m_log <- lm(Flow.Bytes ~ ., data = rest_log)

par(mfrow = c(1, 3))
plot(m_log, which = 1)
plot(m_log, which = 2)
plot(m_log, which = 4)

cat(sprintf("\nLog model ncvTest p = %.3e\n", ncvTest(m_log)$p))

# --- 7. Add Polynomial Terms to Fix Heteroscedasticity ---
# The log model still shows heteroscedasticity and curvature at high
# fitted values. Squared terms capture the saturation effect where
# extreme predictor values don't produce proportionally larger flows.

rest_log$Bwd.Packet.Length.Min2 <- rest_log$Bwd.Packet.Length.Min^2
rest_log$act_data_pkt_fwd2 <- rest_log$act_data_pkt_fwd^2
m_final <- lm(Flow.Bytes ~ . + Bwd.Packet.Length.Min2 + act_data_pkt_fwd2, data = rest_log)

summary(m_log)
summary(m_final)
confint(m_final)

par(mfrow = c(3, 1))
plot(m_final, which = 1, main = "Final: Residuals vs Fitted")
plot(m_final, which = 2, main = "Final: Normal Q-Q")
plot(m_final, which = 4, main = "Final: Cook's Distance")
par(mfrow = c(1, 1))

ncv_final <- ncvTest(m_final)
cat(sprintf("\nFinal model ncvTest p = %.3e", ncv_final$p))
cat(if (ncv_final$p > 0.05) "  -> homoscedasticity not violated\n" else "  -> heteroscedasticity remains\n")

cat("\n=== Model Progression ===\n")
cat(sprintf("Raw (all data):               R2 = %.4f\n", summary(m1)$r.squared))
cat(sprintf("Log (no 1198):                R2 = %.4f\n", summary(m_log)$r.squared))
cat(sprintf("Final (+ squared terms):      R2 = %.4f\n", summary(m_final)$r.squared))
cat(sprintf("Rows removed: 1  (row 1198 only, 0.06%% of data)\n"))
