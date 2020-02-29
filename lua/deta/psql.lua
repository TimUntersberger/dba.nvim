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
      local pkOutput = execute_sql(
        string.format(
          [[
          select 
            col.column_name
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
            and const.constraint_type = 'PRIMARY KEY'
          LIMIT 
            1
          ]], 
          table_name
        )
      )

      local pk = psql_result_to_table(pkOutput).values[1]

      local orderBy = ''

      if pk ~= nil then
        orderBy = 'order by ' .. pk.column_name .. ' ASC'
      end

      local output = execute_sql(
        string.format(
          [[
            select * from 
              %s
            %s
            limit %d 
            offset %d 
          ]], 
          table_name, 
          orderBy,
          page_size, 
          page_size * (page - 1)
        )
      )

      local result = psql_result_to_table(output)

      result.pk = ''

      if pk ~= nil then
        result.pk = pk.column_name
      end

      return result
    end,
    get_all_tables = function()
      local output = {}
      if current_database == nil then
        output = execute_sql(
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
      else
        output = execute_sql(
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
      end
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
    insert = function(table_name, changeset)
      local headers = {}
      local values = {}

      for k, v in pairs(changeset) do
        table.insert(headers, k)
        local v_as_num = tonumber(v)
        if v_as_num == nil then
          table.insert(values, "'" .. v .. "'")
        else
          table.insert(values, v)
        end
      end

      local headers_string = table.concat(headers, ", ")
      local values_string = table.concat(values, ", ")

      execute_sql(
        string.format(
          [[
            insert into
              %s(%s)
            values
              (%s)
          ]],
          table_name,
          headers_string,
          values_string
        )
      )
    end,
    update = function(table_name, id, changeset)
      local update_string_parts = {}

      for k, v in pairs(changeset) do
        local v_as_num = tonumber(v)
        if v_as_num == nil then
          table.insert(update_string_parts, k .. " = '" .. v .. "'")
        else
          table.insert(update_string_parts, k .. " = " .. v)
        end
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

