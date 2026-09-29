# EP Dedup PTF and Timestamp UDFs

[![EP Dedup PTF and Timestamp UDFs Build](https://github.com/IBM/ibm-event-automation/actions/workflows/ep-dedup-ptf-and-timestamp-udfs-release.yml/badge.svg)](https://github.com/IBM/ibm-event-automation/actions/workflows/ep-dedup-ptf-and-timestamp-udfs-release.yml) [![Releases](https://img.shields.io/badge/releases-view-blue)](https://github.com/IBM/ibm-event-automation/releases)

A combined JAR containing the Timestamp UDFs and Deduplication PTF for Apache Flink SQL,
for use when migrating IBM Event Processing flows to Confluent Platform for Flink.

> **Note:** IBM Event Processing bundles these functions internally. This JAR is only required
> when running migrated flows outside of IBM Event Processing — specifically on
> Confluent Platform for Flink using the [migration tools](../migration-tools/README.md).

| Module | Description | Reference |
|---|---|---|
| [Timestamp UDFs](../timestamp-udf/README.md) | Flink User-Defined Functions (UDFs) for parsing ISO 8601 timestamp strings with and without timezone information into Flink's TIMESTAMP type. See [Flink scalar functions](https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/functions/udfs/). | `TO_TIMESTAMP_UDF`, `TO_TIMESTAMP_LTZ_UDF` |
| [Deduplication PTF](../deduplication-ptf/README.md) | Deduplicate events within a configurable time window. See [Flink Process Table Functions](https://nightlies.apache.org/flink/flink-docs-release-2.3/docs/dev/table/functions/ptfs/). | `DEDUPLICATE_PTF` |

---

* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Build from source](#build-from-source)

---

## Prerequisites

Only if you want to build from sources:
- Java 11+
- Flink 2.2.1+
- Maven 3

## Installation

Download `ep-dedup-ptf-and-timestamp-udfs.jar` from [GitHub Releases](https://github.com/IBM/ibm-event-automation/releases).

The [migration tools](../migration-tools/README.md) Dockerfile downloads the JAR into the Flink
`lib/` directory of the application image at build time:

```dockerfile
RUN curl --fail -L -o /opt/flink/lib/ep-dedup-ptf-and-timestamp-udfs.jar \
    https://github.com/IBM/ibm-event-automation/releases/download/ep-dedup-ptf-and-timestamp-udfs-vX.Y.Z/ep-dedup-ptf-and-timestamp-udfs.jar
```

Placing the JAR in `lib/` makes it available on the classpath of both the JobManager and
TaskManager processes, which is required for Flink to resolve and execute the registered
UDFs and PTF at runtime. The migration tools Dockerfile handles this automatically.

## Build from source

Build the combined JAR from this directory:

```bash
git clone https://github.com/IBM/ibm-event-automation.git
cd ibm-event-automation/event-processing
mvn -f timestamp-udf/pom.xml clean install
mvn -f deduplication-ptf/pom.xml clean install
mvn -f ep-dedup-ptf-and-timestamp-udfs/pom.xml clean package
```

The combined JAR is produced at `ep-dedup-ptf-and-timestamp-udfs/target/ep-dedup-ptf-and-timestamp-udfs.jar`.

