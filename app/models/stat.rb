class Stat < ActiveRecord::Base
	def push_mail
		oo = Openoffice.new("Current.ods")
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
