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
# Templated from the hbase and hadoop install whirr scripts
function update_repo() {
  if which dpkg &> /dev/null; then
    retry_apt_get update
  elif which rpm &> /dev/null; then
    retry_yum update -y yum
  fi
}

function install_accumulo() {
  local OPTIND
  local OPTARG
  
  if [ "$INSTALL_ACCUMULO_DONE" == "1" ]; then
    echo "Accumulo is already installed."
    return;
  fi
  
  echo "Installing ACCUMULO"
  
  ACCUMULO_TAR_URL=
  ZOOKEEPER_TAR_URL=
  while getopts "u:z:" OPTION; do
    case $OPTION in
    u)
      ACCUMULO_TAR_URL="$OPTARG"
      ;;
    z)
      ZOOKEEPER_TAR_URL="$OPTARG"
      ;;
    esac
  done
  
  # assign default URL if no other given (optional)
  ACCUMULO_TAR_URL=${ACCUMULO_TAR_URL:-http://archive.apache.org/dist/accumulo/1.5.0/accumulo-1.5.0-bin.tar.gz}
  ZOOKEEPER_TAR_URL=${ZOOKEEPER_TAR_URL:-http://archive.apache.org/dist/zookeeper/zookeeper-3.4.5/zookeeper-3.4.5.tar.gz}

  # derive details from the URL
  ACCUMULO_TAR_FILE=${ACCUMULO_TAR_URL##*/}
  ACCUMULO_TAR_MD5_FILE=$ACCUMULO_TAR_FILE.md5

  # extract "version" or the name of the directory contained in the tarball,
  # but since hbase has used different namings use the directory instead.
  ACCUMULO_VERSION=${ACCUMULO_TAR_URL%/*.tar.gz}
  ACCUMULO_VERSION=${ACCUMULO_VERSION##*/}
  ZOOKEEPER_VERSION=ZOOKEEPER_HOME=/usr/local/$(basename $ZOOKEEPER_TAR_URL '.tar.gz')

  # simple check that we have a proper URL or default to use filename
  if [[ "${ACCUMULO_VERSION:0:8}" != "accumulo" ]]; then
    ACCUMULO_VERSION=${ACCUMULO_TAR_FILE%.tar.gz}
  fi

  update_repo

  if ! id hadoop &> /dev/null; then
    useradd hadoop
  fi

  # up file-max
  sysctl -w fs.file-max=65535
  # up ulimits
  echo "root soft nofile 65535" >> /etc/security/limits.conf
  echo "root hard nofile 65535" >> /etc/security/limits.conf
  ulimit -n 65535
  # up epoll limits; ok if this fails, only valid for kernels 2.6.27+
  set +e
  sysctl -w fs.epoll.max_user_instances=4096 > /dev/null 2>&1
  set -e
  # if there is no hosts file then provide a minimal one
  [ ! -f /etc/hosts ] && echo "127.0.0.1 localhost" > /etc/hosts

  install_tarball $ACCUMULO_TAR_URL

  ACCUMULO_HOME=/usr/local/`ls -1 /usr/local/ | grep accumulo | head -n 1`
  ACCUMULO_CONF_DIR=$ACCUMULO_HOME/conf
  cp $ACCUMULO_CONF_DIR/examples/512MB/standalone/* $ACCUMULO_CONF_DIR/

  echo "export ACCUMULO_HOME=$ACCUMULO_HOME" >> /etc/profile
  echo 'export PATH=$JAVA_HOME/bin:$ACCUMULO_HOME/bin:$PATH' >> /etc/profile

  # detect if zookeeper has already been installed, if not download and unpack it
  if [[ -z "$ZOOKEEPER_HOME" || ! -d $ZOOKEEPER_HOME ]]; then
    echo "Installing ZooKeeper from $ZOOKEEPER_TAR_URL"
    install_tarball $ZOOKEEPER_TAR_URL
    ZOOKEEPER_HOME=/usr/local/`ls -1 /usr/local/ | grep zookeeper | head -n 1`
    echo "export ZOOKEEPER_HOME=$ZOOKEEPER_HOME" >> /etc/profile
  fi

  INSTALL_ACCUMULO_DONE=1
}

