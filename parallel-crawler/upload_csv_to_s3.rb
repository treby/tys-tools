require 'aws-sdk'

Aws.config.update(
  credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
  region: 'ap-northeast-1'
)

source_file = Dir.glob(File.dirname(__FILE__) + '/outputs/*.csv').last
filename = File.basename(source_file)

s3_client = Aws::S3::Client.new
s3_client.put_object(bucket: 'mlborder', key: "runners/tys/#{filename}", body: open(source_file))
