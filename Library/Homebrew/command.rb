module Homebrew
  class Command
    attr_reader :command_name, :valid_options, :description, :help_output,
      :man_output

    def initialize_variables
      @valid_options = []
      @root_options = []
      @argv = ARGV.dup.uniq
    end

    def options(&block)
      initialize_variables
      @parent = nil
      instance_eval(&block)
      generate_help_and_manpage_output
    end

    def cmd_name(cmd)
      @command_name = cmd
    end

    def option(*args, **option_hash, &block)
      option_hash[:option] = "--#{args[0]}"
      option_name = option_hash[:option]
      if @parent.nil?
        @root_options.push(option_name)
      else
        hash = @valid_options.find { |x| x[:option] == @parent }
        if hash[:child_options].nil?
          hash[:child_options] = [option_name]
        else
          hash[:child_options].push(option_name)
        end
      end
      @valid_options.push(option_hash)
      return unless block_given?
      old_parent = @parent
      @parent = option_name
      instance_eval(&block)
      @parent = old_parent
    end

    def desc(desc)
      @description = desc
    end

    def get_error_message(argv)
      invalid_options =
        argv.select { |arg| /^--/ =~ arg }
            .reject { |opt| @valid_options.map { |h| h[:option] }.include?(opt) }
      return if invalid_options.empty?
      "Invalid option(s) provided: #{invalid_options.join " "}"
    end

    def check_for_errors
      error_message = get_error_message(@argv)
      return if error_message.nil?
      odie <<-EOS.undent
        #{error_message}
        Correct usage:
        #{@help_output}
      EOS
    end

    def option_string(option)
      hash = @valid_options.find { |x| x[:option] == option }
      child_options = hash[:child_options]
      output = "[`#{option}`]"
      if child_options
        childs_str = child_options.map do |co|
          option_string(co)
        end.join(" ")
        output = output.gsub(/`#{option}`/, "\\0 #{childs_str}")
      end
      output
    end

    def desc_string(option, parent_present = false)
      hash = @valid_options.find { |x| x[:option] == option }
      desc = hash[:desc]
      child_options = hash[:child_options]

      output = <<-EOS.undent
        `#{option}`, #{desc}
      EOS
      if parent_present
        output = output.gsub(/`#{option}`/, 'With \\0')
      else
        output = output.gsub(/`#{option}`/, 'If \\0 is passed')
      end
      unless child_options.nil?
        childs_str = child_options.map do |co|
          desc_string(co, true)
        end.join("\s\s\s\s")
        output = <<-EOS.undent
          #{output}\s\s\s\s#{childs_str}
        EOS
                       .chop
      end
      output
    end

    def generate_help_and_manpage_output
      option_str = @root_options.map do |ro|
        option_string(ro)
      end.join(" ").gsub(/\s+/, " ")
      desc_str = @root_options.map do |ro|
        desc_string(ro)
      end.join("\n\s\s\s\s")

      help_lines = "\s\s" + <<-EOS.undent
        * `#{@command_name}` #{option_str}:
            #{@description}

            #{desc_str}
      EOS
                                  .chop
      @man_output = help_lines
      help_lines = help_lines.split("\n")
      help_lines.map! do |line|
        line
          .sub(/^  \* /, "#{Tty.bold}brew#{Tty.reset} ")
          .gsub(/`(.*?)`/, "#{Tty.bold}\\1#{Tty.reset}")
          .gsub(/<(.*?)>/, "#{Tty.underline}\\1#{Tty.reset}")
      end
      @help_output = help_lines.join("\n")
    end
  end
end
