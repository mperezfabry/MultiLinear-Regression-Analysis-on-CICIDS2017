# Multi-Linear Regression Analysis on CICIDS2017

## Project Overview
This project performs statistical analysis on the CICIDS2017 network intrusion detection dataset. The primary goal is to identify key features that distinguish between benign network traffic and various types of cyber attacks using Multiple Linear Regression (for continuous traffic characteristics) and Logistic Regression (binary classification).

## Methodology
Variable selection is performed using **Stepwise BIC** on two separate feature sets:
1. **Linear Stepwise BIC** — Predicting `Flow.Bytes` using benign traffic only (MLR)
2. **Logistic Stepwise BIC** — Predicting `Attack_Flag` (binary) using all traffic

Highly correlated features (|r| > 0.9) are pruned before selection to ensure model stability.

## Project Structure
- `setup.R` — Loads raw CSV files, samples data, performs feature engineering and Stepwise BIC selection, exports cleaned datasets
- `Logistic.R` — Logistic regression model for attack prediction using `glm_data.csv`
- `Linear.R` — Multiple linear regression model for flow byte prediction using `mlr_data.csv`
- `Descriptive.R` — Descriptive statistics and visualizations using both datasets
- `mlr_data.csv` — Cleaned dataset with MLR-selected features and `Flow.Bytes` response
- `glm_data.csv` — Cleaned dataset with logistic-selected features and `Attack_Flag` response

## Usage
Run scripts in order:
```R
source("setup.R")       # Performs variable selection and exports CSVs
source("Descriptive.R") # Descriptive statistics and visualizations
source("Linear.R")      # Linear model fitting and diagnostics
source("Logistic.R")    # Logistic model fitting and evaluation
```

## Dataset
The CICIDS2017 dataset CSV files must be placed in the project directory. `setup.R` samples ~250 rows per file to keep memory usage manageable.

## Contributing
Please document all updates to the codebase in `Notes.md`.
