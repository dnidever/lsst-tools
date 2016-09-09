pro cosmos_plots,final,sepall

; Make plots of the cosmos data

if n_elements(final) eq 0 or n_elements(sepall) eq 0 then begin
  print,'Restoring the data'
  restore,'combine_exp_catalogs.dat'
endif

setdisp
!p.font = 0

; Density of sources on the sky
ps_open,'sky_density',/color,thick=4,/encap
hess,final.coord_ra,final.coord_dec,dx=0.01,dy=0.01,xtit='RA',ytit='DEC',tit='Density of COSMOS processCcdDecam sources'
ps_close
ps2jpg,'sky_density.eps',/eps

ps_open,'sky_density_log',/color,thick=4,/encap
hess,final.coord_ra,final.coord_dec,dx=0.01,dy=0.01,xtit='RA',ytit='DEC',tit='Density of COSMOS processCcdDecam sources (log scale)',/log
ps_close
ps2jpg,'sky_density_log.eps',/eps

; I need the exposure metadata, filters, exptime, etc.
; how to convert flux in the source catalog to magnitudes

; CMD?

; photometric scatter

; astrometric scatter

stop

end
