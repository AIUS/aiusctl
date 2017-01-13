require "http/client"
require "json"

def ask_nicely(type, url, body)
	headers = HTTP::Headers {
		"Content-Type" => "application/json"
	}

	body = body.to_json

	if type == :post
		HTTP::Client.post url, headers: headers, body: body
	elsif type == :delete
		HTTP::Client.delete url, headers: headers, body: body
	else type == :get
		HTTP::Client.get url, headers: headers
	end
end

def post(url, body)
	ask_nicely :post, url, body
end

def delete(url, body)
	ask_nicely :delete, url, body
end

def get(url)
	ask_nicely :get, url, {} of String => String
end

