CREATE TEMPORARY TABLE orders (
    order_id STRING,
    active BOOLEAN,
    event_time TIMESTAMP_LTZ(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '10' SECOND
) WITH (
    'connector' = 'filesystem',
    'path' = 'src/test/resources/data-in/orders-row-partition-key-boolean.txt',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

SELECT *
FROM TABLE(
    DEDUPLICATE_PTF(
        TABLE orders PARTITION BY active,
        'INACTIVITY',
        CAST(5000 AS BIGINT),
        DESCRIPTOR(event_time)
    )
);
