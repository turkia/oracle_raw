# encoding: UTF-8

require 'oci8'

# <tt>OCI8::Cursor</tt> class is enhanced with helper methods. 
#
# Please refer to http://ruby-oci8.rubyforge.org/en/ for more information about the OCI8 library. 

class OCI8::Cursor

	# This method binds all parameters given in an array. 
	# The first value is the name given in the sql string, the second is the value to be bound,
	# the third is the type of the value, and the fourth is the maximum length of the value. 

	def bind_parameters(params)
		params.each do |p|
			if p[1].is_a?(Array)
				self.bind_param_array(p[0], p[1], p[2], p[3])
			else
				self.bind_param(p[0], p[1], p[2], p[3])
			end
		end if params
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
# == Installation
#
# <tt>gem install oracle_raw</tt>
#
# == Usage
#
# Consult the README. 
# 
# == Additional information
#
# ActiveRecord and ConnectionPool documentation:
#
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

	# Depending whether the +:metadata+ option is +:none+ or +:all+, returns either a plain result set or a map of the following kind:
	#
	# <tt>{ :count => rowcount, :columns => colnames, :data => data, :date => date, :duration => duration }</tt>
	# 
	# Exception are propagated to the caller.

	def query(sqlquery, parameters = [], options = {})

		with_connection { |conn|

			starttime = Time.new; data = []

			cursor = conn.parse(sqlquery)
			cursor.max_array_size = 100
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
				when :plain then
					cursor.close
					data
				else	
					cursor.close
					{:data => data}
			end
		}
	end
end
