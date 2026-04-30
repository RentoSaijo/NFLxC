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
