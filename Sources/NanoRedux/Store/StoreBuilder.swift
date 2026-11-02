/// Factory methods for creating stores.
public enum StoreBuilder {
    @MainActor
    public static func reducer<R: Reducer>(
        initialState: R.State,
        reducer: R,
    ) -> ReducerStore<R> {
        ReducerStore(initialState: initialState, reducer: reducer)
    }
}
