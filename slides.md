# Rento Saijo Slide Notes

## Slide 1: NFL Wide Receiver Contract Projection

Open by framing this as a contract-forecasting project, not just a football project. The goal is to use public information available before a signing decision to project what the veteran wide receiver market might look like for 2026.

Emphasize that this is Rento's setup section: introduction, background, research questions, data, wrangling, and architecture. The dashboard will be handled as a live demo later, so these slides are meant to give the audience enough context to understand the model sections.

## Slide 2: What is a wide receiver?

Explain wide receiver in non-football terms: a wide receiver is an offensive player whose main job is to get open, catch passes from the quarterback, and create yards or touchdowns after the catch.

Use the two big words on the slide:

- Targets: how often the quarterback throws to the receiver. This is partly player talent and partly team role.
- Yards: the field position or offensive value the receiver creates.

Then connect this to contracts. Teams are not only paying for what happened last season. They are paying for expected future role, health, age, leverage, and market context. That is why a model has to include more than box-score production.

## Slide 3: A contract is really a menu of commitments

The key background idea is that NFL contracts are not one simple number. A one-year "prove-it" deal, a two-year role-player deal, and a four-year star extension all mean different things even before discussing dollars.

Define the examples:

- One-year deal: low team commitment, often used for older players, bounce-back candidates, depth players, or players re-entering the market quickly.
- Two-year deal: more stability, but still usually not a franchise-level commitment.
- Four-year deal: more like a long-term bet, generally requiring stronger evidence of sustained value.

This motivates the first modeling task: before predicting price, predict contract length. Term is the market's commitment decision.

## Slide 4: Raw dollars do not travel across eras

Explain AAV: average annual value, or total reported contract value divided by years. Then explain why the project models AAV as a percentage of the salary cap instead of raw dollars.

Use the $10M example. Under a $120M cap, $10M is 8.3% of the cap. Under a $300M cap, the same $10M is only 3.3% of the cap. So the same nominal salary means very different things in different eras.

The modeling target is therefore `aavPerc`, the player's AAV as a share of the salary cap at signing. After prediction, the project can translate the percentage back into 2026 dollars for interpretation and the dashboard.

## Slide 5: The project asks three questions

Read the three research questions exactly as written:

1. Can the term of a veteran wide receiver contract be predicted from public information available before signing?
2. Can the contract's AAV as a percentage of the salary cap be predicted with useful accuracy?
3. Which contract-history, career-stage, production, team-context, and market variables explain those predictions?

Point out that these questions are intentionally ordered. Term comes first because length is a different market decision from price. AAV% comes second because compensation is being modeled after normalizing for cap growth. The third question is about trust and interpretation: even if a model predicts well, we need to understand what information it is using.

## Slide 6: The contract file is the spine

Walk through the source stack.

Spotrac wide receiver contract exports are the contract spine. They provide the outcomes and core contract fields: player name, team, signing age, start year, end year, term, total value, AAV, and AAV as a cap percentage.

nflreadr / nflverse adds football context: player references, rosters, combine measurements, regular receiving stats, snap counts, Next Gen receiving stats, team offensive context, and schedules.

ESPN transactions are used to recover signing dates where possible. This matters because the model should only use information known before a contract was signed. If the date is not matched, the workflow uses a recorded March 15 offseason proxy.

Close the slide by saying the cleaned files are designed so each row is a veteran WR contract or unsigned 2026 candidate, with predictors frozen before the signing decision.

## Slide 7: The wrangling pipeline prevents leakage

This is the leakage-control slide. The model should not accidentally learn from information that would only be known after the contract was signed.

Talk through the five steps:

1. Clean the contract spine: standardize names, parse contract economics, repair implausible end years.
2. Remove the wrong market: exclude rookie-scale and rookie-adjacent deals because rookie contracts are priced by a different mechanism.
3. Find the reference date: use matched ESPN signing dates when available; otherwise use the March 15 proxy.
4. Freeze history windows: `prev1` and `prev2` are the two most recent fully completed seasons before the reference date.
5. Build prior context: previous contracts, player production, team context, market context, and availability flags.

Then say the leakage rules explicitly: the term model does not use current-contract AAV or AAV%, the AAV% model does not use current-contract AAV, and signed team is not used because it is unknown for unsigned candidates.

This is also where you can briefly explain the `prev1` / `prev2` idea from the removed slide: for each contract row, the cleaner starts from the signing reference date and looks backward to the two most recent fully completed seasons. Weighted features emphasize the most recent season, deltas capture movement, and availability flags tell the model whether a source exists for that player.

## Slide 8: The file is wide because contracts price more than box scores

Use this slide to describe what kind of data exists in the modeling table. Do not present this as EDA or as a model-result slide. The point is that each contract row contains many different ways to understand a receiver before the signing decision.

The cleaned files have 456 columns in each split. The main feature families are:

- Contract history: previous term, previous AAV%, time since last deal, and how many contracts the player has already had.
- Career stage: age, years of experience, draft status, and combine information when available.
- Receiving production: targets, catches, yards, touchdowns, first downs, EPA, air yards, yards after catch, target share, and related rates.
- Usage and tracking: snap counts, offensive snap share, and Next Gen receiving data where the public feed has coverage.
- Team context: team passing volume, efficiency, points, wins, and offensive environment.
- WR market context: recent veteran WR market count, median term, median AAV%, and upper-market AAV% levels.

The small coverage chart is there only to explain the data's shape. Some sources are universal or nearly universal, like prior-contract and market context. Others are newer or harder to match, like Next Gen receiving. The important message is that missingness is tracked intentionally. Availability flags help the model distinguish "we do not have this source" from "the player produced zero."

## Slide 9: The split matches the forecasting problem

Explain that the split is time-based rather than random because the production use case is forward-looking.

The train split is 2002-2025 signed veteran WR contracts. The validate split is signed 2026 contracts, which gives a held-out test of how models behave on the current market. The test split is unsigned 2026 WR free-agent candidates, where outcomes are intentionally blank because these are the players being scored.

Mention the row counts shown on the slide:

- Train: 2,796 rows, 1,305 players.
- Validate: 91 rows, 91 players.
- Test: 163 rows, 163 players.

The important point is not just the size. The split mirrors the actual forecasting task: learn from history, check on current signed players, score the unsigned market.

## Slide 10: The solution is a term-price menu

This is the architecture slide.

The workflow has two linked steps:

1. The term model predicts probabilities over contract lengths: 1, 2, 3, 4, and 5+ years.
2. The AAV% model predicts compensation conditional on a supplied term scenario.

Explain why this is better than a single one-shot dollar forecast. Contract negotiations are scenario-based. A player might have one expected price on a one-year deal and a different price path on a three-year deal. The project therefore outputs a menu: term probabilities, term-specific AAV% estimates, and a probability-weighted expected value.

This also explains why `term` is allowed as a predictor in the AAV% model. It is not leakage in this design because the AAV% model is explicitly conditional: "If the term is X, what cap-share price follows?"

Close by handing off to the model sections. Manahil's section evaluates the commitment probabilities. Roop's section evaluates the conditional price model. The dashboard later uses this same architecture as a live player-level contract menu.

# Notes for the Rest of the Presentation

These notes are not PowerPoint slide content. They are a speaking guide for the remaining sections after Rento's setup slides.

## Manahil: Term Model

### Term Model Framing

Start by connecting directly to the architecture slide. Rento has just explained that the first model estimates the market's commitment decision. Manahil's job is to answer: given public pre-signing information, how much contract length is the player likely to receive?

Define the response variable clearly:

- `term` is a multiclass outcome.
- Classes are `1`, `2`, `3`, `4`, and `5+`.
- `5+` pools five-or-more-year deals because separate five-, six-, seven-, and eight-year classes were too sparse to model reliably.

Emphasize that term is not the same as price. Term measures team commitment and player leverage. A one-year deal can be cheap or expensive; a multi-year deal usually signals a different level of confidence from the market.

### EDA Leading to Feature Engineering and Preprocessing

The key EDA point is class concentration. The validation market is dominated by one-year contracts: 76 of the 91 signed 2026 validation contracts were one-year deals. That means accuracy can be misleading. A model that always predicts one year has high accuracy, but it does not give useful probabilities for comparing players.

Talk about why `5+` bucketing was necessary. The long tail above four years is real football information, but individual long-term classes are too rare. Bucketing preserves the distinction between ordinary short-term deals and genuinely long commitments while making the classification problem statistically better posed.

Then transition to preprocessing:

- Remove identifiers and audit fields from predictors.
- Remove non-ex-ante fields such as signing dates after they have already been used to construct feature windows.
- Remove current-contract `aav` and `aavPerc`, because those would leak the answer into the term model.
- Remove `signedTeam`, because it is not known for unsigned 2026 candidates.
- Encode logical variables as yes/no factors.
- Convert character predictors to factors.
- Handle unknown and new levels explicitly.
- Dummy encode categorical fields.
- Mode-impute categorical predictors.
- Median-impute numeric predictors.
- Remove zero-variance predictors.
- Normalize numeric predictors.

Mention the final term matrix had about 500 predictors after preprocessing.

### Model Comparisons and Metrics

Explain that the baseline stage screened a broad set of models before tuning:

- null majority classifier,
- multinomial logistic models,
- ridge, lasso, and elastic net via `glmnet`,
- neural net,
- decision tree,
- random forest,
- XGBoost,
- LightGBM where available.

The baseline result to highlight is that the null majority model had the highest raw accuracy, about `83.5%`, because it essentially picked one year. But it had much worse probability quality: log loss `0.757` and Brier `0.072`. This is the reason accuracy is not the main metric.

Use these metric definitions:

- Log loss is the main metric because it rewards putting high probability on the true class and punishes overconfident wrong predictions.
- Brier score measures probability calibration quality.
- ROC AUC is a secondary ranking metric.
- Accuracy is reported, but it is not the selection criterion.

The optimized comparison on the signed 2026 validation set:

- XGBoost: log loss `0.537`, ROC AUC `0.675`, Brier `0.057`, accuracy `82.4%`.
- Random forest: log loss `0.545`, ROC AUC `0.669`, Brier `0.057`, accuracy `81.3%`.
- Lasso multinomial: log loss `0.592`, ROC AUC `0.642`, Brier `0.060`, accuracy `81.3%`.

The selected predictive model is `term_xgb`. The selected interpretable audit model is `term_ll`, the lasso multinomial model.

Mention the tuning design:

- Training resamples used grouped 5-fold cross-validation by `playerId`.
- Grouping by player matters because some players appear multiple times in the historical contract data.
- XGBoost and random forest used Bayesian optimization.
- Lasso used a regularization grid.
- Selection prioritized multinomial log loss.

### Term Model Interpretation

The main interpretation is that term is driven first by contract history and career stage, not just receiving production.

For the XGBoost term model, the top gain-importance features include:

- observed contract number,
- years of experience at signing,
- unknown previous signed team indicator,
- player-reference age gap and rookie gap,
- weighted receiving yards,
- previous-season receiving EPA,
- previous contract start year,
- player-reference match indicator,
- previous contract AAV,
- age at signing.

Explain this as a market-commitment story. The model is learning whether the player looks like an established multi-contract veteran, a younger prime-age receiver, a fringe player with weaker matching/history, or someone with recent production strong enough to support longer commitment.

For the lasso audit model, say that one-year contract scores are shaped by age, previous-contract timing, and availability/game-history signals, while longer-term classes retain more production, team-context, and continuity signals.

### Term Model Conclusions

The answer to research question 1 is qualified:

Term can be predicted from public information, but the useful output is a probability distribution, not just a single predicted class.

The model is especially useful because it tells us how much probability remains on multi-year outcomes. Even when the modal prediction is one year, a player with 65% one-year probability is different from a player with 95% one-year probability.

This is also why the term model feeds the rest of the project. It gives the probability weights that later combine with Roop's conditional AAV% predictions.

### Term Model Limitations and Future Work

Term-specific limitations:

- The validation market is heavily one-year, so accuracy can overstate performance.
- Public data do not include private team need, medical information, agent leverage, or guarantee structure.
- Rare long-term contracts are pooled into `5+`, which stabilizes modeling but loses detail inside the long-term tail.
- Proxy signing dates can blur the pre-signing window.
- Name and roster matching is weakest for fringe players.

Future work:

- Add calibration diagnostics and interval-style uncertainty.
- Add team cap room and team need scenarios.
- Separate extension-style deals from open-market free-agent deals more explicitly if enough data can be gathered.
- Model guarantees and incentives, not only reported term.

## Roop: AAV% Model

### AAV% Model Framing

Start by connecting to Manahil's section. Once the project has a probability distribution over term, Roop's model asks: under a supplied term scenario, what cap-share price follows?

Define the response:

- `aavPerc` is average annual value as a share of the NFL salary cap at signing.
- It is modeled instead of raw dollars so contracts are comparable across eras.
- Current-contract `aav` is not used as a predictor.
- `term` is allowed as a predictor because this is a conditional pricing model: "If the term is X, what AAV% follows?"

Make the architecture point explicit. This is not leakage because term is supplied as a scenario in production. The model is not pretending it already knows the negotiated term; it is pricing each possible term path.

### EDA Leading to Feature Engineering and Preprocessing

The AAV% EDA should focus on why price is different from term.

Important points:

- Price is less compressed than term.
- The unsigned 2026 market is mostly short-term in modal term, but expected AAV still varies substantially.
- In the predictive model pair, the mean expected AAV for 2026 unsigned receivers is about `$1.49M`, the median is about `$1.11M`, and the maximum is about `$11.52M`.
- Top expected-AAV names in the predictive pair include Deebo Samuel, Jauan Jennings, Keenan Allen, Sterling Shepard, DeAndre Hopkins, Adam Thielen, Josh Reynolds, and Ray-Ray McCloud.

Use this to motivate feature engineering. AAV% is more directly tied to receiving value and prior market value than term is. Term answers commitment; AAV% answers price conditional on that commitment.

Preprocessing is parallel to the term model:

- Remove identifiers, audit fields, and non-ex-ante metadata.
- Remove current-contract `aav`.
- Keep `aavPerc` only as the outcome.
- Keep `term` as a conditional scenario predictor.
- Handle unknown/new categorical levels.
- Dummy encode factors.
- Impute missing categorical and numeric predictors.
- Remove zero-variance predictors.
- Normalize numeric predictors.

Mention the final AAV% matrix had about 504 predictors after preprocessing.

### Model Comparisons and Metrics

The baseline AAV% screen compared:

- null mean regression,
- ordinary linear regression,
- ridge, lasso, and elastic net,
- neural net,
- decision tree,
- random forest,
- XGBoost,
- LightGBM where available.

For regression, the main metric is RMSE because the outcome is continuous cap share. MAE and R-squared are supporting metrics.

Baseline highlights:

- XGBoost was the best untuned regressor: RMSE `0.00610`, MAE `0.00318`, R-squared `0.882`.
- Random forest was close: RMSE `0.00619`, R-squared `0.876`.
- Ridge was the strongest linear-style baseline: RMSE `0.00640`, R-squared `0.871`.
- The null mean model was much worse: RMSE `0.01770`.

Optimized validation results:

- XGBoost: RMSE `0.005654`, MAE `0.002615`, R-squared `0.902898`.
- Ridge linear: RMSE `0.006082`, MAE `0.003890`, R-squared `0.883440`.
- Random forest: RMSE `0.006090`, MAE `0.003062`, R-squared `0.879610`.

The selected predictive model is `aavPerc_xgb`. The selected interpretable audit model is `aavPerc_rl`, the ridge regression model.

Translate the RMSE for the audience: RMSE `0.0057` means about 0.57 percentage points of the salary cap. At the implied 2026 cap, that is roughly `$1.7M`.

### AAV% Model Interpretation

The key interpretation is that compensation is more production-driven than term.

For the XGBoost AAV% model, the top gain-importance features include:

- weighted receiving yards,
- weighted receiving yards per game,
- previous-season receiving yards per game,
- previous-season receiving first downs per game,
- previous-season target share,
- Next Gen weighted yards,
- `term_X5`,
- previous contract AAV%,
- previous-season receiving yards,
- Next Gen weighted receiving touchdowns,
- previous-season offensive snap percentage,
- team yards share,
- `term_X4`.

Explain this as a pricing story. The AAV% model is learning how much a player's recent production, role, target share, prior market price, and supplied term scenario should be worth as a share of the cap.

For the ridge audit model, the paper's interpretation is that the largest coefficients are term indicators and previous-contract market variables, followed by receiving and snap-context features. That is a useful check: both the flexible model and the interpretable model point toward term and receiving value as important price signals.

### AAV% Model Conclusions

The answer to research question 2 is stronger than the term answer:

Cap-share AAV is meaningfully predictable once the model conditions on term.

The final output should not be read as "this player will sign exactly for this dollar amount." It should be read as a scenario menu. A player may have one price under a one-year term and a different price under a multi-year term, and the expected AAV combines those scenario prices with Manahil's term probabilities.

### AAV% Model Limitations and Future Work

AAV%-specific limitations:

- Public reported AAV omits guarantees, incentives, option years, and contract structure.
- Medical information, private workouts, team cap room, and negotiation leverage are not observed.
- Route participation, target quality, separation, and injury context would improve the receiver-value signal.
- Next Gen Stats coverage is thinner historically, especially before 2020.
- Because the AAV% model is conditional on term, errors in term probabilities affect the final expected value.

Future work:

- Model guarantees and incentives separately from AAV.
- Add team-specific cap-and-need scenarios.
- Add prediction intervals around AAV% and dollar AAV.
- Refresh Spotrac and nflverse sources automatically as new 2026 signings occur.
- Separate player archetypes, such as slot receivers, deep threats, return specialists, and aging veterans, if sample size supports it.

## Roop: Overall Conclusions

The overall conclusion should connect the two model sections back to the research questions.

Main answers:

1. Term can be predicted, but it is best represented as a probability distribution over contract lengths.
2. AAV% is meaningfully predictable once the model conditions on supplied term.
3. The two outcomes are related but not interchangeable. Term is driven more by career stage and contract history; compensation is driven more by receiving value, role, prior market value, and the supplied term scenario.

Final model pair:

- Predictive pair: `term_xgb_final + aavPerc_xgb_final`.
- Interpretable pair: `term_ll_final + aavPerc_rl_final`.

Big practical takeaway:

The project should be understood as a public-data contract menu, not a single precise dollar prediction. That is more realistic because NFL negotiation itself is scenario-based.

For the 2026 unsigned WR market, the model projects a short-term market:

- 163 unsigned 2026 WR candidates were scored.
- Every scored player has a one-year modal term in the predictive pair.
- Mean one-year probability is about `85.8%`.
- Median expected AAV is about `$1.11M`.
- Top expected-AAV cases are Deebo Samuel, Jauan Jennings, and Keenan Allen, who still retain meaningful one-year probability but stand out on price because of production and prior market signals.

Overall limitations:

- Public data cannot see private negotiation context.
- Contract guarantees and incentives are omitted from the main targets.
- Signing-date proxies are imperfect.
- Advanced receiver tracking coverage is incomplete.
- Team-specific cap room and need are not yet modeled.

Overall future work:

- Add guarantee and incentive modeling.
- Add team-level scenario scoring.
- Add uncertainty intervals and calibration checks.
- Improve player matching and automate data refreshes.
- Expand from WR-only to other positions only if position-specific modeling designs are built, because other positions have different market logic.

## Rento: Dashboard Live Demo

This section should be live demo rather than additional slides.

Start by saying the dashboard is the same architecture the audience has just seen:

- term probabilities from the term model,
- conditional AAV% paths from the compensation model,
- probability-weighted contract summaries,
- player context to explain why the output looks the way it does.

### Suggested Demo Flow

1. Open with the dashboard purpose.

Say: "The paper and slides explain the modeling system. The dashboard is where the model becomes a player-level contract menu."

2. Start in `Player Lens`.

Pick a recognizable top player such as Deebo Samuel, Jauan Jennings, or Keenan Allen. Walk through:

- previous-contract anchors,
- age and experience,
- relevant player/market context,
- term probability distribution,
- scenario-specific AAV paths,
- expected AAV summary.

Emphasize that the modal term can be one year while expected value is still high. That is the entire reason the menu view is useful.

3. Switch to another player with a lower expected value.

Choose a depth/fringe receiver and show how the same interface changes. The point is to show that the model is not only ranking stars; it is applying a consistent framework to the whole unsigned WR market.

4. Move to `Market Board`.

Explain the scatter/ranking view:

- x-axis: one-year probability,
- y-axis: expected AAV,
- table: market-wide ranking and player lookup.

Use this to reinforce the overall market conclusion: most players are short-term leaning, but price is right-skewed.

5. Move briefly to `Method`.

Do not spend too long here. Use it to show transparency:

- active architecture,
- validation metrics,
- chosen hyperparameters,
- feature-importance or coefficient artifacts.

6. Close with the main takeaway.

Say: "The model is not trying to be a perfect contract oracle. It is a structured way to turn public information into term probabilities, conditional price scenarios, and a transparent market board."

### Dashboard Talking Points

Use the dashboard to make these points concrete:

- A single dollar forecast hides too much.
- A player can be likely to receive a one-year deal and still be expensive.
- Probability-weighted expected value is not the same as modal contract value.
- The model pair makes tradeoffs visible: commitment first, price second.
- The dashboard is useful for comparison, not certainty.

### Dashboard Limitations to Mention

Keep this short because Roop will already cover overall limitations:

- It uses public data only.
- It does not know team-specific medicals, agent leverage, guarantees, incentives, or private bidding.
- It should be interpreted as a scenario tool, not a prediction of the exact signed contract.
