# IBM Event Processing Deduplication PTF

A Process Table Function (PTF) for Apache Flink SQL that deduplicates events within a configurable time window.
Originally developed for IBM Event Processing.

This PTF is useful when an event stream contains duplicate events and you want to suppress them based on a partition key and a time-based deduplication strategy.

It provides the following capabilities:
- Two deduplication modes: `FIXED_INTERVAL` and `INACTIVITY`
- Partition-based deduplication — each partition key maintains independent deduplication state
- Support for complex partition key types: `ROW`, `ARRAY`, `BOOLEAN`, `TIMESTAMP`, and nested types
- Event-time based processing using Flink watermarks
- Compatible with both `TIMESTAMP` and `TIMESTAMP_LTZ` event-time columns

> The Deduplication PTF is distributed as part of the combined `ep-dedup-ptf-and-timestamp-udfs.jar`. See [ep-dedup-ptf-and-timestamp-udfs](../ep-dedup-ptf-and-timestamp-udfs/README.md) for installation and release instructions.

---

* [Prerequisites](#prerequisites)
* [Build from source](#build-from-source)
* [Deduplication modes](#deduplication-modes)
* [SQL Usage](#sql-usage)
  * [Function arguments](#function-arguments)
  * [Example](#example)

---

## Prerequisites

- Java 11+
- Flink 2.2.1+
- Maven 3

## Build from source

Build this module independently:

```bash
git clone https://github.com/IBM/ibm-event-automation.git
cd ibm-event-automation/event-processing/deduplication-ptf
mvn clean install
```

## Deduplication modes

### FIXED_INTERVAL
Emits at most one event per timeout window. Duplicate events do not extend the window.

### INACTIVITY
Duplicate events extend the active session. A new event is emitted only after a period of inactivity longer than the timeout.

## SQL Usage

Register the PTF before using it:

```sql
CREATE FUNCTION DEDUPLICATE_PTF AS 'com.ibm.ei.streamproc.ptf.DeduplicationPTF';
```

### Function arguments

| Argument | Type | Optional | Description |
|---|---|---|---|
| `input` | TABLE (set-semantic) | no | Input view; must carry a `PARTITION BY` clause |
| `mode` | STRING | no | `'FIXED_INTERVAL'` or `'INACTIVITY'` |
| `timeoutMillis` | BIGINT | no | Timeout in milliseconds (> 0): fixed window length for `FIXED_INTERVAL`, inactivity gap for `INACTIVITY` |
| `DESCRIPTOR(<col>)` | DESCRIPTOR | yes | Specifies the event-time column as the 4th positional argument. When omitted, the framework resolves the time column automatically from the watermark declared on the input table. |

> **Note on `uid`:** Flink assigns each PTF call a stable operator identifier used for state migration and savepoint compatibility. When multiple `DEDUPLICATE_PTF` calls appear in the same job, pass a unique string as the 5th positional argument (e.g. `'deduplicate-orders'`) to avoid identifier collisions. When omitted, Flink uses the function name as the default.

### Example

```sql
SELECT *
FROM TABLE(
  DEDUPLICATE_PTF(
    TABLE source_view PARTITION BY order_id,
    'FIXED_INTERVAL',
    CAST(5000 AS BIGINT),
    DESCRIPTOR(event_time)
  )
);
```
