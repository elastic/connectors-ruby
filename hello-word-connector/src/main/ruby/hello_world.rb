require 'java'
java_package 'co.elastic.enterprise.search.hello.world'
class HelloWorld
  def fetch_documents
    {
      :title => 'Traditional Test',
      :body => 'Hello, world'
    }
  end
end