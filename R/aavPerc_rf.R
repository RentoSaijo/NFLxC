#!/usr/bin/env Rscript

source(file.path('R', 'optimization_helpers.R'))

# —— Data —— #
inputs <- loadWorkflowInputs('aavPerc')

# —— Model —— #
spec <- parsnip::rand_forest(
  trees = tune::tune(),
  mtry  = tune::tune(),
  min_n = tune::tune()
) |>
  parsnip::set_engine(
    'ranger',
    importance  = 'none',
    num.threads = 1,
    seed        = tuningSeed
  ) |>
  parsnip::set_mode('regression')

# —— Parameters —— #
mtryUpper <- max(10L, min(150L, inputs$predictorCount))

paramInfo <- hardhat::extract_parameter_set_dials(spec) |>
  update(
    trees = dials::trees(c(300L, 1800L)),
    mtry  = dials::mtry(c(5L, mtryUpper)),
    min_n = dials::min_n(c(2L, 60L))
  )

# —— Run —— #
summaryRow <- runBayesWorkflow(
  task        = 'aavPerc',
  modelId     = 'aavPerc_rf',
  modelFamily = 'random_forest',
  engine      = 'ranger',
  package     = 'ranger',
  spec        = spec,
  paramInfo   = paramInfo,
  initialSize = rfInitialSize,
  bayesIter   = rfBayesIter
)

message(sprintf(
  'Wrote aavPerc_rf results to %s.',
  normalizePath(file.path('results', 'aavPerc_rf.csv'))
))
