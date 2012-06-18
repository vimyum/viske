"=============================================================================
" File: viske.vim
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

" Set Default Values {{{
let s:subWinHeight = get(g:, "ViskeSubWinHeight",  7)
let s:todoWinWidth = get(g:, "ViskeTodoWinWidth", 40)
let s:calWinWidth  = get(g:, "ViskeCalWinWidth" , 25)
let s:scheduleDir  = get(g:, "ViskeDir", $HOME ."/Schedule/")
let s:cutDownMsg   = get(g:, "ViskeCutDownMsg", 0)
let s:dispMode     = get(g:, "ViskeDispMode",   1)
let s:startTime    = get(g:, "ViskeStartTime",  8)
let s:endTime      = get(g:, "ViskeEndTime",   20)
let s:widthFuzzy   = get(g:, "ViskeWidthFuzzy", 2)
let g:ViskeLang    = get(g:, "ViskeLang", "us")
"}}}

" Task Containers {{{
let s:taskArray    = []
let s:taskLookup   = {}
let s:barLookup    = {}
let s:deletedTasks = []
"}}}

" TaksList Lookup IDs {{{
let s:ID_Year	= 0
let s:ID_Mon	= 1
let s:ID_Day	= 2
let s:ID_Start	= 3
let s:ID_End	= 4
let s:ID_Flag	= 5
let s:ID_Msg	= 6
let s:ID_RStart	= 7
let s:ID_REnd	= 8
let s:ID_ID		= 9
let s:ID_Desc	= 10
"}}}

" Script Variables {{{
let s:year=1999
let s:mon=1
let s:day=1
let s:splitChar = '\$\$'
let s:taskDelimiter = '$$'
let s:linePeriod = 8

let s:taskLine    = 1
let s:taskMaxLine = 0
let s:todayLine   = 0

let s:winNr = {'main':0, 'sub':0, 'cal':0, 'todo':0}
let s:posArray  = {}
let s:offset = 2

let s:winl = 0
let s:YankBuf = []
let s:VidemScheTimeFocus = 0

if !exists("g:VidemTaskTypeMark")
	let g:VidemTaskTypeMark  = ['', '#', '!', '+', '%', '*']
endif

let s:taskTypeTodoNum = 6 
let s:taskTypeMarkNum = { 1:'', 2:'#', 3:'!', 4:'+', 5:'%', 6:'*'}
let s:taskTypeMark = {' ':1, '#':2, '!':3, '+':4, '%':5, '*':6}
let s:todoTypeMark = {'+':1, '!':2, '-':3}
"}}}

"Lookup Tables {{{
let s:timeList = 
			\['00','1','2','3','4','5','6','7','8',
			\ '9','10','11','12','13','14','15','16','17','18',
			\ '19','20','21','22','23','24']
let s:timeListMin = 
			\['00','1','2','3','4','5','6','7','8',
			\ '9','10','11','12','13','14','15','16','17','18',
			\ '19','20','21','22','23','24']
let s:monthLT =
			\['-','Janualy', 'Feburary', 'March', 'April', 'May', 'June', 'July',
			\ 'Augast', 'September', 'November', 'December']
"}}}

func! viske#start(...) "{{{

	let dayDict = call("videm#cal#getTodayDict", a:000)
	let s:year = dayDict['year']
	let s:mon  = dayDict['mon']
	let s:day  = dayDict['day']

	set buftype=nowrite
	set noswapfile
	set nonumber
	set nowrap

	cal s:SetHighLight()

	"<dispMode> 0: Main/Sub, 1: Main/Sub/Cal, 2:Main/Sub/Todo/Cal
	cal s:SplitWindow(s:dispMode)
	nno q	:qa!<CR>

	cal s:SetSubWin()
	if s:winNr['todo'] > 0
		cal s:SetTodoWin()
	endif
	if s:winNr['cal'] > 0
		cal s:SetCalWin()
	endif

	autocmd VimLeave *	:call <SID>Close()
	exe "set statusline=" . repeat(winwidth(1),"-")

	cal s:SetLabels()
	cal videm#cal#setSelectFunc("viske#selectCal")

	cal s:SetMainWin(s:day, s:mon, s:year)
endf "}}}

func! s:SetLabels() "{{{
	if exists("g:ViskeTaskTypeLabel")
		let s:taskTypeLabel = g:ViskeTaskTypeLabel
	else
		if g:ViskeLang == "jp"
			let s:taskTypeLabel = ['\ ', "(出張)", "%#ViskeIMPT#(！重要！)", "(プライベート)", "(打合せ)", "(備考)"]
		elseif g:ViskeLang == "cn"
			let s:taskTypeLabel = ['\ ', "(出差)", "%#ViskeIMPT#(！重要！)", "(私事)", "(会议)", "(备考)"]
		else
			let s:taskTypeLabel = ['\ ', "(Leaving)", "%#ViskeIMPT#(Important)", "(Private)", "(Meeting)", "(Todo)"]
		endif
	endif
	if exists("g:ViskeDayLabel")
		let s:dayDispList = g:ViskeDayLabel
	else
		if g:ViskeLang == "jp"
			let s:dayDispList = ['日', '月', '火', '水', '木', '金', '土']
		elseif g:ViskeLang == "cn"
			let s:dayDispList = ['天', '月', '火', '水', '木', '金', '土']
		else
			let s:dayDispList = ['Sun', 'Mon', 'Tue', 'Wen', 'Thu', 'Fri', 'Sat']
		endif
	endif
endf "}}}

func! s:SetHighLight() "{{{
	"
	"Main Window
	let cList = []
	if has("gui_running")
		cal add(cList, videm#lib#getColor("ViskeMain", 'guibg=#112222 guifg=#EEEEBB'))
		cal add(cList, videm#lib#getColor("ViskeTaskSelected", 'guifg=#AAAA33'))
	else
		cal add(cList, videm#lib#getColor("ViskeMain", 'ctermbg=none ctermfg=none'))
		cal add(cList, videm#lib#getColor("ViskeTaskSelected", 'ctermfg=7 guifg=#EEEEEE'))
	endif

	cal add(cList, videm#lib#getColor("ViskeTimeLine", 'ctermfg=7 ctermbg=4 guifg=#333388 guibg=#8888AA'))
	cal add(cList, videm#lib#getColor("ViskeTimeLineSelected", 'ctermfg=7 ctermbg=6'))

	cal add(cList, videm#lib#getColor("ViskeTask",  'ctermfg=7 guifg=#BBBBCC'))
	cal add(cList, videm#lib#getColor("ViskeTask1", 'ctermfg=0 ctermbg=2 guifg=#225522 guibg=#77CC99'))
	cal add(cList, videm#lib#getColor("ViskeTask2", 'ctermfg=0 ctermbg=3 guifg=#332233 guibg=#9955AA'))
	cal add(cList, videm#lib#getColor("ViskeTask3", 'ctermfg=0 ctermbg=1 guifg=#552222 guibg=#CC2244'))
	cal add(cList, videm#lib#getColor("ViskeTask4", 'ctermfg=0 ctermbg=5 guifg=#225522 guibg=#99AA55'))
	cal add(cList, videm#lib#getColor("ViskeTask5", 'ctermfg=0 ctermbg=6 guifg=#112233 guibg=#446699'))

	cal add(cList, videm#lib#getColor("ViskeItemBullet", 'ctermfg=6 guifg=#333366'))
	cal add(cList, videm#lib#getColor("ViskeItem",       'ctermfg=7 guifg=#DDDDFF'))
	cal add(cList, videm#lib#getColor("ViskeTodoImp",    'ctermfg=1 guifg=#FF4466'))
	cal add(cList, videm#lib#getColor("ViskeTodoDone",   'ctermfg=0 guifg=#888888'))
	cal add(cList, videm#lib#getColor("ViskeTodo",       'ctermfg=2 guifg=#AAFFCC'))

	cal add(cList, videm#lib#getColor("ViskeHolyday", 'ctermfg=1 guifg=#CC8888'))
	cal add(cList, videm#lib#getColor("ViskeWeekday", 'ctermfg=4 guifg=#8888CC'))
	cal add(cList, videm#lib#getColor("ViskeDay",     'ctermfg=7 guifg=#EEFFEE'))

	cal add(cList, videm#lib#getColor("ViskeInputTime",  'ctermfg=3 guifg=#88CC88'))
	cal add(cList, videm#lib#getColor("ViskeInputDelim", 'ctermfg=0 guifg=#444444'))
	cal add(cList, videm#lib#getColor("ViskeInputPlace", 'ctermfg=6 guifg=#AA99CC'))
	cal add(cList, videm#lib#getColor("ViskeVBoundary", 'ctermfg=0 ctermbg=0 guifg=#111111 guibg=#111111'))

	let boundaryCL = videm#lib#getColor("ViskeBoundary", 'ctermfg=0 guibg=#111111')
	let boundaryStr = videm#lib#getColor("ViskeBoundaryStr", 'ctermbg=7 guifg=#FFFFFF')
	if has("gui_running")
		let boundaryCL[1]  = matchstr(boundaryCL[1],'guibg=[^[:blank:]]\+')
		let boundaryStr[1] = matchstr(boundaryStr[1],'guifg=[^[:blank:]]\+')
	else
		let boundaryCL[1] = matchstr(boundaryCL[1],'ctermfg=[^[:blank:]]\+')
		let boundaryStr[1] = matchstr(boundaryStr[1],'ctermbg=[^[:blank:]]\+')
	endif
	if strlen(boundaryCL[1]) < 1
		let boundaryCL[1] = "ctermfg=0 guibg=#111111"
	endif
	cal add(cList, ["ViskeBoundary_A", boundaryCL[1] .' '. boundaryStr[1]])
	cal add(cList, ["ViskeBoundary_B", boundaryCL[1] .' ctermbg=2'])
	
	let normalColor = videm#lib#getColor("ViskeMain", 'guifg=#EEEEEE guibg=#112222')[1]
	"Twice Declartion is required!!
	exe 'hi Normal '. normalColor
	exe 'hi Normal '. normalColor

	for i in cList
		exe 'hi '. i[0] .' '. i[1]
	endfor
	exe "hi ViskeIMPT ctermfg=1 guifg=#FF3333 ctermbg=0 guibg=#000000"
 
	cal videm#lib#setColor("ViskeMain", "NonText", cList)
	cal videm#lib#setColor("ViskeVBoundary", "VertSplit", cList)
	cal videm#lib#setColor("ViskeTimeLineSelected", "CursorLine", cList)
	cal videm#lib#setColor("ViskeBoundary_A", "StatusLine", cList)
	cal videm#lib#setColor("ViskeBoundary_B", "StatusLineNC", cList)
	cal videm#lib#setColor("ViskeTask", "ViskeTask_A", cList)
	cal videm#lib#setColor("ViskeTask", "ViskeTask_B", cList)

	let s:TimeLineSelectedColor = videm#lib#getColor("ViskeTimeLineSelected", "cterfbg=0")[1]
	let s:TaskSelectedColor = videm#lib#getColor("ViskeTaskSelected", 
				\ "ctermfg=7 guifg=#EEEEEE", 'f')[1] .
				\ " ctermbg=NONE guibg=NONE term=underline gui=underline"

endf "}}}

func! s:SetSubWin() "{{{
	exe s:winNr['sub'] . "wincmd w"
	ino <silent><buffer>	<NL>	<ESC>:cal <SID>RegTask()<CR>:<BS>
	ino <silent><buffer>	<C-r>	<ESC>:cal <SID>RegTask()<CR>:<BS>
	ino <silent><buffer>	<C-q>	<ESC>:wincmd k<CR>:<BS>
	ino <silent><buffer>	<C-w>	<ESC>:wincmd k<CR>:<BS>
	ino <silent><buffer>	<C-n>	<C-o>:cal <SID>ScheIncTime("inc")<CR>:<BS>
	ino <silent><buffer>	<C-p>	<C-o>:cal <SID>ScheIncTime("dec")<CR>:<BS>
	ino <silent><buffer>	<C-u>	<ESC>0f>2ld$a
	ino <silent><buffer>	<C-u>	<ESC>0f>2ld$a
	ino <silent><buffer>	<C-a>	<ESC>0f>la
	ino <silent><buffer>	<C-e>	<C-o>:cal <SID>ToggleTimeFocus()<CR>:<BS>
	nno <silent><buffer>	<CR>	:cal <SID>RegTask()<CR>:<BS>
	nno <silent><buffer>	<C-r>	:cal <SID>RegTask()<CR>:<BS>
	nno <silent><buffer>	<C-w>	:wincmd k<CR>:<BS>
	syn match ViskeInputTime /[0-9]\+:[0-9]\+/
	syn match ViskeInputDelim /\s>\s/
	syn match ViskeInputPlace /@/
	syn match ViskeTodoImp /^\s*!.*$/
	syn match ViskeTodoDone /^\s*-.*$/
	exe "resize ". s:subWinHeight
	exe "vert resize 999"
endf "}}}

func! s:SetTodoWin() "{{{
	exe s:winNr['todo'] . "wincmd w"
	vert resize str2nr(s:todoWinWidth) + str2nr(s:calWinWidth)
	exe "vert resize ". (str2nr(s:todoWinWidth) + str2nr(s:calWinWidth))
endf "}}}

func! s:SetCalWin() "{{{
	exe s:winNr['cal'] . "wincmd w"
	exe "vert resize ". s:calWinWidth
	cal videm#cal#display()
endf "}}}

func! s:SaveTasks() "{{{
	let fname = s:scheduleDir . s:year . "_" . s:mon . ".dat"
	let tmp = []
	for i in s:taskArray
		if len(i) > s:ID_Desc
			cal add(tmp, join(i, s:taskDelimiter))
		else
			cal add(tmp, join(i, s:taskDelimiter).'$$')
		endif
	endfor
	try
		call writefile(tmp, fname)
	catch
		echo 'failed to save "'. fname ."'"
		cal getchar()
	endtry
endf "}}}

func! s:Close() "{{{
	call s:SaveTasks()
endf "}}}

func! s:SetMainWin(day, mon, year) "{{{
	exe s:winNr['main'] ."wincmd w"

	setl conceallevel=2
	setl concealcursor=nvic

	syn match ViskeTask_A '\s?1?.*' contains=ViskeTask1,ViskeTask2,ViskeTask3,ViskeTask4,
				\ ViskeTask5,Dlm1,Dlm2,Dlm3,Dlm4,Dlm5,DlmH,ViskeTask_B
	syn match ViskeTask_B '.\+?1?'  contains=ViskeTask1,ViskeTask2,ViskeTask3,ViskeTask4,
				\ ViskeTask5,Dlm1,Dlm2,Dlm3,Dlm4,Dlm5,DlmH,ViskeTask_A

	syn match ViskeTimeLine /^|.*|$/ contains=ALL

	syn match DlmH /?1?/   conceal
	syn match Dlm1 /\$1\$/ conceal
	syn match Dlm2 /\$2\$/ conceal
	syn match Dlm3 /\$3\$/ conceal
	syn match Dlm4 /\$4\$/ conceal
	syn match Dlm5 /\$5\$/ conceal

	syn match ViskeTask1 '\%(?1?\).*\%(\$1\$\)' contains=Dlm1,DlmH
	syn match ViskeTask2 '\%(?1?\).*\%(\$2\$\)' contains=Dlm2,DlmH
	syn match ViskeTask3 '\%(?1?\).*\%(\$3\$\)' contains=Dlm3,DlmH
	syn match ViskeTask4 '\%(?1?\).*\%(\$4\$\)' contains=Dlm4,DlmH
	syn match ViskeTask5 '\%(?1?\).*\%(\$5\$\)' contains=Dlm5,DlmH

	syn match ViskeItemBullet /^\s\*/ 
	syn match ViskeItem /^\s\*\s.*/  contains=ViskeItemBullet
	syn match ViskeTodoImp /^\s\*\s!.*/ contains=ViskeItemBullet,ViskeItemMK
	syn match ViskeTodoDone /^\s\*\s-.*/ contains=ViskeItemBullet,ViskeItemMK
	syn match ViskeTodo /^\s\*\s+.*/ contains=ViskeItemBullet,ViskeItemMK
	syn match ViskeItemMK /[!+\-]/     conceal
	syn match ViskeDay /^\s*[0-9]\+/ 

	syn match ViskeHolyday /^\s*\d\{1,2}.*\$1\$/ contains=ViskeDay,Dlm1
	syn match ViskeWeekday /^\s*\d\{1,2}(.*)$/   contains=ViskeDay

	set laststatus=0
	set statusline=\ 
	set cursorline

	nno <silent><buffer> K	:silent cal <SID>VMove("K")<CR>
	nno <silent><buffer> J	:silent cal <SID>VMove("J")<CR>
	nno <silent><buffer> k	:silent cal <SID>VMove("k")<CR>
	nno <silent><buffer> j	:silent cal <SID>VMove("j")<CR>
	nno <silent><buffer> l	:silent cal <SID>HMove("l")<CR>
	nno <silent><buffer> h	:silent cal <SID>HMove("h")<CR>
	nno <silent><buffer> L	:silent cal <SID>HMove("L")<CR>
	nno <silent><buffer> H	:silent cal <SID>HMove("H")<CR>
	nno <silent><buffer> 0		0l
	vno <silent><buffer> <CR>	v:silent cal  <SID>MakeTask(0)<CR>:<BS>
	vno <silent><buffer> <NL>	v:silent cal  <SID>MakeTask(0)<CR>:<BS>
	nno <silent><buffer> <CR>	:call   <SID>MakeTask(1)<CR>:<BS>
	nno <silent><buffer> <NL>	:call   <SID>MakeTask(1)<CR>:<BS>
	nno <silent><buffer> dd		:call 	<SID>TaskDelete()<CR>:<BS>
	nno <silent><buffer> p		:call 	<SID>TaskPaste()<CR>:<BS>
	nno <silent><buffer> yy		:call 	<SID>TaskYank()<CR>:<BS>
	nno <silent><buffer> cc		:call 	<SID>TaskChange()<CR>:<BS>
	nno <silent><buffer> +		:call	<SID>FlagChange("todo")<CR>:<BS>
	nno <silent><buffer> -		:call	<SID>FlagChange("done")<CR>:<BS>
	nno <silent><buffer> !		:call	<SID>FlagChange("imp")<CR>:<BS>
	nno <silent><buffer> *		:call	<SID>FlagChange("none")<CR>:<BS>
	nno <silent><buffer> %		:call	<SID>FlagChange("%")<CR>:<BS>
	nno <silent><buffer> +		:call	<SID>FlagChange("+")<CR>:<BS>
	nno <silent><buffer> #		:call	<SID>FlagChange("#")<CR>:<BS>
	nno <silent><buffer> !		:call	<SID>FlagChange("!")<CR>:<BS>
	nno <silent><buffer> gm		:call	<SID>MoveMiddle()<CR>:<BS>
	nno <silent><buffer> gh		:call	<SID>MoveToday()<CR>:<BS>

	nno <buffer> > :cal <SID>ModifyTask(">")<CR>:<BS>
	nno <buffer> < :cal <SID>ModifyTask("<")<CR>:<BS>
	nno <buffer> } :cal <SID>ModifyTask("}")<CR>:<BS>
	nno <buffer> { :cal <SID>ModifyTask("{")<CR>:<BS>
	nno <buffer> ) :cal <SID>ModifyTask(")")<CR>:<BS>
	nno <buffer> ( :cal <SID>ModifyTask("(")<CR>:<BS>

	nno <silent> <C-o> :cal <SID>FocusCal()<CR>:<BS>

	"test command
	nno <buffer> T					:call <SID>ScheTest()<CR>
	nno <buffer> r					:call <SID>Refresh()<CR>
	nno <buffer> s					:call <SID>SaveTasks()<CR>
	auto VimResized <buffer> :cal <SID>Refresh()

	cal s:SetWinWidth()
	cal s:ReadTasks(a:mon, a:year) 
	silent cal s:Show(a:day, a:mon, a:year)
endf "}}}

func! s:Refresh() "{{{
	exe s:winNr['sub'] . "wincmd w"
	exe "resize ". s:subWinHeight
	exe s:winNr['cal'] . "wincmd w"
	exe "vert resize ". s:calWinWidth
	cal videm#cal#reload()
	exe s:winNr['main'] . "wincmd w"
	cal s:SetWinWidth()
	silent cal s:Show(s:day, s:mon, s:year)
endf "}}}

func! s:SetWinWidth() "{{{
	if exists("g:ScheduleMinSlot") && g:ScheduleMinSlot > 2
		let s:minSlot = g:ScheduleMinSlot
	else
		let tmp = (winwidth(0) -2 + s:widthFuzzy)/((s:endTime - s:startTime + 1)*2)
		let s:minSlot = (tmp < 2) ? 2 : tmp
	endif
	let s:timeSlot  = s:minSlot * 2
	let s:winHeight = winheight(0)
	let s:winWidth  = s:timeSlot * (s:endTime - s:startTime + 1) + 2
	if videm#string#getDispLen(s:timeList[0]) > s:timeSlot
		let s:timeList = s:timeListMin
	endif

	exe "vno <buffer> L ". s:timeSlot ."l" 
	exe "vno <buffer> H ". s:timeSlot ."h"
	exe "vno <buffer> l ". s:minSlot  ."l"
	exe "vno <buffer> h ". s:minSlot  ."h"

endf "}}}

func! s:Show(day, mon, year) "{{{
	let s:taskLookup  = {}
	let s:barLookup   = {}
	let s:taskLine    = 1
	let s:taskMaxLine = 0
	cal sort(s:taskArray, "s:TaskListSort")
	let eday = videm#cal#getLastDay(a:year, a:mon)
	let wday = videm#cal#getWDay(a:year, a:mon, 1)
	setl modifiable
	%delete
	cal s:FillCanvas(93 + len(s:taskArray)) 
	cal s:MakeTimeLine('|')
	for i in range(1, eday)
		if a:day == i
			let s:todayLine = s:taskLine
		endif
		let wday = s:ShowDayLine(i, wday)
		if s:ShowTasks(printf("%d",i)) == 0
			cal s:ShowTimeLine()
		endif
		let  s:taskLine += 1
	endfor
	setl nomodifiable
	cal cursor(s:todayLine + 1, 2)
	if s:winl > 0
		exe 'norm! zt'. s:winl .''
	else
		exe 'norm! zt'
	endif
endf "}}}

func! s:FillCanvas(line) "{{{
	for i in range(1, a:line)
		call append(1, repeat(' ', s:winWidth))
	endfor
endf "}}}

func! s:MakeTimeLine(delim) "{{{
	let s:timeTitle = a:delim
	let pos = 2 - s:minSlot
	for i in range(s:startTime, s:endTime)
		let s:timeTitle = s:timeTitle . 
					\videm#string#padding(s:timeList[i], s:timeSlot, ' ')
		for j in range(0,1)
			let idx = i + (j * 0.5)
			"let pos = s:timeSlot * (i - s:startTime) + (j*(s:minSlot)) + s:offset
			let pos += s:minSlot
			"cal extend(s:posArray, {s:FtoS(idx) : pos})
			let s:posArray[s:FtoS(idx)] = pos
		endfor
	endfor
	let s:posArray[s:FtoS(s:endTime + 1)] = pos + s:minSlot
	let s:timeTitle = s:timeTitle . a:delim
endf "}}}

func! s:ShowDayLine(day, wday) "{{{
	let dayTitle = ""
	let daystr = (strlen(a:day) < 2) ? ' ' . a:day : a:day
	if a:wday == 0 || a:wday == 6
		let dayTitle = daystr ."(". s:dayDispList[a:wday] .")$1$"
	else
		let dayTitle = daystr ."(". s:dayDispList[a:wday] .")" 
	endif
	call setline(s:taskLine, dayTitle)
	let s:taskLine += 1
	call extend(s:barLookup, {s:taskLine : a:day})
	if a:wday < 6
		return a:wday + 1
	endif
	retu 0
endf "}}}

func! s:ShowTimeLine() "{{{
	call setline(s:taskLine, s:timeTitle)
	let s:taskLine += 1
endf "}}}

func! s:ShowTasks(day) "{{{
	let cnt  = 0
	let tcnt = 0
	for i in s:taskArray
		if i[s:ID_Day] != a:day
			let tcnt += 1
			continue
		endif
		if cnt % s:linePeriod == 0
			cal s:ShowTimeLine()
		endif
		if i[s:ID_Flag] == '6' "todo task
			cal setline(s:taskLine, ' * '.  i[s:ID_Msg])
		else
			let startp  = s:GetPos(i[s:ID_Start])
			let endp    = s:GetPos(i[s:ID_End])
			let taskLen = endp - startp
			let dispmsg = s:MakeDispTask(i[s:ID_Msg], i[s:ID_Flag],
						\ taskLen , startp)
			cal setline(s:taskLine, repeat(' ', (startp - dispmsg[1]-1)). dispmsg[0]) 
		endif
		cal extend(s:taskLookup, {s:taskLine : tcnt})
		let s:taskLine += 1
		let cnt  += 1
		let tcnt += 1
	endfor
	let s:taskMaxLine = s:taskLine
	retu cnt
endf "}}}

func s:ShowTaskInSubWin(id) "{{{
	%delete
	let tmp = s:taskArray[s:taskLookup[a:id]]
	exe 'set statusline='. s:taskTypeLabel[(str2nr(tmp[s:ID_Flag])-1)]
	if tmp[s:ID_Flag] == '6'
		let msg = ' '. tmp[s:ID_Msg]
	else
		let msg = ' '. tmp[s:ID_RStart] .' - '. tmp[s:ID_REnd] 
					\ .' > '. tmp[s:ID_Msg]
	endif
	cal setline(1, msg)

	if s:IsDesc(tmp) > 0
		cal append(1, "")
		let cnt = 2
		for i in split(tmp[s:ID_Desc], '%%')
			cal append(cnt, ' ' . i)
			let cnt += 1
		endfor
	endif

	cal cursor(1, col('$'))
endf "}}}

func! s:ReadTasks(mon, year) "{{{
	let fname = s:scheduleDir . a:year . "_" . a:mon . ".dat"
	if getftype(fname) != "file"
		echo 'failed to read "'. fname ."'"
		cal getchar()
	else
		let tmp = readfile(fname)
		for i in tmp
			cal add(s:taskArray, split(i, '\$\$'))
		endfor
	endif
	cal s:WebFuncGet()
endf "}}}

func! s:GetPos(time) "{{{
	retu s:posArray[a:time]
endf "}}}

func! s:GetTime(pos) "{{{
	let mp = 0
	let mt = 0
	let sp = a:pos
	for ktime in keys(s:posArray)
		if s:posArray[ktime] <= sp && s:posArray[ktime] > mp
			let mp = s:posArray[ktime]
			let mt = ktime
		endif
	endfor
	retu mt
endf "}}}

func! SetPos(time) "{{{
	cal cursor(0, s:posArray[a:time])
endf "}}}

func! s:FtoS(num) "{{{
	retu printf("%.1f",a:num)
endf "}}}

func! s:MoveMiddle() "{{{
	cal cursor(0, 2 + s:timeSlot * 6)
endf "}}}

func! s:MoveToday() "{{{
	cal cursor(s:todayLine + 1, 0)
endf "}}}

func! s:VMove(direction) "{{{
	let scroll_up = 0
	let ln = line('.')
	if a:direction ==# "J"
		let ln += 1
		while has_key(s:taskLookup, ln) == 0 && has_key(s:barLookup, ln) == 0
			let ln += 1
			if ln > s:taskMaxLine
				exe "norm! "
				retu
			endif
		endwhile
	elseif a:direction ==# "K"
		let ln -= 1
		while has_key(s:taskLookup, ln) == 0 && has_key(s:barLookup, ln) == 0
			let ln -= 1
			let scroll_up = 1
			if ln <= 1
				retu
			endif
		endwhile
	elseif a:direction ==# "j"
		let ln += 1
		while has_key(s:barLookup, ln) == 0
			let ln += 1
			if ln > s:taskMaxLine
				exe "norm! "
				retu
			endif
		endwhile
	elseif a:direction ==# "k"
		let ln -= 1
		let scroll_up = 1
		while has_key(s:barLookup, ln) == 0
			let ln -= 1
			if ln <= 1
				retu
			endif
		endwhile
	endif
	cal cursor(ln, 0)

	if has_key(s:barLookup, ln) > 0
		exe "hi CursorLine ". s:TimeLineSelectedColor
		if scroll_up == 1 && winline() == 1
			exec "norm! "
		endif
		let s:day = s:barLookup[ln]
		exe s:winNr['sub'] . "wincmd w"
		%delete
		set statusline=\ 
		exe s:winNr['main'] . "wincmd w"
		retu
	endif

	exe "hi CursorLine ". s:TaskSelectedColor
	exe s:winNr['sub'] . "wincmd w"
	cal s:ShowTaskInSubWin(ln)
	exe s:winNr['main'] . "wincmd w"
endfunction "}}}

func! s:Time2Str(time) "{{{
	let tmp = substitute(a:time . '0', '\(\d\+.\)50', '\130', '')
	return substitute(tmp, '\.', ':', '')
endf "}}}

func! s:Str2Time(str) "{{{
	let hm = split(a:str, ':')
	if str2nr(hm[1]) < 30
		let hm[1] = 0
	else 
		let hm[1] = 5
	endif
	retu hm[0] .".". hm[1]
endf "}}}

func! s:MakeTask(todo) range "{{{
	let endCol = col('.')
	let endLn  = line('.')
	norm! gvo
	let startCol = col('.')
	if endLn != line('.') && a:todo == 0
		norm! v
		return
	endif
	if startCol > endCol
		let tmp = endCol
		let endCol = startCol
		let startCol = tmp
	endif
	let s:winl = winline() - 2
	let s:day = s:barLookup[line(".")]
	exe s:winNr['sub'] . "wincmd w"
	%delete
	if a:todo == 1
		cal setline(1, ' 00:00 - 00:00  > * ')
	else
		let stime=s:Time2Str(s:GetTime(startCol))
		let etime=s:Time2Str(s:GetTime(endCol))
		cal setline(1, ' '. stime ." - ". etime ." >  ")
	endif
	cal cursor(1, col('$'))
	let s:VidemScheTimeFocus = 0
	startinsert
endf "}}}

func! s:RegTask() "{{{
	let plan = getline(1)
	let rstime = substitute(plan, '\s\(\d\{1,2}:\d\d\)\s.*', '\1', '')
	let retime = substitute(plan, '.*-\s*\(\d\{1,2}:\d\d\)\s.*', '\1', '')
	let stime = s:Str2Time(rstime)
	let etime = s:Str2Time(retime)
	let task  =  substitute(plan, 
				\ '^\s\d\{1,2}:\d\d\s.*-\s*\d\{1,2}:\d\d\s.*>\s\+\(\S.*\)$', '\1', '')
	if len(plan) == len(task) 
		cal setline(2, "!Format is Invalid!")
		wincmd k
		retu
	endif
	let type = 1
	if has_key(s:taskTypeMark, task[0]) > 0
		let type = s:taskTypeMark[task[0]]
		if type == s:taskTypeTodoNum
			let stime = "0.0"
			let etime = "0.0"
			let rstime = "00:00"
			let retime = "00:00"
		endif
		let task = strpart(task, 1)
	endif

	if type != s:taskTypeTodoNum
		if str2float(stime) >= str2float(etime)
			cal setline(2, "!Time is Invalid!")
			wincmd k
			retu
		endif

		if str2float(stime) < s:startTime
			let stime = s:startTime . ".0"
		endif
		if str2float(etime) > s:endTime + 1
			let etime = (s:endTime + 1) . ".0"
		endif
	endif
	let desc = ""
	for i in range(2, line('$'))
		let desc .= getline(i) . "%%"
	endfor
	cal add(s:taskArray, [s:year, s:mon, s:day, stime, etime, type, task, 
				\ rstime, retime, "0", desc])
	exe s:winNr['main'] . "wincmd w"
	silent cal s:Show(s:day, s:mon, s:year)
endf "}}}

func! s:TaskDelete() "{{{
	let npos = getpos(".")
	if has_key(s:taskLookup, npos[1]) == 0
		return
	endif
	let s:YankBuf = copy(s:taskArray[s:taskLookup[npos[1]]])
	call remove(s:taskArray, s:taskLookup[npos[1]])
	let s:winl = winline() - 2
	silent cal s:Show(s:day, s:mon, s:year)
endf "}}}

func! s:TaskChange() "{{{
	let npos = getpos(".")
	if has_key(s:taskLookup, npos[1]) == 0
		return
	endif
	let s:YankBuf = copy(s:taskArray[s:taskLookup[npos[1]]])
	let s:day = s:YankBuf[s:ID_Day]
	call remove(s:taskArray, s:taskLookup[npos[1]])

	let s:winl = winline() - 2
	exe s:winNr['sub'] . "wincmd w"
	%delete
	let tmark = s:taskTypeMarkNum[s:YankBuf[s:ID_Flag]]
	call setline(1, ' '. s:YankBuf[s:ID_RStart] .' - '. 
				\ s:YankBuf[s:ID_REnd] .' > '. 
				\ tmark . s:YankBuf[s:ID_Msg])

	if s:IsDesc(s:YankBuf) > 0
		cal append(1, "")
		let cnt = 2
		for i in split(s:YankBuf[s:ID_Desc], '%%')
			cal append(cnt, i)
			let cnt += 1
		endfor
	endif

	cal cursor(1, col('$'))
	let s:VidemScheTimeFocus = 0
	startinsert
endf "}}}

func! s:TaskPaste() "{{{
	let npos = getpos(".")
	if has_key(s:barLookup, npos[1]) == 0 || len(s:YankBuf) <= 0
		return
	endif

	let newTask = copy(s:YankBuf)
	let newTask[s:ID_Year] = s:year
	let newTask[s:ID_Mon] = s:mon
	let newTask[s:ID_Day] = s:day
	cal add(s:taskArray, newTask)
	let s:winl = winline() - 2
	silent cal s:Show(s:day, s:mon, s:year)
endf "}}}

func! s:TaskYank() "{{{
	let npos = getpos(".")
	if has_key(s:taskLookup, npos[1]) == 0
		return
	endif
	let s:YankBuf = copy(s:taskArray[s:taskLookup[npos[1]]])
endf "}}}

func! s:ScheIncTime(flg) "{{{
	let line = getline(".")
	if s:VidemScheTimeFocus == 0
		let time = matchstr(line, '^\s\d\{1,2}:\d\d')
	else
		let time = substitute(line, 
					\ '\d\{1,2}:\d\d\s*-\s*\(\d\{1,2}:\d\d\).*', '\1', '')
	endif
	let time = s:TimeInc(time, a:flg, 15) 
	if s:VidemScheTimeFocus == 0
		call setline(1, substitute(line, '\d\{1,2}:\d\d', time, ''))
	else
		call setline(1, substitute(line, '-\s*\d\{1,2}:\d\d', '- '. time, ''))
	endif
endf "}}}

func! s:ToggleTimeFocus() "{{{
	let s:VidemScheTimeFocus = 1 - s:VidemScheTimeFocus
endf "}}}

func! s:TaskListSort(l1, l2) "{{{
	let str1 = a:l1[s:ID_RStart]
	let str2 = a:l2[s:ID_RStart]
	let hm1 = split(str1, ':')
	let hm2 = split(str2, ':')
	let h1 = str2nr(hm1[0])
	let h2 = str2nr(hm2[0])
	if  h1 != h2
		return (h1 - h2)
	endif
	return (str2nr(hm1[1]) - str2nr(hm2[1]))
endf "}}}

func! s:SplitMsg(msg, len, pad, rev) "{{{
	let dispLen = videm#string#getDispLen(a:msg)
	if strlen(a:msg) == dispLen
		retu s:SplitMsgNMB(a:msg, a:len, a:pad, a:rev)
	endif
	if dispLen == a:len
		retu [a:msg, ""]
	elseif dispLen > a:len
		if a:rev == 0
			let nstr = videm#string#trimDispLen(a:msg, a:len, 0)
			let rstr = strpart(a:msg, strlen(nstr))
			if videm#string#getDispLen(nstr) < a:len
				let nstr = a:pad . nstr
			endif
			retu [nstr, rstr]
		else
			let nstr = videm#string#trimDispLenRev(a:msg, a:len, 0)
			let rstr = strpart(a:msg, 0, (strlen(a:msg) - strlen(nstr)))
			if videm#string#getDispLen(nstr) < a:len
				let nstr = nstr . a:pad
			endif
			retu [nstr, rstr]
		endif
	endif
	retu [a:msg . repeat(a:pad, (a:len - dispLen)), ""]
endf

func! s:SplitMsgNMB(msg, len, pad, rev)
	let slen = strlen(a:msg)
	if slen == a:len
		retu [a:msg, ""]
	elseif slen > a:len
		if a:rev == 0
			retu [strpart(a:msg, 0, a:len), strpart(a:msg, a:len)]
		else
			retu [strpart(a:msg, (slen - a:len)), strpart(a:msg, 0, (slen - a:len))]
		endif
	endif
	retu [a:msg . repeat(a:pad, (a:len - slen)), ""]
endf "}}}

func! s:SplitWindow(mode) "{{{
	if a:mode == 0
		new 
		wincmd w
		let s:winNr['main'] = winnr()
		wincmd j
		let s:winNr['sub'] = winnr()
	elseif a:mode == 1
		new 
		wincmd w
		vert new 
		wincmd k
		let s:winNr['main'] = winnr()
		wincmd j
		let s:winNr['sub'] = winnr()
		wincmd l
		let s:winNr['cal'] = winnr()
	elseif a:mode == 2
		new 
		wincmd w
		vert new 
		wincmd w
		vert new 
		wincmd k
		let s:winNr['main'] = winnr()
		wincmd j
		let s:winNr['sub'] = winnr()
		wincmd l
		let s:winNr['todo'] = winnr()
		wincmd l
		let s:winNr['cal'] = winnr()
	else
		echo "bad arguments"
		sleep 1
	endif
endf "}}}

func! s:HMove(direction) range "{{{
	let ncol = col('.')
	if a:direction ==# "l"
		let ncol += s:minSlot
	elseif a:direction ==# "h"
		let ncol -= s:minSlot
	elseif a:direction ==# "L"
		let ncol += s:timeSlot
	elseif a:direction ==# "H"
		let ncol -= s:timeSlot
	endif
	cal cursor(0, (ncol/s:minSlot)*s:minSlot + 2)
	return
endf "}}}

func s:ModifyTask(flg) "{{{
	let ln = line('.')
	if has_key(s:taskLookup, ln) == 0
		return
	endif

	let task = s:taskArray[s:taskLookup[ln]]
	let etime = task[s:ID_End] 
	let stime = task[s:ID_Start]
	let retime = task[s:ID_REnd] 
	let rstime = task[s:ID_RStart]
	let otime = stime

	let et = str2float(task[s:ID_End])
	let st = str2float(task[s:ID_Start])

	if a:flg == '>'
		let et = str2float(etime) + 0.5
		let st = str2float(stime) + 0.5
		let retime = s:TimeInc(retime, 'inc', 30)
		let rstime = s:TimeInc(rstime, 'inc', 30)
	elseif a:flg == '<'
		let et = str2float(etime) - 0.5
		let st = str2float(stime) - 0.5
		let retime = s:TimeInc(retime, 'dec', 30)
		let rstime = s:TimeInc(rstime, 'dec', 30)
	elseif a:flg == '('
		let st = str2float(stime) - 0.5
		let rstime = s:TimeInc(rstime, 'dec', 30)
	elseif a:flg == '}'
		let et = str2float(etime) + 0.5
		let retime = s:TimeInc(retime, 'inc', 30)
	elseif a:flg == '{'
		let et = str2float(etime) - 0.5
		let retime = s:TimeInc(retime, 'dec', 30)
	elseif a:flg == ')'
		let st = str2float(stime) + 0.5
		let rstime = s:TimeInc(rstime, 'inc', 30)
	endif
	if et - st < 0.5 || st < s:startTime || et > s:endTime + 1
		return
	endif

	let stime = s:FtoS(st)
	let etime = s:FtoS(et)

	let dispmsgList = s:MakeDispTask(task[s:ID_Msg], task[s:ID_Flag],
				\ s:GetPos(etime) - s:GetPos(stime) , s:GetPos(stime))
	let task[s:ID_Start] = stime
	let task[s:ID_End]   = etime
	let task[s:ID_RStart] = rstime
	let task[s:ID_REnd]   = retime
	setl modifiable
	cal setline(line('.'), repeat(' ', (s:GetPos(stime) - dispmsgList[1] -1)) . dispmsgList[0]) 
	setl nomodifiable
	exe s:winNr['sub'] . "wincmd w"
	cal s:ShowTaskInSubWin(ln)
	exe s:winNr['main'] . "wincmd w"
endf "}}}

func s:MakeDispTask(msg, flg, len, pos)"{{{
	let offset = 0
	if s:cutDownMsg || a:pos + videm#string#getDispLen(a:msg) < s:winWidth
		let msg = s:SplitMsg(a:msg, a:len, " ", 0) 
		if msg[1] == "" || s:cutDownMsg
			let rmsg = "?1?" . msg[0] ."$". a:flg ."$"
		else
			let rmsg = "?1?" . msg[0] ."$". a:flg ."$". msg[1]
		endif
	else
		let msg = s:SplitMsg(a:msg, a:len, " ", 1)
		if msg[1] == "" 
			let rmsg = "?1?". msg[0] ."$". a:flg ."$"
		else
			let offset = videm#string#getDispLen(msg[1])
			let rmsg = msg[1] ."?1?". msg[0] ."$". a:flg ."$"
		endif
	endif
	retu [rmsg, offset]
endf "}}}

func! s:TimeInc(time, flg, val) "{{{
let hm = split(a:time, ':')
	if len(hm) != 2
		return
	endif
	let hour = str2nr(hm[0])
	let min  = str2nr(hm[1])
	let val  = str2nr(a:val)
	if a:flg == "inc"
		let min += a:val
	elseif a:flg == "dec"
		let min -= a:val
	endif
	if min >= 60
		let hour = hour + min / 60
		let min  = min % 60
	endif
	while min < 0
		let hour -= 1
		let min += 60
	endwhile
	if min >= 60 || min < 0 || hour >= 24 || hour < 0
		retu a:time
	endif
	if min < 10
		let hm[1] = "0" . min
	else 
		let hm[1] = min
	endif
	retu hour .":". hm[1]
endf "}}}

func! s:FlagChange(flg) "{{{
	let ln = line('.')
	if has_key(s:taskLookup, ln) == 0
		return
	endif
	let tmp = (s:taskArray[s:taskLookup[ln]])
	if tmp[s:ID_Flag] == '6'
		cal s:TodoFlagChange(a:flg)
	else
		cal s:TaskFlagChange(a:flg)
	endif
endf "}}}

func! s:TaskFlagChange(flg) "{{{
	let ln = line('.')
	let flg = a:flg
	if has_key(s:taskLookup, ln) == 0
		return
	endif
	let tmp = (s:taskArray[s:taskLookup[ln]])
	if a:flg == 'none'
		let flg = ' '
	endif
	
	if !has_key(s:taskTypeMark, flg)
		echo "flg:". flg
		sleep 1
		return
	endif

	let oline = getline('.')
	exe 'let nline = substitute(oline, '. "'".'\$\d\$'. "', '" .'\$'. 
				\ s:taskTypeMark[flg] .'\$'. "', '')"
	let tmp[s:ID_Flag] = s:taskTypeMark[flg]

	setl modifiable
	call setline(ln, nline)
	setl nomodifiable
	exe s:winNr['sub'] . "wincmd w"
	cal s:ShowTaskInSubWin(ln)
	exe s:winNr['main'] . "wincmd w"
endf "}}}

func! s:TodoFlagChange(flg) "{{{
	let ln = line('.')
	let tmp = (s:taskArray[s:taskLookup[ln]])
	let msg = tmp[s:ID_Msg]

	if a:flg == "todo" || a:flg == "+"
		if has_key(s:todoTypeMark, msg[0]) > 0 
			let msg = strpart(msg, 1)
		endif
		let msg = "+". msg
	elseif a:flg == "imp" || a:flg == "!"
		if has_key(s:todoTypeMark, msg[0]) > 0 
			let msg = strpart(msg, 1)
		endif
		let msg = "!". msg
	elseif a:flg == "done"
		if has_key(s:todoTypeMark, msg[0]) > 0 
			let msg = strpart(msg, 1)
		endif
		let msg = "-". msg
	elseif a:flg == "none"
		if has_key(s:todoTypeMark, msg[0]) > 0 
			let msg = strpart(msg, 1)
		endif
	else
		return
	endif
	let tmp[s:ID_Msg] = msg

	let line = getline(".")
	setl modifiable
	call setline(ln, " * " . msg)
	setl nomodifiable
	exe s:winNr['sub'] . "wincmd w"
	cal s:ShowTaskInSubWin(ln)
	exe s:winNr['main'] . "wincmd w"
endf "}}}

func! s:FocusCal() "{{{
	if s:winNr['cal'] > 0
		exe s:winNr['cal'] . "wincmd w"
	endif
endf "}}}

func! viske#selectCal(day, mon, year) "{{{
	cal s:SaveTasks()
	let s:day = a:day
	let s:mon = a:mon
	let s:year = a:year
	exe s:winNr['main'] . "wincmd w"
	cal s:SetWinWidth()
	let s:taskArray = []
	cal s:ReadTasks(a:mon, a:year) 
	silent cal s:Show(a:day, a:mon, a:year)
endf "}}}

func! s:IsDesc(a) "{{{
	if len(a:a) > s:ID_Desc
		retu 1
	endif
	retu 0
endf "}}}

func viske#setWebFuncGet(fname)
	let s:webFuncGet = function(a:fname)
endf
func viske#setWebFuncSet(fname)
	let s:WebFuncSet = function(a:fname)
endf

func s:DefaultWebFuncGet(taskArray)
	retu a:taskArray
endf

let s:webFuncGet = function("s:DefaultWebFuncGet")
func s:WebFuncGet()
	let s:taskArray = call(s:webFuncGet, [s:taskArray])
endf

func s:DefaultWebFuncSet(taskArray)
	retu a:taskArray
endf
let s:WebFuncSet = function("s:DefaultWebFuncSet")
func s:webFuncSet()
	let s:taskArray = call(s:WebFuncSet, [s:taskArray])
endf

func! viske#RtimeToDtime(str)
	let hm = split(a:str, ':')
	if str2nr(hm[0]) < s:startTime
		let hm[0] = printf("%d", s:startTime)
		let hm[1] = 0
	elseif str2nr(hm[0]) > s:endTime
		let hm[0] = printf("%d", s:endTime + 1)
		let hm[1] = 0
	else
		if str2nr(hm[1]) < 30
			let hm[1] = 0
		else 
			let hm[1] = 5
		endif
	endif
	retu hm[0] .".". hm[1]
endf

func! s:ScheTest()
	"echo s:taskArray
	echo s:TimeLineSelectedColor
	cal getchar()
endf

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: foldmethod=marker
