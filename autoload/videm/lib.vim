"=============================================================================
" File: videm#lib.vim
" Author: Sagara Takahiro <vimyum@gmail.com>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" Version: 1.0
"=============================================================================

let s:cpo_save = &cpo
set cpo&vim

func! videm#lib#openMultiFiles(fileList)
	let cnt = 0
	for name in a:fileList
		let name = substitute(name, "^[ ]*", "", "") "ignore indent
		let name = substitute(name, '\s\+$', "", "")  "ignore tail space
		let name = substitute(name, '\s*#.*$', "", "")  "remove comment
		let name = fnamemodify(name,":p")
		if getftype(name) != "file"
			continue
		endif
		if cnt == 0
			call videm#tmux#sendMsg($VIDEM_MAIN, videm#tmux#openFile("-") . name)
		else 
			while videm#tmux#checkVim() == 0
				"busy loop
			endwhile
			call videm#tmux#sendMsg($VIDEM_MAIN, ":e " . name)
		endif
		let cnt += 1
	endfor
endf

func! videm#lib#openMultiFilesNew(fileList)
	let cnt = 0
	let title = ""
	let newDir = "/"
	let newlist = []
	for oname in a:fileList
		let cnt += 1
		let name = videm#string#fnameSanitize(oname)
		if getftype(name) != "file"
			if cnt == 1
				if oname[0] == "<"
					let title = substitute(oname, '<\(.*\)>', '\1', '')
				else
					let title = substitute(oname, '=\+\s*\(.*\)\s=\+', '\1', '')
				endif
			endif
			continue
		endif
		if newDir == "/"
			let newDir = strpart(name, 0, strridx(name,'/')) . "/"
		endif
		call add(newlist, name)
	endfor
	call videm#tmux#newWin()
	call videm#tmux#sendMsg("-", "cd " . newDir . " && vim " . join(newlist, " "))
	if title != ""
		call videm#tmux#renameWin("-", title)
	endif
endf

func! videm#lib#dec2bc(num)
	let num = a:num
	let str = ""
	while (num > 0)
		let rem = num % 2
		if rem == 1
			let str = "1". str
		else
			let str = "0". str
		endif
		let num = num / 2
	endwhile
	retu str
endf

"==================================
"functions for highlight
"==================================
func! videm#lib#setColor(ocolor, color, lst)
	for i in a:lst
		if i[0] == a:ocolor
			exe 'hi '. a:color .' '. i[1]
		endif
	endfor
endf

func! videm#lib#getColor(name, defcolor, ...)
	if highlight_exists(a:name)
		redir => msg
		silent exe "hi ". a:name
		redir END
	else
		let msg = a:defcolor
	endif
	if a:0 > 0
		let flg = a:1
	else
		let flg = 'a'
	endif
	let msg = videm#string#stripLF(msg)
	if flg != 'b'
		let ctermfgC = matchstr(msg, 'ctermfg=[^[:blank:]]\+')
		let guifgC   = matchstr(msg, 'guifg=[^[:blank:]]\+')
	else
		let ctermfgC = ''
		let guifgC = ''
	endif
	if flg != 'f'
		let ctermbgC = matchstr(msg, 'ctermbg=[^[:blank:]]\+')
		let guibgC   = matchstr(msg, 'guibg=[^[:blank:]]\+')
	else
		let guibgC = ''
		let ctermbgC = ''
	endif
		let msg = ctermbgC .' '. ctermfgC .' '. guibgC .' '. guifgC
	let msg = substitute(msg, '^\s\+', '', '')
	retu [a:name, substitute(msg, '\s\+$', '', '')]
endf

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: foldmethod=marker
