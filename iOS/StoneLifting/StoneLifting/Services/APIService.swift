//
//  APIService.swift
//  StoneAtlas
//
//  Created by Max Rogers on 7/10/25.
//

import Foundation

// MARK: - API Service

/// Core networking service for communicating with the StoneLifting backend
/// Handles HTTP requests, authentication, and response parsing
@Observable
final class APIService {
    // MARK: - Properties

    static let shared = APIService()
    private let logger = AppLogger()

    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Current JWT token for authenticated requests
    private(set) var authToken: String?

    /// Current refresh token for getting new JWT tokens
    private(set) var refreshToken: String?

    /// Task that's currently refreshing the token
    private var refreshTask: Task<Void, Never>?

    /// Queue of requests waiting for token refresh to complete
    private var pendingRequests: [CheckedContinuation<Void, Never>] = []

    // MARK: - Initialization

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)

        setupDateFormatting()
        loadStoredToken()
    }

    // MARK: - Configuration

    private func setupDateFormatting() {
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
    }

    private func loadStoredToken() {
        authToken = KeychainHelper.shared.getString(forKey: KeychainKeys.jwtToken)
        refreshToken = KeychainHelper.shared.getString(forKey: KeychainKeys.refreshToken)
    }

    // MARK: - Token Management

    /// Store JWT token and refresh token for future requests
    /// - Parameters:
    ///   - token: JWT token from login response
    ///   - refreshToken: Refresh token from login response
    func setAuthToken(_ token: String, refreshToken: String? = nil) {
        logger.info("Setting auth token")
        authToken = token
        KeychainHelper.shared.save(token, forKey: KeychainKeys.jwtToken)

        if let refreshToken = refreshToken {
            self.refreshToken = refreshToken
            KeychainHelper.shared.save(refreshToken, forKey: KeychainKeys.refreshToken)
        }
    }

    /// Clear stored JWT token and refresh token (for logout)
    func clearAuthToken() {
        logger.info("Clearing auth token")
        authToken = nil
        refreshToken = nil
        refreshTask?.cancel()
        refreshTask = nil
        pendingRequests.removeAll()
        KeychainHelper.shared.delete(forKey: KeychainKeys.jwtToken)
        KeychainHelper.shared.delete(forKey: KeychainKeys.refreshToken)
    }

    var isAuthenticated: Bool {
        authToken != nil
    }

    // MARK: - HTTP Methods

    /// Perform a GET request
    /// - Parameters:
    ///   - endpoint: API endpoint path
    ///   - requiresAuth: Whether this endpoint requires authentication
    /// - Returns: Decoded response data
    func get<T: Codable>(
        endpoint: String,
        requiresAuth: Bool = false,
        type: T.Type
    ) async throws -> T {
        try await performRequest(
            endpoint: endpoint,
            method: "GET",
            body: EmptyBody?.none,
            requiresAuth: requiresAuth,
            responseType: type
        )
    }

    /// Perform a POST request
    /// - Parameters:
    ///   - endpoint: API endpoint path
    ///   - body: Request body to encode as JSON
    ///   - requiresAuth: Whether this endpoint requires authentication
    /// - Returns: Decoded response data
    func post<T: Codable, U: Codable>(
        endpoint: String,
        body: T,
        requiresAuth: Bool = false,
        responseType: U.Type
    ) async throws -> U {
        try await performRequest(
            endpoint: endpoint,
            method: "POST",
            body: body,
            requiresAuth: requiresAuth,
            responseType: responseType
        )
    }

    /// Perform a PUT request
    /// - Parameters:
    ///   - endpoint: API endpoint path
    ///   - body: Request body to encode as JSON
    ///   - requiresAuth: Whether this endpoint requires authentication
    /// - Returns: Decoded response data
    func put<T: Codable, U: Codable>(
        endpoint: String,
        body: T,
        requiresAuth: Bool = true,
        responseType: U.Type
    ) async throws -> U {
        try await performRequest(
            endpoint: endpoint,
            method: "PUT",
            body: body,
            requiresAuth: requiresAuth,
            responseType: responseType
        )
    }

    /// Perform a PATCH request
    /// - Parameters:
    ///   - endpoint: API endpoint path
    ///   - body: Request body to encode as JSON
    ///   - requiresAuth: Whether this endpoint requires authentication
    /// - Returns: Decoded response data
    func patch<T: Codable, U: Codable>(
        endpoint: String,
        body: T,
        requiresAuth: Bool = true,
        responseType: U.Type
    ) async throws -> U {
        try await performRequest(
            endpoint: endpoint,
            method: "PATCH",
            body: body,
            requiresAuth: requiresAuth,
            responseType: responseType
        )
    }

    /// Perform a DELETE request
    /// - Parameters:
    ///   - endpoint: API endpoint path
    ///   - requiresAuth: Whether this endpoint requires authentication
    func delete(endpoint: String, requiresAuth: Bool = true) async throws {
        let _: EmptyResponse = try await performRequest(
            endpoint: endpoint,
            method: "DELETE",
            body: EmptyBody?.none,
            requiresAuth: requiresAuth,
            responseType: EmptyResponse.self
        )
    }
}

// MARK: - Private Methods

private extension APIService {
    /// Refresh the access token using the refresh token
    /// - Returns: True if refresh succeeded, false otherwise
    func refreshAccessToken() async -> Bool {
        // If already refreshing, wait for it to complete
        if let existingTask = refreshTask {
            await existingTask.value
            return authToken != nil
        }

        // Start a new refresh task
        refreshTask = Task { @MainActor in
            guard let currentRefreshToken = refreshToken else {
                logger.warning("No refresh token available for refresh")
                clearAuthToken()
                return
            }

            logger.info("Refreshing access token...")

            do {
                // Create the refresh request manually to avoid recursion
                guard let url = URL(string: APIConfig.baseURL + "/auth/refresh") else {
                    throw APIError.invalidURL
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(APIConfig.Headers.applicationJSON, forHTTPHeaderField: APIConfig.Headers.contentType)

                let body = RefreshTokenRequest(refreshToken: currentRefreshToken)
                request.httpBody = try encoder.encode(body)

                logger.debug("Sending refresh token request...")
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                if httpResponse.statusCode == 200 {
                    let authResponse = try decoder.decode(AuthResponse.self, from: data)
                    setAuthToken(authResponse.token, refreshToken: authResponse.refreshToken)
                    logger.info("Access token refreshed successfully")

                    // Resume all pending requests
                    let continuations = pendingRequests
                    pendingRequests.removeAll()
                    for continuation in continuations {
                        continuation.resume()
                    }
                } else {
                    logger.error("Token refresh failed with status: \(httpResponse.statusCode)")
                    clearAuthToken()
                }
            } catch {
                logger.error("Error refreshing access token", error: error)
                clearAuthToken()
            }

            refreshTask = nil
        }

        await refreshTask?.value
        return authToken != nil
    }

    /// Core method for performing HTTP requests
    /// - Parameters:
    ///   - endpoint: API endpoint path
    ///   - method: HTTP method (GET, POST, PUT, DELETE)
    ///   - body: Optional request body
    ///   - requiresAuth: Whether to include JWT token
    ///   - responseType: Expected response type
    /// - Returns: Decoded response
    // swiftlint:disable:next cyclomatic_complexity
    func performRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: String,
        body: T?,
        requiresAuth: Bool,
        responseType: U.Type
    ) async throws -> U {
        guard let url = URL(string: APIConfig.baseURL + endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(APIConfig.Headers.applicationJSON, forHTTPHeaderField: APIConfig.Headers.contentType)

        if requiresAuth {
            guard let token = authToken else {
                throw APIError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: APIConfig.Headers.authorization)
        }

        if let body = body {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw APIError.encodingFailed(error)
            }
        }

        do {
            logger.info("Performing request with url: \(request.url?.absoluteString ?? ""), method: \(request.httpMethod ?? "")")
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            logger.debug("HTTP Status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200 ... 299:
                logger.info("Successful response for url: \(request.url?.absoluteString ?? "")")
                // Success - decode response
                if responseType == EmptyResponse.self {
                    guard let emptyResponse = EmptyResponse() as? U else {
                        throw APIError.invalidResponse
                    }
                    return emptyResponse
                }

                do {
                    return try decoder.decode(responseType, from: data)
                } catch {
                    logger.error("Error decoding response for url: \(request.url?.absoluteString ?? "")", error: error)
                    throw APIError.decodingFailed(error)
                }

            case 401:
                logger.warning("Got 401 Unauthorized - attempting token refresh")

                // Only attempt refresh if we have a refresh token and this isn't already a refresh request
                if refreshToken != nil && !endpoint.contains("/auth/refresh") {
                    // Wait for any in-progress refresh or start a new one
                    let refreshSucceeded = await refreshAccessToken()

                    if refreshSucceeded {
                        // Retry the original request with the new token
                        logger.info("Token refreshed - retrying original request")
                        return try await performRequest(
                            endpoint: endpoint,
                            method: method,
                            body: body,
                            requiresAuth: requiresAuth,
                            responseType: responseType
                        )
                    }
                }

                // No refresh token or refresh failed - clear everything and throw
                logger.error("Error loading url: \(request.url?.absoluteString ?? "")", error: APIError.unauthorized)
                clearAuthToken()
                throw APIError.unauthorized

            case 400:
                // Try to decode error message from backend
                logger.debug("Got 400 response. Raw data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")

                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data),
                   let reason = errorResponse.reason {
                    logger.error("Error loading url: \(request.url?.absoluteString ?? "") | Error: \(reason)")
                    throw APIError.badRequestWithMessage(reason)
                }

                logger.error("Error loading url: \(request.url?.absoluteString ?? "") | Error: Could not decode error response")
                throw APIError.badRequest

            case 404:
                logger.error("Error loading url: \(request.url?.absoluteString ?? "")", error: APIError.notFound)
                throw APIError.notFound

            case 500 ... 599:
                logger.debug("Got \(httpResponse.statusCode) response. Raw data: \(String(data: data, encoding: .utf8) ?? "unable to decode")")

                if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data),
                   let reason = errorResponse.reason {
                    logger.error("Error loading url: \(request.url?.absoluteString ?? "") | Error: \(reason)")
                    throw APIError.serverErrorWithMessage(reason)
                }

                logger.error("Error loading url: \(request.url?.absoluteString ?? "")", error: APIError.serverError)
                throw APIError.serverError

            default:
                logger.error("Error loading url: \(request.url?.absoluteString ?? "")", error: APIError.unknown(httpResponse.statusCode))
                throw APIError.unknown(httpResponse.statusCode)
            }

        } catch {
            if error is APIError {
                logger.error("Error loading url: \(request.url?.absoluteString ?? "")", error: error)
                throw error
            } else {
                logger.error("Error loading url: \(request.url?.absoluteString ?? "")", error: error)
                throw APIError.networkError(error)
            }
        }
    }
}

// MARK: - Supporting Types

private struct EmptyResponse: Codable {}
struct EmptyBody: Codable {}

/// Error response from backend
private struct ErrorResponse: Codable {
    let error: Bool?
    let reason: String?
}

/// API error types
enum APIError: Error, LocalizedError {
    case invalidURL
    case notAuthenticated
    case encodingFailed(Error)
    case decodingFailed(Error)
    case networkError(Error)
    case invalidResponse
    case badRequest
    case badRequestWithMessage(String)
    case unauthorized
    case notFound
    case serverError
    case serverErrorWithMessage(String)
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Something went wrong on our end. Please try again or contact support if this continues."
        case .notAuthenticated:
            return "You need to be logged in to do that. Please sign in to continue."
        case let .encodingFailed(error):
            return "We couldn't process your request. Please try again. (\(error.localizedDescription))"
        case let .decodingFailed(error):
            return "We received an unexpected response from the server. Please try again. (\(error.localizedDescription))"
        case let .networkError(error):
            return "We're having trouble connecting to the internet. Please check your connection and try again. (\(error.localizedDescription))"
        case .invalidResponse:
            return "We received an unexpected response from the server. Please try again later."
        case .badRequest:
            return "Something's not quite right with your request. Please check your information and try again."
        case let .badRequestWithMessage(message):
            return message
        case .unauthorized:
            return "Your session has expired. Please sign in again to continue."
        case .notFound:
            return "We couldn't find what you're looking for. It may have been moved or deleted."
        case .serverError:
            return "Our servers are experiencing issues. Please try again in a few moments."
        case let .serverErrorWithMessage(message):
            return message
        case let .unknown(code):
            return "Something unexpected happened (error \(code)). Please try again or contact support if this continues."
        }
    }
}
