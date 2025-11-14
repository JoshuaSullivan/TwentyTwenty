import Testing
import Foundation
@testable import TwentyTwenty

/// Unit tests for ModelListViewModel
@MainActor
struct ModelListViewModelTests {

    // MARK: - Initialization Tests

    @Test("ViewModel initializes with no filter selected")
    func testInitialState() {
        let viewModel = ModelListViewModel()

        #expect(viewModel.selectedIOSVersion == nil)
        #expect(viewModel.filteredModels.count == VisionModelRegistry.allModels.count)
    }

    // MARK: - Filtering Tests

    @Test("Filtering by iOS version returns correct models")
    func testFilteringByVersion() {
        let viewModel = ModelListViewModel()

        // All models in the registry are iOS 18.0
        viewModel.setFilter(to: 18.0)

        #expect(viewModel.selectedIOSVersion == 18.0)
        #expect(viewModel.filteredModels.count == VisionModelRegistry.allModels.count)
    }

    @Test("Filtering by higher iOS version returns no models when none available")
    func testFilteringHigherVersion() {
        let viewModel = ModelListViewModel()

        // Filter for iOS 27.0 (doesn't exist yet)
        viewModel.setFilter(to: 27.0)

        #expect(viewModel.selectedIOSVersion == 27.0)
        #expect(viewModel.filteredModels.isEmpty)
    }

    @Test("Clearing filter shows all models")
    func testClearFilter() {
        let viewModel = ModelListViewModel()

        // Set filter first
        viewModel.setFilter(to: 18.0)
        #expect(viewModel.selectedIOSVersion == 18.0)

        // Clear filter
        viewModel.clearFilter()

        #expect(viewModel.selectedIOSVersion == nil)
        #expect(viewModel.filteredModels.count == VisionModelRegistry.allModels.count)
    }

    @Test("Setting filter to nil shows all models")
    func testSetFilterToNil() {
        let viewModel = ModelListViewModel()

        viewModel.setFilter(to: 18.0)
        #expect(viewModel.selectedIOSVersion == 18.0)

        viewModel.setFilter(to: nil)

        #expect(viewModel.selectedIOSVersion == nil)
        #expect(viewModel.filteredModels.count == VisionModelRegistry.allModels.count)
    }

    // MARK: - Available Versions Tests

    @Test("Available iOS versions returns non-empty array")
    func testAvailableVersions() {
        let viewModel = ModelListViewModel()

        #expect(!viewModel.availableIOSVersions.isEmpty)
        #expect(viewModel.availableIOSVersions.contains(18.0))
    }

    @Test("Available iOS versions are sorted")
    func testAvailableVersionsSorted() {
        let viewModel = ModelListViewModel()
        let versions = viewModel.availableIOSVersions

        #expect(versions == versions.sorted())
    }

    // MARK: - Grouped Models Tests

    @Test("Models grouped by category returns non-empty groups")
    func testModelsByCategory() {
        let viewModel = ModelListViewModel()
        let grouped = viewModel.modelsByCategory

        #expect(!grouped.isEmpty)

        // Verify all models are accounted for
        let totalModelsInGroups = grouped.reduce(0) { $0 + $1.models.count }
        #expect(totalModelsInGroups == viewModel.filteredModels.count)
    }

    @Test("Models within each category are sorted by name")
    func testModelsWithinCategorySorted() {
        let viewModel = ModelListViewModel()
        let grouped = viewModel.modelsByCategory

        for group in grouped {
            let names = group.models.map { $0.name }
            #expect(names == names.sorted())
        }
    }

    @Test("Grouped models respect filter")
    func testGroupedModelsRespectFilter() {
        let viewModel = ModelListViewModel()

        // With filter
        viewModel.setFilter(to: 18.0)
        let groupedWithFilter = viewModel.modelsByCategory
        let totalWithFilter = groupedWithFilter.reduce(0) { $0 + $1.models.count }

        // Without filter
        viewModel.clearFilter()
        let groupedWithoutFilter = viewModel.modelsByCategory
        let totalWithoutFilter = groupedWithoutFilter.reduce(0) { $0 + $1.models.count }

        // Both should have the same count since all models are iOS 18.0
        #expect(totalWithFilter == totalWithoutFilter)
    }

    // MARK: - Integration Tests

    @Test("Changing filter multiple times works correctly")
    func testMultipleFilterChanges() {
        let viewModel = ModelListViewModel()
        let initialCount = viewModel.filteredModels.count

        // Change filter multiple times
        viewModel.setFilter(to: 18.0)
        let count1 = viewModel.filteredModels.count

        viewModel.setFilter(to: 19.0)
        let count2 = viewModel.filteredModels.count

        viewModel.clearFilter()
        let count3 = viewModel.filteredModels.count

        #expect(count1 == initialCount) // All models are 18.0
        #expect(count2 == 0) // No models for 19.0 yet
        #expect(count3 == initialCount) // Back to all models
    }
}
