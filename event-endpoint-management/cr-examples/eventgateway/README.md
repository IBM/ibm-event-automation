# Samples

This directory hosts samples of the `eventgateway` custom resource.  Samples need customization
and are non-functional without modification.

To utilise the samples, you will need to:

- Specify the license, license metric and license use
- Accept the terms of the license
- Replace all placeholder values indicated by angled brackets, for example: `<eem-manager-gateway-route>`

To find out more about the samples see [the documentation](https://ibm.github.io/event-automation/eem/installing/planning/).

### Sample Overview
- [production.yaml](./production.yaml) : A sample yaml file for production environments.


- [quick-start.yaml](./quick-start.yaml) : A sample yaml file for development environments.
    - features:
        - Custom CPU and Memory resource settings


- [usage-based-pricing.yaml](./usage-based-pricing.yaml) : A sample yaml file highlighting configuration for usage based pricing (UBP) license metrics.
    - features:
        - UBP configuration