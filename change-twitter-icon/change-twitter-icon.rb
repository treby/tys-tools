require 'twitter'
require 'optparse'

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
  config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
  config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
  config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
end

params = ARGV.getopts('', 'idol_id:')
idol_id = params['idol_id']
client.update_profile_image(open("#{File.dirname(__FILE__)}/icons/#{idol_id}.png"))
