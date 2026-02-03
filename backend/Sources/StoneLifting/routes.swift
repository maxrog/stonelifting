import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "StoneLifting API v1.0"
    }
    
    app.get("health") { req in
        return ["status": "healthy"]
    }
    
    // Authentication routes (OAuth-only)
    let authRoutes = app.grouped("auth")
    authRoutes.post("apple", use: appleSignIn)
    authRoutes.post("google", use: googleSignIn)
    
    // Availability check routes (no auth required)
    authRoutes.get("check-username", ":username", use: checkUsernameAvailability)
    authRoutes.get("check-email", ":email", use: checkEmailAvailability)
    
    // Protected routes
    let protectedRoutes = app.grouped(AuthController.JWTAuthenticator())
    protectedRoutes.get("me", use: getMe)
    protectedRoutes.get("stats", use: getUserStats)
    protectedRoutes.on(.POST, "upload", "image", body: .collect(maxSize: "5mb"), use: uploadImage)

    
    // API routes
    try app.register(collection: StoneController())
}

// MARK: - OAuth Auth Handlers

func appleSignIn(req: Request) async throws -> LoginResponse {
    try AppleSignInRequest.validate(content: req)
    let appleRequest = try req.content.decode(AppleSignInRequest.self)

    // Verify Apple identity token with proper token verification and nonce validation
    let oauthService = OAuthVerificationService(client: req.client)
    let appleUserInfo = try await oauthService.verifyAppleToken(appleRequest.identityToken, nonce: appleRequest.nonce)

    // Check if user already exists with this Apple ID
    if let existingUser = try await User.query(on: req.db)
        .filter(\.$appleId == appleUserInfo.userID)
        .first() {
        // User exists, log them in
        req.logger.info("Apple Sign In: Existing user logged in - userID: \(appleUserInfo.userID)")
        let token = try AuthController.generateToken(for: existingUser, on: req)
        return LoginResponse(user: UserResponse(user: existingUser), token: token)
    }

    // New user - create account
    // Use email from token or from request, or generate private relay email
    let email = appleUserInfo.email ?? appleRequest.email ?? "\(appleUserInfo.userID)@privaterelay.appleid.com"
    let baseUsername = email.components(separatedBy: "@").first ?? "user"
    let username = try await generateUniqueUsername(baseUsername, on: req.db)

    // Moderate username for inappropriate content
    if let openAIKey = Environment.get("OPENAI_API_KEY") {
        let moderationService = ModerationService(apiKey: openAIKey)
        let result = try await moderationService.moderateText(username, on: req.client)

        if result.flagged {
            // If flagged, use a generic username
            let fallbackUsername = try await generateUniqueUsername("user", on: req.db)
            req.logger.warning("Apple Sign In: Username '\(username)' flagged, using '\(fallbackUsername)' instead")
        }
    }

    let user = User(
        username: username,
        email: email,
        appleId: appleUserInfo.userID,
        authProvider: .apple
    )

    try await user.save(on: req.db)
    req.logger.info("Apple Sign In: New user created - userID: \(appleUserInfo.userID), username: \(username)")

    let token = try AuthController.generateToken(for: user, on: req)
    return LoginResponse(user: UserResponse(user: user), token: token)
}

func googleSignIn(req: Request) async throws -> LoginResponse {
    try GoogleSignInRequest.validate(content: req)
    let googleRequest = try req.content.decode(GoogleSignInRequest.self)

    // Verify Google ID token with Google's verification endpoint
    let oauthService = OAuthVerificationService(client: req.client)
    let googleUserInfo = try await oauthService.verifyGoogleToken(googleRequest.idToken)

    // Check if user already exists with this Google ID
    if let existingUser = try await User.query(on: req.db)
        .filter(\.$googleId == googleUserInfo.userID)
        .first() {
        // User exists, log them in
        req.logger.info("Google Sign In: Existing user logged in - userID: \(googleUserInfo.userID)")
        let token = try AuthController.generateToken(for: existingUser, on: req)
        return LoginResponse(user: UserResponse(user: existingUser), token: token)
    }

    // New user - create account
    let baseUsername = googleUserInfo.email.components(separatedBy: "@").first ?? "user"
    let username = try await generateUniqueUsername(baseUsername, on: req.db)

    // Moderate username for inappropriate content
    if let openAIKey = Environment.get("OPENAI_API_KEY") {
        let moderationService = ModerationService(apiKey: openAIKey)
        let result = try await moderationService.moderateText(username, on: req.client)

        if result.flagged {
            // If flagged, use a generic username
            let fallbackUsername = try await generateUniqueUsername("user", on: req.db)
            req.logger.warning("Google Sign In: Username '\(username)' flagged, using '\(fallbackUsername)' instead")
        }
    }

    let user = User(
        username: username,
        email: googleUserInfo.email,
        googleId: googleUserInfo.userID,
        authProvider: .google
    )

    try await user.save(on: req.db)
    req.logger.info("Google Sign In: New user created - userID: \(googleUserInfo.userID), username: \(username)")

    let token = try AuthController.generateToken(for: user, on: req)
    return LoginResponse(user: UserResponse(user: user), token: token)
}

// MARK: - Helper Functions

/// Generate a unique username by appending numbers if needed
private func generateUniqueUsername(_ base: String, on db: any Database) async throws -> String {
    // Sanitize base username
    let sanitized = base.lowercased()
        .filter { $0.isLetter || $0.isNumber || $0 == "_" }
        .prefix(20)

    var username = String(sanitized)
    if username.isEmpty {
        username = "user"
    }

    var counter = 1
    while try await User.query(on: db).filter(\.$username == username).first() != nil {
        username = "\(sanitized)\(counter)"
        counter += 1
    }

    return username
}

// MARK: - Availability Check Handlers

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

// MARK: Image Handlers


func uploadImage(req: Request) async throws -> ImageUploadResponse {
    let user = try req.auth.require(User.self)
    let userId = try user.requireID()
    let uploadRequest = try req.content.decode(ImageUploadRequest.self)
    
    // Decode base64 image data
    guard let imageData = Data(base64Encoded: uploadRequest.imageData) else {
        throw Abort(.badRequest, reason: "Invalid base64 image data")
    }
    
    // Validate file size (max 5MB)
    guard imageData.count <= 5_000_000 else {
        throw Abort(.badRequest, reason: "File too large. Maximum size is 5MB.")
    }
    
    // Validate it's actually an image
    guard isValidImageData(imageData) else {
        throw Abort(.badRequest, reason: "Invalid image format. Only JPEG and PNG are supported.")
    }
    
    // Upload to Cloudinary
    guard let cloudName = Environment.get("CLOUDINARY_CLOUD_NAME"),
          let apiKey = Environment.get("CLOUDINARY_API_KEY"),
          let apiSecret = Environment.get("CLOUDINARY_API_SECRET") else {
        throw Abort(.internalServerError, reason: "Cloudinary configuration missing")
    }

    let cloudinary = CloudinaryService(cloudName: cloudName,
                                       apiKey: apiKey,
                                       apiSecret: apiSecret)

    // Use user ID and UUID for unique public ID
    let publicId = "user_\(userId)_\(UUID().uuidString)"

    do {
        let imageURL = try await cloudinary.uploadImage(imageData,
                                                        publicId: publicId,
                                                        folder: "stonelifting/stones",
                                                        on: req.client)

        req.logger.info("Image uploaded successfully to Cloudinary: \(imageURL)")

        return ImageUploadResponse(success: true,
                                   imageUrl: imageURL,
                                   message: "Image uploaded successfully")
    } catch let error as CloudinaryError {
        switch error {
        case .moderationFailed(let message):
            req.logger.warning("Image moderation failed: \(message)")
            throw Abort(.badRequest, reason: message)
        case .uploadFailed(let message):
            req.logger.error("Failed to upload image to Cloudinary: \(message)")
            throw Abort(.internalServerError, reason: "Failed to upload image")
        case .invalidConfiguration:
            req.logger.error("Cloudinary configuration is invalid")
            throw Abort(.internalServerError, reason: "Service configuration error")
        }
    } catch {
        req.logger.error("Failed to upload image to Cloudinary: \(error)")
        throw Abort(.internalServerError, reason: "Failed to upload image")
    }
}

// Helper functions
private func isValidImageData(_ data: Data) -> Bool {
    guard data.count >= 4 else { return false }
    
    let header = data.prefix(4)
    
    // JPEG magic numbers
    if header.starts(with: [0xFF, 0xD8]) {
        return true
    }
    
    // PNG magic numbers
    if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
        return true
    }
    
    return false
}
