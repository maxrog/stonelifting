import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT
/*
 TODO production migration
 .env file (better pw + jwt) + TODOs in here
 */

// configures your application
public func configure(_ app: Application) async throws {
    // JWT configuration
    guard let jwtSecret = Environment.get("JWT_SECRET") else {
        app.logger.critical("JWT_SECRET environment variable is not set. Application cannot start securely.")
        fatalError("JWT_SECRET must be set in environment variables")
    }
    app.jwt.signers.use(.hs256(key: jwtSecret))


    // TODO prod figure out which middleware actually needed in prod
    // Filesystem middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // CORS middleware - configure allowed origins based on environment
    let allowedOrigin: CORSMiddleware.AllowOriginSetting
    if let corsOrigin = Environment.get("CORS_ALLOWED_ORIGIN") {
        // Production: use specific origin from environment
        allowedOrigin = .custom(corsOrigin)
    } else if app.environment == .development {
        // Development: allow localhost
        allowedOrigin = .custom("http://localhost:3000")
    } else {
        app.logger.critical("CORS_ALLOWED_ORIGIN must be set for non-development environments")
        fatalError("CORS_ALLOWED_ORIGIN environment variable must be set")
    }

    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: allowedOrigin,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )))
    
    // Database configuration
    if let databaseURL = Environment.get("DATABASE_URL") {
        // Production/Railway: use DATABASE_URL connection string
        var postgresConfig = try SQLPostgresConfiguration(url: databaseURL)
        postgresConfig.coreConfiguration.tls = .prefer(try .init(configuration: .clientDefault))
        app.databases.use(.postgres(configuration: postgresConfig), as: .psql)
    } else {
        // Local development: use individual variables
        app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "vapor_database",
            tls: .prefer(try .init(configuration: .clientDefault)))
        ), as: .psql)
    }

    // Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateStone())

    try await app.autoMigrate()

    // Routes
    try routes(app)
}
