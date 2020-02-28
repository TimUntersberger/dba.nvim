require('deta/util')
require('deta/psql')

local driver = create_psql_driver("postgresql://tim:tim@localhost:5432")

return {
  set_connection_string = function(str)
    driver = create_psql_driver(str)
  end,
  set_database = function(database)
    return driver.set_database(database)
  end,
  get_all_rows = function(table_name, page_size, page)
    return driver.get_all_rows(table_name, page_size, page)
  end,
  get_all_tables = function()
    return driver.get_all_tables()
  end,
  get_all_databases = function() 
    return driver.get_all_databases()
  end,
  update = function(table, id, changeset)
    driver.update(table, id, changeset)
  end
}
