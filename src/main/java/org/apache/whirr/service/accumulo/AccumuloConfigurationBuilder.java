package org.apache.whirr.service.accumulo;

import java.io.IOException;

import org.apache.commons.configuration.CompositeConfiguration;
import org.apache.commons.configuration.Configuration;
import org.apache.commons.configuration.ConfigurationException;
import org.apache.commons.configuration.PropertiesConfiguration;
import org.apache.whirr.Cluster;
import org.apache.whirr.ClusterSpec;
import org.apache.whirr.service.hadoop.HadoopConfigurationConverter;
import org.apache.whirr.service.zookeeper.ZooKeeperCluster;
import org.jclouds.scriptbuilder.domain.Statement;

public class AccumuloConfigurationBuilder {
    public static Statement buildAccumuloSite(String path, ClusterSpec clusterSpec, Cluster cluster)
            throws ConfigurationException, IOException {
        Configuration config = buildAccumuloSiteConfiguration(
                clusterSpec,
                cluster,
                new PropertiesConfiguration(AccumuloConfigurationBuilder.class.getResource("/"
                        + AccumuloConstants.FILE_ACCUMULO_DEFAULT_PROPERTIES)));
        return HadoopConfigurationConverter.asCreateXmlConfigurationFileStatement(path, config);
    }

    static Configuration buildAccumuloSiteConfiguration(ClusterSpec clusterSpec, Cluster cluster, Configuration defaults)
            throws ConfigurationException, IOException {
        Configuration config = build(clusterSpec, cluster, defaults, "accumulo-site");

        config.setProperty("instance.zookeeper.host", ZooKeeperCluster.getHosts(cluster));

        return config;
    }

    public static Statement buildAccumuloEnv(String path, ClusterSpec clusterSpec, Cluster cluster)
            throws ConfigurationException, IOException {
        Configuration config = buildAccumuloEnvConfiguration(
                clusterSpec,
                cluster,
                new PropertiesConfiguration(AccumuloConfigurationBuilder.class.getResource("/"
                        + AccumuloConstants.FILE_ACCUMULO_DEFAULT_PROPERTIES)));
        return HadoopConfigurationConverter.asCreateEnvironmentVariablesFileStatement(path, config);
    }

    static Configuration buildAccumuloEnvConfiguration(ClusterSpec clusterSpec, Cluster cluster, Configuration defaults)
            throws ConfigurationException, IOException {
        Configuration config = build(clusterSpec, cluster, defaults, "accumulo-env");

        return config;
    }

    private static Configuration build(ClusterSpec clusterSpec, Cluster cluster, Configuration defaults, String prefix)
            throws ConfigurationException {
        CompositeConfiguration config = new CompositeConfiguration();
        Configuration sub = clusterSpec.getConfigurationForKeysWithPrefix(prefix);
        config.addConfiguration(sub.subset(prefix)); // remove prefix
        config.addConfiguration(defaults.subset(prefix));
        return config;
    }
}
