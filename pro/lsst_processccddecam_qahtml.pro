pro lsst_processccddecam_qahtml,datarepodir,logfile,info,visitinfo

; This makes QA HTML pages for processccddecam

; -one page with a table of visits and summaries
; -a separate page for each visit showing all chips

thisprog = 'processCcdDecam'

nvisit = n_elements(visitinfo)

; Create visits summary page
;-----------------------------
lsst_undefine,hlines
LSST_PUSH,hlines,'<html>'
LSST_PUSH,hlines,'<head>'
LSST_PUSH,hlines,'<title>'+thisprog+' results for '+datarepodir
LSST_PUSH,hlines,'</title'
LSST_PUSH,hlines,'</head>'
LSST_PUSH,hlines,'<body>'
LSST_PUSH,hlines,'<center><H1>LSST DRP '+thisprog+' Summary page for '+datarepodir+'</H1></center>'
LSST_PUSH,hlines,'<p>'
LSST_PUSH,hlines,'<center>'
LSST_PUSH,hlines,'<table border=1>'

; NEED LINKS TO VISIT-SPECIFIC HTML PAGES

LSST_PUSH,hlines,'<tr><td><b>Visit</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center><b><a href="'+datarepodir+'html/'+thisprog+'_'+visitinfo[j].visit+'.html">'+visitinfo[j].visit+'</a></b></center></td>'
LSST_PUSH,hlines,'</tr>'
; Date
LSST_PUSH,hlines,'<tr><td><b>Date-Obs</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+visitinfo[j].dateobs+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; Airmass
LSST_PUSH,hlines,'<tr><td><b>Airmass</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+strtrim(visitinfo[j].airmass,2)+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; RA
LSST_PUSH,hlines,'<tr><td><b>RA</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+ten2sexig(visitinfo[j].ra/15.0)+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; DEC
LSST_PUSH,hlines,'<tr><td><b>DEC</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+ten2sexig(visitinfo[j].dec)+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; Date-Obs
LSST_PUSH,hlines,'<tr><td><b>Date</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+visitinfo[j].dateobs+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; FWHM
LSST_PUSH,hlines,'<tr><td><b>FWHM</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+strtrim(visitinfo[j].fwhm,2)+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; Filter
LSST_PUSH,hlines,'<tr><td><b>Filter</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+visitinfo[j].filter+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; Exptime
LSST_PUSH,hlines,'<tr><td><b>Exptime</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+strtrim(visitinfo[j].exptime,2)+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; Number of CCds
LSST_PUSH,hlines,'<tr><td><b>NCCDNUM</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+strtrim(visitinfo[j].nccdnum,2)+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; Number of successfully processed CCDs
LSST_PUSH,hlines,'<tr><td><b>Nsuccess</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+strtrim(visitinfo[j].nsuccess,2)+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; Number of failed CCDs
LSST_PUSH,hlines,'<tr><td><b>Nfailed</b></td>'
for j=0,nvisit-1 do begin
  if visitinfo[j].nfailed gt 0 then color='#FF0000' else color='#00FF00'
  LSST_PUSH,hlines,'<td bgcolor='+color+'><center>'+strtrim(visitinfo[j].nfailed,2)+'</center></td>'
endfor
LSST_PUSH,hlines,'</tr>'
; Nsources
LSST_PUSH,hlines,'<tr><td><b>Nsources</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+strtrim(visitinfo[j].nsources,2)+'</center></td>'
LSST_PUSH,hlines,'</tr>'
; Total processing time
LSST_PUSH,hlines,'<tr><td><b>ProcessingTime</b></td>'
for j=0,nvisit-1 do LSST_PUSH,hlines,'<td><center>'+strtrim(visitinfo[j].duration,2)+'</center></td>'
LSST_PUSH,hlines,'</tr>'
LSST_PUSH,hlines,'</table>'
LSST_PUSH,hlines,''
LSST_PUSH,hlines,'</center>'
LSST_PUSH,hlines,''
LSST_PUSH,hlines,'</body>'
LSST_PUSH,hlines,'</html>'

if file_test(datarepodir+'html/',/directory) eq 0 then file_mkdir,datarepodir+'html'
htmlfile = datarepodir+'html/'+thisprog+'.html'
WRITELINE,htmlfile,hlines
FILE_CHMOD,htmlfile,'755'o
lsst_printlog,logfile,'Writing ',htmlfile


;--------------------------------
; Make HTML page for this visit
;--------------------------------
For i=0,nvisit-1 do begin
  ind = where(info.visit eq visitinfo[i].visit,nind)
  info1 = info[ind]

; ADD LINKS TO SCRIPTFILE, LOGFILE AND CONFIGFILE
; astrometric accuracy, and other metrics spit out in the logfile
  
  lsst_undefine,hlines
  LSST_PUSH,hlines,'<html>'
  LSST_PUSH,hlines,'<head>'
  LSST_PUSH,hlines,'<title>'+thisprog+' results for '+datarepodir
  LSST_PUSH,hlines,'</title'
  LSST_PUSH,hlines,'</head>'
  LSST_PUSH,hlines,'<body>'
  LSST_PUSH,hlines,'<center><H1>LSST DRP '+thisprog+' Summary page for '+datarepodir+' and Visit='+visitinfo[i].visit+'</H1></center>'
  LSST_PUSH,hlines,'<hr>'
  LSST_PUSH,hlines,'<p>'
  ;LSST_PUSH,hlines,'<p>'
  ;LSST_PUSH,hlines,'<center><H2>Final Results</H2>'
  ;LSST_PUSH,hlines,'<p>'
  ;LSST_PUSH,hlines,'<table border=1>'
  ;LSST_PUSH,hlines,'<tr><td><b>Field Name</b></td><td><center>'+ifield+'</center></td></tr>'
  ;LSST_PUSH,hlines,'<tr><td><b>Base Name</b></td><td><center>'+ampbase+'</center></td></tr>'
  ;if TAG_EXIST(str,'PROB') then type='ALLFRAME' else type='ALLSTAR'
  ;LSST_PUSH,hlines,'<tr><td><b>Type</b></td><td><center>'+type+'</center></td></tr>'
  ;LSST_PUSH,hlines,'<tr><td><b>RA</b></td><td><center>'+ten2sexig(fieldampinfo[j].ra/15.0)+'</center></td></tr>'
  ;LSST_PUSH,hlines,'<tr><td><b>DEC</b></td><td><center>'+ten2sexig(fieldampinfo[j].dec)+'</center></td></tr>'
  ;LSST_PUSH,hlines,'<tr><td><b>Total Sources</b></td><td><center>'+strtrim(nstr,2)+'</center></td></tr>'
  ;LSST_PUSH,hlines,'<tr><td><b>Total Stars</b></td><td><center>'+strtrim(ngd,2)+'</center></td></tr>'
  ;; --CMD--
  ;LSST_PUSH,hlines,'<tr><td><b>CMD and 2CD</b></td>'
  ;test = FILE_TEST('html/'+fieldampinfo[j].cmdfile)
  ;if test eq 1 then begin
  ;  LSST_PUSH,hlines,'<td><center><a href="'+fieldampinfo[j].cmdfile+'"><img src="'+$
  ;              fieldampinfo[j].cmdfile+'" height=400></a></center></td>'
  ;endif else begin
  ;  LSST_PUSH,hlines,'<td><center>Image NOT FOUND</center></td>'
  ;endelse
  ;LSST_PUSH,hlines,'</tr>'
  ;; --Combined Image--
  ;if FILE_TEST('html/'+combimagefile) eq 1 then begin
  ;  result = query_gif('html/'+combimagefile,gifstr)
  ;  dims = gifstr.dimensions
  ;  height = 400 < dims[1]
  ;  sheight = strtrim(long(height),2)
  ;  LSST_PUSH,hlines,'<tr><td><b>Combined Image</b></td>'
  ;  LSST_PUSH,hlines,'<td><center><a href="'+combimagefile+'"><img src="'+combimagefile+$
  ;           '" height='+sheight+'></a></center></td>'
  ;  LSST_PUSH,hlines,'</tr>'
  ;endif
  ;; --CMD and 2CD with giants--
  ;LSST_PUSH,hlines,'<tr><td><b>CMD and 2CD with giants</b></td>'
  ;test = FILE_TEST('html/'+fieldampinfo[j].cmdgiantsfile)
  ;if test eq 1 then begin
  ;  LSST_PUSH,hlines,'<td><center><a href="'+fieldampinfo[j].cmdgiantsfile+'"><img src="'+$
  ;            fieldampinfo[j].cmdgiantsfile+'" height=300></a></center></td>'
  ;endif else begin
  ;  LSST_PUSH,hlines,'<td><center>Image NOT FOUND</center></td>'
  ;endelse
  ;LSST_PUSH,hlines,'</tr>'
  ;; --Sky plot with giants--
  ;LSST_PUSH,hlines,'<tr><td><b>Sky plot with giants</b></td>'
  ;test = FILE_TEST('html/'+fieldampinfo[j].skygiantsfile)
  ;if test eq 1 then begin
  ;  LSST_PUSH,hlines,'<td><center><a href="'+fieldampinfo[j].skygiantsfile+'"><img src="'+$
  ;              fieldampinfo[j].skygiantsfile+'" height=300></a></center></td>'
  ;endif else begin
  ;  LSST_PUSH,hlines,'<td><center>Image NOT FOUND</center></td>'
  ;endelse
  ;LSST_PUSH,hlines,'</tr>'
  ;; --Sky plot--
  ;LSST_PUSH,hlines,'<tr><td><b>Sky Distribution</b></td>'
  ;LSST_PUSH,hlines,'<td><center><a href="'+skyfile+'"><img src="'+skyfile+'" height=300></a></center></td>'
  ;LSST_PUSH,hlines,'</tr>'
  ;; --Histogram plot--
  ;LSST_PUSH,hlines,'<tr><td><b>Histogram</b></td>'
  ;LSST_PUSH,hlines,'<td><center><a href="'+histfile+'"><img src="'+histfile+'" height=300></a></center></td>'
  ;LSST_PUSH,hlines,'</tr>'
  ;; --Error plots--
  ;LSST_PUSH,hlines,'<tr><td><b>Errors</b></td>'
  ;LSST_PUSH,hlines,'<td><center><a href="'+errorfile+'"><img src="'+errorfile+'" height=350></a></center></td>'
  ;LSST_PUSH,hlines,'</tr>'
  ;; --Chi vs. Sharp plot--
  ;LSST_PUSH,hlines,'<tr><td><b>Chi vs. Sharp</b></td>'
  ;LSST_PUSH,hlines,'<td><center><a href="'+chisharpfile+'"><img src="'+chisharpfile+'" height=300></a></center></td>'
  ;LSST_PUSH,hlines,'</tr>'
  ;; --Chi vs. Mag plot--
  ;LSST_PUSH,hlines,'<tr><td><b>Chi vs. Mag</b></td>'
  ;LSST_PUSH,hlines,'<td><center><a href="'+chimagfile+'"><img src="'+chimagfile+'" height=300></a></center></td>'
  ;LSST_PUSH,hlines,'</tr>'
  ;LSST_PUSH,hlines,'</table>'
  ;LSST_PUSH,hlines,''
  ;LSST_PUSH,hlines,''
  LSST_PUSH,hlines,''
  LSST_PUSH,hlines,'<center><H2>Individual CCD Information:</H2></center>'
  LSST_PUSH,hlines,'<table border=1>'
  LSST_PUSH,hlines,'<tr><td><b>CCDNUM</b></td>'
  for l=0,nind-1 do begin
    if info1[l].success eq 0 then color='#FF0000' else color='#00FF00'
    LSST_PUSH,hlines,'<td bgcolor='+color+'><center><b>'+info1[l].ccdnum+'</b></center></td>'
  end
  LSST_PUSH,hlines,'</tr>'
  ; Processing timesample
  LSST_PUSH,hlines,'<tr><td><b>Processing Timestampe</b></td>'
  for l=0,nind-1 do LSST_PUSH,hlines,'<td><center>'+systime(0,info1[l].runtimestamp)+'</center></td>'
  LSST_PUSH,hlines,'</tr>'
  ; Script file
  LSST_PUSH,hlines,'<tr><td><b>Script file</b></td>'
  for l=0,nind-1 do LSST_PUSH,hlines,'<td><center><a href="'+info1[l].scriptfile+'">'+file_basename(info1[l].scriptfile)+'</a></center></td>'
  LSST_PUSH,hlines,'</tr>'
  ; Log file
  LSST_PUSH,hlines,'<tr><td><b>Log file</b></td>'
  for l=0,nind-1 do LSST_PUSH,hlines,'<td><center><a href="'+info1[l].logfile+'">'+file_basename(info1[l].logfile)+'</a></center></td>'
  LSST_PUSH,hlines,'</tr>'
  ; User config file
  LSST_PUSH,hlines,'<tr><td><b>User config file</b></td>'
  for l=0,nind-1 do begin
     if info1[l].userconfigfile eq '' then LSST_PUSH,hlines,'<td><center>None</center></td>'else $
     LSST_PUSH,hlines,'<td><center><a href="'+info1[l].userconfigfile+'">'+file_basename(info1[l].userconfigfile)+'</a></center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Final config file
  LSST_PUSH,hlines,'<tr><td><b>Final config file</b></td>'
  for l=0,nind-1 do LSST_PUSH,hlines,'<td><center><a href="'+info1[l].finalconfigfile+'">'+file_basename(info1[l].finalconfigfile)+'</a></center></td>'
  LSST_PUSH,hlines,'</tr>'
  ; Duration
  LSST_PUSH,hlines,'<tr><td><b>ProcessingTime</b></td>'
  for l=0,nind-1 do begin
     LSST_PUSH,hlines,'<td><center>'+strtrim(string(info1[l].duration,format='(F10.1)'),2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Image Size
  LSST_PUSH,hlines,'<tr><td><b>Image Size</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(info1[l].nx,2)+'x'+strtrim(info1[l].ny,2)+'</center></td>'
  end
  LSST_PUSH,hlines,'</tr>'
  ; Filter
  LSST_PUSH,hlines,'<tr><td><b>Filter</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+info1[l].filter+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Exptime
  LSST_PUSH,hlines,'<tr><td><b>Exptime</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(string(info1[l].exptime,format='(F10.2)'),2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Date
  LSST_PUSH,hlines,'<tr><td><b>Date</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+info1[l].dateobs+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Airmass
  LSST_PUSH,hlines,'<tr><td><b>Airmass</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(info1[l].airmass,2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; RA
  LSST_PUSH,hlines,'<tr><td><b>RA</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+ten2sexig(info1[l].ra/15.0)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; DEC
  LSST_PUSH,hlines,'<tr><td><b>DEC</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+ten2sexig(info1[l].dec)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ;; PSF Chi
  ;LSST_PUSH,hlines,'<tr><td><b>PSF Chi</b></td>'
  ;for l=0,nind-1 do LSST_PUSH,hlines,'<td><center>'+info1[l].psfchi+'</center></td>'
  ;LSST_PUSH,hlines,'</tr>'
  ; FWHM
  LSST_PUSH,hlines,'<tr><td><b>FWHM</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(string(info1[l].fwhm,format='(F10.2)'),2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Fluxmag0
  LSST_PUSH,hlines,'<tr><td><b>Fluxmag0</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $    
    LSST_PUSH,hlines,'<td><center>'+strtrim(info1[l].fluxmag0,2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Medbackground
  LSST_PUSH,hlines,'<tr><td><b>MedBackground</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(string(info1[l].medbackground,format='(F10.2)'),2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Sigbackground
  LSST_PUSH,hlines,'<tr><td><b>SigBackground</b></td>'
  for l=0,nind-1 do begin
    if file_test(info1[l].calexpfile) eq 0 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(string(info1[l].sigbackground,format='(F10.2)'),2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Nsources
  LSST_PUSH,hlines,'<tr><td><b>Nsources</b></td>'
  for l=0,nind-1 do begin
    if info1[l].nsources eq -1 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(info1[l].nsources,2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; InitPSFFWHM
  LSST_PUSH,hlines,'<tr><td><b>InitPSFFWHM</b></td>'
  for l=0,nind-1 do begin
    if info1[l].initpsffwhm eq -1 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(string(info1[l].initpsffwhm,format='(F10.2)'),2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Npsfstars_selected
  LSST_PUSH,hlines,'<tr><td><b>NPSFstarselected</b></td>'
  for l=0,nind-1 do begin
    if info1[l].npsfstars_selected eq -1 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(info1[l].npsfstars_selected,2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Npsfstars_used
  LSST_PUSH,hlines,'<tr><td><b>NPSFstarsused</b></td>'
  for l=0,nind-1 do begin
    if info1[l].npsfstars_used eq -1 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(info1[l].npsfstars_used,2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Ncosmicrays
  LSST_PUSH,hlines,'<tr><td><b>Ncosmicrays</b></td>'
  for l=0,nind-1 do begin
    if info1[l].ncosmicrays eq -1 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(info1[l].ncosmicrays,2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; wcsrms
  LSST_PUSH,hlines,'<tr><td><b>WCSrms</b></td>'
  for l=0,nind-1 do begin
    if info1[l].wcsrms eq -1 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(string(info1[l].wcsrms,format='(F10.2)'),2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Ndetected
  LSST_PUSH,hlines,'<tr><td><b>Ndetected</b></td>'
  for l=0,nind-1 do begin
    if info1[l].ndetected eq -1 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(info1[l].ndetected,2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Ndeblended
  LSST_PUSH,hlines,'<tr><td><b>Ndeblended</b></td>'
  for l=0,nind-1 do begin
    if info1[l].ndeblended eq -1 then LSST_PUSH,hlines,'<td><center>--</center></td>' else $
    LSST_PUSH,hlines,'<td><center>'+strtrim(info1[l].ndeblended,2)+'</center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ; Image
  LSST_PUSH,hlines,'<tr><td><b>Image</b></td>'
  for l=0,nind-1 do begin
    LSST_PUSH,hlines,'<td><center><a href="'+info1[l].calexp_plotfile+'"><img src="'+info1[l].calexp_plotfile+$
                '" height=250></a></center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ;; Histogram
  ;LSST_PUSH,hlines,'<tr><td><b>ALS Histogram</b></td>'
  ;for l=0,nind-1 do begin
  ;  LSST_PUSH,hlines,'<td><center><a href="'+info1[l].histfile+'"><img src="'+info1[l].histfile+$
  ;              '" height=250></a></center></td>'
  ;end
  ;LSST_PUSH,hlines,'</tr>'
  ; FluxErr vs. Flux plot
  LSST_PUSH,hlines,'<tr><td><b>FluxErr vs. Flux</b></td>'
  for l=0,nind-1 do begin
    LSST_PUSH,hlines,'<td><center><a href="'+info1[l].src_plotfile+'"><img src="'+info1[l].src_plotfile+$
                '" height=250></a></center></td>'
  endfor
  LSST_PUSH,hlines,'</tr>'
  ;; Chi vs. Sharp plot
  ;LSST_PUSH,hlines,'<tr><td><b>ALS Chi vs. Sharp</b></td>'
  ;for l=0,nind-1 do begin
  ;  LSST_PUSH,hlines,'<td><center><a href="'+info1[l].chisharpfile+'"><img src="'+info1[l].chisharpfile+$
  ;              '" height=250></a></center></td>'
  ;end
  ;LSST_PUSH,hlines,'</tr>'
  ;; Chi vs. Mag plot
  ;LSST_PUSH,hlines,'<tr><td><b>ALS Chi vs. Mag</b></td>'
  ;for l=0,nind-1 do begin
  ;  LSST_PUSH,hlines,'<td><center><a href="'+info1[l].chimagfile+'"><img src="'+info1[l].chimagfile+$
  ;              '" height=250></a></center></td>'
  ;endfor
  LSST_PUSH,hlines,'</tr>'
  LSST_PUSH,hlines,'</table>'
  LSST_PUSH,hlines,''
  LSST_PUSH,hlines,'</center>'
  LSST_PUSH,hlines,''
  LSST_PUSH,hlines,'</body>'
  LSST_PUSH,hlines,'</html>'

; PUT ERRORS IN HERE SOMEWHERE
  
  htmlfile = datarepodir+'html/'+thisprog+'_'+visitinfo[i].visit+'.html'
  WRITELINE,htmlfile,hlines
  FILE_CHMOD,htmlfile,'755'o

  lsst_printlog,logfile,'Writing ',htmlfile

Endfor ; visit loop
  
;stop

end
