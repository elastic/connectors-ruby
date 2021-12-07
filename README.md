# ent-search-connectors
The new home of Enterprise Search Connectors


### Building
run `mvn clean install`

### Generating Java from Ruby
This project uses Ruby source files (for historical reasons), and generates java code from them. To generate the code,
the Maven Exec Plugin is used to execute the `script/build_jruby.sh` script for a given module. As an example,
to run this goal for the `hello-world-connector`, run:

```shell
mvn clean exec:exec@build-ruby -pl hello-word-connector
```