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

#set -v
#set -x

PIPEWORK=$HOME/pipework/pipework

# get number of nodes in cluster
NODES=`grep NODES target/cluster.properties | gawk '{ print $2 }'`
echo $NODES

# docker info
DOCKER_IMAGE=sshd-openjdk6
DOCKER_CMD="sudo docker"

# generate ssh key pair
if [ -f target/id_rsa ]; then
	rm -f target/id_rsa*
fi
ssh-keygen -t rsa -P '' -f target/id_rsa

# generate minimal dockerfile to inject ssh keypair into base image
cat << EOF > target/Dockerfile
FROM $DOCKER_IMAGE
RUN mkdir -p /root/.ssh
ADD id_rsa.pub /root/.ssh/authorized_keys
RUN chmod go-rwx /root/.ssh/*
RUN chown root:root -R /root/.ssh/*
EOF

if [ -f target/docker.imageId ]; then
	$DOCKER_CMD rmi `cat target/docker.imageId` 2>/dev/null
fi

DOCKER_IMAGE=`$DOCKER_CMD build target | grep "Successfully built" | gawk '{ print $3 }'`
if [ -z "$DOCKER_IMAGE" ]; then
	echo "Error creating docker image"
	exit 1
fi
echo "Docker Img with SSH Keys: $DOCKER_IMAGE"
echo $DOCKER_IMAGE > target/docker.imageId

echo -n "" > target/docker.sed
echo -n "" > target/docker.containers

for (( x=0; x<$NODES; x++ )); do
	# Start docker container so we can acquire the docker assigned hostnames and IPs
	DOCKER_CONTAINERS[$x]=`$DOCKER_CMD run -d $DOCKER_IMAGE /usr/sbin/sshd -D`
	echo ${DOCKER_CONTAINERS[$x]} >> target/docker.containers
	DOCKER_IPS[$x]=`$DOCKER_CMD inspect ${DOCKER_CONTAINERS[$x]} | grep IPAddress | gawk -F \" '{ print $4 }'`
	DOCKER_HOSTNAMES[$x]=`$DOCKER_CMD inspect ${DOCKER_CONTAINERS[$x]} | grep Hostname\" | gawk -F \" '{ print $4 }'`

	# Find the JClouds generated IP and hostnames
	JCLOUDS_HOSTNAMES[$x]=`grep "$x[[:space:]]HOSTNAME" target/cluster.properties | gawk '{ print $3 }'` 
	JCLOUDS_PRIVATE_IPS[$x]=`grep "$x[[:space:]]PRIVATE_IP" target/cluster.properties | gawk '{ print $3 }'`
	JCLOUDS_PUBLIC_IPS[$x]=`grep "$x[[:space:]]PUBLIC_IP" target/cluster.properties | gawk '{ print $3 }'`

	# Acquire how many scripts were generated for this node
	SCRIPTS[$x]=`grep "$x[[:space:]]SCRIPTS" target/cluster.properties | gawk '{ print $3 }'`

	echo ${DOCKER_CONTAINERS[$x]} ${DOCKER_HOSTNAMES[$x]} ${DOCKER_IPS[$x]} 
	echo ${JCLOUDS_HOSTNAMES[$x]} ${JCLOUDS_PRIVATE_IPS[$x]} ${JCLOUDS_PUBLIC_IPS[$x]}

	# add jclouds to docker private IP replacement stmt
	echo "s/${JCLOUDS_PRIVATE_IPS[$x]}/${DOCKER_IPS[$x]}/g" >> target/docker.sed
	# Add jclouds hostname to docker private IP replacement stmt
	echo "s/${JCLOUDS_HOSTNAMES[$x]}/${DOCKER_IPS[$x]}/g" >> target/docker.sed

	# now create updated versions of the whirr scripts
	for (( s=0; s<${SCRIPTS[$x]}; s++ )); do
		cp -f "target/${JCLOUDS_PRIVATE_IPS[$x]}-${JCLOUDS_PUBLIC_IPS[$x]}-$s.sh" "target/${DOCKER_IPS[$x]}-$s.sh"
	done
done

function run_node_scripts {
	x=$1
	SCRIPTS=$2
	DOCKER_IP=$3
	LOG=target/node-$x.log

	echo "Starting node $x" 2>&1 1> $LOG

	for (( s=0; s<$SCRIPTS; s++ )); do
		sed -i -f target/docker.sed target/$DOCKER_IP-$s.sh
	done

	chmod u+x target/$DOCKER_IP-*.sh

	# copy scripts (ignore unknown hosts and host key checking)
	scp -i target/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
		target/$DOCKER_IP-*.sh root@$DOCKER_IP:/tmp

	for (( s=0; s<$SCRIPTS; s++ )); do
		echo "-------------------------------------------------------------" >> $LOG
		echo "Running script $s" >> $LOG

		ssh -i target/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
			root@$DOCKER_IP /tmp/$DOCKER_IP-$s.sh "init"

		if [ $? -ne 0 ]; then
			echo "Failed in running $DOCKER_IP-$s.sh init"
			return 1
		fi

		ssh -i target/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
			root@$DOCKER_IP /tmp/$DOCKER_IP-$s.sh "run" 2>&1 1>> $LOG

		if [ $? -ne 0 ]; then
			echo "Failed in running $DOCKER_IP-$s.sh run"
			return 1
		fi
	done

	return 0
}

export -f run_node_scripts

# give time to start
sleep 5s

# Run the init scripts on each node in parallel
for (( x=0; x<$NODES; x++ )); do
	echo $x ${SCRIPTS[$x]} ${DOCKER_IPS[$x]}
done | xargs -n 3 -P $NODES bash -c 'run_node_scripts "$@"' --
