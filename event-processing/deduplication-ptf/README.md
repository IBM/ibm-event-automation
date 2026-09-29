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

> The Deduplication PTF is distributed as part of the combined `ibm-ep-functions.jar`. See [ibm-ep-functions](../ibm-ep-functions/README.md) for installation and release instructions.

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
Emits at most one event per fixed time window. The window is anchored to the last emitted event. Duplicate events within the window are suppressed and do not extend the window.

### INACTIVITY
Emits the first event immediately, then suppresses duplicates until a gap of at least `timeoutMillis` milliseconds has elapsed with no events for that partition key. Every event (including duplicates) resets the inactivity timer.

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
| `on_time` | DESCRIPTOR | yes | Event-time column; defaults to the watermark column |
| `uid` | STRING | yes | Stable Flink operator identifier for savepoint compatibility |

### Example

```sql
SELECT *
FROM TABLE(
  DEDUPLICATE_PTF(
    input         => TABLE source_view PARTITION BY order_id,
    mode          => 'FIXED_INTERVAL',
    timeoutMillis => CAST(5000 AS BIGINT),
    on_time       => DESCRIPTOR(event_time),
    uid           => 'deduplicate-orders'
  )
);
```
