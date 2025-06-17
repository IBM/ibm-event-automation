# Samples

This directory hosts samples of the `flinksessionjob` custom resource.

**Note:** To use the samples, ensure you have a flink session cluster deployed using FlinkDeployment custom resource and a flink job written in java.

### Samples Overview

- [quick-start-session-job.yaml](./quick-start-session-job.yaml): This creates a flink session job in the [session-cluster-quick-start](../../flinkdeployment/openshift/quick-start.yaml) deployment.

- [production-session-job.yaml](./production-session-job.yaml): This creates a flink session job in the [session-cluster-prod](../../flinkdeployment/openshift/production.yaml) deployment

- [minimal-production-session-job.yaml](./minimal-production-session-job.yaml): This creates a flink session job in the [session-cluster-minimal-prod](../../flinkdeployment/openshift/minimal-production.yaml) deployment
