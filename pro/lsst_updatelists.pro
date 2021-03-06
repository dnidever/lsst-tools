;+
;
; LSST_UPDATELISTS
;
; This updates the lists (inputlist, outputlist, successlist and failurelist)
; for a LSST stage.
;
; INPUTS:
;  stages         The stages structure with name, inputs and outputs for each.
;  lists          The lists structure output by lsst_getinput.
;  =logsdir       The "logs/" directory.  The defaul is just "logs/"
;  =outlist       The list of new output files.
;  =successlist   The list of new successfully processed files.
;  =failurelist   The list of new failed files.
;  =errorlist     The list of errors that go with the failed files.
;  /silent        Don't print anything
;
; OUTPUTS:
;  The stage's lists will be updated
;
; USAGE:
;  IDL>lsst_updatelists,stages,lists,logsdir=logsdir,outlist=outlist,successlist=successlist,$
;                          failurelist=failurelist,errorlist=errorlist,silent=silent,stp=stp
;
; By D.Nidever  March 2008
;  updated for LSST   Nov 2015
;-

pro lsst_updatelists,stages,lists,logsdir=logsdir,outlist=outlist,successlist=successlist,$
                        failurelist=failurelist,errorlist=errorlist,silent=silent,stp=stp

; Not enough inputs
nstages = n_elements(stages)
nlists = n_elements(lists)
if nstages eq 0 or nlists eq 0 then begin
  print,'Syntax - lsst_updatelists,stages,lists,logsdir=logsdir,outlist=outlist,successlist=successlist,'
  print,'                                 failurelist=failurelist,errorlist=errorlist,silent=silent,stp=stp'
  return
endif


; Check the "lists" structure
type = SIZE(lists,/type)
if (type ne 8) then begin
  print,'LISTS MUST BE A STRUCTURE'
  return
endif
tags = TAG_NAMES(lists)
gdthisprog = where(tags eq 'THISPROG',ngdthisprog)
if (ngdthisprog eq 0) then begin
  print,'LISTS IS MISSING THE "THISPROG" TAG'
  return
endif
gdninputlines = where(tags eq 'NINPUTLINES',ngdninputlines)
if (ngdthisprog eq 0) then begin
  print,'LISTS IS MISSING THE "NINPUTLINES" TAG'
  return
endif
gdnoutputlines = where(tags eq 'NOUTPUTLINES',ngdnoutputlines)
if (ngdthisprog eq 0) then begin
  print,'LISTS IS MISSING THE "NOUTPUTLINES" TAG'
  return
endif
gdnsuccesslines = where(tags eq 'NSUCCESSLINES',ngdnsuccesslines)
if (ngdthisprog eq 0) then begin
  print,'LISTS IS MISSING THE "NSUCCESSLINES" TAG'
  return
endif



; Is "thisprog" a valid stage?
;-------------------------------
thisprog = strupcase(lists.thisprog)
stagenames = stages.name
; NOT a valid stage
stageind = where(strupcase(stagenames) eq strupcase(thisprog),nstageind)
if (nstageind eq 0) then begin
  print,thisprog,' IS NOT A VALID STAGE'
  return
endif

; Logs directory
cd,current=curdir
if n_elements(logsdir) eq 0 then logsdir=curdir+'/logs/'

; List filenames
logfile = logsdir+thisprog+'.log'
inputfile = logsdir+thisprog+'.inlist'
outputfile = logsdir+thisprog+'.outlist'
successfile = logsdir+thisprog+'.success'
failurefile = logsdir+thisprog+'.failure'


;##########################################
;#  UPDATING LIST FILES
;##########################################
if not keyword_set(silent) then begin
  printlog,logfile,''
  printlog,logfile,'-----------------------'
  printlog,logfile,'UPDATING THE LISTS'
  printlog,logfile,'-----------------------'
  printlog,logfile,''
endif


; Inputlines
lsst_undefine,inputlines
ninputlines = lists.ninputlines
if (ninputlines) gt 0 then inputlines=lists.inputlines

;----------------------
; Updating SUCCESS list
;----------------------
nsuccesslist = n_elements(successlist)
if not keyword_set(silent) then $
  printlog,logfile,strtrim(nsuccesslist,2),' files successfully processed'
if (nsuccesslist gt 0) then begin

  ; Adding to the OLD successlist
  lsst_undefine,oldsuccesslines,newsuccesslines
  if (lists.nsuccesslines gt 0) then oldsuccesslines = lists.successlines
  PUSH,newsuccesslines,oldsuccesslines
  PUSH,newsuccesslines,successlist

  ; Get unique ones
  ui = UNIQ(newsuccesslines,sort(newsuccesslines))
  ui = ui[sort(ui)]
  newsuccesslines = newsuccesslines[ui]
  nnewsuccesslines = n_elements(newsuccesslines)

  ; Write the success file
  WRITELINE,successfile,newsuccesslines

  ;out = successlist+'  SUCCESS'
  ;printlog,logfile,out,/logonly
endif


;------------------
; Updating OUTLIST
;------------------
noutlist = n_elements(outlist)
if (noutlist gt 0) then begin

  ; Adding to the OLD outlist
  lsst_undefine,oldoutputlines,newoutputlines
  if (lists.noutputlines gt 0) then oldoutputlines = lists.outputlines
  PUSH,newoutputlines,oldoutputlines
  PUSH,newoutputlines,outlist

  ; Get unique ones
  ui = UNIQ(newoutputlines,sort(newoutputlines))
  ui = ui[sort(ui)]
  newoutputlines = newoutputlines[ui]
  nnewoutputlines = n_elements(newoutputlines)


  nnew = nnewoutputlines - lists.noutputlines
  if not keyword_set(silent) then begin
    printlog,logfile,strtrim(nnewoutputlines,2),' files in '+thisprog+'.outlist'
    printlog,logfile,strtrim(nnew,2),' files were ADDED to '+thisprog+'.outlist'
  endif

  ; Write the output file
  WRITELINE,outputfile,newoutputlines

  ;out = 'Added '+outlist+' to OUTLIST'
  ;printlog,logfile,out,/logonly
endif


;----------------
; Updating INLIST
;----------------
; Some successful ones
if (nsuccesslist gt 0) then begin
  if not keyword_set(silent) then $
    printlog,logfile,strtrim(nsuccesslist,2),' files removed from '+thisprog+'.inlist'

  ; Some files left over
  if (nsuccesslist lt ninputlines) then begin
    ; Match them
    MATCH,inputlines,successlist,ind1,ind2,count=nmatch

    if (nmatch gt 0) then begin
      newinputlines = inputlines
      REMOVE,ind1,newinputlines
      WRITELINE,inputfile,newinputlines
    endif else begin
      printlog,logfile,'NO MATCH BETWEEN INPUTLINES AND NEW SUCCESSLIST'
    endelse

  ; All succeeded, "empty" inlist
  endif else begin

    ; Make a zero length file
    FILE_DELETE,inputfile,/allow
    SPAWN,'touch '+inputfile,out,errout
  endelse
endif


;----------------------
; Updating FAILURE list
;----------------------
nfailurelist = n_elements(failurelist)
if not keyword_set(silent) then $
  printlog,logfile,strtrim(nfailurelist,2),' files FAILED'

; Checking to see if any past failures were successful this time
remnewsuccess=0
if (lists.nfailurelines gt 0 and nsuccesslist gt 0) then begin
  MATCH,lists.failurelines,successlist,ind1,ind2,count=nind1
  if nind1 gt 0 then remnewsuccess=1
endif

if (nfailurelist gt 0) or (remnewsuccess eq 1) then begin

  ; Adding to the OLD failure list
  lsst_undefine,oldfailurelines,newfailurelines
  if (lists.nfailurelines gt 0) then oldfailurelines = lists.failurelines
  PUSH,newfailurelines,oldfailurelines
  PUSH,newfailurelines,failurelist

  ; Get unique ones
  ui = UNIQ(newfailurelines,sort(newfailurelines))
  ui = ui[sort(ui)]
  newfailurelines = newfailurelines[ui]
  nnewfailurelines = n_elements(newfailurelines)

  ; Removing PAST failures that were successful this time
  if (nsuccesslist gt 0) then begin
    MATCH,newfailurelines,successlist,ind1,ind2,count=nind1

    if (nind1 gt 0) then begin
      if nind1 lt nnewfailurelines then REMOVE,ind1,newfailurelines
      if nind1 eq nnewfailurelines then lsst_undefine,newfailurelines
      nnewfailurelines = n_elements(newfailurelines)
    endif
  endif ; some successful files

  ; Write the failure file, should be okay even if no lines
  WRITELINE,failurefile,newfailurelines

endif

;stop

if keyword_set(stp) then stop

end
