/**
 * Copyright 2024 IBM Corp. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

package com.ibm.flink.udf.scalar;

import java.util.LinkedList;
import java.util.concurrent.TimeUnit;

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.types.Row;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static com.ibm.flink.udf.util.Util.getRowFields;

public class CustomScalarFunctionTest {
  @Test
  public void test() throws Exception {
    // Given
    
    EnvironmentSettings settings = EnvironmentSettings.newInstance().inStreamingMode().build();
    TableEnvironment tEnv = TableEnvironment.create(settings);

    tEnv.executeSql(
        "CREATE FUNCTION ENCODE_BASE64 AS 'com.ibm.flink.udf.scalar.CustomScalarFunction'"
    );
    
    tEnv.executeSql(
        "CREATE TABLE `Source` (`sentence` STRING) "
        + "WITH ("
        + " 'connector' = 'filesystem',"
        + " 'format' = 'json',"
        + " 'path' = 'sql/sentences.ndjson'"
        + ")"
    );
    
    // When

    TableResult tResult = tEnv.executeSql(
        "SELECT `sentence`, ENCODE_BASE64(`sentence`) as `encoded` FROM `Source`"
    );
    tResult.await(60, TimeUnit.SECONDS);

    // Then
    
    LinkedList<Row> rows = new LinkedList<>();
    tResult.collect().forEachRemaining(rows::add);
    
    assertEquals(2, rows.size());
    
    assertEquals(
        "A first sentence to process, QSBmaXJzdCBzZW50ZW5jZSB0byBwcm9jZXNz",
        getRowFields(rows, 0, "sentence", "encoded"));
    
    assertEquals(
        "The second and last sentence to process, VGhlIHNlY29uZCBhbmQgbGFzdCBzZW50ZW5jZSB0byBwcm9jZXNz",
        getRowFields(rows, 1, "sentence", "encoded"));
  }
}
