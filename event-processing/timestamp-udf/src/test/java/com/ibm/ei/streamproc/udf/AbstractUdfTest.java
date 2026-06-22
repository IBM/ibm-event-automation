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

package com.ibm.ei.streamproc.udf;

import com.ibm.ei.streamproc.helper.TableEnvironmentHelper;
import org.apache.flink.streaming.api.environment.LocalStreamEnvironment;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.table.api.TableResult;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.types.Row;
import org.apache.flink.util.CloseableIterator;
import org.junit.jupiter.api.BeforeEach;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.nio.file.Path;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;

/**
 * Abstract base class for testing IBM Event Processing timestamp User-Defined Functions (UDFs).
 *
 * <p>This class provides common test infrastructure and utility methods for testing Flink UDFs
 * that parse ISO 8601 timestamp strings. It sets up a local Flink execution environment,
 * registers the timestamp UDFs, and provides helper methods for executing SQL test files
 * and asserting results.
 *
 * <p><b>Test Infrastructure:</b>
 * <ul>
 *   <li>Creates a local Flink {@link StreamExecutionEnvironment} for each test</li>
 *   <li>Registers timestamp UDFs using {@link TableEnvironmentHelper}</li>
 *   <li>Executes SQL statements from test resource files</li>
 *   <li>Provides assertion helpers for different timestamp types</li>
 * </ul>
 */
public abstract class AbstractUdfTest {
    /**
     * Base path to SQL test files containing UDF test queries.
     * Points to {@code src/test/resources/sql-udf/} directory.
     */
    final static public Path SQL_FILE_PATH = Path.of("src/test/resources/sql-udf/")
        .toAbsolutePath();

    /**
     * Flink table environment used for executing SQL queries in tests.
     */
    private TableEnvironment tableEnv;

    /**
     * Sets up the Flink test environment before each test method.
     *
     * <p>Creates a local Flink streaming environment, initializes a {@link StreamTableEnvironment},
     * and registers all timestamp UDFs using {@link TableEnvironmentHelper#registerTimestampFunctions(TableEnvironment)}.
     *
     * <p>This method is automatically called by JUnit before each test method execution.
     *
     * @see TableEnvironmentHelper#registerTimestampFunctions(TableEnvironment)
     */
    @BeforeEach
    public void createTableEnvironment() {
        final LocalStreamEnvironment env = StreamExecutionEnvironment.createLocalEnvironment();
        tableEnv = StreamTableEnvironment.create(env);
        TableEnvironmentHelper.registerTimestampFunctions(tableEnv);
    }

    /**
     * Executes a SQL test file and returns the transformed column values from the result.
     *
     * <p>This method reads SQL statements from the specified file, executes them sequentially
     * in the Flink table environment, and collects the second column (index 1) from each
     * result row. This is typically the column containing the UDF transformation result.
     *
     * <p><b>SQL File Format:</b> The SQL file should contain one or more SQL statements
     * separated by semicolons. Each statement is executed in order, and the result of
     * the last statement is collected.
     *
     * @param sqlFileName the name of the SQL file in the {@link #SQL_FILE_PATH} directory
     *                    (e.g., "to-timestamp.sql")
     * @return a list of objects from the second column of the query result, representing
     *         the UDF transformation results. May contain {@code null} values for failed transformations.
     * @throws IOException if the SQL file cannot be read
     *
     * @see #readSqlFromFile(String)
     */
    protected final List<Object> customUdfTest(final String sqlFileName) throws IOException {
        final String sqlFilePath = SQL_FILE_PATH + "/" + sqlFileName;
        final String[] sqlStatements = readSqlFromFile(sqlFilePath);
        final AtomicReference<TableResult> tableResult = new AtomicReference<>();
        for (final String sqlStatement : sqlStatements) {
            tableResult.set(tableEnv.executeSql(sqlStatement));
        }
        final List<Object> transformedColumn = new ArrayList<>();
        final CloseableIterator<Row> results = tableResult.get().collect();
        while (results.hasNext()) {
            final Row row = results.next();
            transformedColumn.add(row.getField(1));
        }
        return transformedColumn;
    }
    /**
     * Asserts that a field result is a {@link LocalDateTime} with the expected string representation.
     *
     * <p>This assertion is used for testing {@code TO_TIMESTAMP_UDF} results, which return
     * {@link LocalDateTime} objects for timestamps without timezone information.
     *
     * @param fieldResult the actual result from the UDF (expected to be {@link LocalDateTime})
     * @param expectedString the expected string representation of the timestamp
     *                       (e.g., "1971-01-01T00:00:00.123")
     *
     * @throws AssertionError if the result is not a {@link LocalDateTime} or doesn't match
     *                        the expected string
     *
     * @see ToTimestampUdf
     * @see LocalDateTime
     */
    protected void assertTimestamp(final Object fieldResult, final String expectedString) {
        assertInstanceOf(LocalDateTime.class, fieldResult);
        assertEquals(expectedString, fieldResult.toString());
    }

    /**
     * Asserts that a field result is an {@link Instant} with the expected string representation.
     *
     * <p>This assertion is used for testing {@code TO_TIMESTAMP_LTZ_UDF} results, which return
     * {@link Instant} objects representing timestamps in UTC.
     *
     * @param fieldResult the actual result from the UDF (expected to be {@link Instant})
     * @param expectedString the expected string representation of the instant in UTC
     *                       (e.g., "1970-12-31T16:00:00.123Z")
     *
     * @throws AssertionError if the result is not an {@link Instant} or doesn't match
     *                        the expected string
     *
     * @see ToTimestampLtzUdf
     * @see Instant
     */
    protected void assertTimestampLtz(final Object fieldResult, final String expectedString) {
        assertInstanceOf(Instant.class, fieldResult);
        assertEquals(expectedString, fieldResult.toString());
    }
    /**
     * Asserts that a field result matches the expected value for error cases.
     *
     * <p>This assertion is used for testing UDF behavior with invalid input, where the UDF
     * is expected to return {@code null} or a specific error value.
     *
     * @param fieldResult the actual result from the UDF (typically {@code null} for errors)
     * @param expectedString the expected value (typically {@code null} for parsing errors)
     *
     * @throws AssertionError if the result doesn't match the expected value
     */
    protected void assertErrorTimestamp(final Object fieldResult, final String expectedString) {
        assertEquals(expectedString, fieldResult);
    }

    /**
     * Reads SQL statements from a file and splits them into individual statements.
     *
     * <p>This method reads the entire SQL file, splits it by semicolons to separate
     * individual statements, trims whitespace, and ensures each statement ends with
     * a semicolon.
     *
     * @param filePath the absolute path to the SQL file to read
     * @return an array of SQL statements, each trimmed and ending with a semicolon
     * @throws IOException if the file cannot be read
     */
    private String[] readSqlFromFile(final String filePath) throws IOException {
        final StringBuilder sqlStatement = new StringBuilder();
        try (final BufferedReader reader = new BufferedReader(new FileReader(filePath))) {
            String line;
            while ((line = reader.readLine()) != null) {
                sqlStatement.append(line).append("\n");
            }
        }
        final String[] statements = sqlStatement.toString().split(";");

        for (int i = 0; i < statements.length; i++) {
            statements[i] = statements[i].trim().concat(";");
        }
        return statements;
    }
}
