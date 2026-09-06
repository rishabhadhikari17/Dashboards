WITH params AS (
  SELECT
    90 AS maximum_display_days
),

/*
  Determine the selected reporting period.

  The Date Range filter controls which dates are displayed.
*/
selected_date_anchor AS (
  SELECT
    MIN(ecom.orders.created_at)::date
      AS selected_start_date,

    MAX(ecom.orders.created_at)::date
      AS selected_end_date

  FROM ecom.orders

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
  Include seven additional days before the displayed period
  so the first displayed date has an accurate WoW comparison.
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
  Produce one row per paid order.

  DISTINCT prevents attribution or payment joins from
  duplicating order revenue.
*/
eligible_orders AS (
  SELECT DISTINCT
    ecom.orders.order_id,
    ecom.orders.created_at::date AS order_date,
    ecom.orders.total

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
      Do not repeat the Date Range filter here because the
      additional seven days are required for comparison.
    */
    AND ecom.orders.created_at >=
        db.display_start_date - INTERVAL '7 days'

    AND ecom.orders.created_at <
        db.display_end_date + INTERVAL '1 day'

    [[AND {{payment_method}}]]
    [[AND {{country}}]]
    [[AND {{Acquisition_Channel}}]]
    [[AND {{device_type}}]]
),

daily_revenue AS (
  SELECT
    eo.order_date AS metric_date,

    SUM(eo.total)::numeric AS revenue

  FROM eligible_orders AS eo

  GROUP BY eo.order_date
),

/*
  Preserve dates with no paid revenue.
*/
daily_series AS (
  SELECT
    c.metric_date,

    COALESCE(
      dr.revenue,
      0
    )::numeric AS revenue

  FROM calendar AS c

  LEFT JOIN daily_revenue AS dr
    ON dr.metric_date = c.metric_date
),

/*
  Compare each date with the same weekday seven days earlier.
*/
daily_comparison AS (
  SELECT
    current_day.metric_date,
    current_day.revenue,

    previous_week.revenue
      AS revenue_7d_ago

  FROM daily_series AS current_day

  LEFT JOIN daily_series AS previous_week
    ON previous_week.metric_date =
       current_day.metric_date - INTERVAL '7 days'
)

SELECT
  dc.metric_date,

  ROUND(
    dc.revenue,
    2
  ) AS revenue,

  ROUND(
    dc.revenue_7d_ago,
    2
  ) AS revenue_7d_ago,

  ROUND(
    (
      dc.revenue - dc.revenue_7d_ago
    )
    / NULLIF(dc.revenue_7d_ago, 0),
    4
  ) AS wow_change

FROM daily_comparison AS dc
CROSS JOIN date_bounds AS db

WHERE dc.metric_date
      BETWEEN db.display_start_date
          AND db.display_end_date

ORDER BY dc.metric_date ASC;
