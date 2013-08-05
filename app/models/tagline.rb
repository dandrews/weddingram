class Tagline
  TAGLINES_KEY = "site_taglines"
  
  def self.random
    phrase = $redis.srandmember(TAGLINES_KEY).presence || fallback
    "#{phrase.starts_with?("'") ? '' : ' '}#{phrase}"
  end
  
  def self.fallback
    ["is an investment banker",
      "is a dermatologist",
      "is vice president",
      "is the managing partner",
      "graduated from Yale",
      "has a master's degree in education"].sample
  end
end