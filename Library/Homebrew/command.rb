module Homebrew
  class Command
    attr_reader :command_name, :valid_options, :description, :help_output,
      :man_output

    def initialize_variables
      @valid_options = []
      @root_options = []
      @argv = ARGV.dup
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

    def add_valid_option(option_hash)
      @valid_options.push(option_hash)
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
      add_valid_option(option_hash)
      return unless block_given?
      old_parent = @parent
      @parent = option_name
      instance_eval(&block)
      @parent = old_parent
    end

    def desc(desc)
      if @description.nil?
        @description = desc
      else
        @description = <<-EOS.undent
          #{@description}
          #{desc}
        EOS
                             .strip
      end
    end

    def argv_invalid_options_passed(argv)
      argv_options_only = argv.select { |arg| /^--/ =~ arg }
      argv_options_only = argv_options_only.uniq
      valid_option_names =
        @valid_options
        .map { |option_hash| option_hash[:option] }

      argv_options_only
        .reject { |opt| valid_option_names.include?(opt.split("=", 2)[0]) }
        .map { |opt| opt.split("=", 2)[0] }
    end

    def get_error_message(argv)
      argv_invalid_options = argv_invalid_options_passed(argv)
      return if argv_invalid_options.empty?
      invalid_opt_str = Formatter.pluralize(argv_invalid_options.length, "invalid option")
      invalid_opt_str = "#{invalid_opt_str} provided: #{argv_invalid_options.join " "}"
      <<-EOS.undent
        #{invalid_opt_str unless argv_invalid_options.empty?}
      EOS
    end

    def check_for_errors
      error_message = get_error_message(@argv)
      return if error_message.nil?
      generate_help_and_manpage_output
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
        output = output.gsub(/`#{option}`/, "`#{option}` #{childs_str}")
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
