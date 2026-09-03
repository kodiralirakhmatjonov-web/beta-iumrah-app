import Foundation
import SwiftUI

@MainActor
final class UmrahFlowState: ObservableObject {
    enum Stage: Int, CaseIterable, Hashable {
        case inUmrah
        case start
        case tawaf
        case postTawaf
        case safa
        case end
        case afterUmrah
    }

    enum RitualMode: String, CaseIterable, Hashable {
        case listening
        case reading
    }

    @Published var stage: Stage
    @Published var startPhase = 0

    @Published var tawafRound = 1
    @Published var tawafTextMode = 0
    @Published var tawafMode: RitualMode = .listening
    @Published var tawafReadingStep = 0
    @Published var tawafZikrCount = 0

    @Published var postTawafStep = 0

    @Published var safaRound = 1
    @Published var safaTextMode = 0
    @Published var safaMode: RitualMode = .listening
    @Published var safaReadingStep = 0

    @Published var endPhase = 0

    init(initialStage: Stage = .start) {
        self.stage = initialStage
    }

    var topProgress: Double {
        switch stage {
        case .inUmrah:
            return 0
        case .start:
            return 0.04 + (Double(startPhase) / 3.0) * 0.06
        case .tawaf:
            return 0.10 + (Double(tawafRound - 1) / 7.0) * 0.42
        case .postTawaf:
            return 0.52 + (Double(postTawafStep) / 4.0) * 0.08
        case .safa:
            return 0.60 + (Double(safaRound - 1) / 7.0) * 0.32
        case .end:
            return 0.94 + (Double(endPhase) / 3.0) * 0.05
        case .afterUmrah:
            return 1
        }
    }

    func resetTawafReading() {
        tawafReadingStep = 0
        tawafZikrCount = 0
    }

    func resetSafaReading() {
        safaReadingStep = 0
    }

    func reset() {
        startPhase = 0
        tawafRound = 1
        tawafTextMode = 0
        tawafMode = .listening
        resetTawafReading()
        postTawafStep = 0
        safaRound = 1
        safaTextMode = 0
        safaMode = .listening
        resetSafaReading()
        endPhase = 0
        stage = .start
    }
}

enum UmrahFlowKeys {
    static let all: Set<String> = {
        var keys: Set<String> = [
            "complete_btn", "continue_btn", "tap_btn", "sunna_dua_btn",
            "start_text", "start_text1", "start_text2", "start_text3",
            "end_text", "end_text1", "end_text3",
            "home1_title", "home1_sub", "home1_btn", "home1_btn3_sub",
            "home2_3title", "home2_3_subtitle", "home_3_btn", "home_3_btn_sub",
            "home_3_btn2", "home_3_btn2_sub", "home_3_btn3",
            "tawaf_title", "tawaf_break_title", "tawafpray_title1", "tawafpray_text1",
            "tawaf_common_text1", "tawaf_common_text2", "tawaf_common_text3", "tawaf_common_text4",
            "zamzam_title", "zamzam_title1", "zamzam_text",
            "safago_title", "safago_title1", "safago_text", "safadua_title",
            "overlay_safa_title", "overlay_safa_text1",
            "umrah_start_title", "sai_title", "tahallul_title",
            "navigate_button", "close_button", "cancel_omra"
        ]

        for round in 1...7 {
            keys.insert("tawaf\(round)_text1")
            keys.insert("tawaf\(round)_text2")
            keys.insert("tawaf\(round)_tarab1")
            keys.insert("tawaf\(round)_zikr_text")
            keys.insert("tawaf\(round)_zikr_repeat")
            for arabicIndex in 1...3 {
                keys.insert("tawaf\(round)_reading_arab\(arabicIndex)")
            }
            for textIndex in 1...6 {
                keys.insert("tawaf\(round)_reading_text\(textIndex)")
            }

            keys.insert("safa\(round)_title1")
            keys.insert("safa\(round)_text1")
            keys.insert("safa\(round)_text2")
            keys.insert("safa\(round)_sarab1")
        }
        return keys
    }()
}
