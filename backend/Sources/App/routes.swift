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
    
    // Protected routes
    let protectedRoutes = app.grouped(AuthController.JWTAuthenticator())
    protectedRoutes.get("me", use: getMe)
    protectedRoutes.get("stats", use: getUserStats)
    
    // API routes
    try app.register(collection: StoneController())
}

// MARK: - Auth Handlers
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
