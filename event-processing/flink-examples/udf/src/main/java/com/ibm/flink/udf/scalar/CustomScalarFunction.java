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

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.annotation.FunctionHint;
import org.apache.flink.table.functions.ScalarFunction;

/**
 * Example implementation of a scalar Flink UDF which converts a string into its base 64 encoding.
 * This is for illustration purposes only, as Flink provides the built-in TO_BASE64 function.
 */
public class CustomScalarFunction extends ScalarFunction {
    
    private static final long serialVersionUID = 1L;

    @FunctionHint(
        input = @DataTypeHint("STRING"),
        output = @DataTypeHint("STRING")
    )
    public String eval(String sentence) {
        return sentence != null 
                  ? Base64.getEncoder().encodeToString(sentence.getBytes(StandardCharsets.UTF_8))
                  : "";
    }
}
