local connection_string = "postgresql://tim:tim@localhost:5432/tim"

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
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
      local result = {}

      local i = 0
      local lines = string.gmatch(output, "[^\r\n]+")
      print(#lines)
      for line in lines do
        print(i .. " " .. line)
        i = i + 1
      end

      return result
    end
  }
end

local psql = create_psql_driver(connection_string)

local databases = psql.get_all_databases()

dump(databases)

return {}
