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

import java.io.IOException;

import org.apache.commons.configuration.Configuration;
import org.apache.whirr.service.FirewallManager;
import org.apache.whirr.service.FirewallManager.Rule;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class AccumuloMasterClusterActionHandler extends AccumuloClusterActionHandler {
    private static final Logger LOG = LoggerFactory.getLogger(AccumuloMasterClusterActionHandler.class);

    public static final String ROLE = "accumulo-master";

    @Override
    public String getRole() {
        return ROLE;
    }

    @Override
    protected void configureFirewallRules(FirewallManager firewallManager, Configuration conf) throws IOException {
        // open port for master (9999 by default)
        firewallManager.addRule(Rule
                .create()
                .destination(role(AccumuloMasterClusterActionHandler.ROLE))
                .port(conf.getInt(AccumuloConstants.PROP_ACCUMULO_PORT_MASTER,
                        AccumuloConstants.DEFAULT_ACCUMULO_PORT_MASTER)));
    }
}
