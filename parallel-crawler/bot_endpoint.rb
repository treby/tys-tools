require 'optparse'

params = ARGV.getopts('', 'reward_rank:', 'prev_tweet_id:')
reward_rank = params['reward_rank'] ? params['reward_rank'].to_i : nil
prev_tweet_id = params['prev_tweet_id']

if system('bundle exec ruby get_ranking_all.rb -e 350; bundle exec ruby make_csv.rb')
  system('bundle exec ruby upload_csv_to_s3.rb') && system("bundle exec ruby analyze_and_tweet.rb --reward #{reward_rank} --prev_tweet #{prev_tweet_id}")
else
  raise '=== Error Occurred! ==='
end
