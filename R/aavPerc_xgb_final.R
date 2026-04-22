#!/usr/bin/env Rscript

source(file.path('R', 'final_model_helpers.R'))

# —— Inputs —— #
selectedResult <- loadSelectedResult(file.path('results', 'aavPerc_xgb.csv'))
modelId        <- 'aavPerc_xgb_final'

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
  parsnip::set_mode('regression')

# —— Fit —— #
modelObject <- fitFinalModel(
  modelId        = modelId,
  task           = 'aavPerc',
  engine         = 'xgboost',
  spec           = spec,
  selectedResult = selectedResult
)

# —— Reports —— #
importanceTable <- extractXgbImportance(modelObject, topN = 50L)
importancePath  <- saveImportancePlot(
  importanceTable = importanceTable,
  modelId         = modelId,
  title           = 'AAV% XGBoost Final Feature Importance'
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
  metric = c('rmse', 'mae', 'rsq'),
  value  = c(
    formatNumber(selectedResult$rmse),
    formatNumber(selectedResult$mae),
    formatNumber(selectedResult$rsq)
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
  '# aavPerc_xgb_final',
  '',
  '## Purpose',
  '',
  'This is the final predictive `aavPerc` model. It is conditioned on a term scenario, which is the intended production use case for the contract app and the free-agent scoring workflow.',
  '',
  '## Why This Model',
  '',
  '- It delivered the strongest held-out `aavPerc` accuracy after tuning.',
  '- Boosted trees capture nonlinear effects and interactions among recent production, market context, prior contract history, and the supplied term scenario.',
  '- This is the most predictive conditional compensation model in the project.',
  '',
  '## Final Fit',
  '',
  paste0('- Final training rows: `', modelObject$fittedRows, '`.'),
  paste0('- Predictor count after recipe: `', modelObject$predictorCount, '`.'),
  paste0('- Final fit time: `', formatNumber(modelObject$fitSeconds), '` seconds.'),
  paste0('- Implied 2026 cap used for dollar translation: `', formatNumber(modelObject$impliedCap2026, digits = 0L), '`.'),
  paste0('- Saved model object: `', file.path(modelsDir, paste0(modelId, '.rds')), '`.'),
  '',
  '## Selected Hyperparameters',
  '',
  markdownTable(paramTable),
  '',
  '## Historical Held-Out Metrics',
  '',
  markdownTable(metricTable),
  '',
  '## Interpretation',
  '',
  'This model is interpreted through global gain importance. The most important variables are the ones that most consistently improved split quality across the final boosted ensemble, conditional on the supplied term scenario.',
  '',
  paste0('![AAV% XGBoost Importance](', file.path('plots', basename(importancePath)), ')'),
  '',
  'Top features by gain:',
  '',
  markdownTable(topFeatures),
  '',
  '## Statistical Notes',
  '',
  '- This is a conditional market model, not a one-shot contract model. The supplied term scenario changes the predicted `aavPerc` path.',
  '- Gain importance is global and unsigned. It does not reveal a linear marginal effect in the way a penalized linear model does.',
  '- Predicted dollar AAV is produced by multiplying predicted `aavPerc` by the implied 2026 cap from the labeled 2026 contracts.',
  '',
  '## Files',
  '',
  paste0('- Model: `', file.path(modelsDir, paste0(modelId, '.rds')), '`.'),
  paste0('- Importance CSV: `', file.path(modelsDir, paste0(modelId, '_importance.csv')), '`.'),
  paste0('- Importance plot: `', importancePath, '`.')
)

writeLines(lines, con = file.path(modelsDir, paste0(modelId, '.md')))

message(sprintf(
  'Wrote final aavPerc xgboost model to %s.',
  normalizePath(file.path(modelsDir, paste0(modelId, '.rds')))
))
