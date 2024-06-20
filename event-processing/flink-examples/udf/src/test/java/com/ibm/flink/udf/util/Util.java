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

package com.ibm.flink.udf.util;

import java.util.LinkedList;
import java.util.List;
import java.util.stream.Collectors;

import org.apache.flink.types.Row;

public class Util {

  /**
   * Extracts the values of the field name from the rowNumber'th position of a collection of {@link Row}.
   *
   * @param resultRows A collection of rows resulting from the output of a Flink job
   * @param rowNumber The index of the row to get from the collection
   * @param fieldNames The field names for which corresponding values must be retrieved in the row at index rowNumber
   * @return A comma-separated list of values corresponding to the field names
   */
  public static String getRowFields(List<Row> resultRows, int rowNumber, String... fieldNames) {
    List<Object> result = new LinkedList<>();
    if (fieldNames != null) {
      for (String field: fieldNames) {
        result.add(resultRows.get(rowNumber).getField(field));
      }
    }
    return result.stream().map(Object::toString).collect(Collectors.joining(", "));
  }

}
