/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License;
 * you may not use this file except in compliance with the Elastic License.
 */

package co.elastic.connectors.api;

import java.util.Iterator;
import java.util.ServiceLoader;

public class ConnectorFactory {

    public static Iterator<Connector> getConnectors(){
        Iterable<Connector> services = ServiceLoader.load(Connector.class);
        return services.iterator();
    }
}
