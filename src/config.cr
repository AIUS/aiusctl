
class Config
	@login : String | Nil
	@password : String | Nil

	@otan = "https://otan.aius.u-strasbg.fr"
	@sales = "http://localhost:3000"

	def initialize
	end

	def login=(@login) end
	def login
		@login
	end

	def password=(@password) end
	def password
		@password
	end

	def otan=(@otan) end
	def otan
		@otan
	end

	def sales=(@sales) end
	def sales
		@sales
	end
end

