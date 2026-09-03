import Foundation
import SwiftUI

@MainActor
final class UmrahFlowState: ObservableObject {
    enum Stage: Int, CaseIterable {
        case inUmrah
        case start
        case tawaf
        case postTawaf
        case safa
        case end
        case afterUmrah
    }

    @Published var stage: Stage
    @Published var startPhase = 0
    @Published var tawafRound = 1
    @Published var tawafTextMode = 0
    @Published var postTawafStep = 0
    @Published var safaRound = 1
    @Published var safaTextMode = 0
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

    func reset() {
        startPhase = 0
        tawafRound = 1
        tawafTextMode = 0
        postTawafStep = 0
        safaRound = 1
        safaTextMode = 0
        endPhase = 0
        stage = .start
    }
}

enum UmrahFlowKeys {
    static let all: Set<String> = {
        var keys: Set<String> = [
            "complete_btn", "continue_btn", "end_text", "end_text1", "end_text3",
            "home_3_btn", "home_3_btn_sub", "home_3_btn2", "home_3_btn2_sub",
            "home_3_btn3", "home_3_btn3_sub", "home_btn2_sub", "home_btn3",
            "home_btn5", "home_btn5_sub", "home_btnp", "home1_btn", "home1_btn2",
            "home1_btn3", "home1_btn3_sub", "home1_btn6_sub", "home1_sub",
            "home1_title", "home1_title2", "home1_title2_sub", "home1_title3",
            "home1_title3_sub", "home2_3_subtitle", "home2_3title", "home2_title2",
            "home2_title2_sub", "home2_title3", "home2_title3_sub", "safadua_title",
            "safago_text", "safago_title", "safago_title1", "start_text", "start_text1",
            "start_text2", "start_text3", "sunna_dua_btn", "tap_btn", "tawaf_common_text1",
            "tawaf_common_text2", "tawaf_common_text3", "tawaf_common_text4", "tawaf_title",
            "tawafpray_text1", "tawafpray_title1", "zamzam_text", "zamzam_title",
            "zamzam_title1"
        ]

        for round in 1...7 {
            keys.insert("tawaf\(round)_text1")
            keys.insert("tawaf\(round)_text2")
            keys.insert("tawaf\(round)_tarab1")
            keys.insert("safa\(round)_title1")
            keys.insert("safa\(round)_text1")
            keys.insert("safa\(round)_text2")
            keys.insert("safa\(round)_sarab1")
        }
        return keys
    }()
}
