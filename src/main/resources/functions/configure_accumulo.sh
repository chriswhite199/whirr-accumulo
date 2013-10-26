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
    
  if [ -z "$ACCUMULO_HOME" ]; then
    ACCUMULO_HOME=/usr/local/`ls -1 /usr/local/ | grep accumulo | head -n 1`
  fi

  if [ -z "$ACCUMULO_CONF_DIR" ]; then
    ACCUMULO_CONF_DIR=$ACCUMULO_HOME/conf
  fi

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

  CONFIGURE_ACCUMULO_DONE=1
}