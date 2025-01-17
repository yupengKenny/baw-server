# frozen_string_literal: true

Dir.glob("#{__dir__}/patches/**/*.rb").each do |override|
  #puts "loading #{override}"
  require override
end

require 'zeitwerk'

Zeitwerk::Loader.new.tap do |loader|
  loader.tag = 'emu'
  base_dir = __dir__
  loader.push_dir(base_dir)
  loader.ignore("#{base_dir}/patches")
  # loader.inflector.inflect {
  # 'io' => 'IO'
  # }

  loader.enable_reloading if BawApp.dev_or_test?
  #loader.log! # debug only!
  loader.setup # ready!
end

require 'semantic_logger'
require 'deep_sort'

# A module for dealing with ecoacoustic metadata.
module Emu
  include SemanticLogger::Loggable

  # When the module is loaded check the tool exists and is executable
  EXE_PATH = Pathname.new('/emu/emu')

  raise IOError, 'Cannot find the emu binary' unless EXE_PATH.exist?

  raise IOError, 'emu binary does not have execute permission' unless EXE_PATH.executable?

  module_function

  def version
    result = execute('version')

    return result.records.first[:version] if result.success?

    nil
  end

  #
  # @param [Array<String>] args
  # @return [ExecuteResult]
  #
  def execute(*args)
    all_args = [
      EXE_PATH.to_path,
      '--format',
      'jsonl',
      *args.map(&:to_s)
    ]

    output, error, status = nil
    time = Benchmark.measure do
      output, error, status = Open3.capture3(*all_args)
    end

    status&.exitstatus => exit_code
    success = exit_code.zero?

    # split output by line
    records = output
              .split("\n")
              .map(&method(:parse_record))

    logger.debug('Ran emu executable', command: all_args.join(' '), status: status, log: error, time_taken: time.total)

    ExecuteResult.new(
      success: success,
      records: records,
      log: error,
      time_taken: time.total
    )
  rescue StandardError => e
    logger.error(
      'error occurred while invoking emu',
      command: all_args.join(' '),
      status: status,
      log: error,
      time_taken: time.total,
      output: output,
      exception: e
    )
    raise
  end

  # @return [Emu::JsonAdapter]
  def parser
    @parser ||= JsonAdapter.new
  end

  #
  # Convert a string from EMU into a hash.
  #
  # @param [string] string The JSON
  #
  # @return [HashWithIndifferentAccess] The parsed result
  #
  def parse_record(string)
    parser.call(string)
  end
end
