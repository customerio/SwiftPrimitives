//
//  DefaultInitializable.swift
//  Customer.io
//
//  Created by Holly Schilling on 12/9/25.
//

public protocol DefaultInitializable {
    static func create() -> sending Self
    init()
}

extension DefaultInitializable where Self: Sendable {
    public static func create() -> sending Self {
        return self.init()
    }
}
