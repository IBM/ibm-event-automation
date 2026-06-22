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

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Integration tests for IBM Event Processing timestamp User-Defined Functions (UDFs).
 *
 * <p>This test class verifies the behavior of {@link ToTimestampUdf} and {@link ToTimestampLtzUdf}
 * by executing SQL queries from test resource files and asserting the transformation results.
 *
 * <p><b>Test Coverage:</b>
 * <ul>
 *   <li>{@link #timestampUdf()} - Tests {@code TO_TIMESTAMP_UDF} for parsing timestamps without timezone</li>
 *   <li>{@link #timestampLtzUdf()} - Tests {@code TO_TIMESTAMP_LTZ_UDF} for parsing timestamps with timezone</li>
 * </ul>
 *
 * <p><b>Test Data:</b> Test SQL files are located in {@code src/test/resources/sql-udf/}
 * and contain various ISO 8601 timestamp formats including edge cases and error scenarios.
 */
public class TimestampTest extends AbstractUdfTest {

    /**
     * Tests the {@code TO_TIMESTAMP_UDF} function with various ISO 8601 timestamp formats.
     *
     * <p>This test verifies that the UDF correctly parses timestamps without timezone information
     * and returns {@link java.time.LocalDateTime} objects. It also tests error handling for invalid inputs
     * such as timestamps with timezone information, which should return {@code null}.
     *
     * <p><b>Test Cases:</b>
     * <ul>
     *   <li>Basic timestamp: "1971-01-01T00:00"</li>
     *   <li>Timestamps with varying fractional second precision (milliseconds to nanoseconds)</li>
     *   <li>Error cases: timestamps with timezone information (should return {@code null})</li>
     *   <li>Error cases: invalid formats (should return {@code null})</li>
     * </ul>
     *
     * @throws Exception if SQL execution or file reading fails
     *
     * @see ToTimestampUdf
     * @see AbstractUdfTest_old#customUdfTest(String)
     */
    @Test
    @DisplayName("To_Timestamp test")
    public void timestampUdf() throws Exception {
        final List<Object> results = customUdfTest(
            "to-timestamp.sql");
        assertEquals(15, results.size());
        assertTimestamp(results.get(0), "1971-01-01T00:00");
        assertTimestamp(results.get(1), "1971-01-01T00:00:00.123");
        assertTimestamp(results.get(2), "1971-01-01T00:00:00.123400");
        assertTimestamp(results.get(3), "1971-01-01T00:00:00.123450");
        assertTimestamp(results.get(4), "1971-01-01T00:00:00.123456");
        assertTimestamp(results.get(5), "1971-01-01T00:00:00.123456700");
        assertTimestamp(results.get(6), "1971-01-01T00:00:00.123456780");
        assertTimestamp(results.get(7), "1971-01-01T00:00:00.123456789");
        assertErrorTimestamp(results.get(8), null);
        assertErrorTimestamp(results.get(9), null);
        assertErrorTimestamp(results.get(10), null);
        assertErrorTimestamp(results.get(11), null);
        assertErrorTimestamp(results.get(12), null);
        assertErrorTimestamp(results.get(13), null);
        assertErrorTimestamp(results.get(14), null);
    }

    /**
     * Tests the {@code TO_TIMESTAMP_LTZ_UDF} function with various ISO 8601 timestamp formats.
     *
     * <p>This test verifies that the UDF correctly parses timestamps with timezone information
     * and returns {@link java.time.Instant} objects representing the timestamp in UTC. It tests various
     * timezone offsets and fractional second precisions.
     *
     * <p><b>Test Cases:</b>
     * <ul>
     *   <li>Timestamps with timezone offset: "1971-01-01T00:00:00.123+08:00"</li>
     *   <li>Timestamps with varying fractional second precision (milliseconds to nanoseconds)</li>
     *   <li>Different timezone offsets: +00:00, +00:30, +01:30</li>
     *   <li>Conversion to UTC: all results are returned as {@link java.time.Instant} in UTC</li>
     *   <li>Error cases: invalid formats (should return {@code null})</li>
     * </ul>
     *
     * @throws Exception if SQL execution or file reading fails
     *
     * @see ToTimestampLtzUdf
     * @see AbstractUdfTest_old#customUdfTest(String)
     */
    @Test
    @DisplayName("To_Timestamp_ltz test")
    public void timestampLtzUdf() throws Exception {
        final List<Object> results = customUdfTest(
            "to-timestamp-ltz.sql");
        assertEquals(12, results.size());
        assertTimestampLtz(results.get(0), "1970-12-31T16:00:00.123Z");
        assertTimestampLtz(results.get(1), "1970-12-31T16:00:00.123400Z");
        assertTimestampLtz(results.get(2), "1970-12-31T16:00:00.123450Z");
        assertTimestampLtz(results.get(3), "1970-12-31T16:00:00.123456Z");
        assertTimestampLtz(results.get(4), "1970-12-31T16:00:00.123456700Z");
        assertTimestampLtz(results.get(5), "1970-12-31T16:00:00.123456780Z");
        assertTimestampLtz(results.get(6), "1970-12-31T16:00:00.123456789Z");
        assertTimestampLtz(results.get(7), "2024-02-20T20:11:41.123456789Z");
        assertTimestampLtz(results.get(8), "2024-02-20T20:41:41.123456789Z");
        assertTimestampLtz(results.get(9), "2024-02-20T21:41:41.123456789Z");
        assertErrorTimestamp(results.get(10), null);
        assertErrorTimestamp(results.get(11), null);
    }
}
