" TODO: make <C-d> and <C-u> jump 5 rows instead of 1
" TODO: add prompt for deletion
" TODO(Maybe): Support smart actions like row deletion for custom queries
" TODO: improve error handling
" TODO: start selectconnection implementation
" TODO: DetaRunQuery support non select statements.
" Probably should implement a driver method that detects what type of query it
" is. On the vim side we just check whether the type is a select statement to
" know whether to display the result in a DetaQueryResultView or not

lua deta = require("deta")

let s:currentView = {}
let s:defaultValues = {
  \ 'page': 1,
  \ 'pageSize': 50
  \ }

command! -nargs=1 DetaGetAll call <SID>GetAllRows(<q-args>)
command! -nargs=1 DetaGetTableMetadata call <SID>GetTableMetadata(<q-args>)
command! -nargs=1 DetaSetDatabase call <SID>SetDatabase(<q-args>)
command! -nargs=1 DetaConnect call <SID>Connect(<q-args>)
command! -nargs=0 DetaTables execute 'Clap deta_tables'
command! -nargs=0 -range DetaRunSelectedQuery call <SID>RunSelectedQuery()
command! -nargs=* DetaRunQuery call <SID>RunQuery(<q-args>)
command! -nargs=0 DetaDatabases execute 'Clap deta_databases'
command! -nargs=0 DetaConnections call <SID>ChooseConnection()
command! -nargs=0 DetaNextTableChunk call <SID>NextTableChunk()
command! -nargs=0 DetaPreviousTableChunk call <SID>PreviousTableChunk()
command! -nargs=0 DetaGoNextColumn call <SID>GoNextColumn()
command! -nargs=0 DetaGoPreviousColumn call <SID>GoPreviousColumn()
command! -nargs=0 DetaGoFirstColumn call <SID>GoFirstColumn()
command! -nargs=0 DetaGoLastColumn call <SID>GoLastColumn()
command! -nargs=0 DetaGoNextRow call <SID>GoNextRow()
command! -nargs=0 DetaGoPreviousRow call <SID>GoPreviousRow()
command! -nargs=0 DetaGoFirstRow call <SID>GoFirstRow()
command! -nargs=0 DetaGoLastRow call <SID>GoLastRow()
command! -nargs=0 DetaEditColumn call <SID>EditColumn()
command! -nargs=0 DetaDeleteRow call <SID>DeleteRow()
command! -nargs=0 DetaInsertRow call <SID>InsertRow()
command! -nargs=0 DetaToggleMetadata call <SID>ToggleMetadata()
  
nnoremap <leader>dg :DetaGetAll 
nnoremap <leader>dc :DetaConnect 
nnoremap <leader>dt :DetaTables<CR>
nnoremap <leader>dd :DetaDatabases<CR>
nnoremap <leader>dq :DetaRunQuery 
vnoremap <silent> <leader>dq :DetaRunSelectedQuery<CR>

aug Deta
  autocmd! * <buffer>
  au filetype DetaQueryResultView au BufWipeout <buffer> call <SID>OnBufWipeout()
aug END

function! s:OnBufWipeout()
  let s:currentView = {}

  aug Deta
  aug END
endfunction

function! s:RunQuery(query)
  call <SID>ExecuteQuery(a:query)
endfunction

function! s:RunSelectedQuery()
  let l:startLine = line("'<")
  let l:startCol = col("'<")
  let l:endLine = line("'>")
  let l:endCol = col("'>")

  let l:lines = getline(l:startLine, l:endLine)
  let l:lines[0] = l:lines[0][l:startCol - 1:-1]
  let l:lines[-1] = l:lines[-1][0:l:endCol - 1]

  let l:sql = join(l:lines, '\n')

  call <SID>ExecuteQuery(l:sql)
endfunction

function! s:ExecuteQuery(sql)
  let l:result = luaeval('deta.execute_sql(_A[1])', [a:sql])

  call <SID>OpenQueryResultView("query", s:defaultValues.pageSize, s:defaultValues.page,
        \ l:result, v:null, v:false, v:true)
endfunction

function! s:SetDatabase(db)
  call luaeval('deta.set_database(_A[1])', [a:db])
endfunction

function! GetMinColumnWidth(rows)
  let l:width = 0
  for row in a:rows
    let l:currLen = strlen(row)
    if l:currLen > l:width
      let l:width = l:currLen
    endif
  endfor
  return l:width
endfunction

function! Pad(str, minWidth, filler)
    return a:str . repeat(a:filler, a:minWidth - len(a:str))
endfunction

function! PadSpace(str, minWidth)
    return Pad(a:str, a:minWidth, " ")
endfunction

function! PrintSeperator(line, width, isSet)
  if a:isSet
    call setline(a:line, getline(a:line) . Pad("", a:width + 4, "-"))
  else
    call append(a:line, Pad("", a:width + 4, "-"))
  endif
endfunction

function! PrintColumnValue(line, value, isSet)
  if a:isSet
    call setline(a:line, getline(a:line) . a:value)
  else
    call append(a:line, a:value)
  endif
endfunction

function! PrintColumnValues(line, values)
  call PrintColumnValue(a:line, "| " . join(a:values, " | ") . " |", 0)
endfunction

function! PadColumnValues(values, widths, valueIsKey)
  return map(deepcopy(a:values), {k, v -> PadSpace(v, a:widths[a:valueIsKey ? v : k])})
endfunction

function! SumList(list)
  let l:sum = 0

  for x in a:list
    let l:sum = l:sum + x
  endfor

  return l:sum
endfunction

function! PrintQueryResult(result)
  let l:columnWidths = GetColumnWidthsForQueryResult(a:result)
  let l:columnCount = len(l:columnWidths)
  let l:seperatorLen = SumList(values(l:columnWidths)) + 3 * (l:columnCount - 1)

  call PrintSeperator(line('$'), l:seperatorLen, 1)
  call PrintColumnValues(line('$'), PadColumnValues(a:result.headers, l:columnWidths, v:true))
  call PrintSeperator(line('$'), l:seperatorLen, 0)

  for l:row in a:result.values
    let l:rowStr = "|"
    for l:header in a:result.headers
      let l:rowStr = l:rowStr . " " . PadSpace(l:row[l:header], l:columnWidths[l:header]) . " |"
    endfor
    call PrintColumnValue(line("$"), l:rowStr, v:false)
  endfor

  if len(a:result.values) > 0
    call PrintSeperator(line('$'), l:seperatorLen, 0)
  endif
endfunction

function! GetColumnWidthsForQueryResult(result)
  let l:cache = {}

  for l:header in a:result.headers
    let l:cache[l:header] = [l:header]
  endfor

  for l:row in a:result.values
    for l:item in items(l:row)
      let l:header = l:item[0]
      let l:value = l:item[1]

      call add(l:cache[l:header], l:value)
    endfor
  endfor

  return map(l:cache, {k, v -> GetMinColumnWidth(v)})
endfunction

function! s:NextTableChunk()
  if s:currentView == {}
    return
  endif

  if s:currentView.isEnd != 1
    let s:currentView.page = s:currentView.page + 1
    call s:currentView.generator(s:currentView.page, s:currentView.pageSize)
  endif
endfunction

function! s:PreviousTableChunk()
  if s:currentView == {}
    return
  endif

  if s:currentView.page != 1
    let s:currentView.page = s:currentView.page - 1
    call s:currentView.generator(s:currentView.page, s:currentView.pageSize)
  endif
endfunction

function! s:LineIsSeperator(line)
  let l:str = getline(a:line)

  for l:char in split(l:str, '\zs')
    if l:char != "-"
      return v:false
    endif
  endfor
  
  return v:true
endfunction

function! s:GoNextRow()
  let l:line = line(".")
  let l:column = col(".")

  if l:line + 1 == line('$')
    return
  endif

  call cursor(l:line + 1, l:column)

  if <SID>LineIsSeperator(line('.'))
    call cursor(l:line + 2, l:column)
  endif
  call UpdateCursorPosition()
endfunction

function! s:GoPreviousRow()
  let l:line = line(".")
  let l:column = col(".")

  if l:line - 1 == 1
    return
  endif

  call cursor(l:line - 1, l:column)

  if <SID>LineIsSeperator(line('.'))
    call cursor(l:line - 2, l:column)
  endif
  call UpdateCursorPosition()
endfunction

function! s:GoNextColumn()
  execute 'normal! f|'
  if col('.') != strlen(getline('.'))
    execute 'normal! w'

    if getline('.')[col('.') - 1] == '|'
      execute 'normal! b'
      call cursor(line('.'), col('.') + 2)
    endif
  else
    execute 'normal! b'

    if getline('.')[col('.') - 1] == '|'
      call cursor(line('.'), col('.') + 2)
    endif
  endif

  call UpdateCursorPosition()
endfunction

function! s:GoPreviousColumn()
  execute 'normal! F|'
  if col('.') != 1
    execute 'normal! b'

    if getline('.')[col('.') - 1] == '|'
      call cursor(line('.'), col('.') + 2)
    endif
  else
    execute 'normal! w'

    if getline('.')[col('.') - 1] == '|'
    execute 'normal! b'

      call cursor(line('.'), col('.') + 2)
    endif
  endif
  call UpdateCursorPosition()
endfunction

function! s:GoFirstColumn()
  execute 'normal! 0'
  execute 'normal! w'
  call UpdateCursorPosition()
endfunction

function! s:GoLastColumn()
  execute 'normal! $'
  execute 'normal! b'
  call UpdateCursorPosition()
endfunction

function! s:DeleteRow()
  if s:currentView.result.pk == ''
    echom "Table does not have a primary key column"
    return
  endif

  let l:lineNumber = line('.')
  let l:row = s:currentView.result.values[l:lineNumber - 3 - 1]
  let l:pk = l:row[s:currentView.result.pk]

  call UpdateCursorPosition()

  call luaeval('deta.delete(_A[1], _A[2])', [s:currentView.name, l:pk])

  call <SID>GetAllRows(s:currentView.name, s:currentView.page, s:currentView.pageSize)
endfunction

function! s:InsertRow()
  let l:lineNumber = line('.')
  let l:headers = s:currentView.result.headers
  let l:entity = {}

  for l:header in l:headers
    if l:header != s:currentView.result.pk
      let l:entity[l:header] = input(l:header . ": ")
    endif
  endfor

  call UpdateCursorPosition()

  call luaeval('deta.insert(_A[1], _A[2])', [s:currentView.name, l:entity])

  call <SID>GetAllRows(s:currentView.name, s:currentView.page, s:currentView.pageSize)
endfunction

function! s:EditColumn()
  let l:index = col('.') - 1
  let l:lineNumber = line('.')
  let l:line = getline(l:lineNumber)
  let l:columnNumber = 0
  
  for l:char in split(l:line[0:index], '\zs')
    if l:char == "|"
      let l:columnNumber = l:columnNumber + 1
    endif
  endfor

  let l:values = s:currentView.result.values[l:lineNumber - 3 - 1]
  let l:headers = s:currentView.result.headers
  if s:currentView.result.pk == ''
    echom "Table does not have a primary key column"
    return
  endif
  let l:header = l:headers[l:columnNumber - 1]
  let l:currentValue = l:values[l:header]

  let l:newValue = input(l:header . ": ", l:currentValue)

  if l:newValue == '' || l:currentValue == l:newValue
    return
  endif

  let l:changset = {}

  let l:changset[l:header] = l:newValue

  call UpdateCursorPosition()

  call <SID>Update(s:currentView.name, l:values.id, l:changset)

  call <SID>GetAllRows(s:currentView.name, s:currentView.page, s:currentView.pageSize)
endfunction

function! UpdateCursorPosition()
  if s:currentView == {}
    return
  endif

  let s:currentView.cursor.y = line('.')
  let s:currentView.cursor.x = col('.')
endfunction

function! s:GoFirstRow()
  if s:currentView.isEnd
    return
  endif

  call cursor(4, col('.'))
  call UpdateCursorPosition()
endfunction

function! s:GoLastRow()
  if s:currentView.isEnd
    return
  endif

  call cursor(line('$') - 1, col('.'))
  call UpdateCursorPosition()
endfunction

function! s:ToggleMetadata()
  if s:currentView.isMetadata == v:false
    call <SID>GetTableMetadata(s:currentView.name, s:currentView.page, s:currentView.pageSize)
  else
    call <SID>GetAllRows(s:currentView.name, s:currentView.page, s:currentView.pageSize)
  endif
endfunction

function! s:OpenQueryResultView(title, page, pageSize, result, generator, isMetadata, isCustomQuery)
  " check whether result is a dictionary
  let l:previousMetadata = v:null

  if type(a:result) == 4
    setlocal modifiable
    setlocal nowrap
    setlocal noreadonly

    if s:currentView != {}
      execute '1,$d'
      let s:currentView.isEnd = len(a:result.values) == 0
      let s:currentView.result = a:result
      let s:currentView.page = a:page
      let s:currentView.pageSize = a:pageSize
      let s:currentView.generator = a:generator
      let l:previousMetadata = s:currentView.isMetadata
      let s:currentView.isMetadata = a:isMetadata
    else
      execute 'enew | setlocal filetype=DetaQueryResultView nobuflisted buftype=nofile bufhidden=wipe noswapfile'

      setlocal nonu
      setlocal nornu

      nnoremap <silent> <buffer> l :DetaGoNextColumn<CR>
      nnoremap <silent> <buffer> w :DetaGoNextColumn<CR>
      nnoremap <silent> <buffer> h :DetaGoPreviousColumn<CR>
      nnoremap <silent> <buffer> b :DetaGoPreviousColumn<CR>
      nnoremap <silent> <buffer> 0 :DetaGoFirstColumn<CR>
      nnoremap <silent> <buffer> $ :DetaGoLastColumn<CR>
      nnoremap <silent> <buffer> j :DetaGoNextRow<CR>
      nnoremap <silent> <buffer> <C-d> :DetaGoNextRow<CR>
      nnoremap <silent> <buffer> k :DetaGoPreviousRow<CR>
      nnoremap <silent> <buffer> <C-u> :DetaGoNextRow<CR>
      nnoremap <silent> <buffer> gg :DetaGoFirstRow<CR>
      nnoremap <silent> <buffer> G :DetaGoLastRow<CR>

      if a:isCustomQuery == v:false 

        nnoremap <silent> <buffer> ]c :DetaNextTableChunk<CR>
        nnoremap <silent> <buffer> [c :DetaPreviousTableChunk<CR>
        nnoremap <silent> <buffer> e :DetaEditColumn<CR>
        nnoremap <silent> <buffer> dd :DetaDeleteRow<CR>
        nnoremap <silent> <buffer> i :DetaInsertRow<CR>
        nnoremap <silent> <buffer> - :DetaToggleMetadata<CR>

      endif

      let s:currentView = {
            \'name': a:title,
            \'bid': bufnr(''),
            \'result': a:result,
            \'pageSize': s:defaultValues.pageSize,
            \'page': s:defaultValues.page,
            \'isEnd': len(a:result.values) == 0,
            \'cursor': {
            \  'x': 3,
            \  'y': 2
            \},
            \'generator': a:generator,
            \'isMetadata': a:isMetadata
            \}
    endif

    call PrintQueryResult(a:result)
    
    setlocal nomodifiable
    setlocal readonly

    let l:lineCount = line('$')
    let l:maxCol = col('$')

    if (s:currentView.cursor.y != 2 && l:lineCount == 3) || l:previousMetadata != a:isMetadata
      let s:currentView.cursor.y = 2
      let s:currentView.cursor.x = 3
    elseif l:lineCount < s:currentView.cursor.y
      let s:currentView.cursor.y = l:lineCount
    endif

    if l:maxCol < s:currentView.cursor.x
      let s:currentView.cursor.x = l:maxCol
    endif
      
    call cursor(s:currentView.cursor.y, s:currentView.cursor.x)

  endif

endfunction

function! s:GetAllRows(tableName, ...)
  let l:page = a:0 >= 1 ? a:1 : 1
  let l:pageSize = a:0 >= 2 ? a:2 : 50
  let l:result = luaeval('deta.get_all_rows(_A[1], _A[2], _A[3])', [a:tableName, l:pageSize, l:page])

  echo l:result.pk

  call <SID>OpenQueryResultView(a:tableName, l:page, l:pageSize, l:result, 
        \function("s:GetAllRows", [a:tableName]), v:false, v:false)
endfunction

function! s:GetTableMetadata(tableName, ...)
  let l:page = a:0 >= 1 ? a:1 : 1
  let l:pageSize = a:0 >= 2 ? a:2 : 50
  let l:result = luaeval('deta.get_table_metadata(_A[1], _A[2], _A[3])', [a:tableName, l:pageSize, l:page])

  call <SID>OpenQueryResultView(a:tableName, l:page, l:pageSize, l:result,
        \function("s:GetTableMetadata", [a:tableName]), v:true, v:false)
endfunction

function! s:Update(table, id, changeset)
  call luaeval('deta.update(_A[1], _A[2], _A[3])', [a:table, a:id, a:changeset])
endfunction

function! s:Connect(connectionString)
  call luaeval('deta.set_connection_string(_A[0])', [a:connectionString])
endfunction

function! s:ChooseDatabaseSink(selected)
  execute "DetaSetDatabase " . a:selected
endfunction

function! s:ChooseDatabase()
  let l:result = luaeval('deta.get_all_databases()')
  let l:source = map(deepcopy(l:result.values), {i, v -> v.database_name})

  return l:source
endfunction

function! s:ChooseTableSink(selected)
  execute "DetaGetAll " . a:selected
endfunction

function! s:ChooseTable()
  let l:result = luaeval('deta.get_all_tables()')
  " if the result is not a dictionary (implicitely meaning v:null)
  let l:source = type(l:result) != 4 ? [] : map(deepcopy(l:result.values), {i, v -> v.table_name})

  return l:source
endfunction

let g:clap_provider_deta_tables = {
  \ 'source': function('s:ChooseTable'),
  \ 'sink': function('s:ChooseTableSink')
  \ }
let g:clap_provider_deta_databases = {
  \ 'source': function('s:ChooseDatabase'),
  \ 'sink': function('s:ChooseDatabaseSink')
  \ }

