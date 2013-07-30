class ArticlesController < ApplicationController
  def index
  end
  
  def ngram_calculator
    terms = params[:q].split(",").map{|t| t.squish.gsub(/[^[[:word:]]\s\-\&]/, '')}
    
    smoothing_factor = params[:s].to_i
    
    hsh = if terms.blank?
      {:error => "Enter something!"}
    elsif terms.size > 8
      {:error => "You can't enter more than 8 things!"}
    elsif terms.any?{|t| t.split(" ").size > Article::MAX_NGRAM_SIZE}
      {:error => "Max ngram size is #{Article::MAX_NGRAM_SIZE}"}
    elsif smoothing_factor < 0 || smoothing_factor > 5
      {:error => "Smoothing Factor must be between 0 and 5"}
    else
      Article.ngram_query_for_web(terms, smoothing_factor)
    end
    
    hsh[:error] = "Something went wrong" if hsh.blank?
    
    render :json => hsh
  end
end
