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
  echo "Launches a Flink cluster on docker compose to execute SQL statements with User-Defined Functions (UDF) using the Flink SQL client."
  echo "Syntax: $(basename ${0}) [option]"
  echo "Available options:"
  echo "  start            Starts the Flink cluster."
  echo "  run <sql file>   Executes the SQL statements contained in the provided SQL file."
  echo "  reset            Resets the Flink cluster."
  echo "  stop             Stops the Flink cluster."
}

function main() {
  local command=${1}
  local subCommand=${2}
  local currentDir="$(dirname "${0}")"

  if [ -z "${command}" ]; then
    usage
    exit 1
  fi

  shift
  case ${command} in
    "start")
      echo "Starting docker compose..."
      docker compose -f ${currentDir}/docker-compose/docker-compose.yaml up -d
      ;;
    "reset")
      echo "Resetting docker compose..."
      docker compose -f ${currentDir}/docker-compose/docker-compose.yaml rm -s -f -v
      ;;
    "stop")
      echo "Stopping docker compose..."
      docker compose -f ${currentDir}/docker-compose/docker-compose.yaml down -v
      ;;
    "run")
      local sqlFile=${subCommand:?}
      if [ ! -f "${sqlFile}" ]; then
        echo >&2 "Error: file ${sqlFile} not found"
        exit 1
      fi
      echo "Executing ${sqlFile}... (it might take a few minutes to complete)"
      docker compose -f ${currentDir}/docker-compose/docker-compose.yaml exec sp-flink bash -c "/opt/flink/bin/sql-client.sh -f /var/host/${sqlFile}"
      ;;
     
    *)
      echo >&2 "Error: invalid command '${command}'"; usage; exit 1
  esac

  echo "==> ${command} performed."
}

main "$@"
