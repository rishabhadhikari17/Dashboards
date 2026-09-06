WITH params AS (
  SELECT
    DATE '2026-06-15' AS as_of_date,
    12 AS lookback_weeks
),

/*
  Select users with a complete 30-day adoption window.

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

    -- Only include users with a complete 30-day window
    AND users.signup_date
        + INTERVAL '30 days'
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
  Find the first core-feature-use event occurring within
  seven days of signup.

  This is the same activation definition used by the
  Activation Rate chart.
*/
first_activation AS (
  SELECT
    eligible_users.user_id,

    MIN(
      events.occurred_at
    ) AS activated_at

  FROM eligible_users

  JOIN saas.events
    ON events.user_id = eligible_users.user_id

   -- Activation must occur after signup
   AND events.occurred_at >=
       eligible_users.signup_date

   -- Activation must occur within seven days of signup
   AND events.occurred_at <
       eligible_users.signup_date
       + INTERVAL '7 days'

   AND LOWER(
         TRIM(events.event_type)
       ) = 'feature_use'

  JOIN saas.features
    ON features.feature_id = events.feature_id
   AND LOWER(
         TRIM(features.category)
       ) = 'core'

  GROUP BY
    eligible_users.user_id
),

/*
  Find the first power-feature-use event after activation
  and within 30 days of signup.

  Requiring the event to occur after activation preserves
  the chronological funnel order.
*/
first_power_feature AS (
  SELECT
    eligible_users.user_id,

    MIN(
      events.occurred_at
    ) AS first_power_feature_at

  FROM eligible_users

  JOIN first_activation
    ON first_activation.user_id =
       eligible_users.user_id

  JOIN saas.events
    ON events.user_id =
       eligible_users.user_id

   -- Power-feature usage must occur after activation
   AND events.occurred_at >=
       first_activation.activated_at

   -- Power-feature usage must occur within 30 days of signup
   AND events.occurred_at <
       eligible_users.signup_date
       + INTERVAL '30 days'

   AND LOWER(
         TRIM(events.event_type)
       ) = 'feature_use'

  JOIN saas.features
    ON features.feature_id = events.feature_id
   AND LOWER(
         TRIM(features.category)
       ) IN (
         'analytics',
         'workflow',
         'integrations',
         'data'
       )

  GROUP BY
    eligible_users.user_id
),

funnel_counts AS (
  SELECT
    COUNT(
      DISTINCT eligible_users.user_id
    ) AS signed_up,

    COUNT(
      DISTINCT first_activation.user_id
    ) AS activated,

    COUNT(
      DISTINCT first_power_feature.user_id
    ) AS used_power

  FROM eligible_users

  LEFT JOIN first_activation
    ON first_activation.user_id =
       eligible_users.user_id

  LEFT JOIN first_power_feature
    ON first_power_feature.user_id =
       eligible_users.user_id
),

funnel AS (
  /*
    Stage 1: All eligible signups
  */
  SELECT
    1 AS stage_order,
    'Signed Up' AS stage,

    funnel_counts.signed_up AS users,

    1.0000::numeric AS overall_conversion,

    1.0000::numeric AS previous_stage_conversion

  FROM funnel_counts

  UNION ALL

  /*
    Stage 2: Activated through a core feature within 7 days
  */
  SELECT
    2 AS stage_order,
    'Activated Within 7 Days' AS stage,

    funnel_counts.activated AS users,

    ROUND(
      funnel_counts.activated::numeric
      /
      NULLIF(
        funnel_counts.signed_up,
        0
      ),
      4
    ) AS overall_conversion,

    ROUND(
      funnel_counts.activated::numeric
      /
      NULLIF(
        funnel_counts.signed_up,
        0
      ),
      4
    ) AS previous_stage_conversion

  FROM funnel_counts

  UNION ALL

  /*
    Stage 3: Used a power feature after activation
    and within 30 days of signup
  */
  SELECT
    3 AS stage_order,
    'Used Power Feature Within 30 Days' AS stage,

    funnel_counts.used_power AS users,

    ROUND(
      funnel_counts.used_power::numeric
      /
      NULLIF(
        funnel_counts.signed_up,
        0
      ),
      4
    ) AS overall_conversion,

    ROUND(
      funnel_counts.used_power::numeric
      /
      NULLIF(
        funnel_counts.activated,
        0
      ),
      4
    ) AS previous_stage_conversion

  FROM funnel_counts
)

SELECT
  funnel.stage_order,
  funnel.stage,
  funnel.users,
  funnel.overall_conversion,
  funnel.previous_stage_conversion

FROM funnel

ORDER BY funnel.stage_order ASC;
