# frozen_string_literal: true

require 'dry-validation'
require 'config'

Dir.glob("#{__dir__}/patches/**/*.rb").each do |override|
  require override
end

Dir.glob("#{__dir__}/initializers/**/*.rb").each do |file|
  require file
end

# A module for app wide constants or defs.
module BawApp
  # makes module methods 'static'

  module_function

  # Returns the root path of the app. Similar to Rails.root but does not depend
  # on Rails being defined.
  # @returns [Pathname] - for the root of the application
  def root
    @root ||= Pathname.new("#{__dir__}/../../../..").cleanpath
  end

  # Returns the path to the tmp directory.
  # @returns [Pathname] - for the tmp directory
  def tmp_dir
    @tmp_dir ||= root / 'tmp'
  end

  # Get the config folder path.
  # @return [Pathname]
  def config_root
    @config_root ||= root / 'config'
  end

  # Get the current application environment as defined by RAILS_ENV or RACK_ENV.
  # @return [ActiveSupport::StringInquirer]
  def env
    return Rails.env if defined?(Rails) && defined?(Rails.env)

    # https://github.com/rails/rails/blob/1ccc407e9dc95bda4d404c192bbb9ce2b8bb7424/railties/lib/rails.rb#L67
    @env ||= ActiveSupport::StringInquirer.new(
      ENV['RAILS_ENV'].presence || ENV['RACK_ENV'].presence || 'development'
    )
  end

  # Get the path to the default config files that will be loaded by the app
  def config_files(config_root = self.config_root, env = self.env)
    [
      config_root / 'settings.yml',
      config_root / 'settings' / 'default.yml',
      config_root / 'settings' / "#{env}.yml",
      *@custom_configs
    ].map(&:to_s).freeze
  end

  def custom_configs=(value)
    raise ArgumentError, 'Not an array' unless value.is_a?(Array)

    @custom_configs = value.map { |file|
      next file if File.exist?(file)

      raise ArgumentError, "The settings must exist and yet the file could not be found: #{file}"
    }
  end

  # are we in the development environment?
  # @return [Boolean]
  def development?
    env == 'development'
  end

  def rspec?
    ENV.key?('RUNNING_RSPEC')
  end

  # are we in the test environment?
  # @return [Boolean]
  def test?
    rspec? || env == 'test'
  end

  # Returns true if environment is development? or test?
  # @return [Boolean]
  def dev_or_test?
    development? || test?
  end

  def log_to_stdout?
    return false if rspec?

    env_value = ActiveModel::Type::Boolean.new.cast(ENV['RAILS_LOG_TO_STDOUT'])
    return env_value unless env_value.nil?

    return true if development?
    return true if test?

    # container application by default, should log to std out
    true
  end

  def log_level(default = Logger::DEBUG)
    # The default Rails log level is warn in production env and info in any other env.
    return ENV['RAILS_LOG_LEVEL'] if ENV.key?('RAILS_LOG_LEVEL')
    return Logger::INFO if Rails.env.staging?
    return Logger::INFO if Rails.env.production?

    default
  end

  def http_scheme
    @http_scheme ||= BawApp.dev_or_test? ? 'http' : 'https'
  end

  def attachment_size_limit
    10.megabytes
  end

  def attachment_thumb_size
    [512, 512]
  end

  # add custom configs before other things start
  def setup(configs = nil)
    return if @setup

    @setup = true

    @custom_configs = configs || []
  end
end
