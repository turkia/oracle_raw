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
		params.each do |p| self.bind_param(p[0], p[1], p[2], p[3]) end if params
	end

	# This method performs exec and prefetch. 

	def exec_with_prefetch(amount = 5000)
		self.exec
		self.prefetch_rows = amount
	end
end


# This is a Ruby library for interfacing with an Oracle Database using pooled OCI8 connections (http://ruby-oci8.rubyforge.org/en/).
#
# == Installation
#
# <tt>gem install oracle_raw</tt>
#
# == Usage
#
# Consult the README. 

class OracleRaw

	# Global options are readable and writable. 

	attr_accessor :global_options

	# Establishes a connection with the given connection parameters, and sets global options. 
	# Pool_size is included for backward compatibility and may be ignored if pool settings are specified in global_options. 
	# Example: {:min_pool_size => 4, :pool_increment => 2, :max_pool_size => 10}
	# 
	# <tt>tnsnames = '(DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SID = TEST)))'</tt>

	def initialize(tnsnames, schema, password, pool_size = 1, global_options = {:min_pool_size => pool_size, :pool_increment => 0, :max_pool_size => pool_size})
		@schema = schema; @password = password
		@global_options = global_options 
		@pool = OCI8::ConnectionPool.new(global_options[:min_pool_size], global_options[:max_pool_size], global_options[:pool_increment], schema, password, tnsnames)
	end

	# Closes all connections in the connection pool. 

	def close
		@pool.destroy
	end

	# Yields a raw connection to the block argument. Example: 
	# 
	# <tt>db.with_connection { |c| c.exec("insert into names (id, name) values (1, 'Paul')") }</tt>

	def with_connection
		begin
			c = OCI8.new(@schema, @password, @pool)
			yield c
		ensure
			c.logoff
		end
	end

	# Executes given sql query. If parameters are given, binds them first. 
	#
	# Example: 
	# db.query('select * from names where id = :id and name = :name', [[:id, id, Integer, 2], [:name, name, String, 50]])
	#
	# The default return format for query results is to wrap result set in { :data => data }.
	# If a +:metadata+ option is set to +:plain+ or +:all+, returns either a plain result set with no wrapper, 
	# or a wrapped result set enhanced with additional information as follows: 
	#
	# <tt>{ :count => rowcount, :columns => colnames, :data => data, :date => date, :duration => duration }</tt>
	# 
	# Exceptions are propagated to the caller.

	def query(sqlquery, parameters = [], options = {})

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
