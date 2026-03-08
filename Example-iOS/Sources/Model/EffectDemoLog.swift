//
//  EffectDemoLog.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/03/09.
//

import Foundation

struct EffectDemoLog: Identifiable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let message: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        message: String,
    ) {
        self.id = id
        self.date = date
        self.message = message
    }
}
