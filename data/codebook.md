# WR Contract Modeling Codebook

## Scope

This project prepares three modeling files for non-entry WR contracts:

- `data/train.csv`: 2002-2025 signed contracts used for fitting.
- `data/validate.csv`: 2026 signed contracts used for held-out evaluation.
- `data/test.csv`: 2026 unsigned candidates whose next contracts will be scored.

All three files are produced by `R/clean.R`.

## Responses

- `term`: Actual contract length in years.
- `aavPerc`: Actual average annual value as a share of the league cap at signing.

`aav` is retained for bookkeeping and later dollar translation, but it is not a modeling target here. For an `aavPerc` model, current-contract `aav` should be excluded from predictors in the training script.

## Row Definitions

- `train.csv` contains contracts with `startYear >= 2002`, `startYear <= 2025`, `!isEntryLike`, non-missing `term`, and non-missing `aavPerc`.
- `validate.csv` contains the same contract type for `startYear == 2026`.
- `test.csv` contains non-entry WRs whose latest observed contract ended after 2025, who do not already have a 2026 contract in the raw files, and whose 2026 outcome columns are intentionally blank.

Current row counts from the latest build:

- `train.csv`: 3,159 rows across 1,421 players.
- `validate.csv`: 122 rows across 122 players.
- `test.csv`: 166 rows across 166 players.
- Each file currently has 452 columns.

## Source Data

### Local contract files

- `data/WR_Contracts_200s.csv`
- `data/WR_Contracts_2010s.csv`
- `data/WR_Contracts_2020s.csv`

These provide the contract spine: player, team, signing age, term, value, AAV, cap share, and bonus/guarantee fields. Bonus and guarantee fields are used only during parsing and are dropped from the modeling exports.

### External `nflreadr` sources

- `load_players()`: Player IDs, birth dates, height, weight, draft data, rookie season, college.
- `load_rosters()`: Historical roster backfill used to improve player matching.
- `load_combine()`: Static athletic testing matched by `pfrId`.
- `load_player_stats()`: Prior-season regular player stats.
- `load_snap_counts()`: Prior-season usage and snap share.
- `load_nextgen_stats(stat_type = 'receiving')`: Prior-season receiving NGS metrics.
- `load_team_stats(summary_level = 'reg')`: Prior-season team offensive environment.
- `load_schedules()`: Prior-season team results context.

`load_pfr_advstats()` was tested and rejected for this workflow because the available output is quarterback-oriented and did not produce usable WR coverage.

## Contract Cleaning

- Contract files are row-bound and standardized to WR only.
- Player names are normalized into `playerKey`.
- `aavPerc` is parsed as a decimal share, not a percentage string.
- Implausible `endYearRaw` values are replaced with `startYear + round(term) - 1`.
- Previous-contract fields are created within each player by chronological ordering.
- `prev1Season` and `prev2Season` are always `startYear - 1` and `startYear - 2`.

## Player Matching

Contracts are matched to a player reference built from `load_players()` plus historical rosters.

Matching process:

- Join on normalized `playerKey`.
- Prefer the candidate with the smallest signing-age gap.
- Penalize impossible rookie-season matches.
- Use team agreement only as a weak tie-breaker.

The following fields capture match quality and are retained:

- `playerRefMatched`
- `playerRefAgeGap`
- `playerRefRookieGap`

## Entry-Like Filtering

The project is restricted to non-entry deals.

`isEntryLike` is set when either condition holds:

- `startYear == rookieSeason`
- No prior contract is observed and `ageAtSigning <= 23`

Only rows with `!isEntryLike` are exported to `train`, `validate`, and `test`.

## Predictor Families

### Metadata and contract history

- Contract identifiers: `contractRowId`, `sourceFile`, `playerName`, `playerKey`, `playerId`, `pfrId`
- Timing and labels: `startYear`, `signedTeam`
- Biographical inputs: `ageAtSigning`, `birthDate`, `height`, `weight`
- Combine inputs: `combineForty`, `combineBench`, `combineVertical`, `combineBroadJump`, `combineCone`, `combineShuttle`, `combineAvailable`
- Draft inputs: `draftYear`, `draftRound`, `draftPick`, `rookieSeason`, `undraftedFlag`
- Match-quality inputs: `playerRefMatched`, `playerRefAgeGap`, `playerRefRookieGap`
- Contract-history inputs: `observedContractNumber`, `prevContractStartYear`, `prevContractEndYear`, `prevContractTerm`, `prevContractAav`, `prevContractAavPerc`, `prevSignedTeam`, `gapSincePrevContractEnd`
- Season-reference inputs: `prev1Season`, `prev2Season`, `prev1Team`, `prev2Team`, `priorTeamSame`

### Regular player stats: prefix `reg`

Base metrics:

- `games`, `targets`, `receptions`, `receivingYards`, `receivingTds`, `receivingFirstDowns`
- `receivingEpa`, `receivingAirYards`, `receivingYardsAfterCatch`
- `carries`, `rushingYards`, `rushingTds`
- `targetShare`, `airYardsShare`, `wopr`
- `targetsPerGame`, `receptionsPerGame`, `receivingYardsPerGame`, `receivingTdsPerGame`
- `receivingFirstDownsPerGame`, `receivingEpaPerGame`
- `catchRate`, `yardsPerTarget`, `yardsPerReception`, `tdPerTarget`
- `airYardsPerTarget`, `yacPerReception`, `rushYardsPerCarry`
- `teamTargetShareCalc`, `teamYardsShareCalc`, `teamTdShareCalc`, `teamAirYardsShareCalc`

### Snap usage: prefix `snap`

Base metrics:

- `snapGames`, `offenseSnaps`, `offenseSnapsPerGame`
- `offensePctMean`, `offensePctMax`
- `stSnaps`, `stSnapsPerGame`, `stPctMean`
- `offenseSnapShare`

### Next Gen receiving: prefix `ngs`

Base metrics:

- `targets`, `receptions`, `yards`, `recTouchdowns`
- `catchPercentage`, `avgCushion`, `avgSeparation`
- `avgIntendedAirYards`, `percentShareOfIntendedAirYards`
- `avgAirDistance`, `maxAirDistance`
- `avgYac`, `avgExpectedYac`, `avgYacAboveExpectation`
- `efficiency`, `yardsPerTarget`, `yardsPerReception`, `tdPerTarget`

### Team context: prefix `team`

Base metrics:

- `games`, `wins`, `losses`, `ties`, `winPct`
- `attempts`, `passingYards`, `passingTds`, `passingEpa`, `passingCpoe`
- `carries`, `rushingYards`, `rushingEpa`
- `points`, `pointsAgainst`, `pointDiff`, `marginPerGame`
- `targets`, `receivingYards`, `receivingTds`, `receivingAirYards`
- `passRate`, `teamPlays`, `passingYardsPerAttempt`, `passingYardsPerGame`
- `passingTdsPerGame`, `passingEpaPerGame`, `pointsPerGame`, `receivingYardsPerTarget`
- `passRateDiffLeague`, `passingYardsPerGameDiffLeague`, `passingEpaPerGameDiffLeague`, `pointsPerGameDiffLeague`

### WR market context: prefix `market`

These are built from prior signed non-entry WR contracts in the local contract data:

- `contractCount`
- `medianTerm`
- `medianAav`
- `medianAavPerc`
- `p75AavPerc`
- `medianAgeAtSigning`

## Naming Convention

For each metric family above, `R/clean.R` creates:

- `Prev1`: Value from the season immediately before signing.
- `Prev2`: Value from two seasons before signing.
- `Weighted`: A `1:2` weighted average of `Prev2` and `Prev1`.
- `Delta`: `Prev1 - Prev2` when both seasons exist.
- `Prev1Available`, `Prev2Available`, `YearsAvailable`: Coverage indicators for the family.

Example:

- `regPrev1ReceivingYards`
- `regPrev2ReceivingYards`
- `regWeightedReceivingYards`
- `regDeltaReceivingYards`

## Missing-Data Policy

- Raw prior-season metrics remain `NA` when the source season is unavailable.
- Weighted features use the observed season directly when only one of `Prev1` or `Prev2` exists.
- Delta features are set to `0` when one or both seasons are missing.
- Availability flags remain in the files so the model can distinguish true zeros from missing seasonal history.

This keeps zeros reserved for true measured values, except for the intentionally neutral missing-delta convention.

## Coverage Snapshot In `train.csv`

- Combine coverage: `49.1%`
- Any regular-stat history: `62.8%`
- Two-year regular-stat history: `43.7%`
- Any snap history: `49.9%`
- Two-year snap history: `32.1%`
- Any NGS history: `14.6%`
- Two-year NGS history: `6.4%`
- Any team context: `66.3%`
- Two-year team context: `46.7%`
- Market context: `100%` for both prior seasons

## Modeling Notes

- `contractRowId`, `sourceFile`, `playerName`, `playerKey`, `playerId`, and `pfrId` are identifiers or bookkeeping fields and should be treated as metadata in modeling recipes.
- `signedTeam` is retained for auditability but is not known for unsigned `test.csv` rows, so it should not be used as an ex ante predictor unless team-specific scenarios are created intentionally.
- `aav` is retained for reporting and post-model translation, but it should not be used to predict `aavPerc`.
- The current files are prepared for a modeling workflow similar to the reference project: split first, then assign ID roles in the recipe, then dummy/novel handling on the remaining predictors.

