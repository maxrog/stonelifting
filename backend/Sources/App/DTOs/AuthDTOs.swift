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

struct ForgotPasswordRequest: Content {
    let email: String
}

struct ResetPasswordRequest: Content {
    let email: String
    let token: String
    let newPassword: String
}

struct MessageResponse: Content {
    let message: String
}

struct AvailabilityResponse: Content {
    let available: Bool
}
