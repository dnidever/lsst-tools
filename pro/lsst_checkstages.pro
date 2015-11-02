;+
;
; LSST_CHECKSTAGES
;
; This program checks that all the stages can work together, i.e. that
; the inputs and outputs work together.
;
; INPUTS:
;  stages   The stages structure with name, inputs and outputs for each.
;  /silent  Don't print any messages to the screen.
;  /stp     Stop at the end of the program.
;
; OUTPUTS:
;  =error   The error message, if one occurred.
;
; USAGE:
;  IDL>lsst_checkstages,stages,error=error,stp=stp
;
; By D.Nidever  Nov 2012
;-

pro lsst_checkstages,stages,error=error,silent=silent,stp=stp

; Initializing some parameters
lsst_undefine,error

nstages = n_elements(stages)

; Not enough inputs
if n_elements(stages) eq 0 then begin
  error = 'Not enough inputs'
  print,'Syntax - lsst_checkstages,stages,error=error,silent=silent,stp=stp'
  return
endif

; Only one stage, nothing to check
if nstages le 1 then return

; Loop over the stages
for i=1,nstages-1 do begin
  prestage = stages[i-1]
  thisstage = stages[i]
  ; is the input of thisstage an output of the prestage?
  input = thisstage.inputs1
  outputs = reform( *prestage.outputarr )
  noutputs = prestage.noutputs
  inthere = total( stregex(outputs,input,/boolean,/fold_case) )
  ; Not found
  if inthere eq 0 then begin
    error = input+' for stage '+thisstage.name+' is NOT an output in the prior stage '+prestage.name+' ('+prestage.outputstr+')'
    if not keyword_set(silent) then print,error 
  endif
endfor

if keyword_set(stp) then stop

end
