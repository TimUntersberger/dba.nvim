lua dba = require("dba")

command! -nargs=1 DbaGetAll call <SID>GetAllRows(<q-args>)

function! s:GetAllRows(table_name)
  let l:result = luaeval('dba.get_all_rows(_A[1], 50, 1)', [a:table_name])
  let l:output = deepcopy(l:result)

  enew

  for row in l:output.values
    call append(line('$'), row.name)
  endfor

  execute ':d _'
endfunction
