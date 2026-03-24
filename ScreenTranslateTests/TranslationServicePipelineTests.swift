import XCTest
@testable import ScreenTranslate

@available(macOS 13.0, *)
actor MockTranslationProvider: TranslationProvider, TranslationPromptConfigurable, TranslationPromptContextProviding {
    struct Request: Sendable, Equatable {
        let texts: [String]
        let sourceLanguage: String?
        let targetLanguage: String
    }

    nonisolated let id: String
    nonisolated let name: String

    private var available: Bool
    private var translateError: Error?
    private var batchResults: [TranslationResult]
    private var checkConnectionResult: Bool
    private var promptContextID: String?
    private(set) var requests: [Request] = []
    private(set) var promptTemplates: [String?] = []

    init(
        id: String,
        name: String,
        available: Bool = true,
        batchResults: [TranslationResult] = [],
        translateError: Error? = nil,
        checkConnectionResult: Bool = true,
        promptContextID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.available = available
        self.batchResults = batchResults
        self.translateError = translateError
        self.checkConnectionResult = checkConnectionResult
        self.promptContextID = promptContextID
    }

    var isAvailable: Bool {
        get async { available }
    }

    func translate(
        text: String,
        from sourceLanguage: String?,
        to targetLanguage: String
    ) async throws -> TranslationResult {
        let results = try await translate(
            texts: [text],
            from: sourceLanguage,
            to: targetLanguage
        )
        guard let result = results.first else {
            XCTFail("MockTranslationProvider returned no results for a single-text request")
            throw TranslationProviderError.translationFailed("MockTranslationProvider returned no results")
        }
        return result
    }

    func translate(
        texts: [String],
        from sourceLanguage: String?,
        to targetLanguage: String
    ) async throws -> [TranslationResult] {
        try await translate(
            texts: texts,
            from: sourceLanguage,
            to: targetLanguage,
            promptTemplate: nil
        )
    }

    func translate(
        texts: [String],
        from sourceLanguage: String?,
        to targetLanguage: String,
        promptTemplate: String?
    ) async throws -> [TranslationResult] {
        requests.append(
            Request(texts: texts, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        )
        promptTemplates.append(promptTemplate)

        if let translateError {
            throw translateError
        }

        if batchResults.count == texts.count {
            return batchResults
        }

        if batchResults.count == 1, let first = batchResults.first {
            return texts.map { text in
                TranslationResult(
                    sourceText: text,
                    translatedText: first.translatedText,
                    sourceLanguage: first.sourceLanguage,
                    targetLanguage: first.targetLanguage
                )
            }
        }

        return texts.map { text in
            TranslationResult(
                sourceText: text,
                translatedText: "\(text) -> \(targetLanguage)",
                sourceLanguage: sourceLanguage ?? "Auto",
                targetLanguage: targetLanguage
            )
        }
    }

    func checkConnection() async -> Bool {
        checkConnectionResult
    }

    func requestCount() async -> Int {
        requests.count
    }

    func lastPromptTemplate() async -> String? {
        promptTemplates.last.flatMap { $0 }
    }

    func compatiblePromptIdentifier() async -> String? {
        promptContextID
    }
}

@available(macOS 13.0, *)
actor MockTranslationServicing: TranslationServicing {
    struct Request: Sendable, Equatable {
        let segments: [String]
        let targetLanguage: String
        let preferredEngine: TranslationEngineType
        let sourceLanguage: String?
        let scene: TranslationScene?
        let mode: EngineSelectionMode
        let fallbackEnabled: Bool
        let parallelEngines: [TranslationEngineType]
        let sceneBindings: [TranslationScene: SceneEngineBinding]
    }

    private var nextResult: [BilingualSegment]
    private var nextError: Error?
    private(set) var requests: [Request] = []

    init(nextResult: [BilingualSegment] = [], nextError: Error? = nil) {
        self.nextResult = nextResult
        self.nextError = nextError
    }

    func translate(
        segments: [String],
        to targetLanguage: String,
        preferredEngine: TranslationEngineType,
        from sourceLanguage: String?,
        scene: TranslationScene?,
        mode: EngineSelectionMode,
        fallbackEnabled: Bool,
        parallelEngines: [TranslationEngineType],
        sceneBindings: [TranslationScene: SceneEngineBinding]
    ) async throws -> [BilingualSegment] {
        requests.append(
            Request(
                segments: segments,
                targetLanguage: targetLanguage,
                preferredEngine: preferredEngine,
                sourceLanguage: sourceLanguage,
                scene: scene,
                mode: mode,
                fallbackEnabled: fallbackEnabled,
                parallelEngines: parallelEngines,
                sceneBindings: sceneBindings
            )
        )

        if let nextError {
            throw nextError
        }

        return nextResult
    }

    func requestCount() async -> Int {
        requests.count
    }
}

@available(macOS 13.0, *)
final class TranslationServicePipelineTests: XCTestCase {
    private func makeResult(
        source: String,
        translated: String,
        sourceLanguage: String = "English",
        targetLanguage: String = "Chinese"
    ) -> TranslationResult {
        TranslationResult(
            sourceText: source,
            translatedText: translated,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }

    func testPrimaryEngineAppliesCustomPromptAndReturnsBundle() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let apple = MockTranslationProvider(
            id: "apple",
            name: "Apple",
            batchResults: [
                makeResult(source: "Hello", translated: "你好"),
                makeResult(source: "World", translated: "世界")
            ]
        )
        await registry.register(apple, for: .apple)

        let service = TranslationService(registry: registry)
        await service.updatePromptConfig(
            TranslationPromptConfig(
                enginePrompts: [.apple: "Custom prompt {text}"]
            )
        )

        let bundle = try await service.translate(
            segments: ["Hello", "World"],
            to: "zh-Hans",
            from: "en",
            scene: .translateAndInsert,
            mode: .primaryWithFallback,
            preferredEngine: .apple,
            fallbackEnabled: false
        )

        XCTAssertEqual(bundle.primaryEngine, .apple)
        XCTAssertEqual(bundle.selectionMode, .primaryWithFallback)
        XCTAssertEqual(bundle.primaryResult.map(\.translated), ["你好", "世界"])
        let appleRequests = await apple.requests
        let applePromptTemplate = await apple.lastPromptTemplate()
        XCTAssertEqual(appleRequests, [
            MockTranslationProvider.Request(
                texts: ["Hello", "World"],
                sourceLanguage: "en",
                targetLanguage: "zh-Hans"
            )
        ])
        XCTAssertEqual(applePromptTemplate, "Custom prompt {text}")
    }

    func testTranslateAndInsertUsesDefaultInsertPromptWhenNoCustomPromptExists() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let apple = MockTranslationProvider(
            id: "apple",
            name: "Apple",
            batchResults: [
                makeResult(source: "Translate me", translated: "请翻译我")
            ]
        )
        await registry.register(apple, for: .apple)

        let service = TranslationService(registry: registry)

        _ = try await service.translate(
            segments: ["Translate me"],
            to: "zh-Hans",
            from: "en",
            scene: .translateAndInsert,
            mode: .primaryWithFallback,
            preferredEngine: .apple,
            fallbackEnabled: false
        )

        let promptTemplate = await apple.lastPromptTemplate()
        XCTAssertEqual(promptTemplate, TranslationPromptConfig.defaultInsertPrompt)
    }

    func testCustomEngineUsesCompatiblePromptForSelectedProviderInstance() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let custom = MockTranslationProvider(
            id: "custom:1",
            name: "Custom",
            batchResults: [
                makeResult(source: "Translate me", translated: "翻译我")
            ],
            promptContextID: "compatible-provider-1"
        )
        await registry.register(custom, for: .custom)

        let service = TranslationService(registry: registry)
        await service.updatePromptConfig(
            TranslationPromptConfig(
                compatibleEnginePrompts: ["compatible-provider-1": "Compatible prompt {text}"]
            )
        )

        _ = try await service.translate(
            segments: ["Translate me"],
            to: "zh-Hans",
            from: "en",
            scene: .translateAndInsert,
            mode: .primaryWithFallback,
            preferredEngine: .custom,
            fallbackEnabled: false
        )

        let promptTemplate = await custom.lastPromptTemplate()
        XCTAssertEqual(promptTemplate, "Compatible prompt {text}")
    }

    func testPrimaryWithFallbackUsesFallbackWhenPrimaryFails() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let primary = MockTranslationProvider(
            id: "apple",
            name: "Apple",
            translateError: TranslationProviderError.connectionFailed("primary offline")
        )
        let fallback = MockTranslationProvider(
            id: "mtran",
            name: "MTran",
            batchResults: [
                makeResult(source: "Hello", translated: "你好")
            ]
        )

        await registry.register(primary, for: .apple)
        await registry.register(fallback, for: .mtranServer)

        let service = TranslationService(registry: registry)

        let bundle = try await service.translate(
            segments: ["Hello"],
            to: "zh-Hans",
            from: "en",
            mode: .primaryWithFallback,
            preferredEngine: .apple,
            fallbackEnabled: true
        )

        XCTAssertEqual(bundle.primaryEngine, .mtranServer)
        XCTAssertEqual(bundle.successfulEngines, [.mtranServer])
        XCTAssertEqual(bundle.failedEngines, [.apple])
        let primaryRequestCount = await primary.requestCount()
        let fallbackRequestCount = await fallback.requestCount()
        XCTAssertEqual(primaryRequestCount, 1)
        XCTAssertEqual(fallbackRequestCount, 1)
    }

    func testUnavailablePrimaryEngineFallsBackWithoutExecutingPrimaryTranslation() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let primary = MockTranslationProvider(
            id: "apple",
            name: "Apple",
            available: false,
            batchResults: [
                makeResult(source: "Hello", translated: "你好")
            ]
        )
        let fallback = MockTranslationProvider(
            id: "mtran",
            name: "MTran",
            batchResults: [
                makeResult(source: "Hello", translated: "您好")
            ]
        )

        await registry.register(primary, for: .apple)
        await registry.register(fallback, for: .mtranServer)

        let service = TranslationService(registry: registry)

        let bundle = try await service.translate(
            segments: ["Hello"],
            to: "zh-Hans",
            from: "en",
            mode: .primaryWithFallback,
            preferredEngine: .apple,
            fallbackEnabled: true
        )

        XCTAssertEqual(bundle.primaryEngine, .mtranServer)
        XCTAssertEqual(bundle.primaryResult.map(\.translated), ["您好"])
        let primaryRequestCount = await primary.requestCount()
        let fallbackRequestCount = await fallback.requestCount()
        XCTAssertEqual(primaryRequestCount, 0)
        XCTAssertEqual(fallbackRequestCount, 1)
    }

    func testRegistryCreatesBuiltInProviderWhenRegistrationWasSkipped() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)

        let provider = try await registry.createProvider(
            for: .apple,
            config: .default(for: .apple)
        )

        XCTAssertTrue(provider is AppleTranslationProvider)
        let registeredProvider = await registry.provider(for: .apple)
        XCTAssertNotNil(registeredProvider)
    }

    func testRegistryCreatesLLMProvidersThatArePromptConfigurable() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let provider = try await registry.createProvider(
            for: .ollama,
            config: TranslationEngineConfig(
                id: .ollama,
                isEnabled: true,
                options: EngineOptions(
                    baseURL: "http://127.0.0.1:11434",
                    modelName: "llama3",
                    timeout: 30
                )
            )
        )

        XCTAssertNotNil(provider as? any TranslationPromptConfigurable)
    }

    func testParallelModeCapturesSuccessAndFailurePerEngine() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let apple = MockTranslationProvider(
            id: "apple",
            name: "Apple",
            batchResults: [
                makeResult(source: "Hello", translated: "你好")
            ]
        )
        let mtran = MockTranslationProvider(
            id: "mtran",
            name: "MTran",
            translateError: TranslationProviderError.timeout
        )

        await registry.register(apple, for: .apple)
        await registry.register(mtran, for: .mtranServer)

        let service = TranslationService(registry: registry)

        let bundle = try await service.translate(
            segments: ["Hello"],
            to: "zh-Hans",
            from: "en",
            mode: .parallel,
            preferredEngine: .apple,
            parallelEngines: [.apple, .mtranServer]
        )

        XCTAssertEqual(bundle.selectionMode, .parallel)
        XCTAssertEqual(bundle.result(for: .apple)?.segments.map(\.translated), ["你好"])
        XCTAssertNil(bundle.result(for: .mtranServer)?.segments.first)
        XCTAssertNotNil(bundle.result(for: .mtranServer)?.error)
        XCTAssertTrue(bundle.hasErrors)
    }

    func testQuickSwitchUsesPrimaryEngineWithoutFallback() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let apple = MockTranslationProvider(
            id: "apple",
            name: "Apple",
            batchResults: [
                makeResult(source: "Hello", translated: "你好")
            ]
        )
        let mtran = MockTranslationProvider(
            id: "mtran",
            name: "MTran",
            batchResults: [
                makeResult(source: "Hello", translated: "您好")
            ]
        )

        await registry.register(apple, for: .apple)
        await registry.register(mtran, for: .mtranServer)

        let service = TranslationService(registry: registry)

        let bundle = try await service.translate(
            segments: ["Hello"],
            to: "zh-Hans",
            from: "en",
            mode: .quickSwitch,
            preferredEngine: .apple
        )

        XCTAssertEqual(bundle.selectionMode, .quickSwitch)
        XCTAssertEqual(bundle.primaryEngine, .apple)
        XCTAssertEqual(bundle.primaryResult.map(\.translated), ["你好"])
        let appleRequestCount = await apple.requestCount()
        let mtranRequestCount = await mtran.requestCount()
        XCTAssertEqual(appleRequestCount, 1)
        XCTAssertEqual(mtranRequestCount, 0)
    }

    func testSceneBindingHonorsSceneSpecificPrimaryEngine() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let apple = MockTranslationProvider(
            id: "apple",
            name: "Apple",
            batchResults: [
                makeResult(source: "Hello", translated: "你好")
            ]
        )
        let mtran = MockTranslationProvider(
            id: "mtran",
            name: "MTran",
            batchResults: [
                makeResult(source: "Hello", translated: "您好")
            ]
        )

        await registry.register(apple, for: .apple)
        await registry.register(mtran, for: .mtranServer)

        let service = TranslationService(registry: registry)

        let bundle = try await service.translate(
            segments: ["Hello"],
            to: "zh-Hans",
            from: "en",
            scene: .screenshot,
            mode: .sceneBinding,
            preferredEngine: .apple,
            sceneBindings: [
                .screenshot: SceneEngineBinding(
                    scene: .screenshot,
                    primaryEngine: .mtranServer,
                    fallbackEngine: nil,
                    fallbackEnabled: false
                )
            ]
        )

        XCTAssertEqual(bundle.primaryEngine, .mtranServer)
        XCTAssertEqual(bundle.primaryResult.map(\.translated), ["您好"])
        let appleRequestCount = await apple.requestCount()
        let mtranRequestCount = await mtran.requestCount()
        XCTAssertEqual(appleRequestCount, 0)
        XCTAssertEqual(mtranRequestCount, 1)
    }

    func testAllEnginesFailThrowsMultiEngineError() async {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let apple = MockTranslationProvider(
            id: "apple",
            name: "Apple",
            translateError: TranslationProviderError.connectionFailed("primary offline")
        )
        let mtran = MockTranslationProvider(
            id: "mtran",
            name: "MTran",
            translateError: TranslationProviderError.timeout
        )

        await registry.register(apple, for: .apple)
        await registry.register(mtran, for: .mtranServer)

        let service = TranslationService(registry: registry)

        do {
            _ = try await service.translate(
                segments: ["Hello"],
                to: "zh-Hans",
                from: "en",
                mode: .primaryWithFallback,
                preferredEngine: .apple,
                fallbackEnabled: true
            )
            XCTFail("Expected translation failure")
        } catch let error as MultiEngineError {
            switch error {
            case .allEnginesFailed(let errors):
                XCTAssertEqual(errors.count, 2)
            default:
                XCTFail("Unexpected multi-engine error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testEmptyInputReturnsEmptyBundleWithoutQueryingProviders() async throws {
        let registry = TranslationEngineRegistry(registerBuiltInProviders: false)
        let apple = MockTranslationProvider(id: "apple", name: "Apple")
        await registry.register(apple, for: .apple)

        let service = TranslationService(registry: registry)

        let bundle = try await service.translate(
            segments: [],
            to: "zh-Hans",
            from: "en",
            mode: .primaryWithFallback,
            preferredEngine: .apple
        )

        XCTAssertTrue(bundle.results.isEmpty)
        let appleRequestCount = await apple.requestCount()
        XCTAssertEqual(appleRequestCount, 0)
    }

    func testTextTranslationFlowUpdatesStateAndResultOnSuccess() async throws {
        let service = MockTranslationServicing(
            nextResult: [
                BilingualSegment(
                    original: TextSegment(text: "Hello", boundingBox: .zero, confidence: 1.0),
                    translated: "你好",
                    sourceLanguage: "English",
                    targetLanguage: "Chinese"
                )
            ]
        )
        let flow = TextTranslationFlow(service: service)

        let result = try await flow.translate(
            "Hello",
            config: TextTranslationConfig(
                targetLanguage: "zh-Hans",
                sourceLanguage: "en",
                preferredEngine: .apple,
                scene: .translateAndInsert,
                mode: .parallel,
                fallbackEnabled: false,
                parallelEngines: [.apple, .mtranServer],
                sceneBindings: [.translateAndInsert: SceneEngineBinding(
                    scene: .translateAndInsert,
                    primaryEngine: .custom,
                    fallbackEngine: .ollama,
                    fallbackEnabled: true
                )]
            )
        )

        XCTAssertEqual(result.translatedText, "你好")
        XCTAssertEqual(result.targetLanguage, "Chinese")
        let currentPhase = await flow.currentPhase
        let lastError = await flow.lastError
        let lastResult = await flow.lastResult
        let serviceRequests = await service.requests
        let serviceRequestCount = await service.requestCount()
        XCTAssertEqual(currentPhase, .completed)
        XCTAssertNil(lastError)
        XCTAssertEqual(lastResult?.translatedText, "你好")
        XCTAssertEqual(serviceRequests, [
            MockTranslationServicing.Request(
                segments: ["Hello"],
                targetLanguage: "zh-Hans",
                preferredEngine: .apple,
                sourceLanguage: "en",
                scene: .translateAndInsert,
                mode: .parallel,
                fallbackEnabled: false,
                parallelEngines: [.apple, .mtranServer],
                sceneBindings: [.translateAndInsert: SceneEngineBinding(
                    scene: .translateAndInsert,
                    primaryEngine: .custom,
                    fallbackEngine: .ollama,
                    fallbackEnabled: true
                )]
            )
        ])
        XCTAssertEqual(serviceRequestCount, 1)
    }

    func testTextTranslationFlowMapsServiceFailureToUserFacingErrorState() async {
        let service = MockTranslationServicing(
            nextError: TranslationProviderError.connectionFailed("offline")
        )
        let flow = TextTranslationFlow(service: service)

        do {
            _ = try await flow.translate(
                "Hello",
                config: TextTranslationConfig(
                    targetLanguage: "zh-Hans",
                    sourceLanguage: "en",
                    preferredEngine: .apple,
                    scene: .textSelection,
                    mode: .primaryWithFallback,
                    fallbackEnabled: true,
                    parallelEngines: [],
                    sceneBindings: [:]
                )
            )
            XCTFail("Expected flow to fail")
        } catch let error as TextTranslationError {
            switch error {
            case .translationFailed(let message):
                XCTAssertTrue(message.contains("offline"))
            default:
                XCTFail("Unexpected text translation error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        let currentPhase = await flow.currentPhase
        let lastError = await flow.lastError
        let serviceRequestCount = await service.requestCount()

        if case .failed(let failedError) = currentPhase,
           case .translationFailed(let message) = failedError {
            XCTAssertTrue(message.contains("offline"))
        } else {
            XCTFail("Expected failed phase with translationFailed error")
        }

        if case .translationFailed(let message)? = lastError {
            XCTAssertTrue(message.contains("offline"))
        } else {
            XCTFail("Expected translationFailed error")
        }
        XCTAssertEqual(serviceRequestCount, 1)
    }
}
