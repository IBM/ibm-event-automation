# IBM Event Processing Deduplication PTF

This directory contains the source for the deduplication Process Table Function (PTF) module used by IBM Event Processing.

The module is intentionally self-contained so it can also be copied to the public repository distribution location
without requiring a parent POM or other repository-specific build structure.

## How it integrates with stream-proc

Deduplication supports two execution paths depending on the
`"useSqlDeduplication"` setting in the flow definition:

- **SQL-based path:** When `"useSqlDeduplication": true` is set, `stream-proc`
  performs deduplication entirely in Flink SQL using the `DEDUPLICATE_PTF`
  Process Table Function (PTF).

  The PTF is registered in Flink SQL as:

  ```sql
  CREATE FUNCTION DEDUPLICATE_PTF
  AS 'com.ibm.ei.streamproc.ptf.DeduplicationPTF';
  ```
  and invoked using named arguments so that each `DEDUPLICATE_PTF` call in a job
  receives a stable, node-scoped operator UID:

  ```sql
  SELECT <output columns>
  FROM TABLE(
    DEDUPLICATE_PTF(
      input         => TABLE <source_view> PARTITION BY <key>,
      mode          => '<MODE>',
      timeoutMillis => CAST(<ms> AS BIGINT),
      on_time       => DESCRIPTOR(<event_time_col>),
      uid           => 'deduplicate-<nodeId>'
    )
  );
  ```

  | Argument | Type | Optional | Description |
  |---|---|---|---|
  | `input` | TABLE (set-semantic) | no | Input view; must carry a `PARTITION BY` clause |
  | `mode` | STRING | no | `'FIXED_INTERVAL'` or `'INACTIVITY'` |
  | `timeoutMillis` | BIGINT | no | Timeout in ms (> 0): fixed window length for `FIXED_INTERVAL`, inactivity gap for `INACTIVITY` |
  | `on_time` | DESCRIPTOR | yes | Event-time column; defaults to the watermark column |
  | `uid` | STRING | yes | Stable Flink operator identifier for savepoint compatibility |

- **DataStream-based (non-PTF) path:** When `"useSqlDeduplication"` is `false`, or absent for flows deployed through the flow deployer, `stream-proc` uses the DataStream-based implementation from `ibm-ep-java-nodes`. This implementation cannot be exported to SQL.

In the Deduplicate node's flow JSON, set `configuration.deduplicationMode` to one
of the following values. The corresponding `mode` PTF argument value is shown for reference:

| Mode | Flow JSON `configuration.deduplicationMode` value | PTF `mode` argument |
|---|---|---|
| Fixed interval | `"fixed-interval"` | `'FIXED_INTERVAL'` |
| Inactivity | `"inactivity"` | `'INACTIVITY'` |

When partition keys are nested properties (e.g. `item.name`), `stream-proc` creates a synthetic
projection view to lift them to top-level columns before passing them to the PTF, because Flink's
`PARTITION BY` clause only accepts top-level columns.

For example, given events with an `item.name` field, configure the Deduplicate node to use that
nested property as its partition key:

```json
{
  "configuration": {
    "deduplicationMode": "fixed-interval",
    "useSqlDeduplication": true,
    "matchingCriteriaProperties": [
    {
      "name": "item",
      "type": "ROW",
      "properties": [
        {
          "name": "name",
          "type": "STRING"
        }
      ]
    }
    ]
  }
}
```

For an input such as `{ "item": { "name": "widget" } }`, the node uses `item.name` as the
partition key. Events with the same `item.name` value are treated as duplicates within the
configured fixed interval, while events with different values, such as `gadget`, are processed
separately.

## Build

Build the module from this directory:

```bash
mvn clean package
```

## Public distribution copy

A public copy of this module is intended to be maintained in:

- Source location: https://github.com/IBM/ibm-event-automation/tree/main/event-processing/deduplication-ptf
- Releases: https://github.com/IBM/ibm-event-automation/releases

The public repository is intended to provide customers with:
- access to the module source
- a downloadable jar through GitHub Releases
- the ability to rebuild the module if needed

This repository remains the maintained source used for Event Processing product build needs.

The public repository copy is maintained separately for customer-facing distribution. No repository linkage or 
synchronization mechanism is assumed beyond manual update when needed.

The public-repo-specific `README.md` is maintained separately and is not intended to be copied as-is from this repository.