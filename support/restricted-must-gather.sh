#!/bin/bash
#
# Licensed Materials - Property of IBM
# Copyright IBM Corporation 2023. All Rights Reserved
# US Government Users Restricted Rights -
# Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#

usage() {
printf "A tool for collecting a reduced amount of diagnostic data.

Usage:
  restricted-must-gather.sh [flags]
Options:
  -m|--modules'': Define the data module that specifies what type of information is collected. For more information, see Available data modules.
  -n|--namespace'': Specify the namespace from which the data is collected.  If specifying more than one of eventstreams, eem, eventprocessing and flink modules, individual namespace flags must be used
  --es-namespace'': the namespace from which the eventstreams data is collected.
  --eem-namespace'': the namespace from which the eem data is collected.
  --ep-namespace'': the namespace from which the eventprocessing data is collected.
  --flink-namespace'': the namespace from which the flink data is collected.
  -h|--help: Display the help message.

Available data modules:
  eventstreams            Resources relating to instances of eventstreams
                          Resources relating to the eventstreams operator
                          Resources relating to instances of kafka connect
  eventprocessing         Resources relating to instances of event processing
                          Resources relating to the event processing operator
  eem                     Resources relating to instances of event endpoint management
                          Resources relating to the event endpoint management operator
  flink                   Resources relating to instances of flink
                          Resources relating to the flink operator

Specifying namespaces:
  If only one module is specified in the list of modules, you simply specify the relevant namespace
  using the -n|--namespace flag.

  If multiple products are being specified, then you MUST utilise the individual namespace flags for each module:

    --es-namespace'': the namespace from which the eventstreams data is collected.
    --eem-namespace'': the namespace from which the eem data is collected.
    --ep-namespace'': the namespace from which the eventprocessing data is collected.
    --flink-namespace'': the namespace from which the flink data is collected.
"
}

check_openssl() {
  printf  "Checking for presence of openssl\n" | tee -a "${BASE_LOG}"
  command -v openssl > /dev/null
  OPENSSL_PRESENCE=$(echo ${?})
  if [ "${OPENSSL_PRESENCE}" -ne 0 ]; then
      printf  '  ** WARN ** - openssl is desirable for diagnostics but absent on this system - continuing...\n' | tee -a "${BASE_LOG}"
  else
      printf  '  ** OK ** - openssl present on system...\n' | tee -a "${BASE_LOG}"
  fi
}

# only print valid printable characters
cleanOutput() {
    tr -cd '\11\12\15\40-\176'
}

check_pvc () {
    NAMESPACE="$1"
    PVC="$2"
    PHASE=$(kubectl get pvc -n ${NAMESPACE} ${PVC} --no-headers -o=jsonpath="{.status.phase}" | cleanOutput)
    VOLUME=$(kubectl get pvc -n ${NAMESPACE} ${PVC} --no-headers -o=jsonpath="{.spec.volumeName}" | cleanOutput)
    VOLUME_EXISTS=$(kubectl get pv ${VOLUME} --no-headers &> /dev/null; echo ${?})
    if [ "${PHASE}" != "Bound" ]; then
        printf "    ** ERROR ** - Persistence problem for pvc: %s phase is not Bound, is: %s\n" "${PVC}" "${PHASE}"| tee -a "${BASE_LOG}"
    elif [ "${VOLUME_EXISTS}" -ne 0 ]; then
        printf "    ** ERROR ** - Persistence problem for pvc: %s bound to volume %s which does not exist\n" "${PVC}" "${VOLUME}"| tee -a "${BASE_LOG}"
    else
        printf "    ** OK ** - Persistence is okay for pvc: %s\n" "${PVC}" | tee -a "${BASE_LOG}"
    fi
}

get_resource_list() {
  RESOURCE="$1"
  NAMESPACE="$2"
  LOG_LOCATION="$3/${RESOURCE}"
  mkdir -p "${LOG_LOCATION}"
  kubectl get "${RESOURCE}" -n "${NAMESPACE}" -o wide -L zone >> "${LOG_LOCATION}/list-${RESOURCE}.log"
  echo $(kubectl get "${RESOURCE}" -n "${NAMESPACE}" -o jsonpath="{.items[*].metadata.name}")
}

get_resource_list_detailed() {
  RESOURCE="$1"
  NAMESPACE="$2"
  LOG_LOCATION="$3/${RESOURCE}"
  mkdir -p "${LOG_LOCATION}"
  kubectl get "${RESOURCE}" -n "${NAMESPACE}" -o json >> "${LOG_LOCATION}/list-${RESOURCE}-json.log"
}

check_persistence() {
  NAMESPACE="$1"
  LABEL1="$2"
  LABEL2="$3"

  printf "Checking for persistence for %s...\n" "${LABEL2}" | tee -a "${BASE_LOG}"
  PODS=$(kubectl get pods -n ${NAMESPACE} -l "${LABEL1},${LABEL2}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
  TEMP_ARR=(${PODS[@]})
  NUM_PODS=${#TEMP_ARR[@]}
  PVCS=$(kubectl get pvc -n ${NAMESPACE} -l "${LABEL1},${LABEL2}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
  TEMP_ARR=(${PVCS[@]})
  NUM_PVCS=${#TEMP_ARR[@]}
  if [ "${NUM_PVCS}" -eq 0 ]; then
      printf "  Persistence not enabled for %s\n" "${LABEL2}" | tee -a "${BASE_LOG}"
  elif [ "${NUM_PODS}" -eq "${NUM_PVCS}" ]; then
      for PVC in ${PVCS[@]}; do
          printf "  Checking pvc %s for %s...\n" "${PVC}" "${LABEL2}" | tee -a "${BASE_LOG}"
          check_pvc "${NAMESPACE}" "${PVC}"
      done
  elif [ "${NUM_PVCS}" -eq 1 ]; then
      ACCESS_MODE=$(kubectl get pvc -n ${NAMESPACE} ${PVCS[0]} --no-headers -o=jsonpath="{.spec.accessModes}" | cleanOutput)
      if [ "${ACCESS_MODE}" == "[ReadWriteMany]" ]; then
          printf "  Checking pvc %s for %s\n" "${PVCS[0]}" "${LABEL2}" | tee -a "${BASE_LOG}"
          check_pvc "${NAMESPACE}" "${PVCS[0]}"
      else
          printf "    ** ERROR ** - Persistence problem for %s, there are %s pods with 1 %s pvc\n" "${LABEL2}" "${NUM_PODS}" "${ACCESS_MODE}" | tee -a "${BASE_LOG}"
      fi
  else
      printf "    ** ERROR ** - Persistence problem for %s, there are %s pods and %s pvcs\n" "${LABEL2}" "${NUM_PODS}" "${NUM_PVCS}" | tee -a "${BASE_LOG}"
  fi
}

check_zookeeper_pods() {
  NAMESPACE="$1"
  INSTANCE="$2"
  INSTANCE_LABEL="$3"

  ZK_PODS=$(kubectl get pods -n ${NAMESPACE} -l "${INSTANCE_LABEL},app.kubernetes.io/name=zookeeper" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
  for POD in ${ZK_PODS[@]}; do
    printf "Checking zookeeper pod %s status\n" "${POD}" | tee -a "${BASE_LOG}"
    OKAY=$(kubectl exec "${POD}" -n "${NAMESPACE}" -c "zookeeper" -i -- sh -c "echo ruok | nc localhost 12181" | cleanOutput)
    MODE=$(kubectl exec "${POD}" -n "${NAMESPACE}" -c "zookeeper" -i -- sh -c "echo srvr | nc localhost 12181 | grep Mode" | cleanOutput)
    if [ "${OKAY}" == "imok" ]; then
        printf "  zookeeper pod %s is in %s\n" "${POD}" "${MODE}" | tee -a "${BASE_LOG}"
    else
        printf "  zookeeper pod %s is not okay, state %s\n" "${POD}" "${OKAY}" | tee -a "${BASE_LOG}"
    fi

    printf "  checking zookeeper to zookeeper connections\n" | tee -a "${BASE_LOG}"
    for TEST_POD in ${ZK_PODS[@]}; do
        printf "    connection test from %s to %s\n" "${POD}" "${POD}" | tee -a "${BASE_LOG}"
        CMD="
        echo -n \"Run \"
        OUT=\$(curl -Ss -k --cert /opt/kafka/zookeeper-node-certs/${POD}.crt --key /opt/kafka/zookeeper-node-certs/${POD}.key https://${TEST_POD}.${INSTANCE}-zookeeper-nodes.${NAMESPACE}.svc:3888 2>&1)
        if [ \"\${OUT}\" == \"curl: (52) Empty reply from server\" ]; then
            echo -n \"Succeeded\"
        elif [ \"\${OUT}\" == \"curl: (35) SSL peer had some unspecified issue with the certificate it received.\" ]; then
            echo -n \"Intermittent\"
        else
            echo -n \"Failed: \${OUT}\"
        fi
        "
        RESPONSE=$(kubectl exec "${POD}" -n "${NAMESPACE}" -c "zookeeper" -i -- sh -c "${CMD}" | cleanOutput)
        if [ "${RESPONSE}" == "Run Succeeded" ]; then
            printf "    Done\n" | tee -a "${BASE_LOG}"
        elif [ "${RESPONSE}" == "Run Intermittent" ]; then
            # This is an intermittent error that was seen during testing. logs of the failure can be seen in the addressed ZK's logs. They
            # indicate the failure was due to a random DNS resoltion blip
            printf "    Done\n" | tee -a "${BASE_LOG}"
            printf "    saw intermittent error: 'curl: (35) SSL peer had some unspecified issue with the certificate it received.'\n" | tee -a "${BASE_LOG}"
            printf "    this will produce a stack trace in the addressed zookeepers logs indicating an ssl failure due to hostname'\n" | tee -a "${BASE_LOG}"
            printf "    verification'" | tee -a "${BASE_LOG}"
        elif [ "${RESPONSE}" == "Run " ]; then
            # This is an intermittent error that was seen during testing. It occurs when the curl command fails to run for some unknown
            # reason and causes the command to exit prematurely. It does not indicate a connection failure
            printf "    Done\n" | tee -a "${BASE_LOG}"
            printf "    saw an intermittent error indicating curl failed to run abd the connection was not tested'\n" | tee -a "${BASE_LOG}"
        else
            printf "    ** ERROR **\n" | tee -a "${BASE_LOG}"
            printf "    connection test from %s to %s failed with response: ${RESPONSE}\n" "${POD}" "${TEST_POD}" | tee -a "${BASE_LOG}"
        fi
    done
  done
}

check_kafka_pods() {
  NAMESPACE="$1"
  INSTANCE="$2"
  INSTANCE_LABEL="$3"

  KAFKA_PODS=$(kubectl get pods -n ${NAMESPACE} -l "${INSTANCE_LABEL},app.kubernetes.io/name=kafka" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
  for KAFKA_POD in ${KAFKA_PODS[@]}; do
      ZOOKEEPER_CLIENT_NAME="${INSTANCE}-zookeeper-client"
      printf "Checking %s to zookeeper connections using %s\n" "${KAFKA_POD}" "${ZOOKEEPER_CLIENT_NAME}" | tee -a "${BASE_LOG}"
      # This is not the ideal but it's the only thing that worked as the zookeeper client does not support non TLS connections
      # The zookeeper-shell.sh script is used to test the connection to the zookeeper cluster. It is a script that comes with the kafka
      # distribution and is used to test the connection to the zookeeper cluster. It is used here to test the connection to the zookeeper
      # cluster from the kafka pods. The script is run in a loop to ensure that the connection is stable.
      for i in 1 2 3; do
          printf "  checking random connection run ${i}\n" | tee -a "${BASE_LOG}"
          RESPONSE=$(kubectl exec "${KAFKA_POD}" -n "${NAMESPACE}" -c "kafka" -i -t -q -- sh -c "./bin/zookeeper-shell.sh ${ZOOKEEPER_CLIENT_NAME}.${NAMESPACE}.svc:2181 -zk-tls-config-file /tmp/strimzi.properties ls /zookeeper &>/tmp/${ZOOKEEPER_CLIENT_NAME}.out")
          OKAY=$(kubectl exec "${KAFKA_POD}" -n "${NAMESPACE}" -c "kafka" -i -t -q -- sh -c "cat /tmp/${ZOOKEEPER_CLIENT_NAME}.out" | cleanOutput)
          if [[ "${OKAY}" == *"session timed out"* ]]; then
              printf "    [ERR]\n" | tee -a "${BASE_LOG}"
              printf "  connection to %s failed, response: %s\n" "${ZOOKEEPER_CLIENT_NAME}" "${OKAY}" | tee -a "${BASE_LOG}"
          else
              printf "    Done\n" | tee -a "${BASE_LOG}"
          fi
      done
  done

}

get_pod_logs () {
    POD_DIR="${1}"
    NAMESPACE="${2}"
    POD="${3}"
    PARAMS="${4}"

    printf "  Gathering diagnostics for pod: %s\n" "${POD}" | tee -a "${BASE_LOG}"
    mkdir -p "${POD_DIR}"
    kubectl describe pod "${POD}" -n "${NAMESPACE}" > "${POD_DIR}/pod-describe.log"
    CONTAINERS=$(kubectl get pod ${POD} -n ${NAMESPACE} -o jsonpath="{.spec.containers[*].name}" | cleanOutput)
    INIT_CONTAINERS=$(kubectl get pod ${POD} -n ${NAMESPACE} -o jsonpath="{.spec.initContainers[*].name}" | cleanOutput)
    JOB_NAME=$(kubectl get pod ${POD} -n ${NAMESPACE} -o jsonpath="{.metadata.ownerReferences[?(@.kind == 'Job')].name}" | cleanOutput)
    if [ "${JOB_NAME}" ]; then
        printf "    Gathering Job logs\n" | tee -a "${BASE_LOG}"
        kubectl logs "${POD}" -n "${NAMESPACE}" --since="${SINCE}h" ${PARAMS} > "${POD_DIR}/${JOB_NAME}.log"
        printf "    Done\n" | tee -a "${BASE_LOG}"
    else
        for CONTAINER in ${CONTAINERS[@]}; do
            printf "    Gathering diagnostics for container: %s\n" "${CONTAINER}" | tee -a "${BASE_LOG}"
            get_container_diagnostics "${NAMESPACE}" "${POD}" "${CONTAINER}" "${POD_DIR}"
            get_container_logs "${NAMESPACE}" "${POD}" "${CONTAINER}" "${POD_DIR}" "${PARAMS}"
        done
        for CONTAINER in ${INIT_CONTAINERS[@]}; do
            printf "    Gathering diagnostics for init container: %s\n" "${CONTAINER}"| tee -a "${BASE_LOG}"
            get_init_container_logs "${NAMESPACE}" "${POD}" "${CONTAINER}" "${POD_DIR}" "${PARAMS}"
        done
    fi
}

get_init_container_logs () {
    NAMESPACE="${1}"
    POD="${2}"
    CONTAINER="${3}"
    DIR="${4}"
    PARAMS="${5}"
    printf "      Gathering init container logs\n" | tee -a "${BASE_LOG}"
    kubectl logs "${POD}" -n "${NAMESPACE}" -c "${CONTAINER}" --since="${SINCE}h" ${PARAMS} > "${DIR}/init_container_log-${CONTAINER}.log"
    printf "    Done\n" | tee -a "${BASE_LOG}"
    RESTART_COUNT=$(kubectl get pod ${POD} -n ${NAMESPACE} -o jsonpath="{.status.initContainerStatuses[?(@.name == \"${CONTAINER}\")].restartCount}" | cleanOutput)
    if [ "${RESTART_COUNT}" -ne 0 ]; then
        printf "      Gathering previous init container logs\n" | tee -a "${BASE_LOG}"
        kubectl logs "${POD}" -n "${NAMESPACE}" -c "${CONTAINER}" --previous --limit-bytes=10000000 ${PARAMS} > "${DIR}/previous_init_container_log-${CONTAINER}.log"
        printf "    Done\n" | tee -a "${BASE_LOG}"
    fi
}

get_container_diagnostics () {
    NAMESPACE="${1}"
    POD="${2}"
    CONTAINER="${3}"
    DIR="${4}"
    PHASE=$(kubectl get pod ${POD} -n ${NAMESPACE} -o jsonpath="{.status.phase}" | cleanOutput )
    if [ "${PHASE}" == "Running" ]; then
        printf "      Retrieving image name\n" | tee -a "${BASE_LOG}"
        IMAGE=$(kubectl exec ${POD} -n ${NAMESPACE} -c ${CONTAINER} -i -- sh -c "if [ -s \"/image.txt\" ]; then cat \"/image.txt\"; else echo -n notPresent; fi" | cleanOutput)
        echo "Pod: ${POD}, Container: ${CONTAINER}, Image: ${IMAGE}" >> "${DIR}/images.log"
        printf "    Done\n" | tee -a "${BASE_LOG}"
        if [ ! -s "${DIR}/etc_hosts.log" ]; then
            printf "      Retrieving hosts file\n" | tee -a "${BASE_LOG}"
            kubectl exec "${POD}" -n "${NAMESPACE}" -c "${CONTAINER}" -i -- sh -c "cat /etc/hosts" > "${DIR}/etc_hosts.log"
            printf "    Done\n" | tee -a "${BASE_LOG}"
        fi
        if [ ! -s ${DIR}/resolv_conf.log ]; then
            printf "      Retrieving resolv.conf file\n" | tee -a "${BASE_LOG}"
            kubectl exec "${POD}" -n "${NAMESPACE}" -c "${CONTAINER}" -i -- sh -c "cat /etc/resolv.conf" > "${DIR}/resolv_conf.log"
            printf "    Done\n" | tee -a "${BASE_LOG}"
        fi
    fi
}

get_container_logs () {
    NAMESPACE="${1}"
    POD="${2}"
    CONTAINER="${3}"
    DIR="${4}"
    PARAMS="${5}"
    printf "      Gathering container logs\n" | tee -a "${BASE_LOG}"
    kubectl logs "${POD}" -n "${NAMESPACE}" -c "${CONTAINER}" --since="${SINCE}h" ${PARAMS} > "${DIR}/container_log-${CONTAINER}.log"
    printf "    Done\n" | tee -a "${BASE_LOG}"
    RESTART_COUNT=$(kubectl get pod ${POD} -n ${NAMESPACE} -o jsonpath="{.status.containerStatuses[?(@.name == \"${CONTAINER}\")].restartCount}" | cleanOutput)
    if [ "${RESTART_COUNT}" -ne 0 ]; then
        printf "      Gathering previous container logs" | tee -a "${BASE_LOG}"
        kubectl logs "${POD}" -n "${NAMESPACE}" -c "${CONTAINER}" --previous --limit-bytes=10000000 ${PARAMS} > "${DIR}/previous_container_log-${CONTAINER}.log"
        printf "    Done\n" | tee -a "${BASE_LOG}"
    fi
}

gather_crds_and_crs() {
  NAMESPACE="${1}"
  LOGDIR="${2}"
  CRDS=(${3})

  CRD_DIR="${LOGDIR}/crds"
  CR_DIR="${LOGDIR}/crs"
  mkdir -p "${CRD_DIR}"
  mkdir -p "${CR_DIR}"

  printf "Gathering crds and crs\n" | tee -a "${BASE_LOG}"
  for CRD in "${CRDS[@]}"; do
      printf "Gathering crd %s\n" "${CRD}" | tee -a "${BASE_LOG}"
      kubectl get crd "${CRD}" -o yaml > "${CRD_DIR}/${CRD}.yaml"
      printf "    Done\n" | tee -a "${BASE_LOG}"
      CRS=$(kubectl get "${CRD}" -n "${NAMESPACE}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
      for CR in ${CRS[@]}; do
          printf "Gathering %s instance - %s\n" "${CRD}" "${CR}" | tee -a "${BASE_LOG}"
          kubectl get "${CRD}" "${CR}" -n "${NAMESPACE}" -o yaml > "${CR_DIR}/${CRD}-${CR}.yaml"
          printf "    Done\n" | tee -a "${BASE_LOG}"
      done
  done
}

get_resources() {
  NAMESPACE="${1}"
  LOGDIR="${2}"
  RESOURCES=(${3})
  INSTANCE_LABEL="${4}"
  INGRESS_LABEL="${5}"
  OIDC_LABEL="${6}"

  for RESOURCE in "${RESOURCES[@]}"; do
      RESOURCE_DIR="${LOGDIR}/${RESOURCE}"
      mkdir -p "${RESOURCE_DIR}"

      printf "Checking for %s\n" "${RESOURCE}" | tee -a "${BASE_LOG}"
      kubectl get "${RESOURCE}" -n "${NAMESPACE}" -l "${INSTANCE_LABEL}" -o wide >> "${RESOURCE_DIR}/${RESOURCE}-get.log"
      ITEM_NAMES=$(kubectl get "${RESOURCE}" -n "${NAMESPACE}" -l "${INSTANCE_LABEL}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
      for ITEM_NAME in ${ITEM_NAMES[@]}; do
          printf "Gathering diagnostics for %s: %s\n" "${RESOURCE}" "${ITEM_NAME}" | tee -a "${BASE_LOG}"
          kubectl describe "${RESOURCE}" "${ITEM_NAME}" -n "${NAMESPACE}" > "${RESOURCE_DIR}/${ITEM_NAME}-describe.log"
          if [ "${RESOURCE}" != "secrets" ]; then
              kubectl get "${RESOURCE}" "${ITEM_NAME}" -n "${NAMESPACE}" -o yaml > "${RESOURCE_DIR}/${ITEM_NAME}-yaml.yaml"
          fi
          printf "    Done\n" | tee -a "${BASE_LOG}"
      done
      if [ "${RESOURCE}" == "secrets" ] && [ "${OIDC_LABEL}" != "" ]; then
          OIDC_SECRETS=$(kubectl get ${RESOURCE} -n ${NAMESPACE} -l ${OIDC_LABEL} --no-headers -o custom-columns=":metadata.name" | cleanOutput)
          for OIDC_SECRET in ${OIDC_SECRETS[@]}; do
              printf "Gathering diagnostics for %s: %s\n" "${RESOURCE}" "${OIDC_SECRET}" | tee -a "${BASE_LOG}"
              kubectl describe "${RESOURCE}" "${OIDC_SECRET}" -n "${NAMESPACE}" > "${RESOURCE_DIR}/${OIDC_SECRET}-describe.log"
              printf "    Done\n" | tee -a "${BASE_LOG}"
          done
      fi

      if [ "${INGRESS_LABEL}" != "" ]; then
        INGRESS_RESOURCES=$(kubectl get "${RESOURCE}" -n "${NAMESPACE}" -l "${INGRESS_LABEL}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
        for INGRESS_RESOURCE in ${INGRESS_RESOURCES[@]}; do
            printf "Gathering diagnostics for %s: %s\n" "${RESOURCE}" "${INGRESS_RESOURCE}"| tee -a "${BASE_LOG}"
            kubectl describe "${RESOURCE}" "${INGRESS_RESOURCE}" -n "${NAMESPACE}" > "${RESOURCE_DIR}/${INGRESS_RESOURCE}-describe.log"
            printf "    Done\n" | tee -a "${BASE_LOG}"
        done
      fi
  done
}

get_operator_install_resources() {
  NAMESPACE="${1}"
  LOGDIR="${2}"

  printf "Gathering install info\n" | tee -a "${BASE_LOG}"
  HAS_ROUTES=$(kubectl api-resources | cleanOutput | grep route.openshift.io &> /dev/null; echo ${?})
  if [ "${HAS_ROUTES}" -eq 0 ]; then
    for RESOURCE in ${OLM_OPERATOR_INSTALL_RESOURCES[@]}; do
      printf "  Gathering %s in %s\n" "${RESOURCE}" "${NAMESPACE}" | tee -a "${BASE_LOG}"
      RESOURCE_NAMES=$(kubectl get "${RESOURCE}" -n "${NAMESPACE}" -o custom-columns=":metadata.name" | cleanOutput)
      if [ "" == "${RESOURCE_NAMES}" ]; then
        printf "    None Found\n" | tee -a "${BASE_LOG}"
      else
        mkdir -p ${LOGDIR}/${RESOURCE}
        for RESOURCE_NAME in ${RESOURCE_NAMES[@]}; do
            printf "    Getting %s %s into %s\n" "${RESOURCE}" "${RESOURCE_NAME}" "${LOGDIR}/${RESOURCE}/${RESOURCE_NAME}.log" | tee -a "${BASE_LOG}"
            kubectl get "${RESOURCE}" ${RESOURCE_NAME} -n "${NAMESPACE}" -o yaml > "${LOGDIR}/${RESOURCE}/${RESOURCE_NAME}.log"
            printf "    Done\n" | tee -a "${BASE_LOG}"
        done
      fi
    done
  else
    printf "  Gathering helm install info\n" | tee -a "${BASE_LOG}"
    mkdir -p "${LOGDIR}/helm"
    helm list -n "${NAMESPACE}" > "${LOGDIR}/helm/helm-list.log"
    for REL_NAME in $(helm list -n "${NAMESPACE}" -q); do
      printf "  Gathering helm info for %s in namespace %s\n" "${REL_NAME}" "${NAMESPACE}" | tee -a "${BASE_LOG}"
      helm get all "${REL_NAME}" -n "${NAMESPACE}" >  "${LOGDIR}/helm/${REL_NAME}-get-all.log"
    done
  fi
}

analyse_cert () {
  DIR="${1}"
  NAME="${2}"
  if [ -s "${DIR}/${NAME}" ]; then
      # Attempt decode
      printf "  Decode certificate: %s\n" "${NAME}" | tee -a "${BASE_LOG}"
      BASE64_CHECK=$(base64 --help 2>/dev/null | grep "\-i in_file")
      if [ -n "${BASE64_CHECK}" ]; then
          BASE64_DECODE="base64 --decode -i "
      else
          BASE64_DECODE="base64 --decode "
      fi

      ${BASE64_DECODE} "${DIR}/${NAME}" > "${DIR}/decoded-${NAME}"
      printf "    Done\n" | tee -a "${BASE_LOG}"
      if [ "${OPENSSL_PRESENCE}" -eq 0 ]; then
          # Attempt openssl
          printf "  Inspect certificate: %s\n" "${NAME}" | tee -a "${BASE_LOG}"
          openssl x509 -text -in "${DIR}/decoded-${NAME}" > "${DIR}/openssl-${NAME}"
          printf "    Done\n" | tee -a "${BASE_LOG}"
      else
          printf 'openssl not available on this system - skipping certificate inspection...     [SKIP]'
      fi
  else
      printf "No Certicate at %s, removing\n" "${DIR}/${NAME}"
      rm -f "${DIR}/${NAME}"
  fi
}

extract_certificate_data () {
  NAMESPACE="${1}"
  SECRET_NAME="${2}"
  CERT_DIR="${3}"
  SPECIFIC_KEY="${4}"

  mkdir -p "${CERT_DIR}"
  INITIAL_DATA_MAP=$(kubectl get secret -n ${NAMESPACE} ${SECRET_NAME} -o=jsonpath="{.data}" 2> /dev/null)
  DATA_MAP=$(echo ${INITIAL_DATA_MAP} | cut -d '[' -f2 | tr -d '[]{}"' | cleanOutput)
  if [ $? -eq 0 ]; then
      IFS=',' read -ra DATA_MAP <<< "$DATA_MAP"
      for DATUM in ${DATA_MAP[@]}; do
          NAME=$(cut -d ':' -f1 <<< ${DATUM})
          VALUE=$(cut -d ':' -f2 <<< ${DATUM})
          if [ -n "${SPECIFIC_KEY}" ]; then
              if [ "${NAME}" == "${SPECIFIC_KEY}" ]; then
                  printf "  Got encoded certificate from specified key: %s\n" "${NAME}" | tee -a "${BASE_LOG}"
                  echo "${VALUE}" > "${CERT_DIR}/${NAME}"
                  printf "    Done\n" | tee -a "${BASE_LOG}"
                  analyse_cert "${CERT_DIR}" "${NAME}"
              fi
          else
              case ${NAME} in
                  *.crt|*.cert|*.cacert)
                      printf "  Got encoded certificate: %s\n" "${NAME}" | tee -a "${BASE_LOG}"
                      echo "${VALUE}" > "${CERT_DIR}/${NAME}"
                      printf "    Done\n" | tee -a "${BASE_LOG}"
                      analyse_cert "${CERT_DIR}" "${NAME}"
                      ;;
                  *)
                      ;;
              esac
          fi
      done
  fi
}

get_es_certificates() {
  NAMESPACE="${1}"
  LOGDIR="${2}"
  SECRETS=(${3})
  INSTANCE="${4}"

  printf "  Getting certificate from secrets\n" | tee -a "${BASE_LOG}"
  for SECRET in "${SECRETS[@]}"; do
     SECRET_NAME="${INSTANCE}-${SECRET}"
     CERT_DIR="${LOGDIR}/${SECRET_NAME}-certificates"
     extract_certificate_data "${NAMESPACE}" "${SECRET_NAME}" "${CERT_DIR}"
  done
}

get_external_endpoint_cert () {
  ADDRESS="${1}"
  OUTPUT_FILE="${2}"
  if [ "${OPENSSL_PRESENCE}" -eq 0 ]; then
      printf "  Get presented certificate at endpoint: %s" "${ADDRESS}" | tee -a "${BASE_LOG}"
      CONNECT_RC=$(echo -n | openssl s_client -connect ${ADDRESS} -servername ${ADDRESS} &> /dev/null; echo ${?})
      if [ "${CONNECT_RC}" -eq 0 ]; then
          echo -n | openssl s_client -connect "${ADDRESS}" -servername "${ADDRESS}" &> "${OUTPUT_FILE}"
          printf "    Done\n" | tee -a "${BASE_LOG}"
      else
          printf '     ** ERROR **'
      fi
  else
      printf 'openssl not available on this system - skipping endpoint certificate discovery...     [SKIP]'
  fi
}

get_route_certs() {
  NAMESPACE="${1}"
  INSTANCE_LABEL="${2}"
  LOGDIR="${3}"

  EXTERNAL_PRESENTED_CERTS_DIR="${LOGDIR}/presented-certificates-external"
  mkdir -p "${EXTERNAL_PRESENTED_CERTS_DIR}"

  printf "Gathering certs from routes\n" | tee -a "${BASE_LOG}"
  HAS_ROUTES=$(kubectl api-resources | cleanOutput | grep route.openshift.io &> /dev/null; echo ${?})
  if [ "${HAS_ROUTES}" -eq 0 ]; then
      ROUTES=$(kubectl get routes -n ${NAMESPACE} -l ${INSTANCE_LABEL} --no-headers -o custom-columns=":metadata.name" | cleanOutput)
      for ROUTE in ${ROUTES[@]}; do
      printf "Gathering connection details for route %s\n" "${ROUTE}" | tee -a "${BASE_LOG}"
      TLS_ENABLED=$(kubectl get route -n ${NAMESPACE} ${ROUTE} -o jsonpath="{.spec.tls}" | cleanOutput)
      ADDRESS=$(kubectl get route -n ${NAMESPACE} ${ROUTE} -o jsonpath="{.spec.host}" | cleanOutput)
      if [ "${TLS_ENABLED}" != "<none>" ]; then
          get_external_endpoint_cert "${ADDRESS}:443" "${EXTERNAL_PRESENTED_CERTS_DIR}/${ROUTE}.log"
      fi
      done
  fi
}

get_certificates() {
  NAMESPACE="${1}"
  LOGDIR="${2}"
  CRDS=("${3}")
  SUFFIXES=("${4}")

  mkdir -p "${LOGDIR}/secrets"

  for CRD in ${CRDS[@]}; do
    CRS=$(kubectl get ${CRD} -n ${NAMESPACE} -o custom-columns=":metadata.name" | cleanOutput)
    for CR in ${CRS[@]}; do
        INSTANCE_LABEL="app.kubernetes.io/instance=${CR}"
        printf "Gathering certificates from secrets in %s %s\n" "${CRD}" "${CR}" | tee -a "${BASE_LOG}"
        CA_SECRET=$(kubectl get ${CRD} ${CR} -n ${NAMESPACE} --no-headers -o=jsonpath="{..tls.caSecretName}" | cleanOutput)
        if [ -n "${CA_SECRET}" ]; then
            kubectl describe secret "${CA_SECRET}" -n "${NAMESPACE}" > "${LOGDIR}/secrets/${CA_SECRET}-describe.log"
            extract_certificate_data "${NAMESPACE}" "${CA_SECRET}" "${LOGDIR}/secrets/${CA_SECRET}-extracted-certs"
        fi

        TLS_SECRET=$(kubectl get ${CRD} ${CR} -n ${NAMESPACE} --no-headers -o=jsonpath="{..tls.secretName}" | cleanOutput)
        if [ -n "${TLS_SECRET}" ]; then
            kubectl describe secret "${TLS_SECRET}" -n "${NAMESPACE}" > "${LOGDIR}/secrets/${TLS_SECRET}-describe.log"
            extract_certificate_data "${NAMESPACE}" "${TLS_SECRET}" "${LOGDIR}/secrets/${TLS_SECRET}-extracted-certs"

            # find any specified secret key values for the certs on CR and fetch those in case the are not .cert / .crt / .cacert
            TLS_SERVER_CERT_SECRET_KEY=$(kubectl get ${CRD} ${CR} -n ${NAMESPACE} --no-headers -o=jsonpath="{..tls.serverCertificate}" | cleanOutput)
            if [ -n "${TLS_SERVER_CERT_SECRET_KEY}" ]; then
                extract_certificate_data "${NAMESPACE}" "${TLS_SECRET}" "${LOGDIR}/secrets/${TLS_SECRET}-extracted-certs" "${TLS_SERVER_CERT_SECRET_KEY}"
            fi

            CA_CERT_SECRET_KEY=$(kubectl get ${CRD} ${CR} -n ${NAMESPACE} --no-headers -o=jsonpath="{..tls.caCertificate}" | cleanOutput)
            if [ -n "${CA_CERT_SECRET_KEY}" ]; then
                extract_certificate_data "${NAMESPACE}" "${TLS_SECRET}" "${LOGDIR}/secrets/${TLS_SECRET}-extracted-certs" "${CA_CERT_SECRET_KEY}"
            fi
        fi

        TRUSTED_CERTS_SECRETS=$(kubectl get ${CRD} ${CR} -n ${NAMESPACE} --no-headers -o=jsonpath="{..tls.trustedCertificates[*]}" | cleanOutput)
        if [ -n "${TRUSTED_CERTS_SECRETS}" ]; then
            for ENTRY in ${TRUSTED_CERTS_SECRETS[@]}; do
                SECRET=$(echo "${ENTRY}" | jq .secretName | tr -d '"')
                CA_KEY=$(echo "${ENTRY}" | jq .certificate | tr -d '"')
                kubectl describe secret "${SECRET}" -n "${NAMESPACE}" > "${LOGDIR}/secrets/${SECRET}-describe.log"
                extract_certificate_data "${NAMESPACE}" "${SECRET}" "${LOGDIR}/secrets/${SECRET}-extracted-certs" "${CA_KEY}"
            done
        fi

        printf "Gathering certificates from default secrets if present\n" | tee -a "${BASE_LOG}"
        for SUFFIX in ${SUFFIXES[@]}; do
            SECRET_NAME="${CR}-${SUFFIX}"
            EXISTS=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}")
            if [ -n "${EXISTS}"  ]; then
            kubectl describe secret "${SECRET_NAME}" -n "${NAMESPACE}" > "${LOGDIR}/secrets/${SECRET_NAME}-describe.log"
            extract_certificate_data "${NAMESPACE}" "${SECRET_NAME}" "${LOGDIR}/secrets/${SECRET_NAME}-extracted-certs"
            fi
        done
    done
  done
}

gather_operator_common() {
  NAMESPACE="$1"
  LOG_LOCATION="$2"
  CRD_LIST=("$3")
  OPERATOR_RESOURCE_LABEL="$4"

  printf "Gathering namespace overview information...\n" | tee -a "${BASE_LOG}"
  all_pods=$( get_resource_list pods "${NAMESPACE}" "${LOG_LOCATION}" )
  detailed_pods=$( get_resource_list_detailed pods "${NAMESPACE}" "${LOG_LOCATION}" )

  gather_crds_and_crs "${NAMESPACE}" "${LOG_LOCATION}" "${CRD_LIST[*]}"
  get_operator_install_resources "${NAMESPACE}" "${LOG_LOCATION}"

  printf "Gathering operator pod logs\n" | tee -a "${BASE_LOG}"

  for LABEL in ${OPERATOR_RESOURCE_LABEL}; do
    NAMESPACE_OPERATOR_PODS=$(kubectl get pods -n ${NAMESPACE} -l "${LABEL}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
    for POD in ${NAMESPACE_OPERATOR_PODS[@]}; do
      if ! [ -e "${LOG_LOCATION}/${POD}" ]; then
        get_pod_logs "${LOG_LOCATION}/${POD}" "${NAMESPACE}" "${POD}"
      fi
    done

    get_resources "${NAMESPACE}" "${LOG_LOCATION}" "${OPERATOR_RESOURCES[*]}" "${LABEL}"
  done
}

gather_eventstreams() {
  NAMESPACE="$1"
  LOG_LOCATION="$2"

  gather_operator_common "${NAMESPACE}" "${LOG_LOCATION}" "${ES_OPERATOR_CRDS[*]}" "app.kubernetes.io/name=eventstreams-operator eventstreams.ibm.com/kind=cluster-operator"

  printf  "Listing eventstream instances...\n" | tee -a "${BASE_LOG}"
  ES_INSTANCES=$( get_resource_list eventstreams "${NAMESPACE}" "${LOG_LOCATION}" )

  for INSTANCE in ${ES_INSTANCES}; do
    printf "Gathering diagnostics for %s\n" "${INSTANCE}" | tee -a "${BASE_LOG}"
    INSTANCE_LABEL="eventstreams.ibm.com/cluster=${INSTANCE}"
    ES_INGRESS_LABEL="app.kubernetes.io/name=management-ingress"
    ES_OIDC_LABEL="client.oidc.security.ibm.com/owned-by=${INSTANCE}-ibm-es-eventstreams"

    get_resources "${NAMESPACE}" "${LOG_LOCATION}" "${COMMON_RESOURCES[*]}" "${INSTANCE_LABEL}" "${ES_INGRESS_LABEL}" "${ES_OIDC_LABEL}"
    get_resources "${NAMESPACE}" "${LOG_LOCATION}" "${ES_OPERATOR_RESOURCES[*]}" "${INSTANCE_LABEL}" "${ES_INGRESS_LABEL}" "${ES_OIDC_LABEL}"
    get_es_certificates "${NAMESPACE}" "${LOG_LOCATION}" "${ES_OPERATOR_CERT_SECRETS[*]}" "${INSTANCE}"
    get_route_certs "${NAMESPACE}" "${INSTANCE_LABEL}" "${LOG_LOCATION}"

    for PERSISTENCE_LABEL in "${ES_OPERATOR_PERSISTENT_COMPONENT_LABELS[@]}"; do
      check_persistence "${NAMESPACE}" "${INSTANCE_LABEL}" "${PERSISTENCE_LABEL}"
    done

    check_zookeeper_pods "${NAMESPACE}" "${INSTANCE}" "${INSTANCE_LABEL}"
    check_kafka_pods "${NAMESPACE}" "${INSTANCE}" "${INSTANCE_LABEL}"

    for COMPONENT_LABEL in ${ES_OPERATOR_COMPONENT_LABELS[@]}; do
      PODS=$(kubectl get pods -n ${NAMESPACE} -l "${INSTANCE_LABEL},${COMPONENT_LABEL}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
      for POD in ${PODS[@]}; do
        get_pod_logs "${LOG_LOCATION}/${POD}" "${NAMESPACE}" "${POD}"
      done
    done
  done

  printf  "Listing kafkaconnect instances...\n" | tee -a "${BASE_LOG}"
  kafkaconnect_instances=$( get_resource_list kafkaconnect "${NAMESPACE}" "${LOG_LOCATION}" )
  if [ -z "$instances_kafka_connect" ]
  then
      printf "INFO: No Kafka Connect instances found\n" | tee -a "${BASE_LOG}"
  else
      printf "Gathering kafka connect pod logs" | tee -a "${BASE_LOG}"
      PODS_NAMESPACES=$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=kafka-connect --no-headers -o custom-columns=":metadata.namespace" | cleanOutput)
      PODS_NAMES=$(kubectl get pods --all-namespaces -l app.kubernetes.io/name=kafka-connect --no-headers -o custom-columns=":metadata.name" | cleanOutput)
      TEMP_ARR=(${PODS_NAMES[@]})
      LENGTH=${#TEMP_ARR[@]}
      for (( i=0; i<${LENGTH}; i++ )); do
         get_pod_logs "${LOG_LOCATION}/${PODS_NAMES[${i}]}" "${PODS_NAMESPACES[${i}]}" "${PODS_NAMES[${i}]}"
      done
  fi
}

gather_eem() {
  NAMESPACE="$1"
  LOG_LOCATION="$2"

  EEM_OPERATOR_LABEL="app.kubernetes.io/instance=ibm-eem-operator"

  gather_operator_common "${NAMESPACE}" "${LOG_LOCATION}" "${EEM_OPERATOR_CRDS[*]}" "${EEM_OPERATOR_LABEL}"
  get_certificates "${NAMESPACE}" "${LOG_LOCATION}" "${EEM_OPERATOR_CRDS[*]}" "${EEM_DEFAULT_SECRET_SUFFIX[*]}"

  printf  "Listing eem instances...\n" | tee -a "${BASE_LOG}"
  EEM_INSTANCES=$( get_resource_list eventendpointmanagements "${NAMESPACE}" "${LOG_LOCATION}" )
  printf  "Listing egw instances...\n" | tee -a "${BASE_LOG}"
  EGW_INSTANCES=$( get_resource_list eventgateways "${NAMESPACE}" "${LOG_LOCATION}" )

  for INSTANCE in ${EEM_INSTANCES} ${EGW_INSTANCES}; do
    printf "Gathering diagnostics for %s\n" "${INSTANCE}" | tee -a "${BASE_LOG}"
    INSTANCE_LABEL="app.kubernetes.io/instance=${INSTANCE}"

    get_resources "${NAMESPACE}" "${LOG_LOCATION}" "${COMMON_RESOURCES[*]}" "${INSTANCE_LABEL}"
    get_route_certs "${NAMESPACE}" "${INSTANCE_LABEL}" "${LOG_LOCATION}"

    PODS=$(kubectl get pods -n ${NAMESPACE} -l "${INSTANCE_LABEL}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
    for POD in ${PODS[@]}; do
      get_pod_logs "${LOG_LOCATION}/${POD}" "${NAMESPACE}" "${POD}"
    done

  done

}

gather_eventprocessing() {
  NAMESPACE="$1"
  LOG_LOCATION="$2"

  EP_OPERATOR_LABEL="app.kubernetes.io/instance=ibm-ep-operator"

  gather_operator_common "${NAMESPACE}" "${LOG_LOCATION}" "${EP_OPERATOR_CRDS[*]}" "${EP_OPERATOR_LABEL}"
  get_certificates "${NAMESPACE}" "${LOG_LOCATION}" "${EP_OPERATOR_CRDS[*]}" "${EP_DEFAULT_SECRET_SUFFIX[*]}"

  printf  "Listing ep instances...\n" | tee -a "${BASE_LOG}"
  EP_INSTANCES=$( get_resource_list eventprocessings "${NAMESPACE}" "${LOG_LOCATION}" )

  for INSTANCE in ${EP_INSTANCES}; do
    printf "Gathering diagnostics for %s\n" "${INSTANCE}" | tee -a "${BASE_LOG}"
    INSTANCE_LABEL="app.kubernetes.io/instance=${INSTANCE}"

    get_resources "${NAMESPACE}" "${LOG_LOCATION}" "${COMMON_RESOURCES[*]}" "${INSTANCE_LABEL}"
    get_route_certs "${NAMESPACE}" "${INSTANCE_LABEL}" "${LOG_LOCATION}"

    PODS=$(kubectl get pods -n ${NAMESPACE} -l "${INSTANCE_LABEL}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
    for POD in ${PODS[@]}; do
      get_pod_logs "${LOG_LOCATION}/${POD}" "${NAMESPACE}" "${POD}"
    done
  done

}

gather_flink() {
    NAMESPACE="$1"
    LOG_LOCATION="$2"

    FLINK_OPERATOR_LABEL="app.kubernetes.io/instance=ibm-eventautomation-flink-operator"
    gather_operator_common "${NAMESPACE}" "${LOG_LOCATION}" "${FLINK_OPERATOR_CRDS[*]}" "${FLINK_OPERATOR_LABEL}"

    printf  "Listing flinkdeployment instances...\n" | tee -a "${BASE_LOG}"
    FLINK_INSTANCES=$( get_resource_list flinkdeployments "${NAMESPACE}" "${LOG_LOCATION}" )

    for INSTANCE in ${FLINK_INSTANCES}; do
      printf "Gathering diagnostics for %s\n" "${INSTANCE}" | tee -a "${BASE_LOG}"
      INSTANCE_LABEL="app=${INSTANCE}"
      PRODUCT_LABEL="app.kubernetes.io/name=ibm-eventautomation-flink"

      get_resources "${NAMESPACE}" "${LOG_LOCATION}" "${COMMON_RESOURCES[*]}" "${INSTANCE_LABEL}"
      get_resources "${NAMESPACE}" "${LOG_LOCATION}" "${COMMON_RESOURCES[*]}" "${PRODUCT_LABEL}"

      get_route_certs "${NAMESPACE}" "${INSTANCE_LABEL}" "${LOG_LOCATION}"

      PODS=$(kubectl get pods -n ${NAMESPACE} -l "${INSTANCE_LABEL}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
      for POD in ${PODS[@]}; do
        get_pod_logs "${LOG_LOCATION}/${POD}" "${NAMESPACE}" "${POD}"
      done

      PODS=$(kubectl get pods -n ${NAMESPACE} --selector component=jobmanager,app="${INSTANCE}" --no-headers -o custom-columns=":metadata.name" | cleanOutput)
      for POD in ${PODS[@]}; do
        JOBS_LIST=$(kubectl exec ${POD} -n ${NAMESPACE} -- curl -s localhost:8081/jobs | jq -r '.jobs[].id')
        for job in $JOBS_LIST; do
          kubectl exec ${POD} -n ${NAMESPACE} -- curl -s localhost:8081/jobs/$job >> "${LOG_LOCATION}/${POD}/job-list"
          echo -e "\n---" >> "${LOG_LOCATION}/${POD}/job-list"
        done
      done
    done
}

###################################################################################################

declare -a OLM_OPERATOR_INSTALL_RESOURCES=(
    "installplans"
    "subscriptions"
    "clusterserviceversions"
    "operandrequests"
)

declare -a ES_OPERATOR_PERSISTENT_COMPONENT_LABELS=(
    "app.kubernetes.io/name=kafka"
    "app.kubernetes.io/name=schema-registry"
    "app.kubernetes.io/name=zookeeper"
)

declare -a ES_OPERATOR_COMPONENT_LABELS=(
    "app.kubernetes.io/name=admin-api"
    "app.kubernetes.io/name=admin-ui"
    "app.kubernetes.io/name=entity-operator"
    "app.kubernetes.io/name=kafka"
    "app.kubernetes.io/name=kafka-mirror-maker-2"
    "app.kubernetes.io/name=metrics"
    "app.kubernetes.io/name=rest-producer"
    "app.kubernetes.io/name=schema-registry"
    "app.kubernetes.io/name=zookeeper"
    "app.kubernetes.io/name=apicurio-registry"
    "app.kubernetes.io/name=apicurio-registry-v2"
    "app.kubernetes.io/name=kafka-proxy"
)

declare -a ES_OPERATOR_CRDS=(
    "eventstreams.eventstreams.ibm.com"
    "eventstreamsgeoreplicators.eventstreams.ibm.com"
    "kafkaconnectors.eventstreams.ibm.com"
    "kafkaconnects.eventstreams.ibm.com"
    "kafkaconnects2is.eventstreams.ibm.com"
    "kafkamirrormaker2s.eventstreams.ibm.com"
    "kafkarebalances.eventstreams.ibm.com"
    "kafkas.eventstreams.ibm.com"
    "kafkatopics.eventstreams.ibm.com"
    "kafkausers.eventstreams.ibm.com"
)

declare -a ES_OPERATOR_RESOURCES=(
    "client"
    "poddisruptionbudgets"
    "rolebindings"
    "roles"
    "strimzipodsets"
)

declare -a ES_OPERATOR_CERT_SECRETS=(
    "ibm-es-admapi-cert"
    "ibm-es-recapi-cert"
    "ibm-es-metrics-cert"
    "ibm-es-ac-reg-cert"
    "ibm-es-ac-reg2-cert"
    "ibm-es-ibmcloud-ca-cert"
    "cluster-ca-cert"
    "clients-ca-cert"
    "kafka-brokers"
    "zookeeper-nodes"
)

declare -a EEM_OPERATOR_CRDS=(
    "eventendpointmanagements.events.ibm.com"
    "eventgateways.events.ibm.com"
)

declare -a OPERATOR_RESOURCES=(
    "deployments"
    "roles"
    "rolebindings"
    "serviceaccounts"
)

declare -a COMMON_RESOURCES=(
    "certificates"
    "configmaps"
    "deployments"
    "issuers"
    "networkpolicies"
    "persistentvolumeclaims"
    "replicasets"
    "routes"
    "ingresses"
    "secrets"
    "services"
    "statefulsets"
    "serviceaccounts"
)

declare -a EEM_DEFAULT_SECRET_SUFFIX=(
    "ibm-eem-manager"
    "ibm-eem-manager-ca"
)

declare -a EP_OPERATOR_CRDS=(
    "eventprocessings.events.ibm.com"
)

declare -a EP_DEFAULT_SECRET_SUFFIX=(
    "ibm-ep-backend-cert"
    "ibm-ep-root-ca"
)

declare -a FLINK_OPERATOR_CRDS=(
    "flinkdeployments.flink.apache.org"
)

###################################################################################################
if [ $# -lt 1 ]; then
    printf "Terminating... No arguments specified\n"
    usage
    exit 1
fi

LAUNCH_ARGS="$@"
CURRENT_DATE=$(date "+%Y%m%d%H%M%S")
BASE_COLLECTION_PATH="./restricted-must-gather-${CURRENT_DATE}"
BASE_LOG="${BASE_COLLECTION_PATH}/must-gather.log"

unset SINCE
SINCE=120

# init value
modules=""
namespace=""
esnamespace=""
eemnamespace=""
epnamespace=""
flinknamespace=""

# overwrite default value by command line
while [[ $# -gt 0 ]];
do
    case "$1" in
        "-m"|"--modules")
            modules="$2"
            shift 2;
            ;;
        "-n"|"--namespace")
            namespace="$2"
            shift 2;
            ;;
        "--es-namespace")
            esnamespace="$2"
            shift 2;
            ;;
        "--eem-namespace")
            eemnamespace="$2"
            shift 2;
            ;;
        "--ep-namespace")
            epnamespace="$2"
            shift 2;
            ;;
        "--flink-namespace")
            flinknamespace="$2"
            shift 2;
            ;;
        "-h"|"--help")
            usage
            exit 0
            ;;
        --)
            shift
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

products=0
module_array=(${modules//,/ })
for m in "${module_array[@]}"
do
  case $m in
    "eventstreams"|"eem"|"eventprocessing"|"flink")
      let products+=1
      ;;
  esac
done

if [ "${products}" -gt 1 ]; then
  if [ -n "${namespace}" ]; then
    printf "namespace is not a valid flag when multiple modules specified, use individual flags:\n"
    usage
    exit 2
  fi

  #check namespace flags
  for m in "${module_array[@]}"
  do
    case "$m" in
      "eventstreams")
        if [ -z "${esnamespace}" ]; then
          printf "you must indicate the eventstreams namespace using the  -es|--es-namespace flag\n"
          exit 3
        fi
        ;;
      "eem")
        if [ -z "${eemnamespace}" ]; then
          printf "you must indicate the eem namespace using the  -eem|--eem-namespace flag\n"
          exit 4
        fi
        ;;
      "eventprocessing")
        if [ -z "${epnamespace}" ]; then
          printf "you must indicate the eventprocessing namespace using the  -ep|--ep-namespace flag\n"
          exit 5
        fi
        ;;
      "flink")
        if [ -z "${flinknamespace}" ]; then
          printf "you must indicate the flink namespace using the  -flink|--flink-namespace flag\n"
          exit 5
        fi
        ;;
    esac
  done
fi

mkdir -p "${BASE_COLLECTION_PATH}"
printf "Arguments passed to gather script were:  %s\n" "${LAUNCH_ARGS}"| tee -a "${BASE_LOG}"

if [ -n "${namespace}" ]; then
  # If we have got here only one product module being collected
  # set all namespaces to the namespace value
  esnamespace="${namespace}"
  epnamespace="${namespace}"
  eemnamespace="${namespace}"
  flinknamespace="${namespace}"
else
  printf "esnamespace = ${esnamespace}\n"
  printf "epnamespace = ${epnamespace}\n"
  printf "eemnamespace = ${eemnamespace}\n"
  printf "flinknamespace = ${flinknamespace}\n"
fi

check_openssl

for m in "${module_array[@]}"
do
   case $m in
       "eventstreams")
            gather_eventstreams "${esnamespace}" "${BASE_COLLECTION_PATH}/es"
            ;;
       "eem")
            gather_eem "${eemnamespace}" "${BASE_COLLECTION_PATH}/eem"
            ;;
       "eventprocessing")
            gather_eventprocessing "${epnamespace}" "${BASE_COLLECTION_PATH}/ep"
            ;;
       "flink")
            gather_flink "${flinknamespace}" "${BASE_COLLECTION_PATH}/flink"
            ;;
        *)
            printf "Invalid module $m\n"
            usage
            exit 1
            ;;
   esac
done