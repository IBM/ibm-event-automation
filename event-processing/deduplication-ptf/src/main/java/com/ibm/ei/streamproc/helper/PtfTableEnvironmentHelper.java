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

import com.ibm.ei.streamproc.ptf.DeduplicationPTF;
import org.apache.flink.table.api.TableEnvironment;

import java.util.Objects;

/**
 * Helper utility class for registering IBM Event Processing deduplication Process Table Functions (PTFs)
 * with a Flink {@link TableEnvironment}.
 *
 * <p>This class provides convenience methods to register the deduplication PTF in a single call,
 * simplifying the setup process for Flink applications that need event deduplication capabilities.
 *
 * <p><b>Usage Example:</b>
 * <pre>{@code
 * StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
 * TableEnvironment tableEnv = StreamTableEnvironment.create(env);
 * 
 * // Register the deduplication PTF
 * PtfTableEnvironmentHelper.registerProcessTableFunctions(tableEnv);
 * 
 * // Now you can use it in SQL
 * tableEnv.executeSql(
 *     "SELECT * FROM TABLE(" +
 *     "  DEDUPLICATE_PTF(" +
 *     "    TABLE source_table," +
 *     "    DESCRIPTOR(event_time)," +
 *     "    'FIXED_INTERVAL'," +
 *     "    60000" +
 *     "  )" +
 *     ")"
 * );
 * }</pre>
 *
 * @see DeduplicationPTF
 * @see TableEnvironment
 */
public class PtfTableEnvironmentHelper {

    /**
     * Private constructor to prevent instantiation of this utility class.
     */
    private PtfTableEnvironmentHelper() {
        throw new UnsupportedOperationException("This is a utility class and cannot be instantiated");
    }

    /**
     * Registers the IBM Event Processing deduplication PTF with the provided Flink {@link TableEnvironment}.
     *
     * <p>This method registers the following function as a temporary system function:
     * <ul>
     *   <li>{@code DEDUPLICATE_PTF} - {@link DeduplicationPTF} for event deduplication</li>
     * </ul>
     *
     * <p>The function is registered as a temporary system function, meaning it is available
     * for the lifetime of the {@link TableEnvironment} and can be used in all SQL queries executed
     * within that environment.
     *
     * <p><b>Deduplication Modes:</b>
     * <ul>
     *   <li><b>FIXED_INTERVAL:</b> Filters duplicates within fixed time windows</li>
     *   <li><b>SESSION:</b> Filters duplicates based on session timeout (inactivity)</li>
     * </ul>
     *
     * @param tableEnv the Flink {@link TableEnvironment} in which to register the PTF. Must not be {@code null}.
     * @throws NullPointerException if {@code tableEnv} is {@code null}
     *
     * @see TableEnvironment#createTemporarySystemFunction(String, Class)
     * @see DeduplicationPTF
     */
    public static void registerProcessTableFunctions(final TableEnvironment tableEnv) {
        Objects.requireNonNull(tableEnv, "TableEnvironment must not be null");
        tableEnv.createTemporarySystemFunction("DEDUPLICATE_PTF", DeduplicationPTF.class);
    }
}
