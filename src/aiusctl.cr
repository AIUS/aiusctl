require "http/client"
require "json"
require "readline"
require "option_parser"
require "colorize"

require "./config"

token = ""

config = Config.new

begin
	OptionParser.parse! do |parser|
		parser.banner = "usage: aiusctl [options]"

		parser.on("-l LOGIN", "--login LOGIN", "Specifies the username to log on with.") do |login|
			config.login = login
		end
		parser.on("-p PASSWORD", "--password PASSWORD", "Specifies the password to log on with. DO NOT USE THIS OPTION UNLESS YOU ARE WRITING TESTS.") do |password|
			config.password = password
		end

		parser.on("-o URL", "--otan URL", "Authentication server URL.") do |url|
			config.otan = url
		end
		parser.on("-s URL", "--sales URL", "Sales server URL.") do |url|
			config.sales = url
		end

		parser.unknown_args do |args|
			args.each do |arg|
				raise OptionParser::InvalidOption.new arg
			end
		end
	end
rescue e : OptionParser::InvalidOption
	STDERR << e << "\n"
	exit 1
end

if config.login.nil?
	STDIN << "Login: "
	STDIN.flush

	begin
		login = STDIN.read_line
	rescue e
		STDERR << e << "\n"
		exit 2
	end
end

if config.password.nil?
	STDIN << "Password: "
	STDIN.flush

	begin
		password = STDIN.noecho &.gets.try &.chomp
	rescue e
		STDERR << '\n' << e << '\n'
		exit 2
	end

	STDOUT << '\n'
end

require "./requests"

response = post config.otan + "/token", {
	"username" => login,
	"password" => password,
}

if response.status_code == 200
	response = JSON.parse response.body

	new_token = response["token"]?

	if new_token
		puts "Connected."

		new_token = new_token.as_s?

		unless new_token.nil?
			token = new_token
		else
			puts "Received token is not a JSON string?"

			exit
		end
	else
		puts "No token received. Dying nao."

		exit
	end
else
	STDERR << "HTTP error (#{response.status_code}).\n"
	STDERR << response.body

	STDERR << "Could not authenticate. Dying nao.\n"

	exit
end

alias Command = NamedTuple(help: String, exec: Proc(Array(String), Nil))

commands = Hash(String, Command | Hash(String, Command)) {
	"version" => {
		help: "Prints version information about aiusctl.",
		exec: ->(arg : Array(String)) {
			puts "#{`sed -n "/^version: /{s/^version: *//;p}"`}"
			nil
		}
	},
	"sales" => Hash {
		"list" => {
			help: "List products on sale.",
			exec: ->(arg : Array(String)) {
				answer = JSON.parse get(config.sales + "/products").body

				answer.each do |product|
					puts "#{product["id"]}: #{product["name"]} - #{product["price"]}"
				end

				return
			}
		},
		"sell" => {
			help: "Sell a product.",
			exec: ->(arg : Array(String)) {
				if ! arg[1]?
					puts "usage: sell <id>"

					return
				end

				id = arg[1].to_i

				puts "id: #{id}"
			}
		},
		"new-product" => {
			help: "Add a product to the sales list.",
			exec: ->(arg : Array(String)) {
				if ! arg[2]?
					puts "usage: sell <name> <price>"

					return
				end

				name = arg[1].to_s
				price = arg[2].to_f64

				answer = JSON.parse post(config.sales + "/products", {
					"name" => name,
					"price" => price,
					"token" => token
				}).body

				puts answer

				return
			}
		},
		"delete-product" => {
			help: "Delete a product from the list of sellable items.",
			exec: ->(arg : Array(String)) {
				if ! arg[1]?
					puts "usage: delete-product <id>"

					return
				end

				id = arg[1].to_i
				answer = delete(config.sales + "/product/#{id}", {
					"token" => token
				}).body

				puts answer
			}
		},
	}
}

commands["help"] = {
	help: "Lists the available commands.",
	exec: ->(arg : Array(String)) {
		commands.each do |command, data|
			if data.is_a? Hash(String, Command)
				STDOUT << command.colorize(:blue).bold << "\n"

				data.each do |key, value|
					STDOUT << command.colorize(:white).bold.to_s
					STDOUT << " / "
					STDOUT << key.colorize(:green).bold.to_s

					(command.size + key.size .. 23).each do
						STDOUT << ' '
					end

					STDOUT << value[:help] << "\n"
				end
			else
				STDOUT << command.colorize(:white).bold
				STDOUT << ": "

				(command.size .. 24).each do
					STDOUT << ' '
				end

				STDOUT << data[:help] << "\n"
			end
		end

		return
	}
}

category : String | Nil = nil

while true
	line = Readline.readline (category.nil? ? "" : category.colorize(:blue).bold.to_s) + " > "

	if line.nil?
		if category.is_a? String
			category = nil

			STDOUT << '\n'

			next
		else
			break
		end
	end

	arg = line.split /[ \t]+/

	if arg.size > 0
		selected_commands = commands

		if category.is_a? String
			selected_commands = commands[category]?

			unless selected_commands
				selected_commands = commands
			end
		end

		command = selected_commands[arg[0]]?

		unless command
			command = commands[arg[0]]?
		end

		if command.is_a? Hash(String, Command)
			category = arg[0]
			puts "#{arg[0]}/?"
		elsif command.is_a? Command
			command[:exec].call arg
		else
			puts "Unknown command: #{arg[0]}"
		end
	end
end

response = delete config.otan + "/token/" + token, {} of String => (String | Nil)

if response.status_code != 200
	STDERR << "Received HTTP error code: " << response.status_code << ".\n"
	STDERR << response.body
end

