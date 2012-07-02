
if !exists('s:is_enabled')
	let s:is_enabled = 0
else
	finish
endif

let s:gcalScript = get(g:, "viskeGcalGetScript", $HOME . "/.vim/ruby/gcal.rb")
let s:tzone      = get(g:, "viskeGcalTZone", "+0900")
let s:afile      = get(g:, "viskeGcalAuthFile", $HOME . "/.google-api.yaml")

func! viske#gcal#name()
	retu "Google Calendar"
endf

func! viske#gcal#get(curTaskArray, mon, year)
	let id = g:viske#id
	let curTaskArray = a:curTaskArray
	let newTaskArray = []
	let deleteTask   = []
	let s:dir = viske#getDir()
	let s:ofile = get(g:, "ViskeGcalTaskFile", s:dir . "viskeGoogleCalendar")

	"Create arguments
	let argl = []
	if !exists("g:viskeGcalId")
		echo "[gcal] set calendar ID as 'g:viskeGcalId'."
		cal getchar()
		retu a:curTaskArray
	endif
	if isdirectory(s:dir) <= 0
		echo "[gcal] Schedule Directory is required."
		cal getchar()
		retu a:curTaskArray
	endif

	if !filereadable(s:gcalScript)
		let bundlePlc = $HOME . ".vim/bundle/viske/ruby/gcal.rb"
		if !filereadable(bundlePlc)
			echo "[gcal] Place the gcal.rb script on ". s:gcalScript
			cal getchar()
			retu a:curTaskArray
		endif
		let s:gcalScript = bundlePlc
	endif

	cal add(argl, '--month ' . a:mon)
	cal add(argl, '--year '  . a:year)
	cal add(argl, '--id '    . g:viskeGcalId)
	cal add(argl, '--dir '   . s:dir)
	cal add(argl, '--tzone ' . s:tzone)
	cal add(argl, '--afile ' . s:afile)
	cal add(argl, '--ofile ' . s:ofile)
	if exists("g:viskeGcalLogFile")
		cal add(argl, '--log ' . g:viskeGcalLogFile)
	endif

	let argstr = join(argl, ' ')
	echo "Now downloading from Google Calendar..."
	try
		cal system("ruby ". s:gcalScript ." --list ". argstr)
	catch
		echo "[gcal] Failed to get tasks from Google Calendar."
		cal getchar()
		retu a:curTaskArray
	endtry
	let tmp = readfile(s:ofile)
	for i in tmp
		cal add(newTaskArray, split(i, '\$\$'))
	endfor
	for j in newTaskArray
		let j[id["day"]]   = substitute(j[id["day"]], '^0', '','')
		let j[id["start"]] = viske#RtimeToDtime(j[id["rstart"]])
		let j[id["end"]]   = viske#RtimeToDtime(j[id["rend"]])
		if  j[id["id"]] != ""
			for cnt in range(0, len(curTaskArray)-1)
				if curTaskArray[cnt][id["id"]] == j[id["id"]]
					cal remove(curTaskArray, cnt)
					break
				endif
			endfor
		endif
	endfor

	for k in curTaskArray
		if k[id["id"]] == "0" || k[id["id"]] == ""
			continue
		endif
		cal filter(curTaskArray, 'v:val[id["id"]] != k[id["id"]]')
	endfor

	cal extend(curTaskArray, newTaskArray)
	retu curTaskArray
endf

func! viske#gcal#set(taskl, mon, year)
	if !exists("g:viskeGcalId")
		echo "[gcal] set calendar ID as 'g:viskeGcalId'."
		cal getchar()
		retu 
	endif
	let s:dir = viske#getDir()
	let s:ofile = get(g:, "ViskeGcalTaskFile", s:dir . "viskeGoogleCalendar")

	let argl = []
	cal add(argl, '--id '  . g:viskeGcalId)
	if exists("g:viskeGcalLogFile")
		cal add(argl, '--log ' . g:viskeGcalLogFile)
	endif
	let argstr = join(argl, ' ')

	if len(a:taskl) > 0
		let deltasks = join(a:taskl, ',')
		echo "Now synchronizing (deleting)..."
		cal system("ruby ". s:gcalScript ." --delete --dlist ". deltasks ." ". argstr)
	endif

	cal add(argl, '--month ' . a:mon)
	cal add(argl, '--year '  . a:year)
	cal add(argl, '--dir '   . s:dir)
	cal add(argl, '--tzone ' . s:tzone)
	cal add(argl, '--afile ' . s:afile)
	cal add(argl, '--ofile ' . s:ofile)
	let argstr = join(argl, ' ')

	echo "Now synchronizing (uploading)..."
	cal system("ruby ". s:gcalScript ." --insert ". argstr)
endf
