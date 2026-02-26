# Refactor Plan: LLMTranslationProvider.callLLMAPI

## Background

CodeRabbit identified that `callLLMAPI` method has high cyclomatic complexity (~80 lines doing multiple things):
- Building endpoint URL based on engine type
- Building headers based on engine type  
- Building request body based on engine type
- Configuring URLRequest (timeout, method)
- Executing network request
- Handling HTTP status codes
- Parsing response based on engine type

## Goals

1. Reduce cyclomatic complexity by extracting engine-specific logic into focused helpers
2. Improve testability (each helper can be unit tested independently)
3. Maintain existing behavior and error handling
4. Follow Single Responsibility Principle

## Current Structure

```swift
private func callLLMAPI(
    prompt: String,
    credentials: StoredCredentials?
) async throws -> String {
    // 1. Get base URL and model name
    // 2. Switch on engineType to build endpoint + headers
    // 3. Create URLRequest, set timeout, add headers
    // 4. Switch on engineType to build request body
    // 5. Serialize body to JSON
    // 6. Execute URLSession request
    // 7. Validate HTTP status codes
    // 8. Parse response based on engineType
}
```

## Proposed Structure

### New Helper Methods

#### 1. `buildEndpointAndHeaders`

```swift
/// Builds the API endpoint URL and HTTP headers based on engine type.
/// - Parameters:
///   - baseURL: The base URL for the API
///   - credentials: Optional stored credentials for authentication
/// - Returns: Tuple of (endpoint URL, HTTP headers dictionary)
private func buildEndpointAndHeaders(
    baseURL: URL,
    credentials: StoredCredentials?
) -> (endpoint: URL, headers: [String: String]) {
    var headers: [String: String] = ["Content-Type": "application/json"]
    let endpoint: URL
    
    switch engineType {
    case .claude:
        endpoint = baseURL.appendingPathComponent("v1/messages")
        if let apiKey = credentials?.apiKey {
            headers["x-api-key"] = apiKey
            headers["anthropic-version"] = "2023-06-01"
        }
    default:
        endpoint = baseURL.appendingPathComponent("chat/completions")
        if let apiKey = credentials?.apiKey {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
    }
    
    return (endpoint, headers)
}
```

#### 2. `buildRequestBody`

```swift
/// Builds the JSON request body based on engine type.
/// - Parameters:
///   - modelName: The model name to use
///   - prompt: The translation prompt
/// - Returns: Dictionary ready for JSON serialization
private func buildRequestBody(
    modelName: String,
    prompt: String
) -> [String: Any] {
    let messages: [[String: Any]] = [["role": "user", "content": prompt]]
    
    switch engineType {
    case .claude:
        return [
            "model": modelName,
            "max_tokens": config.options?.maxTokens ?? 2048,
            "messages": messages
        ]
    default:
        return [
            "model": modelName,
            "messages": messages,
            "temperature": config.options?.temperature ?? 0.3,
            "max_tokens": config.options?.maxTokens ?? 2048
        ]
    }
}
```

#### 3. `executeRequest`

```swift
/// Executes the HTTP request and handles common error cases.
/// - Parameter request: The configured URLRequest
/// - Returns: The response data on success
/// - Throws: TranslationProviderError for various failure cases
private func executeRequest(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw TranslationProviderError.connectionFailed("Invalid response")
    }
    
    switch httpResponse.statusCode {
    case 200:
        return data
    case 401:
        throw TranslationProviderError.invalidConfiguration("Invalid API key")
    case 429:
        throw TranslationProviderError.rateLimited(retryAfter: nil)
    default:
        logger.error("API error status=\(httpResponse.statusCode)")
        throw TranslationProviderError.translationFailed("API error: \(httpResponse.statusCode)")
    }
}
```

### Refactored `callLLMAPI`

```swift
private func callLLMAPI(
    prompt: String,
    credentials: StoredCredentials?
) async throws -> String {
    let baseURL = try getBaseURL()
    let modelName = getModelName()
    
    let (endpoint, headers) = buildEndpointAndHeaders(
        baseURL: baseURL,
        credentials: credentials
    )
    
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = config.options?.timeout ?? 30
    for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
    }
    
    request.httpBody = try JSONSerialization.data(
        withJSONObject: buildRequestBody(modelName: modelName, prompt: prompt)
    )
    
    let data = try await executeRequest(request)
    return try parseResponse(data, for: engineType)
}
```

## Implementation Steps

### Step 1: Add `buildEndpointAndHeaders`
- Add new method after `getModelName()`
- Extract endpoint and header logic from `callLLMAPI`
- Run tests to verify no behavior change

### Step 2: Add `buildRequestBody`
- Add new method after `buildEndpointAndHeaders`
- Extract body building logic from `callLLMAPI`
- Run tests to verify no behavior change

### Step 3: Add `executeRequest`
- Add new method after `buildRequestBody`
- Extract request execution and status handling
- Run tests to verify no behavior change

### Step 4: Refactor `callLLMAPI`
- Replace inline logic with calls to new helpers
- Verify line count reduced from ~80 to ~20
- Run full test suite

### Step 5: Cleanup
- Remove any dead code
- Ensure consistent formatting
- Update any documentation

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Behavior regression | Low | High | Run existing tests after each step |
| Missing edge cases | Low | Medium | Manual testing with each engine type |
| Performance impact | Very Low | Low | Helpers are simple, no extra overhead |

## Testing Strategy

### Unit Tests (if existing test infrastructure)
- Test `buildEndpointAndHeaders` for each engine type (Claude, OpenAI, Gemini, Ollama)
- Test `buildRequestBody` for each engine type
- Test `executeRequest` with mock URLProtocol for status codes

### Integration Tests
- Translate with OpenAI (requires API key)
- Translate with Claude (requires API key)
- Translate with Ollama (local, no key needed)
- Test error cases: invalid key (401), rate limit (429), server error (500)

### Manual Verification
- [ ] OpenAI translation works
- [ ] Claude translation works  
- [ ] Gemini translation works
- [ ] Ollama translation works
- [ ] Custom baseURL works
- [ ] Error messages are clear

## Expected Outcome

| Metric | Before | After |
|--------|--------|-------|
| `callLLMAPI` lines | ~80 | ~20 |
| Cyclomatic complexity | High | Low |
| Testable units | 1 | 4 |
| Responsibilities per method | 7 | 1-2 |

## Timeline

- Implementation: 30-60 minutes
- Testing: 15-30 minutes
- Total: ~1 hour

## Notes

- This is a **refactor**, not a behavior change
- All existing error handling must be preserved
- `parseResponse` already exists and is well-structured, no changes needed
- Consider making helpers `nonisolated` if they don't need actor isolation for better testability
