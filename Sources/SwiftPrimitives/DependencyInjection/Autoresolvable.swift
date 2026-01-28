//
//  Autoresolvable.swift
//  Customer.io
//
//  Created by Holly Schilling on 12/8/25.
//

public protocol Autoresolvable {
    static func create(resolver: borrowing any Resolver) throws -> sending Self
    init(resolver: borrowing any Resolver) throws
}

extension Autoresolvable where Self: Sendable {
    public static func create(resolver: borrowing any Resolver) throws -> sending Self {
        return try Self.init(resolver: resolver)
    }
}
