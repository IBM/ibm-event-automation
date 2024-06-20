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

import static org.apache.flink.table.api.Expressions.$;
import static org.apache.flink.table.api.Expressions.call;
import static org.apache.flink.table.api.Expressions.row;

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableEnvironment;

/**
 * Example class to test a UDF scalar function.
 * This class is not included in the JAR built by this project.
 */
public class StandaloneDryRun {

    /**
     * This entry point can be executed in a Java Integrated Development Environment (IDE)
     * to deploy and process the rows from the input table with the UDF scalar function.
     */
    public static void main(String[] args) {
        EnvironmentSettings settings = EnvironmentSettings.newInstance().inStreamingMode().build();
        
        TableEnvironment tEnv = TableEnvironment.create(settings);
        
        tEnv.createTemporarySystemFunction("encode_sentence", new CustomScalarFunction());  
        
        Table input = tEnv.fromValues(
                              row("First line"),
                              row("Second and last line"))
                          .as("sentence");
            
        Table table = input.select($("sentence"), call("encode_sentence", $("sentence")))
                           .as("sentence", "base64");
    
        table.execute().print();
    
        // Output at runtime  
        //    +----+--------------------------------+--------------------------------+
        //    | op |                       sentence |                         base64 |
        //    +----+--------------------------------+--------------------------------+
        //    | +I |                     First line |               Rmlyc3QgbGluZQ== |
        //    | +I |           Second and last line |   U2Vjb25kIGFuZCBsYXN0IGxpbmU= |
        //    +----+--------------------------------+--------------------------------+
        //    2 rows in set    
    }
}
