require 'rubimas'
require 'csv'

target_dir = Dir.glob("#{File.dirname(__FILE__)}/outputs/*").sort.last
updated_at = Time.strptime(target_dir.split('/').last, '%Y%m%d-%H%M')

idolname_and_points = (14..50).map do |idol_id|
  points = []
  CSV.foreach("#{target_dir}/tys_#{idol_id}_ranking.tsv", col_sep: "\t") do |line|
    points << line.last
  end
  [Rubimas.find(idol_id).name.shorten, *points]
end

ranks = idolname_and_points.first.count

CSV.open("#{File.dirname(__FILE__)}/outputs/#{updated_at.strftime('%Y%m%d-%H%M')}.csv", 'w') do |csv|
  [['rank', *(1...ranks).to_a], *idolname_and_points].transpose.each { |line| csv << line }
end
