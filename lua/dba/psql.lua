local driver = require('dba/driver')

function psql_row_to_values(s)
  return string.gmatch(s, "[^|]+")
end

function trim_string(s)
  return string.gsub(s, " ", "")
end

function map(mapper, t)
  local result = {}
  for k, value in pairs(t) do
    result[k] = mapper(value)
  end
  return result
end

function psql_result_to_table(psql_result)
  local lines = iterator_to_array(string_to_lines(psql_result))

  local result = {
    headers = map(trim_string, iterator_to_array(psql_row_to_values(lines[1]))),
    values = {}
  }

  for i = 3, #lines - 1 do
    local line = lines[i]
    local tokens = map(trim_string, iterator_to_array(psql_row_to_values(line)))
    local value = {}
    for i, token in pairs(tokens) do
      value[result.headers[i]] = token
    end
    result.values[#result.values + 1] = value
    i = i + 1
  end

  return result
end

function create_psql_driver(connection_string)
  local execute_sql = driver.execute_sql("psql")(connection_string)
  local current_database = nil

  return {
    execute_sql = execute_sql,
    set_database = function(database)
      current_database = database
      execute_sql = driver.execute_sql("psql")(connection_string .. "/" .. current_database)
    end,
    get_all_rows = function(table_name, page_size, page)
      print(table_name)
      local output = execute_sql(
        string.format(
          [[
            select * from %s limit %d offset %d
          ]], 
          table_name, 
          page_size, 
          page_size * (page - 1)
        )
      )
      return psql_result_to_table(output)
    end,
    get_all_tables = function()
      local output = execute_sql(
        string.format(
          [[
            select t.table_name
            from information_schema.tables t
            where t.table_catalog = '%s'
                  and t.table_type = 'BASE TABLE'
                  and t.table_schema not in ('information_schema', 'pg_catalog')
            order by t.table_name;
          ]], 
          current_database
        )
      )
      return psql_result_to_table(output)
    end,
    get_all_databases = function() 
      local output = execute_sql([[
        select 
          datname as database_name
        from pg_database
        order by oid;
      ]])
      return psql_result_to_table(output)
    end
  }
end

