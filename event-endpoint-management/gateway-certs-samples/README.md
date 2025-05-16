# Event Gateway certificate creation samples

Sample scripts for creating certificates for Event Gateways.

Please note that these are simplified scripts to illustrate the certificate requirements of an Event Gateway and should not be considered suitable for production usage.

**Contents:**

- [generate-certs.sh](#generate-certssh)
- [create-cluster-issuer.yaml](#create-cluster-issueryaml)
- [create-gateway-certificate.yaml](#create-gateway-certificateyaml)
- [publish-gateway-certificate.yaml](#publish-gateway-certificatesh)

## generate-certs.sh

[link to file](./generate-certs.sh)

### What this does

This shell script uses openssl to create:
- a Certificate Authority certificate
- a certificate and private key for an Event Gateway

### What you should modify

You should modify the script to create certificates that match your requirements.

### To use this

Run the shell script with the following arguments:

```sh
generate-certs.sh <HOSTNAME> <CA_HOSTNAME> <DIRECTORY>
```

|                 |                                    | default if not specified |
|-----------------|------------------------------------|--------------------------|
| `<HOSTNAME>`    | hostname(s) to add to the certificate<br>Use a comma-separated list if you want to add multiple hostnames to the certificate | `localhost`   |
| `<CA_HOSTNAME>` | hostname(s) to use for the certificate authority<br>Use a comma-separated list if you want to add multiple hostnames  | `localhost`   |
| `<DIRECTORY>`   | directory to create the certificates in       | `./certs`     |


## create-cluster-issuer.yaml

[link to file](./create-cluster-issuer.yaml)

### What this does

These definitions can be used with [a Kubernetes cert-manager Operator](https://ibm.github.io/event-automation/eem/installing/prerequisites/#certificate-management) to create a self-signed cluster issuer that can be used for your other certificates

### What you should modify

You should modify the namespace that is used to match where you are running your cert-manager Operator.

You should also change the CommonName and Subject used in the CA certificate to match your requirements.

### To use this

Apply the modified YAML in your Kubernetes cluster where the cert-manager is running.


## create-gateway-certificate.yaml

[link to file](./create-gateway-certificate.yaml)

### What this does

These definitions can be used with [a Kubernetes cert-manager Operator](https://ibm.github.io/event-automation/eem/installing/prerequisites/#certificate-management) to create a certificate for an Event Gateway

### What you should modify

You should replace `gateway-cluster-issuer` to match the name of a secret where a Cluster Issuer is stored (such as the example created by [`create-cluster-issuer.yaml`](#create-cluster-issueryaml)).

You should replace the `<gateway-group>` and `<gateway-id>` placeholders with the details of the Event Gateway that the certificate will be used for.

You should replace the `<cluster-dns-address>` placeholder with the hostname used by your cluster.

To get the cluster-dns-address of an OpenShift cluster, you can run the command:
```sh
oc get ingresses.config/cluster -o jsonpath={.spec.domain}
```

You should also change the CommonName and Subject used in the CA certificate to match your requirements.

### To use this

You first need to have a Cluster Issuer certificate that can be used to create the Gateway certificate.

Apply the modified YAML in your Kubernetes cluster where the cert-manager is running.

An [example helper shell script](#publish-gateway-certificatesh) is available to show how this can be done.

## publish-gateway-certificate.sh

[link to file](./publish-gateway-certificate.sh)

### What this does

This is an example of a helper shell script for using the [`create-gateway-certificate.yaml`](#create-gateway-certificateyaml) sample.

It will:
- substitute in the provided arguments for the placeholder values in the sample
- apply the modified sample to your Kubernetes cluster

### To use this

You first need to have a Cluster Issuer certificate that can be used to create the Gateway certificate.

Run the shell script with the following arguments:

```sh
publish-gateway-certificate.sh <GATEWAY_GROUP> <GATEWAY_ID> <CLUSTER_DNS> [NAMESPACE]
```

|                   | Required |
| ----------------- | -------- |
| `<GATEWAY_GROUP>` | yes      |
| `<GATEWAY_ID>`    | yes      |
| `<CLUSTER_DNS>`   | yes      |
| `[NAMESPACE]`     | no - if not provided, the current namespace is used |

To get the cluster-dns-address of an OpenShift cluster, you can run the command:
```sh
oc get ingresses.config/cluster -o jsonpath={.spec.domain}
```