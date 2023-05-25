//
//  UIComponents.swift
//  LocationManagerLibrary
//
//  Created by nandhini-pt5566 on 25/05/23.
//

import Foundation
import UIKit

class UIComponents{
    
    static let shared = UIComponents()
    private var alertView : UIAlertController? = nil
    private let POPUP_ACTION_SETTINGS = "Go to settings"
    
    private func createPermissionAlert(locationService: Bool, title: String = "", message : String) -> UIAlertController{
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let settingsAction = UIAlertAction(title: POPUP_ACTION_SETTINGS, style: .default) { _ in
            if locationService {
                //"\(UIApplication.openSettingsURLString)&path=LOCATION/\(bundleId)"
                if let url = URL(string: "App-Prefs:root=Privacy") {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
            else {
                UIApplication.shared.open(URL(string:UIApplication.openSettingsURLString)!)
            }
            self.dismissAlert()
        }
        alert.addAction(settingsAction)
        alert.preferredAction = settingsAction
        
        return alert
    }
    
    func showPermissionAlert(locationService: Bool = false, msg: String) {
        
        dismissAlert()
        
        DispatchQueue.main.async{ [self] in
            if alertView == nil{
                alertView = createPermissionAlert(locationService: locationService, message: msg)
                alertView?.show()
            }
        }
    }
    
    func dismissAlert(){
        
        DispatchQueue.main.async{ [self] in
            if let view = alertView{
                view.dismiss(animated: true)
                alertView = nil
            }
        }
    }
}

extension UIAlertController {
    
    func show() {
        present(animated: true, completion: nil)
    }
    
    func present(animated: Bool, completion: (() -> Void)?) {

        if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
            presentFromController(controller: rootVC, animated: animated, completion: completion)
        }
    }
    
    private func presentFromController(controller: UIViewController, animated: Bool, completion: (() -> Void)?) {
        if
            let navVC = controller as? UINavigationController,
            let visibleVC = navVC.visibleViewController
        {
            presentFromController(controller: visibleVC, animated: animated, completion: completion)
        } else if
            let tabVC = controller as? UITabBarController,
            let selectedVC = tabVC.selectedViewController
        {
            presentFromController(controller: selectedVC, animated: animated, completion: completion)
        } else if let presented = controller.presentedViewController {
            presentFromController(controller: presented, animated: animated, completion: completion)
        } else {
            controller.present(self, animated: animated, completion: completion);
        }
    }
}
