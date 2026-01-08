//
//  APIService.swift
//  StoneLifting
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

    private let session = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Current JWT token for authenticated requests
    private(set) var authToken: String?

    // MARK: - Initialization

    private init() {
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
    }

    // MARK: - Token Management

    /// Store JWT token for future requests
    /// - Parameter token: JWT token from login response
    func setAuthToken(_ token: String) {
        logger.info("Setting auth token")
        authToken = token
        KeychainHelper.shared.save(token, forKey: KeychainKeys.jwtToken)
    }

    /// Clear stored JWT token (for logout)
    func clearAuthToken() {
        logger.info("Clearing auth token")
        authToken = nil
        KeychainHelper.shared.delete(forKey: KeychainKeys.jwtToken)
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
    /// Core method for performing HTTP requests
    /// - Parameters:
    ///   - endpoint: API endpoint path
    ///   - method: HTTP method (GET, POST, PUT, DELETE)
    ///   - body: Optional request body
    ///   - requiresAuth: Whether to include JWT token
    ///   - responseType: Expected response type
    /// - Returns: Decoded response
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
        request.timeoutInterval = 30.0
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
                logger.error("Error loading url: \(request.url?.absoluteString ?? "")", error: APIError.unauthorized)
                // Unauthorized - clear stored token
                clearAuthToken()
                throw APIError.unauthorized

            case 400:
                logger.error("Error loading url: \(request.url?.absoluteString ?? "")", error: APIError.badRequest)
                throw APIError.badRequest

            case 404:
                logger.error("Error loading url: \(request.url?.absoluteString ?? "")", error: APIError.notFound)
                throw APIError.notFound

            case 500 ... 599:
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

/// API error types
enum APIError: Error, LocalizedError {
    case invalidURL
    case notAuthenticated
    case encodingFailed(Error)
    case decodingFailed(Error)
    case networkError(Error)
    case invalidResponse
    case badRequest
    case unauthorized
    case notFound
    case serverError
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
        case .unauthorized:
            return "Your session has expired. Please sign in again to continue."
        case .notFound:
            return "We couldn't find what you're looking for. It may have been moved or deleted."
        case .serverError:
            return "Our servers are experiencing issues. Please try again in a few moments."
        case let .unknown(code):
            return "Something unexpected happened (error \(code)). Please try again or contact support if this continues."
        }
    }
}
