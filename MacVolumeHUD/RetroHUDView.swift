import SwiftUI

struct RetroHUDView: View {
    @ObservedObject var hudState: HUDWindowManager.DisplayState
    @AppStorage("hudSize") private var hudSize: String = "Medium"
    let totalSteps = 16
    let fineStepsPerSegment = 4
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28 * scaleMultiplier)
            
            Image(systemName: iconName)
                .font(.system(size: 74 * scaleMultiplier, weight: .regular))
                .frame(width: 88 * scaleMultiplier, height: 88 * scaleMultiplier)
                .foregroundColor(foregroundColor)
            
            Spacer(minLength: 0)
            
            Canvas { context, size in
                let scale = scaleMultiplier
                let segW: CGFloat = 8.0 * scale
                let segH: CGFloat = 9.0 * scale
                let segSpacing: CGFloat = 1.0 * scale
                let totalW = CGFloat(totalSteps) * segW + CGFloat(totalSteps - 1) * segSpacing
                let startX = (size.width - totalW) / 2
                let startY: CGFloat = 0

                let trackRect = CGRect(x: startX, y: startY, width: totalW, height: segH)
                context.fill(Path(trackRect), with: .color(foregroundColor))

                let filledWidth = totalW * (CGFloat(activeFineSteps) / CGFloat(totalSteps * fineStepsPerSegment))
                if filledWidth > 0 {
                    let fillRect = CGRect(x: startX, y: startY, width: filledWidth, height: segH)
                    context.fill(Path(fillRect), with: .color(filledCellColor))

                    for step in 1..<totalSteps {
                        let dividerX = startX + CGFloat(step) * segW + CGFloat(step - 1) * segSpacing
                        if dividerX >= fillRect.maxX { break }
                        let dividerRect = CGRect(x: dividerX, y: startY, width: segSpacing, height: segH)
                        context.fill(Path(dividerRect), with: .color(foregroundColor))
                    }
                }
            }
            .frame(width: 200 * scaleMultiplier, height: 11 * scaleMultiplier)
            .padding(.bottom, 27 * scaleMultiplier)
        }
        .frame(width: 200 * scaleMultiplier, height: 200 * scaleMultiplier)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
    
    private var scaleMultiplier: CGFloat {
        switch hudSize {
        case "Small": return 0.75
        case "Large": return 1.25
        default: return 1.0
        }
    }
    
    /// Number of fine-grained steps (0–64) so Option+Shift also nudges the bar.
    private var activeFineSteps: Int {
        switch hudState.kind {
        case .volume:
            if hudState.isMuted || hudState.volume == 0 { return 0 }
            return Int(round(Double(hudState.volume) * Double(totalSteps * fineStepsPerSegment)))
        case .brightness:
            return Int(round(Double(hudState.brightness) * Double(totalSteps * fineStepsPerSegment)))
        }
    }
    
    private var iconName: String {
        switch hudState.kind {
        case .volume:
            if hudState.isMuted || hudState.volume == 0 {
                return "speaker.slash.fill"
            } else if hudState.volume <= 0.33 {
                return "speaker.wave.1.fill"
            } else if hudState.volume <= 0.66 {
                return "speaker.wave.2.fill"
            } else {
                return "speaker.wave.3.fill"
            }
        case .brightness:
            return "sun.max.fill"
        }
    }
    
    private var foregroundColor: Color {
        Color(red: 0.50, green: 0.50, blue: 0.50).opacity(0.98)
    }
    
    private var filledCellColor: Color {
        Color(red: 0.95, green: 0.95, blue: 0.95).opacity(1.0)
    }
}
