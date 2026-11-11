import SwiftUI

struct MediaSection: View {
    var body: some View {
        SettingsSection(title: "Media access") {
            Text("Lets Nothing X show and control what Spotify, Music and your browser play.")
                .font(.system(size: 12))
                .foregroundStyle(NTColor.secondary)
            MediaPermissionList()
        }
    }
}
