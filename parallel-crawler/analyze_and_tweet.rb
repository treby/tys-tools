require 'twitter'
require 'rubimas'
require 'optparse'
require 'time'
require 'csv'

params = ARGV.getopts('', 'reward:', 'prev_tweet:')
reward = params['reward'] ? params['reward'].to_i : nil
prev_tweet = params['prev_tweet']

def readable_unit(number)
  digit = number.abs.to_s.length
  digit_limit = 4
  num, unit = if digit < 10_000.to_s.length
                [number, '']
              elsif digit < 100_000_000.to_s.length
                [(number / 10_000.0).round(4), '万']
              else
                [(number / 100_000_000.0).round(4), '億']
              end

  after_digit = num == num.to_i ? 0 : digit_limit - num.to_i.abs.to_s.length
  after_digit <= 0 ? "#{num.to_i}#{unit}" : "#{format("%.#{after_digit}f", num)}#{unit}"
end

def best_rankers(directory)
  (14..50).each_with_object({}) do |idol_id, obj|
    name = nil
    CSV.open("#{File.dirname(__FILE__)}/#{directory}/tys_#{idol_id}_ranking.tsv", col_sep: "\t") do |csv|
      name = csv.readline[2]
    end
    obj[idol_id] = name
  end
end

def adjust_space(text, length)
  text_length = text.chars.map { |c| c.ascii_only? ? 1 : 2 }.sum
  ws_count = length - text_length
  "#{text + (' ' * ws_count)}"
end

current_and_prev_csv_files = Dir.glob(File.dirname(__FILE__) + '/outputs/*.csv').sort[-2..-1].reverse
current_time, prev_time = current_and_prev_csv_files.map { |f| Time.strptime(File.basename(f), '%Y%m%d-%H%M.csv') }
current_and_prev_points = current_and_prev_csv_files.map { |csv_file| CSV.open(csv_file).to_a.transpose.map{ |arr| arr.shift; arr.map(&:to_i) }[1..-1] }
idol_points = (14..50).map{ |n| Rubimas.find(n) }.zip(*current_and_prev_points)

idol_stats = idol_points.map do |idol_ranking_prev_ranking|
  idol, ranking, prev_ranking = idol_ranking_prev_ranking
  point_of = -> (rank) { ranking[rank - 1] }
  prev_point_of = -> (rank) { prev_ranking[rank - 1] }

  { idol: idol,
    point_of: point_of,
    prev_point_of: prev_point_of,
    velocity_of: -> (rank) { point_of.call(rank) - prev_point_of.call(rank) },
    diff: -> (n) { point_of.call(reward) - point_of.call(reward + n) }
  }
end

# 500位までの合計ポイント
total_500_ranking = idol_points.map do |idol_ranking_prev_ranking|
  idol, ranking, prev_ranking = idol_ranking_prev_ranking
  current_total = ranking.sum
  prev_total = prev_ranking.sum
  { idol: idol,
    current_total: current_total,
    prev_total: prev_total,
    velocity: current_total - prev_total
  }
end.sort_by{ |i| i[:current_total] }.reverse.map.with_index(1) do |total, rank|
  total[:current_rank] = rank
  total
end.sort_by{ |i| i[:prev_total] }.reverse.each.with_index(1) do |total, rank|
  total[:prev_rank] = rank
end

# ランキング
target_ranks = [1, 150, 200, 254, 300]
rankings = target_ranks.each_with_object({}) do |rank, obj|
  stats = idol_stats.map { |stats| { idol: stats[:idol], point: stats[:point_of].call(rank), velocity: stats[:velocity_of].call(rank) } }
  obj[rank] = stats.sort_by { |stat| stat[:point] }.reverse
end

# 向こう崖が小さい / 大きい
target_diffs = [1, 5, 10, 15, 20]
cliff_rankings = target_diffs.each_with_object({}) do |diff, obj|
  stats = idol_stats.map { |stats| { idol: stats[:idol], diff: stats[:diff].call(diff) } }
  obj[diff] = stats.sort_by { |stat| stat[:diff] }
end

total_500_summaries = ["『TH@NK YOU for SMILE!!』 #{current_time.strftime('%Y/%m/%d %H:%M')}時点"]
total_500_summaries << ''
total_500_summaries << adjust_space("【上位500位合計ポイントランキング】", 40)
total_500_summaries += total_500_ranking.map do |record|
  point_and_velocity = "#{readable_unit(record[:current_total])}(+#{readable_unit(record[:velocity])})"
  line = "#{'%02d' % record[:current_rank]}位 #{record[:idol].name.to_s.ljust(5, '　')}: #{point_and_velocity}"
  adjust_space(line, 40)
end

best_1_ranking = rankings.delete(1)
best_1_summaries = ['']
best_1_summaries << ''
best_1_summaries << "【アイドル横断全一ランキング】"
best_1_dictionary = best_rankers(current_and_prev_csv_files.first.sub('.csv', ''))
best_1_summaries += best_1_ranking.map.with_index(1) do |record, rank|
  velocity = record[:velocity] > 0 ? "(+#{readable_unit(record[:velocity])})" : ''
  point_and_velocity = "#{readable_unit(record[:point])}#{velocity}"
  "#{'%02d' % rank}位 #{record[:idol].name.to_s.ljust(5, '　')}: #{adjust_space(point_and_velocity, 18)} by #{best_1_dictionary[record[:idol].id]}"
end

filebase = 'outputs/20170317_tys_best'
open("#{filebase}.txt", 'w') { |f| f.puts total_500_summaries.zip(best_1_summaries).map(&:join).join("\n") }
`convert -background white -fill black -font migu-1m-regular.ttf -pointsize 18 -interline-spacing 4 -kerning 0.5 label:@#{filebase}.txt #{filebase}.png`

summaries = []
summaries << "『TH@NK YOU for SMILE』 枠#{reward}"
summaries << "集計期間: #{prev_time.strftime('%Y/%m/%d %H:%M')}〜#{current_time.strftime('%Y/%m/%d %H:%M')}"
summaries << ''

column_width = 37
# アイドル横断ランキング(1, 150, 200, 254)
summaries << '【アイドル横断ランキング】'
summaries << target_ranks[1..-1].map { |rank| adjust_space("#{rank}位ボーダー", column_width) }.join
summaries += rankings.values.map do |ranking|
  ranking[0...20].map.with_index(1) do |record, rank|
    adjust_space("#{'%02d' % rank}位 #{record[:idol].name.shorten.ljust(4, '　')}: #{readable_unit(record[:point])}(+#{readable_unit(record[:velocity])})", column_width)
  end
end.transpose.map(&:join)
summaries << ''

# 落差の小ささランキング → ボーダーが上がりやすい
summaries << '【落差ランキング】'
summaries << '[差が小さい]'
summaries << target_diffs.map { |diff| adjust_space("+#{diff}(#{reward + diff}位)との差", 30) }.join
summaries += cliff_rankings.values.map do |ranking|
  ranking[0...5].map.with_index(1) do |record, rank|
    adjust_space("#{'%02d' % rank}位 #{record[:idol].name.to_s.ljust(5, '　')}: #{readable_unit(record[:diff])}", 30)
  end
end.transpose.map(&:join)
summaries << ''

# 落差の大きさランキング → ボーダーが下がりやすい
summaries << '[差が大きい]'
summaries << target_diffs.map { |diff| adjust_space("+#{diff}(#{reward + diff}位)との差", 30) }.join
summaries += cliff_rankings.values.map do |ranking|
  ranking.reverse[0...5].map.with_index(1) do |record, rank|
    adjust_space("#{'%02d' % rank}位 #{record[:idol].name.to_s.ljust(5, '　')}: #{readable_unit(record[:diff])}", 30)
  end
end.transpose.map(&:join)
summaries << ''

tweets = []
tweets << "現在の注目アイドルは#{cliff_rankings[[5,10,15,20].sample(1).first][0...3].map { |cl| cl[:idol].name.shorten }.join('、')}です。"

open('outputs/20170317_tys_runners.txt', 'w') { |f| f.write summaries.join("\n") }
`convert -background white -fill black -font migu-1m-regular.ttf -pointsize 18 -interline-spacing 4 -kerning 0.5 label:@outputs/20170317_tys_runners.txt outputs/20170317_tys_runners.png`

if prev_tweet
  client = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  media_ids = ['outputs/20170317_tys_best.png', 'outputs/20170317_tys_runners.png'].map do |media_path|
    client.upload(File.new(media_path))
  end
  tweet = client.update "", media_ids: media_ids.first, in_reply_to_status_id: prev_tweet
  client.update "#{tweets.join("\n")}\nhttp://mlborder.com/misc/runners?event=tys", media_ids: media_ids.last, in_reply_to_status_id: tweet.id
end
