pro cosmos_photcalib,fstr,chstr,allsrc,allobj,useaper=useaper,redo=redo

; Use ubercal to calibrate photometry

;if n_elements(fstr) eq 0 then fstr=mrdfits('combine_calexp_catalogs_visitstr.fits',1)
;if n_elements(chstr) eq 0 then chstr=mrdfits('combine_calexp_catalogs_fstr.fits',1)
;if n_elements(allsrc) eq 0 then allsrc=mrdfits('combine_calexp_catalogs_sepall.fits',1)
;if n_elements(allobj) eq 0 then allobj=mrdfits('combine_calexp_catalogs_final.fits',1)

if keyword_set(useaper) then tag='ap' else tag='psf'

COSMOS_GETVISITINFO,info,fstr,/silent
ninfo = n_elements(info)

; Load the catalogs
COSMOS_LOAD_CATPHOT,info,chstr,allsrc,reduxdir=reduxdir,useaper=useaper,redo=redo

; Crossmatch
print,'Crossmatch all of the sources and buld ALLOBJ'
COSMOS_CROSSMATCH,fstr,chstr,allsrc,allobj
;allsrc = MRDFITS('final/cosmos_allsrc_'+tag+'.fits',1)
;allobj = MRDFITS('final/cosmos_allobj_'+tag+'.fits',1)
;MWRFITS,allsrc,'final/cosmos_allsrc_'+tag+'.fits',/create
;MWRFITS,allobj,'final/cosmos_allobj_'+tag+'.fits',/create
;;save,fstr,chstr,allsrc,allobj,file=tmpdir+field+'_crossmatch.dat'
;print,'restoring temporary allsrc/allobj file'
;restore,tmpdir+field+'_crossmatch.dat'

;stop

; Filter loop
uifilter = uniq(chstr.filter,sort(chstr.filter))
ufilter = chstr[uifilter].filter
nfilter = n_elements(ufilter)
for f=0,nfilter-1 do begin
  ifilter = ufilter[f]
  chfiltind = where(chstr.filter eq ifilter,nchfiltind)
  chfiltstr = chstr[chfiltind]
  print,'- ',strtrim(f+1,2),' FILTER = ',ifilter,' ',strtrim(nchfiltind,2),' nchips'

  print,'1. Measuring relative magnitude offsets between chip pairs'
  COSMOS_MEASURE_MAGOFFSET,chfiltstr,allsrc,overlapstr ;,/verbose

  print,'2. Determine relative magnitude offsets per chip using ubercal'
  COSMOS_SOLVE_UBERCAL,overlapstr,ubercalstr

  print,'3. Apply offsets to photometry'
  COSMOS_APPLY_OFFSETS,chfiltstr,ubercalstr,allsrc
endfor

; compute average photometry and astrometry and scatter
COSMOS_AVERAGEPHOT,fstr,chstr,allsrc,allobj

;stop

MWRFITS,fstr,'cosmos_calexp_catalogs_exposures_'+tag+'.fits',/create
MWRFITS,chstr,'cosmos_calexp_catalogs_chips_'+tag+'.fits',/create
MWRFITS,allsrc,'cosmos_calexp_catalogs_allsrc_'+tag+'.fits',/create
MWRFITS,allobj,'cosmos_calexp_catalogs_allobj_'+tag+'.fits',/create

stop

end
