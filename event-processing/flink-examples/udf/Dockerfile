ARG UDF_JAR
ARG FLINK_IMAGE
FROM --platform=linux/amd64 ${FLINK_IMAGE}
COPY --chown=flink:root target/${UDF_JAR} /opt/flink/lib
COPY --chown=flink:root sql/sentences.ndjson /tmp/sentences.ndjson
