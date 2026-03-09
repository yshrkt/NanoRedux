//
//  EffectDemoView.swift
//  Example-iOS
//
//  Created by Yoshihiro Kato on 2026/03/09.
//

import NanoRedux
import SwiftUI

struct EffectDemoView: View {
    @State private var store: Store<EffectDemoFeature.State, EffectDemoFeature.Action>

    init(store: Store<EffectDemoFeature.State, EffectDemoFeature.Action>) {
        self.store = store
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    demoSection(
                        title: "Concat",
                        description: "Runs child effects in declaration order.",
                    ) {
                        Button("Run Concat Demo") {
                            store.send(.concatTapped)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    demoSection(
                        title: "Merge",
                        description: "Runs child effects concurrently.",
                    ) {
                        Button("Run Merge Demo") {
                            store.send(.mergeTapped)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    demoSection(
                        title: "Throttle",
                        description: "Leading-only. Repeated taps within one second are ignored.",
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Tap Rapidly") {
                                store.send(.throttleTapped)
                            }
                            .buttonStyle(.borderedProminent)

                            Text("Throttle fired: \(store.state.throttleCount)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    demoSection(
                        title: "Debounce",
                        description: "Waits for typing to settle before committing the latest value.",
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(
                                "Type to debounce",
                                text: Binding(
                                    get: { store.state.debounceInputText },
                                    set: { store.send(.debounceInputChanged($0)) },
                                ),
                            )
                            .textFieldStyle(.roundedBorder)

                            Text("Debounced text: \(store.state.debouncedText)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .contentMargins(.bottom, 300, for: .scrollContent)
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Event Log")
                        .font(.headline)
                        .frame(maxWidth: .infinity)

                    if store.state.logs.isEmpty {
                        Text("No events yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(store.state.logs) { log in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(log.message)
                                            .font(.caption)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Text(log.date, format: .dateTime.hour().minute().second())
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                        .contentMargins(.bottom, 80, for: .scrollContent)
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal)
                .frame(maxHeight: 300)
                .background(.background)
                .overlay(alignment: .topLeading) {
                    Divider()
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .navigationTitle("Effects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        store.send(.resetTapped)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func demoSection(
        title: String,
        description: String,
        @ViewBuilder content: () -> some View,
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    EffectDemoView(store: .reducer(
        initialState: .init(),
        reducer: EffectDemoFeature.Reducer(),
        dependencies: (),
    ))
}
