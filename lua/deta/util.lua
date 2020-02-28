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

function map(mapper, table)
  local result = {}
  for k,x in pairs(table) do
    result[k] = mapper(x, k)
  end
  return result
end

function string_to_lines(string)
  return string.gmatch(string, "[^\r\n]+")
end
