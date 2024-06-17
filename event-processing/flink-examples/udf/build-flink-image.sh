#!/bin/bash

# Copyright 2024 IBM Corp. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

set -e

function usage() {
  echo "Augments an IBM Flink image with the User-Defined Functions (UDF) JAR."
  echo "Syntax: $(basename ${0}) <IBM_FLINK_IMAGE>"
}

function udfJarName() {
  local projectAbsolutePath=$(cd "$(dirname "$0")" && pwd)
  local artifactId=$(mvn help:evaluate -Dexpression="project.artifactId" -q -DforceStdout -f "${projectAbsolutePath}/pom.xml")
  local version=$(mvn help:evaluate -Dexpression="project.version" -q -DforceStdout -f "${projectAbsolutePath}/pom.xml")
  printf "%s-%s.jar" ${artifactId} ${version}
}

function main() {
  local projectAbsolutePath=$(cd "$(dirname "$0")" && pwd)

  local ibmflinkImage=${1}
  if [ -z "${ibmflinkImage}" ]; then
    echo >&2 "Error: No IBM Flink image provided."
    usage
    exit 1
  fi

  local udfJar="${projectAbsolutePath}/target/$(udfJarName)"
  if [ ! -f "${udfJar}" ]; then
    echo >&2 "Error: file ${udfJar} not found, build the Maven project first."
    exit 1
  fi

  docker build ${projectAbsolutePath} -t flink-with-udf:latest --build-arg UDF_JAR="${udfJarName}" --build-arg FLINK_IMAGE="${ibmflinkImage}"
}

main "$@"
