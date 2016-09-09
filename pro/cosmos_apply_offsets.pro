pro cosmos_apply_offsets,chstr,ubercalstr,allsrc

nchstr = n_elements(chstr)
for i=0,nchstr-1 do begin
  allind = lindgen(chstr[i].nsrc)+chstr[i].sepallindx
  allsrc[allind].mag += ubercalstr[i].magoff
  ;allsrc[allind].mag -= ubercalstr[i].magoff
endfor

;stop

end
