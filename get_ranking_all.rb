require 'optparse'
require 'mechanize'
require 'csv'
require 'fileutils'
require 'oj'

class GreeCrawler
  attr_reader :agent

  def initialize(email: nil, pass: nil)
    @agent = Mechanize.new
    @agent.user_agent_alias = 'iPhone'
    login_with(email, pass)
    set_apps_cookie
  end

  def login_with(gree_email = nil, gree_pass = nil)
    gree_email ||= ENV['GREE_EMAIL']
    gree_pass ||= ENV['GREE_PASSWORD']

    agent.get('http://gree.jp/?action=reg_opt_top') do |page|
      page.form_with(name: 'login') do |login|
        login.field_with(name: 'user_mail') do |email|
          email.value = gree_email
        end
        login.field_with(name: 'user_password') do |pass|
          pass.value = gree_pass
        end
      end.submit
    end
  end

  def set_apps_cookie(url = nil)
    url ||= 'http://imas.gree-apps.net/app/index.php'
    agent.get("http://pf.gree.net/58737?#{URI.encode_www_form({ url: url })}") do |page|
      page.form_with(name: 'redirect').submit
    end
  end

  def crawl_and_output(filename = nil, event_id = nil, idol_id = nil, start_page = 1)
    current_page = start_page
    result = visit_ranking_page(event_id, idol_id, current_page)
    ranker_list = []
    while current_page < 50
      ranker_list += result

      if ranker_list.count > 99
        CSV.open(filename, 'a', encoding: 'utf-8', col_sep: "\t") do |tsv|
          ranker_list.each { |ranker| tsv << [ranker[:rank], ranker[:id], ranker[:name], ranker[:point]] }
        end
        ranker_list = []
      end
      sleep 0.1
      current_page += 1
      result = visit_ranking_page(event_id, idol_id, current_page)
    end

    if ranker_list.any?
      CSV.open(filename, 'a', encoding: 'utf-8', col_sep: "\t") do |tsv|
        ranker_list.each { |ranker| tsv << [ranker[:rank], ranker[:id], ranker[:name], ranker[:point]] }
      end
    end
  end

  def visit_ranking_page(event_id = nil, idol_id = nil, page_num = nil)
    ranking_page = "http://imas.gree-apps.net/app/index.php/event/#{event_id}/ranking/general?page=%d&idol=%d"

    url = ranking_page % [page_num, idol_id]
    puts "page-#{page_num}(#{idol_id}) : #{url}"

    rankers = []
    @agent.get(url) do |page|
      lis = page.search('.list-bg > li')
      next unless lis.any?

      rankers = lis.map do |li|
        user_info_area = li.search('td.user-list-st').first
        user_link = user_info_area.search('a').first
        user_id = user_link ? user_link.attributes['href'].value.split('/').last.to_i : ENV['IMAS_ACCOUNT_ID'].to_i

        user_info_list = user_info_area.search('br').map { |br| br.previous.text.strip }
        user_name = user_info_list[1]
        user_rank = user_info_list.first.match(/(\d+)位/)[1]
        user_point = user_info_list[2].match(/([\d|,]+)/)[1].gsub(',', '').to_i


        { rank: user_rank, id: user_id, name: user_name, point: user_point }
      end
    end
    rankers
  end
end

params = ARGV.getopts('f:s:', 'event_id:')
event_id = params['event_id']
series_name = params['s']

current = Time.now.strftime('%Y%m%d-%H%M')
auths = Oj.load(open('confidential.json'))['accounts']
thread_count = auths.count

groups = Array.new(thread_count).map.with_index do |_, index|
  (14..50).select { |id| (id % thread_count) == index }
end

FileUtils.mkdir_p(current) unless FileTest.exist?(current)

ths = groups.map.with_index do |thread_group, index|
  Thread.new do
    auth = auths[index]
    crawler = GreeCrawler.new(email: auth['email'], pass: auth['pass'])
    puts "========== Thread #{index} START ==========="
    thread_group.each do |idol_id|
      crawler.crawl_and_output("#{current}/tys_#{'%02d' % idol_id}_ranking.tsv", event_id, idol_id, 1)
    end
    puts "========== Thread #{index} FINISH =========="
  end
end

ths.each(&:join)
