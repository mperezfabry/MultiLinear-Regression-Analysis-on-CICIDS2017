library(tinytex)
library(readr)
library(dplyr)
library(ggplot2)
library(ISwR)
library(ISLR)
library(car)
library(MASS)
library(ggrepel)
library(here)
library(glmnet)
library(car)
library(caret)

# --- 1. Load Data ---
file_list <- list.files(path = here("C:/Users/katek/Desktop/NCF/Spring 2026/Stats 2/Final/MachineLearningCSV/MachineLearningCVE"), pattern = "*.csv", full.names = TRUE)

all_data = lapply(file_list, function(f) {
  read_csv(f, show_col_types = FALSE, na = c("", "NA", "Infinity", "NaN", "inf", "Inf"))
}) %>% bind_rows()

# Clean column names
colnames(all_data) = trimws(colnames(all_data))
colnames(all_data) = make.names(colnames(all_data))

# --- 2. Data Cleaning & Feature Engineering ---
all_data = all_data %>%
  mutate(Attack_Flag = ifelse(Label == "BENIGN", 0, 1)) %>%
  mutate(across(-matches("Label"), as.numeric)) %>%
  na.omit()

# Sampling
set.seed(42)
sample_size = 2000 
data_sample = all_data[sample(nrow(all_data), sample_size), ]

test = all_data[-sample(nrow(all_data), sample_size), ]

# Prepare features
features = data_sample[-c(2, 79, 80)]
features = features[, sapply(features, function(x) var(x, na.rm = TRUE) > 0)]

# --- Robustness Check: Remove highly correlated features to fix GLM convergence ---
cor_matrix = cor(features)
cor_matrix[upper.tri(cor_matrix)] = 0
diag(cor_matrix) = 0
to_drop = apply(cor_matrix, 2, function(x) any(abs(x) > 0.9, na.rm = TRUE))
features_pruned = features[, !to_drop]

data_modeling = cbind(Attack_Flag = data_sample$Attack_Flag, features_pruned)

# --- 3. Variable Selection ---

# 3b. SELECTED Stepwise with BIC (Logistic)
base_model = glm(Attack_Flag ~ 1, data = data_modeling, family = binomial)
full_model = glm(Attack_Flag ~ ., data = data_modeling, family = binomial)
step_bic = step(base_model, scope = list(lower = base_model, upper = full_model), 
                 direction = "both", trace = 0, k = log(sample_size))

# --- 4. Results Summary ---
# We use message() and print() to clearly label the final outputs only
message("\n--- MODEL 2: Stepwise BIC Summary ---")
print(summary(step_bic))

# response variable is a binary attack flag called label
# dataset now only has columns named in the BIC selection
data_bic = data_modeling[c('Packet.Length.Variance', 'Destination.Port', 'min_seg_size_forward', 'URG.Flag.Count', 'Init_Win_bytes_backward',
                           'Avg.Bwd.Segment.Size', 'Down.Up.Ratio', 'Init_Win_bytes_forward', 'Avg.Fwd.Segment.Size', 'Flow.Bytes.s',
                           'Bwd.Packet.Length.Min', 'Idle.Min', 'Bwd.IAT.Total', 'PSH.Flag.Count', 'Idle.Std', 'Attack_Flag')]
afmodelbic = glm(Attack_Flag~., family = "binomial", data = data_bic)
summary(afmodelbic)
with(afmodelbic, pchisq(null.deviance - deviance, df.null - df.residual, lower.tail = FALSE))
# all significant, dev = 521.06, AIC = 533.06, p is very low

get_logistic_pred = function(mod, data, res = "y", cut = 0.5) {
  probs = predict(mod, newdata = data, type = "response")
  ifelse(probs > cut, 1, 0)
}
test_pred_50 = get_logistic_pred(afmodelbic, data = test, res = "Attack_Flag", cut = 0.585)
test_tab_50 = table(predicted = test_pred_50, actual = test$Attack_Flag)
print(test_tab_50)
# misclass .585 = 176,525/2,825,876



# VIF order: Packet.Length.Variance, Bwd.IAT.Total 
data_bicvif = data_modeling[c('Destination.Port', 'min_seg_size_forward', 'URG.Flag.Count', 'Init_Win_bytes_backward',
                           'Avg.Bwd.Segment.Size', 'Down.Up.Ratio', 'Init_Win_bytes_forward', 'Avg.Fwd.Segment.Size', 'Flow.Bytes.s',
                           'Bwd.Packet.Length.Min', 'Idle.Min', 'PSH.Flag.Count', 'Idle.Std', 'Attack_Flag')]
afmodelbicvif = glm(Attack_Flag~., family = "binomial", data = data_bicvif)
summary(afmodelbicvif)
vif(afmodelbicvif)
with(afmodelbicvif, pchisq(null.deviance - deviance, df.null - df.residual, lower.tail = FALSE))
# 2 not significant, dev = 712.44, AIC = 740.44, p is very low

test_pred_50 = get_logistic_pred(afmodelbicvif, data = test, res = "Attack_Flag", cut = 0.489)
test_tab_50 = table(predicted = test_pred_50, actual = test$Attack_Flag)
print(test_tab_50)
# misclass .489 = 222,441/2,825,876



# finding regression outliers with rstandard()
# 78, 96, 117, 154, 213, 403, 452, 454, 472, 499, 516, 537, 622, 899, 936, 947, 1023, 1046, 1048, 1052,
# 1068, 1078, 1147, 1183, 1210, 1228, 1245, 1332, 1335, 1343, 1401, 1432, 1481, 1544, 1554, 1559, 1603, 1648, 1712, 1729,
# 1762, 1812, 1826, 1873, 1958, 1960, 1993
for(i in 1:nrow(data_bic_outvif)){
  if (abs(rstandard(afmodelbicoutvif, type='pearson')[i]) > 2){
    print(rstandard(afmodelbicoutvif, type='pearson')[i])
  }
}

# Model without outliers
data_bic_outvifp = data_bicvif[-c(78, 96, 117, 154, 213, 403, 452, 454, 472, 499, 516, 537, 622, 899, 936, 947, 1023, 1046, 1048, 1052,
                                  1068, 1078, 1147, 1183, 1210, 1228, 1245, 1332, 1335, 1343, 1401, 1432, 1481, 1544, 1554, 1559, 1603, 1648, 1712, 1729,
                                  1762, 1812, 1826, 1873, 1863,1958, 1960, 1993),]
afmodelbicoutvifp = glm(Attack_Flag~., family = "binomial", data = data_bic_outvifp)
options(scipen=999)
summary(afmodelbicoutvifp)
# 2 not significant, dev = 375.59, AIC = 403.59, p is very low

# Double outlier check
par(mar = c(5, 5, 5, 5))
plot(afmodelbicoutvifp, which = 5)

data_bic_outvifp = data_bic_outvifp[-c(1863),]
afmodelbicoutvifp = glm(Attack_Flag~., family = "binomial", data = data_bic_outvifp)
options(scipen=999)
summary(afmodelbicoutvifp)

with(afmodelbicoutvifp, pchisq(null.deviance - deviance, df.null - df.residual, lower.tail = FALSE))
# 2 not significant, dev = 365.75, AIC = 393.75, p is very low

test_pred_50 = get_logistic_pred(afmodelbicoutvifp, data = test, res = "Attack_Flag", cut = 0.4)
test_tab_50 = table(predicted = test_pred_50, actual = test$Attack_Flag)
print(test_tab_50)
# misclass .4 = 202,427/2,825,876 = 7.16%



# Final interpretation
# log(Attack_Flag) = -8.5828 - .0001168(Destination.Port) + .4094(min_seg_size_forward) - .006673(Init_Win_bytes_backward)
# + .002252(Avg.Bwd.Segment.Size) + 3.5943(Down.Up.Ratio) - .0001575(Init_Win_bytes_forward) - .06307(Avg.Fwd.Segment.Size)
# - .0000009352(Flow.Bytes.s) - .2975(Bwd.Packet.Length.Min) + .00000006727(Idle.Min) - 1.2989(PSH.Flag.Count)

# pos
# Down.Up.Ratio
# e^3.5943 = 36.3902   100(36.3902 - 1) = 100(35.3902) = 3,639.02%
# Each increase in Down.Up.Ratio multiplies odds of Attack_Flag by 36.3902
# When Down.Up.Ratio increases by 1 unit, Attack_Flag will change by 3,639.02%


# min_seg_size_forward
# e^.4094
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%

# Avg.Bwd.Segment.Size
# e^.002252
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%

# Idle.Min
# e^.00000006727
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%

# neg
# PSH.Flag.Count
# e^-1.2989
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%

# Bwd.Packet.Length.Min
# e^-.2975
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%

# Avg.Fwd.Segment.Size
# e^-.06307
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%

# Init_Win_bytes_backward
# e^-.006673
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%

# Init_Win_bytes_forward
# e^-.0001575
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%

# Destination.Port
# e^-.0001168
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%

# Flow.Bytes.s
# e^-.0000009352
# Each increase in x1 multiplies odds of y by e^(β_1 )
# When X increases by 1 unit, Y will change by 100(e^(β_1 )-1)%


# Conduct model diagnostics for the final model obtained in part 3. If issues are detected - proceed to either to one (or both) of the following:
#• transform/enhance your model from part 3 in order to try fixing them,
#• check for influential observations, verify their effect on resulting estimates/inference, treat them accordingly.

# For the final model, proceed to interpret the results (quality-of-fit, slopes, hypotheses tests, confidence intervals) in “broad strokes”.
# Don’t provide a word-by-word template interpretation on the slide itself.