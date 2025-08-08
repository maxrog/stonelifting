import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "StoneLifting API v1.0"
    }
    
    app.get("health") { req in
        return ["status": "healthy"]
    }
    
    // Authentication routes
    let authRoutes = app.grouped("auth")
    authRoutes.post("register", use: register)
    authRoutes.post("login", use: login)
    authRoutes.post("forgot-password", use: forgotPassword)
    authRoutes.post("reset-password", use: resetPassword)
    
    // Availability check routes (no auth required)
    authRoutes.get("check-username", ":username", use: checkUsernameAvailability)
    authRoutes.get("check-email", ":email", use: checkEmailAvailability)
    
    // Protected routes
    let protectedRoutes = app.grouped(AuthController.JWTAuthenticator())
    protectedRoutes.get("me", use: getMe)
    protectedRoutes.get("stats", use: getUserStats)
    
    // API routes
    try app.register(collection: StoneController())
}

// MARK: - Auth Handlers

// TODO Text code verification
func register(req: Request) async throws -> HTTPStatus {
    let create = try req.content.decode(CreateUserRequest.self)
    
    // Check if user exists
    let existingUser = try await User.query(on: req.db)
        .group(.or) { group in
            group.filter(\.$username == create.username)
            group.filter(\.$email == create.email)
        }
        .first()
    
    if existingUser != nil {
        throw Abort(.conflict, reason: "Username or email already exists")
    }
    
    let user = User(
        username: create.username,
        email: create.email,
        passwordHash: try Bcrypt.hash(create.password)
    )
    
    try await user.save(on: req.db)
    return .created
}

func login(req: Request) async throws -> LoginResponse {
    let loginRequest = try req.content.decode(LoginRequest.self)
    
    guard let user = try await User.query(on: req.db)
        .filter(\.$username == loginRequest.username)
        .first() else {
        throw Abort(.unauthorized)
    }
    
    guard try user.verify(password: loginRequest.password) else {
        throw Abort(.unauthorized)
    }
    
    let token = try AuthController.generateToken(for: user, on: req)
    
    return LoginResponse(
        user: UserResponse(user: user),
        token: token
    )
}

func forgotPassword(req: Request) async throws -> MessageResponse {
    let request = try req.content.decode(ForgotPasswordRequest.self)
    
    // Check if user exists
    guard let user = try await User.query(on: req.db)
        .filter(\.$email == request.email)
        .first() else {
        // Don't reveal if email exists or not for security
        return MessageResponse(message: "If an account with that email exists, you will receive a password reset link.")
    }
    
    // TODO
    // Generate reset token (in production, this should be a secure random token)
    let resetToken = UUID().uuidString
    
    // TODO
    // Store reset token with expiration (you'd need a PasswordResetToken model in production)
    // For now, we'll just log it
    req.logger.info("Password reset token for \(user.email): \(resetToken)")
    
    // In production, send email with reset link
    // await emailService.sendPasswordResetEmail(to: user.email, token: resetToken)
    
    return MessageResponse(message: "If an account with that email exists, you will receive a password reset link.")
}

func resetPassword(req: Request) async throws -> MessageResponse {
    let request = try req.content.decode(ResetPasswordRequest.self)
    
    // TODO
    // In production, validate the reset token and check expiration
    // For demo purposes, we'll accept any token that looks like a UUID
    guard UUID(uuidString: request.token) != nil else {
        throw Abort(.badRequest, reason: "Invalid or expired reset token")
    }
    
    // TODO
    // Find user by email (in production, find by token)
    guard let user = try await User.query(on: req.db)
        .filter(\.$email == request.email)
        .first() else {
        throw Abort(.badRequest, reason: "Invalid reset request")
    }
    
    // Update password
    user.passwordHash = try Bcrypt.hash(request.newPassword)
    try await user.save(on: req.db)
    
    return MessageResponse(message: "Password has been reset successfully")
}

// Add these new handler functions
func checkUsernameAvailability(req: Request) async throws -> AvailabilityResponse {
    guard let username = req.parameters.get("username") else {
        throw Abort(.badRequest, reason: "Username parameter required")
    }
    
    let existingUser = try await User.query(on: req.db)
        .filter(\.$username == username)
        .first()
    
    return AvailabilityResponse(available: existingUser == nil)
}

func checkEmailAvailability(req: Request) async throws -> AvailabilityResponse {
    guard let email = req.parameters.get("email") else {
        throw Abort(.badRequest, reason: "Email parameter required")
    }
    
    let existingUser = try await User.query(on: req.db)
        .filter(\.$email == email)
        .first()
    
    return AvailabilityResponse(available: existingUser == nil)
}

// MARK: User Handlers

func getMe(req: Request) async throws -> UserResponse {
    let user = try req.auth.require(User.self)
    return UserResponse(user: user)
}

func getUserStats(req: Request) async throws -> UserStatsResponse {
    let user = try req.auth.require(User.self)
    
    let stones = try await Stone.query(on: req.db)
        .filter(\.$user.$id == user.requireID())
        .sort(\.$createdAt, .descending)
        .all()
    
    let stoneResponses = stones.map { StoneResponse(stone: $0, user: user) }
    
    return UserStatsResponse(user: user, stones: stoneResponses)
}
