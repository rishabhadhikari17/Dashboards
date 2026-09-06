WITH params AS (
  SELECT
    DATE '2026-06-15' AS as_of_date,
    12 AS lookback_weeks,
    30 AS observation_window_days
),

/*
  Select users with a complete 30-day observation window.

  The saas.users table is intentionally not aliased so
  Metabase Field Filters can map directly to its columns.
*/
eligible_users AS (
  SELECT DISTINCT
    users.user_id,
    users.signup_date

  FROM saas.users

  CROSS JOIN params

  WHERE users.signup_date >=
        DATE_TRUNC(
          'week',
          params.as_of_date
        )
        - params.lookback_weeks * INTERVAL '1 week'

    AND users.signup_date
        + params.observation_window_days * INTERVAL '1 day'
        <= params.as_of_date

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
  Identify qualifying core-feature events.

  Non-core activity must not be treated as first value.
*/
core_feature_events AS (
  SELECT
    events.user_id,
    events.occurred_at

  FROM saas.events

  JOIN saas.features
    ON features.feature_id = events.feature_id
   AND LOWER(
         TRIM(features.category)
       ) = 'core'

  WHERE LOWER(
          TRIM(events.event_type)
        ) = 'feature_use'
),

/*
  Find each eligible user's first core-feature use within
  30 days of signup.

  LEFT JOIN preserves users who do not reach first value.
*/
first_meaningful_action AS (
  SELECT
    eligible_users.user_id,
    eligible_users.signup_date,

    MIN(
      core_feature_events.occurred_at
    ) AS first_value_at

  FROM eligible_users

  CROSS JOIN params

  LEFT JOIN core_feature_events
    ON core_feature_events.user_id =
       eligible_users.user_id

   AND core_feature_events.occurred_at >=
       eligible_users.signup_date

   AND core_feature_events.occurred_at <
       eligible_users.signup_date
       + params.observation_window_days
         * INTERVAL '1 day'

  GROUP BY
    eligible_users.user_id,
    eligible_users.signup_date
),

time_to_value AS (
  SELECT
    first_meaningful_action.user_id,
    first_meaningful_action.signup_date,
    first_meaningful_action.first_value_at,

    EXTRACT(
      EPOCH FROM (
        first_meaningful_action.first_value_at
        - first_meaningful_action.signup_date
      )
    ) / 3600.0 AS hours_to_value

  FROM first_meaningful_action
),

bucketed_users AS (
  SELECT
    time_to_value.user_id,

    CASE
      WHEN time_to_value.first_value_at IS NULL
        THEN 7

      WHEN time_to_value.hours_to_value < 1
        THEN 1

      WHEN time_to_value.hours_to_value < 6
        THEN 2

      WHEN time_to_value.hours_to_value < 24
        THEN 3

      WHEN time_to_value.hours_to_value < 72
        THEN 4

      WHEN time_to_value.hours_to_value < 168
        THEN 5

      ELSE 6
    END AS bucket_order

  FROM time_to_value
),

/*
  Define every bucket explicitly so empty buckets still
  appear with zero users.
*/
bucket_definitions AS (
  SELECT
    1 AS bucket_order,
    'Under 1 hour' AS time_to_value_bucket

  UNION ALL

  SELECT
    2,
    '1–6 hours'

  UNION ALL

  SELECT
    3,
    '6–24 hours'

  UNION ALL

  SELECT
    4,
    '1–3 days'

  UNION ALL

  SELECT
    5,
    '3–7 days'

  UNION ALL

  SELECT
    6,
    '7–30 days'

  UNION ALL

  SELECT
    7,
    'No value within 30 days'
),

bucket_counts AS (
  SELECT
    bucketed_users.bucket_order,

    COUNT(
      DISTINCT bucketed_users.user_id
    ) AS users

  FROM bucketed_users

  GROUP BY
    bucketed_users.bucket_order
),

final_buckets AS (
  SELECT
    bucket_definitions.bucket_order,
    bucket_definitions.time_to_value_bucket,

    COALESCE(
      bucket_counts.users,
      0
    ) AS users

  FROM bucket_definitions

  LEFT JOIN bucket_counts
    ON bucket_counts.bucket_order =
       bucket_definitions.bucket_order
)

SELECT
  final_buckets.bucket_order,
  final_buckets.time_to_value_bucket,
  final_buckets.users,

  ROUND(
    final_buckets.users::numeric
    /
    NULLIF(
      SUM(final_buckets.users) OVER (),
      0
    ),
    4
  ) AS user_share

FROM final_buckets

ORDER BY final_buckets.bucket_order ASC;
