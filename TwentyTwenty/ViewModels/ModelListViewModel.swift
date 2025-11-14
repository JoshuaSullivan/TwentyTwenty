import Foundation
import Observation

/// ViewModel for the main model list view with filtering capabilities
@Observable
@MainActor
final class ModelListViewModel {
    // MARK: - Published Properties

    /// Currently selected minimum iOS version filter (nil = no filter)
    var selectedIOSVersion: Double?

    /// Filtered list of models based on current filter
    var filteredModels: [VisionModel] {
        if let selectedIOSVersion {
            return VisionModelRegistry.models(availableIn: selectedIOSVersion)
        }
        return VisionModelRegistry.allModels
    }

    /// All available iOS versions for the filter picker
    var availableIOSVersions: [Double] {
        VisionModelRegistry.availableIOSVersions
    }

    /// Models grouped by category
    var modelsByCategory: [(category: VisionModelCategory, models: [VisionModel])] {
        let grouped = Dictionary(grouping: filteredModels) { $0.category }
        return VisionModelCategory.allCases.compactMap { category in
            guard let models = grouped[category], !models.isEmpty else { return nil }
            return (category, models.sorted { $0.name < $1.name })
        }
    }

    // MARK: - Initialization

    init() {
        self.selectedIOSVersion = nil
    }

    // MARK: - Public Methods

    /// Clears the iOS version filter
    func clearFilter() {
        selectedIOSVersion = nil
    }

    /// Sets the iOS version filter
    /// - Parameter version: The minimum iOS version to filter by
    func setFilter(to version: Double?) {
        selectedIOSVersion = version
    }
}
