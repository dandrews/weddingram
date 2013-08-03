# encoding: utf-8

class Article < ActiveRecord::Base
  DEFAULT_COLUMNS_TO_INCLUDE = %w(id url title published_on year month day article_text stripped_text summary image_url is_wedding)
  MAX_NGRAM_SIZE = 5
  TOTAL_KEY = "ngram:totals"
  NGRAM_ALL_YEARS_KEY = "ngram:all_years"
  DEFAULT_IMAGE_URL = 'http://i.imgur.com/dlrddMw.gif'
  
  default_scope select(DEFAULT_COLUMNS_TO_INCLUDE).where(:is_wedding => true)
  
  def self.ngram_redis
    $redis
  end
  
  def self.all_years
    # ngram_redis.zrange(NGRAM_ALL_YEARS_KEY, 0, 100)
    (1981..2013).to_a
  end
  
  def self.sorted_set_key(year, n)
    [year, n].join(":")
  end
  
  def self.pretty_ngram_summary(year, n, options = {})
    key = sorted_set_key(year, n)
    raw = ngram_redis.zrevrange(key, options[:offset] || 0, (options[:limit] || 10) - 1, :with_scores => true)
    
    raw.each_slice(2){|ary| puts "#{ary[0]} => #{ary[1].to_i}"}
    nil
  end
  
  def self.ngram_query(terms, smoothing = 0)
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
    
    years = all_years
    
    output = years.inject([]) do |ary, year|
      key = Article.sorted_set_key(year, n)
      member = words.join(" ")

      # hsh[year] = {:count => ngram_redis.zscore(key, member).to_i, :total => ngram_redis.zscore(TOTAL_KEY, key).to_i}
      # hsh[year][:frac] = hsh[year][:count].to_f / hsh[year][:total] rescue nil
      # hsh
      
      ary << ngram_redis.zscore(key, member).to_f / ngram_redis.zscore(TOTAL_KEY, key).to_i
      ary
    end
    
    # TO DO: smooth with weighted averages instead of simple
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
  
  def self.search(terms, opts = {})
    limit = opts[:limit] || 3
    n = terms.size
    qry_text = ""
    
    terms.each_with_index do |t, ix|
      qry_text << "#{' OR' if ix > 0} stripped_text LIKE ?"
    end
    
    conditions = [qry_text] + terms.map{|t| "%#{t}%" }
    
    Article.where(conditions).
            order("random()").
            limit(limit)
  end
  
  def image_url
    read_attribute('image_url').presence || DEFAULT_IMAGE_URL
  end
  
  def canonical_url
    url.gsub(/\?.*$/, '')
  end
end