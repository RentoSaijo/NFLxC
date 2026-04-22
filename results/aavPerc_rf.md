# aavPerc_rf

## Setup

- Task: `aavPerc`.
- Model family: `random_forest`.
- Engine: `ranger`.
- Tuning method: `bayes`.
- Grouped folds on `playerId`: `5`.
- Training rows: `2795`.
- Validation rows: `91`.
- Predictor count after recipe: `504`.
- Selection rule: `best`.
- Primary CV metric: `rmse`.
- Selected CV mean: `0.010367`.
- Selected CV std. err.: `0.000936`.
- Initial design size: `10`.
- Bayesian iterations: `15`.

## Selected Parameters

| parameter | value |
| --- | --- |
| mtry | 143.000000 |
| trees | 978.000000 |
| min_n | 5.000000 |
| .config | iter13 |

## Validate Metrics

| metric | value |
| --- | --- |
| rmse | 0.005975 |
| mae | 0.003059 |
| mse | 0.00003570 |
| rsq | 0.884191 |

## Top CV Candidates

| mtry | trees | min_n | .metric | .estimator | mean | n | std_err | .config |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 143 |  978 | 5 | rmse | standard | 0.010367 | 5 | 0.000936 | iter13 |
| 143 |  887 | 5 | rmse | standard | 0.010367 | 5 | 0.000936 | iter15 |
| 140 |  795 | 4 | rmse | standard | 0.010367 | 5 | 0.000936 | iter09 |
| 143 |  734 | 2 | rmse | standard | 0.010367 | 5 | 0.000936 | iter06 |
| 141 |  952 | 4 | rmse | standard | 0.010367 | 5 | 0.000936 | iter14 |
| 138 |  986 | 3 | rmse | standard | 0.010367 | 5 | 0.000936 | iter10 |
| 123 |  659 | 2 | rmse | standard | 0.010367 | 5 | 0.000936 | iter02 |
| 149 |  866 | 2 | rmse | standard | 0.010367 | 5 | 0.000936 | iter07 |
| 140 |  479 | 2 | rmse | standard | 0.010367 | 5 | 0.000936 | iter11 |
| 142 | 1598 | 2 | rmse | standard | 0.010367 | 5 | 0.000936 | iter03 |
