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

import org.apache.flink.types.Row;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

public class DeduplicationPTFTest extends AbstractPtfTest {

    @Test
    @DisplayName("Inactivity mode - duplicate events")
    public void inactivityDuplicateEvents() throws Exception {

        List<Row> results = customPtfTest("dedup-inactivity.sql");

        // One duplicate should be removed
        assertEquals(2, results.size());

        boolean foundO1 = false;
        boolean foundO2 = false;

        for (Row row : results) {

            String orderId = (String) row.getField(3);

            if ("O1".equals(orderId)) {
                foundO1 = true;
                assertEquals("C1", row.getField(1));
                assertEquals(100.0, row.getField(4));
                assertEquals(
                        "2025-01-01T10:00:00Z",
                        row.getField(2).toString());
            }

            if ("O2".equals(orderId)) {
                foundO2 = true;
                assertEquals("C1", row.getField(1));
                assertEquals(200.0, row.getField(4));
                assertEquals(
                        "2025-01-01T10:00:02Z",
                        row.getField(2).toString());
            }
        }

        assertTrue(foundO1);
        assertTrue(foundO2);
    }

    @Test
    @DisplayName("Inactivity mode - duplicate events extend active window")
    public void inactivityModeExtendsWindow() throws Exception {

        List<Row> results = customPtfTest("dedup-inactivity-extension.sql");

        // Duplicate events extend the inactivity window, so only the first
        // and the event after the inactivity gap should be emitted.
        assertEquals(2, results.size());

        Row firstEvent = results.get(0);
        Row secondEvent = results.get(1);

        // Verify the correct events were emitted, not just the number of events.
        assertEquals("O1", firstEvent.getField(3));
        assertEquals("2025-01-01T10:00:00Z", firstEvent.getField(2).toString());

        assertEquals("O1", secondEvent.getField(3));
        assertEquals("2025-01-01T10:00:12Z", secondEvent.getField(2).toString());
    }

    @Test
    @DisplayName("Fixed interval mode does not extend window")
    public void fixedIntervalDoesNotExtendWindow() throws Exception {

        List<Row> results = customPtfTest("dedup-fixed-interval.sql");

        // Fixed interval mode does not extend the window, so events at
        // 0s, 6s and 12s should be emitted.
        assertEquals(3, results.size());

        assertEquals("O1", results.get(0).getField(3));
        assertEquals(
                "2025-01-01T10:00:00Z",
                results.get(0).getField(2).toString());

        assertEquals("O1", results.get(1).getField(3));
        assertEquals(
                "2025-01-01T10:00:06Z",
                results.get(1).getField(2).toString());

        assertEquals("O1", results.get(2).getField(3));
        assertEquals(
                "2025-01-01T10:00:12Z",
                results.get(2).getField(2).toString());
    }

    @Test
    @DisplayName("Invalid deduplication mode throws exception")
    public void invalidModeThrowsException() {

        Exception exception = assertThrows(
                Exception.class,
                () -> customPtfTest("dedup-invalid-mode.sql"));

        Throwable t = exception;

        while (t != null) {
            if ("Unsupported deduplication mode: INVALID_MODE"
                    .equals(t.getMessage())) {
                return;
            }
            t = t.getCause();
        }

        fail("Expected invalid mode exception was not found");
    }

    @Test
    @DisplayName("Timeout must be greater than zero")
    public void invalidTimeoutThrowsException() {

        Exception exception = assertThrows(
                Exception.class,
                () -> customPtfTest("dedup-invalid-timeout.sql"));

        Throwable t = exception;
        boolean found = false;

        while (t != null) {
            if (t.getMessage() != null
                    && t.getMessage().contains(
                    "timeoutMillis must be greater than 0")) {
                found = true;
                break;
            }
            t = t.getCause();
        }

        assertTrue(found);
    }

    @Test
    @DisplayName("Changelog input is rejected at plan time by Flink's planner")
    public void changelogInputStreamIsRejected() {

        // Flink's own planner (StreamPhysicalProcessTableFunction) rejects changelog
        // input at plan time with a TableException before any records are processed.
        final Exception exception = assertThrows(
                Exception.class,
                () -> customPtfTest("dedup-changelog.sql"));

        assertTrue(
                exception.getMessage().contains("doesn't support consuming update changes"),
                "Expected Flink planner to reject changelog input. Actual: " + exception.getMessage());
    }

    @Test
    @DisplayName("Deduplication state is isolated per partition")
    public void deduplicationPerPartition() throws Exception {

        List<Row> results =
                customPtfTest("dedup-partition-isolation.sql");

        assertEquals(2, results.size());

        boolean foundO1 = false;
        boolean foundO2 = false;

        for (Row row : results) {
            String orderId = (String) row.getField(3);

            if ("O1".equals(orderId)) {
                foundO1 = true;
                assertEquals("C1", row.getField(1));
                assertEquals(100.0, row.getField(4));
                assertEquals(
                        "2025-01-01T10:00:00Z",
                        row.getField(2).toString());
            }

            if ("O2".equals(orderId)) {
                foundO2 = true;
                assertEquals("C2", row.getField(1));
                assertEquals(200.0, row.getField(4));
                assertEquals(
                        "2025-01-01T10:00:02Z",
                        row.getField(2).toString());
            }
        }

        assertTrue(foundO1);
        assertTrue(foundO2);
    }

    @Test
    @DisplayName("Deduplication supports multiple nested partition keys")
    public void deduplicationWithNestedPartitionKeys() throws Exception {

        List<Row> results = customPtfTest("dedup-nested-partitions.sql");

        // Flink places the PARTITION BY column first in the output schema.
        // View columns: partition_key(0), order_id(1), item(2), supplier(3), event_time(4).
        //
        // O1 is intentionally used with two different composite keys:
        // (widget, S1) and (widget, S2), so both must be emitted.
        // Duplicate rows with the same composite key must be suppressed.
        assertEquals(3, results.size());

        // Both O1 rows must be present (different composite keys).
        long o1Count = results.stream().filter(row -> "O1".equals(row.getField(1))).count();
        assertEquals(2, o1Count, "O1 should appear in two distinct composite-key partitions");

        // O1 with supplier S1 is the first event in its partition.
        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1)) && row.getField(3) != null
                        && "S1".equals(((Row) row.getField(3)).getField(0))));

        // O1 with supplier S2 is the first event in its partition.
        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1)) && row.getField(3) != null
                        && "S2".equals(((Row) row.getField(3)).getField(0))));

        // O2 appears exactly once (its duplicate was suppressed).
        long o2Count = results.stream().filter(row -> "O2".equals(row.getField(1))).count();
        assertEquals(1, o2Count, "O2 duplicate should have been suppressed");
    }

    @Test
    @DisplayName("ROW partition key — NULL field values are treated as distinct partition keys")
    public void deduplicationWithRowPartitionKeyNullValues() throws Exception {

        List<Row> results = customPtfTest("dedup-row-partition-key-nulls.sql");

        // Flink places the PARTITION BY column first in the output schema.
        // View columns: partition_key(0), order_id(1), item(2), supplier(3), event_time(4).
        //
        // O1 is sent with two different composite partition keys ROW(item.name, supplier.id):
        //   row 1: item={name:widget}, supplier={id:S1} → key ROW('widget', 'S1')
        //   row 2: item=null,          supplier={id:S1} → key ROW(NULL, 'S1')
        //   row 3: same as row 1                        → duplicate, suppressed
        // The two keys are distinct so both O1 rows must be emitted.
        //
        // O2 is sent twice with item={name:widget}, supplier=null.
        // The partition key expression is ROW(item.name, supplier.id): because supplier itself
        // is null, supplier.id evaluates to null, giving key ROW('widget', NULL). Importantly,
        // the ROW is non-null — null propagates at the field level, not the row level — so both
        // O2 rows share the same partition and the duplicate is suppressed.
        assertEquals(3, results.size());

        // Both O1 rows must be present (different composite keys).
        long o1Count = results.stream().filter(row -> "O1".equals(row.getField(1))).count();
        assertEquals(2, o1Count, "O1 should appear in two distinct composite-key partitions");

        // O1 with non-null item column (key ROW('widget','S1')): field(2) is the top-level item
        // ROW column, which is non-null when item={name:widget} was in the input.
        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1)) && row.getField(2) != null));

        // O1 with null item column (key ROW(NULL,'S1')): field(2) is null because item itself
        // was null in the input, making item.name null in the partition key.
        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1)) && row.getField(2) == null));

        // O2 appears exactly once (its duplicate was suppressed).
        long o2Count = results.stream().filter(row -> "O2".equals(row.getField(1))).count();
        assertEquals(1, o2Count, "O2 duplicate should have been suppressed");
    }

    @Test
    @DisplayName("ROW partition key — mixed types (STRING + BIGINT) are partitioned correctly")
    public void deduplicationWithRowPartitionKeyMixedTypes() throws Exception {

        List<Row> results = customPtfTest("dedup-row-partition-key-mixed-types.sql");

        // Flink places the PARTITION BY column first in the output schema.
        // View columns: partition_key(0), order_id(1), category(2), price(3), event_time(4).
        //
        // O1 is intentionally used with two different composite keys:
        // (electronics, 100) and (electronics, 200), so both must be emitted.
        // Duplicate rows with the same composite key must be suppressed.
        assertEquals(3, results.size());

        // Both O1 rows must be present (different composite keys).
        long o1Count = results.stream().filter(row -> "O1".equals(row.getField(1))).count();
        assertEquals(2, o1Count, "O1 should appear in two distinct composite-key partitions");

        // O1 with price 100.
        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1)) && Long.valueOf(100).equals(row.getField(3))));

        // O1 with price 200 (same category, different price → different partition).
        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1)) && Long.valueOf(200).equals(row.getField(3))));

        // O2 appears exactly once (its duplicate was suppressed).
        long o2Count = results.stream().filter(row -> "O2".equals(row.getField(1))).count();
        assertEquals(1, o2Count, "O2 duplicate should have been suppressed");
    }

    @Test
    @DisplayName("BOOLEAN flat partition key — true and false are treated as distinct partitions")
    public void deduplicationWithBooleanPartitionKey() throws Exception {

        List<Row> results = customPtfTest("dedup-row-partition-key-boolean.sql");

        // Flink places the PARTITION BY column first in the output schema.
        // View columns: active(0), order_id(1), event_time(2).
        //
        // O1 is intentionally used with both true and false partition-key values,
        // so both partitions must retain an event. The duplicate true value is suppressed.
        assertEquals(2, results.size());

        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1))
                        && Boolean.TRUE.equals(row.getField(0))));

        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1))
                        && Boolean.FALSE.equals(row.getField(0))));
    }

    @Test
    @DisplayName("TIMESTAMP flat partition key — distinct timestamps are treated as distinct partitions")
    public void deduplicationWithTimestampPartitionKey() throws Exception {

        List<Row> results = customPtfTest("dedup-row-partition-key-timestamp.sql");

        // Flink places the PARTITION BY column first in the output schema.
        // View columns: created_at(0), order_id(1), event_time(2).
        //
        // O1 is intentionally used with two different partition-key values:
        // 08:00:00Z and 09:00:00Z, so both partitions must retain an event.
        // The duplicate 08:00:00Z value is suppressed.
        assertEquals(2, results.size());

        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1))
                        && "2025-01-01T08:00:00Z".equals(row.getField(0).toString())));

        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1))
                        && "2025-01-01T09:00:00Z".equals(row.getField(0).toString())));
    }

    @Test
    @DisplayName("ARRAY flat partition key — distinct arrays are treated as distinct partitions")
    public void deduplicationWithArrayPartitionKey() throws Exception {

        List<Row> results = customPtfTest("dedup-row-partition-key-array.sql");

        // Flink places the PARTITION BY column first:
        // tags(0), order_id(1), event_time(2)
        //
        // O1 is intentionally used with two different array partition-key values:
        // ["express", "fragile"] and ["standard"], so both partitions must retain an event.
        // The duplicate ["express", "fragile"] value is suppressed.
        assertEquals(2, results.size());

        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1))
                        && Arrays.equals(
                        new String[] {"express", "fragile"},
                        (String[]) row.getField(0))));

        assertTrue(results.stream().anyMatch(row ->
                "O1".equals(row.getField(1))
                        && Arrays.equals(
                        new String[] {"standard"},
                        (String[]) row.getField(0))));
    }

    @Test
    @DisplayName("Nested ROW flat partition key — distinct ROW values are treated as distinct partitions")
    public void deduplicationWithNestedRowPartitionKey() throws Exception {

        List<Row> results = customPtfTest("dedup-row-partition-key-nested-row.sql");

        // Flink places the PARTITION BY column first:
        // item(0), order_id(1), event_time(2)
        //
        // O1 is intentionally used with two different ROW partition-key values:
        // ROW('widget', 10.0) and ROW('gadget', 20.0), so both partitions must retain an event.
        // The duplicate ROW('widget', 10.0) value is suppressed.
        assertEquals(2, results.size());

        assertTrue(results.stream().anyMatch(row -> {
            Row item = (Row) row.getField(0);
            return "O1".equals(row.getField(1))
                    && "widget".equals(item.getField(0))
                    && Double.valueOf(10.0).equals(item.getField(1));
        }));

        assertTrue(results.stream().anyMatch(row -> {
            Row item = (Row) row.getField(0);
            return "O1".equals(row.getField(1))
                    && "gadget".equals(item.getField(0))
                    && Double.valueOf(20.0).equals(item.getField(1));
        }));
    }

}
