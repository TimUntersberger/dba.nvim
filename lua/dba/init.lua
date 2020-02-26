local connection_string = "postgresql://tim:tim@localhost:5432/tim"

function iterator_to_array(iterator)
  local arr = {}
  for val in iterator do
    arr[#arr + 1] = val
  end
  return arr
end

function table_to_json(o, indentation)
  if indentation == nil then indentation = '  ' end
  if type(o) == 'table' then
    local s = '{ \n'
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. indentation .. '['..k..'] = ' .. table_to_json(v, indentation .. "  ") .. ',\n'
    end
    return s .. string.sub(indentation, 1, -3) .. '}'
  else
    return tostring(o)
  end
end

function string_to_lines(string)
  return string.gmatch(string, "[^\r\n]+")
end

function psql_row_to_values(string)
  return string.gmatch(string, "[^|]+")
end

function execute_sql(driver_name)
  return function(connection_string)
    return function(sql)
      return io
        .popen(driver_name .. " " .. connection_string .. " -c '" .. sql .. "'", 'r'):read("*a")
      end
    end
end
function create_psql_driver(connection_string)
  local execute_sql = execute_sql("psql")(connection_string)

  return {
    execute_sql = execute_sql,
    get_all_databases = function() 
      local output = execute_sql([[
        select oid as database_id,
          datname as database_name
        from pg_database
        order by oid;
      ]])
      local lines = iterator_to_array(string_to_lines(output))

      local result = {
        headers = iterator_to_array(psql_row_to_values(lines[1])),
        values = {}
      }

      for i = 3, #lines do
        local line = lines[i]
        local values = iterator_to_array(psql_row_to_values(line))
        result.values[#result.values + 1] = values[2]
        i = i + 1
      end

      return result
    end
  }
end

local psql = create_psql_driver(connection_string)

local databases = psql.get_all_databases()

print(table_to_json(databases))

return { 
  get_all_databases = psql.get_all_databases
}
