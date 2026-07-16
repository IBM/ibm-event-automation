# migration-tools

## Introduction

IBM [announced](https://www.ibm.com/docs/en/announcements/withdrawal-event-automation) the Support lifecycle transition and software ordering completion for IBM Event Automation on June 9, 2026, stating that

> IBM intends to provide migration tools, services and entitlement flexibility to assist with migrating Event Streams and Event Processing deployments to IBM Confluent Platform.

The following table describes the methods available in {{site.data.reuse.ep_name}} for creating Flink workloads and their migration process:

| Workload type | Migration process |
|---|---|
| Flows created in the {{site.data.reuse.ep_name}} low-code visual editor | Flows are exported as SQL files, migrated, and executed on {{site.data.reuse.cpf_long}} as an application, ensuring native {{site.data.reuse.cpf_long}} support. This directory contains the migration tools that are required to migrate your Event Processing flows. |
| Java applications written directly to Flink's Datastream and Table APIs | Outside the scope of this document. The following are the high level steps to migrate a Java application: <br><br>1. Understand how your Flink application is deployed and what state it holds. <br><br>2. Read the [{{site.data.reuse.cpf_long}} documentation](https://docs.confluent.io/cp-flink/current/overview.html){:target="_blank"}. <br><br>3. [Repackage your application](https://docs.confluent.io/cp-flink/current/jobs/applications/packaging.html){:target="_blank"} for {{site.data.reuse.cpf_long}}. <br><br>4. Migrate your state. The [copy-savepoint.sh](https://github.com/IBM/ibm-event-automation/blob/main/event-processing/migration-tools/copy-savepoint.sh){:target="_blank"} script might be useful. <br><br>5. Deploy your application. The [deploy.sh](https://github.com/IBM/ibm-event-automation/blob/main/event-processing/migration-tools/deploy.sh){:target="_blank"} script might also help. |


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

Follow the steps in the [Event Processing documentation](https://ibm.github.io/event-automation/ep/reference/migrate-to-confluent/) to migrate. The overview of the steps are as follows:

1. Build the application docker image (A sample `Dockerfile` is available).
2. Migrate your application state (by using the `copy-savepoint.sh` script).
3. Deploy the migrated application (by using the`deploy.sh` script).