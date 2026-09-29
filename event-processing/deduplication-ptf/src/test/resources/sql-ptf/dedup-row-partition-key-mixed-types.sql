CREATE TEMPORARY TABLE orders (
    order_id STRING,
    category STRING,
    price BIGINT,
    event_time TIMESTAMP_LTZ(3),
    WATERMARK FOR event_time AS event_time - INTERVAL '10' SECOND
) WITH (
    'connector' = 'filesystem',
    'path' = 'src/test/resources/data-in/orders-row-partition-key-mixed-types.txt',
    'format' = 'json',
    'json.timestamp-format.standard' = 'ISO-8601'
);

CREATE TEMPORARY VIEW orders_with_partition_key AS
SELECT
    order_id,
    category,
    price,
    event_time,
    ROW(category, price) AS partition_key
FROM orders;

SELECT *
FROM TABLE(
    DEDUPLICATE_PTF(
        TABLE orders_with_partition_key PARTITION BY partition_key,
        'INACTIVITY',
        CAST(5000 AS BIGINT),
        DESCRIPTOR(event_time)
    )
);
