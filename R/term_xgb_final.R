#!/usr/bin/env Rscript

source(file.path('R', 'final_model_helpers.R'))

# —— Inputs —— #
selectedResult <- loadSelectedResult(file.path('results', 'term_xgb.csv'))
modelId        <- 'term_xgb_final'

# —— Model —— #
spec <- parsnip::boost_tree(
  trees          = selectedResult$trees[[1L]],
  tree_depth     = selectedResult$tree_depth[[1L]],
  learn_rate     = selectedResult$learn_rate[[1L]],
  min_n          = selectedResult$min_n[[1L]],
  loss_reduction = selectedResult$loss_reduction[[1L]],
  sample_size    = selectedResult$sample_size[[1L]],
  mtry           = selectedResult$mtry[[1L]]
) |>
  parsnip::set_engine(
    'xgboost',
    tree_method = 'hist',
    nthread     = 1,
    verbose     = 0
  ) |>
  parsnip::set_mode('classification')

# —— Fit —— #
modelObject <- fitFinalModel(
  modelId        = modelId,
  task           = 'term',
  engine         = 'xgboost',
  spec           = spec,
  selectedResult = selectedResult
)

# —— Reports —— #
importanceTable <- extractXgbImportance(modelObject, topN = 50L)
importancePath  <- saveImportancePlot(
  importanceTable = importanceTable,
  modelId         = modelId,
  title           = 'Term XGBoost Final Feature Importance'
)

readr::write_csv(importanceTable, file.path(modelsDir, paste0(modelId, '_importance.csv')))

paramTable <- tibble::tibble(
  parameter = c('mtry', 'trees', 'min_n', 'tree_depth', 'learn_rate', 'loss_reduction', 'sample_size'),
  value     = c(
    selectedResult$mtry[[1L]],
    selectedResult$trees[[1L]],
    selectedResult$min_n[[1L]],
    selectedResult$tree_depth[[1L]],
    formatNumber(selectedResult$learn_rate),
    formatNumber(selectedResult$loss_reduction, digits = 8L),
    formatNumber(selectedResult$sample_size)
  )
)

metricTable <- tibble::tibble(
  metric = c('mnLogLoss', 'rocAuc', 'brier', 'accuracy'),
  value  = c(
    formatNumber(selectedResult$mnLogLoss),
    formatNumber(selectedResult$rocAuc),
    formatNumber(selectedResult$brier),
    formatNumber(selectedResult$accuracy)
  )
)

topFeatures <- importanceTable |>
  dplyr::slice_head(n = 20L) |>
  dplyr::transmute(
    Feature      = Feature,
    Gain         = formatNumber(Gain),
    Cover        = formatNumber(Cover),
    Frequency    = formatNumber(Frequency)
  )

lines <- c(
  '# term_xgb_final',
  '',
  '## Purpose',
  '',
  'This is the final predictive term model. Hyperparameters were selected on `train.csv` only, with grouped cross-validation and a single 2026 validation check, and the model is now refit once on `train.csv + validate.csv` so it can score the unsigned 2026 free agents.',
  '',
  '## Why This Model',
  '',
  '- `xgboost` was the strongest held-out term model on proper scoring rules after tuning.',
  '- Tree boosting is the better choice here when the target is a sparse, nonlinear multinomial contract outcome with many engineered interactions and missingness indicators.',
  '- This model is not closed form, so it is paired with a more interpretable penalized multinomial logit elsewhere.',
  '',
  '## Final Fit',
  '',
  paste0('- Final training rows: `', modelObject$fittedRows, '`.'),
  paste0('- Predictor count after recipe: `', modelObject$predictorCount, '`.'),
  paste0('- Final fit time: `', formatNumber(modelObject$fitSeconds), '` seconds.'),
  paste0('- Saved model object: `', file.path(modelsDir, paste0(modelId, '.rds')), '`.'),
  '',
  '## Selected Hyperparameters',
  '',
  markdownTable(paramTable),
  '',
  '## Historical Held-Out Metrics',
  '',
  'These are the 2026 validation metrics from the tuning stage. They are the honest out-of-sample numbers that justified the final refit.',
  '',
  markdownTable(metricTable),
  '',
  '## Interpretation',
  '',
  'This model should be interpreted through global feature importance, not through a single signed linear coefficient. Gain-based importance shows which engineered inputs most often contributed the most impurity reduction across the fitted trees.',
  '',
  paste0('![Term XGBoost Importance](', file.path('plots', basename(importancePath)), ')'),
  '',
  'Top features by gain:',
  '',
  markdownTable(topFeatures),
  '',
  '## Statistical Notes',
  '',
  '- Importance is directional only in the sense of relevance. It does not tell you whether a larger feature value increases or decreases a specific term class probability.',
  '- Importance is not a causal claim. It reflects the final boosted ensemble after the recipe transformations, dummy encoding, missing-value handling, and normalization.',
  '- Because the term problem is multiclass and imbalanced, the key validation metric remains multinomial log loss rather than raw accuracy.',
  '',
  '## Files',
  '',
  paste0('- Model: `', file.path(modelsDir, paste0(modelId, '.rds')), '`.'),
  paste0('- Importance CSV: `', file.path(modelsDir, paste0(modelId, '_importance.csv')), '`.'),
  paste0('- Importance plot: `', importancePath, '`.')
)

writeLines(lines, con = file.path(modelsDir, paste0(modelId, '.md')))

message(sprintf(
  'Wrote final term xgboost model to %s.',
  normalizePath(file.path(modelsDir, paste0(modelId, '.rds')))
))
