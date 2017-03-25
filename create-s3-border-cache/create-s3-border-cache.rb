require 'aws-sdk'
require 'influxdb'
require 'time'

Aws.config.update(
  credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
  region: 'ap-northeast-1'
)

class BorderCacheMaker
  def initialize(series_name, start_time, finish_time)
    @series_name = series_name
    @start_time = start_time.to_i
    @finish_time = finish_time.to_i
  end

  def progress
    span = '30m'
    query = "SELECT #{select_target.join(',')} FROM \"#{@series_name}\" WHERE time >= #{@start_time}s AND time <= #{@finish_time + 1}s GROUP BY time(#{span}) fill(previous);"
    client.query(query).first
  end

  private
  def select_target
    columns.map { |column| "MIN(#{column}) AS #{column}" }
  end

  def columns
    return @columns if @columns

    raw_columns = recent_series_data.keys

    columns = raw_columns.select { |k| k.include?('border_') }.sort { |a, b| a.match(/(\d+)/).to_s.to_i <=> b.match(/(\d+)/).to_s.to_i }
    columns += raw_columns.reject do |k|
      k.include?('border_') || %w(time updated_at).include?(k)
    end

    @columns = columns
  end

  def recent_series_data
    unless @recent_series_data
      res = client.query "SELECT * FROM \"#{@series_name}\" ORDER BY time DESC LIMIT 1;"
      @recent_series_data = res.first['values'].first
    end
    @recent_series_data
  end

  def client
    @client = InfluxDB::Client.new(
      ENV['INFLUXDB_DATABASE'],
      host: ENV['INFLUXDB_HOST'],
      user: ENV['INFLUXDB_USER'],
      password: ENV['INFLUXDB_PASS']
    )
  end
end

series_name = '20170317-20170326_hhp'

time = Time.now.strftime('%Y%m%d%H%M')
maker = BorderCacheMaker.new(series_name, Time.parse('2017-03-17 12:00:00 +0900'), Time.parse('2017-03-26 23:59:59 +0900'))
s3_client = Aws::S3::Client.new

s3_client.put_object(bucket: 'mlborder', key: "events/#{series_name}/#{time}.json", body: maker.progress.to_json)
