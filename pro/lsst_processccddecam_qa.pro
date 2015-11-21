pro lsst_processccddecam_qa,datarepodir,visit,ccdnum,qastr

; This makes QA plots for a single processCcdDecam output file visit/ccdnum

plotdir = datarepodir+'/'+visit+'/plots/'
if file_test(plotdir,/directory) eq 0 then file_mkdir,plotdir  

; Initialize the QA structure
qastr = {datarepodir:'',visit:'',ccdnum:'',scriptfile:'',logfile:'',success:0,duration:0.0,ra:0.0,dec:0.0,dateobs:'',airmass:'',$
                     filter:'',exptime:0.0,fwhm:0.0,fluxmag0:0.0,calexpfile:'',nx:0L,ny:0L,$
                     medbackground:0.0,sigbackground:0.0,srcfile:'',nsources:0L,calexp_plotfile:'',src_plotfile:''}
qastr.datarepodir = datarepodir
qastr.visit = visit[0]
qastr.ccdnum = ccdnum[0]
scriptfile = datarepodir+'/'+visit+'/calexp/processCcdDecam-'+visit+'_'+ccdnum+'.sh'
logfile = datarepodir+'/'+visit+'/calexp/processCcdDecam-'+visit+'_'+ccdnum+'.sh.log'
if file_test(scriptfile) then qastr.scriptfile=scriptfile
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

; Save qastr
qadir = datarepodir+'/'+visit+'/qa/'
if file_test(qadir,/directory) eq 0 then file_mkdir,qadir
qafile = qadir+'qa-'+visit+'_'+ccdnum+'.fits'
print,'Saving QA structure to ',qafile
mwrfits,qastr,qafile,/create

;stop

end
