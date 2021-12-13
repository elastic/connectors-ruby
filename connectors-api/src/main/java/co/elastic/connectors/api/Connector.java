package co.elastic.connectors.api;

import java.util.List;
import java.util.Map;

public interface Connector {
    public List<Map<String, String>> fetchDocuments();
}
