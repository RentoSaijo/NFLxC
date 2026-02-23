#!/usr/bin/env Rscript

required_pkgs <- c("dplyr", "janitor", "purrr", "readr", "stringr", "tidyr", "nflreadr")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkgs) > 0) {
  stop(
    paste0(
      "Missing CRAN package(s): ",
      paste(missing_pkgs, collapse = ", "),
      ". Install them first with install.packages(c(",
      paste(sprintf('\"%s\"', missing_pkgs), collapse = ", "),
      "))."
    ),
    call. = FALSE
  )
}

suppressPackageStartupMessages({
  library(dplyr)
  library(janitor)
  library(purrr)
  library(readr)
  library(stringr)
  library(tidyr)
  library(nflreadr)
})

options(readr.show_col_types = FALSE)

contracts_path <- "data/contracts.csv"
output_dir <- "data"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

normalize_player_name <- function(x) {
  x |>
    str_replace_all("[*+]", "") |>
    str_replace_all("[[:punct:]]", " ") |>
    str_replace_all("\\b(jr|sr|ii|iii|iv|v)\\b", " ") |>
    str_squish() |>
    str_to_lower()
}

parse_numeric_any <- function(x) {
  if (is.numeric(x)) {
    return(as.numeric(x))
  }
  parse_number(as.character(x), na = c("", "NA", "NULL"))
}

pick_col <- function(df, candidates, default = NA_character_) {
  hit <- candidates[candidates %in% names(df)]
  if (length(hit) == 0L) {
    return(rep(default, nrow(df)))
  }
  df[[hit[1L]]]
}

collapse_unique_chr <- function(x) {
  x <- as.character(x)
  vals <- unique(x[!is.na(x) & x != ""])
  if (length(vals) == 0L) NA_character_ else paste(vals, collapse = "/")
}

first_non_missing_chr <- function(x) {
  x <- as.character(x)
  vals <- x[!is.na(x) & x != ""]
  if (length(vals) == 0L) NA_character_ else vals[1L]
}

sum_or_na <- function(x) {
  x <- as.numeric(x)
  if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE)
}

add_ratio <- function(df, numerator, denominator, out_name) {
  if (!all(c(numerator, denominator) %in% names(df))) {
    return(df)
  }

  df[[out_name]] <- ifelse(
    !is.na(df[[denominator]]) & df[[denominator]] > 0,
    df[[numerator]] / df[[denominator]],
    NA_real_
  )
  df
}

safe_fetch <- function(fetch_fun, label) {
  tryCatch(
    fetch_fun(),
    error = function(e) {
      message(sprintf("Failed to pull %s: %s", label, e$message))
      tibble()
    }
  )
}

standardize_team <- function(x) {
  nflreadr::clean_team_abbrs(str_squish(as.character(x)))
}

prepare_wr_contracts <- function(path) {
  raw <- read_csv(path, col_types = cols(.default = col_character())) |>
    clean_names()

  raw |>
    transmute(
      contract_row = row_number(),
      player = str_squish(player),
      player_key = normalize_player_name(player),
      pos = str_squish(pos),
      signed_team_raw = str_squish(team_signed_with),
      signed_team = str_extract(signed_team_raw, "([A-Z]{2,3})$"),
      age_at_signing = parse_numeric_any(age_at_signing),
      start_year = as.integer(parse_numeric_any(start_year)),
      end_year_raw = as.integer(parse_numeric_any(end_year)),
      yrs = parse_numeric_any(yrs),
      value = parse_numeric_any(value),
      average_salary = parse_numeric_any(average_salary),
      average_of_cap_at_sign = parse_numeric_any(average_of_cap_at_sign) / 100
    ) |>
    mutate(
      signed_team = standardize_team(signed_team),
      expected_end_year = if_else(
        !is.na(start_year) & !is.na(yrs),
        start_year + as.integer(round(yrs)) - 1L,
        NA_integer_
      ),
      end_year = case_when(
        is.na(end_year_raw) ~ expected_end_year,
        !is.na(expected_end_year) &
          (end_year_raw < start_year | end_year_raw > start_year + 10L) ~ expected_end_year,
        TRUE ~ end_year_raw
      ),
      end_year_was_fixed = !is.na(end_year_raw) & !is.na(end_year) & end_year != end_year_raw
    ) |>
    filter(pos == "WR")
}

build_regular_wr_stats <- function(seasons, wr_player_keys) {
  raw <- safe_fetch(
    function() nflreadr::load_player_stats(seasons = seasons, summary_level = "reg"),
    "nflreadr::load_player_stats"
  )

  if (nrow(raw) == 0) {
    return(tibble(
      season = integer(),
      player = character(),
      player_key = character(),
      team = character(),
      pos = character()
    ))
  }

  dat <- raw
  dat$season <- as.integer(pick_col(dat, c("season"), NA_integer_))
  dat$player <- str_squish(as.character(pick_col(dat, c("player_display_name", "player_name", "player"), "")))
  dat$player_key <- normalize_player_name(dat$player)
  dat$team <- standardize_team(pick_col(dat, c("recent_team", "team_abbr", "team"), NA_character_))
  dat$pos <- toupper(str_squish(as.character(pick_col(dat, c("position", "pos"), NA_character_))))

  metric_candidates <- c(
    "games",
    "targets",
    "receptions",
    "receiving_yards",
    "receiving_tds",
    "receiving_fumbles",
    "receiving_first_downs",
    "receiving_air_yards",
    "receiving_yards_after_catch",
    "receiving_epa"
  )
  metric_cols <- intersect(metric_candidates, names(dat))

  for (nm in metric_cols) {
    dat[[nm]] <- parse_numeric_any(dat[[nm]])
  }

  dat <- dat |>
    filter(
      !is.na(season),
      !is.na(player_key),
      player_key != "",
      is.na(pos) | pos == "WR" | player_key %in% wr_player_keys
    )

  dat |>
    group_by(season, player_key) |>
    summarise(
      player = first_non_missing_chr(player),
      team = collapse_unique_chr(team),
      pos = first_non_missing_chr(pos),
      across(all_of(metric_cols), sum_or_na, .names = "reg_{.col}"),
      .groups = "drop"
    ) |>
    semi_join(tibble(player_key = wr_player_keys), by = "player_key") |>
    add_ratio("reg_receptions", "reg_targets", "reg_catch_rate") |>
    add_ratio("reg_receiving_yards", "reg_targets", "reg_yards_per_target") |>
    add_ratio("reg_receiving_yards", "reg_receptions", "reg_yards_per_reception") |>
    add_ratio("reg_receiving_tds", "reg_targets", "reg_td_per_target") |>
    add_ratio("reg_receiving_air_yards", "reg_targets", "reg_air_yards_per_target") |>
    add_ratio("reg_receiving_yards_after_catch", "reg_receptions", "reg_yac_per_reception")
}

build_advanced_wr_stats <- function(seasons, wr_player_keys) {
  raw <- safe_fetch(
    function() nflreadr::load_nextgen_stats(stat_type = "receiving", seasons = seasons),
    "nflreadr::load_nextgen_stats(receiving)"
  )

  if (nrow(raw) == 0) {
    return(tibble(
      season = integer(),
      player = character(),
      player_key = character(),
      team = character(),
      pos = character()
    ))
  }

  dat <- raw
  dat$season <- as.integer(pick_col(dat, c("season"), NA_integer_))
  dat$week <- as.integer(parse_numeric_any(pick_col(dat, c("week"), NA_integer_)))
  dat$season_type <- toupper(str_squish(as.character(pick_col(dat, c("season_type"), NA_character_))))
  dat$player <- str_squish(as.character(pick_col(dat, c("player_display_name", "player"), "")))
  dat$player_key <- normalize_player_name(dat$player)
  dat$team <- standardize_team(pick_col(dat, c("team_abbr", "team"), NA_character_))
  dat$pos <- toupper(str_squish(as.character(pick_col(dat, c("player_position", "position", "pos"), NA_character_))))

  sum_candidates <- c("targets", "receptions", "yards", "rec_touchdowns", "yards_after_catch")
  avg_candidates <- c(
    "catch_percentage",
    "avg_cushion",
    "avg_separation",
    "avg_intended_air_yards",
    "avg_air_distance",
    "max_air_distance",
    "avg_yac",
    "avg_expected_yac",
    "avg_yac_above_expectation",
    "avg_air_yards_to_sticks",
    "percent_share_of_intended_air_yards",
    "efficiency"
  )

  sum_cols <- intersect(sum_candidates, names(dat))
  avg_cols <- intersect(avg_candidates, names(dat))

  for (nm in c(sum_cols, avg_cols)) {
    dat[[nm]] <- parse_numeric_any(dat[[nm]])
  }

  dat <- dat |>
    filter(
      !is.na(season),
      !is.na(player_key),
      player_key != "",
      is.na(week) | week == 0L,
      is.na(season_type) | season_type == "REG",
      is.na(pos) | pos == "WR" | player_key %in% wr_player_keys
    )

  dat |>
    group_by(season, player_key) |>
    summarise(
      player = first_non_missing_chr(player),
      team = collapse_unique_chr(team),
      pos = first_non_missing_chr(pos),
      across(all_of(sum_cols), sum_or_na, .names = "adv_{.col}"),
      across(
        all_of(avg_cols),
        ~ {
          x <- as.numeric(.x)
          if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
        },
        .names = "adv_{.col}"
      ),
      .groups = "drop"
    ) |>
    semi_join(tibble(player_key = wr_player_keys), by = "player_key") |>
    add_ratio("adv_yards", "adv_targets", "adv_yards_per_target") |>
    add_ratio("adv_yards", "adv_receptions", "adv_yards_per_reception") |>
    add_ratio("adv_rec_touchdowns", "adv_targets", "adv_td_per_target")
}

build_team_context <- function(seasons) {
  raw <- safe_fetch(
    function() nflreadr::load_team_stats(seasons = seasons, summary_level = "reg"),
    "nflreadr::load_team_stats"
  )

  if (nrow(raw) == 0) {
    return(list(
      team = tibble(season = integer(), team = character()),
      league = tibble(season = integer())
    ))
  }

  dat <- raw
  dat$season <- as.integer(pick_col(dat, c("season"), NA_integer_))
  dat$team <- standardize_team(pick_col(dat, c("team", "team_abbr"), NA_character_))

  metric_candidates <- c(
    "points",
    "points_against",
    "yards",
    "first_downs",
    "plays",
    "passing_yards",
    "passing_tds",
    "passing_epa",
    "rushing_yards",
    "rushing_tds",
    "rushing_epa"
  )
  metric_cols <- intersect(metric_candidates, names(dat))

  if (length(metric_cols) == 0L) {
    metric_cols <- grep("passing_|rushing_|epa|points|yards", names(dat), value = TRUE)
    metric_cols <- setdiff(metric_cols, c("team", "season"))
  }

  for (nm in metric_cols) {
    dat[[nm]] <- parse_numeric_any(dat[[nm]])
  }

  team_context <- dat |>
    filter(!is.na(season), !is.na(team), team != "") |>
    distinct(season, team, .keep_all = TRUE) |>
    select(season, team, all_of(metric_cols)) |>
    rename_with(~ paste0("team_", .x), all_of(metric_cols))

  league_context <- team_context |>
    group_by(season) |>
    summarise(
      across(
        starts_with("team_"),
        ~ {
          x <- as.numeric(.x)
          if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
        },
        .names = "league_avg_{.col}"
      ),
      .groups = "drop"
    )

  list(team = team_context, league = league_context)
}

combine_player_season <- function(regular_stats, advanced_stats) {
  empty <- tibble(
    season = integer(),
    player = character(),
    player_key = character(),
    team = character(),
    pos = character()
  )

  if (nrow(regular_stats) == 0) regular_stats <- empty
  if (nrow(advanced_stats) == 0) advanced_stats <- empty

  full_join(
    regular_stats,
    advanced_stats,
    by = c("season", "player_key"),
    suffix = c("_reg", "_adv")
  ) |>
    mutate(
      player = coalesce(player_reg, player_adv),
      team = coalesce(team_reg, team_adv),
      pos = coalesce(pos_reg, pos_adv)
    ) |>
    select(
      season, player, player_key, team, pos, everything(),
      -any_of(c("player_reg", "player_adv", "team_reg", "team_adv", "pos_reg", "pos_adv"))
    ) |>
    arrange(season, player)
}

wr_contracts <- prepare_wr_contracts(contracts_path)
write_csv(wr_contracts, file.path(output_dir, "contracts_wr_clean.csv"))

seasons_to_pull <- seq.int(
  from = min(wr_contracts$start_year, na.rm = TRUE) - 1L,
  to = max(wr_contracts$start_year, na.rm = TRUE) - 1L
)
ngs_seasons <- seasons_to_pull[seasons_to_pull >= 2016L]

wr_player_keys <- wr_contracts |>
  distinct(player_key) |>
  pull(player_key)

message(sprintf("Contract rows (WR): %d", nrow(wr_contracts)))
message(sprintf("Pulling regular stats for seasons %d-%d.", min(seasons_to_pull), max(seasons_to_pull)))
regular_stats <- build_regular_wr_stats(seasons_to_pull, wr_player_keys)

if (length(ngs_seasons) > 0L) {
  message(sprintf("Pulling Next Gen receiving stats for seasons %d-%d.", min(ngs_seasons), max(ngs_seasons)))
  advanced_stats <- build_advanced_wr_stats(ngs_seasons, wr_player_keys)
} else {
  message("No seasons available for Next Gen receiving stats.")
  advanced_stats <- tibble(
    season = integer(),
    player = character(),
    player_key = character(),
    team = character(),
    pos = character()
  )
}

message("Pulling team-level offensive context.")
team_context <- build_team_context(seasons_to_pull)

write_csv(regular_stats, file.path(output_dir, "wr_regular_stats_nflverse.csv"))
write_csv(advanced_stats, file.path(output_dir, "wr_advanced_stats_ngs.csv"))
write_csv(team_context$team, file.path(output_dir, "team_offense_context_nflverse.csv"))
write_csv(team_context$league, file.path(output_dir, "league_offense_context_nflverse.csv"))

wr_player_season <- combine_player_season(regular_stats, advanced_stats)
write_csv(wr_player_season, file.path(output_dir, "wr_player_season_stats_nflverse.csv"))

wr_player_season_for_join <- wr_player_season |>
  rename(
    stat_player = player,
    stat_team = team,
    stat_pos = pos
  )

wr_contract_model_base <- wr_contracts |>
  mutate(stat_season = start_year - 1L) |>
  left_join(
    wr_player_season_for_join,
    by = c("player_key", "stat_season" = "season")
  ) |>
  left_join(
    team_context$team,
    by = c("stat_season" = "season", "signed_team" = "team")
  ) |>
  left_join(
    team_context$league,
    by = c("stat_season" = "season")
  )

write_csv(
  wr_contract_model_base,
  file.path(output_dir, "wr_contracts_with_prior_season_stats_nflverse.csv")
)

player_stat_cols <- grep("^(reg_|adv_)", names(wr_contract_model_base), value = TRUE)
team_stat_cols <- grep("^team_", names(wr_contract_model_base), value = TRUE)

has_player_stats <- if (length(player_stat_cols) > 0) {
  rowSums(!is.na(wr_contract_model_base[, player_stat_cols, drop = FALSE])) > 0
} else {
  rep(FALSE, nrow(wr_contract_model_base))
}

has_team_stats <- if (length(team_stat_cols) > 0) {
  rowSums(!is.na(wr_contract_model_base[, team_stat_cols, drop = FALSE])) > 0
} else {
  rep(FALSE, nrow(wr_contract_model_base))
}

message("")
message("NFLverse pipeline complete.")
message(sprintf("Regular player-season rows: %d", nrow(regular_stats)))
message(sprintf("Advanced player-season rows: %d", nrow(advanced_stats)))
message(sprintf("Combined player-season rows: %d", nrow(wr_player_season)))
message(sprintf(
  "Contracts with >=1 player stat: %d (%.1f%%)",
  sum(has_player_stats),
  100 * mean(has_player_stats)
))
message(sprintf(
  "Contracts with >=1 team context stat: %d (%.1f%%)",
  sum(has_team_stats),
  100 * mean(has_team_stats)
))
message("Output files written to data/:")
message("- contracts_wr_clean.csv")
message("- wr_regular_stats_nflverse.csv")
message("- wr_advanced_stats_ngs.csv")
message("- team_offense_context_nflverse.csv")
message("- league_offense_context_nflverse.csv")
message("- wr_player_season_stats_nflverse.csv")
message("- wr_contracts_with_prior_season_stats_nflverse.csv")
