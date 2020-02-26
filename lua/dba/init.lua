require('dba/util')
require('dba/psql')

local connection_string = "postgresql://tim:tim@localhost:5432"

local psql = create_psql_driver(connection_string)

return psql
