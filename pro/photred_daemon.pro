pro photred_daemon,input,dirs,jobs=jobs

; This program is the daemon for photred.  It controls pleione jobs.
; See daophot_setup.pro for how to make the pleione scripts
;
; If we are running on Pleione, multiple jobs is turned on, and multiple
; jobs are input then run the daemon, otherwise just run single jobs
;
; INPUTS:
;  input   A string array with the IDL commands (i.e. jobs) to be run.
;
;
; Maybe allow the names of the PBS scripts to be input.

COMMON photred,setup

; Current directory
CD,current=curdir

; How many input lines
ninput = n_elements(input)
if ninput eq 0 then begin
  print,'NO INPUT'
  return
endif

ndirs = n_elemets(dirs)
if ndirs eq 0 then dirs = replicate(curdir,ninput)

; What host
host = getenv('HOST')
pleione = stregex(host,'pleione',/boolean,/fold_case)

; Do multiple jobs?
nmulti = READPAR(setup,'NMULTI')
nmulti = long(nmulti)


;--------
; DAEMON
;--------
IF (ninput gt 1) and (pleione eq 1) and (nmulti gt 1) then begin

  ; Keep submitting jobs until nmulti is reached
  ;
  ; Check every minute or so to see how many jobs are still
  ; running.  If it falls below nmulti and more jobs are left then
  ; submit more jobs
  ;
  ; Don't return until all jobs are done.


  ; Default number of jobs to submit at a time
  if nmulti eq 0 or nmulti eq -1 then nmulti=8

  ; Start the "jobs" structure
  ; id will be the ID from Pleione
  dum = {jobid:'',input:'',name:'',scriptname:'',submitted:0,done:0}
  jobs = replicate(dum,ninput)
  jobs.input = input
  njobs = ninput

  ; Loop until all jobs are done
  ; One each loop check the pleione queue and figure out what to do
  count = 0.
  WHILE (flag eq 0) DO BEGIN


    ; Check the jobs we've already submitted (and aren't done yet)
    ;--------------------------------------------------------------
    sub = where(jobs.submitted eq 1 and jobs.done eq 0,nsub)
    for i=0,nsub-1 do begin

      ; Checking status
      jobid = jobs[sub[i]].jobid
      PHOTRED_CHECKPBS,statstr,jobid=jobid

      ; Done
      ; Should probably check the output files too
      if statstr.jobid eq '' then jobs[sub[i]].done=1

      ; Check for errors as well!! and put in jobs structure

    end


    ; How many jobs are still in the queue
    ;-------------------------------------
    dum = where(jobs.submitted eq 1 and jobs.done eq 0,ninqueue)


    ; Need to Submit more jobs
    ;-------------------------
    nnew = (nmulti-ninqueue) > 0
    If (nnew gt 0) then begin

      ; Get the indices of new jobs to be submitted
      nosubmit = where(jobs.submitted eq 0)
      newind = nosubmit[0:nnew-1]

      ; Loop through the new submits
      For i=0,nnew-1 do begin

        ; Make PBS script
        undefine,name,scriptname
        PHOTRED_MAKEPBS,jobs[newind[i]].input,dir=dirs,name=name,scriptname=scriptname

        ; Submitting the job
        SPAWN,'qsub '+scriptname,out,errout
        jobid = reform(out)

        ; Updating the jobs structure
        jobs[newind[i]].submitted = 1
        jobs[newind[i]].jobid = jobid
        jobs[newind[i]].name = name
        jobs[newind[i]].scriptname = scriptname

      End  ; submitting new jobs loop

    Endif  ; new jobs to submit


    ; Are we done?
    ;-------------
    dum = where(jobs.done eq 1,ndone)
    if ndone eq njobs then flag=1


    ; Wait a minute
    ;--------------
    if flag eq 0 then wait,60

    ; Increment the counter
    count++

  ENDWHILE


;------------
; NON-DAEMON
;------------
ENDIF ELSE BEGIN


  ; Loop through the jobs
  FOR i=0,ninput-1 do begin
    
    ; CD to the directory
    ;--------------------
    cd,dirs[i]

    ; Execute the command
    ;--------------------
    ; Do we want to do this with idlbatch so that
    ; there is a nice log file
    dum = EXECUTE(input[i])

  END

ENDELSE


stop

if keyword_set(stp) then stop

end