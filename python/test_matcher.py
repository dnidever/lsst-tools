#!/usr/bin/env python

# call this like: % python test_matcher.py

repodir = "/data/lsst/decam/redux/cp/cosmos/"
visitid = 177341
ccdnum = 15

import lsst.afw.image as afwImage
import lsst.afw.table as afwTable
import lsst.daf.persistence as dafPersist
import lsst.meas.astrom as measAstrom
import math
import numpy as np

def runMatcher(repodir,visitid,ccdnum,offset):

    butler = dafPersist.Butler(repodir)
    exp = butler.get('calexp',visit=visitid,ccdnum=ccdnum)
    wcs = exp.getWcs()
    sourceCat = butler.get('src',visit=visitid,ccdnum=ccdnum)

    config = measAstrom.LoadAstrometryNetObjectsTask.ConfigClass()
    loadANetObj = measAstrom.LoadAstrometryNetObjectsTask(config=config)
    loadRes = loadANetObj.loadPixelBox(bbox = exp.getBBox(),wcs = exp.getWcs(),filterName = exp.getFilter().getName(),calib = exp.getCalib())
    refCat = loadRes.refCat

    match = measAstrom.MatchOptimisticBTask()
    #matchRes = match.matchObjectsToSources(refCat=loadRes.refCat, sourceCat=sourceCat, wcs=wcs, refFluxField=loadRes.fluxField, maxMatchDist=None)
    # THIS WORKS!!

    # add constant to the source catalog, remember the coords are in RADIANS
    #off = 1.0
    #sourceCat["coord_ra"][:] += math.radians(off/ 3600.0)
    #sourceCat["coord_dec"][:] += math.radians(off / 3600.0)
    # matchOptimisticB does NOT use RA/DEC, it uses X/Y and WCS, offset in pixels
    # fail: 320, 350, 400, 500
    # success: 200, 300
    #offset = 200.0

    print "Offset = ", offset, " pixels"
    sourceCat["slot_Centroid_x"][:] += offset
    sourceCat["slot_Centroid_y"][:] += offset

    # This does NOT work.  Get a "Record data is not contiguous in memory." error
    #print "Offset = ", offset, " arcsec"
    #refCat["coord_ra"][:] += math.radians(offset/3600.)
    #refCat["coord_dec"][:] += math.radians(offset/3600.)

    try:
        matchRes = match.matchObjectsToSources(refCat=loadRes.refCat, sourceCat=sourceCat, wcs=wcs, refFluxField=loadRes.fluxField, maxMatchDist=None)
        matches = len(matchRes.matches)
        print "Success"
    except:
        print "Failure"
        matches = 0

    print "Matches = ", matches
 
    return matches
   
#---- using middle-level matching ----
#verbose = True
#mc = measAstrom.MatchOptimisticBConfig()
#sourceInfo = measAstrom.MatchOptimisticBTask.SourceInfoClass(schema=sourceCat.schema, fluxType=matchconfig.sourceFluxType)
#usableSourceCat = sourceCat
#numUsableSources = len(sourceCat)
#usableMatches = match._doMatch(refCat=refCat, sourceCat=usableSourceCat, wcs=wcs, refFluxField=loadRes.fluxField, numUsableSources=numUsableSources, minMatchedPairs=mc.minMatchedPairs, maxMatchDist=mc.maxMatchDistArcSec, sourceInfo=sourceInfo, verbose=verbose)
# THIS STILL DOESN'T WORK!!
#
#----- using the lowest-level matching program -----
#matchconfig = measAstrom.MatchOptimisticBConfig()
#sourceInfo = measAstrom.MatchOptimisticBTask.SourceInfoClass(schema=sourceCat.schema, fluxType=matchconfig.sourceFluxType)
#
#matchControl = measAstrom.MatchOptimisticBControl()
#matchControl.refFluxField = loadRes.fluxField
#matchControl.sourceFluxField = sourceInfo.fluxField
#matchControl.numBrightStars = matchconfig.numBrightStars
#matchControl.minMatchedPairs = matchconfig.minMatchedPairs
#matchControl.maxOffsetPix = matchconfig.maxOffsetPix
#matchControl.numPointsForShape = matchconfig.numPointsForShape
#matchControl.maxDeterminant = matchconfig.maxDeterminant
#
#numSources = len(sourceCat)
#posRefBegInd = 0
##posRefBegInd = numUsableSources - numSources
#verbose = True
#matches = measAstrom.matchOptimisticB(refCat, sourceCat, matchControl, wcs, posRefBegInd, verbose)
## THIS ALSO WORKS!
##-----


#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Test the matchOptimisticB matcher")

    parser.add_argument('--datarepo', '-d', action="store_true", help="The data repository directory", default="/data/lsst/decam/redux/cp/cosmos/")
    parser.add_argument('--visitid', '-v', action="store_true", help="The visit ID", default=177341)
    parser.add_argument('--ccdnum', '-c', action="store_true", help="The CCD number", default=15)

    args = parser.parse_args()

    #if args.debug:
    #    try:
    #        import debug
    #    except ImportError as e:
    #        print >> sys.stderr, e

    #repodir = "/data/lsst/decam/redux/cp/cosmos/"
    #visitid = 177341
    #ccdnum = 15
    #offset = 200

# use numpy structured arrays
    dt = np.dtype([('offset',float),('nmatches',int)])
    str = np.empty(20,dtype=dt)

    #matches = []
    for i in xrange(20):
        #matches.append(runMatcher(args.datarepo,args.visitid,args.ccdnum,i*20))
        nmatches = runMatcher(args.datarepo,args.visitid,args.ccdnum,i*20)
        str['offset'][i] = i*20
        str['nmatches'][i] = nmatches

    #print matches
    print str
