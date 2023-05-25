//
//  ZLocationManager.swift
//  LocationManagerLibrary
//
//  Created by nandhini-pt5566 on 25/05/23.
//

import Foundation
import CoreLocation
import UIKit

public protocol ZLocationManagerDelegate{

    func zLocationManager(didFailWithError error: Error)
    func zLocationManager(didUpdateLocations location: ZLocation?)
    func zLocationManager(didChangeAuthorization status: LocationAuthorizationStatus)
}

public enum LocationAuthorizationStatus{
    case notDetermined
    case restricted
    case denied
    case authorizedAlways
    case authorizedWhenInUse
}

public enum AuthorizationAccuracy{
    case fullAccuracy
    case reducedAccuracy
    case unknown
}

public struct ZLocation: Codable{

    var lat: Double
    var lon: Double
    var speed: Double = -1
    var timeStamp: Date?

    init(latitude: Double, longitude: Double) {
        self.lat = latitude
        self.lon = longitude
    }

    init(latitude: Double, longitude: Double, speed: Double) {
        self.lat = latitude
        self.lon = longitude
        self.speed = speed
    }

    func distance(from loc: ZLocation) -> Double{
        let loc1 = CLLocation(latitude: self.lat, longitude: self.lon)
        let loc2 = CLLocation(latitude: loc.lat, longitude: loc.lon)
        return loc1.distance(from: loc2)
    }
}

// Wrapper for CLLocationManager to give location updates based on the interval specified
public class ZLocationManager : NSObject{

    private var delegate : ZLocationManagerDelegate?
    private let locationManager = CLLocationManager()
    private var timer : Timer? = nil
    private var taskID : UIBackgroundTaskIdentifier! = nil
    private var time : TimeInterval = 0
    private var isTimerOn : Bool = false
    private var significantLocationManager = CLLocationManager()
    private var significantKey: String = "significant"
    private var bgTaskIdentifier = "fetchLocation"
    private var backgroundUpdateNeeded: Bool = false

    public func setupLocationManager(delegate : ZLocationManagerDelegate){

        // setup the location manager and necessary properties
        self.delegate = delegate
        locationManager.delegate = self
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = false
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    private func createTimer(){

        //Delay is used here because when the app launches it takes few secs to update the application state
        if backgroundUpdateNeeded{
            createNewBackgroundTask(.now() + 0.2)
        }

        if timer == nil{
            print("creating timer")
            timer = Timer.scheduledTimer(withTimeInterval: time, repeats: true, block: { [self] Timer in
                locationManager.delegate = self
                startUpdatingLocation()

                if backgroundUpdateNeeded{
                    createNewBackgroundTask(.now())
                }
            })
            RunLoop.current.add(timer!, forMode: RunLoop.Mode.common)
        }
    }

    public func requestAlwaysAuthorization(){
        locationManager.requestAlwaysAuthorization()
    }

    public func requestWhenInUseAuthorization(){
        locationManager.requestWhenInUseAuthorization()
    }

    public func locationServicesEnabled() -> Bool{
        var isEnabled = false
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInteractive).async {
            isEnabled = CLLocationManager.locationServicesEnabled()
            semaphore.signal()
        }
        semaphore.wait()
        return isEnabled
    }

    @available(iOS 14.0, *)
    public func accuracyAuthorization() -> AuthorizationAccuracy{

        let accuracy = locationManager.accuracyAuthorization

        switch accuracy{
        case .fullAccuracy: return .fullAccuracy
        case .reducedAccuracy: return .reducedAccuracy
        @unknown default: return .unknown
        }
    }

    public func authorizationStatus() -> LocationAuthorizationStatus{

        var status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        switch status{
        case .authorizedAlways:
            return .authorizedAlways
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        @unknown default:
            return .notDetermined
        }
    }

    public func requestLocation(){
        return locationManager.requestLocation()
    }

    //call this method to start updating
    public func startUpdatingLocation(with timeInterval: TimeInterval, backgroundUpdateNeeded: Bool){

        addObservers()

        self.time = timeInterval

        if timer != nil{
            timer?.invalidate()
            timer = nil
        }
        self.backgroundUpdateNeeded = backgroundUpdateNeeded
        createTimer()
        isTimerOn = true
    }

    //call this method to stop updating
    public func stopUpdatingLocation(restarted: Bool, backgroundUpdateEnabled: Bool){
        stopUpdating()
        removeObservers()
        timer?.invalidate()
        isTimerOn = false
        timer = nil

        // If location service is restarted in background we need to start the background task
        if backgroundUpdateEnabled{
            if restarted{
                createNewBackgroundTask(.now())
            }
            else{
                endBackgroundTask()
            }
        }
    }

    // To monitor the significant change in location (for ex: 500m). In order to get updates in the background we need to use startMonitoringSignificantChanges
    public func startMonitoringSignificantChanges(){
        if !UserDefaults.standard.bool(forKey: significantKey){
            significantLocationManager.delegate = self
            significantLocationManager.startMonitoringSignificantLocationChanges()
            UserDefaults.standard.set(true, forKey: significantKey)
        }
    }

    func stopMonitoringSignificantChanges(){
        significantLocationManager.stopMonitoringSignificantLocationChanges()
        significantLocationManager.delegate = nil
        UserDefaults.standard.set(false, forKey: significantKey)
    }

    @objc private func startUpdatingLocation(){
        locationManager.startUpdatingLocation()
    }

    private func stopUpdating(){
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
    }
}

// background task related methods
extension ZLocationManager{

    private func createNewBackgroundTask(_ deadline: DispatchTime){
        DispatchQueue.main.asyncAfter(deadline: deadline){ [self] in
            if(UIApplication.shared.applicationState == .inactive || UIApplication.shared.applicationState == .background){
                endBackgroundTask()
                startBackgroundTask()
            }
        }
    }

    @objc private func didEnterBackground(){
        if isTimerOn{
            if authorizationStatus() == .authorizedAlways && backgroundUpdateNeeded{
                startBackgroundTask()
            }
            else{
                timer?.invalidate()
                timer = nil
            }
        }
    }

    @objc private func didEnterForeground(){
        if isTimerOn{
            endBackgroundTask()
            createTimer()
        }
    }

    private func addObservers() {

        // Add observer to notify the change in application state
        NotificationCenter.default.addObserver(self, selector:  #selector(didEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector:  #selector(didEnterForeground),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    private func startBackgroundTask(){
        taskID = UIApplication.shared.beginBackgroundTask(withName: bgTaskIdentifier, expirationHandler: ({ [self] in
            endBackgroundTask()
        }))
    }

    @objc private func endBackgroundTask(){
        if let id = taskID{
            UIApplication.shared.endBackgroundTask(id)
            taskID = UIBackgroundTaskIdentifier.invalid
        }
    }
}

extension ZLocationManager : CLLocationManagerDelegate{

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        if manager == locationManager{

            stopUpdating()

            guard let location = locations.last else{
                delegate?.zLocationManager(didUpdateLocations: nil)
                return
            }
            var zLocation = ZLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, speed: location.speed)
            zLocation.timeStamp = Date()

            delegate?.zLocationManager(didUpdateLocations: zLocation)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate?.zLocationManager(didFailWithError: error)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {

        let status : LocationAuthorizationStatus = authorizationStatus()
        delegate?.zLocationManager(didChangeAuthorization: status)

        locationManager.delegate = self
    }
}


