"=============================================================================
" File: viske#cal.vim
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

scriptencoding utf-8
set encoding=utf-8

if !exists('s:is_enabled')
	let s:is_enabled = 0
else
	finish
endif

let s:wdayTitlesJP = ["日","月","火","水","木","金","土"]
let s:wdayTitlesCN = ["天","一","二","三","四","五","六"]
let s:wdayTitlesEN = ["Su","Mo","Tu","We","Th","Fr","Sa"]
let s:calDict = {}

" Today Data
let s:tyear=1970
let s:tmon =1
let s:tday =1

" Current Data
let s:year=1970
let s:mon =1
let s:day =1

let s:useTabTitle = 0

func viske#cal#useTabLine(num)
	let s:useTabTitle = a:num
endf

func viske#cal#getTodayDict(...)
	let tyear = strftime('%Y')
	let tmon  = matchstr(strftime('%m'), '[^0].*')
	let tday  = matchstr(strftime('%d'), '[^0].*')
	if a:0 == 1
		let tday  = matchstr(a:1, '[^0].*')
	elseif a:0 == 2
		let tday  = matchstr(a:1, '[^0].*')
		let tmon  = matchstr(a:2, '[^0].*')
	elseif a:0 == 3
		let tday  = matchstr(a:1, '[^0].*')
		let tmon  = matchstr(a:2, '[^0].*')
		let tyear = matchstr(a:3, '[^0].*')
	elseif a:0 > 3
		retu {}
	endif
	retu {'day':tday, 'mon':tmon, 'year':tyear }
endf

func viske#cal#display(...)
	let dayDict = call("viske#cal#getTodayDict", a:000)
	let s:year = dayDict['year']
	let s:mon  = dayDict['mon']
	let s:day  = dayDict['day']

	let todayDict = viske#cal#getTodayDict()
	let s:tyear = todayDict['year']
	let s:tmon  = todayDict['mon']
	let s:tday  = todayDict['day']
	set nowrap
	nno <silent><buffer> <CR>	:cal <SID>Select()<CR>:<BS>
	nno <silent><buffer> <C-n>	:silent cal <SID>NextMon()<CR>
	nno <silent><buffer> <C-p>	:silent cal <SID>PrevMon()<CR>
	nno <silent><buffer> q		:qa!<CR>
    nno <silent><buffer> tt     :cal viske#cal#testFunc()<CR>
	cal s:SetHilight()
	cal viske#cal#reload()
endf

func viske#cal#reload()
	setl modifiable
	exe "%delete"
	cal s:BulidCal(s:year, s:mon)
	setl nomodifiable
	cal s:MoveToday()
	norm! 10
	if s:tyear != s:year || s:tmon != s:mon
		return
	endif
	if s:tday < 10
		exe "syn match VidemCalToday '". '\s\@<=\s'. 
					\ s:tday .'\s\@=' . "' "
	else
		exe "syn match VidemCalToday '". '\s\@<='.
					\ s:tday ."'"
	endif
endf

func s:SetHilight()
	let cList = []
	cal add(cList, viske#lib#getColor("VidemCalToday", 'ctermfg=3 ctermbg=5 guifg=#112233 guibg=#88CCEE'))
	cal add(cList, viske#lib#getColor("VidemCalHolyday", 'ctermfg=1 guifg=#EEAA99'))
	cal add(cList, viske#lib#getColor("VidemCalWDayTitle", 'ctermfg=4 guifg=#7788EE'))
	cal add(cList, viske#lib#getColor("VidemCalDateTitle", 'ctermfg=6 guifg=#77EE88'))
	for i in cList
		exe 'hi '. i[0] .' '. i[1]
	endfor

	hi TabLineFill ctermfg=5 ctermbg=3

	let adj = (winwidth(0) - 20) / 2 + 1
	let adj2 = adj + 1
	exe "syn match VidemCalHolyday '". '\%(^\s\{'. adj .
				\ '}.\{18}\)\@<=\s*\d\{1,2}' ."' contains=ALL"
	exe "syn match VidemCalHolyday '". '^\s\{'. adj .','.
				\ adj2 .'}\d\+' . "' contains=ALL"
endf

func! s:GetWdayTitle()
	if !exists("g:wdayTitlesLang")
		retu s:wdayTitlesJP
	endif g:wdayTitlesLang == 'EN'
		retu s:wdayTitlesEN
	elseif g:wdayTitlesLang == 'CN'
		retu s:wdayTitlesCN
	endif
	retu s:wdayTitlesJP
endf

func! s:BulidCal(year, mon)
	cal cursor(1,1)
	let dp = ""
	let wdayTitleList = s:GetWdayTitle()
	let wdayTitle = join(wdayTitleList, ' ')
	exe "syn match VidemCalWDayTitle '". wdayTitle ."'"
	let adjs = repeat(" ", (winwidth(0) - 20) / 2)
	let dp =  adjs ." ". wdayTitle
	put =dp
	let lday  = viske#cal#getLastDay(a:year, a:mon)
	let wday = viske#cal#getWDay(a:year, a:mon, 1)
	let day = 1
	let dp =  repeat('   ', wday)
	while day <= lday
		if day < 10
			let dp .= '  '. day
		else
			let dp .= ' '. day
		endif
		let day  += 1
		let wday += 1
		if (wday % 7) == 0
			let wday = 0
			let dp = adjs . dp
			put =dp
			let dp = ""
		endif
	endwhile
	if strlen(dp)
		let dp = adjs . dp
		put =dp
	endif

	let dateTitle = "<". a:year ."年". a:mon . "月>"
	let pad =(winwidth(0) - viske#string#getDispLen(dateTitle))/2 + 2
	if s:useTabTitle == 0
		let pads = repeat(" ", pad)
		cal setline(1, pads . dateTitle . pads)
		syn match VidemCalDateTitle '^\s\+<.\+>\s\+$'
	else
		let pads = repeat('\ ', pad)
		let tabTitle= pads . dateTitle
		exe "set tabline=" . tabTitle
		set showtabline=2
	endif
endf

func! viske#cal#getLastDay(year, mon)
	if a:mon == 2
		if a:year % 4==0
			if (a:year % 100) == 0 && (a:year % 400) != 0
				retu 28
			else 
				retu 29 
			endif
		else
			return 28
		endif
	elseif a:mon == 4 || a:mon == 6 || 
				\ a:mon==9 || a:mon == 11
		retu 30
	else 
		retu 31
	endif
endf

func! viske#cal#getWDay(year, mon, day)
	let yu = matchstr(a:year, '^\d\{2}')
	let yl = matchstr(a:year, '\d\{2}$')
	if a:mon < 2
		let m = a:mon + 12
	else
		let m = a:mon
	endif
	return (a:day + (26*(m + 1))/10 + yl + (yu/4) + (yl/4) + (yu*5) - 1) % 7
endf

func! s:MoveToday()
	if s:mon != s:tmon || s:year != s:tyear
		exe 'syn clear VidemCalToday'
		cal search(' 1 ', "cw")
		cal cursor(line('.') + 1, col('.'))
	elseif s:tday < 10
		cal search('\s\@<=\s'. s:tday .'\s\@=' , 'cwe')
	else
		cal search('\s\@<='.   s:tday .'\s\@=' , 'cwe')
	endif
	norm! 10<C-y>
endf

function! s:NextMon()
    let s:mon += 1
    if s:mon > 12
        let s:mon   = 1
        let s:year += 1
    endif
	cal viske#cal#reload()
endfunction

func! s:PrevMon()
    let s:mon -= 1
    if s:mon < 1
        let s:mon   = 12
        let s:year -= 1
    endif
	cal viske#cal#reload()
endf

func viske#cal#setSelectFunc(fname)
	let s:selectFunc = function(a:fname)
endf

func s:DefaultSelect(day, mon, year)
	echo "the day is ". a:year. "/". a:mon ."/". a:day
	echo "Please overwirite select function."
	sleep 3
endf

let s:selectFunc = function("s:DefaultSelect")
func s:Select()
	let day = expand("<cword>")
	if strlen(day) <= 0
		return
	endif
	cal call(s:selectFunc, [day, s:mon, s:year])
endf

func! viske#cal#testFunc()
	echo "syn match VidemCalToday '". '\s\@<=\s'. s:tday .'\s\@=' . "' "
	cal getchar()
endf

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: foldmethod=marker
