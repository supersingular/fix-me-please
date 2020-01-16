=begin
Ce controller retourne 2000 posts et 5000 commentaires.
Le but de l'exercice:
- Fixer le test qui casse en ajoutant la nouvelle fonctionnalité
- N'hésite pas à modifier le code si tu en ressent le besoin
Il faut retourner ce gist avec:
- La suite de test qui passe
- Des explications sur tes changements
- Les améliorations possibles
Pour lancer ce fichier `rspec fix_me_please.rb`
=end

begin
  require 'bundler/inline'
rescue LoadError => e
  $stderr.puts 'Bundler version 1.10 or later is required. Please update your Bundler'
  raise e
end

gemfile(true) do
  source 'https://rubygems.org'
  gem 'rails'
  gem 'rspec-rails'
  gem 'sqlite3', '~> 1.4'
  gem 'database_cleaner'
  gem 'byebug' # NEW
end 

require 'active_record'
require 'rspec-rails'
require 'action_controller/railtie'

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.timestamps
  end

  create_table :comments, force: true do |t|
     # OLD👇 
    # t.integer :post_id, null: false

    # NEW👇 comment cant be saved to database without a post
    t.integer :post_id, null: false
    t.integer :author_id, null: false
    t.timestamps
  end

  create_table :authors, force: true do |t|
    t.string :username
  end
end

class Post < ActiveRecord::Base
  # OLD👇 
  # has_many :comments

  # NEW👇 when a `Post` is destroyed, its `comments` will also be destroyed
   has_many :comments, dependent: :destroy
end

class Comment < ActiveRecord::Base
  belongs_to :post
  belongs_to :author

end

class Author < ActiveRecord::Base
  has_many :comments
end

class TestApp < Rails::Application
  config.root = File.dirname(__FILE__)
  config.session_store :cookie_store, key: 'cookie_store_key'
  secrets.secret_token    = 'secret_token'
  secrets.secret_key_base = 'secret_key_base'

  config.logger = Logger.new($stdout)
  Rails.logger  = config.logger

  routes.draw do
     # OLD👇 
    # get '/' => 'comments#users_comments'

    # NEW👇 Used Rails convention to set root path
    root to: 'comments#users_comments'
  end
end

class CommentsController < ActionController::Base
  include Rails.application.routes.url_helpers

  def users_comments
    # OLD👇 Should use Active Record
    # posts = Post.all
    # comments = posts.map(&:comments).flatten
    # comments = comments.sort_by(&:created_at) if options[:sort_by_date]
    # @user_comments = comments.select do |comment|
    #   comment.author.username == options[:username]
    # end
    # render json: @user_comments

    @user_comments = Comment.joins(:post, :author).where('authors.username in(?)', options[:usernames]) 
    # byebug
    @user_comments = @user_comments.order(:created_at) if options[:sort_by_date]
    render json: @user_comments
  end

  private

  def options
    # OLD👇 
    # options = {}
    # available_option_keys = [:username, :sort_by_date]
    # all_keys = params.keys.map(&:to_sym)
    # set_option_keys = all_keys & available_option_keys
    # set_option_keys.each { |key| options[key] = params[key] }
    # options

    # NEW👇
    params.permit(:sort_by_date, usernames: []) # only these are the allowed params
  end
end

# ======================== rspec fix_me_please.rb --format doc

require 'rspec/rails'

RSpec.describe CommentsController, type: :controller do
  describe 'GET #user_comments' do
    # before do
       # OLD👇 
      # @author_1 = Author.create(username: 'Clara')
      # @author_2 = Author.create(username: 'Michmich')
      # @author_3 = Author.create(username: 'Pich')
      # @post_1 = Post.create
      # @post_2 = Post.create
      # @comment_1 = Comment.create(author: @author_1, post: @post_1)
      # @comment_2 = Comment.create(author: @author_2, post: @post_1, created_at: 1.month.ago)
      # @comment_3 = Comment.create(author: @author_1, post: @post_2)
      # @comment_4 = Comment.create(author: @author_2, post: @post_2, created_at: 2.month.ago)
      # @comment_5 = Comment.create(author: @author_3, post: @post_2)
      # @comment_6 = Comment.create(author: @author_1)

      # NEW👇 reason why i used let/let! to declare instance variables:
      #-It is memoized when used multiple times in one example, but not across examples.
      # -variables with let are lazy-loaded, so you wont waste time initializing the variable for examples that don’t reference it, but the ones using let! the obbject is instantly created
      # -Will raise an exception if you have a typo in your variable name.
      let(:author_1) { Author.create(username: 'Clara') }
      let(:author_2) { Author.create(username: 'Michmich') }
      let(:author_3) { Author.create(username: 'Pich') }
      let(:post_1) { Post.create }
      let(:post_2) { Post.create }
      let(:post_3) { Post.create }
      let!(:comment_1) { Comment.create(author: author_1, post: post_1) }
      let!(:comment_2) { Comment.create(author: author_2, post: post_1, created_at: 1.month.ago) }
      let!(:comment_3) { Comment.create(author: author_1, post: post_2) }
      let!(:comment_4) { Comment.create(author: author_2, post: post_2, created_at: 2.month.ago) }
      let!(:comment_5) { Comment.create(author: author_3, post: post_2) }
      let!(:comment_6) { Comment.create(author: author_3, post: post_3) }
    

    context 'no username param' do
      it 'returns an empty array' do
        get :users_comments, format: :json

        expect(response.body).to eq('[]')
      end
    end

    context 'username param' do
      it 'returns two comments for author_1' do
        # OLD👇 
        # get :users_comments, format: :json, params: { username: @author_1.username }

         #NEW👇 allowing more then one username on query string params
        get :users_comments, format: :json, params: { usernames: [ author_1.username ] } 

        expect(JSON.parse(response.body)).to match_array [
            a_hash_including("id" => comment_1.id),
            a_hash_including("id" => comment_3.id)
          ]
      end
    end

    context 'sort_by_date param' do
      it 'returns two comments for author_2 order inverted' do
        # OLD👇 
        # get :users_comments, format: :json, params: { username: @author_2.username, sort_by_date: 'true' }

         #NEW👇 allowing more then one username on query string params
        get :users_comments, format: :json, params: { usernames: [ author_2.username ], sort_by_date: 'true' } 


        expect(JSON.parse(response.body).pluck('id')).to eq([comment_4.id, comment_2.id])
      end
    end

    context 'multiple username param' do
      it 'returns four comments for author_1 and author_2' do
         # OLD👇 
        # get :users_comments, format: :json, params: { username: @author_1.username }

        #NEW👇 added possibility for qyery string params to take more then one param and also added author_2 username to the teste
        get :users_comments, format: :json, params: { usernames: [author_1.username, author_2.username] } 

        expect(JSON.parse(response.body)).to match_array [
            a_hash_including("id" => comment_1.id),
            a_hash_including("id" => comment_2.id),
            a_hash_including("id" => comment_3.id),
            a_hash_including("id" => comment_4.id)
          ]
      end
    end
  end
end