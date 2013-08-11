Weddingram::Application.routes.draw do
  root :to => 'articles#index'
  match '/about' => 'articles#about', :as => :about, :via => :get
  match '/articles/ngram_calculator' => 'articles#ngram_calculator', :as => :ngram_calculator, :via => :get
  match '/articles/search' => 'articles#search', :as => :search, :via => :get
  match '/articles/random' => 'articles#random', :as => :random, :via => :get
  match '/articles/tagline' => 'articles#tagline', :as => :tagline, :via => :get
  
  # TO DO: route anything else to homepage?
end
