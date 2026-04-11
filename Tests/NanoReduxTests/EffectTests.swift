import NanoRedux
import Testing

@MainActor
@Test func `effect execute`() async {
    struct TestAction: Sendable {
        let value: String
    }

    let effect = Effect<TestAction>.run {
        TestAction(value: "hello")
    }

    let result = await effect.execute()

    #expect(result?.value == "hello")
}

@MainActor
@Test func `effect map`() async {
    struct TestAction: Sendable {
        let value: Int
    }
    struct NewAction: Sendable {
        let doubled: Int
    }

    let effect = Effect<TestAction>.run {
        TestAction(value: 5)
    }.map { action in
        NewAction(doubled: action.value * 2)
    }

    let result = await effect.execute() as NewAction?

    #expect(result?.doubled == 10)
}

@MainActor
@Test func `effect none`() async {
    struct TestAction: Sendable {}

    let effect = Effect<TestAction>.none

    let result = await effect.execute()

    #expect(result == nil)
}

@MainActor
@Test func `effect lifetime`() {
    struct TestAction: Sendable {}

    let effect1 = Effect<TestAction>.none
    let effect2 = Effect<TestAction>.run { nil }

    #expect(effect1.lifetime == effect2.lifetime)
}
