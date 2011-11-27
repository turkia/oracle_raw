require 'helper'

$tnsnames = '(DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SID = TEST)))'
$schema = 'scott'
$password = 'tiger'

class TestOracleRaw < Test::Unit::TestCase

	def connect
		OracleRaw.new($tnsnames, $schema, $password)
	end

	def test_sysdate
		db = connect
		sql = 'select sysdate from dual'
		result = db.query(sql, nil, {:item_format => :array, :amount => :single_value})[:data]
		assert_equal(Time, result.class)
		result = db.query(sql, nil, {:amount => :single_value})[:data]
		assert_equal(Time, result.class)
		result = db.query(sql, nil, {:item_format => :hash, :amount => :first_row})[:data]['SYSDATE']
		assert_equal(Time, result.class)
		result = db.query(sql, nil, {:metadata => :all})
		assert_equal(result[:exception], nil)
		assert_equal(1, result[:count])
		db.close
	end

	def test_with_connection
		db = connect
		db.global_options = { :metadata => :all, :item_format => :hash, :amount => :all_rows }

		db.with_connection { |c| 
			begin c.exec('drop table oracle_raw_test') rescue nil end
			c.exec('create table oracle_raw_test (name varchar2(20), age number)')
			c.exec("insert into oracle_raw_test (name, age) values ('Maria', 20)")
			c.exec("insert into oracle_raw_test (name, age) values ('Lucia', 25)")

			cursor = c.parse('insert into oracle_raw_test (name, age) values (:name, :age)')
			cursor.bind_parameters([[:name, 'Kinnie', String], [:age, 30, Integer]])
			cursor.exec
			cursor.close

			c.commit
			age_sum = (c.exec("select sum(age) from oracle_raw_test").fetch)[0]
			assert_equal(75, age_sum)
		}

		result = db.query('select count(*) count from oracle_raw_test', nil, {:metadata => :all, :item_format => :array, :amount => :single_value})
		assert_equal(result[:exception], nil)
		assert(result[:count] == 1 && result[:data] == 3)

		result = db.query('select count(*) count from oracle_raw_test', nil, {:amount => :first_row})
		assert_equal(result[:exception], nil)
		assert_equal(result[:count], 1)

		result = db.query('select name from oracle_raw_test where age = :age', [[:age, 30, Integer]], {:metadata => :none, :amount => :all_rows})
		assert_equal(result[:exception], nil)
		assert_equal(result[:data][0]['NAME'], 'Kinnie')
		assert_equal(result[:count], nil)

		db.with_connection { |c| c.exec('drop table oracle_raw_test') }
		db.close
	end

	def test_max_speed_from_pool
		db = connect
		start = Time.new; num_calls = 1000
		num_calls.times do 
			result = db.query('select 1 from dual') 
puts result[:exception].backtrace if result[:exception]
			assert_equal(result[:exception], nil)
		end
		puts "\nSpeed test: pooled: #{num_calls/(Time.new - start)} calls/second.\n"
		db.close
	end

	def test_max_speed_one_connection
		db = connect
		start = Time.new; num_calls = 1000
		db.with_connection { |c| num_calls.times do c.exec('select 1 from dual') end }
		puts "\nSpeed test: single connection: #{num_calls/(Time.new - start)} calls/second.\n"
		db.close
	end

	def test_max_speed_unpooled
		start = Time.new; num_calls = 100
		num_calls.times do 
			c = OCI8.new($schema, $password, $tnsnames)
			c.exec('select 1 from dual').fetch 
			c.logoff
		end
		puts "\nSpeed test: unpooled: #{num_calls/(Time.new - start)} calls/second.\n"
	end

	def test_no_metadata
		db = connect
		result = db.query('select 1 from dual')
		assert_equal(result[:exception], nil)
		assert_equal(result[:count], nil)
		db.close
	end

	def test_exception
		db = connect
		result = db.query('select * from oracle_raw_test_nonexistent', nil, nil)
		assert(/ORA-00942/ =~ result[:exception].message)
		db.close
	end
end

