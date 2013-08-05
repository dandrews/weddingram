class ArticlesController < ApplicationController
  def index
  end
  
  def ngram_calculator
    terms = get_terms_from_params
    
    smoothing_factor = params[:s].blank? ? 1 : params[:s].to_i
    
    hsh = if terms.blank?
      {:error => "Enter something!"}
    elsif terms.size > 8
      {:error => "You can't enter more than 8 things!"}
    elsif terms.any?{|t| t.is_too_long_to_be_a_valid_query?}
      {:error => "Max ngram size is #{Article::MAX_NGRAM_SIZE}"}
    elsif smoothing_factor < 0 || smoothing_factor > 5
      {:error => "Smoothing Factor must be between 0 and 5"}
    else
      Article.ngram_query(terms, smoothing_factor)
    end
    
    hsh[:error] = "Something went wrong" if hsh.blank?
    
    render :json => hsh
  end
  
  def search
    terms = get_terms_from_params
    articles = Article.full_text_search(terms, :limit => 3)
    
    render :text => render_to_string(:partial => 'summaries', :locals => {:articles => articles})
  end
  
  def random
    render :json => Article.recommended_query_hsh
  end
  
  private
  
  def get_terms_from_params
    Article.get_terms_from_query_string(params[:q])
  end
end
