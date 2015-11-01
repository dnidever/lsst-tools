pro photred_checkpbs,statstr,jobid=jobid,stp=stp

; This checks the status of PBS jobs
; If no jobs are found in queue then an empty
; statstr structure is returned.

njobid = n_elements(jobid)

addon = ''
if njobid gt 0 then addon=' '+jobid[0]

SPAWN,'qstat'+addon,out,errout
dum = where(out ne '',nout)
if nout gt 2 and strmid(out[0],0,3) eq 'Job' then statlines=out[2:*]

nstat = n_elements(statlines)
; Some jobs in queue
if nstat gt 0 then begin
  arr = strsplitter(statlines,' ',/extract)
  dumdum = {jobid:'',name:'',user:'',timeuse:'',status:'',queue:''}
  statstr = replicate(dumdum,nstat)
  statstr.jobid = reform(arr[0,*])
  statstr.name = reform(arr[1,*])
  statstr.user = reform(arr[2,*])
  statstr.timeuse = reform(arr[3,*])
  statstr.status = reform(arr[4,*])
  statstr.queue = reform(arr[5,*])
; No jobs in queue
endif else begin
  statstr = {jobid:'',name:'',user:'',timeuse:'',status:'',queue:''}
endelse

if keyword_set(stp) then stop

end