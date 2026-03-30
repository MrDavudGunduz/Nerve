import Foundation
import Testing

@testable import Core

@Suite("DependencyError Tests")
struct DependencyErrorTests {

  @Test("notRegistered has descriptive message")
  func notRegisteredDescription() {
    let error = DependencyError.notRegistered("MockService")
    #expect(error.description.contains("MockService"))
    #expect(error.description.contains("No registration found"))
  }

  @Test("typeMismatch has descriptive message")
  func typeMismatchDescription() {
    let error = DependencyError.typeMismatch(expected: "String", actual: "Int")
    #expect(error.description.contains("String"))
    #expect(error.description.contains("Int"))
  }

  @Test("circularDependency has descriptive message")
  func circularDependencyDescription() {
    let error = DependencyError.circularDependency("ServiceA")
    #expect(error.description.contains("ServiceA"))
    #expect(error.description.contains("Circular dependency"))
  }

  @Test("DependencyError conforms to Equatable")
  func equatable() {
    let a = DependencyError.notRegistered("Foo")
    let b = DependencyError.notRegistered("Foo")
    let c = DependencyError.notRegistered("Bar")

    #expect(a == b)
    #expect(a != c)
  }
}
