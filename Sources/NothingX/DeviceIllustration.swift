import SwiftUI

struct DeviceIllustration: View {
    let deviceName: String
    var size: CGFloat = 150
    @AppStorage(DeviceColor.key) private var deviceColor = DeviceColor.black
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    private static let body = LinearGradient(
        colors: [Color.white.opacity(0.95), Color.white.opacity(0.42)], startPoint: .top, endPoint: .bottom)
    private static let shade = LinearGradient(
        colors: [Color.white.opacity(0.5), Color.white.opacity(0.16)], startPoint: .top, endPoint: .bottom)

    var body: some View {
        content
            .background(
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.22), .clear], center: .center,
                                         startRadius: 0, endRadius: 80))
                    .frame(width: size * 1.15, height: size * 1.15)
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 10)
            .offset(y: floating ? -4 : 3)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { floating = true }
            }
            .accessibilityHidden(true)
    }

    private var isEarbuds: Bool { DeviceKind(name: deviceName).isEarbuds }

    private var photo: NSImage? {
        let slug = deviceName.lowercased()
            .replacingOccurrences(of: "nothing ", with: "")
            .replacingOccurrences(of: " (", with: "-")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: " ", with: "-")
        return ([deviceColor] + DeviceColor.allCases).lazy.compactMap { NSImage(named: "\(slug)-\($0.rawValue)") }.first
    }

    @ViewBuilder private var content: some View {
        if let photo {
            Image(nsImage: photo).resizable().scaledToFit().frame(width: size, height: size)
        } else if isEarbuds {
            earbuds.scaleEffect(size / 150)
        } else {
            headphone.scaleEffect(size / 150)
        }
    }

    private var headphone: some View {
        ZStack {
            HeadbandShape()
                .stroke(Self.shade, style: StrokeStyle(lineWidth: 9, lineCap: .round))
            ForEach([false, true], id: \.self) { right in
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Self.body)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                        .padding(.vertical, 12)
                        .padding(right ? .leading : .trailing, 9)
                }
                .frame(width: 34, height: 78)
                .overlay(alignment: .topLeading) {
                    Capsule().fill(Color.white.opacity(0.55)).frame(width: 5, height: 26).padding(.top, 10).padding(.leading, 6)
                }
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.55), lineWidth: 1))
                .offset(x: right ? 54 : -54, y: 22)
            }
        }
        .frame(width: 150, height: 120)
    }

    private var earbuds: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Self.body)
                .frame(width: 100, height: 58)
                .overlay(
                    Capsule().fill(Color.black.opacity(0.22)).frame(width: 100, height: 1.5).offset(y: -8)
                )
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.55), lineWidth: 1))
                .offset(y: 30)
            ForEach([false, true], id: \.self) { right in
                VStack(spacing: -4) {
                    Circle().fill(Self.body).frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1))
                    Capsule().fill(Self.body).frame(width: 9, height: 38)
                }
                .rotationEffect(.degrees(right ? -14 : 14))
                .offset(x: right ? 26 : -26, y: -22)
            }
        }
        .frame(width: 150, height: 120)
    }
}

private struct HeadbandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX - 54, y: rect.maxY * 0.52))
        p.addCurve(to: CGPoint(x: rect.midX + 54, y: rect.maxY * 0.52),
                   control1: CGPoint(x: rect.midX - 60, y: rect.minY - 18),
                   control2: CGPoint(x: rect.midX + 60, y: rect.minY - 18))
        return p
    }
}
