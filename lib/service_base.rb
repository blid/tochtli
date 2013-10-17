require 'service_base/engine'

module ServiceBase
	autoload :RabbitConnection, 'service_base/rabbit_connection'
	autoload :Configuration, 'service_base/configuration'
	autoload :BaseController, 'service_base/base_controller'
	autoload :ControllerManager, 'service_base/controller_manager'
	autoload :Message, 'service_base/message'
	autoload :MessageMap, 'service_base/message_map'
	autoload :ReplyQueue, 'service_base/reply_queue'
	autoload :RabbitClient, 'service_base/rabbit_client'
	autoload :Test, 'service_base/test'

	def self.start_services(rabbit_config=nil, logger=nil)
		preload_service_messages
		preload_service_controllers
		ControllerManager.start(rabbit_config, logger)
	rescue
		if logger
			logger.error "Error during service start"
			logger.error "#{$!.class}: #{$!}"
			logger.error $!.backtrace.join("\n")
		end
		raise
	end

	def self.preload_service_messages
		Rails::Engine::Railties.engines.each do |engine|
			next unless engine.paths["service/messages"]
			engine.paths["service/messages"].existent.each do |load_path|
				Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
					require file
				end
			end
		end
	end

	def self.preload_service_controllers
		Rails::Engine::Railties.engines.each do |engine|
			next unless engine.paths["service/controllers"]
			engine.paths["service/controllers"].existent.each do |load_path|
				Dir.glob("#{load_path}/**/*.rb").sort.each do |file|
					require file
				end
			end
		end
	end
end
