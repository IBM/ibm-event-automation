# migration-tools

IBM [announced](https://www.ibm.com/docs/en/announcements/withdrawl-event-automation) the Support lifecycle transition and software ordering completion for IBM Event Automation on June 9, 2026, stating that:

> IBM intends to provide migration tools, services and entitlement flexibility to assist with migrating Event Streams and Event Processing deployments to IBM Confluent.

This directory contains the tools that can help you migrate flows created in Event Processing to Confluent Platform for Apache Flink.

## Prerequisites

To run the scripts, ensure that you have a macOS or Linux-based machine with:

- Access to the Kubernetes cluster or clusters hosting your Event Processing and Confluent Platform Flink installations.
- `envsubst` (part of `gettext`, pre-installed on macOS and most Linux distributions).
- Confluent Manager for Apache Flink (CMF) installed on the target cluster.
- [Docker](https://docs.docker.com/engine/install/) or [Podman](https://podman.io/getting-started/installation.html) installed, to build the application image (Step 1).
- `kubectl` or `oc` installed, to copy savepoint state (Step 2).
- Sufficient local disk space to stage a temporary copy of the savepoint data.
- The [`confluent` CLI](https://docs.confluent.io/confluent-cli/current/install.html) installed, to deploy the application (Step 3).


## Procedure

The high-level steps to migrate flows are as follows:

1. Build the application Docker image by using the [`Dockerfile`](./Dockerfile).
2. Copy the state of your Flink job to the target namespace by using the [`copy-savepoint.sh`](./copy-savepoint.sh) script.
3. Deploy the migrated application by using the [`deploy.sh`](./deploy.sh) script, which creates a `FlinkApplication` custom resource in the target Confluent Manager for Apache Flink environment.

For the complete migration procedure, see the [Event Processing documentation](https://ibm.github.io/event-automation/ep/reference/migrate-to-confluent/).
