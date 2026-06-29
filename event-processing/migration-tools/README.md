# migration-tools

## Introduction

IBM [announced](https://www.ibm.com/docs/en/announcements/withdrawl-event-automation) the Support lifecycle transition and software ordering completion for IBM Event Automation on June 9th 2026  stating that

> IBM intends to provide migration tools, services and entitlement flexibility to assist with migrating Event Streams and Event Processing deployments to IBM Confluent Platform.

This directory contains the migration tools mentioned above. Event Processing (EP) allows customers to create Flink workloads in two distinct ways:
- by creating flows in the EP low-code visual editor
- by creating new Java applications written directly to Flink’s Datastream and Table APIs

These tools exist to support migration of the first type of application - EP flows. The second type, custom Java applications, are straightforward to migrate: please refer directly to the Confluent Platform for Apache Flink [documentation](https://docs.confluent.io/cp-flink/current/overview.html)  for more information. 

These tools will be supported by further documentation on the Event Automation [site](https://ibm.github.io/event-automation/) in due course. 

## Prerequisites

To use these scripts you will need a MacOS or Linux-based machine to run the scripts on, plus
- `docker` (Docker Desktop, Rancher, podman or equivalent)
- The `confluent` CLI
- `kubectl` or `oc`
- Access to the Kubernetes cluster or clusters hosting your Event Processing and Confluent Platform Flink for Apache Flink installations
- Confluent Manager for Apache Flink (CMF) installed on the target cluster

## Purpose and process

As we will shortly describe in the Event Processing documentation, these tools support a three-step process:
1. Repackage the application components (`Dockerfile`)
2. Migrate application state (`copy-savepoint.sh`)
3. Deploy the migrated application (`deploy.sh`)

