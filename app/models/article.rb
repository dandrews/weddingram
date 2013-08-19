# encoding: utf-8

class Article < ActiveRecord::Base
  DEFAULT_COLUMNS_TO_INCLUDE = %w(id url title published_on year month day article_text stripped_text summary image_url is_wedding)
  MAX_NGRAM_SIZE = 5
  TOTAL_KEY = "ngram:totals"
  NGRAM_ALL_YEARS_KEY = "ngram:all_years"
  DEFAULT_IMAGE_URL = 'http://i.imgur.com/dlrddMw.gif'
  
  default_scope select(DEFAULT_COLUMNS_TO_INCLUDE).where(:is_wedding => true)
  
  def self.redis
    $redis
  end
  
  def self.all_years
    redis.zrange(NGRAM_ALL_YEARS_KEY, 0, 100).map(&:to_i)
    # (1981..2013).to_a
  end
  
  def self.sorted_set_key(year, n)
    [year, n].join(":")
  end
  
  def self.pretty_ngram_summary(year, n, options = {})
    key = sorted_set_key(year, n)
    raw = redis.zrevrange(key, options[:offset] || 0, (options[:limit] || 10) - 1, :with_scores => true)
    
    raw.each_slice(2){|ary| puts "#{ary[0]} => #{ary[1].to_i}"}
    nil
  end
  
  ALLOWED_MATH_OPERATORS = ["+", "/", "(", ")"]
  
  def self.get_terms_from_query_string(qry)
    regex = %r{[^[[:word:]]\s\-\&#{ALLOWED_MATH_OPERATORS.join('')}]}
    qry.split(",").map{|t| t.squish.gsub(regex, '')}.select(&:present?)
  end
  
  def self.from_redis(string)
    qry, smoothing = string.split("::")
    
    terms = get_terms_from_query_string(qry)
    smoothing = smoothing.to_i if smoothing.present?
    
    {:query => terms.join(", "), :smoothing => smoothing, :raw => qry}
  end
  
  def self.recommended_query_hsh
    from_redis(Article.redis.srandmember("recommended_searches") || "Yale, Harvard, Princeton::1")
  end
  
  def self.ngram_query(terms, opts = {})
    smoothing = opts[:smoothing] || 1
    case_sensitive = false
    
    preprocess_method = case_sensitive ? :to_s : :downcase
    
    terms_hsh = terms.inject(ActiveSupport::OrderedHash.new) do |hsh, term|
      key = term.dup
      hsh[key] = inner_query(term.send(preprocess_method), smoothing)
      hsh
    end
    
    {:terms => terms_hsh, :years => all_years, :smoothing => smoothing, :tagline => Tagline.random}
  end
  
  def self.equation_query(equation, smoothing)
    individual_terms = equation.split(%r{[#{ALLOWED_MATH_OPERATORS.join('')}]}).map(&:squish).uniq.select(&:present?)
    raise 'equation is too big!' if individual_terms.size > 10
    
    data_hsh = individual_terms.inject({}) do |hsh, t|
      hsh[t] = inner_query(t, smoothing)
      hsh
    end
    
    years = all_years
    output = []
    
    years.size.times do |ix|
      e = equation.dup
      data_hsh.keys.each do |t|
        e.gsub!(/\b#{t}\b/, data_hsh[t][ix].to_s)
      end
      
      raw_value = eval(e)
      
      output << (raw_value.infinite? ? nil : raw_value)
    end
    
    return output
  end
  
  def self.inner_query(term, smoothing)
    return equation_query(term, smoothing) if term.is_equation?
    
    term.squish!
    n = term.split(" ").size
    
    years = all_years
    
    counts_hsh, totals_hsh = {}, {}
    
    Article.redis.pipelined do
      years.each do |year|
        key = Article.sorted_set_key(year, n)
        
        counts_hsh[year] = Article.redis.zscore(key, term)
        totals_hsh[year] = Article.redis.zscore(Article::TOTAL_KEY, key)
      end
    end
    
    counts = counts_hsh.sort_by{|year, val| year}.map{|ary| ary[1].value.to_f}
    totals = totals_hsh.sort_by{|year, val| year}.map{|ary| ary[1].value.to_f}
    
    output = []
    number_of_years = years.size
    
    number_of_years.times do |ix|
      lower = [0, ix - smoothing].max
      upper = [number_of_years - 1, ix + smoothing].min
      output << counts[lower..upper].sum / totals[lower..upper].sum
    end
    
    output
  end
  
  def self.simple_search(terms, opts = {})
    limit = opts[:limit] || 3
    n = terms.size
    qry_text = ""
    
    terms.each_with_index do |t, ix|
      qry_text << "#{' OR' if ix > 0} stripped_text LIKE ?"
    end
    
    conditions = [qry_text] + terms.map{|t| "%#{t.downcase}%" }
    
    Article.where(conditions).
            order("random()").
            limit(limit)
  end
  
  def self.full_text_search(terms, opts = {})
    terms = terms.map(&:split_into_equation_components).flatten.uniq.select(&:present?)
    
    limit = opts[:limit] || 3
    n = terms.size
    
    ts_query_arg = ""
    exact_qry_text = ""
    
    terms.each_with_index do |t, ix|
      # what about searching with &
      ts_query_arg << "#{' |' if ix > 0} (#{t.split(' ').reject{|w| w == '&'}.join(' & ')})"
      exact_qry_text << "#{' OR' if ix > 0} stripped_text LIKE ?"
    end
    
    full_text_conditions = ["to_tsvector('english', article_text) @@ to_tsquery(?)", ts_query_arg]
    exact_conditions = [exact_qry_text] + terms.map{|t| "%#{t.downcase}%" }
    
    scope_without_exact = Article.unscoped.select("id").where(:is_wedding => true).
                        where(full_text_conditions).
                        limit(100)
                        
    inner_sql_without_exact = scope_without_exact.to_sql
    inner_sql_with_exact = scope_without_exact.where(exact_conditions).to_sql
    
    articles = Article.where("id IN (#{inner_sql_with_exact})").order("random()").limit(3)
    
    if articles.length == 0
      Article.where("id IN (#{inner_sql_without_exact})").order("random()").limit(3)
    else
      articles
    end
  end
  
  def thumbnail_image_url
    read_attribute('image_url').to_s.gsub(/\-(thumbLarge|superJumbo)\./, '-thumbStandard.')
  end
  
  def image_url
    thumbnail_image_url.presence || DEFAULT_IMAGE_URL
  end
  
  def canonical_url
    url.gsub(/\?.*$/, '')
  end
  
  def self.wordcloud_urls
    ["http://i.imgur.com/LXUpNTt.png",
     "http://i.imgur.com/SHXfsbP.png",
     "http://i.imgur.com/vCq59h4.png",
     "http://i.imgur.com/anlSlKv.png"]
  end
end