import Foundation
import CoreLocation

public enum LocationRepositoryError: LocalizedError {
    case disabled
    case notAuthorized
    case custom(Error)
}

open class LocationRepository: NSObject {

    public typealias Location = (Result<CLLocation, LocationRepositoryError>) -> Void
    public typealias Permission = (Result<Void, LocationRepositoryError>) -> Void

    public var lastLocation: CLLocation? {
        locationManager.location
    }
    
    public var validStatuses: [CLAuthorizationStatus] = [.authorizedWhenInUse, .authorizedAlways]

    public let locationManager: CLLocationManager
    private var accuracy = kCLLocationAccuracyBest
    private var completionHandlers: [Location] = []
    private var permissionCompletionHandler: Permission?
    
    public init(locationManager: CLLocationManager, accuracy: CLLocationAccuracy) {
        self.locationManager = locationManager
        self.accuracy = accuracy
        super.init()
        initializeTheLocationManager()
    }

    public func stopUpdate() {
        locationManager.stopUpdatingLocation()
    }
    
    public func update(completionHandler: @escaping Location) {
        guard isLocationServicesEnabled() else {
            completionHandler(.failure(.disabled))
            return
        }
        
        guard isAuthorizationStatusValid() else {
            completionHandler(.failure(.notAuthorized))
            return
        }
        
        self.completionHandlers.append(completionHandler)
        
        locationManager.startUpdatingLocation()
    }
    
    public func backgroundUpdate(completionHandler: @escaping Location) {
        guard isLocationServicesEnabled() else {
            completionHandler(.failure(.disabled))
            return
        }
        
        guard isAuthorizationStatusValid() else {
            completionHandler(.failure(.notAuthorized))
            return
        }
        
        self.completionHandlers.append(completionHandler)

        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
    }
    
    private func initializeTheLocationManager() {
        locationManager.desiredAccuracy = accuracy
        locationManager.distanceFilter = accuracy
        locationManager.delegate = self
    }

    public func isLocationServicesEnabled() -> Bool {
        CLLocationManager.locationServicesEnabled()
    }

    public func isAuthorizationStatusValid() -> Bool {
        validStatuses.contains(CLLocationManager.authorizationStatus())
    }
    
    public func isNotDeterminedAuthorization() -> Bool {
        CLLocationManager.authorizationStatus() == .notDetermined
    }
    
    public func isDeniedAuthorization() -> Bool {
        CLLocationManager.authorizationStatus() == .denied
    }
    
    public func getPermission(completionHandler: @escaping Permission) {
        permissionCompletionHandler = completionHandler
        locationManager.requestAlwaysAuthorization()
    }
}

extension LocationRepository: CLLocationManagerDelegate {

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last, location.isValid {
            completionHandlers.forEach { $0(.success(location))}
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied {
            manager.stopUpdatingLocation()
            return
        }
        completionHandlers.forEach { $0(.failure(.custom(error)))}
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard status != .notDetermined else {
            return
        }
        
        if validStatuses.contains(status) {
            permissionCompletionHandler?(.success(()))
        } else {
            permissionCompletionHandler?(.failure(.notAuthorized))
        }
    }
}

extension CLLocation {
    
    var isValid: Bool {
        (coordinate.latitude != 0.0) && (coordinate.longitude != 0.0)
    }
}
