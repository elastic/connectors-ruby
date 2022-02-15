# Connectors
The new home of Elastic Connectors

### System Requirements
- java 11
- jruby (see [.ruby-version](.ruby-version))
- bundler 2.2.29

### Setup
1. `bundle install`

### Building
run `./mvnw clean install`

### Generating Java from Ruby
This project uses Ruby source files (for historical reasons), and generates java code from them. To generate the code,
the Maven Exec Plugin is used to execute the `script/build_jruby.sh` script for a given module. As an example,
to run this goal for the `hello-world-connector`, run:

```shell
./mvnw clean exec:exec@build-ruby -pl hello-world-connector
```

The output generated Java source files can then be found in `hello-world-connector/target/generated-sources/`


### Testing
run `./mvnw clean test`

#### Testing Ruby changes only
Sometimes, you may care less about testing all of the pieces of the project, or even about testing Java code generation
and its tests. In these instances, you can run just rspec tests for your ruby files.

```shell
./mvnw dependency:build-classpath@mvn-classpath exec:exec@test-ruby -pl hello-world-connector
```

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

### Where do I report issues with Connectors?
If something is not working as expected, please open an [issue](https://github.com/elastic/connectors/issues/new).

### Where can I go to get help?
The Workplace Search team at Elastic maintains this library and are happy to help. Try posting your question to the
[Elastic Workplace Search discuss forums](https://discuss.elastic.co/c/workplace-search). Be sure to mention that you're
using Connectors and also let us know what service type you're trying to use, and any errors/issues you are
encountering. You can also find us in the `#enterprise-workplace-search` channel of the
[Elastic Community Slack](elasticstack.slack.com).

### Contribute 🚀
We welcome contributors to the project. Before you begin, a couple notes...
* Read the [Connectors Contributor's Guide](https://github.com/elastic/connectors/blob/main/CONTRIBUTING.md).
* Prior to opening a pull request, please:
    * [Create an issue](https://github.com/elastic/connectors/issues) to discuss the scope of your proposal.
    * Sign the [Contributor License Agreement](https://www.elastic.co/contributor-agreement/). We are not asking you to
      assign copyright to us, but to give us the right to distribute your code without restriction. We ask this of all
      contributors in order to assure our users of the origin and continuing existence of the code. You only need to sign
      the CLA once.
* Please write simple code and concise documentation, when appropriate.