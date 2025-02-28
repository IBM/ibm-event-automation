# Samples

This directory hosts samples of the `flinkstatesnapshot` custom resource.

**Note:** To use the samples to take a snapshot, you must have a running Flink job in the application cluster.

### Samples Overview

- [application-cluster-checkpoint.yaml](application-cluster-checkpoint.yaml): Sample to take a checkpoint. Add the name of the Flink Deployment resource in `spec.jobReference.name` to take a checkpoint for the running job.

- [application-cluster-savepoint.yaml](application-cluster-savepoint.yaml): Sample to take a savepoint. Add the name of the Flink Deployment resource in `spec.jobReference.name` to take a savepoint for the running job.

    - Features:
        - Retry limit.
        - Control the disposal of a savepoint when the `FlinkStateSnapshot` custom resource is removed.