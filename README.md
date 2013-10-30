Whirr-Accumulo Service
======================

[Accumulo](http://accumulo.apache.org/) service for [Apache Whirr](http://whirr.apache.org)

Testing
-------

This service has been minimally tested on a single host via a combination of a 
[unit test](/src/test/java/org/apache/whirr/service/accumulo/AccumuloClusterTest.java) to build 
up the scripts for each stage (install, configure, start), and then a 
[bash script file](/src/test/resources/docker-start.sh) in combination
with [Docker](http://www.docker.io/) to spawn up some minimal containers for each node in the Whirr 
instance template.

This is somewhat temporamental as the script currnelty starts all script stages one after the other for 
each node (nodes are started in parallel), so often the Tablet Server instances started in the start phase
fail as either HDFS, ZooKeeper or accumulo-init has yet to be started.

This is usually fixed by re-running the start stage script (x.x.x.x-2.sh):

```bash
[user@host whirr-accumulo] ssh -i target/id_rsa 172.17.0.4 /tmp/172.17.0.4-2.sh run
```

Obviously the proper way to do testing would be some integration tests that actually spin up a remote cluster
on EC2 etc and if someone wants to donate towards this development cost then let me know
