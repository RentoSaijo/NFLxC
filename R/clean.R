#!/usr/bin/env Rscript

options(readr.show_col_types = FALSE)

# —— Packages —— #
requiredPkgs <- c(
  'dplyr',
  'httr2',
  'janitor',
  'jsonlite',
  'nflreadr',
  'purrr',
  'readr',
  'stringr',
  'tidyr'
)

missingPkgs  <- requiredPkgs[!vapply(requiredPkgs, requireNamespace, logical(1), quietly = TRUE)]

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
contractsPattern   <- '^WR_Contracts_.*\\.csv$'
contractsDir       <- 'data'
trainPath          <- file.path('data', 'train.csv')
validatePath       <- file.path('data', 'validate.csv')
testPath           <- file.path('data', 'test.csv')
trainStartYear     <- 2002L
validateYear       <- 2026L
testReferenceDate  <- as.Date('2026-03-22')
minPlayerSeason    <- 1999L
playerSeasonRange  <- seq.int(from = minPlayerSeason, to = validateYear - 1L)
transactionYears   <- seq.int(from = trainStartYear - 1L, to = validateYear)

# —— Feature Families —— #
regularMetricCols <- c(
  'sourceAvailable',
  'games',
  'targets',
  'receptions',
  'receivingYards',
  'receivingTds',
  'receivingFirstDowns',
  'receivingEpa',
  'receivingAirYards',
  'receivingYardsAfterCatch',
  'carries',
  'rushingYards',
  'rushingTds',
  'targetShare',
  'airYardsShare',
  'wopr',
  'targetsPerGame',
  'receptionsPerGame',
  'receivingYardsPerGame',
  'receivingTdsPerGame',
  'receivingFirstDownsPerGame',
  'receivingEpaPerGame',
  'catchRate',
  'yardsPerTarget',
  'yardsPerReception',
  'tdPerTarget',
  'airYardsPerTarget',
  'yacPerReception',
  'rushYardsPerCarry',
  'teamTargetShareCalc',
  'teamYardsShareCalc',
  'teamTdShareCalc',
  'teamAirYardsShareCalc'
)

snapMetricCols <- c(
  'sourceAvailable',
  'snapGames',
  'offenseSnaps',
  'offenseSnapsPerGame',
  'offensePctMean',
  'offensePctMax',
  'stSnaps',
  'stSnapsPerGame',
  'stPctMean',
  'offenseSnapShare'
)

ngsMetricCols <- c(
  'sourceAvailable',
  'targets',
  'receptions',
  'yards',
  'recTouchdowns',
  'catchPercentage',
  'avgCushion',
  'avgSeparation',
  'avgIntendedAirYards',
  'percentShareOfIntendedAirYards',
  'avgAirDistance',
  'maxAirDistance',
  'avgYac',
  'avgExpectedYac',
  'avgYacAboveExpectation',
  'efficiency',
  'yardsPerTarget',
  'yardsPerReception',
  'tdPerTarget'
)

teamMetricCols <- c(
  'sourceAvailable',
  'games',
  'wins',
  'losses',
  'ties',
  'winPct',
  'attempts',
  'passingYards',
  'passingTds',
  'passingEpa',
  'passingCpoe',
  'carries',
  'rushingYards',
  'rushingEpa',
  'points',
  'pointsAgainst',
  'pointDiff',
  'marginPerGame',
  'targets',
  'receivingYards',
  'receivingTds',
  'receivingAirYards',
  'passRate',
  'teamPlays',
  'passingYardsPerAttempt',
  'passingYardsPerGame',
  'passingTdsPerGame',
  'passingEpaPerGame',
  'pointsPerGame',
  'receivingYardsPerTarget',
  'passRateDiffLeague',
  'passingYardsPerGameDiffLeague',
  'passingEpaPerGameDiffLeague',
  'pointsPerGameDiffLeague'
)

marketMetricCols <- c(
  'sourceAvailable',
  'contractCount',
  'medianTerm',
  'medianAav',
  'medianAavPerc',
  'p75AavPerc',
  'medianAgeAtSigning'
)

seasonTeamCols <- c('seasonTeam')

# —— Helpers —— #
capFirst <- function(x) {
  ifelse(
    nchar(x) > 0L,
    paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x))),
    x
  )
}

parseNumericAny <- function(x) {
  if (is.numeric(x)) {
    return(as.numeric(x))
  }

  readr::parse_number(as.character(x), na = c('', 'NA', 'NULL'))
}

normalizeText <- function(x) {
  x <- iconv(as.character(x), to = 'ASCII//TRANSLIT', sub = ' ')

  x |>
    stringr::str_replace_all('[*+]', ' ') |>
    stringr::str_replace_all('[[:punct:]]', ' ') |>
    stringr::str_replace_all('\\b(jr|sr|ii|iii|iv|v)\\b', ' ') |>
    stringr::str_squish() |>
    stringr::str_to_lower()
}

normalizePlayerName <- function(x) {
  normalizeText(x)
}

compactText <- function(x) {
  stringr::str_replace_all(normalizeText(x), ' ', '')
}

firstToken <- function(x) {
  stringr::word(x, 1L)
}

lastToken <- function(x) {
  stringr::word(x, -1L)
}

safeDetectWord <- function(text, token) {
  escaped <- stringr::str_replace_all(token, '([^[:alnum:]])', '\\\\\\1')

  !is.na(token) &
    token != '' &
    stringr::str_detect(text, stringr::regex(paste0('\\b', escaped, '\\b')))
}

pickCol <- function(df, candidates, default = NA_character_) {
  hit <- candidates[candidates %in% names(df)]

  if (length(hit) == 0L) {
    return(rep(default, nrow(df)))
  }

  df[[hit[1L]]]
}

firstNonMissingChr <- function(x) {
  values <- as.character(x)
  values <- values[!is.na(values) & values != '']

  if (length(values) == 0L) {
    return(NA_character_)
  }

  values[1L]
}

lastNonMissingChr <- function(x) {
  values <- as.character(x)
  values <- values[!is.na(values) & values != '']

  if (length(values) == 0L) {
    return(NA_character_)
  }

  values[length(values)]
}

firstNonMissingNum <- function(x) {
  values <- as.numeric(x)
  values <- values[!is.na(values)]

  if (length(values) == 0L) {
    return(NA_real_)
  }

  values[1L]
}

minNonMissingNum <- function(x) {
  values <- as.numeric(x)
  values <- values[!is.na(values)]

  if (length(values) == 0L) {
    return(NA_real_)
  }

  min(values)
}

maxNonMissingNum <- function(x) {
  values <- as.numeric(x)
  values <- values[!is.na(values)]

  if (length(values) == 0L) {
    return(NA_real_)
  }

  max(values)
}

meanOrNa <- function(x) {
  values <- as.numeric(x)
  values <- values[!is.na(values)]

  if (length(values) == 0L) {
    return(NA_real_)
  }

  mean(values)
}

safeRate <- function(value, denominator) {
  dplyr::if_else(!is.na(denominator) & denominator > 0, value / denominator, NA_real_)
}

safeShare <- function(partValue, totalValue) {
  dplyr::if_else(!is.na(totalValue) & totalValue > 0, partValue / totalValue, NA_real_)
}

weightedTwoYear <- function(prev2, prev1) {
  dplyr::case_when(
    !is.na(prev2) & !is.na(prev1) ~ (prev2 + (2 * prev1)) / 3,
    !is.na(prev1)                 ~ prev1,
    !is.na(prev2)                 ~ prev2,
    TRUE                          ~ NA_real_
  )
}

deltaTwoYear <- function(prev2, prev1) {
  dplyr::case_when(
    !is.na(prev2) & !is.na(prev1) ~ prev1 - prev2,
    TRUE                          ~ 0
  )
}

bucketLongTerm <- function(termValue) {
  dplyr::if_else(
    is.na(termValue),
    termValue,
    pmin(termValue, 5)
  )
}

ageOnDate <- function(birthDate, referenceDate) {
  birthDate     <- as.Date(birthDate)
  referenceDate <- as.Date(referenceDate)

  birthLt <- as.POSIXlt(birthDate)
  refLt   <- as.POSIXlt(referenceDate)

  years <- refLt$year - birthLt$year
  beforeBirthday <- (refLt$mon < birthLt$mon) |
    ((refLt$mon == birthLt$mon) & (refLt$mday < birthLt$mday))

  dplyr::if_else(
    is.na(birthDate) | is.na(referenceDate),
    NA_real_,
    as.numeric(years - beforeBirthday)
  )
}

standardizeTeam <- function(x) {
  nflreadr::clean_team_abbrs(stringr::str_squish(as.character(x)))
}

offseasonReferenceDate <- function(startYear) {
  years <- as.integer(startYear)
  out   <- rep(as.Date(NA), length(years))
  valid <- !is.na(years)

  out[valid] <- as.Date(sprintf('%d-03-15', years[valid]))
  out
}

renameSelected <- function(df, cols, newNames) {
  idx <- match(cols, names(df))
  names(df)[idx] <- newNames
  df
}

safeFetch <- function(fetchFun, label) {
  tryCatch(
    fetchFun(),
    error = function(e) {
      message(sprintf('Failed to pull %s: %s', label, e$message))
      dplyr::tibble()
    }
  )
}

retryFetch <- function(fetchFun, label, attempts = 3L, sleepSeconds = 1) {
  for (attempt in seq_len(attempts)) {
    out <- tryCatch(
      fetchFun(),
      error = function(e) {
        message(sprintf('Attempt %d failed for %s: %s', attempt, label, e$message))
        NULL
      }
    )

    if (!is.null(out)) {
      return(out)
    }

    if (attempt < attempts) {
      Sys.sleep(sleepSeconds * attempt)
    }
  }

  dplyr::tibble()
}

presentSeasons <- function(df) {
  seasons <- parseNumericAny(pickCol(df, c('season'), NA_integer_))
  seasons <- sort(unique(as.integer(seasons)))
  seasons[!is.na(seasons)]
}

pullSeasonsWithBackfill <- function(seasons, fetchManyFun, fetchOneFun, label) {
  raw             <- safeFetch(fetchManyFun, label)
  loadedSeasons   <- presentSeasons(raw)
  missingSeasons  <- setdiff(seasons, loadedSeasons)

  if (length(missingSeasons) == 0L) {
    return(raw)
  }

  message(sprintf(
    'Retrying %s for missing seasons: %s.',
    label,
    paste(missingSeasons, collapse = ', ')
  ))

  retryRows <- purrr::map_dfr(
    missingSeasons,
    function(season) {
      retryFetch(
        function() fetchOneFun(season),
        sprintf('%s season %d', label, season)
      )
    }
  )

  dplyr::bind_rows(raw, retryRows)
}

pullSchedulesRaw <- function(seasons) {
  pullSeasonsWithBackfill(
    seasons,
    function() nflreadr::load_schedules(seasons),
    function(season) nflreadr::load_schedules(season),
    'nflreadr::load_schedules'
  )
}

buildSeasonCalendar <- function(schedulesRaw) {
  scheduleDates <- as.data.frame(schedulesRaw)
  scheduleDates$gamedayRaw <- pickCol(scheduleDates, c('gameday', 'game_date'), NA_character_)

  scheduleDates |>
    dplyr::filter(game_type == 'REG', !is.na(gamedayRaw), gamedayRaw != '') |>
    dplyr::transmute(
      season        = as.integer(season),
      seasonEndDate = as.Date(gamedayRaw)
    ) |>
    dplyr::group_by(season) |>
    dplyr::summarise(
      seasonEndDate = max(seasonEndDate, na.rm = TRUE),
      .groups = 'drop'
    ) |>
    dplyr::arrange(season)
}

derivePriorCompletedSeasons <- function(referenceDates, seasonCalendar) {
  dates      <- as.Date(referenceDates)
  endDates   <- seasonCalendar$seasonEndDate
  seasonVals <- seasonCalendar$season
  prev1      <- rep(NA_integer_, length(dates))
  prev2      <- rep(NA_integer_, length(dates))

  for (i in seq_along(dates)) {
    if (is.na(dates[[i]])) {
      next
    }

    completed <- seasonVals[!is.na(endDates) & endDates < dates[[i]]]

    if (length(completed) >= 1L) {
      prev1[[i]] <- completed[[length(completed)]]
    }

    if (length(completed) >= 2L) {
      prev2[[i]] <- completed[[length(completed) - 1L]]
    }
  }

  dplyr::tibble(
    prev1Season = prev1,
    prev2Season = prev2
  )
}

assignPriorCompletedSeasons <- function(data, referenceCol, seasonCalendar) {
  priorSeasons <- derivePriorCompletedSeasons(data[[referenceCol]], seasonCalendar)

  data$prev1Season <- priorSeasons$prev1Season
  data$prev2Season <- priorSeasons$prev2Season
  data
}

extractSigningTermHint <- function(clause) {
  clauseNorm <- normalizeText(clause)

  dplyr::case_when(
    stringr::str_detect(clauseNorm, '\\b(one|1)[ -]?year\\b')   ~ 1L,
    stringr::str_detect(clauseNorm, '\\b(two|2)[ -]?year\\b')   ~ 2L,
    stringr::str_detect(clauseNorm, '\\b(three|3)[ -]?year\\b') ~ 3L,
    stringr::str_detect(clauseNorm, '\\b(four|4)[ -]?year\\b')  ~ 4L,
    stringr::str_detect(clauseNorm, '\\b(five|5)[ -]?year\\b')  ~ 5L,
    stringr::str_detect(clauseNorm, '\\b(six|6)[ -]?year\\b')   ~ 6L,
    stringr::str_detect(clauseNorm, '\\b(seven|7)[ -]?year\\b') ~ 7L,
    stringr::str_detect(clauseNorm, '\\b(eight|8)[ -]?year\\b') ~ 8L,
    stringr::str_detect(clauseNorm, '\\b(5th|fifth) year option\\b') ~ 1L,
    stringr::str_detect(clauseNorm, '\\bfranchise tag\\b') ~ 1L,
    stringr::str_detect(clauseNorm, '\\btransition tag\\b') ~ 1L,
    stringr::str_detect(clauseNorm, '\\btendered\\b') ~ 1L,
    stringr::str_detect(clauseNorm, '\\bexclusive rights free agent\\b') ~ 1L,
    TRUE ~ NA_integer_
  )
}

extractSigningEndYearHint <- function(clause) {
  throughYear <- stringr::str_match(
    clause,
    stringr::regex('through(?: the)? (\\d{4}) (?:season|campaign)', ignore_case = TRUE)
  )[, 2L]

  as.integer(throughYear)
}

classifySigningAction <- function(clause) {
  clauseNorm <- normalizeText(clause)

  dplyr::case_when(
    stringr::str_detect(clauseNorm, '^re signed\\b') ~ 'resign',
    stringr::str_detect(clauseNorm, '5th year option') ~ 'fifth_year_option',
    stringr::str_detect(clauseNorm, 'franchise tag|transition tag') ~ 'tag',
    stringr::str_detect(clauseNorm, '^tendered\\b') ~ 'tender',
    stringr::str_detect(clauseNorm, 'extension') ~ 'extension',
    stringr::str_detect(clauseNorm, '^agreed to terms with\\b') ~ 'agreed',
    stringr::str_detect(clauseNorm, '^signed\\b') ~ 'signed',
    TRUE ~ 'other'
  )
}

splitTransactionClauses <- function(description) {
  stringr::str_split(
    description,
    '(?<=\\.)\\s+(?=(?:Signed|Re-signed|Agreed to terms with|Exercised|Placed|Applied|Tendered|Waived|Released|Activated|Promoted|Claimed|Traded|Named|Hired|Fired|Designated|Converted|Restructured)\\b)'
  )[[1L]] |>
    stringr::str_squish() |>
    stats::na.omit() |>
    as.character() |>
    (\(x) x[x != ''])()
}

isContractLikeClause <- function(clause) {
  clauseNorm <- normalizeText(clause)

  startsLikeContract <- stringr::str_detect(
    clauseNorm,
    '^(signed|re signed|agreed to terms with|exercised the 5th year option for|placed the franchise tag on|applied the franchise tag to|tendered)\\b'
  )

  hasRosterMove <- stringr::str_detect(
    clauseNorm,
    stringr::regex(
      paste(
        c(
          'active roster',
          'practice squad',
          'injured reserve',
          'return from injured reserve',
          'pup list',
          'non football injury',
          'waivers?',
          'waived',
          'released',
          'terminated',
          'traded',
          'promoted',
          'activated',
          'elevated',
          'designated',
          'converted',
          'restructured'
        ),
        collapse = '|'
      ),
      ignore_case = TRUE
    )
  )

  hasStaffMove <- stringr::str_detect(
    clauseNorm,
    stringr::regex(
      paste(
        c(
          'coach',
          'coordinator',
          'manager',
          'president',
          'assistant',
          'analyst',
          'advisor',
          'scouting',
          'director',
          'quality control',
          'front office',
          'chief operating officer',
          'business operations',
          'hired',
          'fired',
          'named'
        ),
        collapse = '|'
      ),
      ignore_case = TRUE
    )
  )

  startsLikeContract & !hasRosterMove & !hasStaffMove
}

performEspnTransactionRequest <- function(dates, page) {
  request <- httr2::request('https://site.api.espn.com/apis/site/v2/sports/football/nfl/transactions') |>
    httr2::req_url_query(limit = 1000L, page = page, dates = dates)

  response <- tryCatch(
    httr2::req_perform(request),
    error = function(e) {
      NULL
    }
  )

  if (is.null(response)) {
    return(NULL)
  }

  if (httr2::resp_status(response) >= 400L) {
    return(NULL)
  }

  jsonlite::fromJSON(
    httr2::resp_body_string(response),
    simplifyDataFrame = TRUE,
    flatten           = TRUE
  )
}

extractEspnTransactionRows <- function(payload) {
  tx <- payload$transactions

  if (is.null(tx) || length(tx) == 0L) {
    return(dplyr::tibble())
  }

  tx <- as.data.frame(tx, stringsAsFactors = FALSE)

  dplyr::tibble(
    txDate      = as.Date(substr(pickCol(tx, c('date'), ''), 1L, 10L)),
    signedTeam  = standardizeTeam(pickCol(tx, c('team.abbreviation'), NA_character_)),
    description = stringr::str_squish(pickCol(tx, c('description'), NA_character_))
  ) |>
    dplyr::filter(!is.na(txDate), !is.na(signedTeam), !is.na(description), description != '')
}

fetchEspnTransactionsYear <- function(calendarYear) {
  dates        <- sprintf('%d0101-%d1231', calendarYear, calendarYear)
  payloadFirst <- retryFetch(
    function() performEspnTransactionRequest(dates, 1L),
    sprintf('ESPN NFL transactions %d page 1', calendarYear)
  )

  if (is.null(payloadFirst) || length(payloadFirst) == 0L) {
    return(dplyr::tibble())
  }

  pageCount <- as.integer(parseNumericAny(payloadFirst$pageCount))
  rows      <- extractEspnTransactionRows(payloadFirst)

  if (is.na(pageCount) || pageCount <= 1L) {
    return(rows)
  }

  moreRows <- purrr::map_dfr(
    seq.int(from = 2L, to = pageCount),
    function(page) {
      payload <- retryFetch(
        function() performEspnTransactionRequest(dates, page),
        sprintf('ESPN NFL transactions %d page %d', calendarYear, page)
      )

      if (is.null(payload) || length(payload) == 0L) {
        return(dplyr::tibble())
      }

      extractEspnTransactionRows(payload)
    }
  )

  dplyr::bind_rows(rows, moreRows)
}

buildEspnTransactions <- function(calendarYears) {
  purrr::map_dfr(
    sort(unique(as.integer(calendarYears))),
    fetchEspnTransactionsYear
  ) |>
    dplyr::distinct()
}

buildSigningClauses <- function(transactions) {
  if (nrow(transactions) == 0L) {
    return(
      dplyr::tibble(
        txDate         = as.Date(character()),
        signedTeam     = character(),
        clause         = character(),
        clauseNorm     = character(),
        clauseCompact  = character(),
        termTx         = integer(),
        endYearTx      = integer(),
        actionType     = character(),
        positionWrHint = logical()
      )
    )
  }

  transactions |>
    dplyr::mutate(clause = purrr::map(description, splitTransactionClauses)) |>
    tidyr::unnest_longer(clause) |>
    dplyr::mutate(clause = stringr::str_squish(clause)) |>
    dplyr::filter(clause != '') |>
    dplyr::filter(isContractLikeClause(clause)) |>
    dplyr::mutate(
      clauseNorm     = normalizeText(clause),
      clauseCompact  = compactText(clause),
      termTx         = extractSigningTermHint(clause),
      endYearTx      = extractSigningEndYearHint(clause),
      actionType     = classifySigningAction(clause),
      positionWrHint = safeDetectWord(clauseNorm, 'wr') |
        stringr::str_detect(clauseNorm, '\\bwide receiver\\b')
    ) |>
    dplyr::distinct(signedTeam, txDate, clause, .keep_all = TRUE)
}

matchSigningDates <- function(contracts, signingClauses) {
  if (nrow(signingClauses) == 0L) {
    return(
      dplyr::tibble(
        contractRowId          = integer(),
        dateOfSigningObserved  = as.Date(character())
      )
    )
  }

  candidates <- contracts |>
    dplyr::filter(!is.na(startYear), !is.na(signedTeam), !is.na(playerKey), playerKey != '') |>
    dplyr::transmute(
      contractRowId,
      signedTeam,
      startYear,
      endYear,
      termRounded         = as.integer(round(termRaw)),
      prevSignedTeam,
      windowStart         = as.Date(sprintf('%d-07-01', startYear - 1L)),
      windowEnd           = as.Date(sprintf('%d-12-31', startYear)),
      dateTarget          = offseasonReferenceDate(startYear),
      nameNorm            = playerKey,
      nameCompact         = compactText(playerKey),
      firstName           = firstToken(playerKey),
      lastName            = lastToken(playerKey),
      sameTeamContinuation = !is.na(prevSignedTeam) & prevSignedTeam == signedTeam
    ) |>
    dplyr::inner_join(signingClauses, by = 'signedTeam', relationship = 'many-to-many') |>
    dplyr::filter(txDate >= windowStart, txDate <= windowEnd) |>
    dplyr::mutate(
      lastHit         = safeDetectWord(clauseNorm, lastName),
      fullHit         = stringr::str_detect(clauseCompact, stringr::fixed(nameCompact)),
      firstHit        = nchar(firstName) > 1L & safeDetectWord(clauseNorm, firstName),
      firstInitialHit = nchar(firstName) > 0L &
        stringr::str_detect(
          clauseNorm,
          stringr::regex(paste0('\\b', substr(firstName, 1L, 1L), '\\.?\\b'))
        ),
      termOk          = is.na(termTx) | is.na(termRounded) | termTx == termRounded,
      endOk           = is.na(endYearTx) | is.na(endYear) | endYearTx == endYear,
      nameScore       = dplyr::case_when(
        fullHit         ~ 100L,
        firstHit        ~ 90L,
        firstInitialHit ~ 80L,
        TRUE            ~ 70L
      ),
      continuityScore = dplyr::case_when(
        sameTeamContinuation & actionType %in% c('resign', 'extension', 'tag', 'tender', 'fifth_year_option') ~ 5L,
        !sameTeamContinuation & actionType %in% c('signed', 'agreed') ~ 2L,
        TRUE ~ 0L
      ),
      dateGap = abs(as.integer(txDate - dateTarget)),
      score   = nameScore +
        dplyr::if_else(positionWrHint, 5L, 0L) +
        dplyr::if_else(!is.na(termTx), 10L, 0L) +
        dplyr::if_else(!is.na(endYearTx), 15L, 0L) +
        continuityScore
    ) |>
    dplyr::filter(lastHit, termOk, endOk, nameScore >= 80L)

  candidates |>
    dplyr::arrange(contractRowId, dplyr::desc(score), dateGap, txDate) |>
    dplyr::group_by(contractRowId) |>
    dplyr::mutate(
      rank      = dplyr::row_number(),
      nextScore = dplyr::nth(score, 2L, default = NA_integer_),
      nextGap   = dplyr::nth(dateGap, 2L, default = NA_integer_),
      nextDate  = dplyr::nth(txDate, 2L, default = as.Date(NA)),
      accepted  = is.na(nextScore) |
        score > nextScore |
        (score == nextScore & dateGap < nextGap) |
        (score == nextScore & dateGap == nextGap & txDate < nextDate)
    ) |>
    dplyr::ungroup() |>
    dplyr::filter(rank == 1L, accepted) |>
    dplyr::transmute(
      contractRowId,
      dateOfSigningObserved = txDate
    )
}

buildLagTable <- function(source, keyCol, seasonCol, valueCols, prefix, lagLabel, fallback = FALSE) {
  out <- source

  names(out)[match('season', names(out))] <- seasonCol
  out <- out[, c(keyCol, seasonCol, valueCols), drop = FALSE]

  newNames <- paste0(prefix, lagLabel, capFirst(valueCols))

  if (fallback) {
    newNames <- paste0(newNames, 'Fallback')
  }

  renameSelected(out, valueCols, newNames)
}

addWeightedDeltaFeatures <- function(data, prefix, metricCols) {
  for (metric in metricCols) {
    prev1Col    <- paste0(prefix, 'Prev1', capFirst(metric))
    prev2Col    <- paste0(prefix, 'Prev2', capFirst(metric))
    weightedCol <- paste0(prefix, 'Weighted', capFirst(metric))
    deltaCol    <- paste0(prefix, 'Delta', capFirst(metric))

    data[[weightedCol]] <- weightedTwoYear(data[[prev2Col]], data[[prev1Col]])
    data[[deltaCol]]    <- deltaTwoYear(data[[prev2Col]], data[[prev1Col]])
  }

  data
}

addHybridPlayerBlock <- function(data, source, prefix, idCol, keepCols = seasonTeamCols) {
  valueCols       <- setdiff(names(source), c('season', 'playerKey', idCol))
  metricCols      <- setdiff(valueCols, keepCols)
  weightedCols    <- setdiff(metricCols, 'sourceAvailable')
  fallbackSource  <- source |>
    dplyr::add_count(playerKey, season, name = 'nameSeasonCount') |>
    dplyr::filter(nameSeasonCount == 1L) |>
    dplyr::select(-nameSeasonCount)

  for (lagLabel in c('Prev1', 'Prev2')) {
    seasonCol    <- if (lagLabel == 'Prev1') 'prev1Season' else 'prev2Season'
    primaryTable <- buildLagTable(source, idCol, seasonCol, valueCols, prefix, lagLabel, fallback = FALSE)
    fallbackTable <- buildLagTable(fallbackSource, 'playerKey', seasonCol, valueCols, prefix, lagLabel, fallback = TRUE)

    primaryTable <- primaryTable |>
      dplyr::group_by(dplyr::across(dplyr::all_of(c(idCol, seasonCol)))) |>
      dplyr::slice_head(n = 1) |>
      dplyr::ungroup()

    fallbackTable <- fallbackTable |>
      dplyr::group_by(dplyr::across(dplyr::all_of(c('playerKey', seasonCol)))) |>
      dplyr::slice_head(n = 1) |>
      dplyr::ungroup()

    data <- dplyr::left_join(
      data,
      primaryTable,
      by           = stats::setNames(c(idCol, seasonCol), c(idCol, seasonCol)),
      relationship = 'many-to-one',
      na_matches   = 'never'
    )
    data <- dplyr::left_join(
      data,
      fallbackTable,
      by           = c('playerKey', seasonCol),
      relationship = 'many-to-one',
      na_matches   = 'never'
    )

    finalCols    <- paste0(prefix, lagLabel, capFirst(valueCols))
    fallbackCols <- paste0(finalCols, 'Fallback')

    for (i in seq_along(finalCols)) {
      data[[finalCols[[i]]]] <- dplyr::coalesce(data[[finalCols[[i]]]], data[[fallbackCols[[i]]]])
    }

    data <- data |>
      dplyr::select(-dplyr::any_of(fallbackCols))
  }

  data[[paste0(prefix, 'Prev1Available')]] <- dplyr::coalesce(data[[paste0(prefix, 'Prev1SourceAvailable')]], FALSE)
  data[[paste0(prefix, 'Prev2Available')]] <- dplyr::coalesce(data[[paste0(prefix, 'Prev2SourceAvailable')]], FALSE)
  data[[paste0(prefix, 'YearsAvailable')]] <- as.integer(data[[paste0(prefix, 'Prev1Available')]]) +
    as.integer(data[[paste0(prefix, 'Prev2Available')]])

  addWeightedDeltaFeatures(data, prefix, weightedCols)
}

addSimpleKeyBlock <- function(data, source, prefix, baseKeyCol, sourceKeyCol, keepCols = character()) {
  valueCols    <- setdiff(names(source), c('season', sourceKeyCol))
  metricCols   <- setdiff(valueCols, keepCols)
  weightedCols <- setdiff(metricCols, 'sourceAvailable')

  for (lagLabel in c('Prev1', 'Prev2')) {
    seasonCol <- if (lagLabel == 'Prev1') 'prev1Season' else 'prev2Season'
    joinTable <- source

    names(joinTable)[match(sourceKeyCol, names(joinTable))] <- baseKeyCol
    joinTable <- buildLagTable(joinTable, baseKeyCol, seasonCol, valueCols, prefix, lagLabel, fallback = FALSE)
    joinTable <- joinTable |>
      dplyr::group_by(dplyr::across(dplyr::all_of(c(baseKeyCol, seasonCol)))) |>
      dplyr::slice_head(n = 1) |>
      dplyr::ungroup()

    data <- dplyr::left_join(
      data,
      joinTable,
      by           = stats::setNames(c(baseKeyCol, seasonCol), c(baseKeyCol, seasonCol)),
      relationship = 'many-to-one',
      na_matches   = 'never'
    )
  }

  data[[paste0(prefix, 'Prev1Available')]] <- dplyr::coalesce(data[[paste0(prefix, 'Prev1SourceAvailable')]], FALSE)
  data[[paste0(prefix, 'Prev2Available')]] <- dplyr::coalesce(data[[paste0(prefix, 'Prev2SourceAvailable')]], FALSE)
  data[[paste0(prefix, 'YearsAvailable')]] <- as.integer(data[[paste0(prefix, 'Prev1Available')]]) +
    as.integer(data[[paste0(prefix, 'Prev2Available')]])

  addWeightedDeltaFeatures(data, prefix, weightedCols)
}

addSeasonBlock <- function(data, source, prefix) {
  valueCols    <- setdiff(names(source), 'season')
  metricCols   <- valueCols
  weightedCols <- setdiff(metricCols, 'sourceAvailable')

  for (lagLabel in c('Prev1', 'Prev2')) {
    seasonCol <- if (lagLabel == 'Prev1') 'prev1Season' else 'prev2Season'
    joinTable <- source
    names(joinTable)[match('season', names(joinTable))] <- seasonCol
    joinTable <- joinTable[, c(seasonCol, valueCols), drop = FALSE]
    joinTable <- renameSelected(
      joinTable,
      valueCols,
      paste0(prefix, lagLabel, capFirst(valueCols))
    )
    joinTable <- joinTable |>
      dplyr::group_by(dplyr::across(dplyr::all_of(seasonCol))) |>
      dplyr::slice_head(n = 1) |>
      dplyr::ungroup()

    data <- dplyr::left_join(
      data,
      joinTable,
      by           = seasonCol,
      relationship = 'many-to-one',
      na_matches   = 'never'
    )
  }

  data[[paste0(prefix, 'Prev1Available')]] <- dplyr::coalesce(data[[paste0(prefix, 'Prev1SourceAvailable')]], FALSE)
  data[[paste0(prefix, 'Prev2Available')]] <- dplyr::coalesce(data[[paste0(prefix, 'Prev2SourceAvailable')]], FALSE)
  data[[paste0(prefix, 'YearsAvailable')]] <- as.integer(data[[paste0(prefix, 'Prev1Available')]]) +
    as.integer(data[[paste0(prefix, 'Prev2Available')]])

  addWeightedDeltaFeatures(data, prefix, weightedCols)
}

# —— Contracts —— #
readContracts <- function(dataDir, pattern) {
  files <- list.files(dataDir, pattern = pattern, full.names = TRUE)

  if (length(files) == 0L) {
    stop('No WR contract files matched expected pattern.', call. = FALSE)
  }

  raw <- purrr::map_dfr(
    sort(files),
    function(path) {
      readr::read_csv(path, col_types = readr::cols(.default = readr::col_character())) |>
        janitor::clean_names() |>
        dplyr::mutate(sourceFile = basename(path))
    }
  )

  raw$capPctRaw <- pickCol(
    raw,
    c('average_percent_percent_of_cap_at_sign', 'average_of_cap_at_sign')
  )

  raw |>
    dplyr::transmute(
      contractRowId         = dplyr::row_number(),
      sourceFile            = sourceFile,
      playerName            = stringr::str_squish(player),
      playerKey             = normalizePlayerName(player),
      pos                   = stringr::str_squish(pos),
      signedTeamRaw         = stringr::str_squish(team_signed_with),
      signedTeam            = standardizeTeam(stringr::str_extract(signedTeamRaw, '([A-Z]{2,3})$')),
      ageAtSigning          = parseNumericAny(age_at_signing),
      startYear             = as.integer(parseNumericAny(start_year)),
      endYearRaw            = as.integer(parseNumericAny(end_year)),
      termRaw               = parseNumericAny(yrs),
      totalValue            = parseNumericAny(value),
      aav                   = parseNumericAny(average_salary),
      aavPerc               = parseNumericAny(capPctRaw) / 100,
      signingBonus          = parseNumericAny(signing_bonus),
      guaranteeAtSign       = parseNumericAny(guarantee_at_sign),
      practicalGuarantee    = parseNumericAny(practical_guarantee)
    ) |>
    dplyr::filter(pos == 'WR') |>
    dplyr::mutate(
      expectedEndYear = dplyr::if_else(
        !is.na(startYear) & !is.na(termRaw),
        startYear + as.integer(round(termRaw)) - 1L,
        NA_integer_
      ),
      endYear = dplyr::case_when(
        is.na(endYearRaw) ~ expectedEndYear,
        !is.na(expectedEndYear) &
          (endYearRaw < startYear | endYearRaw > startYear + 10L) ~ expectedEndYear,
        TRUE ~ endYearRaw
      ),
      term = bucketLongTerm(termRaw)
    ) |>
    dplyr::select(
      contractRowId,
      sourceFile,
      playerName,
      playerKey,
      pos,
      signedTeamRaw,
      signedTeam,
      ageAtSigning,
      startYear,
      endYearRaw,
      endYear,
      expectedEndYear,
      termRaw,
      term,
      totalValue,
      aav,
      aavPerc,
      signingBonus,
      guaranteeAtSign,
      practicalGuarantee
    ) |>
    dplyr::mutate(
      endYear = dplyr::case_when(
        is.na(endYear) ~ expectedEndYear,
        TRUE ~ endYear
      )
    ) |>
    dplyr::arrange(playerKey, startYear, dplyr::desc(endYear), dplyr::desc(term), dplyr::desc(aav), contractRowId) |>
    dplyr::group_by(playerKey) |>
    dplyr::mutate(
      coveredByEarlierContract = purrr::map_lgl(
        seq_len(dplyr::n()),
        function(i) {
          if (i == 1L) {
            return(FALSE)
          }

          earlier <- seq_len(i - 1L)

          any(
            !is.na(signedTeam[earlier]) &
              signedTeam[earlier] == signedTeam[i] &
              !is.na(startYear[earlier]) &
              !is.na(endYear[earlier]) &
              !is.na(startYear[i]) &
              !is.na(endYear[i]) &
              startYear[earlier] < startYear[i] &
              endYear[earlier] >= endYear[i]
          )
        }
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::filter(!coveredByEarlierContract) |>
    dplyr::select(-coveredByEarlierContract) |>
    dplyr::arrange(playerKey, startYear, endYear, aav, contractRowId) |>
    dplyr::group_by(playerKey) |>
    dplyr::mutate(
      observedContractNumber = dplyr::row_number(),
      prevContractStartYear  = dplyr::lag(startYear),
      prevContractEndYear    = dplyr::lag(endYear),
      prevContractTerm       = dplyr::lag(term),
      prevContractAav        = dplyr::lag(aav),
      prevContractAavPerc    = dplyr::lag(aavPerc),
      prevSignedTeam         = dplyr::lag(signedTeam),
      gapSincePrevContractEnd = dplyr::if_else(
        !is.na(prevContractEndYear),
        startYear - prevContractEndYear,
        NA_real_
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      dateOfSigningObserved = as.Date(NA),
      featureReferenceDate  = as.Date(NA),
      signingDateObserved   = FALSE,
      signingDateSource     = NA_character_
    )
}

# —— Metadata —— #
buildPlayerReference <- function() {
  playersRaw <- safeFetch(
    function() nflreadr::load_players(),
    'nflreadr::load_players'
  )
  combineRaw <- safeFetch(
    function() nflreadr::load_combine(),
    'nflreadr::load_combine'
  )

  rosterYears <- 1999:2025
  rostersRaw  <- pullSeasonsWithBackfill(
    rosterYears,
    function() nflreadr::load_rosters(rosterYears),
    function(season) nflreadr::load_rosters(season),
    'nflreadr::load_rosters'
  )

  playersWr <- as.data.frame(playersRaw) |>
    dplyr::transmute(
      playerId           = as.character(gsis_id),
      pfrId              = as.character(pfr_id),
      displayName        = stringr::str_squish(display_name),
      playerKey          = normalizePlayerName(display_name),
      birthDate          = as.Date(birth_date),
      height             = parseNumericAny(height),
      weight             = parseNumericAny(weight),
      draftYear          = as.integer(parseNumericAny(draft_year)),
      rookieSeason       = as.integer(parseNumericAny(rookie_season)),
      draftRound         = as.integer(parseNumericAny(draft_round)),
      draftPick          = as.integer(parseNumericAny(draft_pick)),
      latestTeam         = standardizeTeam(latest_team),
      yearsOfExperience  = parseNumericAny(years_of_experience),
      collegeName        = stringr::str_squish(college_name),
      position           = position
    ) |>
    dplyr::filter(position == 'WR') |>
    dplyr::select(-position)

  combineWr <- as.data.frame(combineRaw) |>
    dplyr::transmute(
      pfrId            = as.character(pfr_id),
      combineForty     = parseNumericAny(forty),
      combineBench     = parseNumericAny(bench),
      combineVertical  = parseNumericAny(vertical),
      combineBroadJump = parseNumericAny(broad_jump),
      combineCone      = parseNumericAny(cone),
      combineShuttle   = parseNumericAny(shuttle),
      position         = pos
    ) |>
    dplyr::filter(position == 'WR', !is.na(pfrId), pfrId != '') |>
    dplyr::select(-position) |>
    dplyr::group_by(pfrId) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup()

  rostersWr <- as.data.frame(rostersRaw) |>
    dplyr::transmute(
      playerId           = as.character(gsis_id),
      displayNameRoster  = stringr::str_squish(full_name),
      playerKeyRoster    = normalizePlayerName(full_name),
      birthDateRoster    = as.Date(birth_date),
      heightRoster       = parseNumericAny(height),
      weightRoster       = parseNumericAny(weight),
      draftYearRoster    = as.integer(parseNumericAny(entry_year)),
      rookieSeasonRoster = as.integer(parseNumericAny(rookie_year)),
      draftPickRoster    = as.integer(parseNumericAny(draft_number)),
      latestTeamRoster   = standardizeTeam(team),
      yearsExpRoster     = parseNumericAny(years_exp),
      season             = as.integer(season),
      position           = position
    ) |>
    dplyr::filter(position == 'WR', !is.na(playerId), playerId != '') |>
    dplyr::arrange(playerId, season) |>
    dplyr::group_by(playerId) |>
    dplyr::summarise(
      displayNameRoster  = firstNonMissingChr(displayNameRoster),
      playerKeyRoster    = firstNonMissingChr(playerKeyRoster),
      birthDateRoster    = as.Date(firstNonMissingChr(as.character(birthDateRoster))),
      heightRoster       = firstNonMissingNum(heightRoster),
      weightRoster       = firstNonMissingNum(weightRoster),
      draftYearRoster    = firstNonMissingNum(draftYearRoster),
      rookieSeasonRoster = minNonMissingNum(rookieSeasonRoster),
      draftPickRoster    = firstNonMissingNum(draftPickRoster),
      latestTeamRoster   = lastNonMissingChr(latestTeamRoster),
      yearsExpRoster     = maxNonMissingNum(yearsExpRoster),
      .groups = 'drop'
    )

  dplyr::full_join(playersWr, rostersWr, by = 'playerId') |>
    dplyr::left_join(
      combineWr,
      by           = 'pfrId',
      relationship = 'many-to-one',
      na_matches   = 'never'
    ) |>
    dplyr::transmute(
      playerId          = playerId,
      pfrId             = pfrId,
      displayName       = dplyr::coalesce(displayName, displayNameRoster),
      playerKey         = dplyr::coalesce(playerKey, playerKeyRoster),
      birthDate         = dplyr::coalesce(birthDate, birthDateRoster),
      height            = dplyr::coalesce(height, heightRoster),
      weight            = dplyr::coalesce(weight, weightRoster),
      draftYear         = dplyr::coalesce(draftYear, draftYearRoster),
      rookieSeason      = dplyr::coalesce(rookieSeason, rookieSeasonRoster),
      draftRound        = draftRound,
      draftPick         = dplyr::coalesce(draftPick, draftPickRoster),
      latestTeam        = dplyr::coalesce(latestTeam, latestTeamRoster),
      yearsOfExperience = dplyr::coalesce(yearsOfExperience, yearsExpRoster),
      collegeName       = collegeName,
      combineForty      = combineForty,
      combineBench      = combineBench,
      combineVertical   = combineVertical,
      combineBroadJump  = combineBroadJump,
      combineCone       = combineCone,
      combineShuttle    = combineShuttle,
      combineAvailable  = !is.na(combineForty) |
        !is.na(combineBench) |
        !is.na(combineVertical) |
        !is.na(combineBroadJump) |
        !is.na(combineCone) |
        !is.na(combineShuttle)
    ) |>
    dplyr::filter(!is.na(playerKey), playerKey != '') |>
    dplyr::arrange(playerKey, playerId)
}

matchContractPlayers <- function(contracts, playerReference) {
  contracts |>
    dplyr::left_join(playerReference, by = 'playerKey', relationship = 'many-to-many') |>
    dplyr::mutate(
      signingReferenceDate = as.Date(sprintf('%d-03-15', startYear)),
      referenceAge         = ageOnDate(birthDate, signingReferenceDate),
      playerRefAgeGap      = dplyr::if_else(
        !is.na(ageAtSigning) & !is.na(referenceAge),
        abs(ageAtSigning - referenceAge),
        99
      ),
      playerRefRookieGap   = dplyr::if_else(
        !is.na(rookieSeason),
        startYear - rookieSeason,
        NA_real_
      ),
      rookiePenalty        = dplyr::case_when(
        is.na(rookieSeason)    ~ 1,
        playerRefRookieGap < 0 ~ 10,
        TRUE                   ~ 0
      )
    ) |>
    dplyr::arrange(
      contractRowId,
      rookiePenalty,
      playerRefAgeGap,
      dplyr::desc(!is.na(playerId)),
      playerRefRookieGap
    ) |>
    dplyr::group_by(contractRowId) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      birthDate         = as.Date(birthDate),
      draftYear         = as.integer(draftYear),
      rookieSeason      = as.integer(rookieSeason),
      draftRound        = as.integer(draftRound),
      draftPick         = as.integer(draftPick),
      yearsOfExperience = as.numeric(yearsOfExperience),
      playerRefMatched  = !is.na(playerId) | !is.na(birthDate) | !is.na(draftYear),
      yearsExpAtSigning = dplyr::if_else(
        !is.na(rookieSeason),
        as.numeric(startYear - rookieSeason),
        NA_real_
      ),
      undraftedFlag     = is.na(draftPick),
      isEntryLike       = dplyr::case_when(
        !is.na(rookieSeason)                                  ~ startYear == rookieSeason,
        is.na(prevContractStartYear) & !is.na(ageAtSigning)   ~ ageAtSigning <= 23,
        TRUE                                                  ~ FALSE
      )
    ) |>
    dplyr::select(-signingReferenceDate, -referenceAge, -rookiePenalty)
}

# —— External Data —— #
buildTeamSeasons <- function(seasons, schedulesRaw = NULL) {
  raw <- pullSeasonsWithBackfill(
    seasons,
    function() nflreadr::load_team_stats(seasons = seasons, summary_level = 'reg'),
    function(season) nflreadr::load_team_stats(seasons = season, summary_level = 'reg'),
    'nflreadr::load_team_stats'
  )

  if (is.null(schedulesRaw)) {
    schedulesRaw <- pullSchedulesRaw(seasons)
  }

  raw$pointsRaw <- pickCol(raw, c('points', 'fantasy_points'), NA_real_)

  teamBase <- as.data.frame(raw) |>
    dplyr::transmute(
      season                   = as.integer(season),
      team                     = standardizeTeam(team),
      sourceAvailable          = TRUE,
      games                    = parseNumericAny(games),
      attempts                 = parseNumericAny(attempts),
      passingYards             = parseNumericAny(passing_yards),
      passingTds               = parseNumericAny(passing_tds),
      passingEpa               = parseNumericAny(passing_epa),
      passingCpoe              = parseNumericAny(passing_cpoe),
      carries                  = parseNumericAny(carries),
      rushingYards             = parseNumericAny(rushing_yards),
      rushingEpa               = parseNumericAny(rushing_epa),
      points                   = parseNumericAny(pointsRaw),
      targets                  = parseNumericAny(targets),
      receivingYards           = parseNumericAny(receiving_yards),
      receivingTds             = parseNumericAny(receiving_tds),
      receivingAirYards        = parseNumericAny(receiving_air_yards)
    ) |>
    dplyr::mutate(
      passRate                = safeShare(attempts, attempts + carries),
      teamPlays               = attempts + carries,
      passingYardsPerAttempt  = safeRate(passingYards, attempts),
      passingYardsPerGame     = safeRate(passingYards, games),
      passingTdsPerGame       = safeRate(passingTds, games),
      passingEpaPerGame       = safeRate(passingEpa, games),
      pointsPerGame           = safeRate(points, games),
      receivingYardsPerTarget = safeRate(receivingYards, targets)
    )

  resultsBase <- as.data.frame(schedulesRaw) |>
    dplyr::filter(game_type == 'REG', !is.na(home_score), !is.na(away_score)) |>
    dplyr::transmute(
      season     = as.integer(season),
      homeTeam   = standardizeTeam(home_team),
      awayTeam   = standardizeTeam(away_team),
      homeScore  = parseNumericAny(home_score),
      awayScore  = parseNumericAny(away_score)
    )

  teamResults <- dplyr::bind_rows(
    resultsBase |>
      dplyr::transmute(
        season,
        team          = homeTeam,
        wins          = as.integer(homeScore > awayScore),
        losses        = as.integer(homeScore < awayScore),
        ties          = as.integer(homeScore == awayScore),
        pointsAgainst = awayScore
      ),
    resultsBase |>
      dplyr::transmute(
        season,
        team          = awayTeam,
        wins          = as.integer(awayScore > homeScore),
        losses        = as.integer(awayScore < homeScore),
        ties          = as.integer(awayScore == homeScore),
        pointsAgainst = homeScore
      )
  ) |>
    dplyr::group_by(season, team) |>
    dplyr::summarise(
      wins          = sum(wins, na.rm = TRUE),
      losses        = sum(losses, na.rm = TRUE),
      ties          = sum(ties, na.rm = TRUE),
      pointsAgainst = sum(pointsAgainst, na.rm = TRUE),
      .groups = 'drop'
    )

  leagueBase <- teamBase |>
    dplyr::group_by(season) |>
    dplyr::summarise(
      leaguePassRate            = meanOrNa(passRate),
      leaguePassingYardsPerGame = meanOrNa(passingYardsPerGame),
      leaguePassingEpaPerGame   = meanOrNa(passingEpaPerGame),
      leaguePointsPerGame       = meanOrNa(pointsPerGame),
      .groups = 'drop'
    )

  teamBase |>
    dplyr::left_join(
      teamResults,
      by           = c('season', 'team'),
      relationship = 'many-to-one',
      na_matches   = 'never'
    ) |>
    dplyr::left_join(leagueBase, by = 'season') |>
    dplyr::mutate(
      wins                         = dplyr::coalesce(wins, 0L),
      losses                       = dplyr::coalesce(losses, 0L),
      ties                         = dplyr::coalesce(ties, 0L),
      winPct                       = dplyr::if_else(
        (wins + losses + ties) > 0,
        (wins + (0.5 * ties)) / (wins + losses + ties),
        NA_real_
      ),
      pointsAgainst                = parseNumericAny(pointsAgainst),
      pointDiff                    = points - pointsAgainst,
      marginPerGame                = safeRate(pointDiff, games),
      passRateDiffLeague            = passRate - leaguePassRate,
      passingYardsPerGameDiffLeague = passingYardsPerGame - leaguePassingYardsPerGame,
      passingEpaPerGameDiffLeague   = passingEpaPerGame - leaguePassingEpaPerGame,
      pointsPerGameDiffLeague       = pointsPerGame - leaguePointsPerGame
    ) |>
    dplyr::select(season, team, dplyr::all_of(teamMetricCols))
}

buildRegularPlayerSeasons <- function(seasons, teamSeasons) {
  raw <- pullSeasonsWithBackfill(
    seasons,
    function() nflreadr::load_player_stats(seasons = seasons, summary_level = 'reg'),
    function(season) nflreadr::load_player_stats(seasons = season, summary_level = 'reg'),
    'nflreadr::load_player_stats'
  )

  regularBase <- as.data.frame(raw) |>
    dplyr::transmute(
      playerId                 = as.character(player_id),
      playerKey                = normalizePlayerName(player_display_name),
      season                   = as.integer(season),
      seasonTeam               = standardizeTeam(recent_team),
      sourceAvailable          = TRUE,
      games                    = parseNumericAny(games),
      targets                  = parseNumericAny(targets),
      receptions               = parseNumericAny(receptions),
      receivingYards           = parseNumericAny(receiving_yards),
      receivingTds             = parseNumericAny(receiving_tds),
      receivingFirstDowns      = parseNumericAny(receiving_first_downs),
      receivingEpa             = parseNumericAny(receiving_epa),
      receivingAirYards        = parseNumericAny(receiving_air_yards),
      receivingYardsAfterCatch = parseNumericAny(receiving_yards_after_catch),
      carries                  = parseNumericAny(carries),
      rushingYards             = parseNumericAny(rushing_yards),
      rushingTds               = parseNumericAny(rushing_tds),
      targetShare              = parseNumericAny(target_share),
      airYardsShare            = parseNumericAny(air_yards_share),
      wopr                     = parseNumericAny(wopr)
    ) |>
    dplyr::mutate(
      targetsPerGame           = safeRate(targets, games),
      receptionsPerGame        = safeRate(receptions, games),
      receivingYardsPerGame    = safeRate(receivingYards, games),
      receivingTdsPerGame      = safeRate(receivingTds, games),
      receivingFirstDownsPerGame = safeRate(receivingFirstDowns, games),
      receivingEpaPerGame      = safeRate(receivingEpa, games),
      catchRate                = safeRate(receptions, targets),
      yardsPerTarget           = safeRate(receivingYards, targets),
      yardsPerReception        = safeRate(receivingYards, receptions),
      tdPerTarget              = safeRate(receivingTds, targets),
      airYardsPerTarget        = safeRate(receivingAirYards, targets),
      yacPerReception          = safeRate(receivingYardsAfterCatch, receptions),
      rushYardsPerCarry        = safeRate(rushingYards, carries)
    ) |>
    dplyr::left_join(
      teamSeasons |>
        dplyr::select(
          season,
          team,
          teamTargets          = targets,
          teamReceivingYards   = receivingYards,
          teamReceivingTds     = receivingTds,
          teamReceivingAirYards = receivingAirYards
        ),
      by = c('season', 'seasonTeam' = 'team')
    ) |>
    dplyr::mutate(
      teamTargetShareCalc    = safeShare(targets, teamTargets),
      teamYardsShareCalc     = safeShare(receivingYards, teamReceivingYards),
      teamTdShareCalc        = safeShare(receivingTds, teamReceivingTds),
      teamAirYardsShareCalc  = safeShare(receivingAirYards, teamReceivingAirYards)
    ) |>
    dplyr::select(season, playerId, playerKey, seasonTeam, dplyr::all_of(regularMetricCols))

  regularBase
}

buildSnapPlayerSeasons <- function(seasons) {
  seasons <- seasons[seasons >= 2012L]

  if (length(seasons) == 0L) {
    return(dplyr::tibble(
      season     = integer(),
      pfrId      = character(),
      playerKey  = character(),
      seasonTeam = character()
    ))
  }

  raw <- pullSeasonsWithBackfill(
    seasons,
    function() nflreadr::load_snap_counts(seasons = seasons),
    function(season) nflreadr::load_snap_counts(seasons = season),
    'nflreadr::load_snap_counts'
  )

  snapTeamChoice <- as.data.frame(raw) |>
    dplyr::filter(game_type == 'REG', position == 'WR') |>
    dplyr::transmute(
      season       = as.integer(season),
      pfrId        = as.character(pfr_player_id),
      playerKey    = normalizePlayerName(player),
      team         = standardizeTeam(team),
      offenseSnaps = parseNumericAny(offense_snaps),
      snapGames    = 1L
    ) |>
    dplyr::group_by(season, pfrId, playerKey, team) |>
    dplyr::summarise(
      offenseSnaps = sum(offenseSnaps, na.rm = TRUE),
      snapGames    = dplyr::n(),
      .groups = 'drop'
    ) |>
    dplyr::arrange(season, pfrId, playerKey, dplyr::desc(offenseSnaps), dplyr::desc(snapGames), team) |>
    dplyr::group_by(season, pfrId, playerKey) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup() |>
    dplyr::transmute(
      season,
      pfrId,
      playerKey,
      seasonTeam = team
    )

  as.data.frame(raw) |>
    dplyr::filter(game_type == 'REG', position == 'WR') |>
    dplyr::transmute(
      season        = as.integer(season),
      pfrId         = as.character(pfr_player_id),
      playerKey     = normalizePlayerName(player),
      offenseSnaps  = parseNumericAny(offense_snaps),
      offensePct    = parseNumericAny(offense_pct),
      stSnaps       = parseNumericAny(st_snaps),
      stPct         = parseNumericAny(st_pct)
    ) |>
    dplyr::group_by(season, pfrId, playerKey) |>
    dplyr::summarise(
      sourceAvailable  = TRUE,
      snapGames        = dplyr::n(),
      offenseSnaps     = sum(offenseSnaps, na.rm = TRUE),
      offenseSnapsPerGame = safeRate(sum(offenseSnaps, na.rm = TRUE), dplyr::n()),
      offensePctMean   = meanOrNa(offensePct),
      offensePctMax    = maxNonMissingNum(offensePct),
      stSnaps          = sum(stSnaps, na.rm = TRUE),
      stSnapsPerGame   = safeRate(sum(stSnaps, na.rm = TRUE), dplyr::n()),
      stPctMean        = meanOrNa(stPct),
      offenseSnapShare = safeShare(sum(offenseSnaps, na.rm = TRUE), sum(offenseSnaps, na.rm = TRUE) + sum(stSnaps, na.rm = TRUE)),
      .groups = 'drop'
    ) |>
    dplyr::left_join(snapTeamChoice, by = c('season', 'pfrId', 'playerKey')) |>
    dplyr::select(season, pfrId, playerKey, seasonTeam, dplyr::all_of(snapMetricCols))
}

buildNgsPlayerSeasons <- function(seasons) {
  seasons <- seasons[seasons >= 2016L]

  if (length(seasons) == 0L) {
    return(dplyr::tibble(
      season     = integer(),
      playerId   = character(),
      playerKey  = character(),
      seasonTeam = character()
    ))
  }

  raw <- pullSeasonsWithBackfill(
    seasons,
    function() nflreadr::load_nextgen_stats(stat_type = 'receiving', seasons = seasons),
    function(season) nflreadr::load_nextgen_stats(stat_type = 'receiving', seasons = season),
    'nflreadr::load_nextgen_stats'
  )

  raw$teamRaw                         <- pickCol(raw, c('team_abbr', 'team'), NA_character_)
  raw$targetsRaw                      <- pickCol(raw, c('targets'), NA_real_)
  raw$receptionsRaw                   <- pickCol(raw, c('receptions'), NA_real_)
  raw$yardsRaw                        <- pickCol(raw, c('yards'), NA_real_)
  raw$recTouchdownsRaw                <- pickCol(raw, c('rec_touchdowns'), NA_real_)
  raw$catchPercentageRaw              <- pickCol(raw, c('catch_percentage'), NA_real_)
  raw$avgCushionRaw                   <- pickCol(raw, c('avg_cushion'), NA_real_)
  raw$avgSeparationRaw                <- pickCol(raw, c('avg_separation'), NA_real_)
  raw$avgIntendedAirYardsRaw          <- pickCol(raw, c('avg_intended_air_yards'), NA_real_)
  raw$percentShareOfIntendedAirYardsRaw <- pickCol(raw, c('percent_share_of_intended_air_yards'), NA_real_)
  raw$avgAirDistanceRaw               <- pickCol(raw, c('avg_air_distance'), NA_real_)
  raw$maxAirDistanceRaw               <- pickCol(raw, c('max_air_distance'), NA_real_)
  raw$avgYacRaw                       <- pickCol(raw, c('avg_yac'), NA_real_)
  raw$avgExpectedYacRaw               <- pickCol(raw, c('avg_expected_yac'), NA_real_)
  raw$avgYacAboveExpectationRaw       <- pickCol(raw, c('avg_yac_above_expectation'), NA_real_)
  raw$efficiencyRaw                   <- pickCol(raw, c('efficiency'), NA_real_)

  as.data.frame(raw) |>
    dplyr::filter(week == 0L, season_type == 'REG', player_position == 'WR') |>
    dplyr::transmute(
      season                          = as.integer(season),
      playerId                        = as.character(player_gsis_id),
      playerKey                       = normalizePlayerName(player_display_name),
      seasonTeam                      = standardizeTeam(teamRaw),
      sourceAvailable                 = TRUE,
      targets                         = parseNumericAny(targetsRaw),
      receptions                      = parseNumericAny(receptionsRaw),
      yards                           = parseNumericAny(yardsRaw),
      recTouchdowns                   = parseNumericAny(recTouchdownsRaw),
      catchPercentage                 = parseNumericAny(catchPercentageRaw),
      avgCushion                      = parseNumericAny(avgCushionRaw),
      avgSeparation                   = parseNumericAny(avgSeparationRaw),
      avgIntendedAirYards             = parseNumericAny(avgIntendedAirYardsRaw),
      percentShareOfIntendedAirYards  = parseNumericAny(percentShareOfIntendedAirYardsRaw),
      avgAirDistance                  = parseNumericAny(avgAirDistanceRaw),
      maxAirDistance                  = parseNumericAny(maxAirDistanceRaw),
      avgYac                          = parseNumericAny(avgYacRaw),
      avgExpectedYac                  = parseNumericAny(avgExpectedYacRaw),
      avgYacAboveExpectation          = parseNumericAny(avgYacAboveExpectationRaw),
      efficiency                      = parseNumericAny(efficiencyRaw)
    ) |>
    dplyr::mutate(
      yardsPerTarget    = safeRate(yards, targets),
      yardsPerReception = safeRate(yards, receptions),
      tdPerTarget       = safeRate(recTouchdowns, targets)
    ) |>
    dplyr::select(season, playerId, playerKey, seasonTeam, dplyr::all_of(ngsMetricCols))
}

buildMarketSeasons <- function(contracts) {
  contracts |>
    dplyr::filter(!is.na(startYear), !is.na(term), !isEntryLike) |>
    dplyr::group_by(season = startYear) |>
    dplyr::summarise(
      sourceAvailable  = TRUE,
      contractCount    = dplyr::n(),
      medianTerm       = stats::median(term, na.rm = TRUE),
      medianAav        = stats::median(aav, na.rm = TRUE),
      medianAavPerc    = stats::median(aavPerc, na.rm = TRUE),
      p75AavPerc       = stats::quantile(aavPerc, probs = 0.75, na.rm = TRUE, names = FALSE),
      medianAgeAtSigning = stats::median(ageAtSigning, na.rm = TRUE),
      .groups = 'drop'
    )
}

# —— Splits —— #
buildTestRows <- function(contracts) {
  syntheticBaseId      <- max(contracts$contractRowId, na.rm = TRUE)
  actualValidatePlayers <- contracts |>
    dplyr::filter(startYear == validateYear) |>
    dplyr::distinct(playerKey)

  latestContracts <- contracts |>
    dplyr::arrange(playerKey, startYear, endYear, contractRowId) |>
    dplyr::group_by(playerKey) |>
    dplyr::slice_tail(n = 1) |>
    dplyr::ungroup()

  latestContracts |>
    dplyr::filter(endYear == validateYear - 1L) |>
    dplyr::anti_join(actualValidatePlayers, by = 'playerKey') |>
    dplyr::mutate(
      contractRowId          = syntheticBaseId + dplyr::row_number(),
      latestContractStartYear = startYear,
      latestContractEndYear   = endYear,
      latestContractTerm      = term,
      latestContractAav       = aav,
      latestContractAavPerc   = aavPerc,
      latestSignedTeam        = signedTeam,
      playerAgeFallback = ageAtSigning + (validateYear - latestContractStartYear),
      ageAtSigning      = dplyr::coalesce(
        ageOnDate(birthDate, testReferenceDate),
        playerAgeFallback
      ),
      yearsExpAtSigning = dplyr::case_when(
        !is.na(rookieSeason)     ~ as.numeric(validateYear - rookieSeason),
        !is.na(yearsExpAtSigning) ~ yearsExpAtSigning + (validateYear - latestContractStartYear),
        TRUE                     ~ NA_real_
      ),
      startYear         = validateYear,
      endYear           = NA_integer_,
      endYearRaw        = NA_integer_,
      expectedEndYear   = NA_integer_,
      term              = NA_real_,
      totalValue        = NA_real_,
      aav               = NA_real_,
      aavPerc           = NA_real_,
      signingBonus      = NA_real_,
      guaranteeAtSign   = NA_real_,
      practicalGuarantee = NA_real_,
      sourceFile        = 'synthetic_test_row',
      signedTeamRaw     = NA_character_,
      signedTeam        = NA_character_,
      prevContractStartYear = latestContractStartYear,
      prevContractEndYear   = latestContractEndYear,
      prevContractTerm      = latestContractTerm,
      prevContractAav       = latestContractAav,
      prevContractAavPerc   = latestContractAavPerc,
      prevSignedTeam        = latestSignedTeam,
      gapSincePrevContractEnd = dplyr::if_else(
        !is.na(latestContractEndYear),
        as.numeric(validateYear - latestContractEndYear),
        NA_real_
      ),
      observedContractNumber = observedContractNumber + 1L,
      dateOfSigningObserved  = as.Date(NA),
      featureReferenceDate   = testReferenceDate,
      signingDateObserved    = FALSE,
      signingDateSource      = 'test_reference_date',
      isEntryLike            = dplyr::case_when(
        !is.na(rookieSeason) ~ validateYear == rookieSeason,
        TRUE                 ~ FALSE
      )
    ) |>
    dplyr::select(
      -playerAgeFallback,
      -latestContractStartYear,
      -latestContractEndYear,
      -latestContractTerm,
      -latestContractAav,
      -latestContractAavPerc,
      -latestSignedTeam
    )
}

# —— Run —— #
contractsRaw     <- readContracts(contractsDir, contractsPattern)
playerReference  <- buildPlayerReference()
schedulesRaw     <- pullSchedulesRaw(playerSeasonRange)
seasonCalendar   <- buildSeasonCalendar(schedulesRaw)
transactionsRaw  <- buildEspnTransactions(transactionYears)
signingClauses   <- buildSigningClauses(transactionsRaw)
contractsMatched <- matchContractPlayers(contractsRaw, playerReference)
signingMatches   <- matchSigningDates(contractsMatched, signingClauses)
contracts        <- contractsMatched |>
  dplyr::left_join(
    signingMatches,
    by           = 'contractRowId',
    relationship = 'one-to-one',
    suffix       = c('', '.matched')
  ) |>
  dplyr::mutate(
    dateOfSigningObserved = dplyr::coalesce(
      dateOfSigningObserved.matched,
      dateOfSigningObserved
    ),
    featureReferenceDate = dplyr::coalesce(
      dateOfSigningObserved,
      offseasonReferenceDate(startYear)
    ),
    signingDateObserved = !is.na(dateOfSigningObserved),
    signingDateSource   = dplyr::if_else(
      signingDateObserved,
      'espn_transactions',
      'offseason_proxy'
    )
  ) |>
  dplyr::select(-dateOfSigningObserved.matched)
teamSeasons      <- buildTeamSeasons(playerSeasonRange, schedulesRaw)
regularSeasons   <- buildRegularPlayerSeasons(playerSeasonRange, teamSeasons)
snapSeasons      <- buildSnapPlayerSeasons(playerSeasonRange)
ngsSeasons       <- buildNgsPlayerSeasons(playerSeasonRange)
marketSeasons    <- buildMarketSeasons(contracts)

signingCoverage <- contracts |>
  dplyr::filter(startYear >= trainStartYear, startYear <= validateYear) |>
  dplyr::group_by(startYear) |>
  dplyr::summarise(
    contracts      = dplyr::n(),
    observedDates  = sum(signingDateObserved, na.rm = TRUE),
    observedRate   = observedDates / contracts,
    .groups = 'drop'
  )

message(sprintf(
  'Observed ESPN signing dates matched for %d of %d actual contracts.',
  sum(signingCoverage$observedDates, na.rm = TRUE),
  sum(signingCoverage$contracts, na.rm = TRUE)
))

actualRows <- contracts |>
  dplyr::filter(startYear >= trainStartYear, startYear <= validateYear) |>
  dplyr::mutate(dataset = dplyr::if_else(startYear == validateYear, 'validate', 'train'))

testRows <- buildTestRows(contracts) |>
  dplyr::mutate(dataset = 'test')

modelRows <- dplyr::bind_rows(actualRows, testRows) |>
  assignPriorCompletedSeasons('featureReferenceDate', seasonCalendar)

modelRows <- addHybridPlayerBlock(modelRows, regularSeasons, 'reg',  'playerId')
modelRows <- addHybridPlayerBlock(modelRows, snapSeasons,    'snap', 'pfrId')
modelRows <- addHybridPlayerBlock(modelRows, ngsSeasons,     'ngs',  'playerId')

modelRows <- modelRows |>
  dplyr::mutate(
    prev1Team      = dplyr::coalesce(regPrev1SeasonTeam, snapPrev1SeasonTeam, ngsPrev1SeasonTeam),
    prev2Team      = dplyr::coalesce(regPrev2SeasonTeam, snapPrev2SeasonTeam, ngsPrev2SeasonTeam),
    priorTeamSame  = dplyr::if_else(!is.na(prev1Team) & !is.na(prev2Team), prev1Team == prev2Team, NA)
  )

teamPrev1 <- teamSeasons
names(teamPrev1)[match('team', names(teamPrev1))] <- 'prev1Team'
teamPrev1 <- buildLagTable(teamPrev1, 'prev1Team', 'prev1Season', teamMetricCols, 'team', 'Prev1', fallback = FALSE)

teamPrev2 <- teamSeasons
names(teamPrev2)[match('team', names(teamPrev2))] <- 'prev2Team'
teamPrev2 <- buildLagTable(teamPrev2, 'prev2Team', 'prev2Season', teamMetricCols, 'team', 'Prev2', fallback = FALSE)

modelRows <- modelRows |>
  dplyr::left_join(teamPrev1, by = c('prev1Team', 'prev1Season')) |>
  dplyr::left_join(teamPrev2, by = c('prev2Team', 'prev2Season'))

modelRows[['teamPrev1Available']] <- dplyr::coalesce(modelRows[['teamPrev1SourceAvailable']], FALSE)
modelRows[['teamPrev2Available']] <- dplyr::coalesce(modelRows[['teamPrev2SourceAvailable']], FALSE)
modelRows[['teamYearsAvailable']] <- as.integer(modelRows[['teamPrev1Available']]) +
  as.integer(modelRows[['teamPrev2Available']])

modelRows <- addWeightedDeltaFeatures(
  modelRows,
  'team',
  setdiff(teamMetricCols, 'sourceAvailable')
)

modelRows <- addSeasonBlock(modelRows, marketSeasons, 'market')

modelRows <- modelRows |>
  dplyr::select(-dplyr::matches('SeasonTeam$')) |>
  dplyr::select(-dplyr::matches('SourceAvailable$'))

baseCols <- c(
  'contractRowId',
  'sourceFile',
  'playerName',
  'playerKey',
  'playerId',
  'pfrId',
  'dateOfSigningObserved',
  'featureReferenceDate',
  'signingDateObserved',
  'signingDateSource',
  'startYear',
  'term',
  'aav',
  'aavPerc',
  'signedTeam',
  'ageAtSigning',
  'birthDate',
  'height',
  'weight',
  'combineForty',
  'combineBench',
  'combineVertical',
  'combineBroadJump',
  'combineCone',
  'combineShuttle',
  'combineAvailable',
  'draftYear',
  'draftRound',
  'draftPick',
  'rookieSeason',
  'yearsExpAtSigning',
  'undraftedFlag',
  'playerRefMatched',
  'playerRefAgeGap',
  'playerRefRookieGap',
  'observedContractNumber',
  'prevContractStartYear',
  'prevContractEndYear',
  'prevContractTerm',
  'prevContractAav',
  'prevContractAavPerc',
  'prevSignedTeam',
  'gapSincePrevContractEnd',
  'prev1Season',
  'prev2Season',
  'prev1Team',
  'prev2Team',
  'priorTeamSame',
  'isEntryLike'
)

dropCols <- c(
  'endYear',
  'termRaw',
  'yearsOfExperience',
  'pos',
  'signedTeamRaw',
  'endYearRaw',
  'totalValue',
  'signingBonus',
  'guaranteeAtSign',
  'practicalGuarantee',
  'expectedEndYear',
  'displayName',
  'latestTeam',
  'collegeName'
)

featureCols <- setdiff(names(modelRows), c('dataset', baseCols, dropCols))

modelRows <- modelRows |>
  dplyr::select(dataset, dplyr::all_of(baseCols), dplyr::all_of(featureCols))

trainData <- modelRows |>
  dplyr::filter(
    dataset == 'train',
    !isEntryLike,
    !is.na(term),
    !is.na(aavPerc)
  ) |>
  dplyr::select(-dataset)

validateData <- modelRows |>
  dplyr::filter(
    dataset == 'validate',
    !isEntryLike,
    !is.na(term),
    !is.na(aavPerc)
  ) |>
  dplyr::select(-dataset)

testData <- modelRows |>
  dplyr::filter(
    dataset == 'test',
    !isEntryLike
  ) |>
  dplyr::select(-dataset)

readr::write_csv(trainData, trainPath)
readr::write_csv(validateData, validatePath)
readr::write_csv(testData, testPath)

message(sprintf('Wrote %d rows to %s.', nrow(trainData), normalizePath(trainPath)))
message(sprintf('Wrote %d rows to %s.', nrow(validateData), normalizePath(validatePath)))
message(sprintf('Wrote %d rows to %s.', nrow(testData), normalizePath(testPath)))
message(sprintf('Output columns: %d.', ncol(trainData)))
