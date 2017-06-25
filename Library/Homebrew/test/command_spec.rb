require "command"

describe Homebrew::Command do
  it "initializes correctly" do
    command = Homebrew::Command.new
    command.initialize_variables
    expect(command.valid_options).to eq([])
  end

  it "sets @valid_options correctly" do
    command = Homebrew::Command.new
    command.initialize_variables
    command.option "bar", desc: "go to bar" do
      command.option "foo", desc: "do foo"
    end
    command.option "bar1", desc: "go to bar1"
    expect(command.valid_options).to eq [
      { option: "--bar", desc: "go to bar", child_options: ["--foo"] },
      { option: "--foo", desc: "do foo" },
      { option: "--bar1", desc: "go to bar1" },
    ]
  end

  it "sets error message correctly if only one invalid option provided" do
    command = Homebrew::Command.new
    command.initialize_variables
    command.option "bar", desc: "go to bar"
    argv_options = ["--foo"]
    error_message = command.get_error_message(argv_options)
    expect(error_message).to \
      include("1 invalid option provided: --foo")
  end

  it "sets error message correctly if more than one invalid options provided" do
    command_options = Homebrew::Command.new
    command_options.initialize_variables
    command_options.cmd_name "test_command"
    command_options.desc "This is test_command"
    command_options.option "bar", desc: "go to bar"
    command_options.option "foo", desc: "do foo"
    command_options.option "quiet", desc: "be quiet"
    argv_options = ["--bar1", "--bar2", "--bar1", "--bar", "--foo"]
    expect(command_options.get_error_message(argv_options)).to eq <<-EOS.undent
      2 invalid options provided: --bar1 --bar2
    EOS
  end

  it "produces no error message if no invalid options provided" do
    command = Homebrew::Command.new
    command.initialize_variables
    command.option "bar", desc: "go to bar"
    command.option "foo", desc: "do foo"
    command.option "quiet", desc: "be quiet"
    expect(command.get_error_message(["--quiet", "--bar"])).to eq(nil)
  end

  it "tests the option method block thoroughly" do
    command = Homebrew::Command.new
    command.initialize_variables
    command.cmd_name "test_command"
    command.desc "This is test_command"

    command.option "quiet", desc: "list only the names of commands without the header." do
      command.option "bar", desc: "go to bar" do
        command.option "foo", desc: "do foo" do
          command.option "foo child", desc: "do foo"
        end
        command.option "foo1", desc: "do foo for seconds"
      end
      command.option "include-aliases", desc: "the aliases of internal commands will be included."
    end
    command.option "quiet1", desc: "be quiet"

    command.generate_help_and_manpage_output
    expect(command.help_output).to eq <<-EOS.undent
      brew test_command [--quiet [--bar [--foo [--foo child]] [--foo1]] [--include-aliases]] [--quiet1]:
          This is test_command

          If --quiet is passed, list only the names of commands without the header.
          With --bar, go to bar
          With --foo, do foo
          With --foo child, do foo
          With --foo1, do foo for seconds
          With --include-aliases, the aliases of internal commands will be included.

          If --quiet1 is passed, be quiet
    EOS
      .slice(0..-2)
  end
end
