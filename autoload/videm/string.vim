"=============================================================================
" File: videm#string.vim
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

func! videm#string#stripLF(input_string)
	retu substitute(a:input_string, '\(.\{-}\)\n$', '\1', '')
endf

func! videm#string#strip(str)
	retu strpart(a:str, 0, strlen(a:str) - 1)
endf

func! videm#string#getDispLen(msg)
	let len = strlen(a:msg)
	return len - ((len - strlen(substitute(a:msg, ".", "x", "g")))/2)
endf

func! videm#string#padding(msg, len, pad)
	let slen = strlen(a:msg)
	if slen == a:len
		retu a:msg
	elseif slen > a:len
		retu strpart(a:msg, 0, a:len)
	endif
	retu a:msg . repeat(a:pad, (a:len - slen))
endf

func! videm#string#paddingMB(msg, len, pad)
	let dispLen = videm#string#getDispLen(a:msg)
	if strlen(a:msg) == dispLen
		retu videm#string#padding(a:msg, a:len, a:pad)
	endif
	if dispLen == a:len
		retu a:msg
	elseif dispLen > a:len
		let nstr = videm#string#trimDispLen(a:msg, a:len, 0)
		if videm#string#getDispLen(nstr) < a:len
			retu nstr . a:pad
		else
			retu nstr
		endif
	endif
	retu a:msg . repeat(a:pad, (a:len - dispLen))
endf

""TODO: use bitwise functions
func! videm#string#trimDispLen(msg, len, flg)
	let cnt = 0
	let len = 0
	while cnt < strlen(a:msg)
		let bstr = videm#lib#dec2bc(char2nr(a:msg[cnt]))
		if strlen(bstr) < 8
			let cnt += 1
			let len += 1
		elseif bstr =~ '^11'
			let len += 2
			if len > a:len && a:flg == 0
				break
			endif
			let byteLen = stridx(bstr, "0")
			let cnt += byteLen
		else
			echo "Error occured in getStripMB()"
			sleep 1
		endif
		if len >= a:len
			break
		endif
	endwhile
	return strpart(a:msg, 0, cnt)
endf

func! videm#string#fnameSanitize(name)
	let name = substitute(a:name, "^[ ]*", "", "") "ignore indent
	let name = substitute(name, '\s\+$', "", "")   "ignore tail space
	let name = substitute(name, '\s*#.*$', "", "") "remove comment
	let name = fnamemodify(name,":p")
	retu name
endf

func! videm#string#str2list(str)
	let nstr = substitute(a:str, "'", "", "g")
	let nstr = substitute(nstr, "^\[", "", "")
	let nstr = substitute(nstr, "\]$", "", "")
	if nstr[0] == "{" && nstr[len(nstr)-1] == "}"
		retu videm#string#str2dict(nstr)
	endif
	retu split(nstr, ", ", 1)
endf

func! videm#string#str2dict(str)
	let tmplist = []
	let tmpDict = {}
	for i in split(a:str, ", ", 1)
		let nstr = substitute(i, "^\{", "", "")
		let nstr = substitute(nstr, "\}$", "", "")
		let line = split(nstr, ': ', 1)
		let dkey = line[0]
		let dval = line[1]
		let tmpDict[dkey] = dval
		if match(i, "\}$") >= 0
			call add(tmplist, deepcopy(tmpDict))
			let tmpDict = {}
		endif
	endfor
	retu tmplist
endf

func! videm#string#dateSubsitute(str)
	let datestr = system("date +%Y%m%d")
	retu substitute(a:str, '%t', videm#string#stripLF(datestr), "g")
endf

""TODO: use bitwise functions
func! videm#string#trimDispLenRev(msg, len, flg)
	let cnt = strlen(a:msg) - 1
	let pcnt = -1
	let len = 0
	while cnt > 0
		let bstr = videm#lib#dec2bc(char2nr(a:msg[cnt]))
		if strlen(bstr) < 8
			let len += 1
			let pcnt = cnt
		elseif bstr =~ '^11'
			let len += 2
			if len > a:len && a:flg == 0
				echo "break1: " . len
				let cnt = pcnt
				break
			endif
			let byteLen = stridx(bstr, "0")
			let pcnt = cnt
		endif
		if len >= a:len
			break
		endif
		let cnt -= 1
	endwhile
	if pcnt < 0 
		return ""
	endif
	return strpart(a:msg, cnt)
endf

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: foldmethod=marker
