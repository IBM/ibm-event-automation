CREATE TEMPORARY TABLE orders (
    order_id STRING,
    tags ARRAY<STRING>,
    event_time TIMESTAMP_LTZ(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '10' SECOND
) WITH (
    'connector' = 'filesystem',
    'path' = 'src/test/resources/data-in/orders-row-partition-key-array.txt',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

SELECT *
FROM TABLE(
    DEDUPLICATE_PTF(
        TABLE orders PARTITION BY tags,
        'INACTIVITY',
        CAST(5000 AS BIGINT),
        DESCRIPTOR(event_time)
    )
);
