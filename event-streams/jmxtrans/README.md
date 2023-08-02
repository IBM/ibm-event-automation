# JmxTrans

[JMX Trans](https://github.com/jmxtrans/jmxtrans) is a tool for collecting data from JMX endpoints of Java applications and sending it to other applications and services. 

The ability to deploy JmxTrans was deprecated in Event Streams 11.1.5 and removed in Event Streams 11.2.0. While the JmxTrans tool remains unsupported, this document provides high-level guidance on how to deploy it separately alongside an Event Streams instance.

To configure [JmxTrans](https://github.com/jmxtrans/jmxtrans/wiki) with Event Streams, complete the following steps:
1. Create a ConfigMap for JmxTrans configuration.
2. Build a container image that includes Java 11 runtime and the JmxTrans tool.
3. Deploy JmxTrans by using the ConfigMap and the container image.

## Configuring JmxTrans

[JmxTrans documentation](https://github.com/jmxtrans/jmxtrans/wiki) provides further guidance on defining [queries](https://github.com/jmxtrans/jmxtrans/wiki/Queries) and [output writers](https://github.com/jmxtrans/jmxtrans/wiki/OutputWriters). The configuration depends largely on what information is to be captured and where it must be sent. 

The configuration can be deployed as a ConfigMap and then made available to the JmxTrans tool. An example ConfigMap definition is included as a reference. 


```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: <jmxtrans-config>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: jmx-trans
data:
  config.json: |
    '{
      "servers": [
        {
          "host": "<eventstreams-name>-kafka-<broker-id>.<eventstreams-name>-kafka-brokers",
          "port": 9999,
          "queries": [
            {
              "obj": "kafka.server:type=BrokerTopicMetrics,name=*",
              "attr": [
                "Count"
              ],
              "outputWriters": [
                {
                  "@class": "com.googlecode.jmxtrans.model.output.StdOutWriter"
                }
              ]
            }
          ]
        },
        // repeat for each broker
      ]
    }'
```

Where:
- `<jmxtrans-config>` is the name of the ConfigMap.
- `<namespace>` is the namespace where Event Streams is installed.
- `<eventstreams-name>` is the name of the Event Streams instance.
- `<broker-id>` is Kafka broker ID (for example 0).


## JmxTrans container image

JmxTrans is a Java application. This means that a container image, which includes a Java runtime and the JmxTrans tool, is needed to deploy the application on Kubernetes environments. Build a custom image that include a Java runtime and the JmxTrans tool.

**Important:** JmxTrans only supports Java 11.

**Note:** Event Streams 11.1.6 (and earlier) included a container image for running the JmxTrans tool. For example, `cp.icr.io/cp/ibm-eventstreams-jmxtrans@sha256:c43965013d22d3227cf7c1bf1211d59b0595ce6d535ab3fab8e7c80694417f76`. This container image is no longer maintained and does not receive security updates. 

### Custom JmxTrans image

Build a container image that includes Java 11 runtime and the JmxTrans tool. An example [Dockerfile](./Dockerfile) to build such an image is provided as a reference. 

You can build and push the container image by using these commands:  
```
docker build -t <image-registry>/<image-name>:<image-tag> .
docker push <image-registry>/<image-name>:<image-tag>
```

## JmxTrans Deployment

Create a deployment with the JmxTrans image and mount the configuration that is defined in the ConfigMap. An example deployment definition is included as a reference.

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: <jmxtrans-deployment>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: jmx-trans
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: jmx-trans
  template:
    metadata:
      labels:
        app.kubernetes.io/name: jmx-trans
    spec:
      restartPolicy: Always
      imagePullSecrets:
        - name: <image-pull-secret>
      schedulerName: default-scheduler
      terminationGracePeriodSeconds: 30
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: "RuntimeDefault"
      containers:
        - resources:
            limits:
              cpu: '1'
              memory: 1Gi
            requests:
              cpu: 250m
              memory: 1Gi
          readinessProbe:
            exec:
              command:
                - /opt/jmx/jmxtrans_readiness_check.sh
                - <es-name>-kafka-brokers
                - '9999'
            initialDelaySeconds: 15
            timeoutSeconds: 5
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          terminationMessagePath: /dev/termination-log
          name: <jmx-trans>
          env:
            - name: STRIMZI_JMX_USERNAME
              valueFrom:
                secretKeyRef:
                  name: <es-name>-kafka-jmx
                  key: jmx-username
            - name: STRIMZI_JMX_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: <es-name>-kafka-jmx
                  key: jmx-password
            - name: JMXTRANS_LOGGING_LEVEL
              value: INFO
          securityContext:
            capabilities:
              drop:
                - ALL
            privileged: false
            runAsNonRoot: true
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
          imagePullPolicy: IfNotPresent
          volumeMounts:
            - name: strimzi-tmp
              mountPath: /tmp
            - name: jmx-config
              mountPath: /var/lib/jmxtrans
          terminationMessagePolicy: File
          image: >-
            <image-registry>/<image-name>:<image-tag>
      volumes:
        - name: strimzi-tmp
          emptyDir:
            medium: Memory
            sizeLimit: 30Mi
        - name: jmx-config
          configMap:
            name: <jmxtrans-config>
            defaultMode: 420
      dnsPolicy: ClusterFirst
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
```

Where:
- `<es-name>` is the name of the Event Streams instance.
- `<jmxtrans-config>` is the name of the JmxTrans ConfigMap.
- `<image-registry>` is the name of the image registry.
- `<image-name>` is the name of the JmxTrans image.
- `<image-tag>` is the tag for the JmxTrans image.
- `<image-pull-secret>` is the name of the image pull secret.

**Note:** If the Kafka JMX port is not configured with security, remove the environment variables `STRIMZI_JMX_USERNAME` and `STRIMZI_JMX_PASSWORD` from the definition.