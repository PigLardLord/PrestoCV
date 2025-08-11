import Foundation

/// A generic state enumeration for view models that need to track loading states
enum ViewState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)
    
    /// Indicates if the view is currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    /// Returns the error message if in error state
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
    
    /// Returns the loaded data if in loaded state
    var data: T? {
        if case .loaded(let data) = self {
            return data
        }
        return nil
    }
    
    /// Returns a new ViewState with the error cleared
    func clearingError() -> ViewState<T> {
        switch self {
        case .error:
            return .idle
        default:
            return self
        }
    }
}