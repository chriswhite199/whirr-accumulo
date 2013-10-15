/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.whirr.service.accumulo;

import static org.apache.whirr.RolePredicates.role;
import static org.apache.whirr.service.accumulo.AccumuloConfigurationBuilder.buildAccumuloEnv;
import static org.apache.whirr.service.accumulo.AccumuloConfigurationBuilder.buildAccumuloSite;
import static org.jclouds.scriptbuilder.domain.Statements.call;

import java.io.IOException;
import java.util.List;
import java.util.Set;

import org.apache.commons.configuration.Configuration;
import org.apache.commons.configuration.ConfigurationException;
import org.apache.whirr.Cluster;
import org.apache.whirr.Cluster.Instance;
import org.apache.whirr.ClusterSpec;
import org.apache.whirr.service.ClusterActionEvent;
import org.apache.whirr.service.FirewallManager.Rule;
import org.apache.whirr.service.zookeeper.ZooKeeperClusterActionHandler;
import org.jclouds.scriptbuilder.domain.Statement;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.common.base.Function;
import com.google.common.base.Joiner;
import com.google.common.collect.Lists;

public class AccumuloMasterClusterActionHandler extends AccumuloClusterActionHandler {
    private static final Logger LOG = LoggerFactory.getLogger(AccumuloMasterClusterActionHandler.class);

    public static final String ROLE = "accumulo-master";

    @Override
    public String getRole() {
        return ROLE;
    }

    @Override
    protected void beforeBootstrap(ClusterActionEvent event) throws IOException {
        ClusterSpec clusterSpec = event.getClusterSpec();
        Configuration conf = getConfiguration(clusterSpec);

        addStatement(event, call("retry_helpers"));
        addStatement(event, call("install_tarball"));
        addStatement(event, call("configure_hostnames"));

        addStatement(event, call(getInstallFunction(conf, "java", "install_openjdk")));

        String accTarUrl = prepareRemoteFileUrl(event,
                getConfiguration(clusterSpec).getString(AccumuloConstants.ACCUMULO_TARBALL_URL));
        String zkTarUrl = prepareRemoteFileUrl(event,
                getConfiguration(clusterSpec).getString(AccumuloConstants.ZK_TARBALL_URL));

        String accInstallFunc = getInstallFunction(getConfiguration(clusterSpec));

        Statement accInstallStmt = call(accInstallFunc, AccumuloConstants.PARAM_ACC_TARBALL_URL, accTarUrl,
                AccumuloConstants.PARAM_ZK_TARBALL_URL, zkTarUrl);

        addStatement(event, accInstallStmt);
    }

    @Override
    protected void beforeConfigure(ClusterActionEvent event) throws IOException, InterruptedException {

        ClusterSpec clusterSpec = event.getClusterSpec();
        Cluster cluster = event.getCluster();

        Configuration conf = getConfiguration(clusterSpec);

        // add some service firewall holes
        event.getFirewallManager().addRule(
                Rule.create().destination(role(ROLE)).port(conf.getInt(AccumuloConstants.PROP_ACCUMULO_PORT_MASTER)));

        handleFirewallRules(event);

        // Velocity is assuming flat classloaders or TCCL to load templates.
        // This doesn't work in OSGi unless we set the TCCL to the bundle
        // classloader before invocation
        ClassLoader oldTccl = Thread.currentThread().getContextClassLoader();

        try {
            Thread.currentThread().setContextClassLoader(getClass().getClassLoader());
            event.getStatementBuilder().addStatements(
                    buildAccumuloSite("/tmp/accumulo-site.xml", clusterSpec, cluster),
                    buildAccumuloEnv("/tmp/accumulo-env.sh", clusterSpec, cluster));
        } catch (ConfigurationException e) {
            throw new IOException(e);
        } finally {
            Thread.currentThread().setContextClassLoader(oldTccl);
        }

        // Pass list of all servers in ensemble to configure script.
        // Position is significant: i-th server has id i.

        Set<Instance> ensemble = cluster.getInstancesMatching(role(ZooKeeperClusterActionHandler.ZOOKEEPER_ROLE));
        String zkCsv = Joiner.on(',').join(getZookeepersCsv(ensemble));

        Configuration config = getConfiguration(clusterSpec);

        String instanceName = conf.getString(AccumuloConstants.PROP_ACCUMULO_INSTANCE_NAME,
                AccumuloConstants.INSTANCE_NAME);
        String rootPassword = conf.getString(AccumuloConstants.PROP_ACCUMULO_ROOT_PASSWORD,
                AccumuloConstants.ROOT_PASSWORD);

        addStatement(event, call("retry_helpers"));
        addStatement(
                event,
                call(getConfigureFunction(config), AccumuloConstants.PARAM_QUORUM, zkCsv,
                        AccumuloConstants.PARAM_INSTANCE, instanceName, AccumuloConstants.PARAM_PASSWORD, rootPassword));
    }

    private List<String> getZookeepersCsv(Set<Instance> instances) {
        return Lists.transform(Lists.newArrayList(instances), new Function<Instance, String>() {
            @Override
            public String apply(Instance instance) {
                return instance.getPrivateIp();
            }
        });
    }
}
