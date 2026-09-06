WITH params AS (
  SELECT
    DATE '2026-06-15' AS as_of_date,
    12 AS display_weeks,
    3 AS additional_weeks_for_rolling
),

date_limits AS (
  SELECT
    params.as_of_date,
    params.display_weeks,
    params.additional_weeks_for_rolling,

    /*
      A complete activation-week cohort requires:

      7 days to complete the activation week
      + 30 days until retention begins
      + 7 days for the retention window
      = 44 days
    */
    DATE_TRUNC(
      'week',
      params.as_of_date - INTERVAL '44 days'
    )::date AS latest_mature_activation_week,

    /*
      Start of the twelve-week displayed period.
    */
    (
      DATE_TRUNC(
        'week',
        params.as_of_date - INTERVAL '44 days'
      )
      - (
          params.display_weeks - 1
        ) * INTERVAL '7 days'
    )::date AS display_start,

    /*
      Three earlier weeks allow the first displayed week to
      have a complete four-week rolling calculation.
    */
    (
      DATE_TRUNC(
        'week',
        params.as_of_date - INTERVAL '44 days'
      )
      - (
          params.display_weeks
          + params.additional_weeks_for_rolling
          - 1
        ) * INTERVAL '7 days'
    )::date AS calculation_start

  FROM params
),

/*
  Generate a continuous activation-week calendar.

  This prevents missing weeks from causing a four-row window
  to cover more than four calendar weeks.
*/
weeks AS (
  SELECT
    GENERATE_SERIES(
      date_limits.calculation_start,
      date_limits.latest_mature_activation_week,
      INTERVAL '7 days'
    )::date AS activation_week

  FROM date_limits
),

/*
  Identify each user's first qualifying activation.

  The saas.users table is not aliased so Metabase Field Filters
  can be mapped directly to its physical columns.
*/
first_activation AS (
  SELECT
    users.user_id,
    users.signup_date,

    MIN(events.occurred_at) AS activated_at

  FROM saas.users

  CROSS JOIN params

  JOIN saas.events
    ON events.user_id = users.user_id

   -- Activation must occur on or after signup
   AND events.occurred_at >= users.signup_date

   -- Activation must occur within seven days of signup
   AND events.occurred_at <
       users.signup_date + INTERVAL '7 days'

   AND LOWER(
         TRIM(events.event_type)
       ) = 'feature_use'

  JOIN saas.features
    ON features.feature_id = events.feature_id

   -- Activation requires use of a core feature
   AND LOWER(
         TRIM(features.category)
       ) = 'core'

  WHERE users.signup_date < params.as_of_date

    -- Maps to saas.users.signup_date
    [[AND {{signup_date}}]]

    -- Maps to saas.users.plan_type
    [[AND {{plan_type}}]]

    -- Maps to saas.users.signup_source
    [[AND {{signup_source}}]]

    -- Maps to saas.users.role
    [[AND {{role}}]]

  GROUP BY
    users.user_id,
    users.signup_date
),

/*
  Keep only activation cohorts with a complete day-30
  retention observation window.
*/
eligible_activated_users AS (
  SELECT
    first_activation.user_id,
    first_activation.activated_at,

    DATE_TRUNC(
      'week',
      first_activation.activated_at
    )::date AS activation_week

  FROM first_activation

  CROSS JOIN date_limits

  WHERE DATE_TRUNC(
          'week',
          first_activation.activated_at
        )::date
        BETWEEN date_limits.calculation_start
            AND date_limits.latest_mature_activation_week
),

/*
  A user is retained if they perform at least one feature-use
  event between day 30 inclusive and day 37 exclusive
  after activation.
*/
retention_flags AS (
  SELECT
    eligible_activated_users.user_id,
    eligible_activated_users.activation_week,

    CASE
      WHEN EXISTS (
        SELECT 1

        FROM saas.events AS retention_events

        WHERE retention_events.user_id =
              eligible_activated_users.user_id

          AND LOWER(
                TRIM(retention_events.event_type)
              ) = 'feature_use'

          -- Day 30 inclusive
          AND retention_events.occurred_at >=
              eligible_activated_users.activated_at
              + INTERVAL '30 days'

          -- Day 37 exclusive
          AND retention_events.occurred_at <
              eligible_activated_users.activated_at
              + INTERVAL '37 days'
      )
      THEN 1
      ELSE 0
    END AS retained_30d

  FROM eligible_activated_users
),

weekly_retention AS (
  SELECT
    retention_flags.activation_week,

    COUNT(
      DISTINCT retention_flags.user_id
    ) AS activated_users,

    COUNT(
      DISTINCT CASE
        WHEN retention_flags.retained_30d = 1
        THEN retention_flags.user_id
      END
    ) AS retained_users_30d

  FROM retention_flags

  GROUP BY
    retention_flags.activation_week
),

/*
  Join the cohort results to the continuous calendar.

  Weeks with no activated users remain present.
*/
weekly_series AS (
  SELECT
    weeks.activation_week,

    COALESCE(
      weekly_retention.activated_users,
      0
    ) AS activated_users,

    COALESCE(
      weekly_retention.retained_users_30d,
      0
    ) AS retained_users_30d

  FROM weeks

  LEFT JOIN weekly_retention
    ON weekly_retention.activation_week =
       weeks.activation_week
),

retention_metrics AS (
  SELECT
    weekly_series.activation_week,
    weekly_series.activated_users,
    weekly_series.retained_users_30d,

    /*
      Individual activation-cohort retention rate.

      Returns NULL when the cohort has no activated users.
    */
    weekly_series.retained_users_30d::numeric
      /
      NULLIF(
        weekly_series.activated_users,
        0
      ) AS retention_rate_30d,

    /*
      Weighted four-calendar-week retention rate.

      This uses total retained users divided by total activated
      users across the current and previous three weeks.
    */
    SUM(
      weekly_series.retained_users_30d
    ) OVER (
      ORDER BY weekly_series.activation_week
      ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    )::numeric
    /
    NULLIF(
      SUM(
        weekly_series.activated_users
      ) OVER (
        ORDER BY weekly_series.activation_week
        ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
      ),
      0
    ) AS retention_rate_30d_4w

  FROM weekly_series
)

SELECT
  retention_metrics.activation_week,
  retention_metrics.activated_users,
  retention_metrics.retained_users_30d,

  ROUND(
    retention_metrics.retention_rate_30d,
    4
  ) AS retention_rate_30d,

  ROUND(
    retention_metrics.retention_rate_30d_4w,
    4
  ) AS retention_rate_30d_4w

FROM retention_metrics

CROSS JOIN date_limits

WHERE retention_metrics.activation_week
      >= date_limits.display_start

ORDER BY retention_metrics.activation_week ASC;
