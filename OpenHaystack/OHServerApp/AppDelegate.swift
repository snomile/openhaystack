//
//  OpenHaystack – Tracking personal Bluetooth devices via Apple's Find My network
//
//  Copyright © 2021 Secure Mobile Networking Lab (SEEMOO)
//  Copyright © 2021 The Open Wireless Link Project
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

import AppKit
import Cocoa
import Foundation
import Vapor

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let vaporThread = DispatchQueue(label: "Vapor", qos: DispatchQoS.default)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        AnisetteDataManager.shared.requestAnisetteData { result in
            print("feteched anisette data: \(result)")
        }
        
        vaporThread.async {
            self.startVapor()
        }
    }
    
    func startVapor() {
        do {

            let app = try Application(.detect())
            app.http.server.configuration.hostname = "0.0.0.0"
            app.http.server.configuration.port = 8544
            defer { app.shutdown() }

            //Routes
            app.post("getLocationReports") { req -> EventLoopFuture<Response> in
                let reportIds = try req.content.decode(GetReportsBody.self)
                print("Received report ids")
                return ServerReportsFetcher.fetchReports(for: reportIds.ids, with: req)
            }
            
            app.get("health") { req -> String in
                return "OK"
            }
            
            try app.run()
        } catch {
            fatalError("Vapor failed to start \(String(describing: error))")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

}
