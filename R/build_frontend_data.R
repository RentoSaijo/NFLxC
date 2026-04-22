#!/usr/bin/env Rscript

options(readr.show_col_types = FALSE)

# —— Packages —— #
requiredPkgs <- c(
  'dplyr',
  'jsonlite',
  'purrr',
  'readr',
  'tibble'
)

missingPkgs  <- requiredPkgs[
  !vapply(requiredPkgs, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missingPkgs) > 0L) {
  stop(
    paste0(
      'Missing package(s): ',
      paste(missingPkgs, collapse = ', '),
      '. Install them with install.packages(c(',
      paste(paste0('\'', missingPkgs, '\''), collapse = ', '),
      ')).'
    ),
    call. = FALSE
  )
}

# —— Paths —— #
summaryXgbPath   <- file.path('final', 'summary_xgb.csv')
summaryGlmPath   <- file.path('final', 'summary_glm.csv')
scenariosXgbPath <- file.path('final', 'scenarios_xgb.csv')
scenariosGlmPath <- file.path('final', 'scenarios_glm.csv')
metadataPath     <- file.path('final', 'metadata.json')
outputPath       <- file.path('final', 'app_data.json')
termXgbPath      <- file.path('results', 'term_xgb.csv')
termLlPath       <- file.path('results', 'term_ll.csv')
aavXgbPath       <- file.path('results', 'aavPerc_xgb.csv')
aavRlPath        <- file.path('results', 'aavPerc_rl.csv')
termXgbImpPath   <- file.path('models', 'term_xgb_final_importance.csv')
aavXgbImpPath    <- file.path('models', 'aavPerc_xgb_final_importance.csv')
termLlCoefPath   <- file.path('models', 'term_ll_final_coefficients.csv')
aavRlCoefPath    <- file.path('models', 'aavPerc_rl_final_coefficients.csv')

# —— Helpers —— #
readSummary <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(
      contractRowId = as.integer(contractRowId)
    )
}

readScenarios <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(
      contractRowId = as.integer(contractRowId),
      termScenario  = as.integer(termScenario)
    )
}

readResultRow <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::slice(1L)
}

nullIfMissing <- function(value) {
  if (length(value) == 0L || all(is.na(value))) {
    return(NULL)
  }

  value[[1L]]
}

namedValueList <- function(data, columns, digits = 6L) {
  values <- purrr::map(
    columns,
    function(columnName) {
      value <- data[[columnName]][[1L]]

      if (is.null(value) || length(value) == 0L || is.na(value)) {
        return(NULL)
      }

      if (is.numeric(value)) {
        value <- round(as.numeric(value), digits = digits)
      }

      value
    }
  )

  stats::setNames(values, columns) |>
    purrr::compact()
}

buildXgbModelMeta <- function(resultRow, importancePath, title, task, description, plotPath) {
  importanceTbl <- readr::read_csv(importancePath, show_col_types = FALSE) |>
    dplyr::slice_head(n = 10L)

  list(
    title          = title,
    task           = task,
    engine         = 'xgboost',
    description    = description,
    tuningMethod   = nullIfMissing(resultRow$tuningMethod),
    heldoutMetrics = namedValueList(
      resultRow,
      columns = c('mnLogLoss', 'rocAuc', 'brier', 'accuracy', 'rmse', 'mae', 'rsq')
    ),
    hyperparameters = namedValueList(
      resultRow,
      columns = c('mtry', 'trees', 'min_n', 'tree_depth', 'learn_rate', 'loss_reduction', 'sample_size')
    ),
    topFeatures    = importanceTbl |>
      dplyr::transmute(
        feature   = Feature,
        gain      = round(Gain, 6L),
        cover     = round(Cover, 6L),
        frequency = round(Frequency, 6L)
      ) |>
      purrr::transpose(),
    plotPath       = plotPath
  )
}

buildTermLlMeta <- function(resultRow, coefficientPath, plotPath) {
  coefficientTbl <- readr::read_csv(coefficientPath, show_col_types = FALSE) |>
    dplyr::filter(feature != '(Intercept)', coefficient != 0) |>
    dplyr::mutate(absValue = abs(coefficient))

  nonZeroTbl <- coefficientTbl |>
    dplyr::count(class, name = 'nonZeroCoefficients') |>
    dplyr::arrange(class)

  topTbl <- coefficientTbl |>
    dplyr::group_by(class) |>
    dplyr::slice_max(order_by = absValue, n = 3L, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::arrange(class, dplyr::desc(absValue))

  list(
    title          = 'Lasso multinomial logistic regression',
    task           = 'term',
    engine         = 'glmnet',
    description    = 'Penalized softmax classifier on the transformed contract, market, and prior-performance feature space.',
    tuningMethod   = nullIfMissing(resultRow$tuningMethod),
    heldoutMetrics = namedValueList(
      resultRow,
      columns = c('mnLogLoss', 'rocAuc', 'brier', 'accuracy')
    ),
    hyperparameters = namedValueList(
      resultRow,
      columns = c('lambda')
    ),
    classSparsity  = nonZeroTbl |>
      purrr::transpose(),
    topFeatures    = topTbl |>
      dplyr::transmute(
        class       = as.integer(class),
        feature     = feature,
        coefficient = round(coefficient, 6L)
      ) |>
      purrr::transpose(),
    plotPath       = plotPath
  )
}

buildAavRlMeta <- function(resultRow, coefficientPath, plotPath) {
  coefficientTbl <- readr::read_csv(coefficientPath, show_col_types = FALSE) |>
    dplyr::filter(feature != '(Intercept)') |>
    dplyr::mutate(absValue = abs(coefficient)) |>
    dplyr::slice_max(order_by = absValue, n = 12L, with_ties = FALSE)

  list(
    title          = 'Ridge linear regression',
    task           = 'aavPerc',
    engine         = 'glmnet',
    description    = 'Penalized linear compensation model conditioned on the supplied term scenario.',
    tuningMethod   = nullIfMissing(resultRow$tuningMethod),
    heldoutMetrics = namedValueList(
      resultRow,
      columns = c('rmse', 'mae', 'rsq')
    ),
    hyperparameters = namedValueList(
      resultRow,
      columns = c('lambda')
    ),
    topFeatures    = coefficientTbl |>
      dplyr::transmute(
        feature     = feature,
        coefficient = round(coefficient, 6L),
        absValue    = round(absValue, 6L)
      ) |>
      purrr::transpose(),
    plotPath       = plotPath
  )
}

scenarioRows <- function(data, contractId) {
  data |>
    dplyr::filter(contractRowId == contractId) |>
    dplyr::arrange(termScenario) |>
    dplyr::transmute(
      termScenario        = as.integer(termScenario),
      termProbability     = as.numeric(termProbability),
      aavPercPrediction   = as.numeric(aavPercPrediction),
      aavPrediction       = as.numeric(aavPrediction),
      aavPredictionMillions = as.numeric(aavPredictionMillions)
    ) |>
    purrr::transpose()
}

playerRecord <- function(contractId, summaryXgb, summaryGlm, scenariosXgb, scenariosGlm) {
  xgbRow <- summaryXgb |>
    dplyr::filter(contractRowId == contractId) |>
    dplyr::slice(1L)

  glmRow <- summaryGlm |>
    dplyr::filter(contractRowId == contractId) |>
    dplyr::slice(1L)

  list(
    contractRowId      = contractId,
    playerName         = nullIfMissing(xgbRow$playerName),
    playerKey          = nullIfMissing(xgbRow$playerKey),
    playerId           = nullIfMissing(xgbRow$playerId),
    pfrId              = nullIfMissing(xgbRow$pfrId),
    prevSignedTeam     = nullIfMissing(xgbRow$prevSignedTeam),
    ageAtSigning       = nullIfMissing(xgbRow$ageAtSigning),
    yearsExpAtSigning  = nullIfMissing(xgbRow$yearsExpAtSigning),
    context            = list(
      prevContractTerm          = nullIfMissing(xgbRow$prevContractTerm),
      prevContractAav           = nullIfMissing(xgbRow$prevContractAav),
      prevContractAavPerc       = nullIfMissing(xgbRow$prevContractAavPerc),
      prevContractAavMillions   = nullIfMissing(xgbRow$prevContractAavMillions),
      prevVsMarketAavPerc       = nullIfMissing(xgbRow$prevContractAavPerc - xgbRow$marketPrev1MedianAavPerc),
      regWeightedTargets        = nullIfMissing(xgbRow$regWeightedTargets),
      regWeightedReceptions     = nullIfMissing(xgbRow$regWeightedReceptions),
      regWeightedReceivingYards = nullIfMissing(xgbRow$regWeightedReceivingYards),
      regWeightedReceivingTds   = nullIfMissing(xgbRow$regWeightedReceivingTds),
      regWeightedTargetShare    = nullIfMissing(xgbRow$regWeightedTargetShare),
      snapWeightedOffensePctMean = nullIfMissing(xgbRow$snapWeightedOffensePctMean),
      ngsWeightedYardsPerTarget = nullIfMissing(xgbRow$ngsWeightedYardsPerTarget),
      marketPrev1MedianAavPerc  = nullIfMissing(xgbRow$marketPrev1MedianAavPerc)
    ),
    models             = list(
      xgb = list(
        summary = list(
          expectedTerm        = nullIfMissing(xgbRow$expectedTerm),
          modalTerm           = nullIfMissing(xgbRow$modalTerm),
          modalTermProb       = nullIfMissing(xgbRow$modalTermProb),
          predictedTerm       = nullIfMissing(xgbRow$predictedTerm),
          expectedAavPerc     = nullIfMissing(xgbRow$expectedAavPerc),
          expectedAav         = nullIfMissing(xgbRow$expectedAav),
          expectedAavMillions = nullIfMissing(xgbRow$expectedAavMillions),
          modalAavPerc        = nullIfMissing(xgbRow$modalAavPerc),
          modalAav            = nullIfMissing(xgbRow$modalAav),
          modalAavMillions    = nullIfMissing(xgbRow$modalAavMillions),
          prob1               = nullIfMissing(xgbRow$.pred_1),
          prob2               = nullIfMissing(xgbRow$.pred_2),
          prob3               = nullIfMissing(xgbRow$.pred_3),
          prob4               = nullIfMissing(xgbRow$.pred_4),
          prob5               = nullIfMissing(xgbRow$.pred_5)
        ),
        scenarios = scenarioRows(scenariosXgb, contractId)
      ),
      glm = list(
        summary = list(
          expectedTerm        = nullIfMissing(glmRow$expectedTerm),
          modalTerm           = nullIfMissing(glmRow$modalTerm),
          modalTermProb       = nullIfMissing(glmRow$modalTermProb),
          predictedTerm       = nullIfMissing(glmRow$predictedTerm),
          expectedAavPerc     = nullIfMissing(glmRow$expectedAavPerc),
          expectedAav         = nullIfMissing(glmRow$expectedAav),
          expectedAavMillions = nullIfMissing(glmRow$expectedAavMillions),
          modalAavPerc        = nullIfMissing(glmRow$modalAavPerc),
          modalAav            = nullIfMissing(glmRow$modalAav),
          modalAavMillions    = nullIfMissing(glmRow$modalAavMillions),
          prob1               = nullIfMissing(glmRow$.pred_1),
          prob2               = nullIfMissing(glmRow$.pred_2),
          prob3               = nullIfMissing(glmRow$.pred_3),
          prob4               = nullIfMissing(glmRow$.pred_4),
          prob5               = nullIfMissing(glmRow$.pred_5)
        ),
        scenarios = scenarioRows(scenariosGlm, contractId)
      )
    )
  )
}

# —— Build —— #
summaryXgb <- readSummary(summaryXgbPath)
summaryGlm <- readSummary(summaryGlmPath)
scenariosXgb <- readScenarios(scenariosXgbPath)
scenariosGlm <- readScenarios(scenariosGlmPath)
metadata <- jsonlite::read_json(metadataPath, simplifyVector = TRUE)
termXgbResult <- readResultRow(termXgbPath)
termLlResult  <- readResultRow(termLlPath)
aavXgbResult  <- readResultRow(aavXgbPath)
aavRlResult   <- readResultRow(aavRlPath)

contractIds <- sort(unique(summaryXgb$contractRowId))

players <- purrr::map(
  contractIds,
  ~ playerRecord(.x, summaryXgb, summaryGlm, scenariosXgb, scenariosGlm)
)

output <- list(
  generatedAt = as.character(Sys.time()),
  metadata    = metadata,
  method      = list(
    xgb = list(
      familyLabel = 'Predictive pair',
      models      = list(
        term    = buildXgbModelMeta(
          resultRow    = termXgbResult,
          importancePath = termXgbImpPath,
          title        = 'XGBoost multiclass classifier',
          task         = 'term',
          description  = 'Boosted tree ensemble for bucketed contract term probabilities.',
          plotPath     = './models/plots/term_xgb_final_importance.png'
        ),
        aavPerc = buildXgbModelMeta(
          resultRow    = aavXgbResult,
          importancePath = aavXgbImpPath,
          title        = 'XGBoost conditional AAV% regressor',
          task         = 'aavPerc',
          description  = 'Boosted tree regressor for cap-share pricing conditional on a supplied term scenario.',
          plotPath     = './models/plots/aavPerc_xgb_final_importance.png'
        )
      )
    ),
    glm = list(
      familyLabel = 'Interpretable pair',
      models      = list(
        term    = buildTermLlMeta(
          resultRow      = termLlResult,
          coefficientPath = termLlCoefPath,
          plotPath       = './models/plots/term_ll_final_coefficients.png'
        ),
        aavPerc = buildAavRlMeta(
          resultRow      = aavRlResult,
          coefficientPath = aavRlCoefPath,
          plotPath       = './models/plots/aavPerc_rl_final_coefficients.png'
        )
      )
    )
  ),
  teams       = summaryXgb |>
    dplyr::distinct(prevSignedTeam) |>
    dplyr::filter(!is.na(prevSignedTeam), prevSignedTeam != '') |>
    dplyr::arrange(prevSignedTeam) |>
    dplyr::pull(prevSignedTeam),
  players     = players
)

# This keeps the frontend payload stable and browser-friendly.
jsonlite::write_json(
  output,
  path         = outputPath,
  auto_unbox   = TRUE,
  pretty       = TRUE,
  null         = 'null',
  digits       = NA
)

message(sprintf(
  'Wrote frontend data to %s.',
  normalizePath(outputPath)
))
