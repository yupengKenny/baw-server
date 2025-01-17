# frozen_string_literal: true

# @!parse
#   Settings = BawWorkers::Settings

# settings loaded in config/initializers/config.rb
# Accessible through Settings.xxx
# Environment specific settings expected in config/settings/{environment_name}.yml
module BawWeb
  module Settings
    MEDIA_PROCESSOR_LOCAL = 'local'
    MEDIA_PROCESSOR_RESQUE = 'resque'
    BAW_SERVER_VERSION_KEY = 'BAW_SERVER_VERSION'

    def sources
      @config_sources.map { |s| s.instance_of?(Config::Sources::YAMLSource) ? s.path : s }
    end

    # Create or return an existing Api::Response.
    # @return [Api::Response]
    def api_response
      @api_response ||= Api::Response.new
    end

    # Create or return an existing RangeRequest.
    # @return [RangeRequest]
    def range_request
      @range_request ||= RangeRequest.new
    end

    def version_info
      return @version_info unless @version_info.nil?

      version = ENV.fetch(BAW_SERVER_VERSION_KEY, nil)
      version = File.read(Rails.root / 'VERSION').strip if version.blank?
      segments = /v?(\d+)\.(\d+)\.(\d+)(?:-(\d+)-g([a-f0-9]+))?/.match(version)
      @version_info = {
        major: segments&.[](1).to_s,
        minor: segments&.[](2).to_s,
        patch: segments&.[](3).to_s,
        pre: segments&.[](4).to_s,
        build: segments&.[](5).to_s
      }
      @version_info
    end

    def version_string
      info = version_info
      version = "#{info[:major]}.#{info[:minor]}.#{info[:patch]}"

      version += "-#{info[:pre]}" unless info[:pre].blank?

      version += "+#{info[:build]}" unless info[:build].blank?

      version
    end

    # Get the supported media types.
    # @return [Hash]
    def supported_media_types
      if @media_types.blank?
        @media_types = {}

        available_formats.each do |key, value|
          media_category = key.to_sym
          @media_types[media_category] = []

          value.each do |media_type|
            ext = media_type.downcase.trim('.', '')
            mime_type = Mime::Type.lookup_by_extension(ext)
            @media_types[media_category].push mime_type unless mime_type.blank?
          end
          #@media_types[media_category].sort { |a, b| a.to_s <=> b.to_s }
        end
      end

      @media_types
    end

    def is_supported_text_media?(requested_format)
      supported_media_types[:text].include?(requested_format)
    end

    def is_supported_audio_media?(requested_format)
      supported_media_types[:audio].include?(requested_format)
    end

    def is_supported_image_media?(requested_format)
      supported_media_types[:image].include?(requested_format)
    end

    def media_category(requested_format)
      if is_supported_text_media?(requested_format)
        [:text, {}]
      elsif is_supported_audio_media?(requested_format)
        [:audio, cached_audio_defaults]
      elsif is_supported_image_media?(requested_format)
        [:image, cached_spectrogram_defaults]
      else
        [:unknown, {}]
      end
    end

    def process_media_locally?
      media_request_processor == MEDIA_PROCESSOR_LOCAL
    end

    def process_media_resque?
      media_request_processor == MEDIA_PROCESSOR_RESQUE
    end

    def min_duration_larger_overlap?
      audio_recording_max_overlap_sec >= audio_recording_min_duration_sec
    end

    def queue_names
      @queue_names ||= resque.queues_to_process
    end

    def queue_to_process_includes?(name)
      queue_names.include?(name) || queue_names.include?('*')
    end
  end
end
