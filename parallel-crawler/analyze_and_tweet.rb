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

def ajust_space(text, length)
  text_length = text.chars.map { |c| c.ascii_only? ? 1 : 2 }.sum
  ws_count = length - text_length
  "#{text + (' ' * ws_count)}"
end

idol_points = CSV.open(Dir.glob(File.dirname(__FILE__) + '/outputs/*.csv').sort.last).to_a.transpose.map{ |arr| arr.shift; arr.map(&:to_i) }[1..-1]
idol_stats = (14..50).map{ |n| Rubimas.find(n) }.zip(idol_points).map do |idol_and_ranking|
  idol, ranking = idol_and_ranking
  point_of = -> (rank) { ranking[rank - 1] }

  { idol: idol,
    ranking: ranking,
    point_of: point_of,
    diff: -> (n) { point_of.call(reward) - point_of.call(reward + n) }
  }
end

# ランキング
target_ranks = [1, 10, 150, 200, 254]
rankings = target_ranks.each_with_object({}) do |rank, obj|
  stats = idol_stats.map { |stats| { idol: stats[:idol], point: stats[:point_of].call(rank) } }
  obj[rank] = stats.sort_by { |stat| stat[:point] }.reverse
end

# 向こう崖が小さい / 大きい
target_diffs = [1, 5, 10, 15, 20]
cliff_rankings = target_diffs.each_with_object({}) do |diff, obj|
  stats = idol_stats.map { |stats| { idol: stats[:idol], diff: stats[:diff].call(diff) } }
  obj[diff] = stats.sort_by { |stat| stat[:diff] }
end

summaries = []
# アイドル横断ランキング(1, 150, 200, 254)
summaries << '【アイドル横断ランキング】'
summaries << target_ranks.map { |rank| ajust_space("ランキング#{rank}位", 30) }.join
summaries += rankings.values.map do |ranking|
  ranking[0...10].map.with_index(1) do |record, rank|
    ajust_space("#{'%02d' % rank}位 #{record[:idol].name.to_s.ljust(5, '　')} : #{readable_unit(record[:point])}", 30)
  end
end.transpose.map(&:join)
summaries << ''

# 落差の小ささランキング → ボーダーが上がりやすい
summaries << '【落差ランキング】'
summaries << '[差が小さい]'
summaries << target_diffs.map { |diff| ajust_space("+#{diff}(#{reward + diff}位)との差", 30) }.join
summaries += cliff_rankings.values.map do |ranking|
  ranking[0...10].map.with_index(1) do |record, rank|
    ajust_space("#{'%02d' % rank}位 #{record[:idol].name.to_s.ljust(5, '　')} : #{readable_unit(record[:diff])}", 30)
  end
end.transpose.map(&:join)
summaries << ''


# 落差の大きさランキング → ボーダーが下がりやすい
summaries << '[差が大きい]'
summaries << target_diffs.map { |diff| ajust_space("+#{diff}(#{reward + diff}位)との差", 30) }.join
summaries += cliff_rankings.values.map do |ranking|
  ranking.reverse[0...10].map.with_index(1) do |record, rank|
    ajust_space("#{'%02d' % rank}位 #{record[:idol].name.to_s.ljust(5, '　')} : #{readable_unit(record[:diff])}", 30)
  end
end.transpose.map(&:join)
summaries << ''

tweets = []
tweets << "ピックアップアイドルは#{cliff_rankings[[5,10,15,20].sample(1).first][0...3].map { |cl| cl[:idol].name.shorten }.join(',')}です。"

open('outputs/20170317_tys_runners.txt', 'w') { |f| f.puts "TH@NK YOU for SMILE 枠#{reward}\n "; f.write summaries.join("\n") }
`convert -background white -fill black -font migu-1m-regular.ttf -pointsize 18 -interline-spacing 4 -kerning 0.5 label:@outputs/20170317_tys_runners.txt outputs/20170317_tys_runners.png`

if prev_tweet
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end
  client.update_with_media "ランナー分布の更新完了。#{tweets.join("\n")}\nhttp://mlborder.com/misc/runners?event=tys", open('outputs/20170317_tys_runners.png'), in_reply_to_status_id: prev_tweet
end
