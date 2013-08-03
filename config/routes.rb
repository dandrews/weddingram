Weddingram::Application.routes.draw do
  root :to => 'articles#index'
  match '/articles/ngram_calculator' => 'articles#ngram_calculator', :as => :ngram_calculator, :via => :get
  match '/articles/search' => 'articles#search', :as => :search, :via => :get
  
  # TO DO: route anything else to homepage?
end
