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

import org.apache.flink.table.annotation.ArgumentHint;
import org.apache.flink.table.annotation.ArgumentTrait;
import org.apache.flink.table.annotation.DataTypeHint;
import org.apache.flink.table.annotation.FunctionHint;
import org.apache.flink.table.annotation.StateHint;
import org.apache.flink.table.catalog.DataTypeFactory;
import org.apache.flink.table.functions.ProcessTableFunction;
import org.apache.flink.table.functions.TableSemantics;
import org.apache.flink.table.types.inference.TypeInference;
import org.apache.flink.table.types.inference.TypeStrategy;
import org.apache.flink.types.Row;
import org.apache.flink.table.types.logical.LogicalTypeRoot;
import org.apache.flink.table.types.logical.RowType;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.TreeMap;

/**
 * A Flink Process Table Function (PTF) for deduplicating events based on time windows.
 *
 * <p>This PTF removes duplicate events within configurable time windows, supporting two modes:
 * <ul>
 *   <li>
 *     <b>FIXED_INTERVAL:</b> Emits at most one event per timeout window.
 *     Duplicate events do not extend the window.
 *   </li>
 *   <li>
 *     <b>INACTIVITY:</b> Duplicate events extend the active session.
 *     A new event is emitted only after a period of inactivity longer than the timeout.
 *   </li>
 * </ul>
 *
 * <p>The function uses Flink's stateful processing capabilities to track event timestamps
 * and determine when to emit events based on the configured deduplication mode and timeout.
 *
 * <p><b>Arguments:</b>
 * <ul>
 *   <li>{@code input} — the input table (set-semantic); must be partitioned via {@code PARTITION BY}</li>
 *   <li>{@code mode} — deduplication mode: {@code 'FIXED_INTERVAL'} or {@code 'INACTIVITY'}</li>
 *   <li>{@code timeoutMillis} — timeout duration in milliseconds (must be &gt; 0)</li>
 *   <li>{@code on_time} — (optional) descriptor of the event-time column; defaults to the
 *       watermark column declared on the input table</li>
 *   <li>{@code uid} — (optional) stable string identifier for the PTF, used for
 *       state migration and savepoint compatibility. When omitted, the function
 *       name is used as the UID by the framework.</li>
 * </ul>
 *
 * <p><b>Usage example in Flink SQL:</b>
 * <pre>{@code
 * -- Register the function
 * CREATE FUNCTION DEDUPLICATE_PTF AS 'com.ibm.ei.streamproc.ptf.DeduplicationPTF';
 *
 * -- Deduplicate with fixed interval mode
 * SELECT * FROM TABLE(
 *   DEDUPLICATE_PTF(
 *     input         => TABLE source_table PARTITION BY customer_id,
 *     mode          => 'FIXED_INTERVAL',
 *     timeoutMillis => CAST(60000 AS BIGINT),
 *     on_time       => DESCRIPTOR(event_time),
 *     uid           => 'my-dedup-node'
 *   )
 * );
 *
 * -- Deduplicate with inactivity mode
 * SELECT * FROM TABLE(
 *   DEDUPLICATE_PTF(
 *     input         => TABLE source_table PARTITION BY customer_id,
 *     mode          => 'INACTIVITY',
 *     timeoutMillis => CAST(30000 AS BIGINT),
 *     on_time       => DESCRIPTOR(event_time),
 *     uid           => 'my-dedup-node'
 *   )
 * );
 * }</pre>
 *
 * @see ProcessTableFunction
 */
@FunctionHint(
        output = @DataTypeHint("ROW<f0 STRING>")
)
public class DeduplicationPTF extends ProcessTableFunction<Row> {
    
    private static final Logger log = LogManager.getLogger(DeduplicationPTF.class);

    // Transient because this is derived from the input table schema.
    // It is lazily re-initialized by usesTimestampLtz() after task restore.
    private transient Boolean timestampUsesLocalTimeZone;

    /**
     * Deduplication modes supported by this PTF.
     */
    public enum DeduplicationMode {
        /**
         * Emits at most one event per timeout window, anchored to the last emitted event.
         * Duplicate events within the window are suppressed and do not reset the window.
         * A new event is emitted only once {@code timeoutMillis} has elapsed since the
         * last emitted event.
         */
        FIXED_INTERVAL,

        /**
         * Emits one event after a gap of inactivity longer than {@code timeoutMillis}.
         * Every arriving event updates the stored timestamp, including duplicates.
         * Continuous activity therefore suppresses all output until the stream goes quiet.
         */
        INACTIVITY
    }

    /**
     * State class to track the last event timestamp for deduplication logic.
     */
    public static class DeduplicationState {
        /**
         * Timestamp of the last tracked event for deduplication.
         */
        public Long lastEventTimestamp;
    }

    /**
     * State class to buffer and reorder events based on their timestamps.
     */
    public static class ReorderState {
        /**
         * Map of pending events organized by timestamp.
         * Uses TreeMap to maintain timestamp ordering.
         */
        @DataTypeHint("RAW")
        public Map<Long, List<Row>> pendingEvents = new TreeMap<>();

        // Latest cleanup timer registered for this partition
        public Long cleanupTimestamp;
    }

    /**
     * State class to store configuration parameters.
     */
    public static class ConfigState {
        /**
         * Deduplication mode: FIXED_INTERVAL or INACTIVITY.
         */
        // Flink cannot infer the state type for custom enums during type extraction.
        // Store the enum as a RAW type in state.
        @DataTypeHint("RAW")
        public DeduplicationMode mode;
        
        /**
         * Timeout in milliseconds for deduplication window.
         */
        public Long timeoutMillis;
    }

    /**
     * Evaluates the PTF for each input row, buffering events for reordering and deduplication.
     *
     * <p>This method:
     * <ol>
     *   <li>Extracts the event timestamp from the context</li>
     *   <li>Checks if the event is late (before watermark)</li>
     *   <li>Buffers the event for processing</li>
     *   <li>Registers a timer to process the event at its timestamp</li>
     * </ol>
     *
     * @param ctx the processing context providing access to time and state
     * @param reorderEventsState state for buffering and reordering events
     * @param dedupTimestampState state for tracking deduplication timestamps
     * @param configParameterState state for storing configuration parameters
     * @param input the input row to process; SQL argument name {@code input}
     * @param mode the deduplication mode ({@code FIXED_INTERVAL} or {@code INACTIVITY});
     *             SQL argument name {@code mode}
     * @param timeoutMillis the timeout in milliseconds; interpreted as a fixed interval duration
     *                      for {@code FIXED_INTERVAL} mode, or as an inactivity gap for
     *                      {@code INACTIVITY} mode; SQL argument name {@code timeoutMillis}
     */
    public void eval(
            Context ctx,
            @StateHint ReorderState reorderEventsState,
            @StateHint(name = "dedupTimestampState") DeduplicationState dedupTimestampState,
            @StateHint(name = "configParameterState") ConfigState configParameterState,
            @ArgumentHint(
                    value = {
                            ArgumentTrait.SET_SEMANTIC_TABLE
                    },
                    name = "input")
            Row input,
            @ArgumentHint(name = "mode") String mode,
            @ArgumentHint(name = "timeoutMillis") Long timeoutMillis) {

        // Validate the incoming configuration.
        DeduplicationMode incomingMode =
                validateConfiguration(mode, timeoutMillis);

        // Initialize the persisted configuration on first use.
        // Once initialized, the persisted configuration is retained.
        if (configParameterState.mode == null) {
            configParameterState.mode = incomingMode;
            configParameterState.timeoutMillis = timeoutMillis;
        } else if (incomingMode != configParameterState.mode
                || !Objects.equals(configParameterState.timeoutMillis, timeoutMillis)) {

            log.warn(
                    "Configuration change detected. Using persisted configuration. "
                            + "Stored mode={}, timeoutMillis={}, incoming mode={}, timeoutMillis={}",
                    configParameterState.mode,
                    configParameterState.timeoutMillis,
                    incomingMode,
                    timeoutMillis);
        }

        Long timestamp = extractTimestampFromContext(ctx);

        if (timestamp == null) {
            log.warn(
                    "Unable to extract the event timestamp from the configured time descriptor; "
                            + "skipping event");
            return;
        }

        TimeContext<Instant> timeContext = ctx.timeContext(Instant.class);
        Instant watermark = timeContext.currentWatermark();

        log.debug("Processing event: timestamp={}, watermark={}", timestamp, watermark);

        // Ignore late events (events that arrive after the watermark has passed)
        if (watermark != null && timestamp <= watermark.toEpochMilli()) {
            log.debug("Late event ignored: timestamp={}", timestamp);
            return;
        }

        // Buffer the event for reordering
        reorderEventsState.pendingEvents
                .computeIfAbsent(timestamp, k -> new ArrayList<>())
                // Copy before buffering. Buffered rows may outlive the current
                // invocation and must not reference reusable internal Flink data structures.
                .add(Row.copy(input));

        log.debug(
                "Registering PROCESS timer at {}",
                timestamp);
        timeContext.registerOnTime(
                Instant.ofEpochMilli(timestamp));

        // Flink PTF named timers ("cleanup") replace any existing timer with the
        // same name. We only re-register when the cleanup time moves forward,
        // ensuring cleanup is scheduled relative to the latest event seen for
        // this partition.
        long candidateCleanupTimestamp = timestamp + configParameterState.timeoutMillis;

        if (reorderEventsState.cleanupTimestamp == null
                || candidateCleanupTimestamp > reorderEventsState.cleanupTimestamp) {

            reorderEventsState.cleanupTimestamp = candidateCleanupTimestamp;

            log.debug(
                    "Registering CLEANUP timer at {}",
                    candidateCleanupTimestamp);

            timeContext.registerOnTime(
                    "cleanup",
                    Instant.ofEpochMilli(candidateCleanupTimestamp));

        } else {

            log.debug(
                    "Skipping cleanup timer. Existing={}, Candidate={}",
                    reorderEventsState.cleanupTimestamp,
                    candidateCleanupTimestamp);
        }

        log.debug("Buffered event: timestamp={}, pendingCount={}", 
                timestamp, reorderEventsState.pendingEvents.size());
    }

    /**
     * Validates the deduplication configuration and resolves the supplied mode.
     *
     * <p>The mode must be one of the supported {@link DeduplicationMode} values,
     * and the timeout must be a positive value in milliseconds.
     *
     * @param mode the deduplication mode supplied by the caller
     * @param timeoutMillis the timeout in milliseconds; interpreted as a fixed interval duration for
     *                      {@code FIXED_INTERVAL} mode, or as an inactivity gap for {@code INACTIVITY} mode
     * @return the resolved {@link DeduplicationMode}
     * @throws IllegalArgumentException if the mode is unsupported or the timeout
     *         is null or not greater than zero
     */
    private DeduplicationMode validateConfiguration(
            String mode,
            Long timeoutMillis) {

        final DeduplicationMode incomingMode;

        if (mode == null) {
            throw new IllegalArgumentException("Unsupported deduplication mode: null");
        }

        try {
            incomingMode = DeduplicationMode.valueOf(mode.toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException(
                    "Unsupported deduplication mode: " + mode,
                    e);
        }

        if (timeoutMillis == null || timeoutMillis <= 0) {
            throw new IllegalArgumentException(
                    "timeoutMillis must be greater than 0");
        }

        return incomingMode;
    }

    /**
     * Extracts the event timestamp from the PTF time context.
     *
     * <p>The descriptor column type is resolved once and cached via
     * {@code usesTimestampLtz()}. Depending on the resolved type, the timestamp
     * is retrieved as either {@link Instant} (TIMESTAMP_LTZ) or
     * {@link LocalDateTime} (TIMESTAMP) and converted to epoch milliseconds.
     */
    private Long extractTimestampFromContext(Context ctx) {

        if (usesTimestampLtz(ctx)) {
            Instant instant = ctx.timeContext(Instant.class).time();
            return instant == null ? null : instant.toEpochMilli();
        }

        LocalDateTime localDateTime =
                ctx.timeContext(LocalDateTime.class).time();

        return localDateTime == null
                ? null
                : localDateTime.toInstant(ZoneOffset.UTC).toEpochMilli();
    }


    /**
     * Resolves and caches whether the descriptor time column is TIMESTAMP_LTZ.
     * This avoids exception-based type probing and repeated schema inspection
     * for every processed event.
     */
    private boolean usesTimestampLtz(Context ctx) {

        if (timestampUsesLocalTimeZone != null) {
            return timestampUsesLocalTimeZone;
        }

        TableSemantics tableSemantics = ctx.tableSemanticsFor("input");
        if (!(tableSemantics.dataType().getLogicalType() instanceof RowType)) {
            throw new IllegalStateException("Expected the input table type to be a ROW type");
        }

        RowType rowType =
                (RowType) tableSemantics.dataType().getLogicalType();
        int timeColumn = tableSemantics.timeColumn();
        if (timeColumn < 0 || timeColumn >= rowType.getFieldCount()) {
            throw new IllegalStateException("Time column index is outside the input row type");
        }

        LogicalTypeRoot typeRoot =
                rowType.getTypeAt(timeColumn).getTypeRoot();

        if (typeRoot != LogicalTypeRoot.TIMESTAMP_WITH_LOCAL_TIME_ZONE
                && typeRoot != LogicalTypeRoot.TIMESTAMP_WITHOUT_TIME_ZONE) {

            throw new IllegalStateException(
                    "Unsupported time descriptor type: "
                            + typeRoot
                            + ". Expected TIMESTAMP or TIMESTAMP_LTZ.");
        }

        timestampUsesLocalTimeZone =
                typeRoot == LogicalTypeRoot.TIMESTAMP_WITH_LOCAL_TIME_ZONE;

        return timestampUsesLocalTimeZone;
    }


    /**
     * Overrides the type inference to propagate the input table's schema to the output.
     *
     * <p>This ensures that the output of the PTF has the same schema as the input table,
     * allowing seamless integration in SQL queries.
     *
     * @param typeFactory the data type factory for creating types
     * @return the type inference configuration
     */
    @Override
    public TypeInference getTypeInference(DataTypeFactory typeFactory) {
        TypeInference existing = super.getTypeInference(typeFactory);

        TypeStrategy myStrategy = callContext ->
                callContext.getTableSemantics(0)
                        .map(TableSemantics::dataType);

        return TypeInference.newBuilder()
                .staticArguments(existing.getStaticArguments().get())
                .inputTypeStrategy(existing.getInputTypeStrategy())
                .stateTypeStrategies(existing.getStateTypeStrategies())
                .outputTypeStrategy(myStrategy)
                .build();
    }

    /**
     * Timer callback that processes buffered events when their timestamp is reached.
     *
     * <p>This method:
     * <ol>
     *   <li>Retrieves events buffered for the current timestamp</li>
     *   <li>Processes each event through the deduplication logic</li>
     *   <li>Removes processed events from the buffer</li>
     * </ol>
     *
     * @param ctx the timer context providing access to time and state
     * @param reorderEventsState state containing buffered events
     * @param dedupTimestampState state for tracking deduplication timestamps
     * @param configParameterState state containing configuration parameters
     */
    public void onTimer(
            OnTimerContext ctx,
            @StateHint ReorderState reorderEventsState,
            @StateHint(name = "dedupTimestampState") DeduplicationState dedupTimestampState,
            @StateHint(name = "configParameterState") ConfigState configParameterState) {

        TimeContext<Instant> timeContext = ctx.timeContext(Instant.class);
        Instant timerInstant = timeContext.time();
        long timestamp = timerInstant.toEpochMilli();

        log.debug("Timer fired: timestamp={}", timestamp);

        if ("cleanup".equals(ctx.currentTimer())) {

            log.debug(
                    "Cleanup timer fired at {}, clearing dedupTimestampState",
                    timestamp);

            ctx.clearState("dedupTimestampState");

            // Defensive: process timers (at T) always fire before this cleanup
            // timer (at T + timeoutMillis), so this should already be empty.
            if (!reorderEventsState.pendingEvents.isEmpty()) {
                log.warn(
                        "Cleanup timer fired with {} non-empty timestamp buckets still pending - clearing defensively",
                        reorderEventsState.pendingEvents.size());
            }
            reorderEventsState.pendingEvents.clear();

            // Reset so the next event can register a new cleanup timer
            reorderEventsState.cleanupTimestamp = null;

            return;
        }

        List<Row> events = reorderEventsState.pendingEvents.get(timestamp);

        if (events == null || events.isEmpty()) {
            log.debug("No events to process for timestamp={}", timestamp);
            return;
        }

        // Validate that configuration state is available before processing events.
        if (configParameterState.mode == null || configParameterState.timeoutMillis == null) {
            throw new IllegalStateException("configParameterState not initialized");
        }

        // Process each buffered event through deduplication logic
        for (Row event : events) {
            processDedup(
                    event,
                    timestamp,
                    dedupTimestampState,
                    configParameterState.mode,
                    configParameterState.timeoutMillis);
        }

        // Clean up processed events
        reorderEventsState.pendingEvents.remove(timestamp);
    }

    /**
     * Processes a single event through the deduplication logic.
     *
     * <p>Determines whether to emit the event based on:
     * <ul>
     *   <li>The deduplication mode (FIXED_INTERVAL or INACTIVITY)</li>
     *   <li>The time since the last emitted event</li>
     *   <li>The configured timeout</li>
     * </ul>
     *
     * @param row the event row to process
     * @param currentTimestamp the timestamp of the current event
     * @param dedupTimestampState state tracking the last emitted event timestamp
     * @param dedupMode the deduplication mode, which determines how the timeout is applied
     * @param timeoutMillis the timeout in milliseconds for the fixed interval or inactivity window
     */
    private void processDedup(
            Row row,
            long currentTimestamp,
            DeduplicationState dedupTimestampState,
            DeduplicationMode dedupMode,
            long timeoutMillis) {

        Long lastSeenTimestamp = dedupTimestampState.lastEventTimestamp;

        boolean isFirstEvent = lastSeenTimestamp == null;

        long previousTimestamp = isFirstEvent ? 0L : lastSeenTimestamp;

        boolean windowExpired = currentTimestamp - previousTimestamp > timeoutMillis;

        boolean shouldEmit = false;

        switch (dedupMode) {
            case FIXED_INTERVAL:
                // Fixed interval mode:
                // The deduplication window is anchored to the last emitted event.
                // Duplicate events do not update the stored timestamp.
                // This allows one event to be emitted once the timeout has elapsed
                // since the last emitted event, regardless of how many duplicates
                // arrive in between.
                shouldEmit = isFirstEvent || windowExpired;

                if (shouldEmit) {
                    dedupTimestampState.lastEventTimestamp = currentTimestamp;
                }
                break;

            case INACTIVITY:
                // Inactivity mode:
                // Every event updates the stored timestamp, including duplicates.
                // Continuous activity therefore extends the window.
                // A new event is emitted only after no events have been seen for
                // longer than timeoutMillis.
                shouldEmit = isFirstEvent || windowExpired;
                dedupTimestampState.lastEventTimestamp = currentTimestamp;
                break;

            default:
                throw new IllegalStateException("Unsupported deduplication mode: " + dedupMode);
        }

        if (shouldEmit) {
            log.debug("Emitting event: timestamp={}, mode={}", currentTimestamp, dedupMode);
            collect(row);
        } else {
            log.debug("Filtering duplicate event: timestamp={}, mode={}", currentTimestamp, dedupMode);
        }
    }
}
