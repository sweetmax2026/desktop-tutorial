// Models.swift
// Bikini Bottom HRV Monitor
// 数据模型

import Foundation
import SwiftUI

// MARK: - HRV 读数
struct HRVReading: Identifiable {
    let id = UUID()
    let timestamp: Date
    let sdnn: Double       // SDNN 毫秒值
    let source: String     // 数据来源（如 "Apple Watch"）
}

/// 用每天的 HRV 中位数绘制趋势，避免同一天有多条读数时图表过于嘈杂。
struct HRVDailyPoint: Identifiable {
    let date: Date
    let sdnn: Double

    var id: Date { date }
}

// MARK: - HRV 状态
enum HRVStatus: String, CaseIterable {
    case good     = "GOOD"
    case moderate = "MODERATE"
    case stressed = "STRESSED"
    case unknown  = "UNKNOWN"

    /// 数据尚不充分时使用 emoji，已有主题角色时改用资源图。
    var emoji: String {
        switch self {
        case .good:     return "🧽"  // 海绵宝宝 — 恢复好
        case .moderate: return "⭐"  // 派大星 — 一般
        case .stressed: return "🐙"  // 章鱼哥 — 压力高
        case .unknown:  return "🌊"
        }
    }

    var characterAssetName: String? {
        switch self {
        case .good: return "CharacterGood"
        case .moderate: return "CharacterModerate"
        case .stressed: return "CharacterStressed"
        case .unknown: return nil
        }
    }

    /// 中文标签
    var label: String {
        switch self {
        case .good:     return "恢复很棒！"
        case .moderate: return "还行"
        case .stressed: return "压力有点大"
        case .unknown:  return "等待数据…"
        }
    }

    /// 海底主题的状态文案。避免将 HRV 解释为医疗诊断。
    var themeQuote: String {
        switch self {
        case .good:     return "我准备好了！"
        case .moderate: return "我们去抓水母吧！"
        case .stressed: return "今天需要一点安静。"
        case .unknown:  return "正在从健康数据里寻找今天的信号。"
        }
    }

    var reminderTitle: String {
        switch self {
        case .stressed: return "今天先放慢一点"
        case .moderate: return "来一次小小的暂停"
        case .good: return "今天状态不错"
        case .unknown: return "HRV 有新消息"
        }
    }

    func reminderBody(latestHRV: Double, baseline: Double) -> String {
        switch self {
        case .stressed:
            return "最新 HRV (Int(latestHRV)) ms，低于你的 7 天基线 (Int(baseline)) ms。先喝口水、深呼吸一下吧。"
        case .moderate:
            return "最新 HRV 是 (Int(latestHRV)) ms。今天可以给自己留一点缓冲时间。"
        case .good:
            return "最新 HRV 是 (Int(latestHRV)) ms。继续保持舒服的节奏。"
        case .unknown:
            return "健康数据有更新，打开 App 看看今天的状态。"
        }
    }

    /// 主题色
    var themeColor: Color {
        switch self {
        case .good:     return Color(red: 1.0, green: 0.85, blue: 0.0)   // 海绵宝宝黄
        case .moderate: return Color(red: 1.0, green: 0.6, blue: 0.7)    // 派大星粉
        case .stressed: return Color(red: 0.0, green: 0.7, blue: 0.7)    // 章鱼哥青
        case .unknown:  return Color(red: 0.2, green: 0.5, blue: 0.9)    // 海洋蓝
        }
    }

    /// 背景渐变色
    var backgroundGradient: LinearGradient {
        switch self {
        case .good:
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.15, blue: 0.4), Color(red: 0.1, green: 0.3, blue: 0.15)],
                startPoint: .top, endPoint: .bottom
            )
        case .moderate:
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.15, blue: 0.4), Color(red: 0.3, green: 0.2, blue: 0.35)],
                startPoint: .top, endPoint: .bottom
            )
        case .stressed:
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.15, blue: 0.4), Color(red: 0.35, green: 0.1, blue: 0.1)],
                startPoint: .top, endPoint: .bottom
            )
        case .unknown:
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.15, blue: 0.4), Color(red: 0.1, green: 0.2, blue: 0.4)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}
