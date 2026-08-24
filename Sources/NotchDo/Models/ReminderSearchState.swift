struct ReminderSearchState: Equatable {
    private(set) var isPresented = false
    private(set) var focusRequest = 0
    var query = ""

    mutating func present() {
        isPresented = true
        focusRequest &+= 1
    }

    mutating func clear() {
        query = ""
        focusRequest &+= 1
    }

    mutating func dismiss() {
        query = ""
        isPresented = false
    }
}
