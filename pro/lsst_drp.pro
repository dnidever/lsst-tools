;+
;
; LSST_DRP
;
; This is an IDL wrapper around the LSST DRP command line tasks.
;
; Currently there are five stages:
;  -processCcd
;  -makeCoaddTempExp
;  -assembleCoadd
;  -processCoadd
;  -forcedPhot
;
; Each stage has several log files associated with it:
;  INLIST   The list of files to process
;  OUTLIST  The successfully outputted files
;  SUCCESS  The files in INLIST that were successfully processed
;  FAILURE  The files in INLIST that were NOT successfully processed
;  LOG      A running log of what the stage has done
;
; Each stage can be run separately from the command line if desired.
;
; By D. Nidever  Nov 2015
;-

pro lsst_drp,dirs,redo=redo,stp=stp


COMMON lsst,setup


; Start the logfile
;------------------
; format is photred.DATETIME.log
jd = systime(/julian)
caldat,jd,month,day,year,hour,minute,second
smonth = strtrim(month,2)
if month lt 10 then smonth = '0'+smonth
sday = strtrim(day,2)
if day lt 10 then sday = '0'+sday
syear = strmid(strtrim(year,2),2,2)
shour = strtrim(hour,2)
if hour lt 10 then shour='0'+shour
sminute = strtrim(minute,2)
if minute lt 10 then sminute='0'+sminute
ssecond = strtrim(round(second),2)
if second lt 10 then ssecond='0'+ssecond
logfile = 'lsst_drp.'+smonth+sday+syear+shour+sminute+ssecond+'.log'
JOURNAL,logfile

; Print info
;-----------
host = GETENV('HOST')
print,''
print,'############################################'
print,'Starting LSST_DRP   ',systime(0)
print,'Running on ',host
print,'############################################'
print,''

; Check that all of the required programs are available
;------------------------------------------------------
;  Each sub-program will do its own test.
progs = ['lsst_loadsetup','lsst_getinput','lsst_updatelists','lsst_processccddecam']
test = PROG_TEST(progs)
if min(test) eq 0 then begin
  bd = where(test eq 0,nbd)
  print,'SOME NECESSARY PROGRAMS MISSING'
  print,progs[bd]
  return
endif

; Make sure we have the right printlog.pro, not Markwardt's version
tempprogs = strsplit(!path,':',/extract)+'/printlog.pro'
test = file_test(tempprogs)
ind = where(test eq 1,nind)
bd = where(stregex(tempprogs[ind],'markwardt',/boolean) eq 1,nbd)
if nbd gt 0 then begin
  baddir = file_dirname(tempprogs[ind[bd]])
  print,"There is a version of Markwardt's PRINTLOG.PRO in "+baddir
  print,'Please rename this program (i.e. printlog.pro.orig)'
  return
endif


; LOAD THE SETUP FILE
;--------------------
; This is a 2xN array.  First colume are the keywords
; and the second column are the values.
; Use READPAR.PRO to read it
LSST_LOADSETUP,setup,count=count
if (count lt 1) then return

; Are we redoing?
doredo = READPAR(setup,'REDO')
if keyword_set(redo) or (doredo ne '-1' and doredo ne '0') then redo=1



;#########################################
;#  STARTING THE PROCESSING
;#########################################


;----------------
; processCcdDecam
;----------------
LSST_PROCESSCCDDECAM,redo=redo

;------------------
; makeCoaddTempExp
;------------------
LSST_MAKECOADDTEMPEXP,redo=redo


;----------------
; assembleCoadd
;----------------
LSST_ASSEMBLECOADD,redo=redo

;--------------
; processCoadd
;--------------
LSST_PROCESSCOADD,redo=redo

;-------------
; forcedPhot
;-------------
LSST_FORCEDPHOT,redo=redo


print,'LSST FINISHED'


; Run PHOTRED_SUMMARY
;--------------------
LSST_SUMMARY


; End logfile
;------------
JOURNAL

if keyword_set(stp) then stop

end
