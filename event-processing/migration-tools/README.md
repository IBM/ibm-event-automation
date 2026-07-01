# migration-tools

## Introduction

IBM [announced](https://www.ibm.com/docs/en/announcements/withdrawal-event-automation) the Support lifecycle transition and software ordering completion for IBM Event Automation on June 9, 2026, stating that

> IBM intends to provide migration tools, services and entitlement flexibility to assist with migrating Event Streams and Event Processing deployments to IBM Confluent Platform.

With Event Processing, you can create Flink workloads in two distinct ways:

- By creating flows in the Event Processing low-code visual editor
- By creating new Java applications written directly to Flink’s Datastream and Table APIs

This directory contains the migration tools to migrate your Event Processing flows.

The second type, custom Java applications, are straightforward to migrate. Follow the steps in the Confluent Platform for Apache Flink [documentation](https://docs.confluent.io/cp-flink/current/overview.html) for more information.

Further information is available on the Event Automation [documentation](https://ibm.github.io/event-automation/).

## Prerequisites

To use these scripts, you need a macOS or Linux-based machine to run the scripts on:

- [Docker](https://docs.docker.com/engine/install/){:target="_blank"} or [Podman CLI](https://podman.io/getting-started/installation.html){:target="_blank"} installed.
(Docker Desktop, Rancher, podman or equivalent)
- The `confluent` CLI installed.
- If you are using {{site.data.reuse.openshift}}, ensure you have the following set up for your environment:

  - A supported version of the {{site.data.reuse.openshift_short}} [installed](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/){:target="_blank"}.  For supported versions, see the [support matrix]({{ 'support/matrix/#event-processing' | relative_url }}).
  - The {{site.data.reuse.openshift_short}} CLI (`oc`) [installed](https://docs.redhat.com/en/documentation/openshift_container_platform/4.21/html/cli_tools/openshift-cli-oc#cli-getting-started){:target="_blank"}.

- If you are using other Kubernetes platforms, ensure you have the following set up for your environment:

  - A supported version of a Kubernetes platform installed. For supported versions, see the [support matrix]({{ 'support/matrix/#event-processing' | relative_url }}).
  - The Kubernetes command-line tool (`kubectl`) [installed](https://v1-35.docs.kubernetes.io/docs/tasks/tools/){:target="_blank"}.
- Access to the Kubernetes cluster or clusters hosting your Event Processing and Confluent Platform Flink for Apache Flink installations.
- Confluent Manager for Apache Flink (CMF) installed on the target cluster.

## Procedure

Follow the steps in the [Event Processing documentation](https://ibm.github.io/event-automation/) to migrate. The overview of the steps are as follows:

1. Repackage the application components (`Dockerfile`)
2. Migrate application state (`copy-savepoint.sh`)
3. Deploy the migrated application (`deploy.sh`)

