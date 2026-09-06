WITH params AS (
  SELECT
    90 AS maximum_display_days
),

/*
  Determine the date range displayed on the dashboard.

  Date Range represents the paid order date.
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
  Thirteen additional days are required before the display period:

  - Six days for the current seven-day rolling window
  - Seven more days for the preceding seven-day comparison
*/
calendar AS (
  SELECT
    GENERATE_SERIES(
      db.display_start_date - INTERVAL '13 days',
      db.display_end_date,
      INTERVAL '1 day'
    )::date AS metric_date

  FROM date_bounds AS db
),

/*
  Produce one row per paid order.

  An order is treated as refunded when it has at least one
  refund record with status = succeeded.
*/
eligible_orders AS (
  SELECT
    ecom.orders.order_id,
    ecom.orders.created_at::date AS order_date,

    MAX(
      CASE
        WHEN LOWER(TRIM(ecom.refunds.status)) = 'succeeded'
        THEN 1
        ELSE 0
      END
    ) AS successfully_refunded

  FROM ecom.orders

  LEFT JOIN ecom.refunds
    ON ecom.orders.order_id =
       ecom.refunds.order_id

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

    AND ecom.orders.created_at >=
        db.display_start_date - INTERVAL '13 days'

    AND ecom.orders.created_at <
        db.display_end_date + INTERVAL '1 day'

    [[AND {{payment_method}}]]
    [[AND {{country}}]]
    [[AND {{Acquisition_Channel}}]]
    [[AND {{device_type}}]]

  GROUP BY
    ecom.orders.order_id,
    ecom.orders.created_at::date
),

daily_orders AS (
  SELECT
    eo.order_date AS metric_date,

    COUNT(DISTINCT eo.order_id)
      AS paid_orders,

    COUNT(DISTINCT eo.order_id) FILTER (
      WHERE eo.successfully_refunded = 1
    ) AS refunded_orders

  FROM eligible_orders AS eo

  GROUP BY eo.order_date
),

/*
  Preserve dates with no paid orders.
*/
daily_series AS (
  SELECT
    c.metric_date,

    COALESCE(dord.paid_orders, 0)
      AS paid_orders,

    COALESCE(dord.refunded_orders, 0)
      AS refunded_orders

  FROM calendar AS c

  LEFT JOIN daily_orders AS dord
    ON dord.metric_date = c.metric_date
),

/*
  Calculate rolling seven-day order totals.
*/
rolling_metrics AS (
  SELECT
    ds.metric_date,

    SUM(ds.paid_orders) OVER (
      ORDER BY ds.metric_date
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS paid_orders_7d,

    SUM(ds.refunded_orders) OVER (
      ORDER BY ds.metric_date
      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS refunded_orders_7d

  FROM daily_series AS ds
),

rolling_rates AS (
  SELECT
    rm.metric_date,
    rm.paid_orders_7d,
    rm.refunded_orders_7d,

    rm.refunded_orders_7d::numeric
      / NULLIF(rm.paid_orders_7d, 0)
      AS refund_rate_7d

  FROM rolling_metrics AS rm
),

/*
  Compare the latest rolling seven-day period with the
  non-overlapping seven-day period immediately before it.
*/
period_comparison AS (
  SELECT
    current_period.metric_date,
    current_period.paid_orders_7d,
    current_period.refunded_orders_7d,
    current_period.refund_rate_7d,

    previous_period.refund_rate_7d
      AS refund_rate_previous_7d

  FROM rolling_rates AS current_period

  LEFT JOIN rolling_rates AS previous_period
    ON previous_period.metric_date =
       current_period.metric_date - INTERVAL '7 days'
)

SELECT
  pc.metric_date,
  pc.paid_orders_7d,
  pc.refunded_orders_7d,

  ROUND(
    pc.refund_rate_7d,
    4
  ) AS refund_rate_7d,

  ROUND(
    pc.refund_rate_previous_7d,
    4
  ) AS refund_rate_previous_7d,

  ROUND(
    (
      pc.refund_rate_7d
      - pc.refund_rate_previous_7d
    )
    / NULLIF(pc.refund_rate_previous_7d, 0),
    4
  ) AS wow_change,

  ROUND(
    100 * (
      pc.refund_rate_7d
      - pc.refund_rate_previous_7d
    ),
    2
  ) AS percentage_point_change

FROM period_comparison AS pc
CROSS JOIN date_bounds AS db

WHERE pc.metric_date
      BETWEEN db.display_start_date
          AND db.display_end_date

ORDER BY pc.metric_date ASC;


