CREATE TABLE `source`
(
    `jsonDate`  STRING,
    `timestamp` AS TO_TIMESTAMP_LTZ_UDF(`jsonDate`)
) WITH (
  'connector' = 'filesystem',
  'path' = 'src/test/resources/data-in/timestamp-tz.txt',
  'format' = 'json'
);
SELECT * FROM `source`