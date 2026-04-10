# term_xgb

## Setup

- Task: `term`.
- Model family: `boosted_tree`.
- Engine: `xgboost`.
- Tuning method: `bayes`.
- Grouped folds on `playerId`: `5`.
- Training rows: `2795`.
- Validation rows: `91`.
- Predictor count after recipe: `500`.
- Selection rule: `best`.
- Primary CV metric: `mn_log_loss`.
- Selected CV mean: `0.787532`.
- Selected CV std. err.: `0.044845`.
- Initial design size: `12`.
- Bayesian iterations: `18`.

## Selected Parameters

| parameter | value |
| --- | --- |
| mtry | 92.000000 |
| trees | 1251.000000 |
| min_n | 10.000000 |
| tree_depth | 4.000000 |
| learn_rate | 0.005249 |
| loss_reduction | 0.000160 |
| sample_size | 0.945583 |
| .config | iter09 |

## Validate Metrics

| metric | value |
| --- | --- |
| mnLogLoss | 0.536581 |
| rocAuc | 0.674789 |
| brier | 0.056768 |
| accuracy | 0.824176 |

## Top CV Candidates

| mtry | trees | min_n | tree_depth | learn_rate | loss_reduction | sample_size | .metric | .estimator | mean | n | std_err | .config |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  92 | 1251 | 10 | 4 | 0.005249286 | 1.600941e-04 | 0.9455827 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | iter09 |
| 100 |  897 |  8 | 7 | 0.005036977 | 6.502122e-06 | 0.8919519 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | iter05 |
| 104 | 1340 |  5 | 3 | 0.005460091 | 2.759464e-02 | 0.9897089 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | iter13 |
|  42 | 1153 |  2 | 3 | 0.005107832 | 5.048202e-01 | 0.9891019 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | iter08 |
|  88 | 1242 |  5 | 4 | 0.007209783 | 1.082646e-05 | 0.8872083 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | iter07 |
|  55 | 1283 | 16 | 6 | 0.005963787 | 2.383174e-03 | 0.9927851 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | iter12 |
| 119 | 1148 |  7 | 9 | 0.007035518 | 7.884171e-05 | 0.9953637 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | iter06 |
| 109 | 1072 | 16 | 4 | 0.005000000 | 8.111308e-05 | 0.5909091 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | pre0_mod11_post0 |
|  44 |  911 |  5 | 2 | 0.005390562 | 6.421293e-05 | 0.8302832 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | iter14 |
|  36 |  927 | 68 | 4 | 0.030651083 | 6.211748e-05 | 0.9900133 | mn_log_loss | multiclass | 0.787532 | 5 | 0.044845 | iter01 |
