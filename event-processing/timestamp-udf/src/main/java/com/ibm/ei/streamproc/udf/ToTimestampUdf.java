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

import org.apache.flink.table.functions.ScalarFunction;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;
import java.time.format.DateTimeParseException;
import java.util.Objects;

/**
 * A Flink User-Defined Function (UDF) for parsing ISO 8601 timestamp strings without timezone information
 * into Flink's TIMESTAMP type (represented as {@link LocalDateTime}).
 *
 * <p>This UDF is designed to handle ISO 8601 formatted timestamp strings that do not contain timezone
 * information. If a timezone is detected in the input string, the function returns {@code null}.
 *
 * <p><b>Supported Input Formats:</b>
 * <ul>
 *   <li>ISO 8601 date-time format: {@code "2024-01-15T10:30:45"}</li>
 *   <li>ISO 8601 with space separator: {@code "2024-01-15 10:30:45"}</li>
 *   <li>ISO 8601 with fractional seconds: {@code "2024-01-15T10:30:45.123"}</li>
 * </ul>
 *
 * <p><b>Usage example in Flink SQL:</b>
 * <pre>{@code
 * -- Register the function
 * CREATE FUNCTION TO_TIMESTAMP_UDF AS 'com.ibm.ei.streamproc.udf.ToTimestampUdf';
 *
 * -- Use in SQL query
 * SELECT TO_TIMESTAMP_UDF(`a_timestamp_string`) AS `a_timestamp` FROM a_table;
 * }</pre>
 *
 * <p><b>Return Value:</b>
 * <ul>
 *   <li>Returns {@link LocalDateTime} for valid timestamp strings without timezone</li>
 *   <li>Returns {@code null} for:
 *     <ul>
 *       <li>Null input</li>
 *       <li>Strings containing timezone information</li>
 *       <li>Invalid timestamp formats</li>
 *       <li>Any parsing errors</li>
 *     </ul>
 *   </li>
 * </ul>
 *
 * <p><b>Thread Safety:</b> This class is thread-safe. The {@link DateTimeFormatterBuilder} is immutable
 * and the {@code eval} method is stateless.
 *
 * @see ToTimestampLtzUdf for parsing timestamps with timezone information
 */
public class ToTimestampUdf extends ScalarFunction {
    private static final Logger log = LogManager.getLogger(ToTimestampUdf.class);
    
    /**
     * Reusable DateTimeFormatter for parsing ISO 8601 timestamps without timezone.
     * This formatter is thread-safe and immutable, created once and reused for all parsing operations.
     */
    private static final DateTimeFormatter FORMATTER = new DateTimeFormatterBuilder()
            .appendOptional(DateTimeFormatter.ISO_DATE_TIME)
            .appendOptional(new DateTimeFormatterBuilder()
                    .append(DateTimeFormatter.ISO_DATE)
                    .appendLiteral(' ')
                    .append(DateTimeFormatter.ISO_TIME)
                    .toFormatter()
            )
            .toFormatter();

    /**
     * Evaluates the UDF by parsing an ISO 8601 timestamp string without timezone into a {@link LocalDateTime}.
     *
     * <p>This method is called by Flink's Table API for each row in the input data. It attempts to parse
     * the input string using ISO 8601 formats, but only accepts timestamps without timezone information.
     *
     * @param ts the ISO 8601 timestamp string to parse (e.g., "2024-01-15T10:30:45" or "2024-01-15 10:30:45").
     *           May be {@code null}.
     * @return a {@link LocalDateTime} representing the parsed timestamp, or {@code null} if:
     *         <ul>
     *           <li>the input is {@code null}</li>
     *           <li>the input contains timezone information</li>
     *           <li>the input cannot be parsed as a valid ISO 8601 timestamp</li>
     *           <li>any runtime error occurs during parsing</li>
     *         </ul>
     *
     * @see LocalDateTime
     * @see DateTimeFormatter#ISO_DATE_TIME
     */
    public static LocalDateTime eval(final String ts) {
        try {
            if (Objects.isNull(ts) || hasTimeZone(ts)) {
                return null;
            }
            return FORMATTER.parse(ts, LocalDateTime::from);
        } catch (final DateTimeParseException e) {
            return null;
        } catch (final RuntimeException e) {
            log.error(e);
            return null;
        }
    }

    /**
     * Checks whether the given timestamp string contains timezone information.
     *
     * <p>This method attempts to parse the input string as an {@link OffsetDateTime}. If successful,
     * it indicates that the string contains timezone information (e.g., "+01:00" or "Z").
     *
     * @param ts the timestamp string to check for timezone information. Must not be {@code null}.
     * @return {@code true} if the string contains timezone information and can be parsed as
     *         {@link OffsetDateTime}; {@code false} if it cannot be parsed with timezone information
     *         (indicating it's a local timestamp without timezone)
     *
     * @see OffsetDateTime
     */
    private static boolean hasTimeZone(final String ts) {
        try {
            OffsetDateTime.parse(ts, FORMATTER);
            return true;
        } catch (final DateTimeParseException e) {
            return false;
        }
    }
}
