module ServiceBase
	module Test
		class TestCase < ActiveSupport::TestCase

			setup do
				@connection = TestRabbitConnection.new
				@message_index = 0
			end

			def publish(message)
				@message_index += 1
				delivery_info = TestDeliveryInfo.new(message.routing_key)
				properties = TestMessageProperties.new("test.reply", @message_index)
				payload = message.to_json

				@message, @reply = nil
				@controller.cleanup

				unless @controller.process_message(delivery_info, properties, payload)
					if (reply = @connection.publications.first) && reply[:message].is_a?(ServiceBase::ErrorMessage)
						raise "Process error: #{reply[:message].message}"
					else
						raise "Message #{message.class.name} not processed by #{@controller}."
					end
				end

				reply = @connection.publications.first
				if reply && reply[:routing_key] == "test.reply" && reply[:correlation_id] == @message_index
					@connection.publications.shift
					@reply = reply[:message]
				end
			end

			def assert_published(message_class, attributes, opts={})
				timeout = attributes.delete(:timeout)
				publication = @connection.get_publication(timeout)
				assert_not_nil publication, "No message published"
				@message = publication[:message]
				assert_kind_of message_class, @message
				attributes.each do |attr_name, value|
					assert_equal value, @message.send(attr_name), "Message attribute :#{attr_name} value does not match"
				end
				@message
			end

		end

		class TestRabbitConnection
			include MonitorMixin
			attr_reader :channel, :exchange, :publications

			def initialize
				super
				@channel = TestRabbitChannel.new
				@exchange = TestRabbitExchange.new
				@publications = []
				@cv = new_cond
			end

			def publish(routing_key, message, options={})
				synchronize do
					@publications << options.merge(routing_key: routing_key, message: message)
					@cv.signal
				end
			end

			def get_publication(timeout=nil)
				synchronize do
					@cv.wait(timeout) if timeout && @publications.empty?
					@publications.shift
				end
			end

			def logger
				Logger.new(STDOUT)
			end
		end

		class TestRabbitChannel
			def queue(name, options={})
				TestQueue.new(name, options)
			end
		end

		class TestRabbitExchange
		end

		class TestQueue
			attr_reader :name, :options, :routing_key

			def initialize(name, options)
				@name = name
				@options = options
			end

			def bind(exchange, options)
				@routing_key = options[:routing_key]
			end

			def subscribe(*args)
			end
		end

		class TestDeliveryInfo
			attr_reader :routing_key, :exchange

			def initialize(routing_key, exchange='TestExchange')
				@routing_key = routing_key
				@exchange = exchange
			end

			def [](key)
				send(key)
			end
		end

		class TestMessageProperties
			attr_reader :reply_to, :message_id, :correlation_id

			def initialize(reply_to, message_id=nil, correlation_id=nil)
				@reply_to = reply_to
				@message_id = message_id
				@correlation_id = correlation_id
			end

			def [](key)
				send(key)
			end
		end

		class TestMessageHandler
			attr_reader :reply, :timeout_message

			def call(reply)
				@reply = reply
			end

			def on_timeout(original_message=nil)
				@timeout_message = original_message
			end
		end
	end
end