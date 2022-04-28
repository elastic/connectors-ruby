module ConnectorsSdk
  module Helpers
    module AtlassianTimeFormatter
      def format_time(time)
        time = Time.parse(time) if time.is_a?(String)
        time.strftime('%Y-%m-%d %H:%M')
      end
    end
  end
end
