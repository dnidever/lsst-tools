;+
;
; SMASHRED_LOAD_CATPHOT
;
; This program loads all of the photometry for one PHOTRED catalog
;
; INPUTS:
;  info        The structure with the relevant input information needed
;                to load the data.
;  /useast     Use the .ast files, by default the .phot files are used.
;  /usrorig    Use the original als/alf files.
;  =reduxdir   The reduction directory, the default is "/data/smash/cp/red/photred/"
;  /redo       Reget the photometry even if the temporary output file
;                already exists.
;
; OUTPUTS:
;  chstr       The structure with information on each chip file and
;                indices to the photometry information in ALLSRC.
;  allsrc      All source data concatenated together.
;  =error      The error message if one occurred.
;
; USAGE:
;  IDL>smashred_load_catphot,info,chstr,/useast
;
; By D.Nidever April 2016
;-

pro cosmos_load_catphot,info,chstr,allsrc,useaper=useaper,reduxdir=reduxdir,redo=redo,error=error

undefine,error
undefine,allsrc

radeg = 180.0d0 / !dpi

; Checking the inputs
if n_elements(info) eq 0 then begin
  error = 'Not enough inputs'
  print,'Syntax - smashred_load_catphot,info,chstr,allsrc,useast=useast,useorig=useorig,reduxdir=reduxdir,redo=redo,error=error'
  return
endif

; Defaults
;if n_elements(reduxdir) eq 0 then reduxdir='/data/lsst/decam/redux/cp/cosmos-sdssref/'
if n_elements(reduxdir) eq 0 then reduxdir='/data/lsst/decam/redux/cp/cosmos-sdssref-psfex/'
if file_test(reduxdir,/directory) eq 0 then begin
  error = reduxdir+' NOT FOUND'
  if not keyword_set(silent) then print,error
  return
endif
if n_elements(outputdir) eq 0 then outputdir=reduxdir+'final/'
if file_test(outputdir,/directory) eq 0 then begin
  if not keyword_set(silent) then print,outputdir+' does NOT exist.  Creating it.'
  FILE_MKDIR,outputdir
endif
; Temporary directory                                                                                                                                                                                                               
;tmpdir = outputdir+'/tmp/'
;if file_test(tmpdir,/directory) eq 0 then FILE_MKDIR,tmpdir

;; Construct the base name
;fbase = file_basename(info.file,'_summary.fits')  ; the observed field name

;; Output filename
;outfile = tmpdir+fbase+'_'+info.night+'_photred.fits'

if keyword_set(useaper) then tag='ap' else tag='psf'
allsrcfile = outputdir+'cosmos_allsrc_'+tag+'.fits'
chstrfile = outputdir+'cosmos_chstr_'+tag+'.fits'
;allsrcfile = outputdir+'cosmos_allsrc.fits'
;chstrfile = outputdir+'cosmos_chstr.fits'

; Get the data
if file_test(allsrcfile) eq 0 or keyword_set(redo) then begin

  ; Initialize CHSTR with INFO
  chstr = info

  ; Get data from the phot/ast files
  ;add_tag,chstr,'refexpnum','',chstr
  add_tag,chstr,'vertices_ra',dblarr(4),chstr
  add_tag,chstr,'vertices_dec',dblarr(4),chstr
  ;add_tag,chstr,'nsrc',-1L,chstr
  ;add_tag,chstr,'sepallindx',-1LL,chstr

  ; Initalize ALLSRC structure
  ;allsrc_schema = {cmbindx:-1L,chipindx:-1L,fid:'',id:-1L,x:0.0,y:0.0,mag:0.0,err:0.0,$
  ;                    cmag:-1.0,cerr:-1.0,chi:0.0,sharp:0.0,flag:-1,prob:-1.0,ra:0.0d0,dec:0.0d0}
  allsrc_schema = {id:0LL,fstrid:-1L,coord_ra:0.0d0,coord_dec:0.0d0,visit:'',ccdnum:0L,flags:bytarr(9),deblend_nchild:0L,$
                   base_gaussiancentroid_x:0.0d0,base_gaussiancentroid_y:0.0d0,base_sdssshape_xx:0.0d0,base_sdssshape_yy:0.0d0,$
                   base_sdssshape_xy:0.0d0,base_circularapertureflux_12_0_flux:0.0d0,base_circularapertureflux_12_0_fluxsigma:0.0d0,$
                   base_psfflux_flux:0.0d0, base_psfflux_fluxsigma:0.0d0,mag:0.0d0,magerr:0.0d0,cmbindx:-1LL}
  allsrc = replicate(allsrc_schema,5000000L)
  nallsrc = n_elements(allsrc)
  cur_sepall_indx = 0LL

  ; Load in the data
  ;If file_test(outfile) eq 0 or keyword_set(redo) then begin
  nchstr = n_elements(chstr)
  for i=0,nchstr-1 do begin

    srcfile = chstr[i].srcfile
    str = mrdfits(srcfile,1,/silent)
    nstr = n_elements(str)

    ; convert coords from RADIANS to DEGREES
    str.coord_ra *= radeg
    str.coord_dec *= radeg

    ;chstr[i].sepallindx = n_elements(sepall)
    chstr[i].nsrc = nstr

    ; Concatenate with SEPALL (all individual detections)
    ;-----------------------------------------------------
    ; id, flags, coord_ra, coord_dec, exposure, ccdnum, deblend_nchild,
    ; BASE_GAUSSIANCENTROID_X, BASE_GAUSSIANCENTROID_Y 
    ; sdssshape_xx, sdssshape_yy, sdssshape_xy, psfflux_flux,
    ; psfflux_sigma
    ;dum = {id:0LL,fstrid:-1L,coord_ra:0.0d0,coord_dec:0.0d0,visit:'',ccdnum:0L,flags:bytarr(9),deblend_nchild:0L,$
    ;       base_gaussiancentroid_x:0.0d0,base_gaussiancentroid_y:0.0d0,base_sdssshape_xx:0.0d0,base_sdssshape_yy:0.0d0,$
    ;         base_sdssshape_xy:0.0d0,base_psfflux_flux:0.0d0, base_psfflux_fluxsigma:0.0d0,mag:0.0d0,magerr:0.0d0,cmbindx:-1LL}
    newsep = replicate(allsrc_schema,nstr)
    struct_assign,str,newsep
    newsep.fstrid = i
    newsep.visit = chstr[i].visit
    newsep.ccdnum = chstr[i].ccdnum
    ; Use PSF flux
    if not keyword_set(useaper) then begin
      flux = newsep.base_psfflux_flux
      fluxsigma = newsep.base_psfflux_fluxsigma
    endif else begin
      flux = newsep.base_circularapertureflux_12_0_flux
      fluxsigma = newsep.base_circularapertureflux_12_0_fluxsigma
    endelse
    negflux = where(flux lt 0,nnegflux,comp=posflux,ncomp=nposflux)
    if nposflux gt 0 then begin
      ; convert to mag
      newsep[posflux].mag = -2.5*alog10(flux[posflux]/chstr[i].fluxmag0)
      ; err_mag = (2.5/ln10) * err_flux/flux 
      newsep[posflux].magerr = (2.5/alog(10))*(fluxsigma[posflux]/flux[posflux])
    endif
    if nnegflux gt 0 then begin
      newsep[negflux].mag = !values.f_nan
      newsep[negflux].magerr = !values.f_nan
    endif
    nnewsep = n_elements(newsep)

    ; Load the calexp header
    calexpfile = chstr[i].calexpfile
    head0 = headfits(calexpfile,exten=0)
    head1 = headfits(calexpfile,exten=1)

    chstr[i].sepallindx = cur_sepall_indx

    ; Get astrometric vertices from header
    nx = sxpar(head1,'NAXIS1')
    ny = sxpar(head1,'NAXIS2')
    head_xyad,head1,[0,nx-1,nx-1,0],[0,0,ny-1,ny-1],vra,vdec,/degree
    chstr[i].vertices_ra = vra
    chstr[i].vertices_dec = vdec

    ; Add new elements to ALLSRC
    if nallsrc lt cur_sepall_indx+nnewsep then begin
      print,'Adding new elements to ALLSRC'
      new = replicate(allsrc_schema,nallsrc+5000000L)  ; add another 5 million elements
      new[0:nallsrc-1] = allsrc
      allsrc = new
      undefine,new
      nallsrc = n_elements(allsrc)  
    endif

    ; Add to ALLSRC structure
    allsrc[cur_sepall_indx:cur_sepall_indx+nnewsep-1] = newsep

    ; Increment index
    cur_sepall_indx += nnewsep

    print,i+1,chstr[i].visit,chstr[i].ccdnum,nnewsep,format='(I5,A12,I5,I10)'

    ;stop

  endfor ; chstr loop

  ; Pruning extra ALLSRC elements
  if nallsrc gt cur_sepall_indx then allsrc = allsrc[0:cur_sepall_indx-1]

  ; Save the output file
  print,'Saving to ',chstrfile
  MWRFITS,chstr,chstrfile,/create,/silent
  print,'Saving to ',allsrcfile
  MWRFITS,allsrc,allsrcfile,/create,/silent

; Loading previously saved files
Endif else begin

  print,'Loading previously saved files'
  print,chstrfile
  chstr = MRDFITS(chstrfile,1,/silent)
  print,allsrcfile
  allsrc = MRDFITS(allsrcfile,1,/silent)
Endelse

;stop

end
