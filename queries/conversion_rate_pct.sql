WITH params AS (
  SELECT
    90 AS maximum_display_days
),

/*
  Determine the selected session-date reporting period.
*/
selected_date_anchor AS (
  SELECT
    MIN(ecom.sessions.started_at)::date
      AS selected_start_date,

    MAX(ecom.sessions.started_at)::date
      AS selected_end_date

  FROM ecom.sessions

  WHERE 1 = 1
    [[AND {{Date_Range}}]]
),

date_bounds AS (
  SELECT
    GREATEST(
      sda.selected_start_date,
      sda.selected_end_date
        - (p.maximum_display_days - 1)
          * INTERVAL '1 day'
    )::date AS display_start_date,

    sda.selected_end_date::date
      AS display_end_date

  FROM selected_date_anchor AS sda
  CROSS JOIN params AS p
),

/*
  Include seven preceding days for the WoW comparison.
*/
calendar AS (
  SELECT
    GENERATE_SERIES(
      db.display_start_date - INTERVAL '7 days',
      db.display_end_date,
      INTERVAL '1 day'
    )::date AS metric_date

  FROM date_bounds AS db
),

/*
  Reduce the joined data to one row per session.

  A session is converted when it contains at least one
  successfully paid order.
*/
session_flags AS (
  SELECT
    ecom.sessions.session_id,
    ecom.sessions.started_at::date AS session_date,

    MAX(
      CASE
        WHEN LOWER(TRIM(ecom.orders.payment_status)) = 'paid'
        THEN 1
        ELSE 0
      END
    ) AS converted_session

  FROM ecom.sessions

  LEFT JOIN ecom.orders
    ON ecom.sessions.session_id =
       ecom.orders.session_id

  LEFT JOIN ecom.customers
    ON ecom.orders.customer_id =
       ecom.customers.customer_id

  LEFT JOIN ecom.attribution_touches
    ON ecom.sessions.session_id =
       ecom.attribution_touches.session_id

  LEFT JOIN ecom.devices
    ON ecom.sessions.device_id =
       ecom.devices.device_id

  LEFT JOIN ecom.payment_intents
    ON ecom.orders.order_id =
       ecom.payment_intents.order_id

  LEFT JOIN ecom.payment_methods
    ON ecom.payment_intents.payment_method_id =
       ecom.payment_methods.payment_method_id

  CROSS JOIN date_bounds AS db

  WHERE ecom.sessions.started_at >=
        db.display_start_date - INTERVAL '7 days'

    AND ecom.sessions.started_at <
        db.display_end_date + INTERVAL '1 day'

    [[AND {{country}}]]
    [[AND {{Acquisition_Channel}}]]
    [[AND {{device_type}}]]
    [[AND {{payment_method}}]]

  GROUP BY
    ecom.sessions.session_id,
    ecom.sessions.started_at::date
),

daily_conversion AS (
  SELECT
    sf.session_date AS metric_date,

    COUNT(DISTINCT sf.session_id)
      AS sessions,

    COUNT(DISTINCT sf.session_id) FILTER (
      WHERE sf.converted_session = 1
    ) AS converted_sessions

  FROM session_flags AS sf

  GROUP BY sf.session_date
),

daily_rates AS (
  SELECT
    dc.metric_date,
    dc.sessions,
    dc.converted_sessions,

    dc.converted_sessions::numeric
      / NULLIF(dc.sessions, 0)
      AS conversion_rate

  FROM daily_conversion AS dc
),

/*
  Keep dates with no sessions in the time series.
  Conversion rate remains NULL when the denominator is zero.
*/
daily_series AS (
  SELECT
    c.metric_date,

    COALESCE(dr.sessions, 0) AS sessions,

    COALESCE(dr.converted_sessions, 0)
      AS converted_sessions,

    dr.conversion_rate

  FROM calendar AS c

  LEFT JOIN daily_rates AS dr
    ON dr.metric_date = c.metric_date
),

daily_comparison AS (
  SELECT
    current_day.metric_date,
    current_day.sessions,
    current_day.converted_sessions,
    current_day.conversion_rate,

    previous_week.conversion_rate
      AS conversion_rate_7d_ago

  FROM daily_series AS current_day

  LEFT JOIN daily_series AS previous_week
    ON previous_week.metric_date =
       current_day.metric_date - INTERVAL '7 days'
)

SELECT
  dc.metric_date,
  dc.sessions,
  dc.converted_sessions,

  ROUND(
    dc.conversion_rate,
    4
  ) AS conversion_rate,

  ROUND(
    dc.conversion_rate_7d_ago,
    4
  ) AS conversion_rate_7d_ago,

  ROUND(
    (
      dc.conversion_rate
      - dc.conversion_rate_7d_ago
    )
    / NULLIF(dc.conversion_rate_7d_ago, 0),
    4
  ) AS wow_change,

  /*
    Absolute movement in percentage points.
    Example: 10% to 12% = +2 percentage points.
  */
  ROUND(
    100 * (
      dc.conversion_rate
      - dc.conversion_rate_7d_ago
    ),
    2
  ) AS percentage_point_change

FROM daily_comparison AS dc
CROSS JOIN date_bounds AS db

WHERE dc.metric_date
      BETWEEN db.display_start_date
          AND db.display_end_date

ORDER BY dc.metric_date ASC;
