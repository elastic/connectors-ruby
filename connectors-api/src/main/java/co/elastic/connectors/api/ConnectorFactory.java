package co.elastic.connectors.api;

import java.util.Iterator;
import java.util.ServiceLoader;

public class ConnectorFactory {

    public static Iterator<Connector> getConnectors(){
        Iterable<Connector> services = ServiceLoader.load(Connector.class);
        return services.iterator();
    }
}
