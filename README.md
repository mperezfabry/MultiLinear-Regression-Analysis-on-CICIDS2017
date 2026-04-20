# Multi-Linear Regression Analysis on CICIDS2017

## Project Overview
This project performs statistical analysis and variable selection on the CICIDS2017 network intrusion detection dataset. The primary goal is to identify key features that distinguish between benign network traffic and various types of cyber attacks using both Multiple Linear Regression (for continuous traffic characteristics) and Logistic Regression (for binary classification).

## Methodology
The current analysis focuses on variable selection for a binary `Attack_Flag` (1 for attacks, 0 for BENIGN) using four statistical methods:
1. **Stepwise AIC**: Prioritizes predictive performance and inclusion.
2. **Stepwise BIC**: Prioritizes model parsimony and essential feature identification.
3. **LASSO (lambda.min)**: Minimizes cross-validated error through L1 regularization.
4. **LASSO (1SE)**: Provides the most robust and simplest model within one standard error of the minimum error.

## Dataset
The analysis utilizes the PCAP-derived CSV files from the CICIDS2017 dataset, covering various attack scenarios including DDoS, PortScan, and Web Attacks.

## Usage
Run the analysis using:
```R
source("analysis.R")
```

## Contributing
Please document all updates to the codebase in `Notes.md`.
