#!/usr/bin/env Rscript

source(file.path('R', 'optimization_helpers.R'))

# —— Data —— #
inputs <- loadWorkflowInputs('term')

# —— Model —— #
spec <- parsnip::rand_forest(
  trees = tune::tune(),
  mtry  = tune::tune(),
  min_n = tune::tune()
) |>
  parsnip::set_engine(
    'ranger',
    probability = TRUE,
    importance  = 'none',
    num.threads = 1,
    seed        = tuningSeed
  ) |>
  parsnip::set_mode('classification')

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
  task        = 'term',
  modelId     = 'term_rf',
  modelFamily = 'random_forest',
  engine      = 'ranger',
  package     = 'ranger',
  spec        = spec,
  paramInfo   = paramInfo,
  initialSize = rfInitialSize,
  bayesIter   = rfBayesIter
)

message(sprintf(
  'Wrote term_rf results to %s.',
  normalizePath(file.path('results', 'term_rf.csv'))
))
