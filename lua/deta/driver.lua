return {
  execute_sql = function (driver_name)
    return function(connection_string)
      return function(sql)
        local command = driver_name .. " " .. connection_string .. " -c \"" .. sql .. "\""
        return io
          .popen(command, 'r'):read("*a")
        end
      end
  end
}
