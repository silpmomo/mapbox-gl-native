#import "MGLGeometry_Private.h"

#import "MGLFoundation.h"

#import <mbgl/util/projection.hpp>
#import <mbgl/util/constants.hpp>

#if !TARGET_OS_IPHONE && !TARGET_OS_SIMULATOR
#import <Cocoa/Cocoa.h>
#endif

/** Vertical field of view, measured in degrees, for determining the altitude
    of the viewpoint.

    TransformState::getProjMatrix() has a variable vertical field of view that
    defaults to 2 arctan ⅓ rad ≈ 36.9° but MapKit uses a vertical field of view of 30°.
    flyTo() assumes a field of view of 2 arctan ½ rad. */
const CLLocationDegrees MGLAngularFieldOfView = 30;

const MGLCoordinateSpan MGLCoordinateSpanZero = {0, 0};

CGRect MGLExtendRect(CGRect rect, CGPoint point) {
    if (point.x < rect.origin.x) {
        rect.size.width += rect.origin.x - point.x;
        rect.origin.x = point.x;
    }
    if (point.x > rect.origin.x + rect.size.width) {
        rect.size.width += point.x - (rect.origin.x + rect.size.width);
    }
    if (point.y < rect.origin.y) {
        rect.size.height += rect.origin.y - point.y;
        rect.origin.y = point.y;
    }
    if (point.y > rect.origin.y + rect.size.height) {
        rect.size.height += point.y - (rect.origin.y + rect.size.height);
    }
    return rect;
}

mbgl::LatLng MGLLatLngFromLocationCoordinate2D(CLLocationCoordinate2D coordinate) {
    try {
        return mbgl::LatLng(coordinate.latitude, coordinate.longitude);
    } catch (std::domain_error &error) {
        [NSException raise:NSInvalidArgumentException format:@"%s", error.what()];
        return {};
    }
}

CLLocationDistance MGLAltitudeForZoomLevel(double zoomLevel, CGFloat pitch, CLLocationDegrees latitude, CGSize size) {
    CLLocationDistance metersPerPixel = mbgl::Projection::getMetersPerPixelAtLatitude(latitude, zoomLevel);
    CLLocationDistance metersTall = metersPerPixel * size.height;
    CLLocationDistance altitude = metersTall / 2 / std::tan(MGLRadiansFromDegrees(MGLAngularFieldOfView) / 2.);
    return altitude * std::sin(M_PI_2 - MGLRadiansFromDegrees(pitch)) / std::sin(M_PI_2);
}

double MGLZoomLevelForAltitude(CLLocationDistance altitude, CGFloat pitch, CLLocationDegrees latitude, CGSize size) {
    CLLocationDistance eyeAltitude = altitude / std::sin(M_PI_2 - MGLRadiansFromDegrees(pitch)) * std::sin(M_PI_2);
    CLLocationDistance metersTall = eyeAltitude * 2 * std::tan(MGLRadiansFromDegrees(MGLAngularFieldOfView) / 2.);
    CLLocationDistance metersPerPixel = metersTall / size.height;
    CGFloat mapPixelWidthAtZoom = std::cos(MGLRadiansFromDegrees(latitude)) * mbgl::util::M2PI * mbgl::util::EARTH_RADIUS_M / metersPerPixel;
    return ::log2(mapPixelWidthAtZoom / mbgl::util::tileSize);
}

MGLRadianDistance MGLDistanceBetweenRadianCoordinates(MGLRadianCoordinate2D from, MGLRadianCoordinate2D to) {
    double a = pow(sin((to.latitude - from.latitude) / 2), 2)
        + pow(sin((to.longitude - from.longitude) / 2), 2) * cos(from.latitude) * cos(to.latitude);
    
    return 2 * atan2(sqrt(a), sqrt(1 - a));
}

CLLocationDistance MGLDistanceBetweenLocationCoordinates(CLLocationCoordinate2D from, CLLocationCoordinate2D to) {
    MGLRadianDistance radianDistance = MGLDistanceBetweenRadianCoordinates(MGLRadianCoordinateFromLocationCoordinate(from),
                                                                           MGLRadianCoordinateFromLocationCoordinate(to));
    return radianDistance * mbgl::util::EARTH_RADIUS_M;
}

MGLRadianDirection MGLRadianCoordinatesDirection(MGLRadianCoordinate2D from, MGLRadianCoordinate2D to) {
    double a = sin(to.longitude - from.longitude) * cos(to.latitude);
    double b = cos(from.latitude) * sin(to.latitude)
    - sin(from.latitude) * cos(to.latitude) * cos(to.longitude - from.longitude);
    return atan2(a, b);
}

MGLRadianCoordinate2D MGLRadianCoordinateAtDistanceFacingDirection(MGLRadianCoordinate2D coordinate,
                                                                   MGLRadianDistance distance,
                                                                   MGLRadianDirection direction) {
    double otherLatitude = asin(sin(coordinate.latitude) * cos(distance)
                                + cos(coordinate.latitude) * sin(distance) * cos(direction));
    double otherLongitude = coordinate.longitude + atan2(sin(direction) * sin(distance) * cos(coordinate.latitude),
                                                         cos(distance) - sin(coordinate.latitude) * sin(otherLatitude));
    return MGLRadianCoordinate2DMake(otherLatitude, otherLongitude);
}

CLLocationCoordinate2D MGLCoordinateAtDistanceFacingDirection(CLLocationCoordinate2D coordinate,
                                                              CLLocationDistance distance,
                                                              CLLocationDirection direction) {
    MGLRadianCoordinate2D radianCenter = MGLRadianCoordinateFromLocationCoordinate(coordinate);
    MGLRadianCoordinate2D radianVertex = MGLRadianCoordinateAtDistanceFacingDirection(radianCenter,
                                                                                      distance / mbgl::util::EARTH_RADIUS_M,
                                                                                      MGLRadiansFromDegrees(direction));
    return MGLLocationCoordinateFromRadianCoordinate(radianVertex);
}

CLLocationDirection MGLDirectionBetweenCoordinates(CLLocationCoordinate2D firstCoordinate, CLLocationCoordinate2D secondCoordinate) {
    // Ported from https://github.com/mapbox/turf-swift/blob/857e2e8060678ef4a7a9169d4971b0788fdffc37/Turf/Turf.swift#L23-L31
    MGLRadianCoordinate2D firstRadianCoordinate = MGLRadianCoordinateFromLocationCoordinate(firstCoordinate);
    MGLRadianCoordinate2D secondRadianCoordinate = MGLRadianCoordinateFromLocationCoordinate(secondCoordinate);
    
    CGFloat a = sin(secondRadianCoordinate.longitude - firstRadianCoordinate.longitude) * cos(secondRadianCoordinate.latitude);
    CGFloat b = (cos(firstRadianCoordinate.latitude) * sin(secondRadianCoordinate.latitude)
                 - sin(firstRadianCoordinate.latitude) * cos(secondRadianCoordinate.latitude) * cos(secondRadianCoordinate.longitude - firstRadianCoordinate.longitude));
    MGLRadianDirection radianDirection = atan2(a, b);
    return radianDirection * 180 / M_PI;
}

CGPoint MGLPointRounded(CGPoint point) {
#if TARGET_OS_IPHONE || TARGET_OS_SIMULATOR
    CGFloat scaleFactor = [UIScreen mainScreen].nativeScale;
#elif TARGET_OS_MAC
    CGFloat scaleFactor = [NSScreen mainScreen].backingScaleFactor;
#endif
    return CGPointMake(round(point.x * scaleFactor) / scaleFactor, round(point.y * scaleFactor) / scaleFactor);
}

MGLMapPoint MGLMapPointForCoordinate(CLLocationCoordinate2D coordinate, double zoomLevel) {
    mbgl::Point<double> projectedCoordinate = mbgl::Projection::project(MGLLatLngFromLocationCoordinate2D(coordinate), std::pow(2.0, zoomLevel));
    return MGLMapPointMake(projectedCoordinate.x, projectedCoordinate.y, zoomLevel);
}

MGLMatrix4 MGLMatrix4Make(std::array<double, 16>  array) {
    MGLMatrix4 mat4 = {
        .m00 = array[0], .m01 = array[1], .m02 = array[2], .m03 = array[3],
        .m10 = array[4], .m11 = array[5], .m12 = array[6], .m13 = array[7],
        .m20 = array[8], .m21 = array[9], .m22 = array[10], .m23 = array[11],
        .m30 = array[12], .m31 = array[13], .m32 = array[14], .m33 = array[15]
    };
    return mat4;
}

