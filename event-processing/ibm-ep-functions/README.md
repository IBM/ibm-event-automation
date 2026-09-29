# IBM Event Processing Functions

[![IBM EP Functions Build](https://github.com/IBM/ibm-event-automation/actions/workflows/ibm-ep-functions-release.yml/badge.svg)](https://github.com/IBM/ibm-event-automation/actions/workflows/ibm-ep-functions-release.yml) [![Releases](https://img.shields.io/badge/releases-view-blue)](https://github.com/IBM/ibm-event-automation/releases)

A combined JAR containing the Timestamp UDFs and Deduplication PTF for Apache Flink SQL.
Originally developed for IBM Event Processing.

| Module | Description | Reference |
|---|---|---|
| [Timestamp UDFs](../timestamp-udf/README.md) | Parse ISO 8601 and SQL-formatted timestamp strings. See [Flink scalar functions](https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/functions/udfs/). | `TO_TIMESTAMP_UDF`, `TO_TIMESTAMP_LTZ_UDF` |
| [Deduplication PTF](../deduplication-ptf/README.md) | Deduplicate events within a configurable time window. See [Flink Process Table Functions](https://nightlies.apache.org/flink/flink-docs-release-2.3/docs/dev/table/functions/ptfs/). | `DEDUPLICATE_PTF` |

---

* [Prerequisites](#prerequisites)
* [Installation](#installation)
* [Build from source](#build-from-source)
* [Release procedure](#release-procedure)

---

## Prerequisites

Only if you want to build from sources:
- Java 11+
- Flink 2.2.1+
- Maven 3

## Installation

Download `ibm-ep-functions.jar` from [GitHub Releases](https://github.com/IBM/ibm-event-automation/releases).

Add the JAR to your Flink job's runtime classpath. For example, with Flink SQL Client:

```bash
./bin/sql-client.sh --jar /path/to/ibm-ep-functions.jar
```

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

## Release procedure

To publish a new release, in GitHub:
1. Select [Create a new Release](https://github.com/IBM/ibm-event-automation/releases/new)
2. Create or select the tag using the format `ep-functions-vX.Y.Z`
3. Set the release title to the tag value
4. Select `Generate release notes`
5. Select `Publish Release`

Publishing the Release triggers `.github/workflows/ibm-ep-functions-release.yml` which builds the combined JAR and uploads `ibm-ep-functions.jar` as a release asset.

Notes:
- Pushing the tag alone does not publish the jar.
- The release workflow only runs for tags starting with `ep-functions-v`.
- The jar is published as a GitHub Release asset, not to a Maven repository.
