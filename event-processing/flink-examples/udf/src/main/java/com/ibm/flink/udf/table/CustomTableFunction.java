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

import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.annotation.FunctionHint;
import org.apache.flink.table.functions.TableFunction;
import org.apache.flink.types.Row;

/**
 * Example implementation of a table Flink UDF which outputs multiple counters for an input string.
 * The input string is a sentence and the counters are about the words it contains.
 */
@FunctionHint(
    output = @DataTypeHint("ROW<word STRING, wordLength INT, wordIndex INT, totalWords BIGINT>")
)
public final class CustomTableFunction extends TableFunction<Row> {

    private static final long serialVersionUID = 1L;

    public void eval(String sentence) {
        if (sentence != null) {
            String[] words = sentence.split("\\s+");
  
            if (words.length == 0) {
                String word = "";
                int wordLength = 0;
                int wordIndex = 0;
                long totalWords = 0;
                
                collect(Row.of(word, wordLength, wordIndex, totalWords));
              
            } else {
                int wordIndex = 0;
                long totalWords = words.length;

                for (String word : words) {
                    collect(Row.of(word, word.length(), wordIndex++, totalWords));
                }
            }
        }
    }
}