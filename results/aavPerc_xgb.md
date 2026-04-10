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
- Selected CV mean: `0.009672`.
- Selected CV std. err.: `0.000925`.
- Initial design size: `12`.
- Bayesian iterations: `18`.

## Selected Parameters

| parameter | value |
| --- | --- |
| mtry | 57.000000 |
| trees | 473.000000 |
| min_n | 2.000000 |
| tree_depth | 3.000000 |
| learn_rate | 0.078861 |
| loss_reduction | 0.000010 |
| sample_size | 0.772218 |
| .config | iter08 |

## Validate Metrics

| metric | value |
| --- | --- |
| rmse | 0.005654 |
| mae | 0.002615 |
| mse | 0.00003196 |
| rsq | 0.902898 |

## Top CV Candidates

| mtry | trees | min_n | tree_depth | learn_rate | loss_reduction | sample_size | .metric | .estimator | mean | n | std_err | .config |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  57 |  473 |  2 |  3 | 0.078861255 | 1.045197e-05 | 0.7722182 | rmse | standard | 0.009672 | 5 | 0.000925 | iter08 |
| 119 |  633 |  2 |  3 | 0.133591744 | 2.538406e-06 | 0.8519792 | rmse | standard | 0.009672 | 5 | 0.000925 | iter06 |
| 119 |  991 | 19 | 10 | 0.010536505 | 1.125386e-06 | 0.6810049 | rmse | standard | 0.009672 | 5 | 0.000925 | iter11 |
| 108 | 1380 |  7 |  3 | 0.085299205 | 1.378696e-05 | 0.6036123 | rmse | standard | 0.009672 | 5 | 0.000925 | iter12 |
|  57 | 1185 |  2 |  4 | 0.005295789 | 7.574818e-06 | 0.6261230 | rmse | standard | 0.009672 | 5 | 0.000925 | iter02 |
| 109 | 1072 | 16 |  4 | 0.005000000 | 8.111308e-05 | 0.5909091 | rmse | standard | 0.009672 | 5 | 0.000925 | pre0_mod11_post0 |
|  88 | 1181 | 30 |  9 | 0.080820914 | 4.328761e-06 | 0.9090909 | rmse | standard | 0.009672 | 5 | 0.000925 | pre0_mod09_post0 |
|  59 |  544 |  3 |  7 | 0.149439622 | 3.795617e-05 | 0.7868864 | rmse | standard | 0.009672 | 5 | 0.000925 | iter01 |
| 104 |  431 |  5 |  2 | 0.144645451 | 7.325593e-05 | 0.6748535 | rmse | standard | 0.009672 | 5 | 0.000925 | iter07 |
| 120 | 1290 | 75 |  6 | 0.028497713 | 1.305826e-05 | 0.9116985 | rmse | standard | 0.009672 | 5 | 0.000925 | iter10 |
