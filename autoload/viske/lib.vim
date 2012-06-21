"=============================================================================
" File: viske#lib.vim
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

func! viske#lib#dec2bc(num)
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
func! viske#lib#setColor(ocolor, color, lst)
	for i in a:lst
		if i[0] == a:ocolor
			exe 'hi '. a:color .' '. i[1]
		endif
	endfor
endf

func! viske#lib#getColor(name, defcolor, ...)
	if highlight_exists(a:name)
		redir => msg
		silent exe "hi ". a:name
		redir END
	else
		let msg = a:defcolor
	endif
	if matchstr(msg, 'clear') != ""
		let msg = a:defcolor
	endif
	if a:0 > 0
		let flg = a:1
	else
		let flg = 'a'
	endif
	let msg = viske#string#stripLF(msg)
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
