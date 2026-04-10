# Optimized Model Comparison

## Term

| modelId | mnLogLoss | rocAuc | brier | accuracy | cvMetricMean |
| --- | ---: | ---: | ---: | ---: | ---: |
| term_xgb | 0.536581 | 0.674789 | 0.056768 | 0.824176 | 0.787532 |
| term_rf | 0.544580 | 0.669144 | 0.057318 | 0.813187 | 0.795450 |
| term_ll | 0.591975 | 0.642260 | 0.060119 | 0.813187 | 0.832474 |

## aavPerc

| modelId | rmse | mae | rsq | cvMetricMean |
| --- | ---: | ---: | ---: | ---: |
| aavPerc_xgb | 0.005654 | 0.002615 | 0.902898 | 0.009672 |
| aavPerc_rl | 0.006082 | 0.003890 | 0.883440 | 0.010494 |
| aavPerc_rf | 0.006090 | 0.003062 | 0.879610 | 0.010546 |
