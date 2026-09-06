WITH date_anchor AS (
    SELECT
        MAX(sessions.started_at)::date AS max_date
    FROM ecom.sessions AS sessions
),

calendar AS (
    SELECT
        GENERATE_SERIES(
            max_date - INTERVAL '13 days',
            max_date,
            INTERVAL '1 day'
        )::date AS metric_date
    FROM date_anchor
),

filtered_data AS (
    SELECT DISTINCT
        sessions.session_id,
        sessions.started_at::date AS metric_date,
        orders.order_id,
        orders.total,
        orders.payment_status,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM ecom.refunds AS refunds
                WHERE refunds.order_id = orders.order_id
                  AND LOWER(refunds.status) = 'succeeded'
            )
            THEN 1
            ELSE 0
        END AS successfully_refunded

    FROM ecom.sessions AS sessions

    CROSS JOIN date_anchor

    LEFT JOIN ecom.orders AS orders
        ON sessions.session_id = orders.session_id

    LEFT JOIN ecom.customers AS customers
        ON orders.customer_id = customers.customer_id

    LEFT JOIN ecom.attribution_touches AS attribution_touches
        ON sessions.session_id = attribution_touches.session_id

    LEFT JOIN ecom.devices AS devices
        ON sessions.device_id = devices.device_id

    LEFT JOIN ecom.payment_intents AS payment_intents
        ON orders.order_id = payment_intents.order_id

    LEFT JOIN ecom.payment_methods AS payment_methods
        ON payment_intents.payment_method_id =
           payment_methods.payment_method_id

    WHERE sessions.started_at >= max_date - INTERVAL '13 days'
      AND sessions.started_at < max_date + INTERVAL '1 day'

        [[AND {{payment_method}}]]
        [[AND {{country}}]]
        [[AND {{Acquisition_Channel}}]]
        [[AND {{device_type}}]]
),

daily_metrics AS (
    SELECT
        metric_date,

        COALESCE(
            SUM(
                CASE
                    WHEN LOWER(payment_status) = 'paid'
                    THEN total
                    ELSE 0
                END
            ),
            0
        ) AS revenue,

        COUNT(
            DISTINCT CASE
                WHEN LOWER(payment_status) = 'paid'
                THEN order_id
            END
        ) AS orders,

        COUNT(DISTINCT session_id) AS sessions,

        COUNT(
            DISTINCT CASE
                WHEN LOWER(payment_status) = 'paid'
                 AND successfully_refunded = 1
                THEN order_id
            END
        ) AS refunded_orders

    FROM filtered_data
    GROUP BY metric_date
)

SELECT
    calendar.metric_date AS date,

    ROUND(
        COALESCE(daily_metrics.revenue, 0)::numeric,
        2
    ) AS revenue,

    COALESCE(daily_metrics.orders, 0) AS orders,

    ROUND(
        COALESCE(daily_metrics.revenue, 0)::numeric
        / NULLIF(daily_metrics.orders, 0),
        2
    ) AS aov,

    ROUND(
        COALESCE(daily_metrics.orders, 0)::numeric
        / NULLIF(daily_metrics.sessions, 0),
        4
    ) AS conversion_rate,

    ROUND(
        COALESCE(daily_metrics.refunded_orders, 0)::numeric
        / NULLIF(daily_metrics.orders, 0),
        4
    ) AS refund_rate

FROM calendar

LEFT JOIN daily_metrics
    ON calendar.metric_date = daily_metrics.metric_date

ORDER BY calendar.metric_date DESC;


-- select * from ecom.sessions
