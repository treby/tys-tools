require 'twitter'
require 'rubimas'
require 'optparse'
require 'csv'

params = ARGV.getopts('', 'reward:', 'prev_tweet:')
reward = params['reward'] ? params['reward'].to_i : nil
prev_tweet = params['prev_tweet']

def readable_unit(number)
  digit = number.abs.to_s.length
  digit_limit = 4
  num, unit = if digit < 10_000.to_s.length
                [number, '']
              elsif digit < 10_000_000_000.to_s.length
                [(number / 10_000.0).round(4), '万']
              else
                [(number / 100_000_000.0).round(4), '億']
              end

  after_digit = num == num.to_i ? 0 : digit_limit - num.to_i.abs.to_s.length
  after_digit <= 0 ? "#{num.to_i}#{unit}" : "#{format("%.#{after_digit}f", num)}#{unit}"
end

idol_points = CSV.open(Dir.glob(File.dirname(__FILE__) + '/outputs/*.csv').last).to_a.transpose.map{ |arr| arr.shift; arr.map(&:to_i) }[1..-1]
idol_rankings = (14..50).map{ |n| Rubimas.find(n) }.zip(idol_points).map(&:flatten)

idol_rankings.each do |idol_rank|
  idol = idol_rank.first
  puts "＜#{idol.name}＞"
  puts "1位: #{readable_unit(idol_rank[1])}"
  puts "10位: #{readable_unit(idol_rank[10])}"
  puts "100位: #{readable_unit(idol_rank[100])}"
  puts "200位: #{readable_unit(idol_rank[200])}"
  puts "BMD(254位): #{readable_unit(idol_rank[254])}"
  puts "300位: #{readable_unit(idol_rank[300])}"
  puts '====='
  puts "5位先(#{reward + 5}位)との差: #{readable_unit(idol_rank[reward] - idol_rank[reward + 5])}"
  puts "10位先(#{reward + 10}位)との差: #{readable_unit(idol_rank[reward] - idol_rank[reward + 10])}"
  puts "20位先(#{reward + 20}位)との差: #{readable_unit(idol_rank[reward] - idol_rank[reward + 20])}"
end

