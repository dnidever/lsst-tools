#!/usr/bin/env python

import sys, os, re
import argparse
#import matplotlib.pyplot as pyplot

import lsst.daf.persistence  as dafPersist
import lsst.afw.cameraGeom   as camGeom
import lsst.afw.coord        as afwCoord
import lsst.afw.geom         as afwGeom
import lsst.afw.image        as afwImage
import math
import numpy as np

def bboxToRaDec(bbox, wcs):
    """Get the corners of a BBox and convert them to lists of RA and Dec."""
    corners = []
    for corner in bbox.getCorners():
        p = afwGeom.Point2D(corner.getX(), corner.getY())
        coord = wcs.pixelToSky(p).toIcrs()
        corners.append([coord.getRa().asDegrees(), coord.getDec().asDegrees()])
    ra, dec = zip(*corners)
    return ra, dec

def percent(values, p=0.5):
    """Return a value a faction of the way between the min and max values in a list."""
    m = min(values)
    interval = max(values) - m
    return m + p*interval

def doPolygonsOverlap(xPolygon1, yPolygon1, xPolygon2, yPolygon2):
    """Returns True if two polygons are overlapping."""

    # How to determine if two polygons overlap.
    # If a vertex of one of the polygons is inside the other polygon
    # then they overlap.
    
    n = len(xPolygon2)
    isin = False

    # Loop through all vertices of second polygon
    for i in range(n):
        # perform iterative boolean OR
        # if any point is inside the polygon then they overlap   
        isin = isin or isPointInPolygon(xPolygon1, yPolygon1, xPolygon2[i], yPolygon2[i])

    return isin

def isLeft(x1, y1, x2, y2, x3, y3):
    # isLeft(): test if a point is Left|On|Right of an infinite 2D line.
    #   From http://geomalgorithms.com/a01-_area.html
    # Input:  three points P1, P2, and P3
    # Return: >0 for P3 left of the line through P1 to P2
    # =0 for P3 on the line
    # <0 for P3 right of the line
    return ( (x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1) )


def isPointInPolygon(xPolygon, yPolygon, xPt, yPt):
    """Returns boolean if a point is inside a polygon of vertices."""
    
    # How to tell if a point is inside a polygon:
    # Determine the change in angle made by the point and the vertices
    # of the polygon.  Add up the delta(angle)'s from the first (include
    # the first point again at the end).  If the point is inside the
    # polygon, then the total angle will be +/-360 deg.  If the point is
    # outside, then the total angle will be 0 deg.  Points on the edge will
    # outside.
    # This is called the Winding Algorithm
    # http://geomalgorithms.com/a03-_inclusion.html

    n = len(xPolygon)
    # Array for the angles
    angle = np.zeros(n)

    # add first vertex to the end
    xPolygon1 = np.append( xPolygon, xPolygon[0] )
    yPolygon1 = np.append( yPolygon, yPolygon[0] )

    wn = 0   # winding number counter

    # Loop through the edges of the polygon
    for i in range(n):
        # if edge crosses upward (includes its starting endpoint, and excludes its final endpoint)
        if yPolygon1[i] <= yPt and yPolygon1[i+1] > yPt:
            # if (P is  strictly left of E[i])    // Rule #4
            if isLeft(xPolygon1[i], yPolygon1[i], xPolygon1[i+1], yPolygon1[i+1], xPt, yPt) > 0: 
                 wn += 1   # a valid up intersect right of P.x

        # if edge crosses downward (excludes its starting endpoint, and includes its final endpoint)
        if yPolygon1[i] > yPt and yPolygon1[i+1] <= yPt:
            # if (P is  strictly right of E[i])    // Rule #4
            if isLeft(xPolygon1[i], yPolygon1[i], xPolygon1[i+1], yPolygon1[i+1], xPt, yPt) < 0: 
                 wn -= 1   # a valid up intersect right of P.x

    # wn = 0 only when P is outside the polygon
    if wn == 0:
        return False
    else:
        return True

#def main(rootDir, tract, visits, ccdKey='ccdnum'):
def main(rootDir, visits, ccdKey='ccdnum'):

    butler = dafPersist.Butler(rootDir)
    mapper = butler.mapper
    camera = mapper.camera

    # Load list of ccds
    ccdList = [detector.getSerial() for detector in camera]

    # Load the skyMap
    skymap = butler.get('deepCoadd_skyMap')


    ##################
    ###  Visit loop
    for i_v, visit in enumerate(visits):

        # Load the bbox info for all ccds
        rmin, rmax, dmin, dmax, ccdNames = [], [], [], [], []

        # Loop over ccds
        for ccd in camera:
            bbox = ccd.getBBox()
            ccdId = int(ccd.getSerial())
            dataId = {'visit': visit, ccdKey: ccdId}
            try:
                #print dataId
                md = butler.get("calexp_md", dataId)
                #md = butler.get("calexp_md", dataId, immediate=True)
                wcs = afwImage.makeWcs(md)
                ra, dec = bboxToRaDec(bbox, wcs)
                #print ra, dec
                #print min(ra), max(ra), min(dec), max(dec)
                buff = 0.1
# WRONG!!! I need the exact coordinates of the vertices
# Having the min/max values would be helpful as well
# AND USE NUMPY ARRAYS!!  lists are slow!
                rmin += [min(ra)]
                rmax += [max(ra)]
                dmin += [min(dec)]
                dmax += [max(dec)]
                ccdNames += [ccdId]
                #print ccdId, min(ra), max(ra), min(dec), max(dec)
            except:
                pass
                #print ccdId, "pass"
                #print "pass"
# check that there are some elements in xmin
        #print xmin

        # Loop over tracts in SkyMap
        for tract in skymap:
# CHECK IF VISIT MIN/MAX BOUNDARY OVERLAPS TRACT, COULD BE CHALLENGING SINCE TRACT COULD HAVE ODD SHAPE
            # Loop over patches in tract
            for patch in tract:
                pra, pdec = bboxToRaDec(patch.getInnerBBox(), tract.getWcs())

# CHECK IF PATCH OVERLAPS VISIT IN MIN/MAX FIRST

                # Loop over ccds
                for i_c in range(len(rmin)):
                    rr = [rmin[i_c], rmax[i_c], rmax[i_c], rmin[i_c]]  # ccd RA array
                    dd = [dmin[i_c], dmin[i_c], dmax[i_c], dmax[i_c]]  # ccd DEC array
# CHECK IF CCD AND PATCH OVERLAP USING MIN/MAX FIRST
                    # if the patch and ccd overlap print out the information
                    if doPolygonsOverlap(rr, dd, pra, pdec):
                        print visit, ccdNames[i_c], str(tract.getId()), str(patch.getIndex()) 

    
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("root", help="Root directory of data repository")
    #parser.add_argument("tract", type=int, help="Tract to show")
    parser.add_argument("visits", help="visit to show")
    #parser.add_argument("-c", "--ccds", help="specify CCDs")
    #parser.add_argument("-p", "--showPatch", action='store_true', default=False,
    #                    help="Show the patch boundaries")
    #parser.add_argument("--ccdKey", default="ccd", help="Data ID name of the CCD key")
    parser.add_argument("--ccdKey", default="ccdnum", help="Data ID name of the CCD key")
    args = parser.parse_args()

    def idSplit(id):
        if id is None:
            return id
        ids = []
        for r in id.split("^"):
            m = re.match(r"^(\d+)\.\.(\d+):?(\d+)?$", r)
            if m:
                limits = [int(v) if v else 1 for v in m.groups()]
                limits[1] += 1
                ids += range(*limits)
            else:
                ids.append(int(r))
        return ids
        
    #main(args.root, args.tract, visits=idSplit(args.visits), ccds=idSplit(args.ccds), ccdKey=args.ccdKey, showPatch=args.showPatch)
    main(args.root, visits=idSplit(args.visits), ccdKey=args.ccdKey)
