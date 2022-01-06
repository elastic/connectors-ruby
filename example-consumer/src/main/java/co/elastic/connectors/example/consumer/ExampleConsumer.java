/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License;
 * you may not use this file except in compliance with the Elastic License.
 */

package co.elastic.connectors.example.consumer;

import co.elastic.connectors.api.Connector;
import co.elastic.connectors.api.ConnectorFactory;

public class ExampleConsumer {

    public void doThing(){
        Connector connector = ConnectorFactory.getConnectors().next();
        connector.fetchDocuments();
    }
}
