class String
  def is_equation?
    Article::ALLOWED_MATH_OPERATORS.any?{|op| self.include?(op)}
  end
  
  def is_too_long_to_be_a_valid_query?
    if is_equation?
      squish.split_into_equation_components.any?{|str| str.split(" ").size > Article::MAX_NGRAM_SIZE}
    else
      squish.split(" ").size > Article::MAX_NGRAM_SIZE
    end
  end
  
  def split_into_equation_components
    split(%r{[#{Article::ALLOWED_MATH_OPERATORS.join('')}]}).map(&:squish).uniq
  end
end