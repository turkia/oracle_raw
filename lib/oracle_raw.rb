# encoding: UTF-8
# 
# Author::    opiskelijarekisteri-devel (mailto:opiskelijarekisteri-devel@helsinki.fi)
# Copyright:: Copyright (c) 2011 opiskelijarekisteri-devel
# License::   GNU General Public License, Version 3 (http://www.gnu.org/copyleft/gpl.txt)

require 'oci8'

# <tt>OCI8::Cursor</tt> class is enhanced with helper methods. 
#
# Please refer to http://ruby-oci8.rubyforge.org/en/ for more information about the OCI8 library. 

class OCI8::Cursor

	# This method binds all parameters given in an array. 
	# The first value is the name given in the sql string, the second is the value to be bound,
	# the third is the type of the value, and the fourth is the maximum length of the value. 

        def bind_parameters(params)
		params.each do |p| self.bind_param(p[0], p[1], p[2], p[3]) end if params
	end

	# This method performs exec and prefetch. 

	def exec_with_prefetch(amount = 5000)
		self.exec
		self.prefetch_rows = amount
	end
end


require 'active_record'


# This is a Ruby library for interfacing with an Oracle Database using pooled OCI8 raw connections (http://ruby-oci8.rubyforge.org/en/).
# It uses ActiveRecord Oracle Enhanced adapter (https://github.com/rsim/oracle-enhanced) for connection pooling.
#
# At the moment the following methods are implemented:
# * #query: a general querying method
# * #with_connection: a method taking a block as an argument; inside the block you can use a raw connection object to execute queries, updates etc.
#
# The behaviour of the query method can be controlled with the following options given to initializer, #query or both: 
# * +:metadata+: if +:all+, returns the number of items in the result set, column names in lower case, and the time and duration of the query. If +:none+, returns only the result set. 
# * +:item_format+: if +:hash+, query returns the result items as hashes. The default is +:array+, i.e. the items are arrays. 
# * +:amount+: if +:all_rows+, returns all rows. If +:first_row+, returns only the first row. If +:single_value+, returns only the first value of the first row. +:single_value+ cannot be used if +:item_format+ is +:hash+. Default is to return all rows. 
#
# Global options can be changed after initialization.  
# Options given to #query override global options given to initializer (but not when the option value is nil).
# 
# == Installation
#
# <tt>gem install oracle_raw</tt>
#
# == Usage
#
# <tt>tnsnames = '(DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SID = TEST)))'</tt>
#
# <tt>schema = 'scott'</tt>
#
# <tt>password = 'tiger'</tt>
#
# <tt>connection_pool_size = 5</tt>
#
# <tt>global_options = { :metadata => :all, :item_format => :hash, :amount => :first_row }</tt>
#
# <tt>db = OracleRaw.new(tnsnames, schema, password, connection_pool_size, global_options)</tt>
#
# <tt>students_sql = 'select * from students where last_name = :last_name' and first_name = :first_name</tt>
#
# <tt>last_name = 'Kruskal-Wallis'</tt>
#
# <tt>first_name = 'Lucy'</tt>
#
# <tt>result = db.query(students_sql, [[:last_name, last_name, String], [:first_name, first_name, String]])</tt>
#
# <tt>puts result[:rowcount]</tt>
#
# <tt>puts result[:duration]</tt>
#
# <tt>result = db.query(students_sql, [[:last_name, last_name, String, 50], [:first_name, first_name, String, 50]], { :metadata => :none, :item_format => :array })</tt>
#
# <tt>puts result[:data]</tt>
# 
# <tt>sysdate_sql = 'select sysdate from dual'</tt>
#
# <tt>puts db.query(sysdate_sql, nil, { :metadata => :none, :amount => :single_value})[:data]</tt>
#
# <tt>puts db.with_connection { |c| (c.exec(sysdate_sql).fetch)[0] }</tt>
#
#--
# ActiveRecord and ConnectionPool documentation:
# * http://ar.rubyonrails.org/
# * http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/ConnectionPool.html

class OracleRaw

	# Global options are readable and writable. 

	attr_accessor :global_options

	# Establishes a connection with the given connection parameters, and sets global options. 
	# 
	# <tt>tnsnames = '(DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SID = TEST)))'</tt>

	def initialize(tnsnames, schema, password, pool_size = 1, global_options = {})
		ActiveRecord::Base.establish_connection(:adapter  => "oracle_enhanced", 
							:username => schema, :password => password, 
							:database => tnsnames, :pool => pool_size)
		@global_options = global_options 
	end

	# Closes all connections in the connection pool. 

	def close
		ActiveRecord::Base.connection_pool.disconnect!
	end

	# Yields a raw connection to the block argument. Example: 
	# 
	# <tt>db.with_connection { |c| c.exec("insert into students (last_name, first_name) values ('Kruskal-Wallis', 'Lucy')") }</tt>

	def with_connection
		ActiveRecord::Base.connection_pool.with_connection { |conn| yield conn.raw_connection }
	end

	# Depending whether the +:metadata+ option is +:all+ or +:none+, returns either of the following:
	#
	# <tt>{ :count => rowcount, :columns => colnames, :data => data, :date => date, :duration => duration }</tt>
	#
	# <tt>{ :data => data }</tt>
	# 
	# If an exception occurs, returns <tt>{ :exception => e }</tt>.

	def query(sqlquery, parameters = [], options = {})

		begin
			with_connection { |conn|

				starttime = Time.new; data = []

				cursor = conn.parse(sqlquery)
				cursor.bind_parameters(parameters) if parameters
				cursor.exec_with_prefetch(5000)

				case options[:item_format] || @global_options[:item_format]

					when :hash then

						case options[:amount] || @global_options[:amount]

							when :first_row then data = cursor.fetch_hash()
							else while r = cursor.fetch_hash(); data << r;  end 
						end
					else 
						case options[:amount] || @global_options[:amount]

							when :single_value then temp = cursor.fetch(); data = (temp ? temp[0] : nil)
							when :first_row then data = cursor.fetch()
							else while r = cursor.fetch(); data << r; end
						end
				end

				case options[:metadata] || @global_options[:metadata]

					when :all then
						colnames = cursor.get_col_names.each do |n| n.downcase! end 
						rowcount = cursor.row_count
						cursor.close
						{:count => rowcount, :columns => colnames, :data => data, :date => starttime, :duration => Time.new - starttime}
					else	
						cursor.close
						{:data => data}
				end
			}
		rescue => e
			{:exception => e}
		end
	end
end

