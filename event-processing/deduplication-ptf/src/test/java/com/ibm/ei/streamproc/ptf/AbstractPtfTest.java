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

package com.ibm.ei.streamproc.ptf;

import com.ibm.ei.streamproc.helper.PtfTableEnvironmentHelper;
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
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Abstract base class for testing IBM Event Processing Process Table Functions (PTFs).
 *
 * <p>This class provides common test infrastructure and utility methods for testing
 * Flink Process Table Functions. It creates a local Flink TableEnvironment,
 * registers the PTFs, executes SQL files, and returns the query results.
 */
public abstract class AbstractPtfTest {

    /**
     * Base path to SQL test files.
     */
    public static final Path SQL_FILE_PATH =
            Path.of("src/test/resources/sql-ptf").toAbsolutePath();

    /**
     * Flink table environment used for executing SQL queries.
     */
    private TableEnvironment tableEnv;

    /**
     * Creates the Flink TableEnvironment before each test and registers the PTFs.
     */
    @BeforeEach
    public void createTableEnvironment() {
        final LocalStreamEnvironment env =
                StreamExecutionEnvironment.createLocalEnvironment();

        tableEnv = StreamTableEnvironment.create(env);

        PtfTableEnvironmentHelper.registerProcessTableFunctions(tableEnv);
    }

    /**
     * Executes a SQL file and returns all output rows.
     *
     * @param sqlFileName SQL file inside src/test/resources/sql-ptf
     * @return all rows produced by the last SQL statement
     * @throws IOException if the SQL file cannot be read
     */
    protected final List<Row> customPtfTest(final String sqlFileName)
            throws IOException {

        final String sqlFilePath =
                SQL_FILE_PATH.resolve(sqlFileName).toString();

        final String[] sqlStatements = readSqlFromFile(sqlFilePath);

        final AtomicReference<TableResult> tableResult =
                new AtomicReference<>();

        for (final String sqlStatement : sqlStatements) {
            tableResult.set(tableEnv.executeSql(sqlStatement));
        }

        final List<Row> outputRows = new ArrayList<>();

        CloseableIterator<Row> results = tableResult.get().collect();

        while (results.hasNext()) {
            outputRows.add(results.next());
        }

        return outputRows;
    }

    /**
     * Reads SQL statements from a file and splits them into individual statements.
     *
     * @param filePath absolute path to the SQL file
     * @return array of SQL statements
     * @throws IOException if the file cannot be read
     */
    private String[] readSqlFromFile(final String filePath)
            throws IOException {

        final StringBuilder sqlStatement = new StringBuilder();

        try (BufferedReader reader = new BufferedReader(new FileReader(filePath))) {
            String line;

            while ((line = reader.readLine()) != null) {
                sqlStatement.append(line).append("\n");
            }
        }

        List<String> statements = new ArrayList<>();

        for (String statement : sqlStatement.toString().split(";")) {
            statement = statement.trim();

            if (!statement.isEmpty()) {
                statements.add(statement + ";");
            }
        }

        return statements.toArray(new String[0]);
    }
}
