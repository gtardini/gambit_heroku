require 'open-uri'
class Stat < ActiveRecord::Base
	def pushMail(oo, stats)
		doc = Nokogiri::HTML(open("https://www.bwin.it/betViewIframe.aspx?SportID=4&bv=bb&selectedLeagues=0").read())
		p doc
	end
end