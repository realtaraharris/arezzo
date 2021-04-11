//
//  AppDelegate.swift
//  Arezzo
//
//  Created by Max Harris on 6/26/20.
//  Copyright © 2020 Max Harris. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do {
            self.window = UIWindow()
            self.window?.rootViewController = ViewController(coder: try NSCoder.empty())
            self.window?.makeKeyAndVisible()
        } catch {
            print(error)
        }

        return true
    }
}
