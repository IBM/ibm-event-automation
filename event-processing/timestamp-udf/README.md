# IBM Event Processing Timestamp UDFs

User-defined functions (UDFs) for Apache Flink SQL that parse ISO 8601 and SQL-formatted timestamp strings.
Originally developed for IBM Event Processing.

These UDFs are useful when events contain multiple timestamp properties in different formats,
include timezone offsets beyond UTC 'Z',
use Avro with string timestamp fields,
have variable precision across events,
or when parsing timestamps from API enrichment responses.

They provide the following capabilities:
- Per-column format flexibility (ISO-8601 or SQL), bypassing Flink format connectors' global `json.timestamp-format.standard` setting
- Full timezone offset support (`+HH:mm`, `+HHmm`, `+HH`, `-HH:mm`, `Z`, etc.)
- Variable precision (0-9 digit fractional seconds)
- Connector-independent (works with JSON, Avro, etc. by parsing `STRING` columns)
- Graceful error handling (returns `null` instead of throwing exceptions)

> These UDFs are distributed as part of the combined `ibm-ep-functions.jar`. See [ibm-ep-functions](../ibm-ep-functions/README.md) for installation and release instructions.

---

* [Prerequisites](#prerequisites)
* [Build from source](#build-from-source)
* [Function TO_TIMESTAMP_UDF](#function-to_timestamp_udf)
* [Function TO_TIMESTAMP_LTZ_UDF](#function-to_timestamp_ltz_udf)
* [SQL Usage Examples](#sql-usage-examples)
  * [Computed Column for Event Time & Watermarks](#computed-column-for-event-time--watermarks)
  * [Direct Transformation in Queries](#direct-transformation-in-queries)

---

## Prerequisites

- Java 11+
- Flink 2.2.1+
- Maven 3

## Build from source

Build this module independently:

```bash
git clone https://github.com/IBM/ibm-event-automation.git
cd ibm-event-automation/event-processing/timestamp-udf
mvn clean package
```

## Function TO_TIMESTAMP_UDF

Parses timestamp strings **without timezone** into Flink's `TIMESTAMP` type (`LocalDateTime`).

**Supported formats:**
- ISO-8601: `2024-01-15T10:30:45.123456789`
- SQL format: `2024-01-15 10:30:45.123456789`

Returns `null` if input contains timezone information (use `TO_TIMESTAMP_LTZ_UDF` instead).

## Function TO_TIMESTAMP_LTZ_UDF

Parses timestamp strings **with timezone** into Flink's `TIMESTAMP_LTZ` type (`Instant` in UTC).

**Supported formats:**
- ISO-8601: `2024-01-15T10:30:45.123456789+01:00`, `2024-01-15T10:30:45Z`
- SQL format: `2024-01-15 10:30:45.123456789+01:00`
- Also accepts timestamps without timezone (uses system default timezone)

Converts all parsed timestamps to UTC.

## SQL Usage Examples

You must register UDFs before using them:
```sql
CREATE FUNCTION TO_TIMESTAMP_UDF AS 'com.ibm.ei.streamproc.udf.ToTimestampUdf';
CREATE FUNCTION TO_TIMESTAMP_LTZ_UDF AS 'com.ibm.ei.streamproc.udf.ToTimestampLtzUdf';
```

### Computed Column for Event Time & Watermarks

Flink requires `TIMESTAMP(3)` type for watermarks, but source data has `STRING` timestamps. UDFs bridge this gap at table definition time.

```sql
CREATE TABLE `source`(
    `ts` STRING,
    -- CAST to TIMESTAMP(3) required for watermark attribute
    `ts___EVENT_TIME` AS CAST(TO_TIMESTAMP_UDF(`ts`) AS TIMESTAMP(3)),
    -- Computed column ts___EVENT_TIME becomes the watermark source, of type TIMESTAMP(3)
    WATERMARK FOR `ts___EVENT_TIME` AS `ts___EVENT_TIME` - INTERVAL '5' SECOND
)
```

### Direct Transformation in Queries

Enables timestamp type conversion at query time for data transformation, filtering, or enrichment scenarios.

```sql
SELECT
    -- STRING column ts is converted to TIMESTAMP(9)
    TO_TIMESTAMP_UDF(`ts`) AS `ts`,
    -- STRING column tsWithZone is converted to TIMESTAMP_LTZ(9)
    TO_TIMESTAMP_LTZ_UDF(`tsWithZone`) AS `tsWithZone`
FROM `table`;
```
