class Tagline
  TAGLINES_KEY = "site_taglines"
  BASE = "I am my beloved's, and my beloved"
  
  def self.random
    phrase = $redis.srandmember(TAGLINES_KEY).presence || fallback
    "#{BASE} #{phrase}"
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