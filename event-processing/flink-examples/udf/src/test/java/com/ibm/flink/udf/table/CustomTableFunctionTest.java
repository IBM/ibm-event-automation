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

package com.ibm.flink.udf.table;

import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.types.Row;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static com.ibm.flink.udf.util.Util.getRowFields;

public class CustomTableFunctionTest {

  @Test
  public void test() throws Exception {
    // Given
    
    EnvironmentSettings settings = EnvironmentSettings.newInstance().inStreamingMode().build();
    TableEnvironment tEnv = TableEnvironment.create(settings);

    tEnv.executeSql(
        "CREATE FUNCTION ANALYZE_STRING AS 'com.ibm.flink.udf.table.CustomTableFunction'"
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
        "SELECT `sentence`, `word`, `wordLength`, `wordIndex`, `totalWords` FROM `Source` LEFT JOIN LATERAL TABLE (ANALYZE_STRING(`sentence`)) ON TRUE;"
    );
    tResult.await(60, TimeUnit.SECONDS);

    // Then
    
    List<Row> rows = new LinkedList<>();
    tResult.collect().forEachRemaining(rows::add);
    
    assertEquals(12, rows.size());
    
    // -- first sentence
    
    assertEquals(
        "A first sentence to process, A, 1, 0, 5",
        getRowFields(rows, 0, "sentence", "word", "wordLength", "wordIndex", "totalWords"));

    assertEquals(
        "A first sentence to process, first, 5, 1, 5",
        getRowFields(rows, 1, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
    
    assertEquals(
        "A first sentence to process, sentence, 8, 2, 5",
        getRowFields(rows, 2, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
    
    assertEquals(
        "A first sentence to process, to, 2, 3, 5",
        getRowFields(rows, 3, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
    
    assertEquals(
        "A first sentence to process, process, 7, 4, 5",
        getRowFields(rows, 4, "sentence", "word", "wordLength", "wordIndex", "totalWords"));

    // -- second sentence
    
    assertEquals(
        "The second and last sentence to process, The, 3, 0, 7",
        getRowFields(rows, 5, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
    
    assertEquals(
        "The second and last sentence to process, second, 6, 1, 7",
        getRowFields(rows, 6, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
    
    assertEquals(
        "The second and last sentence to process, and, 3, 2, 7",
        getRowFields(rows, 7, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
    
    assertEquals(
        "The second and last sentence to process, last, 4, 3, 7",
        getRowFields(rows, 8, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
    
    assertEquals(
        "The second and last sentence to process, sentence, 8, 4, 7",
        getRowFields(rows, 9, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
    
    assertEquals(
        "The second and last sentence to process, to, 2, 5, 7",
        getRowFields(rows, 10, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
    
    assertEquals(
        "The second and last sentence to process, process, 7, 6, 7",
        getRowFields(rows, 11, "sentence", "word", "wordLength", "wordIndex", "totalWords"));
  }
}
