pro photred_makepbs,input,dir=dir,name=name,scriptname=scriptname

; This makes PBS scripts for photred
;
; INPUTS:
;  input    The IDL command to execute.  Can be an array.  idlbatch will be used.
;  =dir     The directory to put the PBS script in.
;  =name    The name to call the PBS script (without the '.sh' ending)
;
; OUTPUTS:
;  PBS scripts output to the direcotires and with the names
;  specified.
;  =scriptname   The absolute names of the scripts
;

ninput = n_elements(input)
ndir = n_elements(dir)
nname = n_elements(name)

; Not enough inputs
if ninput eq 0 then begin
  print,'NO INPUT'
  return
endif

; Not enough directories input
if ndir gt 0 and ndir ne ninput then begin
  print,'INPUT and DIRECTORIES are of different size'
  return
endif


; Current directory
CD,current=curdir

; No directories input
if ndir eq 0 then dir = replicate(curdir,ninput)

; Make names
if nname eq 0 then begin
  name = strarr(ninput)
  for i=0,nname-1 do name[i]=maketemp('pr')
endif

; Makie scriptnames
scriptname = dir+'/'+name+'.sh'



; Script loop
FOR i=0,ninput-1 do begin

  base = name[i]
  bname = dir[i]+'/'+base+'.batch'
  sname = dir[i]+'/'+base+'.sh'

  ; Make IDL batch file
  ;----------------------
  WRITELINE,bname,input[i]


  ; Make the command
  ;----------------------
  undefine,lines
  push,lines,'#!/bin/sh'
  push,lines,'#PBS -l nodes=1:ppn=1'
  push,lines,'#PBS -l walltime=96:00:00'
  push,lines,'#PBS -o '+base+'.report.out'
  push,lines,'#PBS -e '+base+'.error.out'
  ;push,lines,'##PBS -m abe'
  ;push,lines,'#PBS -M dln5q@virginia.edu'
  push,lines,'#PBS -V'
  push,lines,''
  push,lines,'echo Running on host `hostname`'
  push,lines,'echo Time is `date`'
  push,lines,'echo "Nodes used for this job:"'
  push,lines,'echo "------------------------"'
  push,lines,'cat $PBS_NODEFILE'
  push,lines,'echo "------------------------"'
  push,lines,''
  push,lines,'cd '+dir[i]
  push,lines,'idl < ',bname
  push,lines,''
  push,lines,'# print end time'
  push,lines,'echo'
  push,lines,'echo "Job Ended at `date`"'
  push,lines,'echo'

  ; Writing the file
  WRITELINE,scriptname[i],lines
  ;print,'Made PBS script. To run: >>qsub '+base+'.sh<<'

  ; Print info
  print,'PBS script written to: ',scriptsname[i]


END

; Go back to original directory
CD,curdir

stop

end