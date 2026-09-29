# IBM Event Processing Functions

[![IBM EP Functions Build](https://github.com/IBM/ibm-event-automation/actions/workflows/ibm-ep-functions-release.yml/badge.svg)](https://github.com/IBM/ibm-event-automation/actions/workflows/ibm-ep-functions-release.yml) [![Releases](https://img.shields.io/badge/releases-view-blue)](https://github.com/IBM/ibm-event-automation/releases)

A combined JAR containing the Timestamp UDFs and Deduplication PTF for Apache Flink SQL.
Originally developed for IBM Event Processing.

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

Download `ibm-ep-functions.jar` from [GitHub Releases](https://github.com/IBM/ibm-event-automation/releases).

Add the JAR to your Flink application image by copying it into the Flink `lib/` directory. For example, in a Dockerfile:

```dockerfile
RUN curl --fail -L -o /opt/flink/lib/ibm-ep-functions.jar \
    https://github.com/IBM/ibm-event-automation/releases/download/ep-functions-vX.Y.Z/ibm-ep-functions.jar
```

This is the pattern used by the [migration tools](../migration-tools/README.md) to make the UDFs and PTF available to Flink SQL jobs running on Confluent Platform for Flink.

## Build from source

Build the combined JAR from this directory:

```bash
git clone https://github.com/IBM/ibm-event-automation.git
cd ibm-event-automation/event-processing
mvn -f timestamp-udf/pom.xml clean install
mvn -f deduplication-ptf/pom.xml clean install
mvn -f ibm-ep-functions/pom.xml clean package
```

The combined JAR is produced at `ibm-ep-functions/target/ibm-ep-functions.jar`.

