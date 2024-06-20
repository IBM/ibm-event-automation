-- Copyright 2024 IBM Corp. All Rights Reserved.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

SET 'sql-client.execution.type' = 'streaming';
SET 'sql-client.execution.result-mode' = 'tableau';
SET 'table.display.max-column-width' = '40';
SET 'pipeline.name' = 'flink-table-udf';

CREATE TABLE `sentences` (
    `sentence` STRING
)
WITH (
    'connector' = 'filesystem',
    'path' = '/tmp/sentences.ndjson',
    'format' = 'json'
);

CREATE FUNCTION ANALYZE_STRING AS 'com.ibm.flink.udf.table.CustomTableFunction';

SELECT * FROM `sentences` LEFT JOIN LATERAL TABLE (ANALYZE_STRING(`sentence`)) ON TRUE;
