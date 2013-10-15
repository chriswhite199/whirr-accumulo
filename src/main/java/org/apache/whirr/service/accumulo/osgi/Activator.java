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

package org.apache.whirr.service.accumulo.osgi;

import java.util.Properties;

import org.apache.whirr.service.ClusterActionHandler;
import org.apache.whirr.service.accumulo.AccumuloMasterClusterActionHandler;
import org.jclouds.scriptbuilder.functionloader.osgi.BundleFunctionLoader;
import org.osgi.framework.BundleActivator;
import org.osgi.framework.BundleContext;
import org.osgi.framework.ServiceRegistration;

public class Activator implements BundleActivator {
    private BundleFunctionLoader functionLoader;

    private final ClusterActionHandler masterClusterActionHandler = new AccumuloMasterClusterActionHandler();
    private ServiceRegistration masterRegistration;

    /**
     * Called when this bundle is started so the Framework can perform the
     * bundle-specific activities necessary to start this bundle. This method
     * can be used to register services or to allocate any resources that this
     * bundle needs.
     * <p/>
     * <p/>
     * This method must complete and return to its caller in a timely manner.
     * 
     * @param context
     *            The execution context of the bundle being started.
     * @throws Exception
     *             If this method throws an exception, this bundle is marked as
     *             stopped and the Framework will remove this bundle's
     *             listeners, unregister all services registered by this bundle,
     *             and release all services used by this bundle.
     */
    @Override
    public void start(BundleContext context) throws Exception {
        // Initialize OSGi based FunctionLoader
        functionLoader = new BundleFunctionLoader(context);
        functionLoader.start();

        Properties masterProps = new Properties();
        masterProps.put("name", "accumulo-master");
        masterRegistration = context.registerService(ClusterActionHandler.class.getName(), masterClusterActionHandler,
                masterProps);
    }

    @Override
    public void stop(BundleContext context) throws Exception {
        if (masterRegistration != null) {
            masterRegistration.unregister();
        }

        if (functionLoader != null) {
            functionLoader.stop();
        }
    }
}
