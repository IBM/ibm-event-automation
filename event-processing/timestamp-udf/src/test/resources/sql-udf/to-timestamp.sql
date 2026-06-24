CREATE TABLE `source`
(
    `jsonDate`  STRING,
    `timestamp` AS TO_TIMESTAMP_UDF(`jsonDate`)
) WITH (
  'connector' = 'filesystem',
  'path' = 'src/test/resources/data-in/timestamp.txt',
  'format' = 'json'
);
SELECT * FROM `source`