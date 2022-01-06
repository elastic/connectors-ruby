/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License;
 * you may not use this file except in compliance with the Elastic License.
 */

import co.elastic.connectors.api.Connector;

module example.consumer {
    requires org.jruby.complete;
    requires transitive hello.world.connector;
    uses Connector;
}
