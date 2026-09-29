-- This SQL produces a changelog stream via COUNT(*) GROUP BY.
-- DEDUPLICATE_PTF must reject it at plan time with a ValidationException.
CREATE TEMPORARY TABLE orders (
    customer_id STRING,
    event_time  TIMESTAMP_LTZ(3),
    order_id    STRING,
    amount      DOUBLE,
    WATERMARK FOR event_time AS event_time - INTERVAL '10' SECOND
) WITH (
    'connector' = 'filesystem',
    'path' = 'src/test/resources/data-in/orders.txt',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TEMPORARY VIEW order_counts AS
SELECT customer_id, COUNT(*) AS order_count, MAX(event_time) AS last_event_time
FROM orders
GROUP BY customer_id;

SELECT *
FROM TABLE(
    DEDUPLICATE_PTF(
        TABLE order_counts PARTITION BY customer_id,
        'FIXED_INTERVAL',
        CAST(5000 AS BIGINT),
        DESCRIPTOR(last_event_time)
    )
);
