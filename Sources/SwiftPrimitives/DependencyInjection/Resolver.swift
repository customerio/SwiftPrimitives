//
//  Resolver.swift
//  Customer.io
//
//  Created by Holly Schilling on 12/8/25.
//

public protocol Resolver: ~Escapable & ~Copyable {
    var container: DependencyContainer { get }
    func resolve<T>() throws -> sending T
}
