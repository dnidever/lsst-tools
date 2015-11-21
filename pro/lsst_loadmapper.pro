;+
;
; LSST_LOADMAPPER
;
; This program loads the mapper file.
;
; INPUTS:
;  mapperfile  The file with the mapping information (e.g. obs_decam/policy/DecamMapper.paf)
;  /silent  Don't print any messages to the screen.
;  /stp     Stop at the end of the program.
;
; OUTPUTS:
;  mapper   The mapper structure with information each dataset.
;  =count   The number of mapper data structures.  count is -1 if there
;             was a problem.
;  =error   The error message, if one occurred.
;
; USAGE:
;  IDL>lsst_loadmapper,mapperfile,mapper,count=count,error=error,stp=stp
;
; By D.Nidever  Nov 2012
;-

pro lsst_loadmapper,mapperfile,mapper,count=count,error=error,silent=silent,stp=stp

; Initializing some parameters
count = -1
lsst_undefine,mapper
lsst_undefine,error

; Not enough inputs
if n_elements(mapperfile) eq 0 then begin
  error = 'Not enough inputs'
  print,'Syntax - lsst_loadmapper,mapperfile,mapper,count=count,error=error,silent=silent,stp=stp'
  return
endif

; Mapper file doesn't exist
if file_test(mapperfile) eq 0 then begin
  error = mapperfile+' does NOT exist'
  if not keyword_set(silent) then print,error
  return
endif

; Read-in the mapper file
LSST_READLINE,mapperfile[0],lines,comment='#',count=nlines
lines = strtrim(lines,2)
gd = where(lines ne '',ngd)
if ngd eq 0 then begin
  error = mapperfile[0]+' HAS NO LINES TO PARSE'
  if not keyword_set(silent) then print,error
  count = 0
  return
endif
lines = lines[gd]
nlines = n_elements(lines)

; Example of a mapper file.  This is part of HscMapper.paf
;#<?cfg paf policy ?>
;
;needCalibRegistry: true
;
;camera:        "../hsc/camera"
;defects:    "../hsc/defects"
;
;skytiles: {
;    resolutionPix: 700    # Resolution for skytiles: 700 --> 500 arcsec sides
;    paddingArcsec: 10.0   # Overlap between skytiles
;}
;
;levels: {
;    # Keys that are NOT relevant for a particular level
;    skyTile: "visit" "ccd"
;    tract: "patch"
;    visit: "ccd"
;    sensor: "none"
;}
;defaultLevel: "sensor"
;defaultSubLevels: {
;    # Default sublevel for dataRef.subItems()
;    skyTile: "sensor"
;    visit: "sensor"
;    sensor: "none"
;}
;
;exposures: {
;    raw: {
;        template:    "%(field)s/%(dateObs)s/%(pointing)05d/%(filter)s/HSC-%(visit)07d-%(ccd)03d.fits"
;        python:     "lsst.afw.image.DecoratedImageU"
;        persistable:         "DecoratedImageU"
;        storage:     "FitsStorage"
;        level:        "Ccd"
;        tables:        "raw"
;        tables:        "raw_visit"
;    }
;    postISRCCD: {
;        template:    "postISRCCD/v%(visit)07d-f%(filter)s/c%(ccd)03d.fits"
;        python:        "lsst.afw.image.ExposureF"
;        persistable:        "ExposureF"
;        storage:    "FitsStorage"
;        level:        "Ccd"
;        tables:        "raw"
;        tables:        "raw_visit"
;    }

; it looks like there can be duplicate names which probably indicate
; multiple values.

; Parse the lines
if nlines gt 0 then begin

  ; Go through each line and figure out if it's a key-value pair,
  ; whether this is a nesting definition, and what nesting level it's at
  linestr = replicate({line:'',keyvalue:0L,nestdef:0L,nestname:'',nestnum:0L,nestlevel:'',nnestentries:0L,key:'',value:''},nlines)
  nestnum = 0L
  for i=0,nlines-1 do begin
    line = lines[i]
    linestr[i].line = line
    ; Remove comment portions
    hashmark = strpos(line,'#')
    if hashmark ne -1 then line = strtrim(strmid(line,0,hashmark),2)
    ; Colon separation
    linearr = strtrim(strsplit(line,':',/extract),2)
    nlinearr = n_elements(linearr)
    ; key-value pair
    if nlinearr eq 2 then if linearr[1] ne '{' then begin
       linestr[i].keyvalue = 1
       linestr[i].key = linearr[0]
       linestr[i].value = linearr[1]
    endif
    ; nesting definition
    if nlinearr eq 2 then if linearr[1] eq '{' then begin
      linestr[i].nestdef = 1
      linestr[i].nestname = linearr[0]
      lsst_push,nestarr,linearr[0]
    endif
    ; nestnum
    linestr[i].nestnum = nestnum                   ; nest number before incrementing, nest definition is at the same level
    len = strlen(line)
    if strmid(line,len-1,1) eq '}' then begin      ; going down a nesting level
      ; figure out how many nest entries we have for this item
      dum = where(linestr[0:i].nestlevel eq strjoin(nestarr,'.') and linestr[0:i].nestnum eq nestnum,nnestentries)
      nestdefind = where(linestr[0:i].nestlevel eq strjoin(nestarr,'.') and linestr[0:i].nestnum eq nestnum-1,nnestdefind)
      linestr[nestdefind[0]].nnestentries = nnestentries
      nestnum--  ; decriment nest number
      nnestarr = n_elements(nestarr)               ; remove last nest level
      if nnestarr eq 1 then undefine,nestarr
      if nnestarr gt 1 then lsst_remove,nnestarr-1,nestarr
   endif
    if strmid(line,len-1,1) eq '{' then nestnum++  ; going up a nesting level
    ; nestlevel
    if n_elements(nestarr) gt 0 then linestr[i].nestlevel=strjoin(nestarr,'.')
  endfor

  ; Generate final mapper structure, one entry for each unique item.
  ind = where(linestr.keyvalue eq 1,nind)
  mapper = replicate({fullname:'',nesting:'',name:'',value:''},nind)
  nestlevel = linestr[ind].nestlevel
  fullname = nestlevel + '.' + linestr[ind].key
  nonest = where(nestlevel eq '',nnonest)
  if nnonest gt 0 then fullname[nonest] = linestr[ind[nonest]].key
  mapper.fullname = fullname
  mapper.nesting = linestr[ind].nestlevel
  mapper.name = linestr[ind].key
  mapper.value = linestr[ind].value

; No lines to process
endif else begin
  error = mapperfile[0]+' HAS NO LINES TO PARSE'
  if not keyword_set(silent) then print,error
  count = 0
  return
endelse

if keyword_set(stp) then stop

end
