# migration-tools

This directory contains the tools required to migrate flows created in the IBM Event Processing low-code canvas to Confluent Platform for Apache Flink.

For complete migration steps, see the [Event Processing documentation](https://ibm.github.io/event-automation/ep/reference/migrate-to-confluent/).

## Overview

IBM [announced](https://www.ibm.com/docs/en/announcements/withdrawl-event-automation) the Support lifecycle transition and software ordering completion for IBM Event Automation on June 9, 2026, stating that:

> IBM intends to provide migration tools, services and entitlement flexibility to assist with migrating Event Streams and Event Processing deployments to IBM Confluent Platform.

The following table describes the methods available in IBM Event Processing for creating Flink workloads and their migration process:

| Workload type | Migration process |
|---|---|
| Flows created in the IBM Event Processing low-code visual editor | Flows are exported as SQL files, migrated, and executed on Confluent Platform for Apache Flink as an application. This directory contains the migration tools required. |
| Java applications written directly to Flink's Datastream and Table APIs | Outside the scope of this document. The following are the high level steps to migrate a Java application: <br><br>1. Understand how your Flink application is deployed and what state it holds. <br><br>2. Read the [Confluent Platform for Apache Flink documentation](https://docs.confluent.io/cp-flink/current/overview.html). <br><br>3. [Repackage your application](https://docs.confluent.io/cp-flink/current/jobs/applications/packaging.html) for Confluent Platform for Apache Flink. <br><br>4. Migrate your state. The [copy-savepoint.sh](https://github.com/IBM/ibm-event-automation/blob/main/event-processing/migration-tools/copy-savepoint.sh) script might be useful. <br><br>5. Deploy your application. The [deploy.sh](https://github.com/IBM/ibm-event-automation/blob/main/event-processing/migration-tools/deploy.sh) script might also help. |

## Limitations

- Flows that use the detect patterns node or the deduplicate node cannot be migrated directly to Confluent Platform for Apache Flink.

## Prerequisites

Before you begin:

1. Export each of your flows from IBM Event Processing as an SQL file.
2. Restore redacted credentials and amend the SQL for the target environment.
3. Install [Confluent Manager for Apache Flink (CMF)](https://docs.confluent.io/cp-flink/current/get-started/get-started-application.html) and [Confluent for Kubernetes](https://docs.confluent.io/operator/current/co-deploy-cfk.html) in your target environment.

To run the scripts, you also need a macOS or Linux-based machine with:

- Access to the Kubernetes cluster or clusters hosting your Event Processing and Confluent Platform Flink installations.
- `envsubst` (part of `gettext`, pre-installed on macOS and most Linux distributions).
- Confluent Manager for Apache Flink (CMF) installed on the target cluster.
- [Docker](https://docs.docker.com/engine/install/) or [Podman](https://podman.io/getting-started/installation.html) installed, to build the application image (Step 1).
- `kubectl` or `oc` installed, to copy savepoint state (Step 2).
- Sufficient local disk space to stage a temporary copy of the savepoint data.
- The [`confluent` CLI](https://docs.confluent.io/confluent-cli/current/install.html) installed, to deploy the application (Step 3).


## Procedure

Follow the steps in the [Event Processing documentation](https://ibm.github.io/event-automation/ep/reference/migrate-to-confluent/) to migrate. The high-level steps are:

1. Build the application Docker image by using the [`Dockerfile`](./Dockerfile).
2. Copy the state of your Flink job to the target namespace by using the [`copy-savepoint.sh`](./copy-savepoint.sh) script.
3. Deploy the migrated application by using the [`deploy.sh`](./deploy.sh) script, which creates a `FlinkApplication` custom resource in the target Confluent Manager for Apache Flink environment.
