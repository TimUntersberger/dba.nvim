lua deta = require("deta")

command! -nargs=1 DetaGetAll call <SID>GetAllRows(<q-args>)
command! -nargs=1 DetaGetTableMetadata call <SID>GetTableMetadata(<q-args>)
command! -nargs=1 DetaConnect call <SID>Connect(<q-args>)
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
  
nnoremap <leader>dg :DetaGetAll 
nnoremap <leader>dc :DetaConnect 

aug Deta
  autocmd! * <buffer>
  au filetype DetaQueryResultView au BufWipeout <buffer> call <SID>OnBufWipeout()
aug END

function! s:OnBufWipeout()
  let g:currentView = {}

  aug Deta
  aug END
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
  if g:currentView == {}
    return
  endif

  if g:currentView.isEnd != 1
    let g:currentView.page = g:currentView.page + 1
    call <SID>GetAllRows(g:currentView.name, g:currentView.page, g:currentView.pageSize)
  endif
endfunction

function! s:PreviousTableChunk()
  if g:currentView == {}
    return
  endif

  if g:currentView.page != 1
    let g:currentView.page = g:currentView.page - 1
    call <SID>GetAllRows(g:currentView.name, g:currentView.page, g:currentView.pageSize)
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
  else
    execute 'normal! b'
  endif
  call UpdateCursorPosition()
endfunction

function! s:GoPreviousColumn()
  execute 'normal! F|'
  if col('.') != 1
    execute 'normal! b'
  else
    execute 'normal! w'
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

  let l:values = g:currentView.result.values[l:line - 3 - 1]
  let l:headers = g:currentView.result.headers
  if index(l:headers, 'id') == -1
    echom "Table does not have a column that is called id"
    return
  endif
  let l:header = l:headers[l:columnNumber - 1]
  let l:currentValue = l:values[l:header]

  let l:newValue = input(l:header . ": ", l:currentValue)

  let l:changset = {}

  let l:changset[l:header] = l:newValue

  call UpdateCursorPosition()

  call <SID>Update(g:currentView.name, l:values.id, l:changset)

  call <SID>GetAllRows(g:currentView.name, g:currentView.page, g:currentView.pageSize)
endfunction

function! UpdateCursorPosition()
  if g:currentView == {}
    return
  endif

  let g:currentView.cursor.y = line('.')
  let g:currentView.cursor.x = col('.')
endfunction

function! s:GoFirstRow()
  if g:currentView.isEnd
    return
  endif

  call cursor(4, col('.'))
  call UpdateCursorPosition()
endfunction

function! s:GoLastRow()
  if g:currentView.isEnd
    return
  endif

  call cursor(line('$') - 1, col('.'))
  call UpdateCursorPosition()
endfunction

let g:currentView = {}

function! s:OpenQueryResultView(title, page, pageSize, result)
  " TODO: make <C-d> and <C-u> jump 5 rows instead of 1
  " TODO: enable a way to cancel an edit
  " TODO: make it possible to swap between metadata and data of table with a
  " dash
  " TODO(Maybe): implement a function that edits the values of the current row in
  " the database.

  " check whether result is a dictionary
  if type(a:result) == 4
    setlocal modifiable
    setlocal nowrap
    setlocal noreadonly

    if g:currentView != {}
      execute '1,$d'
      let g:currentView.isEnd = len(a:result.values) == 0
      let g:currentView.result = a:result
    else
      execute 'enew | setlocal filetype=DetaQueryResultView nobuflisted buftype=nofile bufhidden=wipe noswapfile'

      setlocal nonu
      setlocal nornu

      nnoremap <silent> <buffer> ]c :DetaNextTableChunk<CR>
      nnoremap <silent> <buffer> [c :DetaPreviousTableChunk<CR>
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
      nnoremap <silent> <buffer> e :DetaEditColumn<CR>

      let g:currentView = {
            \'name': a:title,
            \'bid': bufnr(''),
            \'result': a:result,
            \'pageSize': 50,
            \'page': 1,
            \'isEnd': len(a:result.values) == 0,
            \'cursor': {
            \  'x': 3,
            \  'y': 2
            \}
            \}
    endif

    call PrintQueryResult(a:result)
    
    setlocal nomodifiable
    setlocal readonly

    let l:lineCount = line('$')
    let l:maxCol = col('$')

    if g:currentView.cursor.y != 2 && l:lineCount == 3
      let g:currentView.cursor.y = 2
      let g:currentView.cursor.x = 3
    elseif l:lineCount < g:currentView.cursor.y
      let g:currentView.cursor.y = l:lineCount
    endif

    if l:maxCol < g:currentView.cursor.x
      let g:currentView.cursor.x = l:maxCol
    endif

    call cursor(g:currentView.cursor.y, g:currentView.cursor.x)
  endif

endfunction

function! s:GetAllRows(tableName, ...)
  let l:page = a:0 >= 1 ? a:1 : 1
  let l:pageSize = a:0 >= 2 ? a:2 : 50
  let l:result = luaeval('deta.get_all_rows(_A[1], _A[2], _A[3])', [a:tableName, l:pageSize, l:page])

  call <SID>OpenQueryResultView(a:tableName, l:page, l:pageSize, l:result)
endfunction

function! s:GetTableMetadata(tableName, ...)
  let l:page = a:0 >= 1 ? a:1 : 1
  let l:pageSize = a:0 >= 2 ? a:2 : 50
  let l:result = luaeval('deta.get_table_metadata(_A[1], _A[2], _A[3])', [a:tableName, l:pageSize, l:page])

  call <SID>OpenQueryResultView(a:tableName, l:page, l:pageSize, l:result)
endfunction

function! s:Update(table, id, changeset)
  call luaeval('deta.update(_A[1], _A[2], _A[3])', [a:table, a:id, a:changeset])
endfunction

function! s:Connect(connectionString)
  call luaeval('deta.set_connection_string(_A[0])', [a:connectionString])
endfunction
