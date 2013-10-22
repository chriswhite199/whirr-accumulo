#/bin/bash

set -v
set -x

PIPEWORK=$HOME/pipework/pipework

# get number of nodes in cluster
NODES=`grep NODES target/cluster.properties | gawk '{ print $2 }'`
echo $NODES

# docker info
DOCKER_IMAGE=cswhite/sshd_openjdk-6
DOCKER_CMD="sudo docker"

# generate ssh key pair
if [ -f target/id_rsa ]; then
	rm -f target/id_rsa*
fi
ssh-keygen -t rsa -P '' -f target/id_rsa

# generate minimal dockerfile to inject ssh keypair into base image
cat << EOF > target/Dockerfile
FROM $DOCKER_IMAGE
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

# now replace the jcloud assigned private IP and hostnames with the docker IPs 
# (can't use hostnames as they are not registered anywhere)
for (( x=0; x<$NODES; x++ )); do
	for (( s=0; s<${SCRIPTS[$x]}; s++ )); do
		sed -i -f target/docker.sed target/${DOCKER_IPS[$x]}-$s.sh
	done

	chmod u+x target/${DOCKER_IPS[$x]}-*.sh

	# copy scripts (ignore unknown hosts and host key checking)
	scp -i target/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
		target/${DOCKER_IPS[$x]}-*.sh root@${DOCKER_IPS[$x]}:/tmp

	for (( s=0; s<${SCRIPTS[$x]}; s++ )); do
		ssh -i target/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
			root@${DOCKER_IPS[$x]} /tmp/${DOCKER_IPS[$x]}-$s.sh "init"

		if [ $? -ne 0 ]; then
			exit "Failed in running ${DOCKER_IPS[$x]}-$s.sh init"
		fi

		ssh -i target/id_rsa -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
			root@${DOCKER_IPS[$x]} /tmp/${DOCKER_IPS[$x]}-$s.sh "run"

		if [ $? -ne 0 ]; then
			exit "Failed in running ${DOCKER_IPS[$x]}-$s.sh run"
		fi
	done
done
