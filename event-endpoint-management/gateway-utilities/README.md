# Event Gateway Utilities

Some utilities to help create certificates for you Event Gateways

| File                 | Description |
| ------------- | ----------- |
| generate-certs.sh     | Script that can create a ca cert and cert and key for your gateway using openssl. You will want to modify the script to create certificates that match your companies requirements. Optional arguments cert hostname (can be comma separated list), ca hostname, cert directory and ca directory |
| create-cluster-issuer.yaml     | Create a self-signed cluster issuer for your certificates. Nb. Modify the namespace of the yaml if you're cert-operator is not in the cert-manager namespace. You may want to change the CommonName and Subject of the ca certificate to match your requirements. |
| create-gateway-certificate.yaml     | Create a certificate for your Gateway. You'll need to change the `<gateway-group>`, `<gateway-id>` and `<cluster-dns-address>` to the relevant values for your cluster. You may also want to change the CommonName and Subject to match your requirements.|
| publish-gateway-certificate.sh | Modifies the create-gateway-certificate.yaml with the arguments you pass in and applies the file to your kubernetes cluster. Uses arguments gateway-group, gateway-id and cluster-dns and optionally the namespace you want the certificate to be created in. |



**Note** To get the cluster-dns-address of an openshift cluster run the command:
```bash
oc get ingresses.config/cluster -o jsonpath={.spec.domain}
```