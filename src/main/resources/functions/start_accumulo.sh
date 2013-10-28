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
  shift

  if [ "$START_ACCUMULO_DONE" == "1" ]; then
    echo "Accumulo is already started."
    return;
  fi

  # get parameters
  while getopts "i:n:p:" OPTION; do
    case $OPTION in
    i)
      IP="$OPTARG"
      ;;
    n)
      INSTANCE="$OPTARG"
      ;;
    p)
      PASSWORD="$OPTARG"
      ;;
    esac
  done
  
  if [ -z "$ACCUMULO_HOME" ]; then
    export ACCUMULO_HOME=/usr/local/`ls -1 /usr/local/ | grep accumulo | head -n 1`
  fi

  if [ -z "$ACCUMULO_CONF_DIR" ]; then
    export ACCUMULO_CONF_DIR=$ACCUMULO_HOME/conf
  fi
  
  if [ -z "$ACCUMULO_LOG_DIR" ]; then
    export ACCUMULO_LOG_DIR=$ACCUMULO_HOME/logs  
  fi

  if [ $(echo "$ROLES" | grep "accumulo-master" | wc -l) -gt 0 ]; then
    init_accumulo_master $INSTANCE $PASSWORD
  fi

  for role in $(echo "$ROLES" | tr "," "\n"); do
    case $role in
    accumulo-master)
      start_accumulo_service master ${IP}
      ;;
    accumulo-tserver)
      start_accumulo_service tserver ${IP}
      ;;
    accumulo-gc)
      start_accumulo_service gc ${IP}
      ;;
    accumulo-logger)
      start_accumulo_service logger ${IP}
      ;;
    esac
  done

  START_ACCUMULO_DONE=1
}

function init_accumulo_master() {
  if which dpkg &> /dev/null; then
    AS_HADOOP="su -s /bin/bash - hadoop -c"
  elif which rpm &> /dev/null; then
    AS_HADOOP="/sbin/runuser -s /bin/bash - hadoop -c"
  fi

  $AS_HADOOP "$ACCUMULO_HOME/bin/accumulo init --instance-name $1 --password $2" 2>&1 1>> /tmp/start-accumulo.log
  $AS_HADOOP "${ACCUMULO_HOME}/bin/accumulo org.apache.accumulo.server.master.state.SetGoalState NORMAL" 2>&1 1>> /tmp/start-accumulo.log
}

function start_accumulo_service() {
  if which dpkg &> /dev/null; then
    AS_HADOOP="su -s /bin/bash - hadoop -c"
  elif which rpm &> /dev/null; then
    AS_HADOOP="/sbin/runuser -s /bin/bash - hadoop -c"
  fi
  
  SERVICE=$1
  
  STDOUT=${ACCUMULO_LOG_DIR}/${SERVICE}_${PRIVATE_IP}.out
  STDERR=${ACCUMULO_LOG_DIR}/${SERVICE}_${PRIVATE_IP}.err
  
  echo "Starting $SERVICE for $IP" >> /tmp/start-accumulo.log
  
  $AS_HADOOP bash<<BASH_END
  ${ACCUMULO_HOME}/bin/accumulo ${SERVICE} --address $PRIVATE_IP &
BASH_END
}
