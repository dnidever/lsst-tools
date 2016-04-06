;+
;
; LSST_PROCESSCCDDECAM
;
; This is a wrapper around the LSST processCcdDecam command.
;
; INPUTS:
;  /redo Redo files that were already done.
;  /stp  Stop at the end of the program.
;
; OUTPUTS:
;  Calibrated images for each visit/ccdnum.
;
; By D.Nidever  Nov 2015
;-
pro lsst_processccddecam,redo=redo,error=error,stp=stp

COMMON lsst,setup

thisprog = 'processCcdDecam'

CD,current=curdir

print,''
print,'############################'
print,'RUNNING LSST_'+strupcase(thisprog)
print,'############################'
print,''

; Print date and time to the logfile
print,''
print,'Starting LSST_'+strupcase(thisprog)+'  ',systime(0)

; Check that all of the required programs are available
progs = ['lsst_loadsetup','lsst_getinput','lsst_updatelists']
test = PROG_TEST(progs)
if min(test) eq 0 then begin
  bd = where(test eq 0,nbd)
  error = 'SOME NECESSARY PROGRAMS ARE MISSING:'
  print,error
  print,progs[bd]
  return
endif


; Check that the program for this stage exists
SPAWN,'which '+thisprog+'.py',out,errout
progfile = FILE_SEARCH(out,count=nprogfile)
if (nprogfile eq 0) then begin
  error = thisprog+'.py PROGRAM NOT AVAILABLE'
  print,error
  return
endif

; Check that EUPS works
SPAWN,'which eups',out,errout
progfile = FILE_SEARCH(out,count=nprogfile)
if (nprogfile eq 0) then begin
  error = 'EUPS NOT AVAILABLE'
  print,error
  return
endif

; LOAD THE SETUP FILE if not passed
;-----------------------------------
; This is a 2xN array.  First colume are the keywords
; and the second column are the values.
; Use READPAR.PRO to read it
if n_elements(setup) eq 0 then begin
  LSST_LOADSETUP,setup,count=count
  if count lt 1 then return
endif

; Getting data repository directory
datarepodir = LSST_READPAR(setup,'datarepodir')
if datarepodir eq '0' or datarepodir eq '-1' or datarepodir eq '' then begin
  error = 'No data repository directory'
  if not keyword_set(silent) then print,error
  return
endif
; Check that the datarepodir directory exists
if file_test(datarepodir,/directory) eq 0 then begin
  error = 'Data repository directory '+datarepodir+' NOT FOUND'
  print,error
  return
endif

; Logs directory and files
logsdir = datarepodir+'logs/'                   ; logs directory
testlogs = file_test(logsdir,/directory)        ; make sure it exists
if testlogs eq 0 then FILE_MKDIR,'logs'
logfile = logsdir+strupcase(thisprog)+'.log'    ; initialize logfile
if file_test(logfile) eq 0 then SPAWN,'touch '+logfile,out

; What architecture are we working on
spawn,['uname'],out,errout,/noshell
out = strtrim(out[0],2)
case out of:
   'Darwin': arch='mac'
   'Linux': arch='linux'
   else: arch='unix'
endcase

; Redo
doredo = LSST_READPAR(setup,'REDO')
if keyword_set(redo) or (doredo ne '-1' and doredo ne '0') then redo=1 else redo=0
; Hyperthread
hyperthread = LSST_READPAR(setup,'hyperthread')
if hyperthread ne '0' and hyperthread ne '' and hyperthread ne '-1' then hyperthread=1
if strtrim(hyperthread,2) eq '0' then hyperthread=0
; Nmulti
nmulti = LSST_READPAR(setup,'NMULTI')
if nmulti eq '0' or nmulti eq '' or nmulti eq '-1' then nmulti=1L
nmulti = long(nmulti)
; Mapperfile
mapperfile = LSST_READPAR(setup,'mapperfile')
if mapperfile eq '0' or mapperfile eq '-1' or mapperfile eq '' then begin
  error = 'No Mapper File'
  if not keyword_set(silent) then lsst_printlog,logfile,error
  return
endif
; DOQA
doqa = LSST_READPAR(setup,'DOQA')
if doqa eq '0' or doqa eq '' or doqa eq '-1' then doqa=0
; ALLQA
allqa = LSST_READPAR(setup,'ALLQA')
if allqa eq '0' or allqa eq '' or allqa eq '-1' then allqa=0
; NTHREADS
nthreads = LSST_READPAR(setup,'NTHREADS')
if nthreads eq '0' or nthreads eq '' or nthreads eq '-1' then nthreads=1 else nthreads=long(nthreads)>1


; Load the stages information
LSST_LOADSTAGES,setup,stages,error=error
if n_elements(error) gt 0 then return

; Load the mapper information
LSST_LOADMAPPER,mapperfile,mapper,error=error
if n_elements(error) gt 0 then return

; Check that there is a mapper file
if file_test(datarepodir+'/_mapper') eq 0 then begin
  error = 'No _mapper file in '+datarepodir
  lsst_printlog,logfile,error
  return
endif
; Check that there is a registry
if file_test(datarepodir+'/registry.sqlite3') eq 0 then begin
  error = 'No registry.sqlite3 file in '+datarepodir+'.  Create one with an ingest script.'
  lsst_printlog,logfile,error
  return
endif

; Getting user configuration file directory
configdir = LSST_READPAR(setup,'configdir')
if configdir eq '0' or configdir eq '-1' or configdir eq '' then begin
  error = 'No configuration directory'
  if not keyword_set(silent) then lsst_printlog,logfile,error
  return
endif
; Is there a userconfiguration file for this stage
configfile = configdir+'/'+thisprog+'.config'
if file_test(configfile) then begin
  lsst_printlog,logfile,'Using configuration file ',configfile
endif else begin
  lsst_undefine,configfile
  lsst_printlog,logfile,'No configuration file for '+thisprog
endelse

; Remove any config files for this stage in the config/ directory
;   otherwise it causes config change problems
conf_files = file_search(datarepodir+'config/'+thisprog+'*',count=nconf_files)
if nconf_files gt 0 then file_delete,conf_files,/allow
lsst_printlog,logfile,'Cleaning config/ directory of '+thisprog+' config files'
; Remove anything in the schema/ directory
sch_files = file_search(datarepodir+'schema/*',count=nsch_files)
if nsch_files gt 0 then file_delete,sch_files,/allow
lsst_printlog,logfile,'Cleaning schema/ directory'

; Save EUPS versions of packages in config/
spawn,['eups','list','--setup'],out,errout,/noshell
if n_elements(out) gt 0 then begin
  if file_test(datarepodir+'/config/',/directory) eq 0 then file_mkdir,datarepodir+'/config/'
  WRITELINE,datarepodir+'/config/'+thisprog+'.eupslist.log',out
endif else begin
  error = 'Error getting EUPS versions of packages'
  if not keyword_set(silent) then lsst_printlog,logfile,error
  return
endelse


   
; MAKE SURE THAT THE APPROPRIATE STACK PRODUCTS ARE SETUP WITH EUPS!!!


;###################
; GETTING INPUTLIST
;###################

; Get input
;-----------
lists = LSST_GETINPUT(thisprog,stages,logsdir=logsdir,redo=redo)
ninputlines = lists.ninputlines

; If nothing in the INLIST create it from the registry
if ninputlines eq 0 then begin

  lsst_printlog,logfile,'No files in the INLIST.  Checking the registry database'

  ; Getting visits from the registry
  tempfile = maketemp('reg')
  spawn,'sqlite3 -header registry.sqlite3 "SELECT * from raw;" >> '+tempfile,out,errout
  reg = importascii(tempfile,/header,delimit='|',/silent)
  file_delete,tempfile,/allow
  ;spawn,'echo "select * from raw_visit;" | sqlite3 '+datarepodir+'/registry.sqlite3',out,errour
  ;176837|2013-02-10|z
  ;176838|2013-02-10|z
  ;177071|2013-02-11|i
  ;177072|2013-02-11|i
  ;arr = strsplitter(out,'|',/extract)
  ;visits = strtrim(reform(arr[0,*]),2)
  ;nvisits = n_elements(visits)

  ; Create a unique ccd-level name VISITS[CCDNUM]
  ;  should really use "exposures.instcal.template" in the
  ;  mapper file for this
  visitccd = string(reg.visit,format='(i07)')+'['+string(reg.ccdnum,format='(i02)')+']'
  nvisitccd = n_elements(visitccd)
  
  inputfile = logsdir+strupcase(thisprog)+'.inlist'
  lsst_printlog,logfile,'Adding '+strtrim(nvisitccd,2)+' chip to INLIST'
  WRITELINE,inputfile,visitccd
  
  ; Get inputs again
  lists = LSST_GETINPUT(thisprog,stages,logsdir=logsdir,redo=redo)
  ninputlines = lists.ninputlines
endif


; No files to process
;---------------------
if ninputlines eq 0 then begin
  error = 'NO FILES TO PROCESS'
  lsst_printlog,logfile,error
  return
endif

; Getting the inputs and parsing into visit and ccdnum
inputlines = lists.inputlines
ninputs = n_elements(inputlines)
; parse inputs to VISITS[CCDNUM]
visit = strarr(ninputs)
ccdnum = strarr(ninputs)
for i=0,ninputs-1 do begin
  len = strlen(strtrim(inputlines[i],2))
  lo = strpos(inputlines[i],'[') 
  visit[i] = strmid(inputlines[i],0,lo)
  ccdnum[i] = strmid(inputlines[i],lo+1,len-lo-2)
endfor
visit = string(visit,format='(i07)')  ; should get this format from the policy file
ccdnum = string(ccdnum,format='(i02)')

; List of steps
; 1. figure out the files to run on
; 2. construct the array of commands, with config file
; 3. run job_daemon
; 4. Check the log files for failures and check that the output files
;      are there
; 5. update the lists


; Have some been done already??
;------------------------------
If not keyword_set(redo) then begin

  calexpfile = datarepodir+'/'+visit+'/calexp/calexp-'+visit+'_'+ccdnum+'.fits'
  donearr = file_test(calexpfile)

  ; Some done already. DO NOT REDO
  bd = where(donearr eq 1,nbd)
  if nbd gt 0 then begin
    ; Print out the names
    lsst_printlog,logfile,''
    lsst_printlog,logfile,inputlines[bd]+' '+thisprog+' ALREADY DONE'

    ; Add these to the "success" and "outlist" list
    LSST_PUSH,successlist,inputlines[bd]
    LSST_PUSH,outlist,calexpfile[bd]
    LSST_UPDATELISTS,stages,lists,outlist=outlist,successlist=successlist,$
                        failurelist=failurelist,/silent

    ; Remove them from the arrays
    if nbd lt ninputs then REMOVE,bd,inputlines,visit,ccdnum
    if nbd eq ninputs then LSST_UNDEFINE,inputlines,visit,ccdnum
    ninputs = n_elements(inputlines)

    lsst_printlog,logfile,''
    lsst_printlog,logfile,'REMOVING '+strtrim(nbd,2)+' files from INLIST.  '+$
                          strtrim(ninputs,2)+' files left to PROCESS'
    lsst_printlog,logfile,''
  endif

  ; No files to run
  if ninputs eq 0 then begin
    printlog,logfile,'NO FILES TO PROCESS'
    return
  endif

; Redoing, erase files for ones previously processed
Endif else begin
  lsst_printlog,logfile,'Redoing.  Deleting output files from previous processing.'
  scriptfile = datarepodir+'/'+visit+'/calexp/'+thisprog+'-'+visit+'_'+ccdnum+'.sh'
  donearr = file_test(scriptfile)
  ; Some done already, erase old files
  prevdone = where(file_test(scriptfile) eq 1,nprevdone)
  for i=0,nprevdone-1 do begin
     ivisit = visit[prevdone[i]]
     ivisitccd = visit[prevdone[i]]+'_'+ccdnum[prevdone[i]]
     ; calexp, script/logfile, src, icSrc, icMatch, metadata, bkgd, qa, qascript, plot files
     oldfiles = datarepodir+'/'+ivisit+'/'+$
                ['calexp/calexp-'+ivisitccd+'.fits','calexp/'+thisprog+'-'+ivisitccd+'.sh','calexp/'+thisprog+'-'+ivisitccd+'.sh.log',$
                 'src/src-'+ivisitccd+'.fits','icSrc/icSrc-'+ivisitccd+'.fits','bkgd/bkgd-'+ivisitccd+'.fits',$
                 'icMatch/icMatch-'+ivisitccd+'.fits','metadata/metadata-'+ivisitccd+'.boost','qa/'+thisprog+'QA-'+ivisitccd+'.batch',$
                 'qa/'+thisprog+'QA-'+ivisitccd+'.batch.log','qa/'+thisprog+'QA-'+ivisitccd+'.fits']
     file_delete,oldfiles,/allow                                            ; it will only erase ones that exist
     ; do plot files separately, file_delete can't deal with empty 
     ;  wildcard strings properly
     plotfiles = file_search(datarepodir+'/'+ivisit+'/plots/*-'+ivisitccd+'*.png',count=nplotfiles)
     if nplotfiles gt 0 then file_delete,plotfiles,/allow
  endfor
Endelse


;##################################################
;#  PROCESSING THE FILES
;##################################################
; Make the DAPHOT/ALLSTAR option files (.opt and als.opt)
lsst_printlog,logfile,''
lsst_printlog,logfile,'-----------------------'
lsst_printlog,logfile,'PROCESSING THE FILES'
lsst_printlog,logfile,'-----------------------'
lsst_printlog,logfile,''


;------------------------
; Construct the commands
;------------------------


; get CCD numbers from the mapper file
; or the registry "raw" table

; An example of a processCcdDecam.py command:
; processCcdDecam.py /lsst8/decam/redux/cp/cosmos/ --id visit=0177743 ccdnum=26..33 --configfile /lsst8/decam/redux/cp/cosmos/config.py --clobber-config

; Make commands for processCcdDecam
cmd = thisprog+'.py '+datarepodir+' --id visit='+visit+' ccdnum='+ccdnum
; add thread limit global variable
;  it's a different environmental variable for mac vs. unix/linux
if arch eq 'mac' then nthreads_envvar='VECLIB_MAXIMUM_THREADS' else nthreads_envvar='OMP_NUM_THREADS'
if n_elements(nthreads) gt 0 then cmd='setenv '+nthreads_envvar+' '+strtrim(nthreads,2)+' ; '+cmd
; add configuration file
if n_elements(configfile) gt 0 then cmd+=' --configfile '+configfile
; Add date before and after
;cmd = 'date ; '+cmd+' ; date'
; Directory list,  datarepo/visitid/calexp/
dirs = datarepodir+'/'+visit+'/calexp/'
; Create the directories if necessary
for i=0,ninputs-1 do if file_test(dirs[i],/directory) eq 0 then file_mkdir,dirs[i]
; Make the script names,  processCcdDecam-visitid_ccdnum.batch
inpname = 'processCcdDecam-'+visit+'_'+ccdnum

; Submit the jobs to the daemon
JOB_DAEMON,cmd,dirs,jobs=jobstr,nmulti=nmulti,inpname=inpname,hyperthread=hyperthread,statustime=60

; SHOULD JOBSTR BE SAVED TO DISK??

; return the name of the scriptfiles
; give them reasonable names, name of file that is being processed,
;     stage, data/time

;-------------------
; Checking OUTPUTS
;-------------------
successarr = lonarr(ninputs)+1   ; all good until proven bad
errorarr = strarr(ninputs)
calexparr = strarr(ninputs)

; Loop through all files
print,''
for i=0,n_elements(jobstr)-1 do begin

  lsst_undefine,errors1

; check the outputs of the STAGES file 
; use the mapper policy file for the file/path naming conventions
  
  ; Check for the calexp file
  calexpfile = dirs[i]+'calexp-'+visit[i]+'_'+ccdnum[i]+'.fits'
  calexparr[i] = calexpfile
  if file_test(calexpfile) eq 0 then $
    lsst_push,errors1,'Calexp file '+calexpfile+' NOT FOUND'

  ; If the calexp exists, check that it was created/modified AFTER
  ; the recent script WAS RUN!!  It could be a leftover of a previous
  ; run of the same command
  
  ; Check the log file for errors
  loginfo = file_info(jobstr[i].logfile)
  if loginfo.exists eq 1 and loginfo.size gt 0 then begin
    LSST_READLINE,jobstr[i].logfile,loglines,count=nloglines
    traceback_ind = where(stregex(loglines,'^Traceback',/boolean) eq 1,ntraceback)
    if ntraceback gt 0 then begin
      lastline = loglines[nloglines-1]
      lsst_push,errors1,'Traceback error - '+lastline 
    endif
  endif else lsst_push,errors1,'Log file '+jobstr[i].logfile+' NOT FOUND OR EMPTY'  ; no logfile

  ; Failure
  if n_elements(errors1) gt 0 then begin
    successarr[i] = 0
    lsst_printlog,logfile,inputlines[i]+' ERRORS'
    lsst_printlog,logfile,'  '+errors1
    errorarr[i] = strjoin(errors1,'; ')
  endif
  
endfor

; Put logfilenames and errors in the logs/STAGE.failure file


;##########################################
;#  UPDATING LIST FILES
;##########################################
lsst_undefine,outlist,successlist,failurelist,errorlist

; Success List
ind = where(successarr eq 1,nind,comp=bd,ncomp=nbd)
if nind gt 0 then successlist=inputlines[ind]
; Output List
if nind gt 0 then outlist=calexparr[ind]
; Failure List
if nbd gt 0 then begin
  failurelist = inputlines[bd]
  errorlist = errorarr[bd]
endif

LSST_UPDATELISTS,stages,lists,outlist=outlist,successlist=successlist,$
                    failurelist=failurelist,errorlist=errorlist


;##########################################
;#  RUN QA
;##########################################
if keyword_set(doqa) then begin

   lsst_printlog,logfile,''
   lsst_printlog,logfile,'---- Running QA ----'

   ; Use inputs for this run ONLY
   if not keyword_set(allqa) then begin
     qalist = replicate({input:'',visit:'',ccdnum:'',success:-1},ninputs)
     qalist.input = inputlines
     qalist.visit = visit
     qalist.ccdnum = ccdnum
     qalist.success = successarr
   ; Use all inputs that were attempted (success or failed)
   endif else begin 
     ; Get success and failure lists
     lsst_undefine,qalist
     sfile = logsdir+strupcase(thisprog)+'.success'
     sinfo = file_info(sfile)
     if sinfo.exists eq 1 and sinfo.size gt 0 then begin
       LSST_READLIST,sfile,slines,/unique,count=scount
       qalist1 = replicate({input:'',visit:'',ccdnum:'',success:1},scount)
       qalist1.input = slines
       lsst_push,qalist,qalist1
     endif
     ffile = logsdir+strupcase(thisprog)+'.failure'
     if file_test(sfile) then begin
       LSST_READLIST,ffile,flines,/unique,count=fcount
       qalist1 = replicate({input:'',visit:'',ccdnum:'',success:0},fcount)
       qalist1.input = flines
       lsst_push,qalist,qalist1
     endif   
     ; Parse inputs to VISITS[CCDNUM]
     for i=0,n_elements(qalist)-1 do begin
       len = strlen(strtrim(qalist[i].input,2))
       lo = strpos(qalist[i].input,'[') 
       qalist[i].visit = strmid(qalist[i].input,0,lo)
       qalist[i].ccdnum = strmid(qalist[i].input,lo+1,len-lo-2)
     endfor
   endelse
   nqalist = n_elements(qalist)
  
   ; use job_daemon as well to parallelize
   cmd = "lsst_processccddecam_qa,'"+datarepodir+"','"+qalist.visit+"','"+qalist.ccdnum+"'"
   ; Directory list,  datarepo/visitid/calexp/
   dirs = datarepodir+'/'+qalist.visit+'/qa/'
   ; Create the directories if necessary
   for i=0,nqalist-1 do if file_test(dirs[i],/directory) eq 0 then file_mkdir,dirs[i]
   ; Make the script names,  processCcdDecam-visitid_ccdnum.batch
   inpname = 'processCcdDecamQA-'+qalist.visit+'_'+qalist.ccdnum
   JOB_DAEMON,cmd,dirs,jobs=qajobstr,nmulti=nmulti,inpname=inpname,hyperthread=hyperthread,statustime=60,/idle

   ; should add histogram in magnitude
   
   ; Make HTML pages, SHOW FAILURES, and list of metrics

   ; Load information for each input (visit/ccdnum)
   info = replicate({datarepodir:'',visit:'',ccdnum:'',runtimestamp:-1LL,scriptfile:'',logfile:'',userconfigfile:'',finalconfigfile:'',$
                     success:0,duration:-1.0,ra:-1.0d0,dec:-1.0d0,dateobs:'',airmass:'',$
                     filter:'',exptime:-1.0,fwhm:-1.0,fluxmag0:-1.0,calexpfile:'',nx:-1L,ny:-1L,$
                     medbackground:-1.0,sigbackground:-1.0,srcfile:'',nsources:-1L,calexp_plotfile:'',src_plotfile:'',$
                     initpsffwhm:-1.0,npsfstars_selected:-1L,npsfstars_used:-1L,ncosmicrays:-1L,wcsrms:-1.0,ndetected:-1L,ndeblended:-1L},nqalist)
   info.visit = qalist.visit
   info.ccdnum = qalist.ccdnum
   info.success = qalist.success
   for i=0,nqalist-1 do begin
      qafile = datarepodir+'/'+info[i].visit+'/qa/'+thisprog+'QA-'+info[i].visit+'_'+info[i].ccdnum+'.fits'
      if file_test(qafile) then begin
        info[i].success = 1
        qastr = mrdfits(qafile,1,/silent)
        info[i] = qastr  ; plug it in
      endif
   endfor
   if n_elements(configfile) gt 0 then info.userconfigfile=configfile
   finalconfigfile = datarepodir+'/config/'+thisprog+'.py'
   info.finalconfigfile = finalconfigfile
   
   ; Load information for each visit
   vui = uniq(qalist.visit,sort(qalist.visit))
   uvisit = qalist[vui].visit
   nuvisit = n_elements(uvisit)
   visitinfo = replicate({visit:'',nccdnum:0L,nsuccess:0,nfailed:0,percsuccess:0.0,duration:-1.0,nsources:0L,ra:0.0,dec:0.0,$
                           dateobs:'',airmass:'',fwhm:0.0,filter:'',exptime:0.0},nuvisit)
   visitinfo.visit = uvisit
   for i=0,nuvisit-1 do begin
     gd = where(info.visit eq uvisit[i],ngd)
     gdsuccess = where(info.visit eq uvisit[i] and info.success eq 1,ngdsuccess)
     visitinfo[i].nccdnum = ngd
     visitinfo[i].nsuccess = total(info[gd].success)
     visitinfo[i].nfailed = total(1-info[gd].success)
     visitinfo[i].percsuccess = total(float(info[gd].success/(ngd>1)))
     visitinfo[i].nsources = total(info[gd].nsources)
     if ngdsuccess gt 0 then begin
       visitinfo[i].ra = median([info[gdsuccess].ra])
       visitinfo[i].dec = median([info[gdsuccess].dec])
       visitinfo[i].dateobs = info[gdsuccess[0]].dateobs
       ;visitinfo[i].airmass =
       visitinfo[i].fwhm = median([info[gdsuccess].fwhm])
       visitinfo[i].filter = info[gdsuccess[0]].filter
       visitinfo[i].exptime = info[gdsuccess[0]].exptime
     endif
     visitinfo[i].duration = total(info[gd].duration>0)  ; total processing time
   endfor
   
   ; Create HTML files
   LSST_PROCESSCCDDECAM_QAHTML,datarepodir,logfile,info,visitinfo
   
   stop
endif

lsst_printlog,logfile,'LSST_'+strupcase(thisprog)+' Finished  ',systime(0)

if keyword_set(stp) then stop

end
