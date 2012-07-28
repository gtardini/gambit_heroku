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
							"tabella (partial) accuracy percentage: #{perc[0].percentage}%"  
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
							matches_data[match_name][12]= perc[0][0]
							matches_data[match_name][13]= number_of_black_swans
						end
				else
					p "tabella accuracy percentage not computed."  
				end
		else
	 	end
	 end
	 
	 #ORDERS MATCHES BY CONVENIENCE
	 matches_chance_weighted_convenience_ordered_data = {}
	 matches_chance_weighted_convenience_ordered_data = matches_data.sort_by {|key, value| value[9]} 
	 matches_chance_weighted_convenience_ordered_data.each{|key, value|
		 value  
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
				j  
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
   end
end


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
	 
	
	  "#{tot_i} right out of #{tot_n} >= #{min_odds} && <= #{max_odds}, out of which #{tot_i_h} home wins and #{tot_i_a} away wins"  
	  "#{tot_h} unexpected home wins"  
	  "#{tot_d} unexpected draws, out of which #{tot_d_h} were home favs and #{tot_d_a} were away favs"  
	  "#{tot_a} unexpected away wins"  
	  "BOOKIE PERCENTAGES:"  
	 
	  right_home_win_perc = (tot_i_h.to_f/(tot_i_h + tot_d_h + tot_a).to_f) * 100
	  right_away_win_perc = (tot_i_a.to_f/(tot_i_a + tot_d_a + tot_h).to_f) * 100
	 
	  "right home win predictions: #{right_home_win_perc}%"  
	  "right away win predictions: #{right_away_win_perc}%"  
	
	 
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
