local driver = require('deta/driver')
require('deta/util')

function psql_row_to_values(s)
  return string.gmatch(s, "[^|]+")
end

function trim_string(s)
  return string.gsub(s, " ", "")
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
    execute_sql = function(sql)
      local result = execute_sql(sql)
      return psql_result_to_table(result)
    end,
    set_database = function(database)
      current_database = database
      execute_sql = driver.execute_sql("psql")(connection_string .. "/" .. current_database)
    end,
    get_all_rows = function(table_name, page_size, page)
      local output = execute_sql(
        string.format(
          [[
            select * from %s order by id ASC limit %d offset %d 
          ]], 
          table_name, 
          page_size, 
          page_size * (page - 1)
        )
      )
      if output == "" then
        return nil
      end
      return psql_result_to_table(output)
    end,
    get_all_tables = function()
      local output = execute_sql(
        string.format(
          [[
            select t.table_name
            from information_schema.tables t
            where t.table_catalog = current_database()
                  and t.table_type = 'BASE TABLE'
                  and t.table_schema not in ('information_schema', 'pg_catalog')
            order by t.table_name;
          ]]
        )
      )
      if output == "" then
        return nil
      end
      return psql_result_to_table(output)
    end,
    get_table_metadata = function(table_name, page_size, page)
      local output = execute_sql(
        string.format(
          [[
          select 
            col.column_name,
            col.data_type,
            col.character_maximum_length,
            col.is_nullable,
            col.column_default,
            const.constraint_name,
            const.constraint_type
          from 
            information_schema.columns col 
          left join 
            information_schema.constraint_column_usage usage 
          on 
            usage.column_name = col.column_name
          left join
            information_schema.table_constraints const
          on
            const.constraint_name = usage.constraint_name
          where 
            col.table_name = '%s'
          LIMIT 
            %d                                                    
          OFFSET
            %d
          ]], 
          table_name, 
          page_size, 
          page_size * (page - 1)
        )
      )
      if output == "" then
        return nil
      end
      return psql_result_to_table(output)
    end,
    get_all_databases = function() 
      local output = execute_sql([[
        select 
          datname as database_name
        from pg_database
        order by oid;
      ]])
      if output == "" then
        return nil
      end
      return psql_result_to_table(output)
    end,
    delete = function(table_name, id)
      execute_sql(
        string.format(
          [[
            delete from
              %s
            where
              id = %d;
          ]],
          table_name,
          id
        )
      )
    end,
    update = function(table_name, id, changeset)
      local update_string_parts = {}

      for k, v in pairs(changeset) do
        table.insert(update_string_parts, k .. " = " .. v)
      end

      local update_string = table.concat(update_string_parts, ", ")

      execute_sql(
        string.format(
          [[
            update
              %s
            set
              %s
            where
              id = %d;
          ]],
          table_name,
          update_string,
          id
        )
      )
    end
  }
end

