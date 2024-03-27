# TLS setup

This folder contains 3 YAML files:

- create-cluster-issuer.yaml Creates a CA backed cluster issuer. You need to modify <cert-manager-namespace> to the namespace your cert manager is installed in.
- create-flink-operator-jks-certificate.yaml Creates a jks certificate for the flink operator. Change <flink-operator-namespace> to the namespace your flink operator is installed in and <Base64 encoded password> to be a base64 encoded password you want to use
- `create-flink-deployment-jks-certificate.yaml`: Creates a JKS certfiicate for your Flink deployment. Modify `<flink-namespace>` to the namespace you are creating your `FlinkDeployment` instance, `<flink-deployment-name>` to the name of your Flink deployment, and `<base64-encoded-password>` to be a Base64-encoded password that you want to use.