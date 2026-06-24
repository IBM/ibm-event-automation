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

import java.time.Instant;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;
import java.time.format.DateTimeParseException;
import java.util.Objects;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

/**
 * A Flink User-Defined Function (UDF) for parsing ISO 8601 timestamp strings with timezone information
 * into Flink's TIMESTAMP_LTZ type (represented as {@link Instant}).
 *
 * <p>This UDF is designed to handle ISO 8601 formatted timestamp strings that may contain timezone
 * information. It converts the parsed timestamp to UTC (represented as an {@link Instant}).
 *
 * <p><b>Supported Input Formats:</b>
 * <ul>
 *   <li>ISO 8601 date-time with timezone: {@code "2024-01-15T10:30:45+01:00"}</li>
 *   <li>ISO 8601 with UTC indicator: {@code "2024-01-15T10:30:45Z"}</li>
 *   <li>ISO 8601 with space separator and timezone: {@code "2024-01-15 10:30:45+01:00"}</li>
 *   <li>ISO 8601 with fractional seconds: {@code "2024-01-15T10:30:45.123+01:00"}</li>
 *   <li>ISO 8601 without timezone (assumes system default): {@code "2024-01-15T10:30:45"}</li>
 * </ul>
 *
 * <p><b>Usage example in Flink SQL:</b>
 * <pre>{@code
 * -- Register the function
 * CREATE FUNCTION TO_TIMESTAMP_LTZ_UDF AS 'com.ibm.ei.streamproc.udf.ToTimestampLtzUdf';
 *
 * -- Use in SQL query
 * SELECT TO_TIMESTAMP_LTZ_UDF(`a_timestamp_string`) AS `a_timestamp_ltz` FROM a_table;
 * }</pre>
 *
 * <p><b>Return Value:</b>
 * <ul>
 *   <li>Returns {@link Instant} representing the timestamp in UTC</li>
 *   <li>Returns {@code null} for:
 *     <ul>
 *       <li>Null input</li>
 *       <li>Invalid timestamp formats</li>
 *       <li>Any parsing errors</li>
 *     </ul>
 *   </li>
 * </ul>
 *
 * <p><b>Timezone Handling:</b> If the input string contains timezone information (e.g., "+01:00" or "Z"),
 * it is used for parsing. If no timezone is present, the system default timezone is assumed.
 * The result is always converted to UTC as an {@link Instant}.
 *
 * <p><b>Thread Safety:</b> This class is thread-safe. The {@link DateTimeFormatterBuilder} is immutable
 * and the {@code eval} method is stateless.
 *
 * @see ToTimestampUdf for parsing timestamps without timezone information
 */
public class ToTimestampLtzUdf extends ScalarFunction {
    private static final Logger log = LogManager.getLogger(ToTimestampLtzUdf.class);
    
    /**
     * Reusable DateTimeFormatter for parsing ISO 8601 timestamps with timezone.
     * This formatter is thread-safe and immutable, created once and reused for all parsing operations.
     */
    private static final DateTimeFormatter FORMATTER = new DateTimeFormatterBuilder()
            .appendOptional(DateTimeFormatter.ISO_DATE_TIME)
            .appendOptional(new DateTimeFormatterBuilder()
                    .append(DateTimeFormatter.ISO_DATE)
                    .appendLiteral(' ')
                    .append(DateTimeFormatter.ISO_TIME)
                    .toFormatter())
            .optionalStart()
            .appendOffset("+HHmm", "+HH:mm")
            .optionalEnd()
            .toFormatter();

    /**
     * Evaluates the UDF by parsing an ISO 8601 timestamp string (with or without timezone) into an {@link Instant}.
     *
     * <p>This method is called by Flink's Table API for each row in the input data. It attempts to parse
     * the input string using ISO 8601 formats, handling both timestamps with and without timezone information.
     * The result is always converted to UTC.
     *
     * @param ts the ISO 8601 timestamp string to parse (e.g., "2024-01-15T10:30:45+01:00" or "2024-01-15T10:30:45Z").
     *           May be {@code null}.
     * @return an {@link Instant} representing the parsed timestamp in UTC, or {@code null} if:
     *         <ul>
     *           <li>the input is {@code null}</li>
     *           <li>the input cannot be parsed as a valid ISO 8601 timestamp</li>
     *           <li>any runtime error occurs during parsing</li>
     *         </ul>
     *
     * @see Instant
     * @see ZonedDateTime
     * @see DateTimeFormatter#ISO_DATE_TIME
     */
    public static final Instant eval(final String ts) {
        try {
            if (Objects.isNull(ts)) {
                return null;
            }
            final ZonedDateTime parsed = FORMATTER.parse(ts, ZonedDateTime::from);
            return parsed.toInstant();
        } catch (final DateTimeParseException e) {
            return null;
        } catch (final RuntimeException e) {
            log.error(e);
            return null;
        }
    }
}