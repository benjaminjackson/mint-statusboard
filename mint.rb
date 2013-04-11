require 'csv'
require 'date'
require 'yaml'
require 'json'
require 'data_mapper'
require 'dm-ar-finders'
require 'dm-aggregates'
require 'active_support/all'
require "uri"
require "mechanize"
require 'trollop'
require 'chronic'

HOSTNAME = "https://wwws.mint.com/"

@opts = Trollop::options do
  opt :email, "Email", :type => String, :short => 'e', :required => true
  opt :password, "Password", :type => String, :short => 'p', :required => true
  opt :outfile, "Output File", :type => String, :short => 'o', :default => "output.json"
  opt :type, "Transaction Type ('debit' or 'credit')", :type => String, :short => 't', :default => "debit"
  opt :graph_type, "Graph Type ('line' or 'bar')", :type => String, :short => 'g', :default => "bar"
  opt :color, "Graph Color ('Red', 'Green', or '#555')", :type => String, :short => 'c', :default => "Green"
  opt :title, "Graph Title", :type => String, :short => 'T', :default => "Spending"
  opt :since, "Show Transactions Since (e.g., 'last week', 'yesterday')", :type => :string, :short => 's', :default => 'this month'
  opt :show_every_label, "Show All Labels", :type => :boolean, :short => 'l', :default => false
  opt :weekly, "Show Data Weekly", :type => :boolean, :short => 'w', :default => false
  opt :monthly, "Show Data Monthly", :type => :boolean, :short => 'm', :default => false
end

agent = Mechanize.new
agent.pluggable_parser.default = Mechanize::Download

page  = agent.get(URI.join HOSTNAME, "/login.event")
form = page.form_with(:id => "form-login")

form.username = @opts[:email]
form.password = @opts[:password]
form.submit

TRANSACTIONS_CSV = agent.get(URI.join HOSTNAME, "/transactionDownload.event").body

START_DATE = Chronic.parse(@opts[:since]).to_date
END_DATE = Date.today

begin

  class Transaction
  	include DataMapper::Resource

    has 1, :category
    has 1, :account

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

  	property :id, Serial
    property :name, Text
  end

  class Account
  	include DataMapper::Resource

  	property :id, Serial
    property :name, Text
  end

  DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite::memory:")

  DataMapper.finalize
  DataMapper.auto_upgrade!
end

def dateobj string
  Date.strptime(string, "%m/%d/%Y").strftime("%d-%m-%Y")
end

def create_database_from_csv
  CSV.parse(TRANSACTIONS_CSV, headers: true) do |row|
    x = row.to_hash
    x['Date'] = dateobj(x['Date'])
    x['Amount'] = x['Amount'].to_i
    if Date.parse(x['Date']) > START_DATE && x['Category'] != 'Exclude From Mint'
      Transaction.create! date: x['Date'],
        description: x['Description'],
        original_description: x['Original Description'],
        amount: x['Amount'],
        type: x['Transaction Type'],
        category: Category.first_or_create(:name => x['Category']),
        account: Account.first_or_create(:name => x['Account Name']),
        labels: x['Labels'],
        notes: x['Notes']
      end
  end
end

create_database_from_csv

graph = {
  :graph => {
    :title => @opts[:title],
    :type => @opts[:graph_type],
    :total => true,
    :yAxis => { :units => { :prefix => "$" } },
    :xAxis => { :showEveryLabel => @opts[:show_every_label] },
    :datasequences => [
      { :title => @opts[:type].titlecase, :color => @opts[:color], :datapoints => [] },
    ]
  }
}

(START_DATE..END_DATE).each do |day|
  graph[:graph][:datasequences][0][:datapoints] << {
    :title => day.strftime("%m/%d/%Y"), 
    :value => Transaction.sum(:amount, :date => day, :type => @opts[:type]).to_f 
  }
end

File.open(@opts[:outfile], 'w') do |file|
  file.write(graph.to_json)
end