# Multi-stage Dockerfile for migrating IBM Event Automation flows to Confluent Platform Flink
# This Dockerfile builds a custom image containing:
# - Apache Flink SQL Runner (modified for Confluent dependencies)
# - Confluent-supported connectors (Kafka, JDBC, File)
# - Required dependencies (kafka-clients)
# - Customer's flow.sql file

# Build arguments for version control
# CONFLUENT_FLINK_VERSION      — cp-flink Docker image tag (includes platform suffix)
# CONFLUENT_FLINK_MAVEN_VERSION — Maven artifact version for io.confluent.flink dependencies
#                                 (no platform suffix; must match the image's Flink release)
ARG CONFLUENT_FLINK_VERSION=2.1.2-cp1-java11-amd64
ARG CONFLUENT_FLINK_MAVEN_VERSION=2.1.2-cp1
ARG FLINK_OPERATOR_VERSION=main
ARG KAFKA_CONNECTOR_VERSION=4.0.1-2.0-cp2
ARG KAFKA_CLIENTS_VERSION=3.9.1
ARG JDBC_DRIVER_VERSION=2.1.2-cp1
ARG FILE_SINK_VERSION=2.1.2-cp1
ARG APACHE_HTTP_CONNECTOR_VERSION=1.0.0-2.2
ARG GETINDATA_HTTP_CONNECTOR_VERSION=0.12.0

# REQUIRED: Customer must provide path to their flow.sql file
ARG FLOW_SQL_PATH

# =============================================================================
# Stage 1: Build SQL Runner with Confluent Maven coordinates
# =============================================================================
FROM maven:3.9-eclipse-temurin-11 AS builder

ARG FLINK_OPERATOR_VERSION
ARG CONFLUENT_FLINK_MAVEN_VERSION

WORKDIR /build

# Install xmlstarlet for XML manipulation
RUN apt-get update && apt-get install -y xmlstarlet && rm -rf /var/lib/apt/lists/*

# Clone Apache Flink Kubernetes Operator
RUN git clone --depth 1 --branch ${FLINK_OPERATOR_VERSION} \
    https://github.com/apache/flink-kubernetes-operator.git

WORKDIR /build/flink-kubernetes-operator/examples/flink-sql-runner-example

# Patch pom.xml to use Confluent's Maven repository and artifacts
# Reference: https://docs.confluent.io/cp-flink/current/jobs/applications/packaging.html#set-up-the-project-configuration

# Add Confluent Maven repository
RUN xmlstarlet ed --inplace \
    --subnode "/project" --type elem -n "repositories" \
    --subnode "/project/repositories" --type elem -n "repository" \
    --subnode "/project/repositories/repository" --type elem -n "id" -v "confluent" \
    --subnode "/project/repositories/repository" --type elem -n "url" -v "https://packages.confluent.io/maven" \
    pom.xml

# Add confluent.flink.version property
RUN xmlstarlet ed --inplace \
    --subnode "/project/properties" --type elem -n "confluent.flink.version" -v "${CONFLUENT_FLINK_MAVEN_VERSION}" \
    pom.xml

# Update Flink dependencies to use Confluent's groupId and version
# Change org.apache.flink to io.confluent.flink for dependencies (but not parent)
RUN xmlstarlet ed --inplace \
    --update "//dependency[groupId='org.apache.flink']/groupId" --value "io.confluent.flink" \
    --update "//dependency[groupId='io.confluent.flink' and version='\${flink.version}']/version" --value "\${confluent.flink.version}" \
    pom.xml

# Build the SQL Runner jar (skip XML format check, override Java target to 11)
RUN mvn clean package -DskipTests -Dxml.skip=true -Dmaven.compiler.source=11 -Dmaven.compiler.target=11

# =============================================================================
# Stage 2: Fetch Confluent connectors and dependencies
# =============================================================================
FROM maven:3.9-eclipse-temurin-11 AS dependency-fetcher

ARG KAFKA_CONNECTOR_VERSION
ARG KAFKA_CLIENTS_VERSION
ARG JDBC_DRIVER_VERSION
ARG FILE_SINK_VERSION
ARG APACHE_HTTP_CONNECTOR_VERSION
ARG GETINDATA_HTTP_CONNECTOR_VERSION

WORKDIR /connectors

# Here we download all the connectors typically used by Event Processing flows. Your particular flow may require only a subset of these:
# you should feel free to remove any dependencies that you do not need.

# Fetch Confluent Kafka connector
RUN mvn dependency:get \
    -DremoteRepositories=https://packages.confluent.io/maven \
    -Dartifact=io.confluent.flink:flink-connector-kafka:${KAFKA_CONNECTOR_VERSION} \
    -Dtransitive=false

# Fetch kafka-clients (required by Kafka connector)
RUN mvn dependency:get \
    -Dartifact=org.apache.kafka:kafka-clients:${KAFKA_CLIENTS_VERSION} \
    -Dtransitive=false

# Fetch Confluent JDBC driver bundle
RUN mvn dependency:get \
    -DremoteRepositories=https://packages.confluent.io/maven \
    -Dartifact=io.confluent.flink:flink-sql-jdbc-driver-bundle:${JDBC_DRIVER_VERSION} \
    -Dtransitive=false

# Fetch Confluent File sink
RUN mvn dependency:get \
    -DremoteRepositories=https://packages.confluent.io/maven \
    -Dartifact=io.confluent.flink:flink-file-sink-common:${FILE_SINK_VERSION} \
    -Dtransitive=false

# Fetch Apache Flink HTTP connector (for flows exported from Event Processing v1.5.4 and later)
RUN mvn dependency:get \
    -Dartifact=org.apache.flink:flink-sql-connector-http:${APACHE_HTTP_CONNECTOR_VERSION} \
    -Dtransitive=false

# Fetch GetInData HTTP connector (for flows exported from Event Processing v1.5.3 and earlier)
RUN mvn dependency:get \
    -Dartifact=com.getindata:flink-http-connector:${GETINDATA_HTTP_CONNECTOR_VERSION} \
    -Dtransitive=false

# Copy connector jars to /connectors/lib
RUN mkdir -p /connectors/lib && \
    cp ~/.m2/repository/io/confluent/flink/flink-connector-kafka/${KAFKA_CONNECTOR_VERSION}/flink-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar /connectors/lib/ && \
    cp ~/.m2/repository/io/confluent/flink/flink-sql-jdbc-driver-bundle/${JDBC_DRIVER_VERSION}/flink-sql-jdbc-driver-bundle-${JDBC_DRIVER_VERSION}.jar /connectors/lib/ && \
    cp ~/.m2/repository/io/confluent/flink/flink-file-sink-common/${FILE_SINK_VERSION}/flink-file-sink-common-${FILE_SINK_VERSION}.jar /connectors/lib/ && \
    cp ~/.m2/repository/org/apache/flink/flink-sql-connector-http/${APACHE_HTTP_CONNECTOR_VERSION}/flink-sql-connector-http-${APACHE_HTTP_CONNECTOR_VERSION}.jar /connectors/lib/ && \
    cp ~/.m2/repository/com/getindata/flink-http-connector/${GETINDATA_HTTP_CONNECTOR_VERSION}/flink-http-connector-${GETINDATA_HTTP_CONNECTOR_VERSION}.jar /connectors/lib/

# Copy other dependencies (non-connector libraries) to /dependencies/lib
RUN mkdir -p /dependencies/lib && \
    cp ~/.m2/repository/org/apache/kafka/kafka-clients/${KAFKA_CLIENTS_VERSION}/kafka-clients-${KAFKA_CLIENTS_VERSION}.jar /dependencies/lib/

# Download IBM Event Processing UDF jar (contains TO_TIMESTAMP_LTZ and Deduplication PTF)
RUN curl -L -o /dependencies/lib/ibm-ep-udf.jar \
    https://github.com/IBM/ibm-event-automation/releases/download/timestamp-udf-v1.0.0/ibm-ep-udf.jar

# =============================================================================
# Stage 3: Build final image with Confluent Flink runtime
# =============================================================================
FROM confluentinc/cp-flink:${CONFLUENT_FLINK_VERSION}

# Create directory for user libraries
RUN mkdir -p /opt/flink/usrlib

# Copy SQL Runner jar from builder stage
COPY --from=builder /build/flink-kubernetes-operator/examples/flink-sql-runner-example/target/flink-sql-runner-example-*.jar \
    /opt/flink/usrlib/sql-runner.jar

# Copy connectors and dependencies to Flink lib directory
COPY --from=dependency-fetcher /connectors/lib/*.jar /opt/flink/lib/
COPY --from=dependency-fetcher /dependencies/lib/*.jar /opt/flink/lib/

# =============================================================================
# Customer-specific additions required below this line
# =============================================================================

# REQUIRED: Copy customer's flow.sql file
# This is the SQL file exported from IBM Event Processing
ARG FLOW_SQL_PATH
RUN mkdir -p /opt/flink/usrlib/sql-scripts
COPY ${FLOW_SQL_PATH} /opt/flink/usrlib/sql-scripts/flow.sql

# =============================================================================
# Build instructions
# =============================================================================
# REQUIRED: FLOW_SQL_PATH must be the path to a single .sql file, relative to
# the Docker build context directory. It must NOT be a directory.
#
# Run docker build from the directory containing this Dockerfile, with the
# .sql file also inside that directory (or a subdirectory of it):
#
#   cp /path/to/your/exported/flow.sql .
#   docker build \
#     --build-arg FLOW_SQL_PATH=flow.sql \
#     -t your-registry/flink-migrated-app:latest .
#
# To build with custom versions:
#   docker build \
#     --build-arg FLOW_SQL_PATH=flow.sql \
#     --build-arg CONFLUENT_FLINK_VERSION=2.1.2-cp1-java11-amd64 \
#     --build-arg CONFLUENT_FLINK_MAVEN_VERSION=2.1.2-cp1 \
#     --build-arg KAFKA_CONNECTOR_VERSION=4.0.1-2.0-cp2 \
#     --build-arg JDBC_DRIVER_VERSION=2.1.2-cp1 \
#     --build-arg FILE_SINK_VERSION=2.1.2-cp1 \
#     -t your-registry/flink-migrated-app:latest .
#
# After building, push to your registry:
#   docker push your-registry/flink-migrated-app:latest
