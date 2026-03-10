//
//  SettingsView.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/02/21.
//
import NanoRedux
import SwiftUI

struct SettingsView: View {
    @State private var store: Store<SettingsFeature.State, SettingsFeature.Action>

    init(store: Store<SettingsFeature.State, SettingsFeature.Action>) {
        self.store = store
    }

    var body: some View {
        let _ = Self._printChanges()
        NavigationStack {
            Form {
                Toggle(
                    "Enable notifications",
                    isOn: Binding(
                        get: { store.state.notificationsEnabled },
                        set: { store.send(.toggleNotifications($0)) },
                    ),
                )
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView(store: .reducer(
        initialState: .init(),
        reducer: SettingsFeature.Reducer(),
    ))
}
