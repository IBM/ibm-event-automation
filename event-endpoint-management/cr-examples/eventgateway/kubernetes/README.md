# Samples

This directory hosts samples of the `eventgateway` custom resource that can be used on Kubernetes platforms.  Samples need customization
and are non-functional without modification.

To utilise the samples, you will need to:

- Specify the license, license metric and license use
- Accept the terms of the license
- Update the `spec.listeners[].groups[].endpoint.host` section with dns resolvable hostnames for each listed endpoint, this might be as simple as replacing `<CLUSTER_HOST>`.
- Replace all placeholder values indicated by angled brackets, for example: `<eem-manager-server-endpoint>`

To find out more about the samples see [the documentation](https://ibm.github.io/event-automation/eem/installing/planning/).

### Sample Overview
- [production.yaml](production.yaml) : A sample yaml file for production environments.
    - features:
        - Manager endpoint and API key configuration
        - Listener with TLS and explicit gateway group
        - Custom max Kafka broker limit


- [quick-start.yaml](quick-start.yaml) : A sample yaml file for development environments.
    - features:
        - Listener with explicit gateway group
        - Custom CPU and Memory resource settings
