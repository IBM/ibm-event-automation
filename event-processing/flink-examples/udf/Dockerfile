ARG FLINK_IMAGE=none
FROM ${FLINK_IMAGE}

ARG UDF_JAR
COPY --chown=flink:root target/${UDF_JAR} /opt/flink/lib
COPY --chown=flink:root sql/sentences.ndjson /tmp/sentences.ndjson
