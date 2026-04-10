#!/usr/bin/env Rscript

source(file.path('R', 'optimization_helpers.R'))

# —— Data —— #
inputs <- loadWorkflowInputs('aavPerc')

# —— Model —— #
spec <- parsnip::boost_tree(
  trees          = tune::tune(),
  tree_depth     = tune::tune(),
  learn_rate     = tune::tune(),
  min_n          = tune::tune(),
  loss_reduction = tune::tune(),
  sample_size    = tune::tune(),
  mtry           = tune::tune()
) |>
  parsnip::set_engine(
    'xgboost',
    tree_method = 'hist',
    nthread     = 1,
    verbose     = 0
  ) |>
  parsnip::set_mode('regression')

# —— Parameters —— #
mtryUpper <- max(10L, min(120L, inputs$predictorCount))

paramInfo <- hardhat::extract_parameter_set_dials(spec) |>
  update(
    trees          = dials::trees(c(200L, 1400L)),
    tree_depth     = dials::tree_depth(c(2L, 10L)),
    learn_rate     = dials::learn_rate(log10(c(0.005, 0.15))),
    min_n          = dials::min_n(c(2L, 80L)),
    loss_reduction = dials::loss_reduction(log10(c(1e-6, 10))),
    sample_size    = dials::sample_prop(c(0.5, 1.0)),
    mtry           = dials::mtry(c(5L, mtryUpper))
  )

# —— Run —— #
summaryRow <- runBayesWorkflow(
  task        = 'aavPerc',
  modelId     = 'aavPerc_xgb',
  modelFamily = 'boosted_tree',
  engine      = 'xgboost',
  package     = 'xgboost',
  spec        = spec,
  paramInfo   = paramInfo,
  initialSize = xgbInitialSize,
  bayesIter   = xgbBayesIter
)

message(sprintf(
  'Wrote aavPerc_xgb results to %s.',
  normalizePath(file.path('results', 'aavPerc_xgb.csv'))
))
