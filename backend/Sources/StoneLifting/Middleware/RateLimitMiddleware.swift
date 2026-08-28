import Vapor

/// Tracks request timestamps per key (user ID or IP) within a sliding time window.
actor RateLimiter {
    private var buckets: [String: [Date]] = [:]

    func isAllowed(key: String, limit: Int, window: TimeInterval) -> Bool {
        let now = Date()
        let cutoff = now.addingTimeInterval(-window)
        var timestamps = (buckets[key] ?? []).filter { $0 > cutoff }

        guard timestamps.count < limit else {
            buckets[key] = timestamps
            return false
        }

        timestamps.append(now)
        buckets[key] = timestamps
        return true
    }
}

/// Rate limits requests by authenticated user when available, falling back to
/// the client IP (via X-Forwarded-For, since Railway sits behind a proxy).
struct RateLimitMiddleware: AsyncMiddleware {
    let limiter: RateLimiter
    let limit: Int
    let window: TimeInterval
    let message: String

    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let key = rateLimitKey(for: request)

        guard await limiter.isAllowed(key: key, limit: limit, window: window) else {
            throw Abort(.tooManyRequests, reason: message)
        }

        return try await next.respond(to: request)
    }

    private func rateLimitKey(for request: Request) -> String {
        if let user = request.auth.get(User.self), let userID = try? user.requireID() {
            return "user:\(userID)"
        }
        return "ip:\(clientIP(for: request))"
    }

    private func clientIP(for request: Request) -> String {
        if let forwardedFor = request.headers.first(name: "X-Forwarded-For") {
            let firstIP = forwardedFor.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
            if let firstIP, !firstIP.isEmpty {
                return firstIP
            }
        }
        return request.remoteAddress?.ipAddress ?? "unknown"
    }
}
