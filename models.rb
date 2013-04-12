require 'data_mapper'
require 'dm-ar-finders'
require 'dm-aggregates'

begin

  class Transaction
  	include DataMapper::Resource

    belongs_to :category
    belongs_to :account

  	property :id, Serial
    property :name, Text
    property :type, Text
    property :date, Date
    property :description, Text
    property :original_description, Text
    property :labels, Text
    property :notes, Text
    property :amount, Float
  end

  class Category
  	include DataMapper::Resource
    has n, :transactions

  	property :id, Serial
    property :name, Text
  end

  class Account
  	include DataMapper::Resource
    has n, :transactions

  	property :id, Serial
    property :name, Text
  end

  DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite://#{File.dirname(__FILE__)}/mint.db")

  DataMapper.finalize
  DataMapper.auto_upgrade!
end

