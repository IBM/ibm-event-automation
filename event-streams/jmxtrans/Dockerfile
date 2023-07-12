######################################################################
# Use JMX Trans image to extract jmxtrans jar
######################################################################
FROM jmxtrans/jmxtrans

######################################################################
# The JMX Trans image does not work under Java 17.
######################################################################
FROM openjdk:11-jdk
######################################################################
# Setup environment
######################################################################
ENV JMXTRANS_HOME /usr/share/jmxtrans
ENV PATH $JMXTRANS_HOME/bin:$PATH
ENV JAR_FILE $JMXTRANS_HOME/lib/jmxtrans-all.jar
ENV JMXTRANS_VERSION 272

ENV HEAP_SIZE 512
ENV PERM_SIZE 384
ENV MAX_PERM_SIZE 384
ENV SECONDS_BETWEEN_RUNS 60
ENV CONTINUE_ON_ERROR false
ENV JSON_DIR /var/lib/jmxtrans

WORKDIR ${JMXTRANS_HOME}
RUN mkdir -p ${JMXTRANS_HOME}/conf

######################################################################
# Add JmxTrans Jar and scripts
######################################################################
COPY --from=0 --chown=1001:0 ${JMXTRANS_HOME} ${JMXTRANS_HOME}
COPY --chown=1001:0 --chmod=755 docker-entrypoint.sh /docker-entrypoint.sh
COPY --chown=1001:0 --chmod=755 jmxtrans_readiness_check.sh /opt/jmx/

USER 1001

VOLUME ${JSON_DIR}

ENTRYPOINT [ "/docker-entrypoint.sh",  "start-without-jmx" ]