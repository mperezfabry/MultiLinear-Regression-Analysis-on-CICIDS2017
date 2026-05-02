# Linear.R - Linear Regression for Flow.Bytes prediction

library(readr)
library(dplyr)
library(ggplot2)

# Load data
mlr_data <- read_csv("mlr_data.csv", show_col_types = FALSE)

# TODO: Fit multiple linear regression model
# TODO: Check assumptions (normality, homoscedasticity, linearity)
# TODO: Check collinearity (VIF)
# TODO: Residual diagnostics, leverage, influence
