# Event Gateway Utilities

Some utilities to help create certificates for you Event Gateways

| File                 | Description |
| ------------- | ----------- |
| generate-certs.sh     | Script that can create a ca cert and cert and key for your gateway using openssl. You will want to modify the script to create certificates that match your companies requirements |
| create-cluster-issuer.yaml     | Create a self-signed cluster issuer for your certificates. Nb. This must be run in the cert-operator namespace. You may want to change the CommonName and Subject of the ca certificate to match your requirements |
| create-gateway-certificate.yaml     | Create a certificate for your Gateway. You'll need to change the `<gateway-group>`, `<gateway-id>` and `<cluster-dns-address>` to the relevant values for your cluster. You may also want to change the CommonName and Subject to match your requirements|