# Connectors
The new home of Elastic Connectors


### Building
run `./mvnw clean install`

### Generating Java from Ruby
This project uses Ruby source files (for historical reasons), and generates java code from them. To generate the code,
the Maven Exec Plugin is used to execute the `script/build_jruby.sh` script for a given module. As an example,
to run this goal for the `hello-world-connector`, run:

```shell
./mvnw clean exec:exec@build-ruby -pl hello-word-connector
```

The output generated Java source files can then be found in `hello-world-connector/target/generated-sources/`

### Project Structure


```
.
├── LICENSE                                                                            # License for this repo
├── NOTICE.txt.template                                                                # Used to generate legal notices
├── README.md                                                                          # This README
├── connectors-api
│         └── src/main/java/co/elastic/connectors/api/Connector.java                   # A Java interface
├── hello-world-connector
│         └── src
│             ├── main
│             │   └── ruby
│             │       └── hello_world.rb                                               # An example Ruby source file
│             └── test
│                 └── java
│                     └── co/elastic/connectors/hello/world/HelloWorldTest.groovy      # A test of the generated Java
├── pom.xml
└── script
          └── build_jruby.sh                                                           # Script that builds Jruby->Java
```
