//
//  Autoresolvable.swift
//  Customer.io
//
//  Created by Holly Schilling on 12/8/25.
//

public protocol Autoresolvable: Sendable {
    init(resolver: borrowing any Resolver) throws
}
