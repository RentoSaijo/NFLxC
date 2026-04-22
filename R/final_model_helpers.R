#!/usr/bin/env Rscript

options(readr.show_col_types = FALSE)

source(file.path('R', 'baseline_helpers.R'))

# —— Packages —— #
requiredFinalPkgs <- c(
  'dplyr',
  'forcats',
  'ggplot2',
  'glmnet',
  'jsonlite',
  'readr',
  'recipes',
  'tibble',
  'tidyr',
  'workflows',
  'xgboost'
)

missingFinalPkgs  <- requiredFinalPkgs[
  !vapply(requiredFinalPkgs, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missingFinalPkgs) > 0L) {
  stop(
    paste0(
      'Missing package(s): ',
      paste(missingFinalPkgs, collapse = ', '),
      '. Install them with install.packages(c(',
      paste(paste0('\'', missingFinalPkgs, '\''), collapse = ', '),
      ')).'
    ),
    call. = FALSE
  )
}

# —— Constants —— #
finalSeed        <- 20260422L
testPath         <- file.path('data', 'test.csv')
modelsDir        <- 'models'
modelPlotsDir    <- file.path(modelsDir, 'plots')
finalDir         <- 'final'
termScenarioVals <- as.integer(termLevels)

dir.create(modelsDir, recursive = TRUE, showWarnings = FALSE)
dir.create(modelPlotsDir, recursive = TRUE, showWarnings = FALSE)
dir.create(finalDir, recursive = TRUE, showWarnings = FALSE)

# —— Helpers —— #
elapsedSeconds <- function(startTime) {
  as.numeric((proc.time() - startTime)[['elapsed']])
}

markdownTable <- function(data) {
  if (nrow(data) == 0L) {
    return(character())
  }

  header <- paste0('| ', paste(names(data), collapse = ' | '), ' |')
  rule   <- paste0('| ', paste(rep('---', ncol(data)), collapse = ' | '), ' |')
  rows   <- apply(
    data,
    1,
    function(row) {
      paste0('| ', paste(row, collapse = ' | '), ' |')
    }
  )

  c(header, rule, rows)
}

formatNumber <- function(x, digits = 6L) {
  if (length(x) == 0L || is.null(x)) {
    return(character())
  }

  vapply(
    x,
    function(value) {
      if (is.na(value)) {
        return(NA_character_)
      }

      formatC(value, format = 'f', digits = digits)
    },
    character(1)
  )
}

loadSelectedResult <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::slice(1L)
}

combineTaskData <- function(task) {
  dplyr::bind_rows(
    loadTaskFrame(task, trainPath),
    loadTaskFrame(task, validatePath)
  )
}

loadTestTaskData <- function(task) {
  loadTaskFrame(task, testPath)
}

predictorCountForTask <- function(task, trainingData) {
  recipePrep <- recipes::prep(
    buildRecipe(task, trainingData),
    training = trainingData,
    retain   = TRUE
  )

  ncol(recipes::juice(recipePrep, recipes::all_predictors()))
}

impliedCap2026 <- function() {
  validateRaw <- readr::read_csv(validatePath, show_col_types = FALSE)

  validateRaw |>
    dplyr::filter(!is.na(aav), !is.na(aavPerc), aavPerc > 0) |>
    dplyr::transmute(cap = aav / aavPerc) |>
    dplyr::summarise(cap = stats::median(cap)) |>
    dplyr::pull(cap)
}

extractEngineFit <- function(workflowFit) {
  fitObj <- workflows::extract_fit_parsnip(workflowFit)

  if (!is.null(fitObj$fit)) {
    return(fitObj$fit)
  }

  fitObj
}

extractXgbBooster <- function(workflowFit) {
  engineFit <- extractEngineFit(workflowFit)

  if (inherits(engineFit, 'xgb.Booster')) {
    return(engineFit)
  }

  if (!is.null(engineFit$fit) && inherits(engineFit$fit, 'xgb.Booster')) {
    return(engineFit$fit)
  }

  stop('Unable to extract xgboost booster.', call. = FALSE)
}

extractGlmnetObject <- function(workflowFit) {
  engineFit <- extractEngineFit(workflowFit)

  if (inherits(engineFit, 'glmnet')) {
    return(engineFit)
  }

  if (!is.null(engineFit$fit) && inherits(engineFit$fit, 'glmnet')) {
    return(engineFit$fit)
  }

  stop('Unable to extract glmnet fit.', call. = FALSE)
}

fitFinalModel <- function(modelId, task, engine, spec, selectedResult) {
  trainingData   <- combineTaskData(task)
  recipeSpec     <- buildRecipe(task, trainingData)
  workflowSpec   <- workflows::workflow() |>
    workflows::add_recipe(recipeSpec) |>
    workflows::add_model(spec)
  predictorCount <- predictorCountForTask(task, trainingData)

  set.seed(finalSeed)

  fitStart <- proc.time()
  workflowFit <- parsnip::fit(workflowSpec, data = trainingData)
  fitSecs     <- elapsedSeconds(fitStart)

  modelObject <- list(
    modelId        = modelId,
    task           = task,
    engine         = engine,
    workflow       = workflowFit,
    selectedResult = selectedResult,
    fittedRows     = nrow(trainingData),
    predictorCount = predictorCount,
    fitSeconds     = fitSecs,
    fittedAt       = as.character(Sys.time()),
    impliedCap2026 = impliedCap2026()
  )

  saveRDS(modelObject, file.path(modelsDir, paste0(modelId, '.rds')))

  modelObject
}

extractXgbImportance <- function(modelObject, topN = 50L) {
  booster <- extractXgbBooster(modelObject$workflow)

  xgboost::xgb.importance(model = booster) |>
    tibble::as_tibble() |>
    dplyr::slice_head(n = topN)
}

saveImportancePlot <- function(importanceTable, modelId, title) {
  plotPath <- file.path(modelPlotsDir, paste0(modelId, '_importance.png'))

  plotObj <- importanceTable |>
    dplyr::slice_head(n = 20L) |>
    dplyr::mutate(Feature = forcats::fct_reorder(Feature, Gain)) |>
    ggplot2::ggplot(ggplot2::aes(x = Gain, y = Feature)) +
    ggplot2::geom_col(fill = '#2F6CA8') +
    ggplot2::labs(
      title = title,
      x     = 'Gain',
      y     = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12)

  ggplot2::ggsave(
    filename = plotPath,
    plot     = plotObj,
    width    = 9,
    height   = 6,
    dpi      = 180
  )

  plotPath
}

extractRegressionCoefficients <- function(modelObject, lambda) {
  glmnetFit <- extractGlmnetObject(modelObject$workflow)
  coefMat   <- stats::coef(glmnetFit, s = lambda)

  tibble::tibble(
    feature     = rownames(coefMat),
    coefficient = as.numeric(coefMat[, 1])
  )
}

extractMultinomialCoefficients <- function(modelObject, lambda) {
  glmnetFit <- extractGlmnetObject(modelObject$workflow)
  coefList  <- stats::coef(glmnetFit, s = lambda)

  dplyr::bind_rows(
    lapply(
      names(coefList),
      function(classLabel) {
        coefMat <- coefList[[classLabel]]

        tibble::tibble(
          class       = classLabel,
          feature     = rownames(coefMat),
          coefficient = as.numeric(coefMat[, 1])
        )
      }
    )
  )
}

saveRegressionCoefficientPlot <- function(coefTable, modelId, title) {
  plotPath <- file.path(modelPlotsDir, paste0(modelId, '_coefficients.png'))

  plotObj <- coefTable |>
    dplyr::filter(feature != '(Intercept)') |>
    dplyr::mutate(absCoef = abs(coefficient)) |>
    dplyr::slice_max(absCoef, n = 20L, with_ties = FALSE) |>
    dplyr::mutate(feature = forcats::fct_reorder(feature, absCoef)) |>
    ggplot2::ggplot(ggplot2::aes(x = coefficient, y = feature, fill = coefficient > 0)) +
    ggplot2::geom_col(show.legend = FALSE) +
    ggplot2::scale_fill_manual(values = c('#C44E52', '#2F6CA8')) +
    ggplot2::labs(
      title = title,
      x     = 'Coefficient',
      y     = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12)

  ggplot2::ggsave(
    filename = plotPath,
    plot     = plotObj,
    width    = 9,
    height   = 6,
    dpi      = 180
  )

  plotPath
}

saveMultinomialCoefficientPlot <- function(coefTable, modelId, title) {
  plotPath <- file.path(modelPlotsDir, paste0(modelId, '_coefficients.png'))

  plotObj <- coefTable |>
    dplyr::filter(feature != '(Intercept)', coefficient != 0) |>
    dplyr::mutate(absCoef = abs(coefficient)) |>
    dplyr::group_by(class) |>
    dplyr::slice_max(absCoef, n = 10L, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      featureClass = paste(class, feature, sep = ' :: '),
      featureClass = forcats::fct_reorder(featureClass, coefficient)
    ) |>
    ggplot2::ggplot(ggplot2::aes(x = coefficient, y = featureClass, fill = class)) +
    ggplot2::geom_col(show.legend = FALSE) +
    ggplot2::facet_wrap(~ class, scales = 'free_y') +
    ggplot2::labs(
      title = title,
      x     = 'Coefficient',
      y     = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11)

  ggplot2::ggsave(
    filename = plotPath,
    plot     = plotObj,
    width    = 12,
    height   = 10,
    dpi      = 180
  )

  plotPath
}

predictTermProbabilities <- function(modelObject, testData) {
  probPred <- predict(modelObject$workflow, new_data = testData, type = 'prob')
  classPred <- predict(modelObject$workflow, new_data = testData, type = 'class')

  out <- dplyr::bind_cols(
    testData |>
      dplyr::transmute(
        contractRowId     = contractRowId,
        playerName        = playerName,
        playerKey         = playerKey,
        playerId          = playerId,
        pfrId             = pfrId,
        ageAtSigning      = ageAtSigning,
        yearsExpAtSigning = yearsExpAtSigning,
        prevSignedTeam    = prevSignedTeam
      ),
    probPred,
    tibble::tibble(predictedTerm = as.integer(as.character(classPred$.pred_class)))
  )

  probMatrix <- as.matrix(out[, paste0('.pred_', termLevels), drop = FALSE])

  out |>
    dplyr::mutate(
      expectedTerm = as.numeric(probMatrix %*% as.numeric(termLevels))
    )
}

predictAavScenarios <- function(modelObject, testData) {
  scenarioData <- testData |>
    dplyr::slice(rep(dplyr::row_number(), each = length(termScenarioVals))) |>
    dplyr::mutate(
      termScenario = rep(termScenarioVals, times = nrow(testData)),
      term         = factor(termScenario, levels = termLevels)
    )

  pred <- predict(modelObject$workflow, new_data = scenarioData)

  dplyr::bind_cols(
    scenarioData |>
      dplyr::transmute(
        contractRowId     = contractRowId,
        playerName        = playerName,
        playerKey         = playerKey,
        playerId          = playerId,
        pfrId             = pfrId,
        ageAtSigning      = ageAtSigning,
        yearsExpAtSigning = yearsExpAtSigning,
        prevSignedTeam    = prevSignedTeam,
        termScenario      = termScenario
      ),
    tibble::tibble(aavPercPrediction = pred$.pred)
  ) |>
    dplyr::mutate(
      impliedCap2026 = modelObject$impliedCap2026,
      aavPrediction  = aavPercPrediction * impliedCap2026
    )
}

pairScenarioPredictions <- function(
  pairId,
  termModelId,
  aavModelId,
  termPredictions,
  aavScenarios
) {
  termLong <- termPredictions |>
    dplyr::select(contractRowId, playerName, playerKey, playerId, pfrId, dplyr::starts_with('.pred_')) |>
    tidyr::pivot_longer(
      cols      = dplyr::starts_with('.pred_'),
      names_to  = 'termScenario',
      values_to = 'termProbability'
    ) |>
    dplyr::mutate(
      termScenario = as.integer(gsub('^\\.pred_', '', termScenario))
    )

  combinedScenarios <- aavScenarios |>
    dplyr::left_join(
      termLong,
      by = c('contractRowId', 'playerName', 'playerKey', 'playerId', 'pfrId', 'termScenario')
    ) |>
    dplyr::mutate(
      pairId                     = pairId,
      termModelId                = termModelId,
      aavModelId                 = aavModelId,
      weightedAavPercContribution = termProbability * aavPercPrediction,
      weightedAavContribution     = termProbability * aavPrediction
    )

  summary <- combinedScenarios |>
    dplyr::group_by(contractRowId, playerName, playerKey, playerId, pfrId) |>
    dplyr::summarise(
      pairId             = dplyr::first(pairId),
      termModelId        = dplyr::first(termModelId),
      aavModelId         = dplyr::first(aavModelId),
      ageAtSigning       = dplyr::first(ageAtSigning),
      yearsExpAtSigning  = dplyr::first(yearsExpAtSigning),
      prevSignedTeam     = dplyr::first(prevSignedTeam),
      expectedTerm       = sum(termScenario * termProbability, na.rm = TRUE),
      modalTerm          = termScenario[which.max(termProbability)][[1L]],
      modalTermProb      = max(termProbability, na.rm = TRUE),
      expectedAavPerc    = sum(weightedAavPercContribution, na.rm = TRUE),
      expectedAav        = sum(weightedAavContribution, na.rm = TRUE),
      modalAavPerc       = aavPercPrediction[which.max(termProbability)][[1L]],
      modalAav           = aavPrediction[which.max(termProbability)][[1L]],
      impliedCap2026     = dplyr::first(impliedCap2026),
      .groups            = 'drop'
    )

  list(
    scenarios = combinedScenarios,
    summary   = summary
  )
}

writeMetadataJson <- function(cap2026) {
  jsonlite::write_json(
    list(
      generatedAt   = as.character(Sys.time()),
      impliedCap2026 = cap2026,
      termLevels    = as.integer(termLevels)
    ),
    path        = file.path(finalDir, 'metadata.json'),
    auto_unbox  = TRUE,
    pretty      = TRUE
  )
}
