pro lsst_processccddecam_qa,datarepodir,visit,ccdnum,qastr

; This makes QA plots for a single processCcdDecam output file visit/ccdnum

thisprog = 'processCcdDecam'
  
; Plot directory
plotdir = datarepodir+'/'+visit+'/plots/'
if file_test(plotdir,/directory) eq 0 then file_mkdir,plotdir  

; QA structure filename
qadir = datarepodir+'/'+visit+'/qa/'
if file_test(qadir,/directory) eq 0 then file_mkdir,qadir
qafile = qadir+thisprog+'QA-'+visit+'_'+ccdnum+'.fits'
if file_test(qafile) then file_delete,qafile,/allow  ; erase old version

; Initialize the QA structure
qastr = {datarepodir:'',visit:'',ccdnum:'',runtimestamp:-1LL,scriptfile:'',logfile:'',userconfigfile:'',finalconfigfile:'',$
         success:0,duration:-1.0,ra:-1.0d0,dec:-1.0d0,dateobs:'',airmass:'',$
         filter:'',exptime:-1.0,fwhm:-1.0,fluxmag0:-1.0,calexpfile:'',nx:-1L,ny:-1L,$
         medbackground:-1.0,sigbackground:-1.0,srcfile:'',nsources:-1L,calexp_plotfile:'',src_plotfile:'',$
         initpsffwhm:-1.0,npsfstars_selected:-1L,npsfstars_used:-1L,ncosmicrays:-1L,wcsrms:-1.0,ndetected:-1L,ndeblended:-1L}
qastr.datarepodir = datarepodir
qastr.visit = visit[0]
qastr.ccdnum = ccdnum[0]
scriptfile = datarepodir+'/'+visit+'/calexp/processCcdDecam-'+visit+'_'+ccdnum+'.sh'
logfile = datarepodir+'/'+visit+'/calexp/processCcdDecam-'+visit+'_'+ccdnum+'.sh.log'
if file_test(scriptfile) then begin
  qastr.scriptfile=scriptfile
  scriptinfo = file_info(scriptfile)
  qastr.runtimestamp = scriptinfo.mtime
endif
if file_test(logfile) then qastr.logfile=logfile
; duration in sec
if file_test(scriptfile) and file_test(logfile) then begin
  scriptinfo = file_info(scriptfile)
  loginfo = file_info(logfile)
  duration = loginfo.mtime-scriptinfo.mtime  ; duration = logfile mod time - script mod time
  qastr.duration = duration
endif
  
;------------------------------------
; Making a plot of the calexp image
;------------------------------------

calexpfile = datarepodir+'/'+visit+'/calexp/calexp-'+visit+'_'+ccdnum+'.fits'
if file_test(calexpfile) then begin
   
  ; Load the file
  head0 = headfits(calexpfile,exten=0)
  fits_read,calexpfile,image,imhead,exten=1
  fits_read,calexpfile,mask,maskhead,exten=2
  fits_read,calexpfile,varim,varhead,exten=3

  ; Put info into qastr
  qastr.calexpfile = calexpfile
  qastr.success = 1 
  ; other metrics, median image value, sigma image
  ;  Ngoodpixels, Nbadpixels
  qastr.ra = sxpar(imhead,'crval1') ; this is NOT necessarily the center
  qastr.dec = sxpar(imhead,'crval2') ; this is NOT necessarily the center
  qastr.dateobs = sxpar(imhead,'date')
  ;qastr.airmass = sxpar(head,'airmass')  ; not found
  qastr.filter = strtrim(sxpar(imhead,'filter'),2)
  qastr.exptime = sxpar(imhead,'exptime')
  qastr.fwhm = sxpar(imhead,'fwhm')
  qastr.fluxmag0 = sxpar(imhead,'fluxmag0')
  qastr.nx = sxpar(imhead,'naxis1')
  qastr.ny = sxpar(imhead,'naxis2')
  qastr.medbackground = median(image) ; use "good" pixels only
  qastr.sigbackground = mad(image)
  
  ; for PNGs using the Z-buffer
  linethick = 1.8
  thick = 3.0
  charsize = 3.0 ;0.9
  charthick = 5.0 ;1.6
  set_plot,'z'
  device,set_pixel_depth=24,decomposed=0
  !p.font = 0
  loadct,39,/silent
  bgcolor = 255
  erase,bgcolor
  xsize = 650 ;725
  ysize = 900 ;350
  pbin =  3 ;1 ;2
  device,set_resolution=[xsize*pbin,ysize*pbin]
  color = 0
  ;cogreen = fsc_color('green',5)
  dotlstyle = 2
  dashlstyle = 5

  displayc,float(image),xtit='X (pixels)',ytit='Y (pixels)',tit=file_basename(calexpfile),$
           charsize=charsize,charthick=charthick,thick=thick,/z,background_color=bgcolor,framecolor=color
  ; maybe overplot some metrics, median, sigma of the "good" pixels
  
  ; post plotting
  bim = tvrd(/true)
  bim2 = REBIN(bim,3,xsize,ysize)
  pngfile1 = plotdir+'calexp-'+visit+'_'+ccdnum+'.png'
  WRITE_PNG,pngfile1,bim2

  qastr.calexp_plotfile = pngfile1
  
endif else pngfile1=''          ; calexp image


;-------------------------------
; Making a plot of the sources
;-------------------------------

srcfile = datarepodir+'/'+visit+'/src/src-'+visit+'_'+ccdnum+'.fits'
if file_test(srcfile) then begin

  str = mrdfits(srcfile,1)

  ; Put info into qastr
  qastr.srcfile = srcfile
  ; other metrics, median S/N, peak histogram value, Nsources, etc.
  qastr.nsources = n_elements(str)
  
  ; for PNGs using the Z-buffer
  linethick = 1.8
  thick = 3.0
  charsize = 3.0
  charthick = 5.0
  set_plot,'z'
  device,set_pixel_depth=24,decomposed=0
  loadct,39,/silent
  bgcolor = 255
  erase,bgcolor
  xsize = 650
  ysize = 650
  pbin =  3 ;1 ;2
  device,set_resolution=[xsize*pbin,ysize*pbin]
  color = 0

  !p.background = bgcolor
  plot,str.base_psfflux_flux,str.base_psfflux_fluxsigma,ps=1,xtit='BASE_PSFFLUX_FLUX',ytit='BASE_PSFFLUX_FLUXSIGMA',$
       tit=file_basename(srcfile),color=0,charsize=charsize,charthick=charthick,thick=thick
  
  ; post plotting
  bim = tvrd(/true)
  bim2 = REBIN(bim,3,xsize,ysize)
  pngfile2 = plotdir+'src-'+visit+'_'+ccdnum+'_psffluxerror.png'
  WRITE_PNG,pngfile2,bim2

  qastr.src_plotfile = pngfile2
  
endif else pngfile2=''    ; scatter plot

set_plot,'x'

; Grab information from the logfile, astrometric accuracy/scatter, etc.
if file_test(logfile) then begin

  LSST_READLINE,logfile,loglines,comment='#',count=nloglines

  ; processCcdDecam.calibrate: installInitialPsf fwhm=7.62377514116 pixels; size=15 pixels
  initpsfind = where(stregex(loglines,'^processCcdDecam.calibrate: installInitialPsf ',/boolean) eq 1,ninitpsf)
  if ninitpsf gt 0 then begin
    line1 = loglines[initpsfind[0]]
    lo = strpos(line1,'fwhm=')
    hi = strpos(line1,'pixels;') 
    initpsffwhm = float(strmid(line1,lo+5,hi-lo-6))
    qastr.initpsffwhm = initpsffwhm
  endif
  ; processCcdDecam.calibrate.measurePsf: PSF star selector found 98 candidates
  psfstarselectedind = where(stregex(loglines,'^processCcdDecam.calibrate.measurePsf: PSF star selector',/boolean) eq 1,npsfstarselected)
  if npsfstarselected gt 0 then begin
    line1 = loglines[psfstarselectedind[0]]
    lo = strpos(line1,'found ')
    hi = strpos(line1,'candidates') 
    npsfstars_selected = long(strmid(line1,lo+6,hi-lo-7))
    qastr.npsfstars_selected = npsfstars_selected
  endif
  ; processCcdDecam.calibrate.measurePsf: PSF determination using 67/98 stars.
  psfstarsusedind = where(stregex(loglines,'^processCcdDecam.calibrate.measurePsf: PSF determination using',/boolean) eq 1,npsfstarsused)
  if npsfstarsused gt 0 then begin
    line1 = loglines[psfstarsusedind[0]]
    dum = strsplit(line1,' ',/extract)
    lo = strpos(line1,'using ')
    hi = strpos(line1,'stars') 
    dum = strmid(line1,lo+6,hi-lo-7)
    psfstarsused = long( (strsplit(dum,'/',/extract))[0] )
    qastr.npsfstars_used = psfstarsused
  endif
  ; processCcdDecam.calibrate.repair: Identified 62 cosmic rays.
  cosmicraysind = where(stregex(loglines,'^processCcdDecam.calibrate.repair: Identified ',/boolean) eq 1 and $
                     stregex(loglines,'cosmic rays',/boolean) eq 1,ncosmicraysind)
  if ncosmicraysind gt 0 then begin
    line1 = loglines[cosmicraysind[0]]  ; there normally are two
    dum = strsplit(line1,' ',/extract)
    lo = strpos(line1,'Identified')
    hi = strpos(line1,'cosmic rays') 
    ncosmicrays = long(strmid(line1,lo+11,hi-lo-12))
    qastr.ncosmicrays = ncosmicrays
  endif
  ; processCcdDecam.calibrate.astrometry: Matched and fit WCS in 3 iterations; found 27 matches with scatter = 0.240 +- 0.129 arcsec
  wcsrmsind = where(stregex(loglines,'^processCcdDecam.calibrate.astrometry: Matched and fit WCS',/boolean) eq 1,nwcsrmsind)
  if nwcsrmsind gt 0 then begin
    line1 = loglines[wcsrmsind[0]]  ; there are normally two of these
    dum = strsplit(line1,' ',/extract)
    lo = strpos(line1,'scatter = ')
    hi = strpos(line1,'+-') 
    wcsrms = float(strmid(line1,lo+10,hi-lo-11))
    qastr.wcsrms = wcsrms
  endif
  ; processCcdDecam.detection: Detected 3462 positive sources to 5 sigma.
  ndetectedind = where(stregex(loglines,'^processCcdDecam.detection: Detected ',/boolean) eq 1,ndetectedind)
  if ndetectedind gt 0 then begin
    line1 = loglines[ndetectedind[0]]
    dum = strsplit(line1,' ',/extract)
    lo = strpos(line1,'Detected')
    hi = strpos(line1,'positive') 
    ndetected = long(strmid(line1,lo+9,hi-lo-10))
    qastr.ndetected = ndetected
  endif
  ; processCcdDecam.deblend: Deblended: of 3462 sources, 435 were deblended, creating 1850 children, total 5312 sources
  deblendind = where(stregex(loglines,'^processCcdDecam.deblend: Deblended: ',/boolean) eq 1,ndeblendind)
  if ndeblendind gt 0 then begin
    line1 = loglines[deblendind[0]]
    dum = strsplit(line1,' ',/extract)
    lo = strpos(line1,'sources,')
    hi = strpos(line1,'were deblended') 
    ndeblended = long(strmid(line1,lo+9,hi-lo-10))
    qastr.ndeblended = ndeblended
  endif
  
endif   

; Save qastr
print,'Saving QA structure to ',qafile
mwrfits,qastr,qafile,/create

;stop

end
