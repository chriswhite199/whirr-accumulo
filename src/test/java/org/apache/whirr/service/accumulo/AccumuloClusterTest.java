package org.apache.whirr.service.accumulo;

import java.io.File;
import java.io.PrintStream;
import java.util.Map.Entry;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;

import org.apache.commons.lang.builder.ToStringBuilder;
import org.apache.whirr.ClusterSpec;
import org.apache.whirr.service.BaseServiceDryRunTest;
import org.apache.whirr.service.DryRunModule.DryRun;
import org.jclouds.compute.domain.NodeMetadata;
import org.jclouds.scriptbuilder.domain.OsFamily;
import org.jclouds.scriptbuilder.domain.Statement;
import org.junit.Test;

import com.google.common.base.Predicate;
import com.google.common.collect.ImmutableMap;
import com.google.common.collect.ImmutableSet;

public class AccumuloClusterTest extends BaseServiceDryRunTest {
    @Test
    @Override
    public void testBootstrapAndConfigure() throws Exception {
        // override the default behaviour to create some scripts which we can
        // run on docker containers

        ClusterSpec cookbookWithDefaultRecipe = newClusterSpecForProperties(ImmutableMap.of("whirr.instance-templates",
                "1 hadoop-namenode+hadoop-jobtracker+zookeeper, 1 hadoop-datanode+hadoop-tasktracker",
                "whirr.hadoop.version", "1.2.1"));
        DryRun dryRun = launchWithClusterSpec(cookbookWithDefaultRecipe);

        File tgtDir = new File("target");
        TreeMap<String, String> nodePropMap = new TreeMap<String, String>();

        Set<String> nodes = new TreeSet<String>();
        int n = -1;
        int i = 0;
        for (Entry<NodeMetadata, Statement> exe : dryRun.getExecutions().entries()) {
            NodeMetadata nodeMeta = exe.getKey();
            System.err.println(ToStringBuilder.reflectionToString(exe.getKey()));
            if (!nodes.contains(nodeMeta.getName())) {
                i = 0;
                n++;
                nodes.add(nodeMeta.getName());
            }

            String filename = String.format("%s-%s-%d.sh", nodeMeta.getPrivateAddresses().iterator().next(), nodeMeta
                    .getPublicAddresses().iterator().next(), i);
            PrintStream ps = new PrintStream(new File(tgtDir, filename));
            ps.println(exe.getValue().render(OsFamily.UNIX));
            ps.close();
            // System.err.println("\t" + exe.getValue().render(OsFamily.UNIX));

            i++;

            nodePropMap.put(String.format("%d\tPUBLIC_IP", n), nodeMeta.getPublicAddresses().iterator()
                    .next());
            nodePropMap.put(String.format("%d\tPRIVATE_IP", n), nodeMeta.getPrivateAddresses().iterator()
                    .next());
            nodePropMap.put(String.format("%d\tHOSTNAME", n), nodeMeta.getName());
            nodePropMap.put(String.format("%d\tSCRIPTS", n), String.valueOf(i));
        }

        nodePropMap.put("NODES", String.valueOf(nodes.size()));

        // write jclouds assigned properties to file so we can update with the
        // actual ones assigned to each docker container
        File propFile = new File(tgtDir, "cluster.properties");
        PrintStream ps = new PrintStream(propFile);
        for (Entry<String, String> entry : nodePropMap.entrySet()) {
            ps.println(entry.getKey() + "\t" + entry.getValue());
        }
        ps.close();
    }

    @Override
    protected Predicate<CharSequence> bootstrapPredicate() {
        // TODO Auto-generated method stub
        return new Predicate<CharSequence>() {
            @Override
            public boolean apply(CharSequence arg0) {
                return true;
            }
        };
    }

    @Override
    protected Predicate<CharSequence> configurePredicate() {
        // TODO Auto-generated method stub
        return new Predicate<CharSequence>() {
            @Override
            public boolean apply(CharSequence arg0) {
                return true;
            }
        };
    }

    @Override
    protected Set<String> getInstanceRoles() {
        return ImmutableSet.of("accumulo-master");
    }
}
