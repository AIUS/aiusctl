require "http/client"
require "json"
require "readline"
require "option_parser"

require "./config"

token = nil

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
		STDERR << e << "\n"
		exit 2
	end
end

require "./requests"

response = post config.otan + "/token", {
	"username" => login,
	"password" => password,
}

if response.status_code == 200
	response = JSON.parse response.body

	if response["token"]
		puts "Connected."
		token = response["token"]
	else
		puts "No token received. Dying nao."

		exit
	end
else
	puts "HTTP error (#{response.status_code})."
	puts response
	STDOUT << response.body

	puts "Could not authenticate. Dying nao."

	exit
end

commands = Hash(String, NamedTuple(help: String, exec: Proc(Array(String), Nil))) {
	"sales" => {
		help: "List products on sale.",
		exec: ->(arg : Array(String)) {
			answer = JSON.parse get(config.sales + "/products").body

			answer.each do |product|
				puts "#{product["id"]}: #{product["name"]} - #{product["price"]}"
			end

			return
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

commands["help"] = {
	help: "Lists the available commands.",
	exec: ->(arg : Array(String)) {
		commands.each do |command, data|
			STDOUT << "%-20s" % (command + ":") << data[:help] << "\n"
		end

		return
	}
}

while line = Readline.readline "> "
	arg = line.split /[ \t]+/

	if line.match /^[ \t]*$/
		# Ignored.
	elsif commands[arg[0]]?
		commands[arg[0]][:exec].call arg
	else
		puts "Unknown command: #{arg[0]}"
	end
end

