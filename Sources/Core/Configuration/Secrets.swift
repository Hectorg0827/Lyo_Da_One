//
//  Secrets.swift
//  Lyo
//
//  Created by Lyo Team.
//

import Foundation

struct Secrets {
    // SECURITY: Never ship client-side OpenAI keys.
    // All AI calls must go through the backend (Railway) where keys are stored as secrets.
    static let openAIKey = ""
}
