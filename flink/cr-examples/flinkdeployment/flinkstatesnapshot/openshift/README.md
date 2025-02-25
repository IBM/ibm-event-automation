# Samples

This directory hosts samples of the `flinkstatesnapshot` custom resource.

**Note:** To utilise the samples to take snapshot, you will need to have running flink job in application cluster.

### Samples Overview

- [application-cluster-checkpoint.yaml](./application-cluster-checkpoint.yaml): Sample to take checkpoint. Mention name of the Flink Deployment resource in spec.jobReference.name to take checkpoint for the running job.

- [application-cluster-savepoint.yaml](./application-cluster-savepoint.yaml): Sample to take savepoint. Mention name of the Flink Deployment resource in spec.jobReference.name to take savepoint for the running job.

    - Features:
        - retry limit.
        - control disposal of savepoint when FlinkStateSnapshot custom resource is removed.