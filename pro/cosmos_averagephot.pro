;+
;
; SMASHRED_AVERAGEPHOT
;
; Calculate average photometry for each unique object
; and filter using ALLSRC and ALLOBJT
;
; INPUTS:
;  fstr       The structure with information for each exposure.
;  chstr      The structure with information for each chip.
;  allstr     The structure with information for each source detection.
;  allobj     The structure with information for each unique object.
;  /usecalib  Average the calibrated photometry (CMAG/CERR).  The default
;               is to use the instrumental photometry (MAG/ERR).
;  /silent    Don't print anything to the screen.
;
; OUTPUTS:
;  The photometric magnitude and error columns will be updated in ALLOBJ.
;  =error     The error message if one occurred.
;
; USAGE:
;  IDL>smashred_averagephot,fstr,chstr,allsrc,allobj
;
; By D.Nidever  March 2016
;-

pro cosmos_averagephot,fstr,chstr,allsrc,allobj,error=error,silent=silent

; Not enough inputs
if n_elements(fstr) eq 0 or n_elements(chstr) eq 0 or n_elements(allsrc) eq 0 or n_elements(allobj) eq 0 then begin
  error = 'Not enough inputs'
  print,'Syntax - smashred_averagephot,fstr,chstr,allstr,allobj,usecalib=usecalib,error=error,silent=silent'
  return
endif

lallobjtags = strlowcase(tag_names(allobj))
nallobj = n_elements(allobj)

; Get unique filters
ui = uniq(fstr.filter,sort(fstr.filter))
ufilter = fstr[ui].filter
nufilter = n_elements(ufilter)


; Combine photometry from same filter
if not keyword_set(silent) then print,'Combining all of the photometry'
for i=0,nufilter-1 do begin

  ; Number of exposures for this filter
  filtind = where(fstr.filter eq ufilter[i],nfiltind)
  ; Chips for this filter
  chind = where(chstr.filter eq ufilter[i],nchind)

  ; Indices for the magnitude and errors in ALLOBJ
  magind = where(lallobjtags eq ufilter[i]+'mag')
  errind = where(lallobjtags eq ufilter[i]+'magerr')
  scatind = where(lallobjtags eq ufilter[i]+'magscatter')

  ; Only one exposure for this filter, copy
  if nfiltind eq 1 then begin

    ; All bad to start
    allobj.(magind) = 99.99
    allobj.(errind) = 9.99
    allobj.(scatind) = 99.99

    ; Now copy in the values, ALLSRC only had "good" detections
    for k=0,nchind-1 do begin
      ind = lindgen(chstr[chind[k]].nsrc)+chstr[chind[k]].sepallindx
      allobj[allsrc[ind].cmbindx].(magind) = allsrc[ind].mag
      allobj[allsrc[ind].cmbindx].(errind) = allsrc[ind].magerr
    endfor

  ; Multiple exposures for this filter to average
  endif else begin

    ; Loop through all of the chips and add up the flux, totalwt, etc.
    totalwt = dblarr(nallobj)
    totalfluxwt = dblarr(nallobj)
    for k=0,nchind-1 do begin
      ind = lindgen(chstr[chind[k]].nsrc)+chstr[chind[k]].sepallindx
      totalwt[allsrc[ind].cmbindx] += 1.0d0/allsrc[ind].magerr^2
      totalfluxwt[allsrc[ind].cmbindx] += 2.5118864d^allsrc[ind].mag * (1.0d0/allsrc[ind].magerr^2)
    endfor
    newflux = totalfluxwt/totalwt
    newmag = 2.50*alog10(newflux)
    newerr = sqrt(1.0/totalwt)
    bdmag = where(finite(newmag) eq 0,nbdmag)
    if nbdmag gt 0 then begin
      newmag[bdmag] = 99.99
      newerr[bdmag] = 9.99
    endif

    ; measure scatter, RMS
    ;  sqrt(mean(diff^2))
    totaldiff = dblarr(nallobj)
    numobs = lonarr(nallobj)
    for k=0,nchind-1 do begin
      ind = lindgen(chstr[chind[k]].nsrc)+chstr[chind[k]].sepallindx
      totaldiff[allsrc[ind].cmbindx] += (newmag[allsrc[ind].cmbindx] - allsrc[ind].mag)^2
      numobs[allsrc[ind].cmbindx]++
    endfor
    newscatter = sqrt( totaldiff/(numobs>1) )
    if nbdmag gt 0 then newscatter[bdmag]=99.99

    ; Set scatter=99.99 for numobs=1
    oneobs = where(numobs eq 1,noneobs)
    if noneobs gt 0 then newscatter[oneobs]=99.99

    allobj.(magind) = newmag
    allobj.(errind) = newerr
    allobj.(scatind) = newscatter

    ;stop

  endelse  ; combine multiple exposures for this filter
endfor ; unique filter loop


; Measure astrometric median scatter
;-----------------------------------
nvisits = n_elements(fstr)

; ra/dec scatter
totalra = dblarr(nallobj)
totaldec = dblarr(nallobj)
numobs = lonarr(nallobj)
nchstr = n_elements(chstr)
for k=0,nchstr-1 do begin
  ind = lindgen(chstr[k].nsrc)+chstr[k].sepallindx
  totalra[allsrc[ind].cmbindx] += allsrc[ind].coord_ra
  totaldec[allsrc[ind].cmbindx] += allsrc[ind].coord_dec
  numobs[allsrc[ind].cmbindx]++
endfor
newra = totalra/(numobs>1)
newdec = totaldec/(numobs>1)
bd = where(numobs eq 0,nbd)
if nbd gt 0 then newra[bd]=999999.0
if nbd gt 0 then newdec[bd]=999999.0

; measure scatter, RMS
;  sqrt(mean(diff^2))
totalradiff = dblarr(nallobj)
totaldecdiff = dblarr(nallobj)
for k=0,nchstr-1 do begin
  ind = lindgen(chstr[k].nsrc)+chstr[k].sepallindx
  totalradiff[allsrc[ind].cmbindx] += (newra[allsrc[ind].cmbindx] - allsrc[ind].coord_ra)^2
  totaldecdiff[allsrc[ind].cmbindx] += (newdec[allsrc[ind].cmbindx] - allsrc[ind].coord_dec)^2
endfor
newrascatter = sqrt( totalradiff/(numobs>1) ) * 3600 * cos(newdec/!radeg)
newdecscatter = sqrt( totalradiff/(numobs>1) ) * 3600
if nbd gt 0 then newrascatter[bd]=99.99
if nbd gt 0 then newdecscatter[bd]=99.99

; Set scatter=99.99 for numobs=1
oneobs = where(numobs eq 1,noneobs)
if noneobs gt 0 then newrascatter[oneobs]=99.99
if noneobs gt 0 then newdecscatter[oneobs]=99.99

allobj.coord_ra = newra
allobj.coord_dec = newdec
allobj.rascatter = newrascatter
allobj.decscatter = newdecscatter

;stop

end
