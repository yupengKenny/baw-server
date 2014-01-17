require 'logger'

module MediaTools
  class AudioShntool
    include Logging

    def initialize(shntool_executable, temp_dir)
      @shntool_executable = shntool_executable
      @temp_dir = temp_dir
    end

    def info_command(source)
      # sox std out contains info
      "#{@shntool_executable} info \"#{source}\""
    end

    def parse_info_output(output)
      # contains key value output (separate on first colon(:))
      result = {}
      output.strip.split(/\r?\n|\r/).each { |line|
        if line.include?(':')
          colon_index = line.index(':')
          new_value = line[colon_index+1, line.length].strip
          new_key = line[0, colon_index].strip
          result[new_key] = new_value
        end
      }

      result
    end

    def modify_command(source, target, start_offset = nil, end_offset = nil)
      #cmd_offsets = arg_offsets(start_offset, end_offset)

      #-O val Overwrite existing files?  val is one of: {ask, always,  never}. The default is ask.
      #-a str Prefix str to base part of output filenames
      #-d dir Specify output directory
      #-n fmt Specifies  the  file  count output format.  The default is %02d, which gives two-digit zero-padded numbers (01, 02, 03, ...).
      "#{@shntool_executable} split -O never -a \"#{File.dirname(target)}\" -d #{File.basename(target)} -n \"\" \"#{source}\" \"#{target}\" "
    end

    def arg_offsets(start_offset, end_offset)
      cmd_arg = ''

      unless start_offset.blank?
        start_offset_formatted = Time.at(start_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        cmd_arg += "trim =#{start_offset_formatted}"
      end

      unless end_offset.blank?
        end_offset_formatted = Time.at(end_offset.to_f).utc.strftime('%H:%M:%S.%2N')
        if start_offset.blank?
          # if start offset was not included, include audio from the start of the file.
          cmd_arg += "trim 0 #{end_offset_formatted}"
        else
          cmd_arg += " =#{end_offset_formatted}"
        end
      end

      cmd_arg
    end

  end
end
