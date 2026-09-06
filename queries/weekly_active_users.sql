WITH params AS (
  SELECT
    DATE '2026-06-15' AS as_of_date
),

date_limits AS (
  SELECT
    DATE_TRUNC(
      'week',
      params.as_of_date
    )::date AS current_week_start,

    -- Twelve completed weeks displayed
    (
      DATE_TRUNC('week', params.as_of_date)
      - INTERVAL '12 weeks'
    )::date AS display_start,

    -- Four additional weeks for comparison calculations
    (
      DATE_TRUNC('week', params.as_of_date)
      - INTERVAL '16 weeks'
    )::date AS calculation_start

  FROM params
),

/*
  Select the eligible user population.

  Variable names correspond to actual columns in saas.users.
  The table is intentionally not aliased to simplify Metabase
  Field Filter configuration.
*/
selected_users AS (
  SELECT DISTINCT
    users.user_id

  FROM saas.users

  WHERE 1 = 1

    -- Maps to saas.users.signup_date
    [[AND {{signup_date}}]]

    -- Maps to saas.users.plan_type
    [[AND {{plan_type}}]]

    -- Maps to saas.users.signup_source
    [[AND {{signup_source}}]]

    -- Maps to saas.users.role
    [[AND {{role}}]]
),

/*
  Generate every completed calendar week.

  This ensures that weeks with zero activity remain in the
  time series instead of disappearing.
*/
weeks AS (
  SELECT
    GENERATE_SERIES(
      date_limits.calculation_start,
      date_limits.current_week_start - INTERVAL '1 week',
      INTERVAL '1 week'
    )::date AS active_week

  FROM date_limits
),

weekly_activity AS (
  SELECT
    DATE_TRUNC(
      'week',
      events.occurred_at
    )::date AS active_week,

    COUNT(DISTINCT events.user_id) AS wau

  FROM saas.events

  JOIN selected_users
    ON selected_users.user_id = events.user_id

  CROSS JOIN date_limits

  WHERE events.occurred_at >= date_limits.calculation_start
    AND events.occurred_at < date_limits.current_week_start

    -- WAU requires at least one meaningful product event
    AND LOWER(TRIM(events.event_type)) = 'feature_use'

  GROUP BY
    DATE_TRUNC('week', events.occurred_at)::date
),

weekly_series AS (
  SELECT
    weeks.active_week,

    COALESCE(
      weekly_activity.wau,
      0
    ) AS wau

  FROM weeks

  LEFT JOIN weekly_activity
    ON weekly_activity.active_week = weeks.active_week
),

with_comparisons AS (
  SELECT
    weekly_series.active_week,
    weekly_series.wau,

    LAG(weekly_series.wau) OVER (
      ORDER BY weekly_series.active_week
    ) AS previous_week_wau,

    AVG(weekly_series.wau) OVER (
      ORDER BY weekly_series.active_week
      ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING
    ) AS previous_4_week_avg

  FROM weekly_series
),

final_metrics AS (
  SELECT
    with_comparisons.active_week,
    with_comparisons.wau,
    with_comparisons.previous_week_wau,

    ROUND(
      (
        with_comparisons.wau
        - with_comparisons.previous_week_wau
      )::numeric
      /
      NULLIF(
        with_comparisons.previous_week_wau,
        0
      ),
      4
    ) AS wow_change,

    ROUND(
      with_comparisons.previous_4_week_avg,
      1
    ) AS previous_4_week_avg,

    ROUND(
      (
        with_comparisons.wau
        - with_comparisons.previous_4_week_avg
      )::numeric
      /
      NULLIF(
        with_comparisons.previous_4_week_avg,
        0
      ),
      4
    ) AS change_vs_4_week_avg

  FROM with_comparisons

  CROSS JOIN date_limits

  WHERE with_comparisons.active_week
        >= date_limits.display_start
)

SELECT
  final_metrics.active_week,
  final_metrics.wau,
  final_metrics.previous_week_wau,
  final_metrics.wow_change,
  final_metrics.previous_4_week_avg,
  final_metrics.change_vs_4_week_avg

FROM final_metrics

ORDER BY final_metrics.active_week DESC;
