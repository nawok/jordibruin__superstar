//
//  SettingsSheet.swift
//  Superstar (macOS)
//
//  Created by Jordi Bruin on 17/07/2022.
//

import SwiftUI

struct SettingsSheet: View {
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appsManager: AppsManager
    @AppStorage("pendingPublications") var pendingPublications: [String] = []
    
    @AppStorage("menuBarVisible") var menuBarVisible: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            fetchIcons
            removeCacheIcons
            removePending
            showHiddenApps
            menuBarToggle
            Spacer()
        }
        .padding(12)
        .toolbar(content: {
            ToolbarItem(content: {
                Text("Settings")
                .font(.title2)
                .bold()
            })
        })
    }
    
    var header: some View {
        HStack {
            Text("Settings")
                .font(.system(.title, design: .rounded))
                .bold()
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .opacity(0.7)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
    
    var fetchIcons: some View {
        VStack(alignment: .leading) {
            Button {
                Task {
                    await appsManager.getIcons()
                }
            } label: {
                Label("Fetch Icons", systemImage: "paintbrush.fill")
                    .font(.system(.body, design: .rounded))
            }
            Text("Retrieve the latest icons for your apps")
                .font(.system(.body, design: .rounded))
        }
    }
    
    var removeCacheIcons: some View {
        VStack(alignment: .leading) {
            Button {
                Task {
                    await appsManager.removeCachedIcons()
                }
            } label: {
                Label("Remove Icons Cache", systemImage: "trash.slash.circle.fill")
                    .font(.system(.body, design: .rounded))
            }
            Text("Remove the cached icons")
                .font(.system(.body, design: .rounded))
        }
    }
    
    @AppStorage("hiddenAppIds") var hiddenAppIds: [String] = []
    
    var showHiddenApps: some View {
        VStack(alignment: .leading) {
            Button {
                hiddenAppIds.removeAll()
            } label: {
                Label("Show hidden apps", systemImage: "eye.slash.fill")
                    .font(.system(.body, design: .rounded))
            }
        
        }
    }
    
    var removePending: some View {
        VStack(alignment: .leading) {
        Button {
            pendingPublications.removeAll()
        } label: {
            Label("Clear pending responses", systemImage: "arrowshape.turn.up.left.2.circle.fill")
                .font(.system(.body, design: .rounded))
        }
            Text("When you respond to a review, its ID is saved locally so that it can be hidden while it's being reviewed by Apple. You can reset the cache, but be aware that this will cause you to see reviews that you have already responded to which are in still in review.")
                .font(.system(.body, design: .rounded))
        }
    }
    
    var menuBarToggle: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $menuBarVisible) {
                Text("Show Menu Bar icon")
                    .font(.system(.body, design: .rounded))
            }
            .onChange(of: menuBarVisible) { menuBarVisible in
                updateMenuBar()
            }
//            Text("When you respond to a review, its ID is saved locally so that it can be hidden while it's being reviewed by Apple. You can reset the cache, but be aware that this will cause you to see reviews that you have already responded to which are in still in review.")
//                .font(.system(.caption, design: .rounded))
        }
    }
    
    func updateMenuBar() {
        NotificationCenter.default.post(
            name: Notification.Name.init("changeMenu"),
            object: "Object",
            userInfo: ["menuBarVisible": menuBarVisible]
        )
    }
    
}

//struct SettingsSheet_Previews: PreviewProvider {
//    static var previews: some View {
//        SettingsSheet(appsManager: AppsManager())
//    }
//}
