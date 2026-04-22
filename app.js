const pairMeta = {
  xgb: {
    label: 'Predictive pair',
    subtitle: 'XGBoost term classifier + XGBoost conditional AAV% regressor',
  },
  glm: {
    label: 'Interpretable pair',
    subtitle: 'Lasso multinomial term model + ridge conditional AAV% model',
  },
}

const termColors = {
  1: '#376996',
  2: '#5d8c52',
  3: '#b86533',
  4: '#7f4f9a',
  5: '#a63b3b',
}

const state = {
  pair: 'xgb',
  activePanel: 'player',
  selectedId: null,
}

const els = {
  pairToggle: document.getElementById('pair-toggle'),
  pageTabs: Array.from(document.querySelectorAll('.page-tab')),
  panelCards: Array.from(document.querySelectorAll('.panel-card')),
  heroStats: document.getElementById('hero-stats'),
  boardCount: document.getElementById('board-count'),
  leaderboardBody: document.getElementById('leaderboard-body'),
  playerSelect: document.getElementById('player-select'),
  playerName: document.getElementById('player-name'),
  playerSubtitle: document.getElementById('player-subtitle'),
  playerMiniGrid: document.getElementById('player-mini-grid'),
  playerSummaryGrid: document.getElementById('player-summary-grid'),
  scenarioBody: document.getElementById('scenario-body'),
  methodCopy: document.getElementById('method-copy'),
  marketChart: document.getElementById('market-chart'),
  scenarioChart: document.getElementById('scenario-chart'),
}

let appData = null

const escapeHtml = (value) =>
  String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')

const formatMoney = (value) =>
  value == null || Number.isNaN(value)
    ? 'N/A'
    : `$${Number(value).toFixed(2)}M`

const formatMoneyCompact = (value) =>
  value == null || Number.isNaN(value)
    ? 'N/A'
    : `$${Number(value).toFixed(1)}M`

const formatShare = (value, digits = 3) =>
  value == null || Number.isNaN(value)
    ? 'N/A'
    : `${(Number(value) * 100).toFixed(digits)}%`

const formatNumber = (value, digits = 2) =>
  value == null || Number.isNaN(value)
    ? 'N/A'
    : Number(value).toFixed(digits)

const formatInteger = (value) =>
  value == null || Number.isNaN(value)
    ? 'N/A'
    : Number(value).toFixed(0)

const formatSignedPoints = (value, digits = 2) => {
  if (value == null || Number.isNaN(value)) {
    return 'N/A'
  }

  const numeric = Number(value) * 100
  const sign = numeric > 0 ? '+' : ''
  return `${sign}${numeric.toFixed(digits)} pts`
}

const termLabel = (value) => (Number(value) === 5 ? '5+' : String(value))

const termPill = (value) =>
  `<span class='term-pill term-${Number(value)}'>${termLabel(value)}</span>`

const getSummary = (player, pair) => player.models[pair].summary

const getScenarios = (player, pair) => player.models[pair].scenarios

const metricTileHtml = (tile, tileClass = 'metric-tile') => `
  <article class='${tileClass}'>
    <p class='metric-label'>${escapeHtml(tile.label)}</p>
    <p class='metric-value'>${escapeHtml(tile.value)}</p>
    <p class='metric-sub'>${escapeHtml(tile.sub)}</p>
  </article>
`

const nonNullTiles = (tiles) =>
  tiles.filter((tile) => tile.value != null && tile.value !== '' && tile.value !== 'N/A')

const methodMetricLabel = (name) => {
  const labels = {
    mnLogLoss: 'Log loss',
    rocAuc: 'ROC AUC',
    brier: 'Brier',
    accuracy: 'Accuracy',
    rmse: 'RMSE',
    mae: 'MAE',
    rsq: 'R²',
  }

  return labels[name] ?? name
}

const methodParamLabel = (name) => {
  const labels = {
    mtry: 'mtry',
    trees: 'trees',
    min_n: 'min_n',
    tree_depth: 'tree_depth',
    learn_rate: 'learn_rate',
    loss_reduction: 'loss_reduction',
    sample_size: 'sample_size',
    lambda: 'lambda',
  }

  return labels[name] ?? name
}

const methodTableLabel = (name) => {
  const labels = {
    class: 'Class',
    feature: 'Feature',
    coefficient: 'Coefficient',
    gain: 'Gain',
    cover: 'Cover',
    frequency: 'Frequency',
    absValue: 'Abs. value',
  }

  return labels[name] ?? name
}

const formatMethodValue = (value, digits = 6) => {
  const numeric = Number(value)

  if (!Number.isFinite(numeric)) {
    return String(value)
  }

  if (Number.isInteger(numeric)) {
    return String(numeric)
  }

  return numeric.toFixed(digits)
}

const comparePlayers = (left, right) => {
  const leftSummary = getSummary(left, state.pair)
  const rightSummary = getSummary(right, state.pair)

  return (
    (rightSummary.expectedAavMillions ?? -Infinity) - (leftSummary.expectedAavMillions ?? -Infinity) ||
    (rightSummary.prob1 ?? -Infinity) - (leftSummary.prob1 ?? -Infinity) ||
    left.playerName.localeCompare(right.playerName)
  )
}

const filteredPlayers = () => appData.players.slice().sort(comparePlayers)

const selectedPlayer = (players) => {
  if (players.length === 0) {
    state.selectedId = null
    return null
  }

  const selected = players.find((player) => player.contractRowId === state.selectedId)

  if (selected) {
    return selected
  }

  state.selectedId = players[0].contractRowId
  return players[0]
}

const buildHeroStats = (players) => {
  const topPlayer = players[0]
  const oneYearValues = players.map((player) => getSummary(player, state.pair).prob1).filter((value) => value != null)
  const modalCounts = players.reduce((acc, player) => {
    const modalTerm = Number(getSummary(player, state.pair).modalTerm)
    if (Number.isFinite(modalTerm)) {
      acc[modalTerm] = (acc[modalTerm] || 0) + 1
    }
    return acc
  }, {})
  const topAav = topPlayer ? getSummary(topPlayer, state.pair).expectedAavMillions : null
  const capBasis = appData.metadata.impliedCap2026 / 1e6
  const medianOneYear =
    oneYearValues.length === 0
      ? null
      : oneYearValues.sort((a, b) => a - b)[Math.floor(oneYearValues.length / 2)]
  const dominantTerm = Object.entries(modalCounts).sort((a, b) => b[1] - a[1])[0]

  return [
    {
      label: 'Active board',
      value: `${players.length}`,
      sub: `${pairMeta[state.pair].label} for the full unsigned WR board`,
    },
    {
      label: 'Top expected AAV',
      value: formatMoney(topAav),
      sub: topPlayer ? topPlayer.playerName : 'No players after filters',
    },
    {
      label: 'Median 1Y probability',
      value: medianOneYear == null ? 'N/A' : formatShare(medianOneYear, 1),
      sub: dominantTerm ? `${dominantTerm[1]} of ${players.length} players still have ${termLabel(Number(dominantTerm[0]))} as the modal bucket` : 'No term mix available',
    },
    {
      label: 'Cap basis',
      value: `$${formatNumber(capBasis, 1)}M`,
      sub: 'Implied from signed 2026 contracts',
    },
  ]
}

const renderHeroStats = (players) => {
  els.heroStats.innerHTML = buildHeroStats(players)
    .map(
      (item) => `
        <article class='hero-stat'>
          <p class='hero-stat-label'>${escapeHtml(item.label)}</p>
          <p class='hero-stat-value'>${escapeHtml(item.value)}</p>
          <p class='hero-stat-sub'>${escapeHtml(item.sub)}</p>
        </article>
      `
    )
    .join('')
}

const renderLeaderboard = (players) => {
  els.boardCount.textContent =
    players.length === 0
      ? 'No players available.'
      : `${players.length} players in the live board`

  if (players.length === 0) {
    els.leaderboardBody.innerHTML = `
      <tr>
        <td colspan='5'>
          <div class='empty-state'>No players are available in the live board.</div>
        </td>
      </tr>
    `
    return
  }

  els.leaderboardBody.innerHTML = players
    .map((player) => {
      const summary = getSummary(player, state.pair)
      const selectedClass = player.contractRowId === state.selectedId ? 'is-selected' : ''

      return `
        <tr class='${selectedClass}' data-player-id='${player.contractRowId}'>
          <td>
            <div class='leader-player'>
              <strong>${escapeHtml(player.playerName)}</strong>
              <span>${escapeHtml(player.prevSignedTeam || 'Unknown team')}</span>
            </div>
          </td>
          <td>${escapeHtml(player.prevSignedTeam || '—')}</td>
          <td>${escapeHtml(formatMoney(summary.expectedAavMillions))}</td>
          <td><span class='term-cell'>${termPill(summary.modalTerm)} <span>${escapeHtml(termLabel(summary.modalTerm))}</span></span></td>
          <td>${escapeHtml(formatShare(summary.prob1, 1))}</td>
        </tr>
      `
    })
    .join('')

  els.leaderboardBody.querySelectorAll('tr[data-player-id]').forEach((row) => {
    row.addEventListener('click', () => {
      state.selectedId = Number(row.dataset.playerId)
      state.activePanel = 'player'
      render()
    })
  })
}

const renderPlayerSelect = (players) => {
  if (players.length === 0) {
    els.playerSelect.innerHTML = ''
    els.playerSelect.disabled = true
    return
  }

  els.playerSelect.disabled = false
  els.playerSelect.innerHTML = players
    .map((player) => {
      return `
        <option value='${player.contractRowId}' ${player.contractRowId === state.selectedId ? 'selected' : ''}>
          ${escapeHtml(`${player.playerName} • ${player.prevSignedTeam || 'N/A'}`)}
        </option>
      `
    })
    .join('')
}

const renderPlayerHeader = (player) => {
  if (!player) {
    els.playerName.textContent = 'No player available'
    els.playerSubtitle.textContent = 'The board did not return an active player.'
    els.playerMiniGrid.innerHTML = `<div class='empty-state'>No player selected.</div>`
    els.playerSummaryGrid.innerHTML = `<div class='empty-state'>No player selected.</div>`
    return
  }

  const priorAav = player.context.prevContractAavMillions

  els.playerName.textContent = player.playerName
  els.playerSubtitle.textContent = [
    player.prevSignedTeam || 'Unknown previous team',
    player.ageAtSigning != null ? `Age ${formatInteger(player.ageAtSigning)}` : null,
    player.yearsExpAtSigning != null ? `${formatInteger(player.yearsExpAtSigning)} seasons of experience` : null,
  ]
    .filter(Boolean)
    .join(' • ')

  const contractTiles = nonNullTiles([
    {
      label: 'Previous contract AAV',
      value: formatMoney(priorAav),
      sub: 'Last veteran deal anchor',
    },
    {
      label: 'Previous contract term',
      value: player.context.prevContractTerm != null ? `${termLabel(player.context.prevContractTerm)} yrs` : null,
      sub: 'Length of the last veteran deal',
    },
    {
      label: 'Previous contract AAV%',
      value: player.context.prevContractAavPerc != null ? formatShare(player.context.prevContractAavPerc, 2) : null,
      sub: 'Last veteran deal as cap share',
    },
    {
      label: 'Vs WR market',
      value: player.context.prevVsMarketAavPerc != null ? formatSignedPoints(player.context.prevVsMarketAavPerc, 2) : null,
      sub: 'Previous deal minus veteran WR median',
    },
  ])

  const metricTiles = nonNullTiles([
    {
      label: 'WR market median',
      value: player.context.marketPrev1MedianAavPerc != null ? formatShare(player.context.marketPrev1MedianAavPerc, 2) : null,
      sub: 'Prior-year veteran WR market median',
    },
    {
      label: 'Snap share',
      value: player.context.snapWeightedOffensePctMean != null ? formatShare(player.context.snapWeightedOffensePctMean, 1) : null,
      sub: 'Weighted offensive snap rate',
    },
    {
      label: 'Weighted targets',
      value: player.context.regWeightedTargets != null ? formatNumber(player.context.regWeightedTargets, 1) : null,
      sub: 'Two-season weighted opportunity',
    },
    {
      label: 'Weighted receptions',
      value: player.context.regWeightedReceptions != null ? formatNumber(player.context.regWeightedReceptions, 1) : null,
      sub: 'Two-season weighted catch volume',
    },
    {
      label: 'Weighted yards',
      value: player.context.regWeightedReceivingYards != null ? formatNumber(player.context.regWeightedReceivingYards, 1) : null,
      sub: 'Two-season weighted receiving output',
    },
    {
      label: 'Weighted TDs',
      value: player.context.regWeightedReceivingTds != null ? formatNumber(player.context.regWeightedReceivingTds, 2) : null,
      sub: 'Two-season weighted receiving touchdowns',
    },
    {
      label: 'Target share',
      value: player.context.regWeightedTargetShare != null ? formatShare(player.context.regWeightedTargetShare, 1) : null,
      sub: 'Share of team passing workload',
    },
    {
      label: 'NGS yards/target',
      value: player.context.ngsWeightedYardsPerTarget != null ? formatNumber(player.context.ngsWeightedYardsPerTarget, 2) : null,
      sub: 'Next Gen receiving efficiency',
    },
  ])

  els.playerMiniGrid.innerHTML =
    contractTiles.length === 0
      ? `<div class='empty-state'>No prior contract context is available.</div>`
      : contractTiles.map((tile) => metricTileHtml(tile)).join('')

  els.playerSummaryGrid.innerHTML =
    metricTiles.length === 0
      ? `<div class='empty-state'>No matched player performance context is available.</div>`
      : metricTiles.slice(0, 4).map((tile) => metricTileHtml(tile)).join('')
}

const renderScenarioTable = (player) => {
  if (!player) {
    els.scenarioBody.innerHTML = `
      <tr><td colspan='4'><div class='empty-state'>No scenario table available.</div></td></tr>
    `
    return
  }

  const scenarios = getScenarios(player, state.pair)

  els.scenarioBody.innerHTML = scenarios
    .map(
      (row) => `
        <tr>
          <td>${termPill(row.termScenario)}</td>
          <td>${escapeHtml(formatShare(row.termProbability, 1))}</td>
          <td>${escapeHtml(formatShare(row.aavPercPrediction, 2))}</td>
          <td>${escapeHtml(formatMoney(row.aavPredictionMillions))}</td>
        </tr>
      `
    )
    .join('')
}

const renderMethod = (players) => {
  const methodData = appData.method?.[state.pair]

  if (!methodData) {
    els.methodCopy.innerHTML = `<div class='empty-state'>No model metadata is available.</div>`
    return
  }

  const renderRows = (rows, columns, formatters = {}) =>
    rows
      .map(
        (row) => `
          <tr>
            ${columns
              .map((column) => {
                const formatter = formatters[column]
                const value = formatter ? formatter(row[column], row) : row[column]
                return `<td>${escapeHtml(value)}</td>`
              })
              .join('')}
          </tr>
        `
      )
      .join('')

  const renderModelBlock = (model, heading, detail) => {
    const metricsRows = Object.entries(model.heldoutMetrics || {}).map(([metric, value]) => ({
      metric: methodMetricLabel(metric),
      value: ['accuracy', 'rocAuc', 'rsq'].includes(metric) ? formatMethodValue(value, 3) : formatMethodValue(value, 6),
    }))

    const paramRows = Object.entries(model.hyperparameters || {}).map(([parameter, value]) => ({
      parameter: methodParamLabel(parameter),
      value: formatMethodValue(value, 6),
    }))

    const featureRows = model.topFeatures || []
    const hasClassColumn = featureRows.some((row) => Object.prototype.hasOwnProperty.call(row, 'class'))
    const hasGainColumn = featureRows.some((row) => Object.prototype.hasOwnProperty.call(row, 'gain'))
    const hasAbsValueColumn = featureRows.some((row) => Object.prototype.hasOwnProperty.call(row, 'absValue'))

    const featureColumns = hasClassColumn
      ? ['class', 'feature', 'coefficient']
      : hasGainColumn
        ? ['feature', 'gain', 'cover', 'frequency']
        : hasAbsValueColumn
          ? ['feature', 'coefficient', 'absValue']
          : ['feature', 'coefficient']

    const featureFormatters = {
      class: (value) => (Number(value) === 5 ? '5+' : String(value)),
      coefficient: (value) => formatMethodValue(value, 6),
      gain: (value) => formatMethodValue(value, 6),
      cover: (value) => formatMethodValue(value, 6),
      frequency: (value) => formatMethodValue(value, 6),
      absValue: (value) => formatMethodValue(value, 6),
    }

    const sparsityRows = model.classSparsity || []

    return `
      <article class='method-block'>
        <div class='method-block-header'>
          <div>
            <p class='method-block-kicker'>${escapeHtml(heading)}</p>
            <h3>${escapeHtml(model.title)}</h3>
          </div>
          <div class='method-chip-row'>
            <span class='method-chip'>${escapeHtml(model.engine)}</span>
            <span class='method-chip'>${escapeHtml(model.tuningMethod)}</span>
          </div>
        </div>
        <p>${escapeHtml(detail)}</p>
        <p style='margin-top: 12px;'>${escapeHtml(model.description)}</p>
        <div class='method-metrics'>
          <p class='method-subheading'>Held-out validation</p>
          <table class='method-table'>
            <thead>
              <tr><th>Metric</th><th>Value</th></tr>
            </thead>
            <tbody>${renderRows(metricsRows, ['metric', 'value'])}</tbody>
          </table>
        </div>
        <div class='method-params'>
          <p class='method-subheading'>Selected hyperparameters</p>
          <table class='method-table'>
            <thead>
              <tr><th>Parameter</th><th>Value</th></tr>
            </thead>
            <tbody>${renderRows(paramRows, ['parameter', 'value'])}</tbody>
          </table>
        </div>
        ${
          sparsityRows.length > 0
            ? `
              <div class='method-params'>
                <p class='method-subheading'>Class sparsity</p>
                <table class='method-table'>
                  <thead>
                    <tr><th>Class</th><th>Non-zero coefficients</th></tr>
                  </thead>
                  <tbody>${renderRows(sparsityRows, ['class', 'nonZeroCoefficients'], {
                    class: (value) => (Number(value) === 5 ? '5+' : String(value)),
                  })}</tbody>
                </table>
              </div>
            `
            : ''
        }
        <div class='method-features'>
          <p class='method-subheading'>Most influential features</p>
          <table class='method-table'>
            <thead>
              <tr>${featureColumns.map((column) => `<th>${escapeHtml(methodTableLabel(column))}</th>`).join('')}</tr>
            </thead>
            <tbody>${renderRows(featureRows, featureColumns, featureFormatters)}</tbody>
          </table>
        </div>
        ${model.plotPath ? `<img class='method-plot' src='${escapeHtml(model.plotPath)}' alt='${escapeHtml(model.title)} plot'>` : ''}
      </article>
    `
  }

  els.methodCopy.innerHTML = [
    renderModelBlock(
      methodData.models.term,
      'Term model',
      `${pairMeta[state.pair].label} term model. ${players.length} unsigned WRs are being scored in the live board, and the target remains the bucketed term outcome.`
    ),
    renderModelBlock(
      methodData.models.aavPerc,
      'AAV% model',
      `${pairMeta[state.pair].label} conditional price model. It is always interpreted as AAV% given a supplied term scenario, which is why the player view centers the pricing path rather than a single point estimate.`
    ),
  ].join('')
}

const plotLayoutBase = {
  paper_bgcolor: 'rgba(0,0,0,0)',
  plot_bgcolor: 'rgba(255,255,255,0.55)',
  margin: { t: 24, r: 24, b: 54, l: 60 },
  font: {
    family: 'Space Grotesk, sans-serif',
    color: '#203127',
    size: 14,
  },
  xaxis: {
    gridcolor: 'rgba(32,49,39,0.08)',
    zerolinecolor: 'rgba(32,49,39,0.08)',
    linecolor: 'rgba(32,49,39,0.12)',
    tickfont: { size: 13 },
  },
  yaxis: {
    gridcolor: 'rgba(32,49,39,0.08)',
    zerolinecolor: 'rgba(32,49,39,0.08)',
    linecolor: 'rgba(32,49,39,0.12)',
    tickfont: { size: 13 },
  },
}

const renderMarketChart = (players) => {
  if (players.length === 0) {
    els.marketChart.innerHTML = `<div class='empty-state'>No chartable players after filters.</div>`
    return
  }

  const selectedPlayerId = state.selectedId
  const selectedPlayers = players.filter((player) => player.contractRowId === selectedPlayerId)
  const selectedSummaries = selectedPlayers.map((player) => getSummary(player, state.pair))
  const boardPlayers = players.filter((player) => player.contractRowId !== selectedPlayerId)
  const boardSummaries = boardPlayers.map((player) => getSummary(player, state.pair))

  const boardTrace = {
    type: 'scatter',
    mode: 'markers',
    x: boardSummaries.map((summary) => summary.prob1),
    y: boardSummaries.map((summary) => summary.expectedAavMillions),
    customdata: boardPlayers.map((player) => player.contractRowId),
    text: boardPlayers.map(
      (player, idx) =>
        `${player.playerName}<br>${player.prevSignedTeam || 'Unknown team'}<br>1-year probability: ${formatShare(boardSummaries[idx].prob1, 1)}<br>Expected AAV: ${formatMoney(boardSummaries[idx].expectedAavMillions)}<br>Likeliest term: ${termLabel(boardSummaries[idx].modalTerm)}`
    ),
    hovertemplate: '%{text}<extra></extra>',
    marker: {
      size: boardSummaries.map((summary) => 12 + (summary.modalTermProb || 0) * 30),
      color: boardSummaries.map((summary) => termColors[summary.modalTerm] || '#376996'),
      opacity: 0.82,
      line: {
        color: 'rgba(255,255,255,0.76)',
        width: 1.2,
      },
    },
  }

  const selectedTrace =
    selectedPlayers.length === 0
      ? null
      : {
          type: 'scatter',
          mode: 'markers',
          x: selectedSummaries.map((summary) => summary.prob1),
          y: selectedSummaries.map((summary) => summary.expectedAavMillions),
          customdata: selectedPlayers.map((player) => player.contractRowId),
          text: selectedPlayers.map(
            (player, idx) =>
              `${player.playerName}<br>${player.prevSignedTeam || 'Unknown team'}<br>1-year probability: ${formatShare(selectedSummaries[idx].prob1, 1)}<br>Expected AAV: ${formatMoney(selectedSummaries[idx].expectedAavMillions)}`
          ),
          hovertemplate: '%{text}<extra></extra>',
          marker: {
            size: selectedSummaries.map((summary) => 16 + (summary.modalTermProb || 0) * 34),
            color: selectedSummaries.map((summary) => termColors[summary.modalTerm] || '#376996'),
            opacity: 1,
            line: {
              color: '#15261d',
              width: 3,
            },
          },
        }

  const layout = {
    ...plotLayoutBase,
    showlegend: false,
    margin: { t: 24, r: 24, b: 66, l: 72 },
    xaxis: {
      ...plotLayoutBase.xaxis,
      title: '1-year probability',
      tickformat: ',.0%',
      range: [0.5, 1],
    },
    yaxis: {
      ...plotLayoutBase.yaxis,
      title: 'Expected AAV (millions)',
    },
  }

  Plotly.react(els.marketChart, selectedTrace ? [boardTrace, selectedTrace] : [boardTrace], layout, {
    displayModeBar: false,
    responsive: true,
  })

  if (!els.marketChart.dataset.bound) {
    els.marketChart.on('plotly_click', (event) => {
      const contractId = Number(event.points?.[0]?.customdata)
      if (Number.isFinite(contractId)) {
        state.selectedId = contractId
        state.activePanel = 'player'
        render()
      }
    })
    els.marketChart.dataset.bound = 'true'
  }
}

const renderScenarioChart = (player) => {
  if (!player) {
    els.scenarioChart.innerHTML = `<div class='empty-state'>No scenario chart available.</div>`
    return
  }

  const scenarios = getScenarios(player, state.pair)

  Plotly.react(
    els.scenarioChart,
    [
      {
        type: 'scatter',
        mode: 'lines+markers',
        x: scenarios.map((row) => termLabel(row.termScenario)),
        y: scenarios.map((row) => row.aavPredictionMillions),
        text: scenarios.map(
          (row) =>
            `${termLabel(row.termScenario)} years<br>${formatMoney(row.aavPredictionMillions)}<br>${formatShare(row.aavPercPrediction, 2)} of cap<br>Term probability ${formatShare(row.termProbability, 1)}`
        ),
        hovertemplate: '%{text}<extra></extra>',
        marker: {
          size: scenarios.map((row) => 14 + row.termProbability * 24),
          color: scenarios.map((row) => termColors[row.termScenario] || '#376996'),
          line: {
            color: '#ffffff',
            width: 1.5,
          },
        },
        line: {
          color: '#203127',
          width: 3,
          shape: 'spline',
          smoothing: 0.8,
        },
      },
    ],
    {
      ...plotLayoutBase,
      margin: { t: 20, r: 20, b: 58, l: 72 },
      xaxis: {
        ...plotLayoutBase.xaxis,
        title: 'Term scenario',
      },
      yaxis: {
        ...plotLayoutBase.yaxis,
        title: 'Predicted AAV (millions)',
      },
    },
    {
      displayModeBar: false,
      responsive: true,
    }
  )
}

const render = () => {
  const players = filteredPlayers()
  const player = selectedPlayer(players)

  renderHeroStats(players)
  renderLeaderboard(players)
  renderPlayerSelect(players)
  renderPlayerHeader(player)
  renderScenarioTable(player)
  renderMethod(players)
  renderMarketChart(players)
  renderScenarioChart(player)

  els.pageTabs.forEach((button) => {
    button.classList.toggle('is-active', button.dataset.panel === state.activePanel)
  })

  els.panelCards.forEach((card) => {
    card.classList.toggle('is-hidden', card.dataset.panel !== state.activePanel)
  })
}

const bindControls = () => {
  els.pairToggle.querySelectorAll('.pair-button').forEach((button) => {
    button.addEventListener('click', () => {
      state.pair = button.dataset.pair
      els.pairToggle.querySelectorAll('.pair-button').forEach((item) => {
        item.classList.toggle('is-active', item.dataset.pair === state.pair)
      })
      render()
    })
  })

  els.playerSelect.addEventListener('change', (event) => {
    state.selectedId = Number(event.target.value)
    state.activePanel = 'player'
    render()
  })

  els.pageTabs.forEach((button) => {
    button.addEventListener('click', () => {
      state.activePanel = button.dataset.panel
      render()
    })
  })
}

const bootstrap = async () => {
  const response = await fetch('./final/app_data.json', { cache: 'no-store' })
  appData = await response.json()
  bindControls()
  render()
}

bootstrap().catch((error) => {
  console.error(error)
  document.body.innerHTML = `
    <div class='page-shell'>
      <div class='empty-state'>
        Failed to load the frontend data payload. Check final/app_data.json and refresh the page.
      </div>
    </div>
  `
})
