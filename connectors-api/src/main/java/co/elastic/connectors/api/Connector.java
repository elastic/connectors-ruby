/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
 * or more contributor license agreements. Licensed under the Elastic License;
 * you may not use this file except in compliance with the Elastic License.
 */

package co.elastic.connectors.api;

import java.util.List;
import java.util.Map;

public interface Connector {
    public List<Map<String, String>> fetchDocuments();
}
