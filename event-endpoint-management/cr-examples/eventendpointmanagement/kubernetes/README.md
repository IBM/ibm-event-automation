# Samples

This directory hosts samples of the `eventendpointmanagement` custom resource that can be used on Kubernetes platforms.  Samples need customization
and are non-functional without modification. 

To utilise the samples, you will need to:

- Specify the license, license metric and license use
- Accept the terms of the license
- Update the `spec.manager.endpoints[]` section with dns resolvable hostnames for each listed endpoint, this might be as simple as replacing `<CLUSTER_HOST>`.
- Replace all placeholder values indicated by angled brackets, for example: `<storage-class>`

To find out more about the samples see [the documentation](https://ibm.github.io/event-automation/eem/installing/planning/).

### Sample Overview
- [production.yaml](production.yaml) : A sample yaml file for production environments.
  - features:
    - OIDC auth configuration template
    - Customized TLS configuration including, root CA and UI certificate
    - Persistent storage


- [quick-start.yaml](quick-start.yaml) : A sample yaml file for development environments.
    - features:
        - Local secret based auth configuration
        - Persistent storage
        - Custom CPU and Memory resource settings


- [quick-start-with-ephemeral.yaml](quick-start-with-ephemeral.yaml) : A sample yaml file for development environments using ephemeral storage.
    - features:
        - Local secret based auth configuration
        - Ephemeral storage
        - Custom CPU and Memory resource settings


- [quick-start-with-API-Connect-integration.yaml](quick-start-with-API-Connect-integration.yaml) : A sample yaml file for integrating with IBM API Connect (APIC).
    - features:
        - Local secret based auth configuration
        - Ephemeral storage
        - APIC configuration options (mutual TLS disabled)


- [production-with-APIC-Dev-Portal-integration.yaml](production-with-APIC-Dev-Portal-integration.yaml) : A sample yaml file for production environments with IBM API Connect Developer Portal integration.
    - features:
        - OIDC auth configuration template
        - Customized TLS configuration including, root CA and UI certificate
        - APIC Developer Portal integration
        - Persistent storage
