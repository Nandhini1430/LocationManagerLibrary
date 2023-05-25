//
//  ViewController.swift
//  LocationManagerLibrary
//
//  Created by Nandhini on 05/25/2023.
//  Copyright (c) 2023 Nandhini. All rights reserved.
//

import UIKit
import LocationManagerLibrary

class ViewController: UIViewController {

    private let locationManager = ZLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.setupLocationManager(delegate: self)
        locationManager.startUpdatingLocation(with: 5, backgroundUpdateNeeded: false)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension ViewController: ZLocationManagerDelegate{
    
    func zLocationManager(didFailWithError error: Error) {
        print(error.localizedDescription)
    }
    
    func zLocationManager(didUpdateLocations location: LocationManagerLibrary.ZLocation?) {
        print(location)
    }
    
    func zLocationManager(didChangeAuthorization status: LocationManagerLibrary.LocationAuthorizationStatus) {
        print(status)
    }
}

