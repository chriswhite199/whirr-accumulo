#!/bin/bash

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

# Test script for launching on trystack

WHIRR_OPTS="--config target/trystack-accumulo.properties"

if [ -z "$OS_USERNAME" ]; then
	echo "OpenStack.rc env variable OS_USERNAME not detected"
	exit 1
elif [ -z "$OS_TENANT_NAME" ]; then
	echo "OpenStack.rc env variable OS_TENANT_NAME not detected"
	exit 1
elif [ -z "$OS_AUTH_URL" ]; then
	echo "OpenStack.rc env variable OS_AUTH_URL not detected"
	exit 1
elif [ -z "$OS_PASSWORD" ]; then
	echo "OpenStack.rc env variable OS_PASSWORD not detected"
	exit 1
fi

if [ -z "$WHIRR_HOME" ]; then
	echo "WHIRR_HOME env variable not set"
	exit 1
elif [ ! -f $WHIRR_HOME/bin/whirr ]; then
	echo "\$WHIRR_HOME/bin/whirr not found"
	exit 1
fi

rm target/trystack-accumulo.properties

cat << EOF > target/trystack-accumulo.properties
whirr.provider=trystack-nova
whirr.endpoint=$OS_AUTH_URL
whirr.identity=$OS_TENANT_NAME:$OS_USERNAME
whirr.credential=$OS_PASSWORD
whirr.location-id=RegionOne
#whirr.image-id=RegionOne/5e809aa3-c95e-4241-8e6a-1d807804c313
whirr.image-id=RegionOne/c03cfd5d-63ca-4aeb-87f9-41a85cffcab8
#whirr.instance-templates=1 hadoop-namenode+hadoop-jobtracker+hadoop-datanode+hadoop-tasktracker+accumulo-master
whirr.instance-templates=1 accumulo-master
whirr.private-key-file=target/id_rsa_trystack
whirr.cluster-name=accumulo
EOF

if [ ! -f target/id_rsa_trystack ]; then
	echo "Generating SSH Key Pair"
	ssh-keygen -P '' -t rsa -f target/id_rsa_trystack
fi

function start_cluster() {
	echo "Starting cluster"
	$WHIRR_HOME/bin/whirr launch-cluster $WHIRR_OPTS
}

function stop_cluster() {
	echo "Stopping cluster"
	$WHIRR_HOME/bin/whirr destroy-cluster $WHIRR_OPTS
}

function print_usage() {
	echo "Usage: `basename $0` <start|stop>"
}

# Check some environment variables hav ebeen set

action=$1

if [ -z "$action" ]; then
	print_usage
	exit 1
fi

case $action in
start)
	start_cluster
	;;
stop)
	stop_cluster
	;;
*)
	print_usage
	exit 1
	;;
esac
