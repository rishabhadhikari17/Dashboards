WITH params AS (
  SELECT
    90 AS maximum_display_days
),

/*
  Determine the requested reporting period.

  The dashboard Date Range filter is applied here. If no date
  filter is selected, the latest available order date is used.
*/
selected_date_anchor AS (
  SELECT
    MIN(ecom.orders.created_at)::date AS selected_start_date,
    MAX(ecom.orders.created_at)::date AS selected_end_date

  FROM ecom.orders

  WHERE 1 = 1
    [[AND {{Date_Range}}]]
),

date_bounds AS (
  SELECT
    /*
      Limit the displayed series to a maximum of 90 days.
    */
    GREATEST(
      sda.selected_start_date,
      sda.selected_end_date
        - (p.maximum_display_days - 1) * INTERVAL '1 day'
    )::date AS display_start_date,

    sda.selected_end_date::date AS display_end_date

  FROM selected_date_anchor AS sda
  CROSS JOIN params AS p
),

/*
  Include seven additional days before the displayed period.
  These dates are required for exact same-weekday WoW comparisons.
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
  Build one row per successful order.

  DISTINCT prevents one-to-many attribution or payment joins
  from duplicating an order.
*/
eligible_orders AS (
  SELECT DISTINCT
    ecom.orders.order_id,
    ecom.orders.order_number,
    ecom.orders.created_at::date AS order_date

  FROM ecom.orders

  LEFT JOIN ecom.customers
    ON ecom.orders.customer_id =
       ecom.customers.customer_id

  LEFT JOIN ecom.attribution_touches
    ON ecom.orders.session_id =
       ecom.attribution_touches.session_id

  LEFT JOIN ecom.sessions
    ON ecom.orders.session_id =
       ecom.sessions.session_id

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

  WHERE LOWER(TRIM(ecom.orders.payment_status)) = 'paid'

    /*
      The Date Range filter is not repeated here because the
      query needs the preceding seven days for comparison.
    */
    AND ecom.orders.created_at >=
        db.display_start_date - INTERVAL '7 days'

    AND ecom.orders.created_at <
        db.display_end_date + INTERVAL '1 day'

    [[AND {{country}}]]
    [[AND {{Acquisition_Channel}}]]
    [[AND {{device_type}}]]
    [[AND {{payment_method}}]]
),

daily_orders AS (
  SELECT
    eo.order_date AS metric_date,
    COUNT(DISTINCT eo.order_id) AS successful_orders

  FROM eligible_orders AS eo

  GROUP BY
    eo.order_date
),

/*
  Join activity to a continuous calendar so dates with no
  successful orders appear as zero.
*/
daily_series AS (
  SELECT
    c.metric_date,
    COALESCE(dso.successful_orders, 0) AS successful_orders

  FROM calendar AS c

  LEFT JOIN daily_orders AS dso
    ON dso.metric_date = c.metric_date
),

daily_comparison AS (
  SELECT
    current_day.metric_date,
    current_day.successful_orders,

    previous_week.successful_orders
      AS successful_orders_7d_ago

  FROM daily_series AS current_day

  LEFT JOIN daily_series AS previous_week
    ON previous_week.metric_date =
       current_day.metric_date - INTERVAL '7 days'
)

SELECT
  dc.metric_date,
  dc.successful_orders,
  dc.successful_orders_7d_ago,

  ROUND(
    (
      dc.successful_orders
      - dc.successful_orders_7d_ago
    )::numeric
    / NULLIF(dc.successful_orders_7d_ago, 0),
    4
  ) AS wow_change

FROM daily_comparison AS dc
CROSS JOIN date_bounds AS db

WHERE dc.metric_date
      BETWEEN db.display_start_date
          AND db.display_end_date

ORDER BY dc.metric_date ASC;
