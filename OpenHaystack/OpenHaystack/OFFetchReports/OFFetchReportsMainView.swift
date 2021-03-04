//  OpenHaystack – Tracking personal Bluetooth devices via Apple's Find My network
//
//  Copyright © 2021 Secure Mobile Networking Lab (SEEMOO)
//  Copyright © 2021 The Open Wireless Link Project
//
//  SPDX-License-Identifier: AGPL-3.0-only

import SwiftUI

struct OFFetchReportsMainView: View {

    @Environment(\.findMyController) var findMyController

    @State var targetedDrop: Bool = false
    @State var error: Error?
    @State var showMap = false
    @State var loading = false

    @State var searchPartyToken: Data?
    @State var searchPartyTokenString: String = ""
    @State var keyPlistFile: Data?

    @State var showTokenPrompt = false

    var dropView: some View {
        ZStack(alignment: .center) {
            HStack {
                Spacer()
                Spacer()
            }

            VStack {
                Spacer()
                Text("Drop exported keys here")
                    .font(Font.system(size: 44, weight: .bold, design: .default))
                    .padding()

                Text("The keys can be exported into the right format using the Read FindMy Keys App.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()

                Spacer()
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20.0)
                .stroke(Color.gray, style: StrokeStyle(lineWidth: 5.0, lineCap: .round, lineJoin: .round, miterLimit: 10, dash: [15]))
            )
        .padding()
        .onDrop(of: ["public.file-url"], isTargeted: self.$targetedDrop) { (droppedData) -> Bool in
            return self.droppedData(data: droppedData)
        }

    }

    var loadingView: some View {
        VStack {
            Text("Downloading locations and decrypting...")
            .font(Font.system(size: 44, weight: .bold, design: .default))
            .padding()
        }
    }

    /// This view is shown if the search party token cannot be accessed from keychain
    var missingSearchPartyTokenView: some View {
        VStack {
            Text("Search Party token could not be fetched")
            Text("Please paste the search party token below after copying it from the macOS Keychain.")
            Text("The item that contains the key can be found by searching for: ")
            Text("com.apple.account.DeviceLocator.search-party-token")
                .font(.system(Font.TextStyle.body, design: Font.Design.monospaced))

            TextField("Search Party Token", text: self.$searchPartyTokenString)

            Button(action: {
                if !self.searchPartyTokenString.isEmpty,
                    let file = self.keyPlistFile,
                    let searchPartyToken = self.searchPartyTokenString.data(using: .utf8) {
                    self.searchPartyToken = searchPartyToken
                    self.downloadAndDecryptLocations(with: file, searchPartyToken: searchPartyToken)
                }
            }, label: {
                Text("Download reports")
            })
        }
    }

    var mapView: some View {
        ZStack {
            MapView()
            VStack {
                HStack {
                     Spacer()
                    Button(action: {
                        self.showMap = false
                        self.showTokenPrompt = false
                    }, label: {
                        Text("Import other tokens")
                    })

                     Button(action: {
                         self.exportDecryptedLocations()

                     }, label: {
                         Text("Export")
                     })

                 }
                .padding()
                Spacer()
            }

        }
    }

    var body: some View {
        GeometryReader { geo in
            if self.loading {
                self.loadingView
            } else if self.showMap {
                self.mapView
            } else if self.showTokenPrompt {
                self.missingSearchPartyTokenView
            } else {
                self.dropView
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }

    }

    func droppedData(data: [NSItemProvider]) -> Bool {
        guard let itemProvider = data.first else {return false}

        itemProvider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (u, _) in
            guard let urlData = u as? Data,
                let fileURL = URL(dataRepresentation: urlData, relativeTo: nil),
                // Only plist supported
                fileURL.pathExtension == "plist",
                // Load the file
                let file = try? Data(contentsOf: fileURL)
                else {return}

            print("Received data \(fileURL)")

            self.keyPlistFile = file
            let reportsFetcher = ReportsFetcher()
            self.searchPartyToken = reportsFetcher.fetchSearchpartyToken()

            if let searchPartyToken = self.searchPartyToken {
                self.downloadAndDecryptLocations(with: file, searchPartyToken: searchPartyToken)
            } else {
                self.showTokenPrompt = true
            }

        }
        return true
    }

    func downloadAndDecryptLocations(with keyFile: Data, searchPartyToken: Data) {
        self.loading = true

        self.findMyController.loadPrivateKeys(from: keyFile, with: searchPartyToken, completion: { error in
            // Check if an error occurred
            guard error == nil else {
                self.error = error
                return
            }

            // Show map view
            self.loading = false
            self.showMap = true

        })
    }

    func exportDecryptedLocations() {
        do {
            let devices = self.findMyController.devices
            let deviceData = try PropertyListEncoder().encode(devices)

            SavePanel().saveFile(file: deviceData, fileExtension: "plist")

        } catch {
            print("Error: \(error)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        OFFetchReportsMainView()
    }
}