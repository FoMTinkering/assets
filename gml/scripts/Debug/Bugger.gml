function Bugger() constructor {
    self.cli = undefined;
    self.commands = Map();
    self.hide_ui = false;

    function add_command(command) {
        self.commands.insert(command.name, command);
        return self;
    }

    function execute_command(source) {
        try {
            if string_pos("&&", source) != 0 {
                var split = string_split(source, "&&");
                var chain = new_chain();
                for (var i = 0; i < array_length(split); i++) {
                    chain.append(LinkId.Function, self.execute_command, [split[i]]);
                    chain.append(LinkId.Timer, 1);
                }
            }
            var command_info = self.parse_command(source);
            if command_info == undefined {
                return;
            }
            if command_info.help_request {
                command_info.command.display_help_message();
                return;
            }
            command_info.command.my_process(command_info.args);
        } catch(e) {
            BUGGER.cli.echo(format("error: {}", e));
        }
    }

    //
    //
    function find_next_chunk(source) {
        while string_pos(" ", source) == 1 {
            source = string_delete(source, 1, 1);
        }

        if string_length(source) == 0 {
            return undefined;
        }
        var in_string = string_pos("\"", source) == 1; // this is for the bad parser we use in vsc: "
        if in_string {
            source = string_delete(source, 1, 1);
            var next_quote = string_pos("\"", source) // "
            if next_quote == 0 {
                return undefined;
            }
            var chunk = string_copy(source, 1, next_quote - 1);
            source = string_replace(source, "\"" + chunk + "\"", "");
        } else {
            var next_space = string_pos(" ", source);
            next_space = next_space == 0 ? string_length(source) + 1 : next_space;
            var chunk = string_copy(source, 1, next_space - 1);
            source = string_replace(source, chunk, "");
        }
        return {
            chunk: chunk,
            source: source,
        }
    }

    function parse_command(source) {
        var output = find_next_chunk(source);
        if output == undefined {
            return;
        }
        var command_name = output.chunk;
        source = output.source;
        var command = self.commands.get(command_name);
        if command == undefined {
            self.cli.echo(fmt("Unrecognized command: {}", command_name));
            return;
        }
        var user_arguments = [];
        while true {
            var output = find_next_chunk(source);
            if output == undefined {
                break;
            }
            source = output.source;
            array_push(user_arguments, output.chunk);
        }

        //
        if array_length(user_arguments) > 0 && command.subcommands.contains_key(user_arguments[0]) {
            command = command.subcommands.get(user_arguments[0]);
            array_delete(user_arguments, 0, 1);
        }

        //
        var help_request = array_length(user_arguments) > 0 && user_arguments[0] == "help";

        //
        var args = {};
        for (var i = 0; i < command.args.count(); i++) {
            var arg = command.args.get(i);
            if i >= array_length(user_arguments) {
                if arg.optional {
                    args[$ arg.name] = arg.default_value;
                    continue;
                } else {
                    BUGGER.cli.echo(fmt("Missing required argument: {}", arg.name));
                    return;
                }
            }
            args[$ arg.name] = user_arguments[i];
        }

        //
        return {
            command: command,
            args: args,
            help_request: help_request,
        }
    }

    function update() {
        if keyboard_check_pressed(vk_f2) || keyboard_check_pressed(vk_delete) {
            if !self.cli.canvas.get_enabled() {
                self.cli.show();
                self.cli.cli_input.set_takes_input(true);
            } else {
                self.cli.hide();
                self.cli.cli_input.set_takes_input(false);
            }
        }
    }

    //
    //
    //
    //
    function find_suggestion() {
        var find_matching_str = function(keys, sub_str) {
            //
            if is_array(keys) == false {
                return undefined;
            }

            for (var i = 0; i < array_length(keys); i++) {
                if string_pos(string_lower(sub_str), string_lower(keys[i])) == 1 {
                    return keys[i];
                }
            }
            return undefined;
        }

        var suggestion = "";
        var source = self.cli.cli_input.get_text();
        var command = undefined;
        var argument_iter = 0;
        while true {
            var output = BUGGER.find_next_chunk(source);
            if output == undefined {
                break;
            }
            source = output.source;
            if command == undefined {
                //
                var key = find_matching_str(BUGGER.commands.keys(), output.chunk);
                if key == undefined {
                    break;
                }
                command = BUGGER.commands.get(key);
                suggestion += command.name + " ";
            } else {
                //
                var key = find_matching_str(command.subcommands.keys(), output.chunk);
                if key != undefined {
                    command = command.subcommands.get(key);
                    suggestion += command.name + " ";
                } else {
                    //
                    if argument_iter >= command.args.count() {
                        //
                        break;
                    } else {
                        var needed_arg = command.args.get(argument_iter);

                        //
                        if needed_arg.values == undefined {
                            break;
                        }

                        //
                        var key = find_matching_str(needed_arg.values, output.chunk);
                        if key != undefined {
                            //
                            //
                            if string_pos("/", key) != 0 {
                                var entries = string_split(key, "/");
                                var user_position = string_count("/", output.chunk) + 1;
                                var len = min(array_length(entries), user_position);
                                suggestion += array_to_string(entries, "/", len)
                            } else {
                                argument_iter += 1;
                                suggestion += key + " ";
                            }
                        }
                    }
                }
            }
        }

        return suggestion == "" ? undefined : suggestion;
    }

    self.cli = ANCHOR.spawn_menu(Menu.Bugger);
    self.cli.canvas.disable();
}

function BuggerCommand(_name) {
    return new __BuggerCommand(_name);
}

function __BuggerCommand(name) constructor {
    self.name = name;
    self.help_text = undefined;
    self.author_name = undefined;
    self.args = List();
    self.subcommands = Map();
    self.my_process = function() {}

    function display_help_message() {
        var msg = "";
        if self.author_name != undefined {
            msg += fmt("\n\nAUTHOR: {}", self.author_name);
        }
        if !self.args.is_empty() {
            msg += "\n\nARGUMENTS:";
            for (var i = 0; i < self.args.count(); i++) {
                var arg = self.args.get(i);
                var this_line = fmt("    {}", arg.name);
                if arg.optional {
                    this_line += " [optional";
                    if arg.default_value != undefined {
                        this_line += ", default is " + string(arg.default_value);
                    }
                    this_line += "]";
                }
                if arg.help_text != undefined {
                    repeat 35 - string_length(this_line) {
                        this_line += " ";
                    }
                    this_line += arg.help_text;
                    msg += fmt("\n    " + this_line);
                }

                msg += this_line;
            }
        }
        var keys = self.subcommands.keys();
        if array_length(keys) > 0 {
            msg += "\n\nSUBCOMMANDS:";
            for (var i = 0; i < array_length(keys); i++) {
                var subcommand = self.subcommands.get(keys[i]);
                var this_line = fmt("    {}", subcommand.name);
                for (var j = 0; j < subcommand.args.count(); j++) {
                    this_line += fmt(" <{}>", string_upper(subcommand.args.get(j).name));
                }
                repeat 35 - string_length(this_line) {
                    this_line += " ";
                }
                if subcommand.help_text != undefined {
                    this_line += "\n" + subcommand.help_text;
                }
                msg += "\n\n    " + this_line;
            }
        }
        BUGGER.cli.echo(msg);
    }

    function help(str) {
        self.help_text = str;
        return self;
    }

    function author(str) {
        self.author_name = str;
        return self;
    }

    function arg(arg) {
        self.args.push(arg);
        return self;
    }

    function subcommand(subcommand) {
        self.subcommands.insert(subcommand.name, subcommand);
        return self;
    }

    function process(process) {
        self.my_process = process;
        return self;
    }
}

function BuggerArgument(name) {
    return new __BuggerArgument(name);
}

function __BuggerArgument(name) constructor {
    self.name = name;
    self.help_text = undefined;
    self.args = List();
    self.optional = false;
    self.values = undefined;
    self.default_value = undefined;

    function help(str) {
        self.help_text = str;
        return self;
    }

    function optional(default_value) {
        self.optional = true;
        self.default_value = default_value;
        return self;
    }

    function values(values) {
        self.values = values;
        return self;
    }
}
