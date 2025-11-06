@testable import App
import VaporTesting
import Testing
import Fluent
import JWT

@Suite("App Tests with DB", .serialized)
struct AppTests {
    private func withApp(_ test: (Application) async throws -> ()) async throws {
        let app = try await Application.make(.testing)
        do {
            try await configure(app)
            try await app.autoMigrate()
            try await test(app)
            try await app.autoRevert()
        } catch {
            try? await app.autoRevert()
            try await app.asyncShutdown()
            throw error
        }
        try await app.asyncShutdown()
    }

    // MARK: - Basic Route Tests

    @Test("Test Hello World Route")
    func helloWorld() async throws {
        try await withApp { app in
            try await app.testing().test(.GET, "hello", afterResponse: { res async in
                #expect(res.status == .ok)
                #expect(res.body.string == "Hello, world!")
            })
        }
    }

    // MARK: - Authentication Tests

    @Test("Register New User")
    func registerUser() async throws {
        let newUser = CreateUserRequest(
            username: "testuser",
            email: "test@example.com",
            password: "password123"
        )

        try await withApp { app in
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode(newUser)
            }, afterResponse: { res async throws in
                #expect(res.status == .created)

                // Verify user was created in database
                let user = try await User.query(on: app.db)
                    .filter(\.$username == "testuser")
                    .first()
                #expect(user != nil)
                #expect(user?.email == "test@example.com")
            })
        }
    }

    @Test("Register User with Duplicate Username Fails")
    func registerDuplicateUsernameFails() async throws {
        let user1 = CreateUserRequest(
            username: "testuser",
            email: "test1@example.com",
            password: "password123"
        )
        let user2 = CreateUserRequest(
            username: "testuser",
            email: "test2@example.com",
            password: "password456"
        )

        try await withApp { app in
            // Create first user
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode(user1)
            }, afterResponse: { res async in
                #expect(res.status == .created)
            })

            // Attempt to create second user with same username
            try await app.testing().test(.POST, "auth/register", beforeRequest: { req in
                try req.content.encode(user2)
            }, afterResponse: { res async in
                #expect(res.status == .conflict)
            })
        }
    }

    @Test("Login with Valid Credentials")
    func loginSuccess() async throws {
        // First create a user
        let password = "password123"
        let user = User(
            username: "testuser",
            email: "test@example.com",
            passwordHash: try Bcrypt.hash(password)
        )

        try await withApp { app in
            try await user.save(on: app.db)

            let loginRequest = LoginRequest(username: "testuser", password: password)

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(loginRequest)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let response = try res.content.decode(LoginResponse.self)
                #expect(response.user.username == "testuser")
                #expect(!response.token.isEmpty)
            })
        }
    }

    @Test("Login with Invalid Password Fails")
    func loginInvalidPassword() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            passwordHash: try Bcrypt.hash("correctpassword")
        )

        try await withApp { app in
            try await user.save(on: app.db)

            let loginRequest = LoginRequest(username: "testuser", password: "wrongpassword")

            try await app.testing().test(.POST, "auth/login", beforeRequest: { req in
                try req.content.encode(loginRequest)
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test("Check Username Availability")
    func checkUsernameAvailability() async throws {
        let user = User(
            username: "existinguser",
            email: "existing@example.com",
            passwordHash: try Bcrypt.hash("password123")
        )

        try await withApp { app in
            try await user.save(on: app.db)

            // Check existing username
            try await app.testing().test(.GET, "auth/check-username/existinguser", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let response = try res.content.decode(AvailabilityResponse.self)
                #expect(response.available == false)
            })

            // Check available username
            try await app.testing().test(.GET, "auth/check-username/newuser", afterResponse: { res async throws in
                #expect(res.status == .ok)
                let response = try res.content.decode(AvailabilityResponse.self)
                #expect(response.available == true)
            })
        }
    }

    // MARK: - Stone Tests

    @Test("Create Stone with Authentication")
    func createStone() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            passwordHash: try Bcrypt.hash("password123")
        )

        try await withApp { app in
            try await user.save(on: app.db)

            // Generate JWT token for user
            let token = try AuthController.generateToken(for: user, on: app.http.client.eventLoop.any())

            let stoneRequest = CreateStoneRequest(
                name: "Test Stone",
                weight: 100.0,
                estimatedWeight: nil,
                description: "A test stone",
                imageUrl: nil,
                latitude: 40.7128,
                longitude: -74.0060,
                locationName: "New York",
                isPublic: true,
                liftingLevel: "intermediate",
                carryDistance: 10.0
            )

            try await app.testing().test(.POST, "stones", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
                try req.content.encode(stoneRequest)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let response = try res.content.decode(StoneResponse.self)
                #expect(response.name == "Test Stone")
                #expect(response.weight == 100.0)
            })
        }
    }

    @Test("Create Stone without Authentication Fails")
    func createStoneUnauthorized() async throws {
        let stoneRequest = CreateStoneRequest(
            name: "Test Stone",
            weight: 100.0,
            estimatedWeight: nil,
            description: "A test stone",
            imageUrl: nil,
            latitude: 40.7128,
            longitude: -74.0060,
            locationName: "New York",
            isPublic: true,
            liftingLevel: "intermediate",
            carryDistance: 10.0
        )

        try await withApp { app in
            try await app.testing().test(.POST, "stones", beforeRequest: { req in
                try req.content.encode(stoneRequest)
            }, afterResponse: { res async in
                #expect(res.status == .unauthorized)
            })
        }
    }

    @Test("Get User's Stones")
    func getUserStones() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            passwordHash: try Bcrypt.hash("password123")
        )

        try await withApp { app in
            try await user.save(on: app.db)

            // Create some stones
            let stone1 = Stone(
                name: "Stone 1",
                weight: 100.0,
                estimatedWeight: nil,
                description: nil,
                imageUrl: nil,
                latitude: 40.7128,
                longitude: -74.0060,
                locationName: nil,
                isPublic: true,
                liftingLevel: "beginner",
                carryDistance: nil,
                userID: try user.requireID()
            )
            let stone2 = Stone(
                name: "Stone 2",
                weight: 150.0,
                estimatedWeight: nil,
                description: nil,
                imageUrl: nil,
                latitude: 40.7128,
                longitude: -74.0060,
                locationName: nil,
                isPublic: false,
                liftingLevel: "intermediate",
                carryDistance: nil,
                userID: try user.requireID()
            )

            try await stone1.save(on: app.db)
            try await stone2.save(on: app.db)

            let token = try AuthController.generateToken(for: user, on: app.http.client.eventLoop.any())

            try await app.testing().test(.GET, "stones", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                let stones = try res.content.decode([StoneResponse].self)
                #expect(stones.count == 2)
            })
        }
    }

    @Test("Delete Stone")
    func deleteStone() async throws {
        let user = User(
            username: "testuser",
            email: "test@example.com",
            passwordHash: try Bcrypt.hash("password123")
        )

        try await withApp { app in
            try await user.save(on: app.db)

            let stone = Stone(
                name: "Test Stone",
                weight: 100.0,
                estimatedWeight: nil,
                description: nil,
                imageUrl: nil,
                latitude: 40.7128,
                longitude: -74.0060,
                locationName: nil,
                isPublic: true,
                liftingLevel: "beginner",
                carryDistance: nil,
                userID: try user.requireID()
            )

            try await stone.save(on: app.db)
            let token = try AuthController.generateToken(for: user, on: app.http.client.eventLoop.any())

            try await app.testing().test(.DELETE, "stones/\(try stone.requireID())", beforeRequest: { req in
                req.headers.bearerAuthorization = BearerAuthorization(token: token)
            }, afterResponse: { res async throws in
                #expect(res.status == .ok)

                // Verify stone was deleted
                let deletedStone = try await Stone.find(stone.id, on: app.db)
                #expect(deletedStone == nil)
            })
        }
    }
}
