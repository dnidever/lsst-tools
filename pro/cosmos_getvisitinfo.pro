pro cosmos_getvisitinfo,fstr,visitstr,silent=silent

; combine and match up sources for the exposure-level catalogs

;restore,'combine_calexp_catalogs_temp.dat'
;goto,startagainhere

radeg = 180.0d0 / !dpi

;dir = '/data/lsst/decam/redux/cp/cosmos-sdssref/'
dir = '/data/lsst/decam/redux/cp/cosmos-sdssref-psfex/'

calexpfiles = file_search(dir+'017*/calexp/calexp-*.fits',count=ncalexpfiles)
if not keyword_set(silent) then print,strtrim(ncalexpfiles,2),' calexp files found'

; Initialize the calexp information structure
fstr = replicate({file:'',visit:'',ccdnum:-1L,sepallindx:-1LL,calexpfile:'',srcfile:'',nsrc:-1L,dateobs:'',filter:'',$
                  exptime:0.0,ra:0.0d0,dec:0.0d0,fwhm:0.0,$
                  ellipticity:0.0,avsky:0.0,avsig:0.0,magzero:0.0,fluxmag0:0.0d0,$
                  ; QA information
                  medbackground:-1.0,sigbackground:-1.0,$
                  initpsffwhm:-1.0,npsfstars_selected:-1L,npsfstars_used:-1L,ncosmicrays:-1L,$
                  wcsrms:-1.0,ndetected:-1L,ndeblended:-1L},ncalexpfiles)
fstr.file = calexpfiles
dir = file_dirname(calexpfiles)
base = file_basename(calexpfiles,'.fits')
fstr.visit = strmid(base,7,7)
fstr.ccdnum = long(strmid(base,15,2))

ui = uniq(fstr.visit,sort(fstr.visit))
uvisits = fstr[ui].visit
nvisits = n_elements(uvisits)

; Loop through the visits
undefine,final,sepall
for i=0L,nvisits-1 do begin
  ccdind = where(fstr.visit eq uvisits[i],nccdind)
  if not keyword_set(silent) then print,strtrim(i+1,2),' ',uvisits[i],' ',strtrim(nccdind,2)

  ; Load the calexp info
  undefine,visitsep
  for j=0,nccdind-1 do begin
    head = headfits(fstr[ccdind[j]].file)
    fstr[ccdind[j]].dateobs = strtrim(sxpar(head,'DATE'),2)
    filter = strtrim(sxpar(head,'filter'),2)
    filt = (strsplit(filter,' ',/extract))[0]
    fstr[ccdind[j]].filter = filt
    fstr[ccdind[j]].exptime = sxpar(head,'exptime')
    fstr[ccdind[j]].ra = sxpar(head,'crval1')
    fstr[ccdind[j]].dec = sxpar(head,'crval2')
    fstr[ccdind[j]].fwhm = sxpar(head,'fwhm')
    fstr[ccdind[j]].ellipticity = sxpar(head,'elliptic')
    fstr[ccdind[j]].avsky = sxpar(head,'avsky')
    fstr[ccdind[j]].avsig = sxpar(head,'avsig')
    fstr[ccdind[j]].magzero = sxpar(head,'magzero')
    fstr[ccdind[j]].fluxmag0 = sxpar(head,'fluxmag0')

    ;; Load QA file as well
    ;qafile = fstr[ccdind[j]].visit+'/qa/processCcdDecamQA-'+$
    ;         fstr[ccdind[j]].visit+'_'+string(fstr[ccdind[j]].ccdnum,format='(i02)')+'.fits'
    ;if file_test(qafile) eq 1 then begin
    ;  qastr = mrdfits(qafile,1,/silent)
    ;  fstr[ccdind[j]].medbackground = qastr.medbackground
    ;  fstr[ccdind[j]].sigbackground = qastr.sigbackground
    ;  fstr[ccdind[j]].initpsffwhm = qastr.initpsffwhm
    ;  fstr[ccdind[j]].npsfstars_selected = qastr.npsfstars_selected
    ;  fstr[ccdind[j]].npsfstars_used = qastr.npsfstars_used
    ;  fstr[ccdind[j]].ncosmicrays = qastr.ncosmicrays
    ;  fstr[ccdind[j]].wcsrms = qastr.wcsrms
    ;  fstr[ccdind[j]].ndetected = qastr.ndetected
    ;  fstr[ccdind[j]].ndeblended = qastr.ndeblended
    ;endif else print,'no QA file for ',qafile

    ; Load the source catalog file
    srcfile = fstr[ccdind[j]].visit+'/src/src-'+fstr[ccdind[j]].visit+'_'+string(fstr[ccdind[j]].ccdnum,format='(i02)')+'.fits'
    if file_test(srcfile) eq 0 then begin
      print,'no source files for ',srcfile
      goto,bomb1
    endif
    fstr[ccdind[j]].srcfile = srcfile
    ;str = mrdfits(srcfile,1,/silent)
    ;nstr = n_elements(str)

    ; calexp file
    calexpfile = fstr[ccdind[j]].visit+'/calexp/calexp-'+fstr[ccdind[j]].visit+'_'+string(fstr[ccdind[j]].ccdnum,format='(i02)')+'.fits'
    if file_test(calexpfile) eq 0 then begin
      print,calexpfile,' NOT FOUND'
      goto,bomb1
    endif
    fstr[ccdind[j]].calexpfile = calexpfile

    ;; convert coords from RADIANS to DEGREES
    ;str.coord_ra *= radeg
    ;str.coord_dec *= radeg

    ;fstr[ccdind[j]].sepallindx = n_elements(sepall)
    ;fstr[ccdind[j]].nsrc = nstr

    BOMB1:

  endfor ; chip loop
endfor  ; visit loop

; Only keep the COSMOS data
print,'Keeping only COSMOS field visits'
gd = where(fstr.ra gt 145 and fstr.ra lt 155 and fstr.dec gt 1 and fstr.dec lt 3,ngd)
fstr = fstr[gd]

;startagainhere:

; create visit structure
ui = uniq(fstr.visit,sort(fstr.visit))
uvisits = fstr[ui].visit
nvisits = n_elements(uvisits)
visitstr = replicate({visit:'',dateobs:'',filter:'',exptime:0.0,fwhm:0.0,magzero:0.0,$
                      fluxmag0:0.0d0,avsky:0.0,ndetected:0L},nvisits)
for i=0,nvisits-1 do begin
  ind = where(fstr.visit eq uvisits[i],nind)
  visitstr[i].visit = uvisits[i]
  visitstr[i].dateobs = fstr[ind[0]].dateobs
  visitstr[i].filter = fstr[ind[0]].filter
  visitstr[i].exptime = fstr[ind[0]].exptime
  visitstr[i].fwhm = median([fstr[ind].fwhm])
  visitstr[i].magzero = median([fstr[ind].magzero])
  visitstr[i].fluxmag0 = median([fstr[ind].fluxmag0])
  visitstr[i].avsky = median([fstr[ind].avsky])
  visitstr[i].ndetected = total(fstr[ind].ndetected)
endfor

;stop

end
