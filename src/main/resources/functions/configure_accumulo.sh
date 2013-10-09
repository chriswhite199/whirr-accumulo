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
# Templated from the configure_zookeeper.sh script
function configure_accumulo() {
  local OPTIND
  local OPTARG

  if [ "$CONFIGURE_ACCUMULO_DONE" == "1" ]; then
    echo "Accumulo is already configured."
    return;
  fi
  
  ROLES=$1
  shift
  
  # get parameters
  MASTER_HOST=
  ZOOKEEKER_QUORUM=
  ACCUMULO_TAR_URL=
  while getopts "u:i:p:" OPTION; do
    case $OPTION in
    i)
      INSTANCE="$OPTARG"
      ;;
    p)
      PASSWORD="$OPTARG"
      ;;
    u)
      ACCUMULO_TAR_URL="$OPTARG"
      ;;
    esac
  done
  
  # assign default URL if no other given (optional)
  ACCUMULO_TAR_URL=${ACCUMULO_TAR_URL:-http://archive.apache.org/dist/accumulo/1.5.0/accumulo-1.5.0-bin.tar.gz}
  # derive details from the URL
  ACCUMULO_TAR_FILE=${ACCUMULO_TAR_URL##*/}
  # extract "version" or the name of the directory contained in the tarball,
  # but since accumulo has used different namings use the directory instead.
  ACCUMULO_VERSION=${ACCUMULO_TAR_URL%/*.tar.gz}
  ACCUMULO_VERSION=${ACCUMULO_VERSION##*/}
  # simple check that we have a proper URL or default to use filename
  if [[ "${ACCUMULO_VERSION:0:8}" != "accumulo" ]]; then
    ACCUMULO_VERSION=${ACCUMULO_TAR_FILE%.tar.gz}
  fi
  ACCUMULO_HOME=/usr/local/$ACCUMULO_VERSION
  ACCUMULO_CONF_DIR=$ACCUMULO_HOME/conf

  case $CLOUD_PROVIDER in
  ec2 | aws-ec2 )
    MOUNT=/mnt
    ;;
  *)
    MOUNT=/data
    ;;
  esac

  mkdir -p $MOUNT/accumulo
  chown hadoop:hadoop $MOUNT/accumulo
  if [ ! -e $MOUNT/tmp ]; then
    mkdir $MOUNT/tmp
    chmod a+rwxt $MOUNT/tmp
  fi
  mkdir /etc/accumulo
  ln -s $ACCUMULO_CONF_DIR /etc/accumulo/conf

  # Copy generated configuration files in place
  cp /tmp/accumulo-site.xml $ACCUMULO_CONF_DIR
  cp /tmp/accumulo-env.sh $ACCUMULO_CONF_DIR

  # ACCUMULO_PID_DIR should exist and be owned by hadoop:hadoop
  mkdir -p /var/run/accumulo
  chown -R hadoop:hadoop /var/run/accumulo
  
  # Create the actual log dir
  mkdir -p $MOUNT/accumulo/logs
  chown -R hadoop:hadoop $MOUNT/accumulo/logs

  # Create a symlink at $ACCUMULO_LOG_DIR
  ACCUMULO_LOG_DIR=$(. $ACCUMULO_CONF_DIR/accumulo-env.sh; echo $ACCUMULO_LOG_DIR)
  ACCUMULO_LOG_DIR=${ACCUMULO_LOG_DIR:-/var/log/accumulo/logs}
  rm -rf $ACCUMULO_LOG_DIR
  mkdir -p $(dirname $ACCUMULO_LOG_DIR)
  ln -s $MOUNT/accumulo/logs $ACCUMULO_LOG_DIR
  chown -R hadoop:hadoop $ACCUMULO_LOG_DIR

  if [ $(echo "$ROLES" | grep "accumulo-master" | wc -l) -gt 0 ]; then
    start_ACCUMULO_master
  fi

  for role in $(echo "$ROLES" | tr "," "\n"); do
    case $role in
    accumulo-tabletserver)
      start_ACCUMULO_daemon tserver "tablet server"
      ;;
    accumulo-gcserver)
      start_ACCUMULO_daemon gc "garbage collector"
      ;;
    accumulo-tracerserver)
      start_ACCUMULO_daemon tracer
      ;;
    accumulo-monitorserver)
      start_ACCUMULO_daemon monitor
      ;;
    esac
  done

  CONFIGURE_ACCUMULO_DONE=1
}

function start_ACCUMULO_master() {
  if which dpkg &> /dev/null; then
    AS_HADOOP="su -s /bin/bash - hadoop -c"
  elif which rpm &> /dev/null; then
    AS_HADOOP="/sbin/runuser -s /bin/bash - hadoop -c"
  fi

  $AS_HADOOP "$ACCUMULO_HOME/bin/accumulo init --instance-name $INSTANCE --instance-name --password $PASSWORD"
  $AS_HADOOP "$ACCUMULO_HOME/bin/accumulo org.apache.accumulo.server.master.state.SetGoalState NORMAL"

  start_ACCUMULO_daemon master
}

function start_ACCUMULO_daemon() {
  if which dpkg &> /dev/null; then
    AS_HADOOP="su -s /bin/bash - hadoop -c"
  elif which rpm &> /dev/null; then
    AS_HADOOP="/sbin/runuser -s /bin/bash - hadoop -c"
  fi

  $AS_HADOOP "$ACCUMULO_HOME/bin/start-server.sh $HOST $1 $2"
}

