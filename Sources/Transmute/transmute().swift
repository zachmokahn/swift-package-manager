/*
 This source file is part of the Swift.org open source project

 Copyright 2015 - 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageType
import Utility
import func libc.exit

public func transmute(packages: [Package], rootdir: String) throws -> ([Module], [Product]) {

    var products: [Product] = []
    var map: [Package: [Module]] = [:]

    for package in packages {

        let modules: [Module]
        do {
            modules = try package.modules()
        } catch Package.ModuleError.NoModules(let pkg) where pkg.path == rootdir {
            //Ignore and print warning if root package doesn't contain any sources
            print("warning: root package '\(pkg)' does not contain any sources")
            if packages.count == 1 { exit(0) } //Exit now if there is no more packages 
            modules = []
        }

        let testModules = try package.testModules()
        products += try package.products(modules, tests: testModules)

        // Set dependencies for test modules.
        for testModule in testModules {
            if testModule.basename == "Functional" {
                // FIXME: swiftpm's own Functional tests module does not
                //        follow the normal rules--there is no corresponding
                //        'Sources/Functional' module to depend upon. For the
                //        time being, assume test modules named 'Functional'
                //        depend upon 'Utility', and hope that no users define
                //        test modules named 'Functional'.
                testModule.dependencies = modules.filter{ $0.name == "Utility" }
            } else {
                // Normally, test modules are only dependent upon modules with
                // the same basename. For example, a test module in
                // 'Root/Tests/Foo' is dependent upon 'Root/Sources/Foo'.
                testModule.dependencies = modules.filter{ $0.name == testModule.basename }
            }
        }

        map[package] = modules + testModules.map{$0}
    }

    // ensure modules depend on the modules of any dependent packages
    fillModuleGraph(packages, modulesForPackage: { map[$0]! })

    var set = Set<Module>()
    var stack = packages.flatMap{ map[$0] ?? [] }
    var modules = [Module]()

    while !stack.isEmpty {
        let module = stack.removeFirst()
        if !set.contains(module) {
            set.insert(module)
            stack += module.dependencies
            modules.append(module)
        }
    }

    return (modules, products)
}
