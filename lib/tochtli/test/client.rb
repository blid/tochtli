require_relative 'test_case'

module Tochtli
  module Test
    module Client
      extend UnitTestSupport if defined?(::Test::Unit)
      include Tochtli::Test::Helpers
      
      def before_setup
        super
        @logger      = Tochtli.logger
        @client      = Tochtli::RabbitClient.new(@connection, @logger)
        @reply_queue = @client.reply_queue
      end

      def create_reply(reply_class, original_message, attributes)
        properties = TestMessageProperties.new(nil, reply_class.generate_id, original_message.id)
        reply_class.new(attributes, properties)
      end

      def handle_reply(reply_class, original_message, attributes)
        reply = create_reply(reply_class, original_message, attributes)
        @reply_queue.handle_reply reply
        reply
      end
    end
  end
end
