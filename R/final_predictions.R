#!/usr/bin/env Rscript

source(file.path('R', 'final_model_helpers.R'))

# —— Models —— #
termXgbModel    <- readRDS(file.path(modelsDir, 'term_xgb_final.rds'))
termLlModel     <- readRDS(file.path(modelsDir, 'term_ll_final.rds'))
aavPercXgbModel <- readRDS(file.path(modelsDir, 'aavPerc_xgb_final.rds'))
aavPercRlModel  <- readRDS(file.path(modelsDir, 'aavPerc_rl_final.rds'))

# —— Data —— #
termTestData <- loadTestTaskData('term')
aavTestData  <- loadTestTaskData('aavPerc')
testRaw      <- readr::read_csv(testPath, show_col_types = FALSE)

# —— Context —— #
contextCols <- c(
  'contractRowId',
  'playerName',
  'playerKey',
  'playerId',
  'pfrId',
  'ageAtSigning',
  'yearsExpAtSigning',
  'prevSignedTeam',
  'prevContractTerm',
  'prevContractAav',
  'prevContractAavPerc',
  'regWeightedTargets',
  'regWeightedReceptions',
  'regWeightedReceivingYards',
  'regWeightedReceivingTds',
  'regWeightedTargetShare',
  'snapWeightedOffensePctMean',
  'ngsWeightedYardsPerTarget',
  'marketPrev1MedianAavPerc'
)

playerContext <- testRaw |>
  dplyr::select(tidyselect::any_of(contextCols)) |>
  dplyr::mutate(
    prevContractAavMillions = prevContractAav / 1e6
  )

# —— Model Predictions —— #
termXgbPred <- predictTermProbabilities(termXgbModel, termTestData)
termLlPred  <- predictTermProbabilities(termLlModel, termTestData)

aavPercXgbScenarios <- predictAavScenarios(aavPercXgbModel, aavTestData) |>
  dplyr::mutate(aavPredictionMillions = aavPrediction / 1e6)

aavPercRlScenarios <- predictAavScenarios(aavPercRlModel, aavTestData) |>
  dplyr::mutate(aavPredictionMillions = aavPrediction / 1e6)

# —— Pair Outputs —— #
xgbPair <- pairScenarioPredictions(
  pairId          = 'xgb_pair',
  termModelId     = termXgbModel$modelId,
  aavModelId      = aavPercXgbModel$modelId,
  termPredictions = termXgbPred,
  aavScenarios    = aavPercXgbScenarios
)

glmPair <- pairScenarioPredictions(
  pairId          = 'glm_pair',
  termModelId     = termLlModel$modelId,
  aavModelId      = aavPercRlModel$modelId,
  termPredictions = termLlPred,
  aavScenarios    = aavPercRlScenarios
)

summaryXgb <- xgbPair$summary |>
  dplyr::left_join(
    termXgbPred |>
      dplyr::select(contractRowId, predictedTerm, dplyr::starts_with('.pred_')),
    by = 'contractRowId'
  ) |>
  dplyr::left_join(playerContext, by = c('contractRowId', 'playerName', 'playerKey', 'playerId', 'pfrId', 'ageAtSigning', 'yearsExpAtSigning', 'prevSignedTeam')) |>
  dplyr::mutate(
    expectedAavMillions = expectedAav / 1e6,
    modalAavMillions    = modalAav / 1e6
  ) |>
  dplyr::arrange(dplyr::desc(expectedAav))

summaryGlm <- glmPair$summary |>
  dplyr::left_join(
    termLlPred |>
      dplyr::select(contractRowId, predictedTerm, dplyr::starts_with('.pred_')),
    by = 'contractRowId'
  ) |>
  dplyr::left_join(playerContext, by = c('contractRowId', 'playerName', 'playerKey', 'playerId', 'pfrId', 'ageAtSigning', 'yearsExpAtSigning', 'prevSignedTeam')) |>
  dplyr::mutate(
    expectedAavMillions = expectedAav / 1e6,
    modalAavMillions    = modalAav / 1e6
  ) |>
  dplyr::arrange(dplyr::desc(expectedAav))

scenariosXgb <- xgbPair$scenarios |>
  dplyr::left_join(playerContext, by = c('contractRowId', 'playerName', 'playerKey', 'playerId', 'pfrId', 'ageAtSigning', 'yearsExpAtSigning', 'prevSignedTeam')) |>
  dplyr::arrange(dplyr::desc(termProbability), playerName, termScenario)

scenariosGlm <- glmPair$scenarios |>
  dplyr::left_join(playerContext, by = c('contractRowId', 'playerName', 'playerKey', 'playerId', 'pfrId', 'ageAtSigning', 'yearsExpAtSigning', 'prevSignedTeam')) |>
  dplyr::arrange(dplyr::desc(termProbability), playerName, termScenario)

# —— Output —— #
readr::write_csv(termXgbPred, file.path(finalDir, 'term_xgb_probabilities.csv'))
readr::write_csv(termLlPred, file.path(finalDir, 'term_ll_probabilities.csv'))
readr::write_csv(aavPercXgbScenarios, file.path(finalDir, 'aavPerc_xgb_scenarios.csv'))
readr::write_csv(aavPercRlScenarios, file.path(finalDir, 'aavPerc_rl_scenarios.csv'))
readr::write_csv(summaryXgb, file.path(finalDir, 'summary_xgb.csv'))
readr::write_csv(summaryGlm, file.path(finalDir, 'summary_glm.csv'))
readr::write_csv(scenariosXgb, file.path(finalDir, 'scenarios_xgb.csv'))
readr::write_csv(scenariosGlm, file.path(finalDir, 'scenarios_glm.csv'))
readr::write_csv(playerContext, file.path(finalDir, 'player_context.csv'))

writeMetadataJson(cap2026 = termXgbModel$impliedCap2026)

message(sprintf(
  'Wrote final prediction files to %s.',
  normalizePath(finalDir)
))
