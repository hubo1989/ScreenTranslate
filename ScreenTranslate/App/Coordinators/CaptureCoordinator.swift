//
//  CaptureCoordinator.swift
//  ScreenTranslate
//
//  Created during architecture refactoring - extracts capture logic from AppDelegate
//
//  ## Responsibilities
//  - Full screen capture: Captures entire display via CaptureManager
//  - Selection capture: Shows overlay for user to select region
//  - Translation mode: Captures region and initiates translation flow
//
//  ## Usage
//  Access via AppDelegate.captureCoordinator:
//  ```swift
//  appDelegate.captureCoordinator?.captureFullScreen()
//  appDelegate.captureCoordinator?.captureSelection()
//  appDelegate.captureCoordinator?.startTranslationMode()
//  ```
//

import AppKit
import os

/// Coordinates all capture-related functionality:
/// full screen capture, selection capture, and translation mode capture.
///
/// This coordinator was extracted from AppDelegate as part of the architecture
/// refactoring to improve separation of concerns and testability.
@MainActor
final class CaptureCoordinator {
    // MARK: - Properties

    /// Reference to app delegate for action routing
    private weak var appDelegate: AppDelegate?

    /// Whether a capture operation is currently in progress
    private var isCaptureInProgress = false

    /// Display selector for multi-display support
    private let displaySelector = DisplaySelector()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ScreenTranslate", category: "CaptureCoordinator")

    // MARK: - Initialization

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    // MARK: - Public API

    /// Triggers a full screen capture
    func captureFullScreen() {
        // Prevent overlapping captures
        guard !isCaptureInProgress else {
            logger.debug("Capture already in progress, ignoring request")
            return
        }

        logger.info("Full screen capture triggered via hotkey or menu")

        isCaptureInProgress = true

        Task {
            defer { isCaptureInProgress = false }

            do {
                // Get available displays
                let displays = try await CaptureManager.shared.availableDisplays()

                // Select display (shows menu if multiple)
                guard let selectedDisplay = await displaySelector.selectDisplay(from: displays) else {
                    logger.debug("Display selection cancelled")
                    return
                }

                logger.info("Capturing display: \(selectedDisplay.name)")

                // Perform capture
                let screenshot = try await CaptureManager.shared.captureFullScreen(display: selectedDisplay)

                logger.info("Capture successful: \(screenshot.formattedDimensions)")

                // Show preview window
                PreviewWindowController.shared.showPreview(for: screenshot)

            } catch let error as ScreenTranslateError {
                appDelegate?.showCaptureError(error)
            } catch {
                appDelegate?.showCaptureError(.captureFailure(underlying: error))
            }
        }
    }

    /// Triggers a selection capture
    func captureSelection() {
        // Prevent overlapping captures
        guard !isCaptureInProgress else {
            logger.debug("Capture already in progress, ignoring request")
            return
        }

        logger.info("Selection capture triggered via hotkey or menu")

        isCaptureInProgress = true

        Task {
            do {
                // Present the selection overlay on all displays
                let overlayController = SelectionOverlayController.shared

                // Set up callbacks before presenting
                overlayController.onSelectionComplete = { [weak self] rect, display in
                    Task { @MainActor in
                        await self?.handleSelectionComplete(rect: rect, display: display)
                    }
                }

                overlayController.onSelectionCancel = { [weak self] in
                    Task { @MainActor in
                        self?.handleSelectionCancel()
                    }
                }

                try await overlayController.presentOverlay()

            } catch {
                isCaptureInProgress = false
                logger.error("Failed to present selection overlay: \(error.localizedDescription)")
                appDelegate?.showCaptureError(.captureFailure(underlying: error))
            }
        }
    }

    /// Starts translation mode - presents region selection for translation
    func startTranslationMode() {
        guard !isCaptureInProgress else {
            logger.debug("Capture already in progress, ignoring translation mode request")
            return
        }

        logger.info("Translation mode triggered via hotkey or menu")

        isCaptureInProgress = true

        Task {
            do {
                let overlayController = SelectionOverlayController.shared

                overlayController.onSelectionComplete = { [weak self] rect, display in
                    Task { @MainActor in
                        await self?.handleTranslationSelection(rect: rect, display: display)
                    }
                }

                overlayController.onSelectionCancel = { [weak self] in
                    Task { @MainActor in
                        self?.handleSelectionCancel()
                    }
                }

                try await overlayController.presentOverlay()

            } catch {
                isCaptureInProgress = false
                logger.error("Failed to present translation overlay: \(error.localizedDescription)")
                appDelegate?.showCaptureError(.captureFailure(underlying: error))
            }
        }
    }

    // MARK: - Private Handlers

    /// Handles successful selection completion
    private func handleSelectionComplete(rect: CGRect, display: DisplayInfo) async {
        defer { isCaptureInProgress = false }

        do {
            logger.info("Selection complete: \(Int(rect.width))×\(Int(rect.height)) on \(display.name)")

            // Capture the selected region
            let screenshot = try await CaptureManager.shared.captureRegion(rect, from: display)

            logger.info("Region capture successful: \(screenshot.formattedDimensions)")

            await MainActor.run {
                PreviewWindowController.shared.showPreview(for: screenshot)
            }

        } catch let error as ScreenTranslateError {
            appDelegate?.showCaptureError(error)
        } catch {
            appDelegate?.showCaptureError(.captureFailure(underlying: error))
        }
    }

    /// Handles translation mode selection completion
    private func handleTranslationSelection(rect: CGRect, display: DisplayInfo) async {
        defer { isCaptureInProgress = false }

        do {
            logger.info("Translation selection: \(Int(rect.width))×\(Int(rect.height)) on \(display.name)")

            let screenshot = try await CaptureManager.shared.captureRegion(rect, from: display)

            logger.info("Translation capture successful: \(screenshot.formattedDimensions)")

            TranslationFlowController.shared.startTranslation(
                image: screenshot.image,
                scaleFactor: screenshot.sourceDisplay.scaleFactor
            )

        } catch let error as ScreenTranslateError {
            appDelegate?.showCaptureError(error)
        } catch {
            appDelegate?.showCaptureError(.captureFailure(underlying: error))
        }
    }

    /// Handles selection cancellation
    private func handleSelectionCancel() {
        isCaptureInProgress = false
        logger.debug("Selection cancelled by user")
    }
}
