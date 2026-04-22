# aavPerc_xgb

## Setup

- Task: `aavPerc`.
- Model family: `boosted_tree`.
- Engine: `xgboost`.
- Tuning method: `bayes`.
- Grouped folds on `playerId`: `5`.
- Training rows: `2795`.
- Validation rows: `91`.
- Predictor count after recipe: `504`.
- Selection rule: `best`.
- Primary CV metric: `rmse`.
- Selected CV mean: `0.009601`.
- Selected CV std. err.: `0.000733`.
- Initial design size: `12`.
- Bayesian iterations: `18`.

## Selected Parameters

| parameter | value |
| --- | --- |
| mtry | 105.000000 |
| trees | 1352.000000 |
| min_n | 48.000000 |
| tree_depth | 2.000000 |
| learn_rate | 0.075881 |
| loss_reduction | 0.000001 |
| sample_size | 0.980413 |
| .config | iter04 |

## Validate Metrics

| metric | value |
| --- | --- |
| rmse | 0.005705 |
| mae | 0.002778 |
| mse | 0.00003254 |
| rsq | 0.896643 |

## Top CV Candidates

| mtry | trees | min_n | tree_depth | learn_rate | loss_reduction | sample_size | .metric | .estimator | mean | n | std_err | .config |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 105 | 1352 | 48 | 2 | 0.075880567 | 1.065987e-06 | 0.9804134 | rmse | standard | 0.009601 | 5 | 0.000733 | iter04 |
| 104 | 1028 | 35 | 4 | 0.006191161 | 2.624645e-06 | 0.9962261 | rmse | standard | 0.009601 | 5 | 0.000733 | iter08 |
| 109 | 1072 | 16 | 4 | 0.005000000 | 8.111308e-05 | 0.5909091 | rmse | standard | 0.009601 | 5 | 0.000733 | pre0_mod11_post0 |
| 111 |  340 | 45 | 7 | 0.129405774 | 1.062098e-06 | 0.8997659 | rmse | standard | 0.009601 | 5 | 0.000733 | iter03 |
|  88 | 1181 | 30 | 9 | 0.080820914 | 4.328761e-06 | 0.9090909 | rmse | standard | 0.009601 | 5 | 0.000733 | pre0_mod09_post0 |
|  71 |  770 | 31 | 9 | 0.061917294 | 1.275071e-04 | 0.5013175 | rmse | standard | 0.009601 | 5 | 0.000733 | iter09 |
|  46 |  309 | 23 | 2 | 0.023463282 | 1.000000e-06 | 0.8181818 | rmse | standard | 0.009601 | 5 | 0.000733 | pre0_mod05_post0 |
| 119 | 1289 | 35 | 4 | 0.134831948 | 6.367845e-05 | 0.6682689 | rmse | standard | 0.009601 | 5 | 0.000733 | iter05 |
|  15 | 1290 | 72 | 4 | 0.017222849 | 1.873817e-05 | 0.7727273 | rmse | standard | 0.009601 | 5 | 0.000733 | pre0_mod02_post0 |
|  68 | 1298 |  6 | 3 | 0.005809404 | 3.491955e-03 | 0.6294195 | rmse | standard | 0.009601 | 5 | 0.000733 | iter01 |
