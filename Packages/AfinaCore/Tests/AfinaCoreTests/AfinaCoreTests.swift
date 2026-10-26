import Testing
@testable import AfinaCore

@Test func packageLoads() {
    #expect(!AfinaCore.version.isEmpty)
}
