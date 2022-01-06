/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License;
 * you may not use this file except in compliance with the Elastic License.
 */

open module connectors.api {
    uses co.elastic.connectors.api.Connector;
    requires java.desktop;
    requires org.jruby.complete;
    exports co.elastic.connectors.api;
}