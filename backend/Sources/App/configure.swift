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
    app.jwt.signers.use(.hs256(key: Environment.get("JWT_SECRET") ?? "secret-key"))
    
    // CORS middleware
    app.middleware.use(CORSMiddleware(configuration: .init(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )))
    
    // Database configuration
    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)

    // Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateStone())

    // Routes
    try routes(app)
}
