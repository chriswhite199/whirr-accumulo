#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
function start_accumulo() {
  local OPTIND
  local OPTARG
 
  ROLES=$1

  if [ "$START_ACCUMULO_DONE" == "1" ]; then
    echo "Accumulo is already started."
    return;
  fi

  if [ $(echo "$ROLES" | grep "accumulo-master" | wc -l) -gt 0 ]; then
    start_accumulo_master
  fi

  for role in $(echo "$ROLES" | tr "," "\n"); do
    case $role in
    accumulo-tserver)
      start_accumulo_daemon tserver
      ;;
    accumulo-gc)
      start_accumulo_daemon gc
      ;;
    accumulo-logger)
      start_accumulo_daemon logger
      ;;
    esac
  done

  START_ACCUMULO_DONE=1
}

function start_accumulo_master() {
  ${ACCUMULO_HOME}/bin/accumulo org.apache.accumulo.server.master.state.SetGoalState NORMAL
  ${ACCUMULO_HOME}/bin/start-server.sh $PRIVATE_IP master
}
