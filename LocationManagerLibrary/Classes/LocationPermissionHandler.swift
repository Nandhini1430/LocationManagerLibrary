//
//  LocationPermissionHandler.swift
//  LocationManagerLibrary
//
//  Created by nandhini-pt5566 on 25/05/23.
//

import Foundation
import UIKit

public enum AuthorizationType{
    case ALWAYS
    case WHEN_IN_USE
}

public class LocationPermissionHandler{
    
    static public let shared = LocationPermissionHandler()
    
    private let locationManager = ZLocationManager()
    
    var authorizationType: AuthorizationType = .WHEN_IN_USE
    
    private let SYSTEM_ALERT_FOR_LOCATION_PERMISSION = "count"
    private let LOCATION_ALERT = "This app needs permission to access location in background also. Please make sure loation access is allowed always and precise location is enabled for better accuracy"
    private let ENABLE_PRECISE_LOCATION = "Please enable precise location for better accuracy"
    private let LOCATION_SERVICE_ALERT = "This app needs permission to access location. Please make sure location services is enabled.\r Go to settings -> privacy -> enable location service"
    
    public func addObserver(authorizationType: AuthorizationType) {
        
        // Add observer to notify when the application state becomes foreground
        NotificationCenter.default.addObserver(self, selector:  #selector(didEnterForeground),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
        
        self.authorizationType = authorizationType
    }
    
    // To check whether the user has given location access permission for our app
    private func checkForLocationPermissionStatus(success: @escaping () -> Void, failure: @escaping (Error) -> Void){
        
        let status: LocationAuthorizationStatus = getAuthorizationStatus()
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            UserDefaults.standard.set(false, forKey: SYSTEM_ALERT_FOR_LOCATION_PERMISSION)
            
        case .restricted:
            let error = NSError(domain: "Location Access restricted. Kindly enable location access in settings", code: 1, userInfo: nil)
            failure(error)
            
        case .denied:
            let error = NSError(domain: "Location Access Denied. Kindly enable location access in settings", code: 1, userInfo: nil)
            failure(error)
            
        case .authorizedAlways:
            success()
            
        case .authorizedWhenInUse:
            
            if authorizationType == .ALWAYS{
                locationManager.requestAlwaysAuthorization()
                
                if !UserDefaults.standard.bool(forKey: SYSTEM_ALERT_FOR_LOCATION_PERMISSION){
                    success()
                }
                else{
                    let error = NSError(domain: "Authorized when in use", code: 1, userInfo: nil)
                    failure(error)
                }
                UserDefaults.standard.set(true, forKey: SYSTEM_ALERT_FOR_LOCATION_PERMISSION)
            }
            else{
                success()
            }
        }
    }
 
    // To get current location authorization status
    public func getAuthorizationStatus() -> LocationAuthorizationStatus{
        return locationManager.authorizationStatus()
    }
    
    // To check if location service is enabled in that mobile
    public func checkIfLocationServiceEnabled() -> Bool {
        return locationManager.locationServicesEnabled()
    }
    
    // To check if precise location is enabled
    public func checkIfPreciseLocationIsEnabled() -> Bool{
        if #available(iOS 14.0, *) {
            return locationManager.accuracyAuthorization() == .fullAccuracy
        }
        return false
    }
    
    private func checkAllPermission(){
        
        checkForLocationPermissionStatus { [self] in
            if #available(iOS 14.0, *) {
                if !checkIfPreciseLocationIsEnabled(){
                    UIComponents.shared.showPermissionAlert(locationService: true, msg: ENABLE_PRECISE_LOCATION)
                }
                else{
                    UIComponents.shared.dismissAlert()
                }
            }
        } failure: { [self] error in
            
            let status = getAuthorizationStatus()
            
            if !checkIfLocationServiceEnabled(){
                UIComponents.shared.showPermissionAlert(locationService: true, msg: LOCATION_SERVICE_ALERT)
            }
            else if authorizationType == .ALWAYS{
                if (status != .authorizedAlways) && !(status == .authorizedWhenInUse && !(UserDefaults.standard.bool(forKey: SYSTEM_ALERT_FOR_LOCATION_PERMISSION))){
                    UIComponents.shared.showPermissionAlert(msg: LOCATION_ALERT)
                }
            }
            else{
                UIComponents.shared.dismissAlert()
            }
        }
    }
    
    @objc private func didEnterForeground(){
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2){
            self.checkAllPermission()
        }
    }
}
