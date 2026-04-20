# Project Notes

# Variable Selection

## Stepwise AIC (19 variables retained): 
AIC is relatively lenient with its penalty for adding variables. It kept 19 features, but if you look at the coefficient output, variables like Fwd.IAT.Mean ($p = 0.104$) and Flow.IAT.Min ($p = 0.119$) are not statistically significant at standard alpha levels. AIC kept them because they marginally improved the deviance of the model, but they are essentially noise.

## Stepwise BIC (15 variables retained):
BIC hits the model with a heavier penalty for complexity based on your sample size. It pruned the model down to 15 features. Notice the Pr(>|z|) column in the BIC output: every single variable retained is highly significant, with most having p-values well below 0.001.

## LASSO lambda.min (26 variables retained):
This method prioritized absolute predictive accuracy during cross-validation. It shrunk the coefficients of highly collinear variables to prevent the model from blowing up, but it still kept 26 variables, many of which likely have tiny, marginal effects (notice the incredibly small coefficients like -3.19e-06).

## LASSO lambda.1se (21 variables retained):
A more aggressive penalty than lambda.min, bringing the feature count down to 21. It completely zeroed out features like Flow.Bytes.s and ACK.Flag.Count that lambda.min retained.

## Final Result of Variable Selection:
My preference would be to use the set of 15 variables selected by BIC. They are significant, and fewer, more stable, and easier to interpret than the penalized LASSO versions. Keep it as straightforward as possible.

Anybody is free to work on the TODOs in the code. 