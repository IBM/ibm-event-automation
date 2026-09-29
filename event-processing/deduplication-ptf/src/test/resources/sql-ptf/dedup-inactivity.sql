CREATE TEMPORARY TABLE orders (
    customer_id STRING,
    event_time TIMESTAMP_LTZ(3),
    order_id STRING,
    amount DOUBLE,
    WATERMARK FOR event_time AS event_time - INTERVAL '10' SECOND
) WITH (
    'connector' = 'filesystem',
    'path' = 'src/test/resources/data-in/orders.txt',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

SELECT *
FROM TABLE(
    DEDUPLICATE_PTF(
        TABLE orders PARTITION BY order_id,
        'INACTIVITY',
        CAST(5000 AS BIGINT),
        DESCRIPTOR(event_time)
    )
);