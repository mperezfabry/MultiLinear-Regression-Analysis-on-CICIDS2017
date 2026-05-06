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

# The response variable is 'Attack_Flag', which shows whether that particular traffic is malicious or not.
data_bic = data_modeling[c('Packet.Length.Variance', 'Destination.Port', 'min_seg_size_forward', 'URG.Flag.Count', 'Init_Win_bytes_backward',
                           'Avg.Bwd.Segment.Size', 'Down.Up.Ratio', 'Init_Win_bytes_forward', 'Avg.Fwd.Segment.Size', 'Flow.Bytes.s',
                           'Bwd.Packet.Length.Min', 'Idle.Min', 'Bwd.IAT.Total', 'PSH.Flag.Count', 'Idle.Std', 'Attack_Flag')]
# The dataset now only has columns named in the BIC selection
afmodelbic = glm(Attack_Flag~., family = "binomial", data = data_bic)
summary(afmodelbic)
# All variables were found significant by the model.
# Deviation was 521.06 when null deviation was 2,050.51. This is a much better fit than the null model.
# The AIC is 553.06. This can be used to compare models.
with(afmodelbic, pchisq(null.deviance - deviance, df.null - df.residual, lower.tail = FALSE))
# The p-value is extremely low.
get_logistic_pred = function(mod, data, res = "y", cut = 0.5) {
  probs = predict(mod, newdata = data, type = "response")
  ifelse(probs > cut, 1, 0)
}
test_pred_50 = get_logistic_pred(afmodelbic, data = test, res = "Attack_Flag", cut = 0.585)
test_tab_50 = table(predicted = test_pred_50, actual = test$Attack_Flag)
print(test_tab_50)
# With a cut-off of .585, 176,525 out of 2,825,876 observations were misclassified. This is a misclassification rate of 6.25%.




# Packet.Length.Variance and Bwd.IAT.Total had a VIF higher than 5 and were removed.
data_bicvif = data_modeling[c('Destination.Port', 'min_seg_size_forward', 'URG.Flag.Count', 'Init_Win_bytes_backward',
                           'Avg.Bwd.Segment.Size', 'Down.Up.Ratio', 'Init_Win_bytes_forward', 'Avg.Fwd.Segment.Size', 'Flow.Bytes.s',
                           'Bwd.Packet.Length.Min', 'Idle.Min', 'PSH.Flag.Count', 'Idle.Std', 'Attack_Flag')]
afmodelbicvif = glm(Attack_Flag~., family = "binomial", data = data_bicvif)
vif(afmodelbicvif)
summary(afmodelbicvif)
# 2 variables were found not significant by the model.
# Deviation was 712.44 when null deviation was 2,050.51. This is a much better fit than the null model, but worse than the first. Unfortunately, this step is necessary, so we will keep this model.
# The AIC is 740.44, which also means it's worse than the first model.
with(afmodelbicvif, pchisq(null.deviance - deviance, df.null - df.residual, lower.tail = FALSE))
# The p-value is extremely low.
test_pred_50 = get_logistic_pred(afmodelbicvif, data = test, res = "Attack_Flag", cut = 0.489)
test_tab_50 = table(predicted = test_pred_50, actual = test$Attack_Flag)
print(test_tab_50)
# With a cut-off of .489, 222,441 out of 2,825,876 observations were misclassified. This is a misclassification rate of 7.87%, worse than the first model.



# Finding regression outliers with rstandard().
# 78, 96, 117, 154, 213, 403, 452, 454, 472, 499, 516, 537, 622, 899, 936, 947, 1023, 1046, 1048, 1052,
# 1068, 1078, 1147, 1183, 1210, 1228, 1245, 1332, 1335, 1343, 1401, 1432, 1481, 1544, 1554, 1559, 1603, 1648, 1712, 1729,
# 1762, 1812, 1826, 1873, 1958, 1960, 1993
for(i in 1:nrow(data_bicvif)){
  if (abs(rstandard(afmodelbicvif, type='pearson')[i]) > 2){
    print(rstandard(afmodelbicvif, type='pearson')[i])
  }
}
# Model without outliers.
data_bic_outvifp = data_bicvif[-c(78, 96, 117, 154, 213, 403, 452, 454, 472, 499, 516, 537, 622, 899, 936, 947, 1023, 1046, 1048, 1052,
                                  1068, 1078, 1147, 1183, 1210, 1228, 1245, 1332, 1335, 1343, 1401, 1432, 1481, 1544, 1554, 1559, 1603, 1648, 1712, 1729,
                                  1762, 1812, 1826, 1873, 1863,1958, 1960, 1993),]
afmodelbicoutvifp = glm(Attack_Flag~., family = "binomial", data = data_bic_outvifp)
options(scipen=999)
summary(afmodelbicoutvifp)
# 2 variables were found not significant by the model.
# Deviation was 365.75 when null deviation was 1,988. This is a much better fit than the null model and all previous models.
# The AIC is 393.75, which also shows it's better than all previous models.
with(afmodelbicoutvifp, pchisq(null.deviance - deviance, df.null - df.residual, lower.tail = FALSE))
# The p-value is extremely low.
test_pred_50 = get_logistic_pred(afmodelbicoutvifp, data = test, res = "Attack_Flag", cut = 0.396)
test_tab_50 = table(predicted = test_pred_50, actual = test$Attack_Flag)
print(test_tab_50)
# With a cut-off of .396, 200,779 out of 2,825,876 observations were misclassified. This is a misclassification rate of 7.11%, better than the model with outliers, but not better than the original.
confint(afmodelbicoutvifp)[1:14,] 

# Final interpretation:
# log(Attack_Flag) = -8.5828 - .0001168(Destination.Port) + .4094(min_seg_size_forward) - .006673(Init_Win_bytes_backward)
# + .002252(Avg.Bwd.Segment.Size) + 3.5943(Down.Up.Ratio) - .0001575(Init_Win_bytes_forward) - .06307(Avg.Fwd.Segment.Size)
# - .0000009352(Flow.Bytes.s) - .2975(Bwd.Packet.Length.Min) + .00000006727(Idle.Min) - 1.2989(PSH.Flag.Count)

# Down.Up.Ratio
# e^3.5943 = 36.3902    100(36.3902 - 1) = 100(35.3902) = 3,639.02%
# Each increase in the download and upload ratio multiplies odds of Attack_Flag by 36.3902.
# When the download and upload ratio increases by 1 unit, odds of Attack_Flag will increase by 3,639.02%.
# e^2.7118 = 15.0564    100(14.0564) = 1,405.64%
# e^4.5933 = 98.82    100(97.82) = 9,782%
# We are 95% confident that each increase in the download and upload ratio multiplies odds of Attack_Flag by between 15.0564 and 98.82.
# We are 95% confident that when the download and upload ratio increases by 1 unit, odds of Attack_Flag will increase by between 1,405.64% and 9,782%.

# min_seg_size_forward
# e^.4094 = 1.5059    100(1.5059 - 1) = 100(.5059) = 50.59%
# Each increase in the minimum size of a segment in the forward direction multiplies odds of Attack_Flag by 1.5059.
# When the minimum size of a segment in the forward direction increases by 1 unit, odds of Attack_Flag will increase by 50.59%.
# e^.3249 = 1.3839    100(.3839) = 38.39%
# e^.5096 = 1.6646    100(.6646) = 66.46%
# We are 95% confident that each increase in the minimum size of a segment in the forward direction multiplies odds of Attack_Flag by between 1.3839 and 1.6646,
# We are 95% confident that when the minimum size of a segment in the forward direction increases by 1 unit, odds of Attack_Flag will increase by between 38.39% and 66.46%.

# Avg.Bwd.Segment.Size
# e^.002252 = 1.0023    100(1.0023 - 1) = 100(.0023) = .23%
# Each increase in the average size of a packet in backward direction multiplies odds of Attack_Flag by 1.0023.
# When the average size of a packet in backward direction increases by 1 unit, odds of Attack_Flag will increase by .23%.
# e^.001536 = 1.0015   100(.0015) = .15%
# e^ .003175 = 1.0032    100(.0032) = .32%
# We are 95% confident that each increase in the average size of a packet in backward direction multiplies odds of Attack_Flag by between 1.0015 and 1.0032.
# We are 95% confident that when the average size of a packet in backward direction increases by 1 unit, odds of Attack_Flag will increase by between .15% and .32%.

# Idle.Min
# e^.00000006727 = 1.00000006727    100(1.00000006727 - 1) = 100(.00000006727) = .0000067%
# Each increase in minimum time a flow was idle before becoming active multiplies odds of Attack_Flag by 1.00000006727.
# When minimum time a flow was idle before becoming active increases by 1 unit, odds of Attack_Flag will increase by .0000067%.
# e^.0000000447 = 1.0000000447    100(.000000447) = .00000447%
# e^.00000009307 = 1.0000009307    100(.00000009307) = .000009307%
# We are 95% confident that each increase in minimum time a flow was idle before becoming active multiplies odds of Attack_Flag by between 1.0000000447 and 1.0000009307.
# We are 95% confident that when minimum time a flow was idle before becoming active increases by 1 unit, odds of Attack_Flag will increase by between .00000447% and .000009307%.

# PSH.Flag.Count
# e^-1.2989 = .2728    100(.2728 - 1) = 100(-.7272) = -72.72%
# Each increase in the number of packets with PUSH multiplies odds of Attack_Flag by .2728.
# When the number of packets with PUSH increases by 1 unit, odds of Attack_Flag will decrease by 72.72%.
# e^-2.0751 = .1255    100(.1255 - 1) 100(-.8745) = -87.45%
# e^-.5739 = .5633    100(.5633 - 1) = 100(-.4367) = -43.67%
# We are 95% confident that each increase in the number of packets with PUSH multiplies odds of Attack_Flag by between .1255 and .5633,
# We are 95% confident that when the number of packets with PUSH increases by 1 unit, odds of Attack_Flag will decrease by between 87.45% and 43.67%

# Bwd.Packet.Length.Min
# e^-.2975 = .7423    100(.7423 - 1) = 100(-.2577) = -25.77%
# Each increase in minimum size of a packet in the backward direction multiplies odds of Attack_Flag by .7423.
# When minimum size of a packet in the backward direction increases by 1 unit, odds of Attack_Flag will decrease by 25.77%.
# e^-.4041 = .6676    100(.6676 - 1) = 100(-.3324) = -33.24%
# e^-.2098 = .8107    100(.8107 - 1) = 100(-.1893) = -18.93%
# We are 95% confident that each increase in minimum size of a packet in the backward direction multiplies odds of Attack_Flag by between .6676 and .8107
# We are 95% confident that when minimum size of a packet in the backward direction increases by 1 unit, odds of Attack_Flag will decrease by between 33.24% and 18.93%

# Avg.Fwd.Segment.Size
# e^-.06307 = .9389    100(.9389 - 1) = 100(-.0611) = -6.11%
# Each increase in the average size of a segment in forward direction multiplies odds of Attack_Flag by .9389.
# When the average size of a segment in forward direction increases by 1 unit, odds of Attack_Flag will decrease by 6.11%.
# e^-.08283 = .9205    100(.9205 - 1) = 100(-.0795) = -7.95%
# e^-.04661 = .9545    100(.9545 - 1) = 100(-.0455) = -4.55%
# We are 95% confident that each increase in the average size of a segment in forward direction multiplies odds of Attack_Flag by between .9205 and .9545.
# We are 95% confident that when the average size of a segment in forward direction increases by 1 unit, odds of Attack_Flag will decrease by between 7.95% and 4.55%

# Init_Win_bytes_backward
# e^-.006673 = .9933    100(.9933 - 1) = 100(-.0067) = -.67%
# Each increase in the total number of bytes sent in initial window in the backward direction multiplies odds of Attack_Flag by .9933.
# When the total number of bytes sent in initial window in the backward direction increases by 1 unit, odds of Attack_Flag will decrease by .67%.
# e^-.01054 = .9895    100(.9895 - 1) = 100(-.0105) = -1.05%
# e^-.003414 = .9966    100(.9966 - 1) = 100(-.0034) = -.34%
# We are 95% confident that each increase in the total number of bytes sent in initial window in the backward direction multiplies odds of Attack_Flag by between .9895 and .9966
# We are 95% confident that when the total number of bytes sent in initial window in the backward direction increases by 1 unit, odds of Attack_Flag will decrease by between 1.05% and .34%.

# Init_Win_bytes_forward
# e^-.0001575 = .9998    100(.9998 - 1) = 100(-.0001575) = -.016%
# Each increase in the total number of bytes sent in initial window in the forward direction multiplies odds of Attack_Flag by .9998.
# When the total number of bytes sent in initial window in the forward direction increases by 1 unit, odds of Attack_Flag will decrease by .016%.
# e^-.0002025 = .9998     100(.9998 - 1) = 100(.0002) = -.02%
# e^-.0001193 = .9999    100(.9999 - 1) = 100(.0001) = -.01%
# We are 95% confident that each increase in the total number of bytes sent in initial window in the forward direction multiplies odds of Attack_Flag by between .9998 and .9999.
# We are 95% confident that when the total number of bytes sent in initial window in the forward direction increases by 1 unit, odds of Attack_Flag will decrease by between .02% and .01%.

# Destination.Port
# e^-.0001168 = .9998    100(.9998 - 1) = 100(-.0001575) = -.016%
# Each increase in Destination.Port multiplies odds of Attack_Flag by .9998.
# When Destination.Port increases by 1 unit, odds of Attack_Flag will decrease by .016%.
# e^-.001495 = .9985    100(.9985 - 1)
# e^-.00008886 = .9999    100(.9999 - 1) = 100(.0015) = -.15%
# We are 95% confident that each increase in Destination.Port multiplies odds of Attack_Flag by between .9985 and .9999
# We are 95% confident that when Destination.Port increases by 1 unit, odds of Attack_Flag will decrease by between .15% and .01%

# Flow.Bytes.s
# e^-.0000009352 = .9999    100(.9999 - 1) = 100(.0001) = -.01%
# Each increase in the number of flow bytes per second multiplies odds of Attack_Flag by .9999.
# When the number of flow bytes per second increases by 1 unit, odds of Attack_Flag will decrease by .01%.
# Confidence interval was between -.000001467 and -.0000005361, and both e^-.000001467 e^-.0000005361 - .9999. Interpreting the CI is pointless here.

# The null hypothesis that B1 = B2 = ... = B16 = 0 was changed to B1 = B2 = ... = B14 = 0 due to VIF variable removals.
# Regardless, the null hypothesis is rejected, as our final model was significant as a whole and showed that at least one variable had a significant effect on 'Attack_Flag'.
