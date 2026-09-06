WITH params AS (
  SELECT
    DATE '2026-06-15' AS as_of_date,
    24 AS lookback_weeks
),

date_limits AS (
  SELECT
    DATE_TRUNC(
      'week',
      params.as_of_date
    )::date AS current_week_start,

    (
      DATE_TRUNC(
        'week',
        params.as_of_date
      )
      - params.lookback_weeks * INTERVAL '7 days'
    )::date AS analysis_start

  FROM params
),

/*
  Assign users to signup-week cohorts.

  The saas.users table is intentionally not aliased so
  Metabase Field Filters can map directly to its columns.
*/
cohort_users AS (
  SELECT DISTINCT
    users.user_id,

    DATE_TRUNC(
      'week',
      users.signup_date
    )::date AS cohort_week

  FROM saas.users

  CROSS JOIN date_limits

  WHERE users.signup_date >=
        date_limits.analysis_start

    AND users.signup_date <
        date_limits.current_week_start

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
  Reduce activity to one row per user per completed week.

  A retained user must perform at least one feature-use event
  during the relevant calendar week.
*/
weekly_activity AS (
  SELECT DISTINCT
    events.user_id,

    DATE_TRUNC(
      'week',
      events.occurred_at
    )::date AS activity_week

  FROM saas.events

  CROSS JOIN date_limits

  WHERE LOWER(
          TRIM(events.event_type)
        ) = 'feature_use'

    AND events.occurred_at >=
        date_limits.analysis_start

    AND events.occurred_at <
        date_limits.current_week_start
),

cohort_metrics AS (
  SELECT
    cohort_users.cohort_week,
    date_limits.current_week_start,

    COUNT(
      DISTINCT cohort_users.user_id
    ) AS cohort_size,

    COUNT(
      DISTINCT CASE
        WHEN weekly_activity.activity_week =
             cohort_users.cohort_week
             + INTERVAL '7 days'
        THEN cohort_users.user_id
      END
    ) AS retained_w1,

    COUNT(
      DISTINCT CASE
        WHEN weekly_activity.activity_week =
             cohort_users.cohort_week
             + INTERVAL '14 days'
        THEN cohort_users.user_id
      END
    ) AS retained_w2,

    COUNT(
      DISTINCT CASE
        WHEN weekly_activity.activity_week =
             cohort_users.cohort_week
             + INTERVAL '28 days'
        THEN cohort_users.user_id
      END
    ) AS retained_w4,

    COUNT(
      DISTINCT CASE
        WHEN weekly_activity.activity_week =
             cohort_users.cohort_week
             + INTERVAL '56 days'
        THEN cohort_users.user_id
      END
    ) AS retained_w8,

    COUNT(
      DISTINCT CASE
        WHEN weekly_activity.activity_week =
             cohort_users.cohort_week
             + INTERVAL '84 days'
        THEN cohort_users.user_id
      END
    ) AS retained_w12

  FROM cohort_users

  CROSS JOIN date_limits

  LEFT JOIN weekly_activity
    ON weekly_activity.user_id =
       cohort_users.user_id

   AND weekly_activity.activity_week >=
       cohort_users.cohort_week
       + INTERVAL '7 days'

   AND weekly_activity.activity_week <=
       cohort_users.cohort_week
       + INTERVAL '84 days'

  GROUP BY
    cohort_users.cohort_week,
    date_limits.current_week_start
)

SELECT
  cohort_metrics.cohort_week,
  cohort_metrics.cohort_size,

  /*
    Recent cohorts that have not completed the target
    retention week return NULL instead of 0%.
  */
  CASE
    WHEN cohort_metrics.cohort_week
         + INTERVAL '7 days'
         < cohort_metrics.current_week_start

    THEN ROUND(
      100.0 * cohort_metrics.retained_w1
      /
      NULLIF(
        cohort_metrics.cohort_size,
        0
      ),
      2
    )

    ELSE NULL
  END AS w1_retention_pct,

  CASE
    WHEN cohort_metrics.cohort_week
         + INTERVAL '14 days'
         < cohort_metrics.current_week_start

    THEN ROUND(
      100.0 * cohort_metrics.retained_w2
      /
      NULLIF(
        cohort_metrics.cohort_size,
        0
      ),
      2
    )

    ELSE NULL
  END AS w2_retention_pct,

  CASE
    WHEN cohort_metrics.cohort_week
         + INTERVAL '28 days'
         < cohort_metrics.current_week_start

    THEN ROUND(
      100.0 * cohort_metrics.retained_w4
      /
      NULLIF(
        cohort_metrics.cohort_size,
        0
      ),
      2
    )

    ELSE NULL
  END AS w4_retention_pct,

  CASE
    WHEN cohort_metrics.cohort_week
         + INTERVAL '56 days'
         < cohort_metrics.current_week_start

    THEN ROUND(
      100.0 * cohort_metrics.retained_w8
      /
      NULLIF(
        cohort_metrics.cohort_size,
        0
      ),
      2
    )

    ELSE NULL
  END AS w8_retention_pct,

  CASE
    WHEN cohort_metrics.cohort_week
         + INTERVAL '84 days'
         < cohort_metrics.current_week_start

    THEN ROUND(
      100.0 * cohort_metrics.retained_w12
      /
      NULLIF(
        cohort_metrics.cohort_size,
        0
      ),
      2
    )

    ELSE NULL
  END AS w12_retention_pct

FROM cohort_metrics

ORDER BY cohort_metrics.cohort_week DESC;
