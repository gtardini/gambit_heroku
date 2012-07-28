require 'open-uri'

class Stat < ActiveRecord::Base
	def push_mail
		oo = Openoffice.new("Current.ods")
		doc = Nokogiri::HTML(open("https://www.bwin.it/betViewIframe.aspx?SportID=4&bv=bb&selectedLeagues=0").read())
		if doc.xpath("//div[contains(@class, 'bet-list')]").size == 3
			bets = doc.xpath("//div[contains(@class, 'bet-list')]")[2]
		elsif doc.xpath("//div[contains(@class, 'bet-list')]").size == 2
			bets = doc.xpath("//div[contains(@class, 'bet-list')]")[1]
		end
		times = bets.search(".//td[contains(@class, 'leftcell minwidth')]")
		teams = bets.xpath(".//td[contains(@class, 'label')]")
		odds = bets.xpath(".//td[contains(@class, 'odd')]")

		i=0
		data = []
		buffer = []
		for team in teams do
			if (i+1) % 3 != 0 || i == 0
				buffer << team.text.strip
				buffer << odds[i].text.to_f
			else
				buffer << team.text.strip
				buffer << odds[i].text.to_f
				buffer << times[i/3].text.strip
				data << buffer
				buffer = []
			end
			i = i+1
		end
		hashed_data = []
		hashed_buffer = {}
		for line in data
			hashed_buffer.store("1", line[1])
			hashed_buffer.store("x", line[3])
			hashed_buffer.store("2", line[5])
			hashed_buffer.store("team_1", line[0].strip)
			hashed_buffer.store("team_2", line[4].strip)
			hashed_buffer.store("time", line[6].strip)
			hashed_data << hashed_buffer
			hashed_buffer = {}
		end

		#oo = Openoffice.new("10-11-winter.ods")
		oo.default_sheet = oo.sheets.first
		picked_hour = 0
		picked_minute = 0
		matches_data = {}
		for match in hashed_data
			home_team = match["team_1"]
			away_team = match["team_2"]
			home_win_odds = match["1"]
			away_win_odds = match["2"]
			draw_odds = match["x"]
			time = match["time"]
			hour = time.split(".")[0].to_i
			minute = time.split(".")[1].to_i
			if picked_hour == 0 || (picked_hour != 0 && (hour - picked_hour) >= 1 && (minute - picked_minute >= 0 || hour - picked_hour > 1))
				picked_hour = hour
				picked_minute = minute
			elsif hour - picked_hour < 0
			#siamo in un altro giorno
				break
			end
			#se hour - picked_hour >= 0, allora i match sono tutti nello stesso giorno
			if hour - picked_hour >= 0
				if home_win_odds < away_win_odds
					money_wanted = 5
					money_needed = money_wanted / (home_win_odds-1)
					p "#{time}: #{home_team}: #{home_win_odds} - X: #{draw_odds} - #{away_team}: #{away_win_odds}"
						if home_win_odds%0.05!=0
							home_win_odds = (home_win_odds * 10**1).round.to_f / 10**1
							perc = Stat.find :all, :select => "percentage", :conditions => ["min <= '#{home_win_odds}' AND max >= '#{home_win_odds+0.05}'"]
							number_of_black_swans, roo_home_perc, roo_away_perc = bookie_percentages(oo, home_win_odds)
							p "#{number_of_black_swans} black swan(s)."  
						else
							perc = Stat.find :all, :select => "percentage", :conditions => ["min <= '#{home_win_odds}' AND max >= '#{home_win_odds+0.05}'"]
							number_of_black_swans, roo_home_perc, roo_away_perc = bookie_percentages(oo, home_win_odds)
							p "#{number_of_black_swans} black swan(s)."  
						end
						if perc[0] != nil
							p "tabella (partial) accuracy percentage: #{perc[0].percentage}%"  
							mixed_percentage = (perc[0].percentage*100+roo_home_perc)/2
							chance = mixed_percentage/(number_of_black_swans+1)
							odds_weighted_chance = chance/home_win_odds
							chance_weighted_convenience = chance/money_needed
							#stores in an hash all the data about each match
							match_name = "#{time}: #{home_team}: #{home_win_odds} - X: #{draw_odds} - #{away_team}: #{away_win_odds}"
							matches_data.store(match_name, [])
							matches_data[match_name][0]= time
							matches_data[match_name][1]= home_team
							matches_data[match_name][2]= home_win_odds
							matches_data[match_name][3]= draw_odds
							matches_data[match_name][4]= away_team
							matches_data[match_name][5]= away_win_odds
							matches_data[match_name][6]= mixed_percentage
							matches_data[match_name][7]= chance
							matches_data[match_name][8]= odds_weighted_chance
							matches_data[match_name][9]= chance_weighted_convenience
							matches_data[match_name][10]= roo_home_perc
							matches_data[match_name][11]= roo_away_perc
							matches_data[match_name][12]= perc[0].percentage
							matches_data[match_name][13]= number_of_black_swans
						end
						p "mixed_percentage: #{mixed_percentage}"
						p "chance: #{chance}"
						p "odds_weighted_chance: #{odds_weighted_chance}"
						p "money_needed: #{money_needed}"
						p "chance_weighted_convenience: #{chance_weighted_convenience}"
				else
					p "tabella accuracy percentage not computed."  
				end
		else
			p "nothing-to-say-about: #{time}: #{home_team}: #{home_win_odds} - X: #{draw_odds} - #{away_team}: #{away_win_odds}"
	 	end
	 end
	 
	 #ORDERS MATCHES BY CONVENIENCE
	 matches_chance_weighted_convenience_ordered_data = {}
	 matches_chance_weighted_convenience_ordered_data = matches_data.sort_by {|key, value| value[9]} 
	 matches_chance_weighted_convenience_ordered_data.each{|key, value|
		 p "#{value}"  
	 } 
 
	
	#BETVIRUS PART 
	doc = Nokogiri::HTML(open("http://betvirus.com/bvrates/").read())
 	league = 0
 	country = 0
 	leagues_td = doc.xpath("//td[contains(@class, 'brdright')]")
 	matches_td = doc.xpath("//td[contains(@class, 'tdivbvr')]")
 	countries = []
 	leagues = []
 	matches = []
 	forms = {}
 	form_urls = []
 	inout_form_urls = []
 	#collects league codes
 	for league in leagues_td
		if league.children[1].attributes["href"] != nil
			league_code = league.children[1].attributes["href"].value.strip.gsub("/leagueStats/", "").gsub("/", "").to_i
			leagues << league_code
		end
	end

	#collects match urls
	for match in matches_td
		match_url = "http://betvirus.com" + match.children[0].attributes["href"].value
		matches << match_url
	end


	#collects country codes for each match
	i = 0
	for match in matches
		doc = Nokogiri::HTML(open("http://betvirus.com/leagueStats/#{leagues[i]}/").read())
		div = doc.xpath("//div[contains(@class, 'rImg')]")
		country_code = div[1].children[2].xpath(".//li")[4].children[3].attributes["href"].value.strip.gsub("/country/", "").gsub("/", "")
		countries << country_code
		i += 1
	end

	i=0
	for match in matches
		buffer = []
		doc = Nokogiri::HTML(open(match).read())
		stats = doc.xpath("//td[contains(@class, 'lgStatsText')]")
		form_1 = stats[5].text.strip.gsub("%","").to_i
		form_x = stats[6].text.strip.gsub("%","").to_i
		form_2 = stats[7].text.strip.gsub("%","").to_i
		form_u = stats[8].text.strip.gsub("%","").to_i
		form_o = stats[9].text.strip.gsub("%","").to_i
		inout_form_1 = stats[10].text.strip.gsub("%","").to_i 
		inout_form_x = stats[11].text.strip.gsub("%","").to_i 
		inout_form_2 = stats[12].text.strip.gsub("%","").to_i 
		inout_form_u = stats[13].text.strip.gsub("%","").to_i 
		inout_form_o = stats[14].text.strip.gsub("%","").to_i 
		buffer << form_1 << form_x << form_2 << form_u << form_o << inout_form_1 << inout_form_x << inout_form_2 << inout_form_u << inout_form_o
		forms.store(i, buffer)
		i += 1
	end

	i=0
	for match in matches
		url = "http://betvirus.com/bvtool/?c=#{countries[i]}&l=#{leagues[i]}&t=3&m1=1&y1=2011&m2=7&y2=2012&e1s=#{forms[i][0]-2}&e1e=#{forms[i][0]+2}&exs=#{forms[i][1]-2}&exe=#{forms[i][1]+2}&e2s=#{forms[i][2]-2}&e2e=#{forms[i][2]+2}&eus=#{forms[i][3]-2}&eue=#{forms[i][3]+2}&eos=#{forms[i][4]-2}&eoe=#{forms[i][4]+2}"
		form_urls << url
		i += 1
	end

	i=0
	for match in matches
		url = "http://betvirus.com/bvtool/?c=#{countries[i]}&l=#{leagues[i]}&t=4&m1=1&y1=2011&m2=7&y2=2012&e1s=#{forms[i][5]-2}&e1e=#{forms[i][5]+2}&exs=#{forms[i][6]-2}&exe=#{forms[i][6]+2}&e2s=#{forms[i][7]-2}&e2e=#{forms[i][7]+2}&eus=#{forms[i][8]-2}&eue=#{forms[i][8]+2}&eos=#{forms[i][9]-2}&eoe=#{forms[i][9]+2}"
		inout_form_urls << url
		i += 1
	end

	j = 1
	for url in inout_form_urls
		i = 1
		flag = 1
		while(flag)
			if i == 1
				#do nothing
			else
				url = "#{url}&pageNumber=#{i}"
				ap "page #{i}"
			end
			doc = Nokogiri::HTML(open(url).read())
			nbsp = Nokogiri::HTML("&nbsp;").text
			overall_table = doc.xpath("//table[contains(@id, 'prgTabTblN')]")
			overall_table = overall_table.xpath(".//td[contains(@align, 'center')]")
			overall_home_wins = overall_table[10].text.to_i
			overall_draws = overall_table[11].text.to_i
			overall_away_wins = overall_table[12].text.to_i
			overall_unders = overall_table[13].text.to_i
			overall_overs = overall_table[14].text.to_i
			probs_from_match_eval = overall_table[15].text.strip.gsub(/\s+/, "").delete("-").gsub(nbsp, "").split("%")
			overall_home_probs = probs_from_match_eval[0].to_i
			overall_draw_probs = probs_from_match_eval[1].to_i
			overall_away_probs = probs_from_match_eval[2].to_i
			overall_under_probs = probs_from_match_eval[3].to_i
			overall_over_probs = probs_from_match_eval[4].to_i
			if i == 1
				p "#{j}"  
				p "<a href=#{url}>#{url}</a>"
				p "Overall Home Wins: #{overall_home_wins}"
				p  "Overall Draws: #{overall_draws}"
				p "Overall Away Wins: #{overall_away_wins}"
				p "Overall Unders: #{overall_unders}" 
				p "Overall Overs: #{overall_overs}"
				p "Overall Home Win Probabilities: #{overall_home_probs}" 
				p "Overall Draw Probabilities: #{overall_draw_probs}"
				p "Overall Away Win Probabilities: #{overall_away_probs}"
				p "Overall Under Probabilities: #{overall_under_probs}"
				p "Overall Over Probabilities: #{overall_over_probs}" 
				j = j+1
			end

			maineval_div = doc.xpath("//div[contains(@id, 'mainEvalq')]")
			rows = maineval_div.xpath(".//tr").drop(2)
			rows.each do |row|
				begin
 					row_array = row.text.strip.gsub(/\s+/, " ").gsub(nbsp, " ").split("%")
 					size = row_array[0].size
 					home_probs =  row.text.strip.gsub(/\s+/, " ").gsub(nbsp, " ").split("%")[0][(size - 2)..(size)].to_i
 					draw_probs = row_array[1].strip.gsub(/\s+/, "").delete("-").gsub(nbsp, "").to_i
 					away_probs = row_array[2].strip.gsub(/\s+/, "").delete("-").gsub(nbsp, "").to_i
 					under_probs = row_array[3].strip.gsub(/\s+/, "").gsub(nbsp, "").to_i
 					over_probs = row_array[4].strip.gsub(/\s+/, "").gsub(nbsp, "").delete("-").to_i
 					home_goals = 0
 					away_goals = 0
 					home_odds = 0
 					draw_odds = 0
 					away_odds = 0
 					if row_array[5].size < 15
 						#process for score only matches
 						home_goals = row_array[5].split("-")[0].strip.to_i
 						away_goals = row_array[5].split("-")[1].strip.to_i
 					else
 						home_odds = row_array[5].strip.split(" ")[0].to_f
 						draw_odds = row_array[5].strip.split(" ")[1].to_f
 						away_odds = row_array[5].strip.split(" ")[2].to_f
 						home_goals = row_array[5].strip.split(" ")[3].to_i
 						away_goals = row_array[5].strip.split(" ")[5].strip.delete("-").to_i
 					end
 					#ap home_probs
 					#ap draw_probs
 					#ap away_probs
 					#ap under_probs
 					#ap over_probs
 					#ap home_odds
 					#ap draw_odds
 					#ap away_odds
 					#ap home_goals
 					#ap away_goals
 					#p "----------"
 				rescue
 					#when we arrive to the tr where we have next page, an exception is thrown, and we handle it increasing the counter of the page
 					if row_array[0] != nil
 						last_page = row_array[0].split(" ")[3].to_i
 						if i+1 <= last_page
 							flag = 1
 							i += 1
 						else
 							flag = false
 						end
 					else
 						flag = false
 					end
 				end 
 			end
 		end
 	end
 	
 	
 	#FOOTBALL-BET-DATA.CO.UK PART
 	a = Mechanize.new{ |agent|
	 	agent.user_agent_alias = 'Mac Safari'
	}

	a.get('http://www.football-bet-data.yows.co.uk/') do |page|
		loggedin_page = page.form_with(:action => 'index.asp') do |f|
			f.x1  = "gtardini@gmail.com"
			f.x2 = "footballbetdatarokz"
		end.click_button
	end

	home_odds = 0
	draw_odds = 0
	away_odds = 0

	doc = Nokogiri::HTML(a.post('http://www.football-bet-data.yows.co.uk/index.asp', {"AR1"=>"AR1","AU1"=>"AU1","AU2"=>"AU2","B1"=>"B1","B2"=>"B2","BR1"=>"BR1","BU1"=>"BU1","CH1"=>"CH1","CO1"=>"CO1","CR1"=>"CR1","CZ1"=>"CZ1","CZ2"=>"CZ2","D1"=>"D1","D2"=>"D2","D3"=>"D3","DE1"=>"DE1","DE2"=>"DE2","E0"=>"E0","E1"=>"E1","E2"=>"E2","E3"=>"E3","EC"=>"EC","FI1"=>"FI1","FI2"=>"FI2","FR1"=>"FR1","FR2"=>"FR2","FR3"=>"FR3","G1"=>"G1","G2"=>"G2","HU1"=>"HU1","IC1"=>"IC1","IR1"=>"IR1","IT1"=>"IT1","IT2"=>"IT2","IT3"=>"IT3","J1"=>"J1","J2"=>"J2","MX1"=>"MX1","N1"=>"N1","N2"=>"N2","NO1"=>"NO1","NO2"=>"NO2","PL1"=>"PL1","PL2"=>"PL2","PT1"=>"PT1","PT2"=>"PT2","RO1"=>"RO1","RU1"=>"RU1","SC0"=>"SC0","SC1"=>"SC1","SC2"=>"SC2","SC3"=>"SC3","SI1"=>"SI1","SL1"=>"SL1","SL2"=>"SL2","SP1"=>"SP1","SP2"=>"SP2","SU1"=>"SU1","SU2"=>"SU2","SW1"=>"SW1","SW2"=>"SW2","T1"=>"T1","T2"=>"T2","US1"=>"US1","UK1"=>"UK1","WA1"=>"WA1",

"0-0"=>"0-0","1-0"=>"1-0","2-0"=>"2-0","3-0"=>"3-0","4-0"=>"4-0","5-0"=>"5-0","0-1"=>"0-1","1-1"=>"1-1","2-1"=>"2-1","3-1"=>"3-1","4-1"=>"4-1","5-1"=>"5-1","0-2"=>"0-2","1-2"=>"1-2","2-2"=>"2-2","3-2"=>"3-2","4-2"=>"4-2","5-2"=>"5-2","0-3"=>"0-3","1-3"=>"1-3","2-3"=>"2-3","3-3"=>"3-3","4-3"=>"4-3","5-3"=>"5-3","0-4"=>"0-4","1-4"=>"1-4","2-4"=>"2-4","3-4"=>"3-4","4-4"=>"4-4","5-4"=>"5-4","0-5"=>"0-5","1-5"=>"1-5","2-5"=>"2-5","3-5"=>"3-5","4-5"=>"4-5","5-5"=>"5-5",

"H"=>"H","D"=>"D","A"=>"A",

"0"=>"0","1"=>"1","2"=>"2","3"=>"3","4"=>"4","5"=>"5","6"=>"6","7"=>"7","8"=>"8","9"=>"9","10"=>"10","1-1.25Pho"=>"1-1.25","1.26-1.50Pho"=>"1.26-1.50","1.51-1.80Pho"=>"1.51-1.80","1.81-2.10Pho"=>"1.81-2.10","2.11-2.50Pho"=>"2.11-2.50","2.51-3.00Pho"=>"2.51-3.00","3.01-4.00Pho"=>"3.01-4.00","4.01-5.00Pho"=>"4.01-5.00","5.01-6.00Pho"=>"5.01-6.00","6.01-7.00Pho"=>"6.01-7.00","7.01-100Pho"=>"7.01-100","1-3.45Pdo"=>"1-3.45","3.46-3.69Pdo"=>"3.46-3.69","3.70-3.99Pdo"=>"3.70-3.99","4.00-4.50Pdo"=>"4.00-4.50","4.51-5.00Pdo"=>"4.51-5.00","5.01-5.50Pdo"=>"5.01-5.50","5.51-6.00Pdo"=>"5.51-6.00","6.01-7.00Pdo"=>"6.01-7.00","7.01-8.00Pdo"=>"7.01-8.00","8.01-10.00Pdo"=>"8.01-10.00","10.01-100Pdo"=>"10.01-100","1-1.25Pao"=>"1-1.25","1.26-1.50Pao"=>"1.26-1.50","1.51-1.80Pao"=>"1.51-1.80","1.81-2.10Pao"=>"1.81-2.10","2.11-2.50Pao"=>"2.11-2.50","2.51-3.00Pao"=>"2.51-3.00","3.01-4.00Pao"=>"3.01-4.00","4.01-5.00Pao"=>"4.01-5.00","5.01-6.00Pao"=>"5.01-6.00","6.01-7.00Pao"=>"6.01-7.00","7.01-100Pao"=>"7.01-100","1-1.20Pggo"=>"1-1.20","1.21-1.40Pggo"=>"1.21-1.40","1.41-1.60Pggo"=>"1.41-1.60","1.61-1.80Pggo"=>"1.61-1.80","1.81-2.00Pggo"=>"1.81-2.00","2.01-2.20Pggo"=>"2.01-2.20","2.21-2.40Pggo"=>"2.21-2.40","2.41-2.60Pggo"=>"2.41-2.60","2.61-2.80Pggo"=>"2.61-2.80","2.81-3.00Pggo"=>"2.81-3.00","3.01-100Pggo"=>"3.01-100","1-1.50Pu25o"=>"1-1.50","1.51-1.60Pu25o"=>"1.51-1.60","1.61-1.70Pu25o"=>"1.61-1.70","1.71-1.80Pu25o"=>"1.71-1.80","1.81-1.90Pu25o"=>"1.81-1.90","1.91-2.20Pu25o"=>"1.91-2.20","2.21-2.40Pu25o"=>"2.21-2.40","2.41-2.60Pu25o"=>"2.41-2.60","2.61-2.80Pu25o"=>"2.61-2.80","2.81-3.00Pu25o"=>"2.81-3.00","3.01-100Pu25o"=>"3.01-100","1-1.50Po25o"=>"1-1.50","1.51-1.60Po25o"=>"1.51-1.60","1.61-1.70Po25o"=>"1.61-1.70","1.71-1.80Po25o"=>"1.71-1.80","1.81-1.90Po25o"=>"1.81-1.90","1.91-2.20Po25o"=>"1.91-2.20","2.21-2.40Po25o"=>"2.21-2.40","2.41-2.60Po25o"=>"2.41-2.60","2.61-2.80Po25o"=>"2.61-2.80","2.81-3.00Po25o"=>"2.81-3.00","3.01-100Po25o"=>"3.01-100",

"0-1.25Aho"=>"0-1.25","1.26-1.50Aho"=>"1.26-1.50","1.51-1.80Aho"=>"1.51-1.80","1.81-2.10Aho"=>"1.81-2.10","2.11-2.50Aho"=>"2.11-2.50","2.51-3.00Aho"=>"2.51-3.00","3.01-4.00Aho"=>"3.01-4.00","4.01-5.00Aho"=>"4.01-5.00","5.01-6.00Aho"=>"5.01-6.00","6.01-7.00Aho"=>"6.01-7.00","7.01-100Aho"=>"7.01-100",

"0-3.45Ado"=>"0-3.45","3.46-3.69Ado"=>"3.46-3.69","3.70-3.99Ado"=>"3.70-3.99","4.00-4.50Ado"=>"4.00-4.50","4.51-5.00Ado"=>"4.51-5.00","5.01-5.50Ado"=>"5.01-5.50","5.51-6.00Ado"=>"5.51-6.00","6.01-7.00Ado"=>"6.01-7.00","7.01-8.00Ado"=>"7.01-8.00","8.01-10.00Ado"=>"8.01-10.00","10.01-100Ado"=>"10.01-100",

"0-1.25Aao"=>"0-1.25","1.26-1.50Aao"=>"1.26-1.50","1.51-1.80Aao"=>"1.51-1.80","1.81-2.10Aao"=>"1.81-2.10","2.11-2.50Aao"=>"2.11-2.50","2.51-3.00Aao"=>"2.51-3.00","3.01-4.00Aao"=>"3.01-4.00","4.01-5.00Aao"=>"4.01-5.00","5.01-6.00Aao"=>"5.01-6.00","6.01-7.00Aao"=>"6.01-7.00","7.01-100Aao"=>"7.01-100",

"2011"=>"2011","2012"=>"2012","rDate"=>"tod","stage"=>"2"}).content)

	table = doc.xpath("//table[contains(@id, 'table-3')]")
	rows = table.xpath(".//tr").drop(1)
	matches = {}
	i=0
	for row in rows
		buffer = []
		date = row.children[0].text
		league = row.children[1].text.strip
		home_team = row.children[2].text
		away_team = row.children[3].text
		h_odds = row.children[9].text.strip.to_f
		d_odds = row.children[10].text.strip.to_f
		a_odds = row.children[11].text.strip.to_f
		cs_odds = row.children[12].text.strip.to_f
		cs_prediction = row.children[13].text
		prediction = row.children[14].text
		goals_prediction = row.children[15].text.strip.to_i
		pred_h_odds = row.children[16].text.strip.to_f
		pred_d_odds = row.children[17].text.strip.to_f
		pred_a_odds = row.children[18].text.strip.to_f
		pred_gg_odds = row.children[19].text.strip.to_f
		buffer << date << league << home_team << away_team << h_odds << d_odds << a_odds << cs_odds << cs_prediction << prediction << goals_prediction << pred_h_odds << pred_d_odds << pred_a_odds << pred_gg_odds
		matches.store(i, buffer)
		i += 1
	end

	i = 0
	for match in matches
		league = match[1][1]
		home_odds = match[1][4]
		draw_odds = match[1][5]
		away_odds = match[1][6]
		home_team = match[1][2]
		away_team = match[1][3]
		post_data = {"#{league}"=>"#{league}",
  "0-0"=>"0-0","1-0"=>"1-0","2-0"=>"2-0","3-0"=>"3-0","4-0"=>"4-0","5-0"=>"5-0","0-1"=>"0-1","1-1"=>"1-1","2-1"=>"2-1","3-1"=>"3-1","4-1"=>"4-1","5-1"=>"5-1","0-2"=>"0-2","1-2"=>"1-2","2-2"=>"2-2","3-2"=>"3-2","4-2"=>"4-2","5-2"=>"5-2","0-3"=>"0-3","1-3"=>"1-3","2-3"=>"2-3","3-3"=>"3-3","4-3"=>"4-3","5-3"=>"5-3","0-4"=>"0-4","1-4"=>"1-4","2-4"=>"2-4","3-4"=>"3-4","4-4"=>"4-4","5-4"=>"5-4","0-5"=>"0-5","1-5"=>"1-5","2-5"=>"2-5","3-5"=>"3-5","4-5"=>"4-5","5-5"=>"5-5",
  "H"=>"H","D"=>"D","A"=>"A",
  "0"=>"0","1"=>"1","2"=>"2","3"=>"3","4"=>"4","5"=>"5","6"=>"6","7"=>"7","8"=>"8","9"=>"9","10"=>"10",
  "1-1.25Pho"=>"1-1.25","1.26-1.50Pho"=>"1.26-1.50","1.51-1.80Pho"=>"1.51-1.80","1.81-2.10Pho"=>"1.81-2.10","2.11-2.50Pho"=>"2.11-2.50","2.51-3.00Pho"=>"2.51-3.00","3.01-4.00Pho"=>"3.01-4.00","4.01-5.00Pho"=>"4.01-5.00","5.01-6.00Pho"=>"5.01-6.00","6.01-7.00Pho"=>"6.01-7.00","7.01-100Pho"=>"7.01-100",
  "1-3.45Pdo"=>"1-3.45","3.46-3.69Pdo"=>"3.46-3.69","3.70-3.99Pdo"=>"3.70-3.99","4.00-4.50Pdo"=>"4.00-4.50","4.51-5.00Pdo"=>"4.51-5.00","5.01-5.50Pdo"=>"5.01-5.50","5.51-6.00Pdo"=>"5.51-6.00","6.01-7.00Pdo"=>"6.01-7.00","7.01-8.00Pdo"=>"7.01-8.00","8.01-10.00Pdo"=>"8.01-10.00","10.01-100Pdo"=>"10.01-100",
  "1-1.25Pao"=>"1-1.25","1.26-1.50Pao"=>"1.26-1.50","1.51-1.80Pao"=>"1.51-1.80","1.81-2.10Pao"=>"1.81-2.10","2.11-2.50Pao"=>"2.11-2.50","2.51-3.00Pao"=>"2.51-3.00","3.01-4.00Pao"=>"3.01-4.00","4.01-5.00Pao"=>"4.01-5.00","5.01-6.00Pao"=>"5.01-6.00","6.01-7.00Pao"=>"6.01-7.00","7.01-100Pao"=>"7.01-100",
  "1-1.20Pggo"=>"1-1.20","1.21-1.40Pggo"=>"1.21-1.40","1.41-1.60Pggo"=>"1.41-1.60","1.61-1.80Pggo"=>"1.61-1.80","1.81-2.00Pggo"=>"1.81-2.00","2.01-2.20Pggo"=>"2.01-2.20","2.21-2.40Pggo"=>"2.21-2.40","2.41-2.60Pggo"=>"2.41-2.60","2.61-2.80Pggo"=>"2.61-2.80","2.81-3.00Pggo"=>"2.81-3.00","3.01-100Pggo"=>"3.01-100",
  "1-1.50Pu25o"=>"1-1.50","1.51-1.60Pu25o"=>"1.51-1.60","1.61-1.70Pu25o"=>"1.61-1.70","1.71-1.80Pu25o"=>"1.71-1.80","1.81-1.90Pu25o"=>"1.81-1.90","1.91-2.20Pu25o"=>"1.91-2.20","2.21-2.40Pu25o"=>"2.21-2.40","2.41-2.60Pu25o"=>"2.41-2.60","2.61-2.80Pu25o"=>"2.61-2.80","2.81-3.00Pu25o"=>"2.81-3.00","3.01-100Pu25o"=>"3.01-100",
  "1-1.50Po25o"=>"1-1.50","1.51-1.60Po25o"=>"1.51-1.60","1.61-1.70Po25o"=>"1.61-1.70","1.71-1.80Po25o"=>"1.71-1.80","1.81-1.90Po25o"=>"1.81-1.90","1.91-2.20Po25o"=>"1.91-2.20","2.21-2.40Po25o"=>"2.21-2.40","2.41-2.60Po25o"=>"2.41-2.60","2.61-2.80Po25o"=>"2.61-2.80","2.81-3.00Po25o"=>"2.81-3.00","3.01-100Po25o"=>"3.01-100",
  "2011"=>"2011","2012"=>"2012","rDate"=>"all","stage"=>"2"}

 	 if home_odds >= 1 && home_odds <= 1.25
	 	post_data = post_data.merge "0-1.25Aho"=>"0-1.25"
	 elsif home_odds >= 1.26 && home_odds <= 1.50
	 	post_data = post_data.merge  "1.26-1.50Aho"=>"1.26-1.50"  
	 elsif home_odds >= 1.51 && home_odds <= 1.80
	 	post_data = post_data.merge  "1.51-1.80Aho"=>"1.51-1.80"  
	 elsif home_odds >= 1.81 && home_odds <= 2.10
	 	post_data = post_data.merge  "1.81-2.10Aho"=>"1.81-2.10"  
	 elsif home_odds >= 2.11 && home_odds <= 2.50
	 	post_data = post_data.merge  "2.11-2.50Aho"=>"2.11-2.50"  
	 elsif home_odds >= 2.51 && home_odds <= 3.00
	 	post_data = post_data.merge  "2.51-3.00Aho"=>"2.51-3.00"  
	 elsif home_odds >= 3.01 && home_odds <= 4.00
	 	post_data = post_data.merge  "3.01-4.00Aho"=>"3.01-4.00"  
	 elsif home_odds >= 4.01 && home_odds <= 5.00
	 	post_data = post_data.merge  "4.01-5.00Aho"=>"4.01-5.00"  
	 elsif home_odds >= 5.01 && home_odds <= 6.00
	 	post_data = post_data.merge  "5.01-6.00Aho"=>"5.01-6.00"  
	 elsif home_odds >= 6.01 && home_odds <= 7.00
	 	post_data = post_data.merge  "6.01-7.00Aho"=>"6.01-7.00"  
	 elsif home_odds >= 7.01 && home_odds <= 100
	 	post_data = post_data.merge  "7.01-100Aho"=>"7.01-100"  
	 end

	 if draw_odds >= 0 && draw_odds <= 3.45
		post_data = post_data.merge  "0-3.45Ado"=>"0-3.45"  
	 elsif draw_odds >= 3.46 && draw_odds <= 3.69
	 	post_data = post_data.merge  "3.46-3.69Ado"=>"3.46-3.69"  
	 elsif draw_odds >= 3.70 && draw_odds <= 3.99
	 	post_data = post_data.merge  "3.70-3.99Ado"=>"3.70-3.99"  
	 elsif draw_odds >= 4.00 && draw_odds <= 4.50
	 	post_data = post_data.merge  "4.00-4.50Ado"=>"4.00-4.50"  
	 elsif draw_odds >= 4.51 && draw_odds <= 5.00
	 	post_data = post_data.merge  "4.51-5.00Ado"=>"4.51-5.00"  
	 elsif draw_odds >= 5.01 && draw_odds <= 5.50
	 	post_data = post_data.merge  "5.01-5.50Ado"=>"5.01-5.50"  
	 elsif draw_odds >= 5.51 && draw_odds <= 6.00
	 	post_data = post_data.merge  "5.51-6.00Ado"=>"5.51-6.00"  
	 elsif draw_odds >= 6.01 && draw_odds <= 7.00
	 	post_data = post_data.merge  "6.01-7.00Ado"=>"6.01-7.00"  
	 elsif draw_odds >= 7.01 && draw_odds <= 8.00
	 	post_data = post_data.merge  "7.01-8.00Ado"=>"7.01-8.00"  
	 elsif draw_odds >= 8.01 && draw_odds <= 10.00
	 	post_data = post_data.merge  "8.01-10.00Ado"=>"8.01-10.00"  
	 elsif draw_odds >= 10.01 && draw_odds <= 100
	 	post_data = post_data.merge  "10.01-100Ado"=>"10.01-100"  
	 end

	 if away_odds >= 1 && away_odds <= 1.25
		post_data = post_data.merge  "0-1.25Aao"=>"0-1.25"  
	elsif away_odds >= 1.26 && away_odds <= 1.50
    	post_data = post_data.merge  "1.26-1.50Aao"=>"1.26-1.50"  
    elsif away_odds >= 1.51 && away_odds <= 1.80
    	post_data = post_data.merge  "1.51-1.80Aao"=>"1.51-1.80"  
    elsif away_odds >= 1.81 && away_odds <= 2.10
    	post_data = post_data.merge  "1.81-2.10Aao"=>"1.81-2.10"  
    elsif away_odds >= 2.11 && away_odds <= 2.50
    	post_data = post_data.merge  "2.11-2.50Aao"=>"2.11-2.50"  
    elsif away_odds >= 2.51 && away_odds <= 3.00
    	post_data = post_data.merge  "2.51-3.00Aao"=>"2.51-3.00"  
    elsif away_odds >= 3.01 && away_odds <= 4.00
    	post_data = post_data.merge  "3.01-4.00Aao"=>"3.01-4.00"  
    elsif away_odds >= 4.01 && away_odds <= 5.00
    	post_data = post_data.merge  "4.01-5.00Aao"=>"4.01-5.00"  
    elsif away_odds >= 5.01 && away_odds <= 6.00
    	post_data = post_data.merge  "5.01-6.00Aao"=>"5.01-6.00"  
    elsif away_odds >= 6.01 && away_odds <= 7.00
    	post_data = post_data.merge  "6.01-7.00Aao"=>"6.01-7.00"  
    elsif away_odds >= 7.01 && away_odds <= 100
    	post_data = post_data.merge  "7.01-100Aao"=>"7.01-100"  
    end
    
    p "<b>#{home_team} vs #{away_team}</b><br>"
    
    doc = Nokogiri::HTML(a.post('http://www.football-bet-data.yows.co.uk/index.asp', post_data).content)
    table = doc.xpath("//table[contains(@id, 'table-3')]")
    rows = table.xpath(".//tr").drop(1)
    for row in rows
    	buffer = []
    	date = row.children[0].text
    	league = row.children[1].text.strip
    	home_team = row.children[2].text
    	away_team = row.children[3].text
    	final_score = row.children[4].text
    	result = row.children[5].text
    	tot_goals = row.children[8].text.to_i
    	h_odds = row.children[9].text.strip.to_f
    	d_odds = row.children[10].text.strip.to_f
    	a_odds = row.children[11].text.strip.to_f
    	cs_odds = row.children[12].text.strip.to_f
    	cs_prediction = row.children[13].text
    	prediction = row.children[14].text
    	goals_prediction = row.children[15].text.strip.to_i
    	pred_h_odds = row.children[16].text.strip.to_f
    	pred_d_odds = row.children[17].text.strip.to_f
    	pred_a_odds = row.children[18].text.strip.to_f
    	pred_gg_odds = row.children[19].text.strip.to_f
    	buffer << date << league << home_team << away_team << final_score << result << tot_goals << h_odds << d_odds << a_odds << cs_odds << cs_prediction << prediction << goals_prediction << pred_h_odds << pred_d_odds << pred_a_odds << pred_gg_odds
    	#p buffer
    end
    #p "------------------"
    overall_table = doc.xpath("//table[contains(@bordercolor, '#e5e5e5')]")
    overall_rows = overall_table.xpath(".//tr")
    p overall_rows.text
    i += 1
    end
   end
end



#CLASS STAT END - METHODS COMING NEXT
def simulate_bets(days)
  picks = []
  days.each{
    |date, day|
    number_of_matches = day[0]
    if number_of_matches >= 4
      serie = []
      matches = day[9].to_a
      random_indexes = (0..(matches.length-1)).to_a.sample(4)
      for index in random_indexes
        serie << matches[index]
      end
      picks << serie
    end
  }
  return picks
end

def bookie_percentages(oo, home_win_odds)
	i = 0
	i_h = 0
	i_a = 0
	n = 0
	h = 0
	d = 0
	d_h = 0
	d_a = 0
	a = 0
	tot_i = 0
	tot_i_h = 0
	tot_i_a = 0
	tot_n = 0
	tot_h = 0
	tot_d = 0
	tot_d_h = 0
	tot_d_a = 0
	tot_a = 0
	min_odds = home_win_odds
	max_odds = home_win_odds + 0.05
	date_array = []
	date_hash = {}
	2.upto(13931) do |line|
		date = oo.cell(line,'A')
		home = oo.cell(line,'B')
		away = oo.cell(line,'C')
		h_score = oo.cell(line,'D')
		a_score = oo.cell(line, 'E')
		final_score = oo.cell(line, 'F')
		result = oo.cell(line, 'G')
		h_odds = oo.cell(line, 'H')
		d_odds = oo.cell(line, 'I')
		a_odds = oo.cell(line, 'J')
		league = oo.cell(line, 'K')
		if date
			odds_array = [h_odds, d_odds, a_odds]
			fav_odds = [h_odds, d_odds, a_odds].min
			if odds_array.index(fav_odds) == 0
				fav = "H"
			elsif odds_array.index(fav_odds) == 1
				fav = "D"
			elsif odds_array.index(fav_odds) == 2
				fav = "A"
			end
			#date_hash[date][0]: total number of matches
			#date_hash[date][1]: number of right matches
			#date_hash[date][2]: number of right home win predictions
			#date_hash[date][3]: number of right away win predictions
			#date_hash[date][4]: number of unexpected home wins
			#date_hash[date][5]: number of unexpected draws
			#date_hash[date][6]: number of unexpected draws with home favorite
	  		#date_hash[date][7]: number of unexpected draws with away favorite
	  		#date_hash[date][8]: number of unexpected away wins
	  		#date_hash[date][9]: hash with matches of the day
	  		if date_array.index(date)
		  		if fav_odds >= min_odds && fav_odds <= max_odds
			  		match_name = home + " vs " + away
			  		n = n + 1
			  		tot_n = tot_n + 1
			  		date_hash[date][0] = n
			  		if fav == result
				  		i = i + 1
				  		tot_i = tot_i + 1
				  		date_hash[date][1] = i
				  		if fav == "H"
					  		i_h = i_h + 1
					  		tot_i_h = tot_i_h + 1
					  		date_hash[date][2] = i_h
					  		date_hash[date][9] = date_hash[date][9].merge({match_name => ["H", "H"]})
					  	elsif fav == "A"
					  		i_a = i_a + 1
					  		tot_i_a = tot_i_a + 1
					  		date_hash[date][3] = i_a
					  		date_hash[date][9] = date_hash[date][9].merge({match_name => ["A", "A"]})
					  	end
					elsif fav != result && result == "H"
						h = h + 1
						tot_h = tot_h + 1
						date_hash[date][4] = h
						date_hash[date][9] = date_hash[date][9].merge({match_name => ["A", "H"]})
					elsif fav != result && result == "D"
						d = d + 1
						tot_d = tot_d + 1
						date_hash[date][5] = d
						if fav == "H"
							d_h = d_h + 1
							tot_d_h = tot_d_h + 1
							date_hash[date][6] = d_h
							date_hash[date][9] = date_hash[date][9].merge({match_name => ["H", "D"]})
						elsif fav == "A"
							d_a = d_a + 1
							tot_d_a = tot_d_a + 1
							date_hash[date][7] = d_a
							date_hash[date][9] = date_hash[date][9].merge({match_name => ["A", "D"]})
						end
						#p d_odds
					elsif fav != result && result == "A"
						a = a + 1
						tot_a = tot_a + 1
						date_hash[date][8] = a
						date_hash[date][9] = date_hash[date][9].merge({match_name => ["H", "A"]})
						#p a_odds
					end
				end
			else
				i = 0
				i_h = 0
				i_a = 0
				n = 0
				h = 0
				d = 0
				d_h = 0
				d_a = 0
				a = 0
				if fav_odds >= min_odds && fav_odds <= max_odds
					match_name = home + " vs " + away
					n = n + 1
					tot_n = tot_n + 1
					date_array << date
					date_hash.store(date, [n])
					if fav == result
						i = i + 1
						tot_i = tot_i + 1
						date_hash[date][1] = i
						if fav == "H"
							i_h = i_h + 1
							tot_i_h = tot_i_h + 1
							date_hash[date][2] = i_h
							date_hash[date][9] = {match_name => ["H", "H"]}
						elsif fav == "A"
							i_a = i_a + 1
							tot_i_a = tot_i_a + 1
							date_hash[date][3] = i_a
							date_hash[date][9] = {match_name => ["A", "A"]}
						end
					elsif fav != result && result == "H"
						h = h + 1
						tot_h = tot_h + 1
						date_hash[date][4] = h
						date_hash[date][9] = {match_name => ["A", "H"]}
					elsif fav != result && result == "D"
						d = d + 1
						tot_d = tot_d + 1
						date_hash[date][5] = d
						if fav == "H"
							d_h = d_h + 1
							tot_d_h = tot_d_h + 1
							date_hash[date][6] = d_h
							date_hash[date][9] = {match_name => ["H", "D"]}
						elsif fav == "A"
							d_a = d_a + 1
							tot_d_a = tot_d_a + 1
							date_hash[date][7] = d_a
							date_hash[date][9] = {match_name => ["A", "D"]}
						end
						#p d_odds
					elsif fav != result && result == "A"
						a = a + 1
						tot_a = tot_a + 1
						date_hash[date][8] = a
						date_hash[date][9] = {match_name => ["H", "A"]}
						#p a_odds
					end
				end
			end
		end
	end
	 
	
	  p "#{tot_i} right out of #{tot_n} >= #{min_odds} && <= #{max_odds}, out of which #{tot_i_h} home wins and #{tot_i_a} away wins"  
	  p "#{tot_h} unexpected home wins"  
	  p "#{tot_d} unexpected draws, out of which #{tot_d_h} were home favs and #{tot_d_a} were away favs"  
	  p "#{tot_a} unexpected away wins"  
	  p "BOOKIE PERCENTAGES:"  
	 
	  right_home_win_perc = (tot_i_h.to_f/(tot_i_h + tot_d_h + tot_a).to_f) * 100
	  right_away_win_perc = (tot_i_a.to_f/(tot_i_a + tot_d_a + tot_h).to_f) * 100
	 
	  p "right home win predictions: #{right_home_win_perc}%"  
	  p "right away win predictions: #{right_away_win_perc}%"  
	
	 
	montecarlo_generated_series = simulate_bets(date_hash)
	number_of_black_swans = 0
	for serie in montecarlo_generated_series
		success = false
		for bet in serie
			if bet[1][0] == bet[1][1]
				success = true
			end
		end
		if success == false
			number_of_black_swans = number_of_black_swans + 1
		end
	end
	return number_of_black_swans, right_home_win_perc, right_away_win_perc
end
