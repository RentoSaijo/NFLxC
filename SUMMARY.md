# NFL WR Contract Projection Project Summary

## Objective

The project goal was to build an end-to-end NFL wide receiver contract forecasting workflow that can:

- estimate expected contract term,
- estimate expected `aavPerc` conditional on a supplied term scenario,
- score unsigned 2026 free-agent WRs, and
- surface the results in a local interactive application.

The final design intentionally separates the problem into two linked models instead of one joint model:

1. `term`: multiclass contract-length prediction.
2. `aavPerc`: conditional compensation prediction given a term scenario.

This structure is closer to how contract discussions actually work. Length and compensation are linked, but they are not the same decision. It also makes the final forecasting product scenario-based rather than falsely precise.

## Project Scope

The modeling universe is non-entry NFL WR contracts only. Rookie-scale or rookie-adjacent deals were intentionally removed because:

- they are governed by a different market mechanism,
- their pricing logic is structurally different from veteran deals, and
- including them would let the models learn a mixture of two different data-generating processes.

The final row counts are:

- `data/train.csv`: `2,795` contracts.
- `data/validate.csv`: `91` signed 2026 contracts.
- `data/test.csv`: `163` unsigned 2026 WR free-agent candidates.

The final training rows for each final model are `2,886`, because the selected final models were refit on `train + validate` after hyperparameter selection was finished.

## Data Sources

### 1. Local WR contract files

The local contract spine comes from:

- `data/WR_Contracts_200s.csv`
- `data/WR_Contracts_2010s.csv`
- `data/WR_Contracts_2020s.csv`

These files provide the target economics and contract history:

- player and team labels,
- contract start and end years,
- reported term,
- `aav`,
- `aavPerc`,
- age at signing,
- bonus and guarantee fields.

Bonus and guarantee fields were parsed during cleaning but were not used as core modeling targets because the project scope was narrowed to term and `aavPerc`.

### 2. `nflreadr` / nflverse sources

`R/clean.R` enriches the contract spine with player, team, and market context from publicly accessible nflverse data through `nflreadr`:

- `load_players()`
- `load_rosters()`
- `load_combine()`
- `load_player_stats()`
- `load_snap_counts()`
- `load_nextgen_stats(stat_type = 'receiving')`
- `load_team_stats(summary_level = 'reg')`
- `load_schedules()`

These sources were chosen because they are modern, maintained, R-friendly, and broad enough to support both basic and advanced season-level predictors.

### 3. ESPN NFL transactions

The contract files do not provide exact signing dates. That created a real leakage concern: if a contract starts in 2026 but was actually signed during the 2025 season, then using full 2025 player stats would leak post-signing information.

To reduce that risk, `R/clean.R` now pulls dated NFL transactions from ESPN’s public API and matches likely signing events back to contract rows. That match is imperfect, but it is materially better than assuming every contract was signed after the prior season ended.

This was one of the most important methodological changes in the project.

## Cleaning And Temporal Logic

### Contract standardization

The cleaner:

- row-binds the WR contract files,
- normalizes player names into a stable key,
- parses numeric fields robustly,
- standardizes `aavPerc` as a decimal share rather than a percentage string,
- repairs implausible end years by using `startYear + term - 1` when needed, and
- sorts contracts chronologically within player.

### Removing embedded rows

The raw contract files can contain yearly rows that are already subsumed by a prior multi-year deal. Those rows are not independent contract events, so keeping them would pollute both previous-contract logic and the modeling sample.

The cleaner removes those embedded rows before building contract-history predictors.

### Player matching

The contract spine and nflverse player reference do not share a perfect universal identifier. Matching is done by normalized name, then refined using:

- age proximity,
- rookie-season plausibility,
- roster backfill,
- position context.

The cleaner retains match-quality fields such as:

- `playerRefMatched`
- `playerRefAgeGap`
- `playerRefRookieGap`

Those were kept intentionally. Matching is never perfect, and it is better to expose match quality than to hide it.

### Entry-like filtering

`isEntryLike` is triggered when:

- `startYear == rookieSeason`, or
- no prior contract is observed and `ageAtSigning <= 23`.

Those rows are excluded from train, validate, and test. This avoids blending rookie/initial pricing with the veteran market.

### Signing-date enrichment

Where a confident ESPN transaction match exists, the cleaner records:

- `dateOfSigningObserved`
- `signingDateObserved`
- `signingDateSource`

When no dated match exists, the cleaner falls back to a conservative offseason proxy date of March 15 of the contract `startYear`. This is still an assumption, but it is explicit and auditable.

### Season window definition

The project originally used `startYear - 1` and `startYear - 2` mechanically. That was too crude.

The current logic instead defines:

- `featureReferenceDate`
- `prev1Season`
- `prev2Season`

as the two most recent fully completed regular seasons before the reference date. This is the correct seasonal logic when contracts can be signed before the next league year formally begins.

That decision matters because it directly reduces temporal leakage.

## Predictor Engineering

The model matrix is intentionally broad. The project is not just asking whether a player was productive. It is asking how markets price a player after adjusting for age, prior market position, usage, team environment, and macro WR market conditions.

### Contract history and player context

Important contract-history and identity-era features include:

- `ageAtSigning`
- `yearsExpAtSigning`
- `observedContractNumber`
- `prevContractTerm`
- `prevContractAav`
- `prevContractAavPerc`
- `prevSignedTeam`
- `gapSincePrevContractEnd`
- draft information
- combine fields

These are critical because markets price prior market status very heavily.

### Player production

Regular season-level production features are built from nflverse player stats and include:

- volume,
- rate,
- efficiency,
- team-share,
- air-yards,
- rushing-side hybrid usage.

### Snap usage

Snap share and role stability are added because raw box-score production alone can miss role quality. A player with modest counting stats but elite route/snap participation can still project like a real market player.

### Next Gen receiving

Receiving NGS features were added because they capture receiver-specific traits such as separation, cushion, intended air yards, and YAC over expectation. Coverage is thinner, but the information is more football-specific than simple box-score totals.

### Team environment

Team offensive environment matters for interpreting player production. The same 800 yards can mean different things in a high-volume passing offense versus a low-volume environment. Team features include pass rate, efficiency, points, margins, and offense volume.

### Market context

The cleaner also computes a rolling WR market context from prior veteran WR contracts, including:

- contract count,
- median term,
- median `aav`,
- median `aavPerc`,
- `p75` `aavPerc`,
- median signing age.

This lets the model absorb macro market movement instead of forcing it to infer the whole price level indirectly from calendar time.

## Weighted And Delta Features

For season-level predictor families, the cleaner creates:

- `Prev1`
- `Prev2`
- `Weighted`
- `Delta`

The weighted value uses a `1:2` weighting on `Prev2` and `Prev1`. That choice was deliberate:

- the most recent season should matter more,
- the second prior season should still matter,
- a simple convex weighting is easier to defend than a more elaborate smoothing rule.

`Delta` captures change, because market pricing is partly about trend, not just level. A player moving from 450 to 900 yards is not the same market signal as a player flat at 675.

### Missing-data policy

The project explicitly avoided using zero as a generic missing-value code for player stats.

The policy is:

- raw season fields remain `NA` when unavailable,
- weighted features collapse to the single observed season if only one prior season exists,
- delta becomes `0` when one or both seasons are missing,
- availability flags are retained.

This is a compromise. It preserves real zeroes in the raw metrics, while letting the model treat missing trend as neutral rather than inventing a fake directional shock.

## Train, Validate, And Test Design

The split is time-based, not random:

- `train`: 2002-2025 signed contracts.
- `validate`: 2026 signed contracts.
- `test`: unsigned 2026 players.

This was the right split because the actual use case is forward-looking contract forecasting. A random split would mix eras and make the validation less realistic.

The test file intentionally leaves the 2026 outcome blank. That keeps the production scoring problem honest.

## Leakage Controls

Several leakage issues were identified and addressed during the project.

### Controlled correctly

- `term` models do not use current-contract `aav` or current-contract `aavPerc`.
- `aavPerc` models do not use current-contract `aav`.
- identifier columns are treated as metadata, not predictors.
- `signedTeam` is retained for audit but removed from the modeling recipe because it is unknown for unsigned future players.

### Intentionally allowed

The `aavPerc` model uses `term` as a predictor by design. This is not leakage for the chosen production workflow because the final product is scenario-based:

- first generate a term distribution,
- then estimate `aavPerc` under each possible term.

So the `aavPerc` model is a conditional contract-price model, not a one-shot joint contract model.

### Reduced but not eliminated

Exact signing dates are not available for every contract. ESPN transaction enrichment improved this meaningfully, but coverage is incomplete. The latest codebook snapshot shows observed signing-date coverage of about `60.1%` in `train.csv`.

That means some reference dates still rely on the offseason proxy, which is better than naive `startYear - 1` logic but not perfect.

## Why Term Was Bucketed To 5+

The raw support above 4 years was too sparse to justify separate `5`, `6`, `7`, and `8` classes.

Keeping the tail fully disaggregated caused:

- severe class imbalance,
- unstable multinomial estimation,
- noisy validation metrics,
- extra complexity with little practical decision value.

The final target buckets are:

- `1`
- `2`
- `3`
- `4`
- `5+`

This preserves the distinction between short and long deals while making the classification problem statistically better posed.

## Baseline Modeling

The baseline stage fit a broad, untuned model set for both tasks. That stage existed to answer a basic question before spending time tuning: which engines are even plausible in this feature space?

### Baseline candidates

For `term`, the baseline project compared multiclass classifiers such as:

- null model,
- multinomial linear baselines,
- regularized generalized linear models,
- tree models,
- random forest,
- XGBoost,
- LightGBM where available.

For `aavPerc`, the baseline project compared regression analogues across linear, penalized, tree, and boosted models.

### Baseline conclusion

The strongest baseline families were:

- `xgboost` for `term`,
- `ranger` as a close competitor for `term`,
- `xgboost` for `aavPerc`,
- ridge-style linear models as the most interpretable compensation baseline.

Those results justified investing tuning time in:

- `term_xgb`
- `term_rf`
- `term_ll`
- `aavPerc_xgb`
- `aavPerc_rf`
- `aavPerc_rl`

## Optimization Stage

Hyperparameter tuning was implemented in `R/optimization_helpers.R` and the task-specific tuning scripts.

### Resampling design

Training resamples use grouped 5-fold cross-validation by `playerId`.

This was a necessary decision. Some players appear multiple times in the contract history. If those rows were allowed to split across folds, the cross-validation would become too optimistic because the model would be exposed to the same player’s contract history in both analysis and assessment folds.

### Tuning methods

- `xgboost` and `random forest` used Bayesian optimization.
- lasso and ridge used cross-validated lambda selection over a regularization grid.

The primary tuning metric was chosen to match the problem:

- `term`: multinomial log loss.
- `aavPerc`: RMSE.

Accuracy was deliberately not the primary metric for `term` because the 2026 validation set is dominated by one-year deals. A model can look deceptively good on raw accuracy by mostly learning the marginal distribution.

## Optimized Model Results

From `results/optimized.md`, the selected tuned models were:

### Term

- `term_xgb`: best predictive term model.
- `term_ll`: chosen interpretable term model.

Validation metrics:

- `term_xgb`: `mnLogLoss = 0.536581`, `rocAuc = 0.674789`, `brier = 0.056768`, `accuracy = 0.824176`
- `term_ll`: `mnLogLoss = 0.591975`, `rocAuc = 0.642260`, `brier = 0.060119`, `accuracy = 0.813187`

### aavPerc

- `aavPerc_xgb`: best predictive compensation model.
- `aavPerc_rl`: chosen interpretable compensation model.

Validation metrics:

- `aavPerc_xgb`: `rmse = 0.005654`, `mae = 0.002615`, `rsq = 0.902898`
- `aavPerc_rl`: `rmse = 0.006082`, `mae = 0.003890`, `rsq = 0.883440`

These are strong numbers, but they should be interpreted correctly:

- `aavPerc` is conditional on term, which is the intended production setup.
- `term` accuracy is flattered by the 2026 class distribution, so log loss remains the real term metric.

## Final Model Selection

The final selected models were:

### Highest predictive

- `term_xgb_final`
- `aavPerc_xgb_final`

### Most interpretable

- `term_ll_final`
- `aavPerc_rl_final`

This gives the project two usable model families:

- a higher-performance forecasting pair,
- a more transparent audit pair with closed-form structure.

That is better than pretending one model can satisfy both goals equally well.

## Final Refit

After model selection, the chosen models were refit on `train + validate` and saved to `models/`:

- `models/term_xgb_final.rds`
- `models/term_ll_final.rds`
- `models/aavPerc_xgb_final.rds`
- `models/aavPerc_rl_final.rds`

Detailed markdown reports and interpretation artifacts were also generated:

- feature-importance reports for the XGBoost models,
- coefficient reports and plots for the lasso and ridge models,
- supporting CSV exports for coefficients or importances.

These reports live in `models/` and `models/plots/`.

## Final Prediction Workflow

`R/final_predictions.R` loads the saved final models and scores `data/test.csv`.

### Term outputs

For each unsigned 2026 free agent, the term models produce:

- class probabilities for `1`, `2`, `3`, `4`, `5+`,
- a modal term,
- an expected term.

### aavPerc outputs

For each free agent and each term scenario, the compensation models produce:

- predicted `aavPerc`,
- predicted dollar AAV using the implied 2026 cap,
- scenario-level tables that can be combined with term probabilities.

### Pair summaries

The final output is published as two paired forecast systems:

- predictive pair: `term_xgb_final + aavPerc_xgb_final`
- interpretable pair: `term_ll_final + aavPerc_rl_final`

The `final/` directory contains:

- term probabilities,
- scenario-level `aavPerc` predictions,
- pair-level summaries,
- player context,
- metadata.

Important files include:

- `final/summary_xgb.csv`
- `final/summary_glm.csv`
- `final/scenarios_xgb.csv`
- `final/scenarios_glm.csv`
- `final/player_context.csv`

## Web Application

A local static web application was built in plain `HTML`, `CSS`, and `JavaScript`, with the data served from the existing project outputs.

The final app is intentionally scenario-first and compact rather than dashboard-heavy. The production UI now has three views:

- `Player Lens`: one-player negotiation view with previous-contract anchors on the left, the best available current player and market context on the right, and the scenario-based AAV path plus contract menu underneath.
- `Market Board`: a market-wide scatter and ranking table centered on `1-year probability` versus projected price, because the 2026 unsigned WR cohort is overwhelmingly one-year leaning.
- `Method`: model-family documentation view showing the active architecture, held-out validation metrics, chosen hyperparameters, and the saved feature-importance or coefficient artifacts for the two active models.

The Shiny implementation was retired because it forced the analysis into cramped cards and control-heavy chrome. The replacement frontend is a browser-native app built from:

- `index.html`
- `styles.css`
- `app.js`
- `final/app_data.json`

`R/build_frontend_data.R` now assembles not just player predictions but also method-tab metadata from the saved tuning results and final model artifacts. That metadata includes:

- held-out validation metrics for the active pair,
- selected hyperparameters or lambda values,
- top gain-importance rows for `xgboost` models,
- top coefficient tables and class sparsity summaries for penalized regression models,
- and links to the saved plots in `models/plots/`.

The player lens deliberately stopped showing every possible engineered feature. Earlier iterations created clutter and `NA`-heavy panels because the unsigned 2026 pool does not have full stat coverage:

- all players have previous-contract and market-anchor context,
- `61` have snap-share context,
- `53` have matched weighted regular receiving stats,
- `12` have matched NGS receiving efficiency.

The final layout therefore prioritizes universally available contract context first, then fills the right-hand player block with only the best non-missing player or market metrics for the selected free agent.

`R/launch_app.R` now starts a simple local static server through Python’s built-in `http.server` and opens the browser to the project root.

The app is currently live locally at:

- [http://127.0.0.1:8181/](http://127.0.0.1:8181/)

## Important Statistical Rationale

### Why split term and price

Term and price are related but not identical. Contract negotiations often revolve around multiple term scenarios with different `aav` paths. A single joint model would be harder to interpret and harder to present cleanly.

### Why use `aavPerc` instead of raw `aav`

Using cap share instead of raw dollars stabilizes the target across eras and makes the outcome more comparable through time.

### Why keep both predictive and interpretable models

The boosted models are better forecasting engines. The penalized linear models are better audit tools. In a project like this, both matter:

- forecasting without interpretability creates trust problems,
- interpretability without strong predictive performance creates utility problems.

### Why grouped CV by player

Without grouping, the model would leak repeated-player structure across folds. Grouping by `playerId` is the right compromise between realistic resampling and efficient use of the historical sample.

### Why not use game-by-game data

The user explicitly wanted a season-level workflow, and that is appropriate here. The contract question is primarily a market-pricing problem, not a week-level game-state problem. Season aggregation is simpler, faster, and easier to defend.

## Remaining Limitations

No serious project summary should pretend the workflow is perfect.

### 1. Signing-date coverage is incomplete

ESPN matching improved the temporal logic, but exact dates are not observed for every row.

### 2. Player matching is probabilistic

The pipeline exposes match-quality variables, but any multi-source player-identity workflow still has some error risk.

### 3. Validation sample is small

`validate.csv` has only `91` rows, and the term distribution is heavily concentrated in one-year contracts. That is enough to compare model families, but not enough to treat small metric differences as absolute truth.

### 4. NGS coverage is thin

Advanced receiving features are useful when present, but their historical coverage is much weaker than standard season stats.

### 5. The app reports model outputs, not certainty

The scenario framework is intentionally probabilistic, but it is still a model-based view of a noisy market. Team-specific need, medical information, and private negotiation context are not fully observed here.

## Final File Map

### Data preparation

- `R/clean.R`
- `data/codebook.md`
- `data/train.csv`
- `data/validate.csv`
- `data/test.csv`

### Baselines and tuning

- `R/term_baseline.R`
- `R/aavPerc_baseline.R`
- `R/optimization_helpers.R`
- `R/term_xgb.R`
- `R/term_rf.R`
- `R/term_ll.R`
- `R/aavPerc_xgb.R`
- `R/aavPerc_rf.R`
- `R/aavPerc_rl.R`
- `results/baseline.md`
- `results/optimized.md`

### Final models

- `R/final_model_helpers.R`
- `R/term_xgb_final.R`
- `R/term_ll_final.R`
- `R/aavPerc_xgb_final.R`
- `R/aavPerc_rl_final.R`
- `models/`

### Final predictions and app

- `R/final_predictions.R`
- `R/build_frontend_data.R`
- `R/launch_app.R`
- `final/`
- `index.html`
- `styles.css`
- `app.js`

## End State

The project now has:

- a cleaned non-entry WR contract dataset,
- temporally improved season windows,
- tuned predictive and interpretable model pairs,
- serialized final models,
- scenario-based predictions for unsigned 2026 WR free agents,
- and a live local application for reviewing the outputs.

That is a materially complete workflow, not just a notebook or exploratory prototype.
