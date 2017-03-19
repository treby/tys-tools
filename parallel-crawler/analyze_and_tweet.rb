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

source = ""

idol_rankings.each do |idol_rank|
  idol = idol_rank.first
  source += "＜#{idol.name}＞\n"
  source += "1位: #{readable_unit(idol_rank[1])}\n"
  source += "10位: #{readable_unit(idol_rank[10])}\n"
  source += "100位: #{readable_unit(idol_rank[100])}\n"
  source += "200位: #{readable_unit(idol_rank[200])}\n"
  source += "BMD(254位): #{readable_unit(idol_rank[254])}\n"
  source += "300位: #{readable_unit(idol_rank[300])}\n"
  source += "=====\n"
  source += "5位先(#{reward + 5}位)との差: #{readable_unit(idol_rank[reward] - idol_rank[reward + 5])}\n"
  source += "10位先(#{reward + 10}位)との差: #{readable_unit(idol_rank[reward] - idol_rank[reward + 10])}\n"
  source += "20位先(#{reward + 20}位)との差: #{readable_unit(idol_rank[reward] - idol_rank[reward + 20])}\n"
end

puts source
if prev_tweet
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end
  client.update "ランナー分布を更新しました。\nhttp://mlborder.com/misc/runners?event=tys", in_reply_to_status_id: prev_tweet
end
