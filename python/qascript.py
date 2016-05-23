#!/usr/bin/env python

# call this like: % python test_matcher.py

#repodir = "/data/lsst/decam/redux/cp/cosmos/"
#visitid = 177341
#ccdnum = 15

import lsst.afw.image as afwImage
import lsst.afw.table as afwTable
import lsst.afw.geom as afwGeom
import lsst.daf.persistence as dafPersist
import lsst.meas.astrom as measAstrom
import math
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.image as mpimg

def mad(arr):
    """ Median Absolute Deviation: a "Robust" version of standard deviation.
        Indices variabililty of the sample.
        https://en.wikipedia.org/wiki/Median_absolute_deviation 
        It needs to be scaled by 1.4826x to be on the same "scale" as std. dev.
    """
    med = np.median(arr)
    return 1.4826*np.median(np.abs(arr - med))

#def getqainfo(repodir,visitid,ccdnum):
def getqainfo(dataref):

    #butler = dataRef.butlerSubset.butler
    #butler = dafPersist.Butler(repodir)
    #exp = butler.get('calexp',visit=visitid,ccdnum=ccdnum)

    # Start the structure
    dt = np.dtype([('visit',int),('ccdnum',int),('calexp_exists',bool),('background_exists',bool),('src_exists',bool),('metadata_exists',bool),
                   ('icsrc_exists',bool),('icmatch_exists',bool),('psf_exists',bool),('wcs_exists',bool),
                   ('ra',float),('dec',float),('filter',np.str_,1),('datetime',np.str_,30),('nx',int),('ny',int),('exptime',float),('ncrpix',int),
                   ('fluxmag0',float),('fluxmag0sigma',float),
                   ('calexp_bgmean',float),('calexp_bgvar',float),('calexp_bgmean2',float),('calexp_bgvar2',float),('calexp_magzero',float),
                   ('calexp_magzero_rms',float),('calexp_magzero_nobj',int),('calexp_colorterm1',float),('calexp_colorterm2',float),('calexp_colorterm3',float),
                   ('apcorr_exists',bool),('apcorr_med',float),('apcorr_std',float),
                   ('ixx',float),('iyy',float),('ixy',float),('semimajor_pix',float),('semiminor_pix',float),('pa_pix',float),
                   ('ellipticity_pix',float),('semimajor_arcsec',float),('semiminor_arcsec',float),
                   ('pa_arcsec',float),('ellipticity_arcsec',float),('nsources',int),('bkgdmed',float),('bkgdsig',float),
                   ('measurePsf_numAvailStars',int),('measurePsf_numGoodStars',int),('measurePsf_spatialFitChi2',float),
                   ('detection_sigma',float),('detection_nGrow',int),('detection_doSmooth',bool),
                   ('detection_smoothingKernelWidth',int),
                   ('metadata_processccd_exists',bool),('metadata_processccd_calibrate_exists',bool),('metadata_processccd_calibrate_astrometry_exists',bool),
                   ('metadata_processccd_calibrate_astrometry_matcher_exists',bool),('metadata_processccd_calibrate_astrometry_refobjloader_exists',bool),
                   ('metadata_processccd_calibrate_astrometry_wcsfitter_exists',bool),('metadata_processccd_calibrate_detection_exists',bool),
                   ('metadata_processccd_calibrate_measurepsf_exists',bool),('metadata_processccd_calibrate_photocal_exists',bool),
                   ('metadata_processccd_calibrate_repair_exists',bool),('metadata_processccd_deblend_exists',bool),('metadata_processccd_detection_exists',bool)])

    #data = np.empty(1,dtype=dt)
    data = np.zeros(1,dtype=dt)

    visit = dataref.dataId['visit']
    ccdnum = dataref.dataId['ccdnum']
    data['visit'] = visit
    data['ccdnum'] = ccdnum

    # Check if the files/products exist
    data['calexp_exists'] = dataref.datasetExists('calexp')
    data['background_exists'] = dataref.datasetExists('calexpBackground')
    data['src_exists'] = dataref.datasetExists('src')
    data['metadata_exists'] = dataref.datasetExists('processCcdDecam_metadata')
    data['icsrc_exists'] = dataref.datasetExists('icSrc')
    data['icmatch_exists'] = dataref.datasetExists('icMatch')

    # Load the exposure
    if data['calexp_exists']:
        exp = dataref.get('calexp')
        mask = exp.getMaskedImage().getMask()
        data['wcs_exists'] = exp.hasWcs()
        wcs = exp.getWcs()
        calib = exp.getCalib()
        data['psf_exists'] = exp.hasPsf()
        psf = exp.getPsf()
        shape = psf.computeShape()

        # Chip/Exposure level information
        filt = exp.getFilter().getName()
        exptime = calib.getExptime()
        fluxmag0 = calib.getFluxMag0()
        datetime = calib.getMidTime()
        data['filter'] = filt
        data['exptime'] = exptime
        data['fluxmag0'] = fluxmag0[0]
        data['fluxmag0sigma'] = fluxmag0[1]
        data['datetime'] = datetime.toString()[0:30]  # can only be 30 char long

        # Get calexp metadata
        calexp_meta = exp.getMetadata()
        calexp_meta_names = ['BGMEAN','BGVAR','BGMEAN2','BGVAR2','MAGZERO','MAGZERO_RMS','MAGZERO_NOBJ','COLORTERM1','COLORTERM2','COLORTERM3']
        for name in calexp_meta_names:
            if calexp_meta.exists(name):
                data['calexp_'+name.lower()] = calexp_meta.get(name)

        # Size of the image
        nx = exp.getWidth()
        ny = exp.getHeight()
        data['nx'] = nx
        data['ny'] = ny

        # Central coordinates
        cen = wcs.pixelToSky(nx/2,ny/2)
        ra = cen.getLongitude().asDegrees()
        dec = cen.getLatitude().asDegrees()
        data['ra'] = ra
        data['dec'] = dec

        # Get aperture correction
        info = exp.getInfo()
        data['apcorr_exists'] = info.hasApCorrMap()
        if data['apcorr_exists']:
            apcorr = info.getApCorrMap()
            apcorr_psfflux = apcorr.get('base_PsfFlux_flux')
            # fill the entire image, THIS IS SLOW!! sample the data instead
            apcorr_im = exp.getMaskedImage().getImage()  # initialize with flux image
            apcorr_psfflux.fillImage(apcorr_im)
            # sample the area
            apcorr_med = np.median(apcorr_im.getArray())
            apcorr_std = np.std(apcorr_im.getArray())
            data['apcorr_med'] = apcorr_med
            data['apcorr_std'] = apcorr_std

        # Get shape parameters
        ixx = shape.getIxx()
        iyy = shape.getIyy()
        ixy = shape.getIxy()
        data['ixx'] = ixx
        data['iyy'] = iyy
        data['ixy'] = ixy

        # Get ellipticity and PA
        axes = afwGeom.ellipses.Axes(shape)
        pa_pix = axes.getTheta() * 180 / math.pi  # CCW from x-axis on pixel-grid
        semimajor_pix = axes.getA()
        semiminor_pix = axes.getB()
        ellipticity_pix = (semimajor_pix-semiminor_pix)/(semimajor_pix+semiminor_pix)
        data['semimajor_pix'] = semimajor_pix
        data['semiminor_pix'] = semiminor_pix
        data['pa_pix'] = pa_pix
        data['ellipticity_pix'] = ellipticity_pix

        # Transform ellipse to on sky
        point = afwGeom.Point2D(nx/2, ny/2)
        local_transform = wcs.linearizePixelToSky(point, afwGeom.arcseconds) # or whatever angle unit you want for radii; PA is always radians
        pixel_ellipse = afwGeom.ellipses.Axes(psf.computeShape(point))
        sky_ellipse = pixel_ellipse.transform(local_transform.getLinear())
        pa_arcsec = sky_ellipse.getTheta() * 180 / math.pi  # east of north???
        semimajor_arcsec = sky_ellipse.getA()
        semiminor_arcsec = sky_ellipse.getB()
        ellipticity_arcsec = (semimajor_arcsec-semiminor_arcsec)/(semimajor_arcsec+semiminor_arcsec)
        data['semimajor_arcsec'] = semimajor_arcsec
        data['semiminor_arcsec'] = semiminor_arcsec
        data['pa_arcsec'] = pa_arcsec
        data['ellipticity_arcsec'] = ellipticity_arcsec

        # Number of CR pixels,  I don't know what bit it is
        #threshold = 16 
        # is there a better way of selecting "CR" pixels than this??
        #cr = np.bitwise_and(np.int16(mask.getArray()),threshold) == threshold
        crBit = mask.getPlaneBitMask('CR')    
        crmask = (mask.getArray() & crBit) == crBit
        ncrpix = crmask.sum()
        data['ncrpix'] = ncrpix

    # No calexp, try to get basic info from raw or instcal
    else:
        # Try to load raw or instcal
        try:
            raw = dataref.get('raw')
        except:
            try:
                instcal = dataref.get('instcal') 
                calib = instcal.getCalib()

                # Chip/Exposure level information
                filt = instcal.getFilter().getName()
                exptime = calib.getExptime()
                datetime = calib.getMidTime()
                data['filter'] = filt
                data['exptime'] = exptime
                data['datetime'] = datetime.toString()[0:30]  # can only be 30 char long

                # Size of the image
                nx = instcal.getWidth()
                ny = instcal.getHeight()
                data['nx'] = nx
                data['ny'] = ny

                # Central coordinates
                wcs = instcal.getWcs()
                cen = wcs.pixelToSky(nx/2,ny/2)
                ra = cen.getLongitude().asDegrees()
                dec = cen.getLatitude().asDegrees()
                data['ra'] = ra
                data['dec'] = dec
            except:
                pass

    # Load the source catalog
    if data['src_exists']:
        src = dataref.get('src')
        nsources = len(src)
        data['nsources'] = nsources
    
    # Background level
    if data['background_exists']:
        backgrounds = dataref.get('calexpBackground')
        bkgdimage = backgrounds.getImage()    
        bkgdmed = np.median(bkgdimage.getArray())
        bkgdsig = mad(bkgdimage.getArray())
        data['bkgdmed'] = bkgdmed
        data['bkgdsig'] = bkgdsig

    # Getting metadata
    if dataref.datasetExists('processCcdDecam_metadata'):
        try:
            meta = dataref.get('processCcdDecam_metadata')

            # check for the existence of various entries in the metadata
            data['metadata_processccd_exists'] = meta.exists('processCcdDecam')
            data['metadata_processccd_calibrate_exists'] = meta.exists('processCcdDecam:calibrate')
            data['metadata_processccd_calibrate_astrometry_exists'] = meta.exists('processCcdDecam:calibrate:astrometry')
            data['metadata_processccd_calibrate_astrometry_matcher_exists'] = meta.exists('processCcdDecam:calibrate:astrometry:matcher')
            data['metadata_processccd_calibrate_astrometry_refobjloader_exists'] = meta.exists('processCcdDecam:calibrate:astrometry:refObjLoader')
            data['metadata_processccd_calibrate_astrometry_wcsfitter_exists'] = meta.exists('processCcdDecam:calibrate:astrometry:wcsFitter')
            data['metadata_processccd_calibrate_detection_exists'] = meta.exists('processCcdDecam:calibrate:detection')
            data['metadata_processccd_calibrate_measurepsf_exists'] = meta.exists('processCcdDecam:calibrate:measurePsf')
            data['metadata_processccd_calibrate_photocal_exists'] = meta.exists('processCcdDecam:calibrate:photocal')
            data['metadata_processccd_calibrate_repair_exists'] = meta.exists('processCcdDecam:calibrate:repair')
            data['metadata_processccd_deblend_exists'] = meta.exists('processCcdDecam:deblend')
            data['metadata_processccd_detection_exists'] = meta.exists('processCcdDecam:detection')

            # PSF values
            if data['metadata_processccd_calibrate_measurepsf_exists']:
                meta_measurePsf = meta.get('processCcdDecam:calibrate:measurePsf')
                numAvailStars = meta_measurePsf.get('numAvailStars')
                numGoodStars = meta_measurePsf.get('numGoodStars')
                spatialFitChi2 = meta_measurePsf.get('spatialFitChi2')
                data['measurePsf_numAvailStars'] = numAvailStars
                data['measurePsf_numGoodStars'] = numGoodStars
                data['measurePsf_spatialFitChi2'] = spatialFitChi2

            # Detection information
            if data['metadata_processccd_detection_exists']:
                meta_det = meta.get('processCcdDecam:detection')
                sigma = meta_det.get('sigma')
                doSmooth = meta_det.get('doSmooth')
                nGrow = meta_det.get('nGrow')
                smoothingKernelWidth = meta_det.get('smoothingKernelWidth')
                data['detection_sigma'] = sigma
                data['detection_doSmooth'] = doSmooth
                data['detection_nGrow'] = nGrow
                data['detection_smoothingKernelWidth'] = smoothingKernelWidth

        except:
            print "Error loading metadata for ",visit,ccdnum

    return data


#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Get QA metric data for a calexp data.")

    parser.add_argument('--datarepo', '-d', action="store", help="The data repository directory", default="/data/lsst/decam/redux/cp/cosmos/")
    parser.add_argument('--outfile', '-o', action="store", help="The output filename for the metrics.", default="qametrics.csv")
    parser.add_argument('--verbose', '-v', action="store_true", help="Print out the data as it is gathered.", default=False)

    args = parser.parse_args()

    print "Getting QA metric data for ", args.datarepo

    # Get all the data IDs
    butler = dafPersist.Butler(args.datarepo)
 
    # Get the total number of dataIds that EXIST
    #ndata=0
    #for dataref in butler.subset(datasetType='calexp'):
    #    if dataref.datasetExists(): # processCcd did not fail
    #        ndata = ndata+1
    ndata = len(butler.subset(datasetType='calexp'))
    print ndata, "calexps"

    count = 0
    for dataref in butler.subset(datasetType='calexp'):
        #if dataref.datasetExists(): # processCcd did not fail
        data1 = getqainfo(dataref)
        # Create the structured array for all calexps
        if count == 0:
            dt = data1.dtype
            data = np.empty(ndata,dtype=dt)
        # Stuff in the data for THIS calexp
        data[count] = data1
        # Print out the information
        if args.verbose:
            print count, data1[0]
        count = count+1

    # output to csv file
    print "Writing outputs to", args.outfile
    data.tofile(args.outfile,sep='\n')

    # Add header line
    f = open(args.outfile,'r')  # read it all back in first
    temp = f.read()
    f.close()
    #  now write out with header line
    f = open(args.outfile, 'w')
    f.write(str(dt.names)+'\n')
    f.write(temp)
    f.close()
