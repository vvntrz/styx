//
//  System.swift
//  styx
//
//  Created by VVinters on 2026-01-26.
//

import Foundation

struct Sys {
    public func envVar(key: String) -> String {
        return ProcessInfo.processInfo.environment[key] ?? ""
    }
    public func getFN(from string: String) -> String {
        if let theRange = string.range(of: ".", options: .backwards),
            let i = string[theRange.upperBound...] as Substring? {
            return String(i)
        } else {
            return ""
        }
    }
}
