FROM ubuntu:12.04

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y openssh-server less net-tools cron openjdk-6-jdk curl

RUN mkdir /var/run/sshd
RUN /usr/sbin/sshd

# commit to a tag named 'sshd-openjdk6'
# sudo docker tag <img-id> sshd-openjdk6