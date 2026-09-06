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

    -- Four additional weeks for the comparison baseline
    (
      DATE_TRUNC('week', params.as_of_date)
      - INTERVAL '16 weeks'
    )::date AS calculation_start

  FROM params
),

/*
  Select the eligible user population.

  Metabase Field Filters are mapped directly to columns in
  saas.users, so this table is intentionally not aliased.
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
  Generate sixteen completed calendar weeks:

  - Twelve weeks for display
  - Four additional weeks for comparison calculations
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

    -- A weekly active user must perform a feature-use event
    AND LOWER(TRIM(events.event_type)) = 'feature_use'

  GROUP BY
    DATE_TRUNC('week', events.occurred_at)::date
),

/*
  Preserve weeks with no qualifying activity.
*/
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

    /*
      Baseline excludes the current week and uses the
      four immediately preceding calendar weeks.
    */
    AVG(weekly_series.wau) OVER (
      ORDER BY weekly_series.active_week
      ROWS BETWEEN 4 PRECEDING AND 1 PRECEDING
    ) AS previous_4_week_avg

  FROM weekly_series
)

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

ORDER BY with_comparisons.active_week ASC;
