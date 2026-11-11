import SwiftUI

struct Dashboard: View {
    @Environment(HeadphoneModel.self) private var model

    private var connected: Bool { model.connection == .connected }
    private var equalizerSupported: Bool {
        (model.isWired ? model.softwareEQProfile : model.eqProfile)?.bands.isEmpty == false
    }

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            CardScrollView(inset: Layout.topInset) {
                VStack(alignment: .leading, spacing: Layout.gap) {
                    DeviceHero()
                    NowPlayingTile(service: model.nowPlaying)
                    BluetoothPermissionNotice()
                    NoiseControlCard()
                    if !connected || model.spatial != nil { SpatialAudioCard() }
                    DeviceFooter().padding(.top, 8)
                }
            }
            .frame(width: 352)
            CardScrollView(inset: Layout.topInset) {
                VStack(alignment: .leading, spacing: Layout.gap) {
                    if !connected || equalizerSupported { EqualizerCard() }
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: Layout.gap) {
                            GesturesCard().frame(minWidth: 340)
                            DeviceSettingsView().frame(minWidth: 340)
                        }
                        VStack(alignment: .leading, spacing: Layout.gap) {
                            GesturesCard()
                            DeviceSettingsView()
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
