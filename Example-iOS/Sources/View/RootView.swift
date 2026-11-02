//
//  RootView.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/02/21.
//
import NanoRedux
import SwiftUI

struct RootView: View {
    @State private var store: any Store<AppFeature.State, AppFeature.Action>

    init(store: any Store<AppFeature.State, AppFeature.Action>) {
        self.store = store
    }

    var body: some View {
        let _ = Self._printChanges()
        TabView {
            TodoView(store: store.todoStore)
                .tabItem {
                    Label("Todos", systemImage: "checklist")
                }

            EffectDemoView(store: store.effectsStore)
                .tabItem {
                    Label("Effects", systemImage: "bolt.horizontal.circle")
                }

            SettingsView(store: store.settingsStore)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .onAppear {
            store.send(.appLaunched)
        }
    }
}

private extension Store where State == AppFeature.State, Action == AppFeature.Action {
    var todoStore: any Store<TodoFeature.State, TodoFeature.Action> {
        scope(state: { $0.todo }, action: { .todo($0) })
    }

    var effectsStore: any Store<EffectDemoFeature.State, EffectDemoFeature.Action> {
        scope(state: { $0.effects }, action: { .effects($0) })
    }

    var settingsStore: any Store<SettingsFeature.State, SettingsFeature.Action> {
        scope(state: { $0.settings }, action: { .settings($0) })
    }
}

#Preview {
    RootView(store: StoreBuilder.reducer(
        initialState: .init(),
        reducer: AppFeature.Reducer(
            dependencies: AppFeature.Dependencies(todo: .init(repository: MockTodoRepository())),
        ),
    ))
}
