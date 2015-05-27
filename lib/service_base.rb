require 'service_base/version'
require 'service_base/engine' if defined?(::Rails)
require 'active_support/all'
require 'bunny'

module ServiceBase
	autoload :RabbitConnection, 'service_base/rabbit_connection'
	autoload :Configuration, 'service_base/configuration'
	autoload :Application, 'service_base/application'
	autoload :Middleware, 'service_base/application'
	autoload :BaseController, 'service_base/base_controller'
	autoload :BaseClient, 'service_base/base_client'
	autoload :ControllerManager, 'service_base/controller_manager'
	autoload :Message, 'service_base/message'
	autoload :MessageMap, 'service_base/message_map'
	autoload :ReplyQueue, 'service_base/reply_queue'
	autoload :RabbitClient, 'service_base/rabbit_client'
	autoload :Test, 'service_base/test'
	autoload :ServiceCache, 'service_base/service_cache'
	autoload :ActiveRecordConnectionCleaner, 'service_base/active_record_connection_cleaner'

	class InvalidMessageError < StandardError
		def initialize(message, service_message)
			super(message)
			@service_message = service_message
		end
	end

	class << self
		# Global logger for services (default: RAILS_ROOT/log/service.log)
		attr_writer :logger

		# If set to true bunny log level would be set to DEBUG (by default it is WARN)
		attr_accessor :debug_bunny

		def logger
			unless @logger
				raise "ServiceBase.logger not set." unless defined?(Rails)
				@logger = Logger.new(File.join(Rails.root, 'log/service.log'))
				@logger.level = Rails.env.production? ? Logger::WARN : Logger::DEBUG
			end
			@logger
		end

		def application
			unless @application
				@application = ServiceBase::Application.new
				@application.use_default_middlewares
			end
			@application
		end

		# Should be invoked only once
		def load_services
			eager_load_service_messages
			eager_load_service_controllers
		end

		def start_services(rabbit_config=nil, logger=nil)
			ControllerManager.start(rabbit_config, logger)
			true
		rescue
			if logger
				logger.error "Error during service start"
				logger.error "#{$!.class}: #{$!}"
				logger.error $!.backtrace.join("\n")
			end
			false
		end

		def stop_services(logger=nil)
			ControllerManager.stop
			true
		rescue
			if logger
				logger.error "Error during service stop"
				logger.error "#{$!.class}: #{$!}"
				logger.error $!.backtrace.join("\n")
			end
			false
		end

		def services_running?
			ControllerManager.running?
		end

		def restart_services(rabbit_config=nil, logger=nil)
			ControllerManager.stop if ControllerManager.running?
			ControllerManager.start(rabbit_config, logger)
			true
		rescue
			if logger
				logger.error "Error during service restart"
				logger.error "#{$!.class}: #{$!}"
				logger.error $!.backtrace.join("\n")
			end
			false
		end

		def eager_load_service_messages
			existent_engine_paths('messages').each do |load_path|
				Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
					require file
				end
			end
		end

		def eager_load_service_controllers
			existent_engine_paths('controllers').each do |load_path|
				Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
					require file
				end
			end
		end

		def existent_engine_paths(type)
			engines = ::Rails::Engine.subclasses.map(&:instance)
			engines += [ Rails.application ]
			engines.collect do |railtie|
				railtie.paths["service/#{type}"].try(:existent)
			end.compact.flatten
		end
	end
end
