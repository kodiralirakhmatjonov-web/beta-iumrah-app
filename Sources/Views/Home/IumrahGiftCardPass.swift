import SwiftUI

/// Native animated pass for iUmrah Gift Cards.
/// Front: premium gift symbol built from animated spectral dots.
/// Back: animated $100 value and copyable code side.
struct IumrahGiftCardPass: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let gift: IumrahFriendGift
    let language: AppSettingsStore.Language

    @State private var isFlipped = false

    var body: some View {
        ZStack {
            surfaced(frontFace)
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                .zIndex(isFlipped ? 0 : 1)

            surfaced(backFace)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                .zIndex(isFlipped ? 1 : 0)
        }
        .aspectRatio(1.58, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture {
            IumrahHaptics.soft()
            withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .spring(response: 0.66, dampingFraction: 0.84)) {
                isFlipped.toggle()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("iUmrah Gift Card, $100")
        .accessibilityHint(localized("Tap to flip", "Нажмите, чтобы перевернуть", "Aylantirish uchun bosing", "Айлантириш учун босинг"))
    }

    private func surfaced<Content: View>(_ content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.085), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    private var frontFace: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    cardBackground

                    Canvas(rendersAsynchronously: true) { context, size in
                        renderGift(in: &context, size: size, time: reduceMotion ? 0.74 : timeline.date.timeIntervalSinceReferenceDate)
                    }
                    .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            Text("iUmrah Gift Card")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .tracking(-0.25)
                            GiftActivityDots()
                            Spacer()
                            Text(stateTitle)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.56))
                        }

                        Spacer(minLength: 0)

                        Text(localized("Gift card for someone close", "Подарочная карта для близких", "Yaqinlar uchun sovg‘a kartasi", "Яқинлар учун совға картаси"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var backFace: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    cardBackground
                    RadialGradient(
                        colors: [Color.white.opacity(0.07), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: proxy.size.width * 0.72
                    )

                    Canvas(rendersAsynchronously: true) { context, size in
                        renderValue(in: &context, size: size, time: reduceMotion ? 0.72 : timeline.date.timeIntervalSinceReferenceDate)
                    }
                    .allowsHitTesting(false)

                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("iUmrah Gift Card")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                            Spacer()
                            Text(stateTitle)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.56))
                        }
                        .foregroundStyle(.white)

                        Spacer(minLength: 0)

                        Text(localized("Gift code", "Код Gift Card", "Gift Card kodi", "Gift Card коди"))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.46))
                        Text(gift.code)
                            .font(.system(size: min(24, proxy.size.width * 0.062), weight: .semibold, design: .monospaced))
                            .tracking(0.4)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .padding(.top, 3)

                        Spacer(minLength: 12)

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 0.7)

                        HStack(alignment: .lastTextBaseline) {
                            Text(localized("Give $100 toward Umrah", "Подарите $100 на умру", "Umrah uchun $100 sovg‘a qiling", "Умра учун $100 совға қилинг"))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.58))
                            Spacer()
                            Text("#\(gift.position)")
                                .font(.caption.monospaced().weight(.bold))
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        .padding(.top, 10)
                    }
                    .padding(16)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }

    private var cardBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.070, green: 0.071, blue: 0.079),
                Color(red: 0.026, green: 0.027, blue: 0.032)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var stateTitle: String {
        if gift.isAvailable { return localized("Available", "Доступна", "Mavjud", "Мавжуд") }
        if gift.isRewardEarned { return localized("Earned", "Зачислено", "Hisoblandi", "Ҳисобланди") }
        return localized("Pending", "Ожидание", "Kutilmoqda", "Кутилмоқда")
    }

    private func renderGift(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard size.width > 1, size.height > 1 else { return }
        let cycle = 4.6
        let progress = positiveRemainder(time, cycle) / cycle
        let baseRadius = min(size.width, size.height) * 0.0082

        func drawDot(_ cx: CGFloat, _ cy: CGFloat, scale: CGFloat = 1.0, phase: Double = 0.0) {
            let hue = positiveRemainder(0.58 + progress + phase, 1.0)
            let wave = 0.5 + 0.5 * sin(2 * .pi * (progress + phase))
            let intensity = 0.25 + 0.75 * wave
            let spectral = Color(hue: hue, saturation: 0.78, brightness: 1.0)
            let radius = baseRadius * scale * CGFloat(0.88 + 0.16 * sin(time * 1.7 + phase * 9.0))
            fillCircle(in: &context, center: CGPoint(x: cx, y: cy), radius: radius * 1.75, color: spectral.opacity(0.12 * intensity))
            fillCircle(in: &context, center: CGPoint(x: cx, y: cy), radius: radius, color: Color.white.opacity(0.22))
            fillCircle(in: &context, center: CGPoint(x: cx, y: cy), radius: radius * 0.88, color: spectral.opacity(0.95 * intensity))
            fillCircle(in: &context, center: CGPoint(x: cx, y: cy), radius: radius * 0.42, color: Color(red: 0.015, green: 0.016, blue: 0.021).opacity(0.94))
        }

        let rect = CGRect(x: size.width * 0.28, y: size.height * 0.26, width: size.width * 0.44, height: size.height * 0.31)
        let bowY = rect.minY - rect.height * 0.08
        let stepX = rect.width / 10.5
        let stepY = rect.height / 6.0

        for row in 0..<6 {
            for col in 0..<11 {
                let x = rect.minX + CGFloat(col) * stepX
                let y = rect.minY + CGFloat(row) * stepY
                if row == 0 || row == 5 || col == 0 || col == 10 || col == 5 {
                    drawDot(x, y, scale: col == 5 ? 1.16 : 1.0, phase: Double(row * 11 + col) * 0.013)
                }
            }
        }

        for i in 0..<7 {
            let t = CGFloat(i) / 6
            drawDot(rect.minX + rect.width * 0.5 - rect.width * 0.18 * t, bowY - rect.height * 0.18 * sin(t * .pi), scale: 1.08, phase: Double(i) * 0.019)
            drawDot(rect.minX + rect.width * 0.5 + rect.width * 0.18 * t, bowY - rect.height * 0.18 * sin(t * .pi), scale: 1.08, phase: Double(i+7) * 0.019)
        }
        for i in 0..<5 {
            let t = CGFloat(i) / 4
            drawDot(rect.minX + rect.width * 0.38 + rect.width * 0.12 * t, rect.minY + rect.height * 0.03 + rect.height * 0.10 * t, scale: 0.98, phase: Double(i+13) * 0.021)
            drawDot(rect.minX + rect.width * 0.62 - rect.width * 0.12 * t, rect.minY + rect.height * 0.03 + rect.height * 0.10 * t, scale: 0.98, phase: Double(i+19) * 0.021)
        }
    }

    private func renderValue(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard size.width > 1, size.height > 1 else { return }
        let points = Self.valuePoints
        guard !points.isEmpty else { return }

        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 1
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 1
        let gridWidth = maxX - minX + 1
        let gridHeight = maxY - minY + 1

        let availableWidth = size.width * 0.74
        let availableHeight = size.height * 0.28
        let spacing = min(availableWidth / gridWidth, availableHeight / gridHeight)
        let origin = CGPoint(x: (size.width - gridWidth * spacing) / 2 + spacing * 0.5, y: size.height * 0.29)
        let cycle = 4.6
        let progress = positiveRemainder(time, cycle) / cycle
        let baseRadius = max(1.25, spacing * 0.20)

        for (index, point) in points.enumerated() {
            let phase = Double(index) * 0.071
            let driftX = sin(time * 1.55 + phase) * Double(spacing * 0.055)
            let driftY = cos(time * 1.32 + phase * 1.7) * Double(spacing * 0.050)
            let x = origin.x + (point.x - minX) * spacing + CGFloat(driftX)
            let y = origin.y + (point.y - minY) * spacing + CGFloat(driftY)

            let hue = positiveRemainder(0.58 + progress + Double(point.x / max(gridWidth, 1)) * 0.28 + Double(point.y / max(gridHeight, 1)) * 0.08, 1.0)
            let wave = 0.5 + 0.5 * sin(2 * .pi * (progress + Double(point.x) * 0.031 - Double(point.y) * 0.019))
            let breathe = 0.5 + 0.5 * sin(2 * .pi * (progress * 2.0 + 0.08))
            let intensity = 0.22 + 0.78 * wave * (0.32 + 0.68 * breathe)
            let spectral = Color(hue: hue, saturation: 0.78, brightness: 1.0)
            let radius = baseRadius * CGFloat(0.86 + 0.16 * sin(time * 1.8 + phase))

            fillCircle(in: &context, center: CGPoint(x: x, y: y), radius: radius * 1.75, color: spectral.opacity(0.10 * intensity))
            fillCircle(in: &context, center: CGPoint(x: x, y: y), radius: radius, color: Color.white.opacity(0.22))
            fillCircle(in: &context, center: CGPoint(x: x, y: y), radius: radius * 0.88, color: spectral.opacity(0.92 * intensity))
            fillCircle(in: &context, center: CGPoint(x: x, y: y), radius: radius * 0.43, color: Color(red: 0.015, green: 0.016, blue: 0.021).opacity(0.94))
        }
    }

    private func fillCircle(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, color: Color) {
        guard radius > 0 else { return }
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func positiveRemainder(_ value: Double, _ divisor: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: divisor)
        return result < 0 ? result + divisor : result
    }

    private func localized(_ en: String, _ ru: String, _ uz: String, _ cyrl: String) -> String {
        switch language {
        case .english: return en
        case .russian: return ru
        case .uzbek: return uz
        case .uzbekCyrillic: return cyrl
        }
    }

    private struct DotPoint: Hashable {
        let x: CGFloat
        let y: CGFloat
    }

    private static let valuePoints: [DotPoint] = {
        let glyphs: [Character: [String]] = [
            "$": ["00100","01111","10100","10100","01110","00101","00101","11110","00100"],
            "1": ["00100","01100","10100","00100","00100","00100","00100","00100","11111"],
            "0": ["01110","10001","10011","10101","10101","11001","10001","10001","01110"]
        ]
        var output: [DotPoint] = []
        var xOffset: CGFloat = 0
        for character in Array("$100") {
            guard let pattern = glyphs[character] else { continue }
            let width = CGFloat(pattern.first?.count ?? 5)
            for (row, line) in pattern.enumerated() {
                for (column, value) in line.enumerated() where value == "1" {
                    output.append(DotPoint(x: xOffset + CGFloat(column), y: CGFloat(row)))
                }
            }
            xOffset += width + 1.8
        }
        return output
    }()
}

private struct GiftActivityDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(reduceMotion ? 0.46 : 0.26 + 0.54 * pulse(time: time, index: index)))
                        .frame(width: 5, height: 5)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func pulse(time: TimeInterval, index: Int) -> Double {
        0.5 + 0.5 * sin(time * 2.2 + Double(index) * 1.3)
    }
}
