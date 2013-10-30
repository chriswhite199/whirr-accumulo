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
import org.apache.whirr.service.ClusterActionHandlerSupport;
import org.apache.whirr.service.FirewallManager.Rule;
import org.apache.whirr.service.zookeeper.ZooKeeperClusterActionHandler;
import org.jclouds.scriptbuilder.domain.Statement;

import com.google.common.base.Function;
import com.google.common.base.Joiner;
import com.google.common.collect.Lists;

/**
 * Base class for Accumulo service handlers - implementation heavily borrowed
 * from the HBase service
 */
public abstract class AccumuloClusterActionHandler extends ClusterActionHandlerSupport {
    /**
     * Returns a composite configuration that is made up from the global
     * configuration coming from the Whirr core with an Accumulo defaults
     * properties.
     */
    protected synchronized Configuration getConfiguration(ClusterSpec clusterSpec) throws IOException {
        return getConfiguration(clusterSpec, AccumuloConstants.FILE_ACCUMULO_DEFAULT_PROPERTIES);
    }

    protected String getInstallFunction(Configuration config) {
        return getInstallFunction(config, "accumulo", AccumuloConstants.FUNCTION_INSTALL);
    }

    protected String getConfigureFunction(Configuration config) {
        return getConfigureFunction(config, "accumulo", AccumuloConstants.FUNCTION_CONFIGURE);
    }

    protected String getStartFunction(Configuration config) {
        return getStartFunction(config, "accumulo", AccumuloConstants.FUNCTION_START);
    }

    protected List<String> getZookeepersCsv(Set<Instance> instances) {
        return Lists.transform(Lists.newArrayList(instances), new Function<Instance, String>() {
            @Override
            public String apply(Instance instance) {
                return instance.getPrivateIp();
            }
        });
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

        // add some service firewall holes - these may need to be pushed down to the subclasses
        event.getFirewallManager().addRule(
                Rule.create()
                        .destination(role(AccumuloMasterClusterActionHandler.ROLE))
                        .port(conf.getInt(AccumuloConstants.PROP_ACCUMULO_PORT_MASTER,
                                AccumuloConstants.DEFAULT_ACCUMULO_PORT_MASTER)));
        event.getFirewallManager().addRule(
                Rule.create()
                        .destination(role(AccumuloTabletServerClusterActionHandler.ROLE))
                        .port(conf.getInt(AccumuloConstants.PROP_ACCUMULO_PORT_TSERVER,
                                AccumuloConstants.DEFAULT_ACCUMULO_PORT_TSERVER)));
        event.getFirewallManager().addRule(
                Rule.create()
                        .destination(role(AccumuloGCClusterActionHandler.ROLE))
                        .port(conf.getInt(AccumuloConstants.PROP_ACCUMULO_PORT_GC,
                                AccumuloConstants.DEFAULT_ACCUMULO_PORT_GC)));
        event.getFirewallManager().addRule(
                Rule.create()
                        .destination(role(AccumuloMonitorClusterActionHandler.ROLE))
                        .port(conf.getInt(AccumuloConstants.PROP_ACCUMULO_PORT_MONITOR,
                                AccumuloConstants.DEFAULT_ACCUMULO_PORT_MONITOR)));
        event.getFirewallManager().addRule(
                Rule.create()
                        .destination(role(AccumuloTracerClusterActionHandler.ROLE))
                        .port(conf.getInt(AccumuloConstants.PROP_ACCUMULO_PORT_TRACER,
                                AccumuloConstants.DEFAULT_ACCUMULO_PORT_TRACER)));

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

        addStatement(event, call("retry_helpers"));
        addStatement(event,
                call(getConfigureFunction(conf), Joiner.on(",").join(event.getInstanceTemplate().getRoles())));
    }

    @Override
    protected void beforeStart(ClusterActionEvent event) throws IOException, InterruptedException {
        ClusterSpec clusterSpec = event.getClusterSpec();
        Configuration conf = getConfiguration(clusterSpec);

        addStatement(event, call("retry_helpers"));
        addStatement(event, call("configure_hostnames"));

        String instanceName = conf.getString(AccumuloConstants.PROP_ACCUMULO_INSTANCE_NAME,
                AccumuloConstants.INSTANCE_NAME);
        String rootPassword = conf.getString(AccumuloConstants.PROP_ACCUMULO_ROOT_PASSWORD,
                AccumuloConstants.ROOT_PASSWORD);

        addStatement(
                event,
                call(getStartFunction(conf), Joiner.on(",").join(event.getInstanceTemplate().getRoles()),
                        AccumuloConstants.PARAM_INSTANCE, instanceName, AccumuloConstants.PARAM_PASSWORD, rootPassword));
    }
}
