Gifsect::Application.routes.draw do
  root 'welcome#index'
  get 'metadata/*path', to: 'gifsect#metadata'
  get '*path', to: 'gifsect#do'
end