package co.elastic.connectors.example.consumer;

import co.elastic.connectors.api.Connector;
import co.elastic.connectors.api.ConnectorFactory;

public class ExampleConsumer {

    public void doThing(){
        Connector connector = ConnectorFactory.getConnectors().next();
        connector.fetchDocuments();
    }
}
