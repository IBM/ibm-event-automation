# TLS setup

This folder contains 3 YAML files:

- `create-cluster-issuer.yaml`:  Creates a CA-backed cluster issuer. You need to modify `<cert-manager-namespace>` to the namespace where your cert manager operator is installed.
- `create-flink-operator-jks-certificate.yaml`: Creates a JKS certificate for the Flink operator. Modify `<flink-operator-namespace>` to the namespace where your flink operator is installed, and `<base64-encoded-password>` to be a Base64-encoded password that you want to use.
- `create-flink-deployment-jks-certificate.yaml`: Creates a JKS certfiicate for your Flink deployment. Modify `<flink-namespace>` to the namespace you are creating your `FlinkDeployment` instance, `<flink-deployment-name>` to the name of your Flink deployment, and `<base64-encoded-password>` to be a Base64-encoded password that you want to use.