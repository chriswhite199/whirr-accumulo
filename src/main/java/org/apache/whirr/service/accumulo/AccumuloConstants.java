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

public final class AccumuloConstants {
    public static final String ACCUMULO_TARBALL_URL = "whirr.accumulo.tarball.url";
    public static final String ZK_TARBALL_URL = "whirr.zookeeper.tarball.url";

    public static final String FUNCTION_INSTALL = "install_accumulo";
    public static final String FUNCTION_CONFIGURE = "configure_accumulo";
    public static final String FUNCTION_START = "start_accumulo";

    public static final String PARAM_QUORUM = "-q";
    public static final String PARAM_INSTANCE = "-n";
    public static final String PARAM_IP = "-i";
    public static final String PARAM_PASSWORD = "-p";
    public static final String PARAM_ACC_TARBALL_URL = "-u";
    public static final String PARAM_ZK_TARBALL_URL = "-z";
    public static final String PARAM_MASTER = "-m";

    public static final String PROP_ACCUMULO_ZOOKEEPER_QUORUM = "accumulo.zookeeper.quorum";
    public static final String PROP_ACCUMULO_ZOOKEEPER_CLIENTPORT = "accumulo.zookeeper.property.clientPort";

    public static final String FILE_ACCUMULO_SITE_XML = "accumulo-site.xml";
    public static final String FILE_ACCUMULO_DEFAULT_PROPERTIES = "whirr-accumulo-default.properties";

    public static final String INSTANCE_NAME = "accumulo";
    public static final String ROOT_PASSWORD = "password";

    public static final String PROP_ACCUMULO_INSTANCE_NAME = "accumulo.instance.name";
    public static final String PROP_ACCUMULO_ROOT_PASSWORD = "accumulo.root.password";

    public static final String PROP_ACCUMULO_PORT_MASTER = "accumulo-site.master.port.client";
    public static final int DEFAULT_ACCUMULO_PORT_MASTER = 9999;
    public static final String PROP_ACCUMULO_PORT_TSERVER = "accumulo-site.tserver.port.client";
    public static final int DEFAULT_ACCUMULO_PORT_TSERVER = 9997;
    public static final String PROP_ACCUMULO_PORT_GC = "accumulo-site.gc.port.client";
    public static final int DEFAULT_ACCUMULO_PORT_GC = 50091;
    public static final String PROP_ACCUMULO_PORT_MONITOR = "accumulo-site.monitor.port.client";
    public static final int DEFAULT_ACCUMULO_PORT_MONITOR = 50095;
    public static final String PROP_ACCUMULO_PORT_TRACER = "accumulo-site.tracer.port.client";
    public static final int DEFAULT_ACCUMULO_PORT_TRACER = 12234;

    private AccumuloConstants() {
    }
}
