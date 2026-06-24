/*
 * Copyright IBM Corp. 2024, 2026
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.ibm.ei.streamproc.helper;

import com.ibm.ei.streamproc.udf.ToTimestampLtzUdf;
import com.ibm.ei.streamproc.udf.ToTimestampUdf;
import org.apache.flink.table.api.TableEnvironment;

import java.util.Objects;

/**
 * Helper utility class for registering IBM Event Processing timestamp User-Defined Functions (UDFs)
 * with a Flink {@link TableEnvironment}.
 *
 * <p>This class provides convenience methods to register all timestamp parsing UDFs in a single call,
 * simplifying the setup process for Flink applications that need to parse ISO 8601 timestamp strings.
 *
 * @see ToTimestampUdf
 * @see ToTimestampLtzUdf
 * @see TableEnvironment
 */
public class TableEnvironmentHelper {

    /**
     * Registers all IBM Event Processing timestamp UDFs with the provided Flink {@link TableEnvironment}.
     *
     * <p>This method registers the following functions as temporary system functions:
     * <ul>
     *   <li>{@code TO_TIMESTAMP_UDF} - {@link ToTimestampUdf} for parsing timestamps without timezone</li>
     *   <li>{@code TO_TIMESTAMP_LTZ_UDF} - {@link ToTimestampLtzUdf} for parsing timestamps with timezone</li>
     * </ul>
     *
     * <p>These functions are registered as temporary system functions, meaning they are available
     * for the lifetime of the {@link TableEnvironment} and can be used in all SQL queries executed
     * within that environment.
     *
     * @param tableEnv the Flink {@link TableEnvironment} in which to register the UDFs. Must not be {@code null}.
     * @throws NullPointerException if {@code tableEnv} is {@code null}
     *
     * @see TableEnvironment#createTemporarySystemFunction(String, Class)
     * @see ToTimestampUdf
     * @see ToTimestampLtzUdf
     */
    public static void registerTimestampFunctions(final TableEnvironment tableEnv) {
        Objects.requireNonNull(tableEnv, "TableEnvironment must not be null");
        tableEnv.createTemporarySystemFunction("TO_TIMESTAMP_UDF", ToTimestampUdf.class);
        tableEnv.createTemporarySystemFunction("TO_TIMESTAMP_LTZ_UDF", ToTimestampLtzUdf.class);
    }
}
