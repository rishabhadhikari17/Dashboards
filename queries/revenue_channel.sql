select attribution_touches.channel, sum(total) from ecom.orders
left join ecom.customers on orders.customer_id = customers.customer_id
left join ecom.attribution_touches on orders.session_id =attribution_touches.session_id 
left join ecom.sessions on orders.session_id =sessions.session_id 
left join ecom.devices on sessions.device_id =devices.device_id
LEFT JOIN ecom.payment_intents on orders.order_id = payment_intents.order_id
LEFT JOIN ecom.payment_methods on payment_intents.payment_method_id = payment_methods.payment_method_id
WHERE payment_status = 'paid' [[and {{payment_method}}]] [[and {{country}}]] [[and {{Date_Range}}]] [[and {{Acquisition_Channel}}]] [[and {{device_type}}]]
group by attribution_touches.channel;
