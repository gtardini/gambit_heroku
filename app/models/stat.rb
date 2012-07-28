class Stat < ActiveRecord::Base
	def push_mail
		oo = Openoffice.new("Current.ods")
		p oo
	end
end