if system('bundle exec ruby get_ranking_all.rb -e 350; bundle exec ruby make_csv.rb')
  system('bundle exec ruby upload_csv_to_s3.rb')
else
  puts '=== Error Occurred! ==='
end
