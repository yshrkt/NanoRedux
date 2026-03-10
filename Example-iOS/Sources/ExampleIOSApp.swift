//
//  ExampleiOSApp.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/02/21.
//
import NanoRedux
import SwiftUI

@main
struct ExampleIOSApp: App {
    @State private var appStore = Store.reducer(
        initialState: AppFeature.State(),
        reducer: AppFeature.Reducer(dependencies: .init(todo: .init(repository: MockTodoRepository()))),
    )

    var body: some Scene {
        WindowGroup {
            RootView(store: appStore)
        }
    }
}
