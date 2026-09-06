WITH params AS (
  SELECT
    MAX(users.signup_date)::date AS as_of_date,
    12 AS lookback_weeks,
    7 AS activation_window_days

  FROM saas.users
),

date_limits AS (
  SELECT
    params.as_of_date,
    params.activation_window_days,

    /*
      A signup-week cohort becomes fully mature after:

      7 days to complete the signup week
      + 7 days for the activation window
      = 14 days
    */
    DATE_TRUNC(
      'week',
      params.as_of_date - INTERVAL '14 days'
    )::date AS latest_mature_signup_week,

    (
      DATE_TRUNC(
        'week',
        params.as_of_date - INTERVAL '14 days'
      )
      - (params.lookback_weeks - 1) * INTERVAL '1 week'
    )::date AS earliest_signup_week

  FROM params
),

/*
  Select eligible users before measuring activation.

  Metabase filters are mapped directly to fields in saas.users,
  so this table is intentionally not aliased.
*/
eligible_signups AS (
  SELECT DISTINCT
    users.user_id,
    users.signup_date,

    DATE_TRUNC(
      'week',
      users.signup_date
    )::date AS signup_week

  FROM saas.users

  CROSS JOIN date_limits

  WHERE DATE_TRUNC(
          'week',
          users.signup_date
        )::date
        BETWEEN date_limits.earliest_signup_week
            AND date_limits.latest_mature_signup_week

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
  A user is activated when they perform their first
  core-feature-use event within 168 hours of signup.
*/
activated_users AS (
  SELECT
    eligible_signups.user_id,
    eligible_signups.signup_week,

    MIN(events.occurred_at) AS activated_at

  FROM eligible_signups

  CROSS JOIN date_limits

  JOIN saas.events
    ON events.user_id = eligible_signups.user_id

   -- Activation must happen after signup
   AND events.occurred_at >= eligible_signups.signup_date

   -- Activation must happen within seven days of signup
   AND events.occurred_at <
       eligible_signups.signup_date
       + date_limits.activation_window_days
         * INTERVAL '1 day'

   AND LOWER(
         TRIM(events.event_type)
       ) = 'feature_use'

  JOIN saas.features
    ON features.feature_id = events.feature_id
   AND LOWER(
         TRIM(features.category)
       ) = 'core'

  GROUP BY
    eligible_signups.user_id,
    eligible_signups.signup_week
),

weekly_activation AS (
  SELECT
    eligible_signups.signup_week,

    COUNT(
      DISTINCT eligible_signups.user_id
    ) AS eligible_signups,

    COUNT(
      DISTINCT activated_users.user_id
    ) AS activated_users

  FROM eligible_signups

  LEFT JOIN activated_users
    ON activated_users.user_id =
       eligible_signups.user_id

   AND activated_users.signup_week =
       eligible_signups.signup_week

  GROUP BY
    eligible_signups.signup_week
)

SELECT
  weekly_activation.signup_week,
  weekly_activation.eligible_signups,
  weekly_activation.activated_users,

  ROUND(
    weekly_activation.activated_users::numeric
    /
    NULLIF(
      weekly_activation.eligible_signups,
      0
    ),
    4
  ) AS activation_rate

FROM weekly_activation

ORDER BY weekly_activation.signup_week ASC;
