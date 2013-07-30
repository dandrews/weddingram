# encoding: utf-8

class Article < ActiveRecord::Base
  # ngram stuff
  
  MAX_NGRAM_SIZE = 5
  
  def self.all_years
    (1981..2013).to_a
  end
  
  def self.sorted_set_key(year, n)
    [year, n].join(":")
  end
  
  TOTAL_KEY = "ngram:totals"
  
  def self.regenerate_all_ngram_data(n = (1..MAX_NGRAM_SIZE).to_a)
    all_years.each{|y| self.delay.generate_ngram_data(y, n)}
  end
  
  def self.pretty_ngram_summary(year, n, options = {})
    key = sorted_set_key(year, n)
    raw = $redis.zrevrange(key, options[:offset] || 0, (options[:limit] || 10) - 1, :with_scores => true)
    
    raw.each_slice(2){|ary| puts "#{ary[0]} => #{ary[1].to_i}"}
    nil
  end
  
  def self.generate_ngram_data(year, n)
    puts "BEGINNING CALCULATION FOR #{year}"
    
    # to do: clear appropriate keys from redis so we're not double counting
    
    Article.find_each(:conditions => ["year = ? AND is_wedding = true AND text IS NOT NULL", year]) do |a|
      ngrams_hsh = a.ngrams(n)
      
      ngrams_hsh.each do |k, v|
        set_key = Article.sorted_set_key(year, k)
        
        $redis.zincrby(TOTAL_KEY, v.size, set_key)
        
        v.each do |val|
          $redis.zincrby(set_key, 1, val.join(" "))
        end
      end
    end
  end
  
  def process_text_for_ngram_calculation
    # what about apostrophes? used to have \' in the regex as well...
    # "master’s degree"
    # "master's degree"
    text.gsub(/[^[[:word:]]\s\-\&]/, '')
  end
  
  def ngrams(n)
    return unless text.present?
    
    n = Array.wrap(n)
    words = process_text_for_ngram_calculation.split(" ")
    
    n.inject({}) do |hsh, this_n|
      this_ngrams = (0..(words.size - this_n)).inject([]) do |ary, i|
        ary << words[i, this_n]
      end
      
      hsh[this_n] = this_ngrams
      hsh
    end
  end
  
  def self.ngram_query_for_web(terms, smoothing = 0)
    terms_hsh = terms.inject(ActiveSupport::OrderedHash.new) do |hsh, term|
      hsh[term] = inner_query(term, smoothing)
      hsh
    end
    
    {:terms => terms_hsh, :years => all_years, :smoothing => smoothing}
  end
  
  # TO DO: cleanup
  def self.inner_query(term, smoothing = 0)
    term.squish!
    words = term.split(" ")
    n = words.size
    
    years = $redis.keys.map{|s| s.first(4).to_i}.uniq.sort.select{|i| i > 0}
    
    # output = years.inject(ActiveSupport::OrderedHash.new) do |hsh, year|
    output = years.inject([]) do |ary, year|
      key = Article.sorted_set_key(year, n)
      # to do: extract separator
      member = words.join(" ")
      # hsh[year] = {:count => $redis.zscore(key, member).to_i, :total => $redis.zscore(TOTAL_KEY, key).to_i}
      # hsh[year][:frac] = hsh[year][:count].to_f / hsh[year][:total] rescue nil
      # hsh
      
      ary << $redis.zscore(key, member).to_f / $redis.zscore(TOTAL_KEY, key).to_i
      ary
    end
    
    if smoothing > 0
      smoothed = []
      output.each_with_index do |val, ix|
        lower = [0, ix - smoothing].max
        upper = [output.size - 1, ix + smoothing].min
        smoothed << output[lower..upper].sum.to_f / (upper - lower + 1)
      end
      
      output = smoothed
    end
    
    output
  end
  
  def self.ngram_query(query)
    terms = query.split(",").map(&:squish)
    
    terms.inject(ActiveSupport::OrderedHash.new) do |hsh, term|
      hsh[term] = Article.inner_query(term)
      hsh
    end
  end
  
  # scraping stuff
  
  MENU_BASE_URL = "http://topics.nytimes.com/topics/reference/timestopics/subjects/w/weddings_and_engagements/index.html"
  ITEMS_PER_PAGE = 10
  
  def self.generate_menu_url(page_num, order = "oldest")
    page_num == 0 ? "#{MENU_BASE_URL}?s=#{order}" : "#{MENU_BASE_URL}?offset=#{page_num * ITEMS_PER_PAGE}&s=#{order}"
  end
  
  # 6362 total pages as of 7/28/2013
  def self.get_article_urls(starting_page = 0, number_of_pages = 1, retry_attempts = 50, sort_order = "oldest")
    menu_headers = {
      "Host" => "topics.nytimes.com",
      "Connection" => "keep-alive",
      "Cache-Control" => "max-age=0",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36",
      "Accept-Encoding" => "gzip,deflate,sdch",
      "Accept-Language" => "en-US,en;q=0.8"
    }
    
    failures = 0
    
    menu_url = generate_menu_url(starting_page, sort_order)
    
    1.upto(number_of_pages) do |i|
      begin
        page_num = starting_page + i - 1
        menu_url = generate_menu_url(page_num, sort_order)
        
        html = RestClient.get(menu_url, menu_headers)
        
        doc = Nokogiri::HTML(html)
        
        links = doc.css("#searchResults .story h5 a").map{|e| e["href"]}
        
        links.each_with_index do |url, ix|
          Article.create(:url => url, :menu_url => menu_url, :menu_offset => ix) rescue ActiveRecord::RecordNotUnique
        end
        
        # alternative: rather than increment offset by 10, get the "next page" link
        # menu_url = base_url + doc.css(".sortBy > .pageNum > a").last["href"]
        
        puts i
        sleep(10) if i % 50 == 0
      rescue => e
        failures += 1
        puts "FAILED ATTEMPT #{failures}: #{e}"
        
        if failures <= retry_attempts
          sleep(10)
          retry
        else
          return "FAILED"
        end
      end
    end
  end
  
  def cache_full_html
    char = url.include?("?") ? "&" : "?"
    url_to_get = "#{url}#{char}pagewanted=all"
    # return url_to_get
    begin
      html = RestClient.get(url_to_get, article_headers)
    rescue RestClient::ResourceNotFound
      html = ""
    end
    
    if !html.valid_encoding?
      ic = Iconv.new('UTF-8', 'WINDOWS-1252')
      html = ic.iconv(html + ' ')[0..-2]
    end
    
    return unless html.valid_encoding? && html.present?
    
    self.full_html = html
    self.save!
  end
  
  def article_headers
    uri = URI.parse(url)
    
    { "Connection" => "keep-alive",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36",
      "Accept-Encoding" => "gzip,deflate,sdch",
      "Accept-Language" => "en-US,en;q=0.8",
      "Host" => uri.host }
  end
  
  def self.get_article_full_htmls(retry_attempts = 50)
    require 'iconv'

    article_headers = {
      "Connection" => "keep-alive",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
      "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36",
      "Accept-Encoding" => "gzip,deflate,sdch",
      "Accept-Language" => "en-US,en;q=0.8"
    }
    # "Host" => "www.nytimes.com",
    # "Referer" => url you just came from
    
    failures = 0
    counter = 0

    conditions = "full_html IS NULL AND url IS NOT NULL AND url LIKE 'http%' AND url NOT LIKE 'http://select.nytimes.com%' AND url NOT LIKE 'http://movies.nytimes.com%'"
    Article.find_each(:conditions => conditions) do |a|
      begin
        counter += 1
        puts counter
        sleep(5) if counter % 50 == 0
        
        char = a.url.include?("?") ? "&" : "?"
        url = "#{a.url}#{char}pagewanted=all"
        
        uri = URI.parse(a.url)
        
        article_headers["Host"] = uri.host
        
        begin
          html = RestClient.get(url, article_headers)
        rescue RestClient::ResourceNotFound
          html = ""
        end
        
        if !html.valid_encoding?
          ic = Iconv.new('UTF-8', 'WINDOWS-1252')
          html = ic.iconv(html + ' ')[0..-2] rescue next
        end
        
        next unless html.valid_encoding? && html.present?
        
        a.full_html = html
        a.save!
      rescue => e
        failures += 1
        puts "FAILED ATTEMPT #{failures} ON #{url}: #{e}"
        
        if failures <= retry_attempts
          sleep(10)
          retry
        else
          return "FAIL"
        end
      end
    end
  end
end