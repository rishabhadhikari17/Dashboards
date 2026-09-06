WITH base AS (
  SELECT
    CASE
      WHEN [[{{date_type}}]] = 'daily'
        THEN DATE(ecom.orders.created_at)
      WHEN [[{{date_type}}]] = 'weekly'
        THEN DATE(date_trunc('week', ecom.orders.created_at))
      WHEN [[{{date_type}}]] = 'monthly'
        THEN DATE(date_trunc('month', ecom.orders.created_at))
    END AS date,
    SUM(total) AS revenue,
    COUNT(orders.order_id) AS orders
  FROM ecom.orders
  LEFT JOIN ecom.customers
    ON orders.customer_id = customers.customer_id
  LEFT JOIN ecom.attribution_touches
    ON orders.session_id = attribution_touches.session_id
  LEFT JOIN ecom.sessions
    ON orders.session_id = sessions.session_id
  LEFT JOIN ecom.devices
    ON sessions.device_id = devices.device_id
  LEFT JOIN ecom.payment_intents
    ON orders.order_id = payment_intents.order_id
  LEFT JOIN ecom.payment_methods
    ON payment_intents.payment_method_id = payment_methods.payment_method_id
  WHERE orders.payment_status = 'paid'
[[AND {{payment_method}}]]
[[AND {{country}}]]
[[AND {{Date_Range}}]]
[[AND {{Acquisition_Channel}}]]
[[AND {{device_type}}]]
  GROUP BY 1
)

SELECT
  date,
  revenue,
  orders,

  -- % change in revenue
  ROUND(
    (
      (revenue - LAG(revenue) OVER (ORDER BY date))
      / NULLIF(LAG(revenue) OVER (ORDER BY date), 0)
      
    )::numeric,
    2
  ) AS revenue_change,

  -- % change in orders (FIXED: avoid integer division)
  ROUND(
    (
      (orders - LAG(orders) OVER (ORDER BY date))::numeric
      / NULLIF(LAG(orders) OVER (ORDER BY date), 0)
      
    ),
    2
  ) AS orders_change

FROM base
ORDER BY date ASC;
