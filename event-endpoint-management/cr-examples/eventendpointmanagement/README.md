# Samples

This directory hosts samples of the `eventendpointmanagement` custom resource.  Samples need customization
and are non-functional without modification. 

To utilise the samples, you will need to:

- Specify the license, license metric and license use
- Accept the terms of the license
- Replace all placeholder values indicated by angled brackets, for example: `<storage-class>`

To find out more about the samples see [the documentation](https://ibm.github.io/event-automation/eem/installing/planning/).

### Sample Overview
- [production.yaml](./production.yaml) : A sample yaml file for production environments.
  - features:
    - OIDC auth configuration template
    - Customized TLS configuration including, root CA and UI certificate
    - Persistent storage


- [quick-start.yaml](./quick-start.yaml) : A sample yaml file for development environments.
    - features:
        - Local secret based auth configuration
        - Ephemeral storage
        - Custom CPU and Memory resource settings


- [quick-start-with-api-connect-integration.yaml](./quick-start-with-api-connect-integration.yaml) : A sample yaml file for integrating with IBM API Connect (APIC).
    - features:
        - Local secret based auth configuration
        - Ephemeral storage
        - APIC configuration options (mutual TLS disabled)


- [usage-based-pricing.yaml](./usage-based-pricing.yaml) : A sample yaml file highlighting configuration for usage based pricing license metrics.
    - features:
        - Local secret based auth configuration
        - Persistent storage
        - License service integration for API call logging