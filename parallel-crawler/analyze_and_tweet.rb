require 'twitter'
require 'rubimas'
require 'optparse'
require 'csv'
require 'pp'

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

def ajust_space(text, length)
  text_length = text.chars.map { |c| c.ascii_only? ? 1 : 2 }.sum
  ws_count = length - text_length
  "#{text + (' ' * ws_count)}"
end

idol_points = CSV.open(Dir.glob(File.dirname(__FILE__) + '/outputs/*.csv').last).to_a.transpose.map{ |arr| arr.shift; arr.map(&:to_i) }[1..-1]
idol_rankings = (14..50).map{ |n| Rubimas.find(n) }.zip(idol_points).map(&:flatten)

idol_summaries = idol_rankings.map do |idol_rank|
  summary = []
  idol = idol_rank.first
  summary << "＜#{idol.name}＞"
  summary << "1位: #{readable_unit(idol_rank[1])}"
  summary << "100位: #{readable_unit(idol_rank[100])}"
  summary << "200位: #{readable_unit(idol_rank[200])}"
  summary << "BMD(254位): #{readable_unit(idol_rank[254])}"
  summary << "300位: #{readable_unit(idol_rank[300])}"
  summary << ""
  summary << "+5(#{reward + 5}位)との差: #{readable_unit(idol_rank[reward] - idol_rank[reward + 5])}"
  summary << "+10(#{reward + 10}位)との差: #{readable_unit(idol_rank[reward] - idol_rank[reward + 10])}"
  summary << "+20(#{reward + 20}位)との差: #{readable_unit(idol_rank[reward] - idol_rank[reward + 20])}"
  summary << ""
  summary << ""
end

lines = idol_summaries.each_slice(4).map do |line_idols|
  line_idols.transpose.map do |elm|
    "#{elm.map { |li| ajust_space(li, 30) }.join}"
  end
end

`convert -background white -fill black -font migu-1m-regular.ttf -pointsize 18 -interline-spacing 4 -kerning 0.5 label:'#{lines.join("\n")}' outputs/2017_tys_runners.png`

if prev_tweet
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end
  client.update "ランナー分布を更新しました。\nhttp://mlborder.com/misc/runners?event=tys", in_reply_to_status_id: prev_tweet
end
