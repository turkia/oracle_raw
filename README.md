oracle_raw
==========

This is a library for interfacing with an Oracle Database. It uses ActiveRecord Oracle Enhanced adapter (https://github.com/rsim/oracle-enhanced) for connection pooling, but otherwise a raw Ruby-OCI8 connection (http://ruby-oci8.rubyforge.org/en/) is used. 

Installation 
============

```bash
gem install oracle_raw
```

Usage
=====

At the moment the following methods are implemented:

* `query`: a general querying method
* `with_connection`: a method taking a block as an argument; inside the block you can use a raw connection object to execute queries, updates etc.

Connect to a database and create a pool of five connections. Global options (see below) and pool size are not mandatory. Default pool size is 1. 

```ruby
tnsnames = '(DESCRIPTION = (ADDRESS = (PROTOCOL = TCP)(HOST = localhost)(PORT = 1521)) (CONNECT_DATA = (SERVER = DEDICATED) (SID = TEST)))'
schema = 'scott'
password = 'tiger'
connection_pool_size = 5
global_options = {}

db = OracleRaw.new(tnsnames, schema, password, connection_pool_size, global_options)
```

Get a connection from the pool and do something with it: 

```ruby
db.with_connection { |c| 
	c.exec('create table names (id number, name varchar2(50))') 
	c.exec("insert into names (id, name) values (1, 'Paul')") 
	c.exec("insert into names (id, name) values (2, 'Maria')")
	c.commit
}
```

Use query method (handles connection internally). Without parameters:

```ruby
db.query('select name from names')
=> {:data=>[["Paul"], ["Maria"]]}
```

Query with parameters: 

```ruby
db.query('select name from names where id = :id', [[:id, 1, Integer]])
=> {:data=>[["Paul"]]}
```

Query with options: the behaviour of the query method can be controlled with the following options given to initializer, #query or both: 

* `:metadata`: if `:all`, returns the number of items in the result set, column names in lower case, and the time and duration of the query. If `:none`, returns only the result set. 
* `:item_format`: if `:hash`, query returns the result items as hashes. The default is `:array`, i.e. the items are arrays. 
* `:amount`: if `:all_rows`, returns all rows. If `:first_row`, returns only the first row. If `:single_value`, returns only the first value of the first row. `:single_value` cannot be used if `:item_format` is `:hash`. Default is to return all rows. 

Global options can be changed after initialization. 
Options given to `query` override global options given to initializer (but not when the option value is nil). 

```ruby
db.query('select name from names', nil, {:item_format => :hash})
=> {:data=>[{"NAME"=>"Paul"}, {"NAME"=>"Maria"}]}

db.query('select name from names', nil, {:item_format => :array})
=> {:data=>[["Paul"], ["Maria"]]}

db.query('select name from names', nil, {:metadata=>:plain})
=> [["Paul"], ["Maria"]]

db.query('select name from names', nil, {:metadata => :all})
=> {:count=>2, :columns=>["name"], :data=>[["Paul"], ["Maria"]], :date=>2012-09-17 15:53:46 +0300, :duration=>0.0016196}

db.query('select count(*) from names', nil, {:amount=>:single_value, :metadata=>:plain}).to_i
=> 2
```

Close the connection pool: 

```ruby
db.close
```

Copyright
=========

Copyright (c) 2011-2013 opiskelijarekisteri-devel. License: LGPLv3. See LICENSE.txt for further details.
