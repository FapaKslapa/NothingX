import SwiftUI

struct DeviceHero: View {
    @Environment(HeadphoneModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                BatteryGauge(readings: model.batteryParts)
                    .frame(maxWidth: .infinity, alignment: .leading)
                DeviceIllustration(deviceName: model.deviceName)
                    .scaleEffect(0.8)
                    .frame(width: 120, height: 120)
            }
            Text(verbatim: model.deviceName).font(.system(size: 17, weight: .medium)).foregroundStyle(NTColor.primary)
        }
    }
}

struct DeviceFooter: View {
    @Environment(HeadphoneModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Firmware", model.firmware)
            row("Serial number", model.serial)
        }
    }

    private func row(_ label: LocalizedStringKey, _ value: String?) -> some View {
        HStack {
            Text(label).ntLabel(NTColor.disabled)
            Spacer()
            Text(verbatim: value ?? "—").font(.system(size: 11, design: .monospaced)).foregroundStyle(NTColor.secondary)
        }
    }
}
