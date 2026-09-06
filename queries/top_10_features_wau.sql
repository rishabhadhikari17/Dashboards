WITH params AS (
  SELECT
    DATE '2026-06-15' AS as_of_date
),

date_limits AS (
  SELECT
    (
      DATE_TRUNC(
        'week',
        params.as_of_date
      )
      - INTERVAL '1 week'
    )::date AS latest_complete_week,

    DATE_TRUNC(
      'week',
      params.as_of_date
    )::date AS current_week_start

  FROM params
),

/*
  Define the user population.

  Plan Type, Signup Source and Role apply to both:
  1. Total WAU denominator
  2. Feature-user numerator
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
  Calculate total WAU for the selected user population.

  Feature Category is intentionally not applied here.
  This keeps the denominator as total WAU for the selected
  Plan Type, Signup Source and User Role.
*/
weekly_active_users AS (
  SELECT
    COUNT(
      DISTINCT events.user_id
    ) AS wau

  FROM saas.events

  JOIN selected_users
    ON selected_users.user_id =
       events.user_id

  CROSS JOIN date_limits

  WHERE LOWER(
          TRIM(events.event_type)
        ) = 'feature_use'

    AND events.occurred_at >=
        date_limits.latest_complete_week

    AND events.occurred_at <
        date_limits.current_week_start
),

/*
  Calculate distinct users and event counts for each feature.

  Feature Category is applied only here, restricting the
  features eligible for the Top 10 ranking.
*/
feature_usage AS (
  SELECT
    features.feature_id,
    features.feature_name,
    features.category,

    COUNT(
      DISTINCT events.user_id
    ) AS feature_users,

    COUNT(
      DISTINCT events.event_id
    ) AS feature_events

  FROM saas.events

  JOIN selected_users
    ON selected_users.user_id =
       events.user_id

  JOIN saas.features
    ON features.feature_id =
       events.feature_id

  CROSS JOIN date_limits

  WHERE LOWER(
          TRIM(events.event_type)
        ) = 'feature_use'

    AND events.occurred_at >=
        date_limits.latest_complete_week

    AND events.occurred_at <
        date_limits.current_week_start

    -- Maps to saas.features.category
    [[AND {{category}}]]

  GROUP BY
    features.feature_id,
    features.feature_name,
    features.category
),

feature_metrics AS (
  SELECT
    date_limits.latest_complete_week AS week,

    feature_usage.feature_id,
    feature_usage.feature_name,
    feature_usage.category,

    weekly_active_users.wau,
    feature_usage.feature_users,
    feature_usage.feature_events,

    /*
      Percentage of total filtered WAU who used the feature.

      Returned as a decimal:
      0.1500 = 15%
    */
    ROUND(
      feature_usage.feature_users::numeric
      /
      NULLIF(
        weekly_active_users.wau,
        0
      ),
      4
    ) AS pct_of_wau,

    /*
      Average feature events per user of that feature.
    */
    ROUND(
      feature_usage.feature_events::numeric
      /
      NULLIF(
        feature_usage.feature_users,
        0
      ),
      2
    ) AS events_per_user

  FROM feature_usage

  CROSS JOIN weekly_active_users
  CROSS JOIN date_limits
),

ranked_features AS (
  SELECT
    ROW_NUMBER() OVER (
      ORDER BY
        feature_metrics.pct_of_wau DESC,
        feature_metrics.feature_users DESC,
        feature_metrics.feature_name ASC
    ) AS feature_rank,

    feature_metrics.week,
    feature_metrics.feature_name,
    feature_metrics.category,
    feature_metrics.wau,
    feature_metrics.feature_users,
    feature_metrics.feature_events,
    feature_metrics.pct_of_wau,
    feature_metrics.events_per_user

  FROM feature_metrics
)

SELECT
  ranked_features.feature_rank,
  ranked_features.week,
  ranked_features.feature_name,
  ranked_features.category,
  ranked_features.wau,
  ranked_features.feature_users,
  ranked_features.feature_events,
  ranked_features.pct_of_wau,
  ranked_features.events_per_user

FROM ranked_features

WHERE ranked_features.feature_rank <= 10

ORDER BY ranked_features.feature_rank ASC;
