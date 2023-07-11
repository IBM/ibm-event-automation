# Samples

This directory hosts samples of the `flinkdeployment` custom resource.

To use the samples, accept the terms of the [license agreement](https://ibm.biz/ea-license) by setting
`spec.flinkConfiguration.license.accept` to 'true'.

To find out more about the samples, see the [documentation](https://ibm.github.io/event-automation/ep/installing/planning/#flink-sample-deployments).

### Samples Overview

- [quick-start.yaml](./quick-start.yaml): A Flink [session cluster](https://nightlies.apache.org/flink/flink-docs-release-1.17/docs/concepts/flink-architecture/#flink-session-cluster)
  for very small workloads that have no persistence or reliability requirements. Suitable for use with the Event Processing flow authoring UI,
  and for deploying advanced flows to [development environments](https://ibm.github.io/event-automation/ep/advanced/deploying-development).
   - Features:
      - Low CPU and memory requests and limits.
      - Ephemeral storage.

- [production.yaml](./production.yaml): A Flink [session cluster](https://nightlies.apache.org/flink/flink-docs-release-1.17/docs/concepts/flink-architecture/#flink-session-cluster)
  for production workloads. Suitable for use with the Event Processing flow authoring UI, and for deploying advanced flows to
  [development environments](https://ibm.github.io/event-automation/ep/advanced/deploying-development).
   - Features:
      - Persistent storage.
      - High Availability for the Flink Job Manager.
  - Prerequisites:
      - [Deploy the Flink PVC](https://ibm.github.io/event-automation/ep/installing/planning/#deploying-the-flink-pvc).
 
- [minimal-production.yaml](./minimal-production.yaml): A Flink [session cluster](https://nightlies.apache.org/flink/flink-docs-release-1.17/docs/concepts/flink-architecture/#flink-session-cluster)
  for small production workloads. Suitable for use with the Event Processing flow authoring UI, and for deploying advanced flows to
  [development environments](https://ibm.github.io/event-automation/ep/advanced/deploying-development).
   - Features:
      - Persistent storage.
      - Lower CPU and memory requests/limits than the Production sample.
   - Prerequisites:
      - [Deploy the Flink PVC](https://ibm.github.io/event-automation/ep/installing/planning/#deploying-the-flink-pvc).

- [production-application-cluster.yaml](./production-application-cluster.yaml): A Flink [application cluster](https://nightlies.apache.org/flink/flink-docs-release-1.17/docs/concepts/flink-architecture/#flink-application-cluster)
  for production workloads. Suitable for deploying advanced flows to [production environments](https://ibm.github.io/event-automation/ep/advanced/deploying-production/).
   - Features:
      - Persistent storage.
   - Prerequisites:
      - Replace all placeholder values indicated by angled brackets, for example: `<insert jar file name here>`.
      - [Deploy the Flink PVC](https://ibm.github.io/event-automation/ep/installing/planning/#deploying-the-flink-pvc).
   - Not suitable when deploying Flink for use with the Event Processing flow authoring UI.