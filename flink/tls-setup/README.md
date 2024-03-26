# TLS setup

This folder contains 3 yaml files

- create-cluster-issuer.yaml Creates a CA backed cluster issuer. You need to modify <cert-manager-namespace> to the namespace your cert manager is installed in.
- create-flink-operator-jks-certificate.yaml Creates a jks certificate for the flink operator. Change <flink-operator-namespace> to the namespace your flink operator is installed in and <Base64 encoded password> to be a base64 encoded password you want to use
- create-flink-deployment-jks-certificate Creates a jks certfiicate for your flink deployment. Change <flink-namespace> to the namespace you're creating your flinkdeployment, <flink-deployment-name> to the name of your flink dpeloyment and <Base64 encoded password> to be a base64 encoded password you want to use