;+
;
; LSST_STAGES
;
; This program loads the stages file.
;
; INPUTS:
;  setup    The setup file.  It is a string array with
;             dimensions of 2xN_parameters.  READPAR can be
;             used to read the parameters.
;  /silent  Don't print any messages to the screen.
;  /stp     Stop at the end of the program.
;
; OUTPUTS:
;  stages   The stages structure with name, inputs and outputs for each.
;  =count   The number of stages.  count is -1 if there
;             was a problem.
;  =error   The error message, if one occurred.
;
; USAGE:
;  IDL>lsst_loadstages,setup,stages,count=count,stp=stp
;
; By D.Nidever  Nov 2012
;-

pro lsst_loadstages,setup,stages,count=count,error=error,silent=silent,stp=stp

; Initializing some parameters
count = -1
lsst_undefine,stages
lsst_undefine,error

; Not enough inputs
if n_elements(setup) eq 0 then begin
  error = 'Not enough inputs'
  print,'Syntax - lsst_stages,setup,stages,silent=silent,error=error,count=count,stp=stp'
  return
endif

; Pull stages filename from setup file
stages_file = LSST_READPAR(setup,'stages')
if stages_file eq '0' or stages_file eq '' or stages_file eq '-1' then begin
  error = 'STAGES file NOT FOUND'
  if not keyword_set(silent) then print,error
  count = -1
  return
endif

; Read the setup file
LSST_READLINE,stages_file[0],lines,comment='#',count=nlines

; Parse the lines
if nlines gt 0 then begin
  lines2 = strsplitter(lines,' ',/extract)
  lines2 = strtrim(lines2,2)
  sz = size(lines2)
  ncol = sz[1]
  npar = sz[2]
  count = npar
  
  ; The stages file has three columns: Name, Inputs, Outputs
  ;  the name is case-sensitive
  ;  multiple inputs/outputs are comma-delimited
  
  stages = replicate({name:'',inputs1:'',ninputs:0L,inputarr:ptr_new(),inputstr:'',outputs1:'',noutputs:0L,outputarr:ptr_new(),outputstr:''},npar)
  for i=0,npar-1 do begin
    stages[i].name = reform(lines2[0,i])
    if ncol gt 1 then begin
      inputstr = reform(lines2[1,i])
      inputarr = strsplit(inputstr,',',/extract)
      ninputs = n_elements(inputarr)
      stages[i].inputs1 = inputarr[0]
      stages[i].ninputs = ninputs
      stages[i].inputarr = ptr_new(inputarr)
      stages[i].inputstr = inputstr
    endif
    if ncol gt 2 then begin
      outputstr = reform(lines2[2,i])
      outputarr = strsplit(outputstr,',',/extract)
      noutputs = n_elements(outputarr)
      stages[i].outputs1 = outputarr[0]
      stages[i].noutputs = noutputs
      stages[i].outputarr = ptr_new(outputarr)
      stages[i].outputstr = outputstr
    endif
  endfor

; No lines to process
endif else begin
  error = setupfiles[0]+' HAS NO LINES TO PARSE'
  if not keyword_set(silent) then print,error
  count = 0
  return
endelse

if keyword_set(stp) then stop

end
