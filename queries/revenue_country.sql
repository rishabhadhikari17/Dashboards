WITH filtered_orders AS (
    SELECT DISTINCT
        orders.order_id,
        customers.country,
        orders.total
    FROM ecom.orders AS orders

    LEFT JOIN ecom.customers AS customers
        ON orders.customer_id = customers.customer_id

    LEFT JOIN ecom.attribution_touches AS attribution_touches
        ON orders.session_id = attribution_touches.session_id

    LEFT JOIN ecom.sessions AS sessions
        ON orders.session_id = sessions.session_id

    LEFT JOIN ecom.devices AS devices
        ON sessions.device_id = devices.device_id

    LEFT JOIN ecom.payment_intents AS payment_intents
        ON orders.order_id = payment_intents.order_id

    LEFT JOIN ecom.payment_methods AS payment_methods
        ON payment_intents.payment_method_id =
           payment_methods.payment_method_id

    WHERE orders.payment_status = 'paid'
        [[AND {{payment_method}}]]
        [[AND {{country}}]]
        [[AND {{Date_Range}}]]
        [[AND {{Acquisition_Channel}}]]
        [[AND {{device_type}}]]
)

SELECT
    country,
    SUM(total) AS revenue
FROM filtered_orders
GROUP BY country
ORDER BY revenue DESC;
