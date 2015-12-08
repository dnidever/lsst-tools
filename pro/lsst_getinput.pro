;+
;
; LSST_GETINPUT
;
; This gets the input for a given LSST stage.  The outputs from the precursor stage
; are copied/moved over and the output list and successlist are checked to make sure
; that a file has not already been processed (unless /redo is set).
;
; INPUTS:
;  thisprog     The stage to get the inputs for (e.g. 'DAOPHOT','MATCH', etc.)
;  stages       The stages structure with all the recent information
;                 about the stages and their inputs and outputs
;  =logsdir     The "logs/" directory.  The defaul is just "logs/"
;  /redo        Redo files already processed
;  /stp         Stop at the end of the program
;  =extension   Only accept inputs with this extension (i.e. 'als').  Do
;                 not include the dot.
;
; OUTPUTS:
;  lists        An IDL structure that includes all of the list information: precursor, prestage,
;                 prefile, inputlines, ninputlines, outputlines, noutputlines, successlines,
;                 and nsuccesslines.
;  =error       The error, if one occured, otherwise undefined.
;
; USAGE:
;  IDL>lists = lsst_getinput('DAOPHOT',stages)
;
; By D.Nidever  March 2008
;  updated for LSST   Nov 2015
;-

function lsst_getinput,thisprog,stages,logsdir=logsdir,redo=redo,stp=stp,error=error,$
                          extension=extension,noempty=noempty

COMMON lsst,setup

lsst_undefine,error

; Not enough inputs
;-------------------
nthisprog = n_elements(thisprog)
if (nthisprog eq 0) or n_elements(stages) eq 0 then begin
  error = 'Not enough inputs'
  print,'Syntax - lists = lsst_getinput(thisprog,stages,logsdir=logsdir,redo=redo)'
  return,{ninputlines:-1}
endif

; Error Handling
;------------------
; Establish error handler. When errors occur, the index of the  
; error is returned in the variable Error_status:  
CATCH, Error_status 

;This statement begins the error handler:  
if (Error_status ne 0) then begin 
   print,'LSST_GETINPUT ERROR: ', !ERROR_STATE.MSG  
   error = !ERROR_STATE.MSG
   CATCH, /CANCEL 
   return,{ninputlines:-1}
endif

; LOAD THE SETUP FILE if not passed
;-----------------------------------
; This is a 2xN array.  First colume are the keywords
; and the second column are the values.
; Use READPAR.PRO to read it
if n_elements(setup) eq 0 then begin
  LSST_LOADSETUP,setup,count=count
  if count lt 1 then return,{ninputlines:-1}
endif


; Is "thisprog" a valid stage?
;-------------------------------
upthisprog = strupcase(thisprog)
; NOT a valid stage
stageind = where(strupcase(stages.name) eq upthisprog,nstageind)
if (nstageind eq 0) then begin
  error = thisprog+' IS NOT A VALID STAGE'
  print,error
  return,{ninputlines:-1}
endif

; Get the precursor stage
if stageind gt 0 then precursor=stages[stagind[0]-1]

; Logs directory
cd,current=curdir
if n_elements(logsdir) eq 0 then logsdir=curdir+'/logs/'

; Does the logs directory exist?
testlogs = FILE_TEST(logsdir,/directory)
if testlogs eq 0 then FILE_MKDIR,logsdir

; Log files
;----------
logfile = logsdir+upthisprog+'.log'
inputfile = logsdir+upthisprog+'.inlist'
outputfile = logsdir+upthisprog+'.outlist'
successfile = logsdir+upthisprog+'.success'
failurefile = logsdir+upthisprog+'.failure'
; If the files don't exist create them
if file_test(logfile) eq 0 then TOUCHZERO,logfile
if file_test(inputfile) eq 0 then TOUCHZERO,inputfile
if file_test(outputfile) eq 0 then TOUCHZERO,outputfile
if file_test(successfile) eq 0 then TOUCHZERO,successfile
if file_test(failurefile) eq 0 then TOUCHZERO,failurefile


;############################################
;#  DEALING WITH LIST FILES
;############################################
lsst_printlog,logfile,''
lsst_printlog,logfile,'--------------------'
lsst_printlog,logfile,'CHECKING THE LISTS'
lsst_printlog,logfile,'--------------------'
lsst_printlog,logfile,''


; CHECK LISTS
;-----------------
;LSST_READLIST,inputfile,inputlines,/exist,/unique,/fully,count=ninputlines,logfile=logfile,/silent
LSST_READLIST,inputfile,inputlines,/unique,count=ninputlines,logfile=logfile,/silent
lsst_printlog,logfile,strtrim(ninputlines,2),' files in '+upthisprog+'.inlist'

; Load the output list
LSST_READLIST,outputfile,outputlines,/unique,count=noutputlines,logfile=logfile,/silent
lsst_printlog,logfile,strtrim(noutputlines,2),' files in '+upthisprog+'.outlist'

; Load the success list
LSST_READLIST,successfile,successlines,/unique,count=nsuccesslines,logfile=logfile,/silent
lsst_printlog,logfile,strtrim(nsuccesslines,2),' files in '+upthisprog+'.success'

; Load the failure list
LSST_READLIST,failurefile,failurelines,/unique,count=nfailurelines,logfile=logfile,/silent
lsst_printlog,logfile,strtrim(nfailurelines,2),' files in '+upthisprog+'.failure'


; CREATING INLIST
;----------------
nprecursor = n_elements(precursor)
flag = 0
if nprecursor eq 0 then flag=1
count = 0

WHILE (flag eq 0) do begin

  ; Getting the file name
  prestage = precursor.name
  upprestage = strupcase(prestage)
  prefile = logsdir+upprestage+'.outlist'
  printlog,logfile,'PRESTAGE = ',prestage

  ; Test that the file exists
  pretest = FILE_TEST(prefile)
  if (pretest eq 1) then begin
    ; Read list, make sure the files exist!!
    LSST_READLIST,prefile,poutputlines,/exist,/unique,/fully,count=npoutputlines,logfile=logfile,/silent
    lsst_printlog,logfile,strtrim(npoutputlines,2),' files in '+prestage+'.outlist file that exist'
  endif else npoutputlines=0

  ; Some files in PRECURSOR.outlist
  ; Move/Copy files from PRECURSOR outlist to CURRENT inlist
  if (npoutputlines gt 0) then begin

    ; Write to input file right away
    WRITELINE,inputfile,poutputlines,/append

    ; "Empty" PRECURSOR output
    ; ONLY if it is an "outlist" and not RENAME
    if not keyword_set(noempty) then begin
      printlog,logfile,'EMPTYING '+prestage+'.outlist'
      FILE_DELETE,prefile
      SPAWN,'touch '+prefile,out
    endif

    ; Add these to the inputlist
    LSST_PUSH,inputlines,poutputlines
    ninputlines = n_elements(inputlines)

    ; Remove redundant names
    ui = UNIQ(inputlines,sort(inputlines))
    ui = ui[sort(ui)]
    inputlines = inputlines[ui]
    ninputlines = n_elements(inputlines)

    ; End now
    flag = 1

  ; The PRECURSOR outlist is empty
  endif else begin
    if pretest eq 0 then $
      printlog,logfile,'NO FILES in ',prestage+'.outlist'
  endelse

  ; Have we exhausted the precursor list
  if (count eq (nprecursor-1)) then flag=1

  count++

ENDWHILE



;----------------------------------------------------------------
; DO NOT OVERWRITE/REDO Files already done (unless /REDO is set)
;----------------------------------------------------------------

; Remove all files in the outlist from the inlist, unless REDO is set
;-------------------------------------------------------------------------
if (ninputlines gt 0) and (noutputlines gt 0) then begin
  MATCH,inputlines,outputlines,ind1,ind2,count=nind1

  if (nind1 gt 0) then begin
    printlog,logfile,strtrim(nind1,2),' files in '+upthisprog+'.outlist are also in '+upthisprog+'.inlist'

    ; REDOING these
    if keyword_set(redo) then begin
      printlog,logfile,'REDO set.  Files in '+upthisprog+'.outlist *NOT* removed from '+upthisprog+'.inlist'

    ; Not redoing these
    endif else begin
      printlog,logfile,strtrim(nind1,2),' files in '+upthisprog+'.outlist removed from '+upthisprog+'.inlist'
      if nind1 lt ninputlines then REMOVE,ind1,inputlines
      if nind1 eq ninputlines then undefine,inputlines
      ninputlines = n_elements(inputlines)
    endelse
  endif
endif


; Remove all files in the success list from the inlist, unless REDO is set
;-------------------------------------------------------------------------
if (ninputlines gt 0) and (nsuccesslines gt 0) then begin
  MATCH,inputlines,successlines,ind1b,ind2b,count=nind1b

  if (nind1b gt 0) then begin
    printlog,logfile,strtrim(nind1b,2),' files in '+upthisprog+'.success are also in '+upthisprog+'.inlist'

    ; REDOING these
    if keyword_set(redo) then begin
      printlog,logfile,'REDO set.  Files in '+upthisprog+'.success *NOT* removed from '+upthisprog+'.inlist'

    ; Not redoing these
    endif else begin
      printlog,logfile,strtrim(nind1b,2),' files in '+upthisprog+'.success removed from '+upthisprog+'.inlist'
      if nind1b lt ninputlines then REMOVE,ind1b,inputlines
      if nind1b eq ninputlines then undefine,inputlines
      ninputlines = n_elements(inputlines)
    endelse
  endif
endif

; Checking the EXTENSION
;-------------------------
if (n_elements(extension) gt 0 and ninputlines gt 0) then begin

  extarr = strarr(ninputlines)
  for i=0,ninputlines-1 do extarr[i]=first_el(strsplit(inputlines[i],'.',/extract),/last)
  gdinp = where(extarr eq extension,ngdinp)

  ; Some endings matched
  if (ngdinp gt 0) then begin
    inputlines = inputlines[gdinp]
    ninputlines = ngdinp

  ; None matched
  endif else begin
    undefine,inputlines
    ninputlines = 0
  endelse

  ndiff = ninputlines-ngdinp
  if ndiff gt 0 then printlog,logfile,strtrim(ndiff,2),' DO NOT HAVE THE REQUIRED >>',extension,'<< EXTENSION'

endif


; It should check that the file "types", "datatypes" are correct from
; the stages structure!!!


; Writing INLIST
;---------------
; Some input files
if (ninputlines gt 0) then begin

  WRITELINE,inputfile,inputlines
  printlog,logfile,strtrim(ninputlines,2),' input files'

; No input files, empty it
endif else begin

  printlog,logfile,'NO input files'
  FILE_DELETE,inputfile
  SPAWN,'touch '+inputfile,out
endelse


; Making LIST structure
;------------------------

lists = {thisprog:thisprog}
if nprecursor gt 0 then lists = CREATE_STRUCT(lists,'precursor',precursor.name)
if n_elements(prestage) gt 0 then lists = CREATE_STRUCT(lists,'prestage',prestage)
if n_elements(prefile) gt 0 then lists = CREATE_STRUCT(lists,'prefile',prefile)
if ninputlines gt 0 then lists = CREATE_STRUCT(lists,'inputlines',inputlines)
lists = CREATE_STRUCT(lists,'ninputlines',ninputlines)
if noutputlines gt 0 then lists = CREATE_STRUCT(lists,'outputlines',outputlines)
lists = CREATE_STRUCT(lists,'noutputlines',noutputlines)
if nsuccesslines gt 0 then lists = CREATE_STRUCT(lists,'successlines',successlines)
lists = CREATE_STRUCT(lists,'nsuccesslines',nsuccesslines)
if nfailurelines gt 0 then lists = CREATE_STRUCT(lists,'failurelines',failurelines)
lists = CREATE_STRUCT(lists,'nfailurelines',nfailurelines)


if keyword_set(stp) then stop

return,lists

end
