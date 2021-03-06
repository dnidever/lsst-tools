;+
;
; SMASHRED_CROSSMATCH
;
; This program crossmatches sources for a field and creates
; the ALLSTR and ALLOBJ structures.
;
; INPUTS:
;  field   The name of the field.
;  fstr    The structure with information for each exposure.
;  chstr   The structure with information for each chip.
;  allsrc  The structure with information for each source detection.
;  =dcr    The matching radius in arcsec.  The default is 0.5 arcsec.
;  /silent Don't print anything to the screen.
;
; OUTPUTS:
;  allobj  The structure with information for each unique object.
;  The CHSTR structure is also updated with the ALLSRCINDX column.
;  =error  The error message if one occurred.
;
; USAGE:
;  IDL>smashred_crossmatch,fstr,chstr,allstr,allobj
; 
; By D.Nidever  March 2016
;-

pro cosmos_crossmatch,fstr,chstr,allsrc,allobj,dcr=dcr,error=error,silent=silent

undefine,allobj

; Not enough inputs
if n_elements(fstr) eq 0 or n_elements(chstr) eq 0 or n_elements(allsrc) eq 0 then begin
  error = 'Not enough inputs'
  print,'Syntax - smashred_crossmatch,field,fstr,chstr,allsrc,allobj'
  return
endif

nfstr = n_elements(fstr)
nchstr = n_elements(chstr)

; Defaults
if n_elements(dcr) eq 0 then dcr=0.5  ; 0.7

; Unique exposures from CHSTR
uiexp = uniq(chstr.visit,sort(chstr.visit))
uexp = chstr[uiexp].visit
nuexp = n_elements(uexp)
; Unique exposures from FSTR
uifexp = uniq(fstr.visit,sort(fstr.visit))
ufexp = fstr[uifexp].visit
nufexp = n_elements(ufexp)
; unqiue FSTR and CHSTR exposures don't match
if nuexp ne nfstr then begin
  error = 'Exposures do NOT match in FSTR and CHSTR'
  if not keyword_set(silent) then print,error
  return
endif
; duplicate exposures in FSTR
if nufexp ne nfstr then begin
  error = 'Duplicate exposures in FSTR'
  if not keyword_set(silent) then print,error
  return
endif


nan = !values.f_nan
dnan = !values.d_nan

; Make the ALLOBJ structure schema
; id, flags, coord_ra, coord_dec, exposure, ccdnum, deblend_nchild,
; BASE_GAUSSIANCENTROID_X, BASE_GAUSSIANCENTROID_Y,
; sdssshape_xx, sdssshape_yy, sdssshape_xy, psfflux_flux,
; psfflux_sigma
fdum = {id:0LL,coord_ra:0.0d0,coord_dec:0.0d0,rascatter:0.0,decscatter:0.0,$
        umag:0.0,umagerr:0.0,umagscatter:0.0,gmag:0.0,gmagerr:0.0,gmagscatter:0.0,rmag:0.0,rmagerr:0.0,rmagscatter:0.0,$
        imag:0.0,imagerr:0.0,imagscatter:0.0,zmag:0.0,zmagerr:0.0,zmagscatter:0.0,$
        ndet:0L,sepindx:lonarr(nufexp)-1,sepfindx:lonarr(nufexp)-1}
;fdum = {id:'',ra:0.0d0,dec:0.0d0,ndet:0L,depthflag:0B,srcindx:lonarr(nuexp)-1,srcfindx:lonarr(nuexp)-1,$
;        u:99.99,uerr:9.99,g:99.99,gerr:9.99,r:99.99,rerr:9.99,i:99.99,ierr:9.99,z:99.99,zerr:9.99,chi:nan,sharp:nan,flag:-1,prob:nan,ebv:99.99}
cur_sepall_indx = 0LL         ; next one starts from HERE
nallsrc = n_elements(allsrc)  ; current number of total Allsrc elements, NOT all filled
; SRCINDX has NDET indices at the front of the array
; SRCFINDX has them in the element that matches the frame they were
; detected in
allobjtags = tag_names(fdum)
lallobjtags = strlowcase(allobjtags)
; Loop through the exposures
for i=0,nfstr-1 do begin
  ; CHSTR indices for this exposure
  expind = where(chstr.visit eq fstr[i].visit,nexpind)
  ;if fstr[i].exptime lt 100 then depthbit=1 else depthbit=2  ; short or long

  print,strtrim(i+1,2),'/',strtrim(nfstr,2),' adding exposure ',fstr[i].visit

  ; Get all chip ALLSRC information for this exposure
  undefine,expnew,expnewallsrcindx
  for j=0,nexpind-1 do begin
    ; Get the source data from CHSTR and ALLSRC
    temp_allsrcindx = lindgen(chstr[expind[j]].nsrc)+chstr[expind[j]].sepallindx
    temp = allsrc[temp_allsrcindx]
    push,expnew,temp         ; add to exposure "new" structure
    push,expnewallsrcindx,temp_allsrcindx  ; allsrc index for this exposure
  endfor

  ;------------------------------
  ; PUT IN ALLOBJ MERGED CATALOG
  ;------------------------------
  ; Copy to new structure type
  If i eq 0 then begin
    allobj = replicate(fdum,n_elements(expnew))
    ;allobj.id = field+'.'+strtrim(lindgen(n_elements(expnew))+1,2)
    allobj.id = strtrim(lindgen(n_elements(expnew))+1,2)
    allobj.coord_ra = expnew.coord_ra
    allobj.coord_dec = expnew.coord_dec

    ; Put ALLSRC index in ALLOBJ
    ;allobj.srcindx[0] = lindgen(n_elements(expnew))
    ;allobj.srcfindx[i] = lindgen(n_elements(expnew))
    allobj.sepindx[0] = expnewallsrcindx
    allobj.sepfindx[i] = expnewallsrcindx
    allobj.ndet = 1
    ;allobj.depthflag OR= depthbit             ; OR combine to depthflag, 1-short, 2-long, 3-short+long
    ; Put ID, CMBINDX in ALLSRC
    ;allsrc[0:cur_sepall_indx-1].fid = allobj.id
    ;allsrc[0:cur_sepall_indx-1].cmbindx = lindgen(n_elements(allobj))
    ;allsrc[expnewallsrcindx].fid = allobj.id
    allsrc[expnewallsrcindx].cmbindx = lindgen(n_elements(allobj))

  ; 2nd and later exposures, check for repeats/overlap
  Endif else begin

    ; Match sources
t0 = systime(1)
    SRCMATCH,allobj.coord_ra,allobj.coord_dec,expnew.coord_ra,expnew.coord_dec,dcr,ind1,ind2,count=nmatch,/sph,/usehist  ; use faster histogram_nd method
;print,'dt=',systime(1)-t0,' sec.  matching time'
    print,' ',strtrim(nmatch,2),' matched sources'
    ; Some matches, add data to existing record for these sources
    if nmatch gt 0 then begin
      for k=0LL,nmatch-1 do allobj[ind1[k]].sepindx[allobj[ind1[k]].ndet] = expnewallsrcindx[ind2[k]]     ; put SRCINDX in ALLOBJ
      allobj[ind1].sepfindx[i] = expnewallsrcindx[ind2]    ; put SRCFINDX in ALLOBJ
      allobj[ind1].ndet++
      ;allobj[ind1].depthflag OR= depthbit                  ; OR combine to depthflag  
      ;allsrc[expnewallsrcindx[ind2]].fid = allobj[ind1].id  ; put ID, CMBINDX in ALLSRC
      allsrc[expnewallsrcindx[ind2]].cmbindx = ind1
      ; Remove stars
      if nmatch lt n_elements(expnew) then remove,ind2,expnew,expnewallsrcindx else undefine,expnew,expnewallsrcindx
    endif

    ; Some left, add records for these sources
    if n_elements(expnew) gt 0 then begin
      print,' ',strtrim(n_elements(expnew),2),' sources left to add'
      newallobj = replicate(fdum,n_elements(expnew))
      ;newallobj.id = field+'.'+strtrim(lindgen(n_elements(expnew))+1+n_elements(allobj),2)
      newallobj.id = strtrim(lindgen(n_elements(expnew))+1+n_elements(allobj),2)
      newallobj.coord_ra = expnew.coord_ra
      newallobj.coord_dec = expnew.coord_dec
      newallobj.sepindx[0] = expnewallsrcindx      ; put SRCINDX in ALLOBJ
      newallobj.sepfindx[i] = expnewallsrcindx     ; put SRCFINDX in ALLOBJ
      newallobj.ndet = 1
      ;newallobj.depthflag OR= depthbit             ; OR combine to depthflag
      ;allsrc[expnewallsrcindx].fid = newallobj.id  ; put ID, CMBINDX in ALLSRC
      allsrc[expnewallsrcindx].cmbindx = lindgen(n_elements(expnew))+n_elements(allobj)
      ; concatenating two large structures causes lots to be zerod out
;t0 = systime(1)
      nold = n_elements(allobj)
      nnew = n_elements(newallobj)
      new = replicate(fdum,nold+nnew)
      new[0:nold-1] = allobj
      new[nold:*] = newallobj
      allobj = new
      undefine,new
;print,'dt=',systime(1)-t0
    endif

  Endelse  ; 2nd or later

bd = where(allobj.coord_ra eq 0.0,nbd)
if nbd gt 0 then stop,'ALLOBJ Zerod out elements problem!!!'

    ;stop

Endfor  ; exposure loop

;stop

end
