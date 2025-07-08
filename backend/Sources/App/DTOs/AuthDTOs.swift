import Vapor

struct CreateUserRequest: Content {
    let username: String
    let email: String
    let password: String
}

struct LoginRequest: Content {
    let username: String
    let password: String
}

struct LoginResponse: Content {
    let user: UserResponse
    let token: String
}
