import Vapor

struct CreateUserRequest: Content {
    let username: String
    let email: String
    let password: String
}

extension CreateUserRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        // Username: 3-20 characters, alphanumeric + underscore
        validations.add("username", as: String.self, is: .count(3...20) && .alphanumeric)

        // Email: valid email format
        validations.add("email", as: String.self, is: .email)

        // Password: 8-128 characters
        validations.add("password", as: String.self, is: .count(8...128))
    }
}

struct LoginRequest: Content {
    let username: String
    let password: String
}

extension LoginRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        // Username: not empty, max 20 chars
        validations.add("username", as: String.self, is: !.empty && .count(...20))

        // Password: not empty, max 128 chars
        validations.add("password", as: String.self, is: !.empty && .count(...128))
    }
}

struct LoginResponse: Content {
    let user: UserResponse
    let token: String
}

struct ForgotPasswordRequest: Content {
    let email: String
}

extension ForgotPasswordRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }
}

struct ResetPasswordRequest: Content {
    let email: String
    let token: String
    let newPassword: String
}

extension ResetPasswordRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("token", as: String.self, is: !.empty && .count(...255))
        validations.add("newPassword", as: String.self, is: .count(8...128))
    }
}

struct MessageResponse: Content {
    let message: String
}

struct AvailabilityResponse: Content {
    let available: Bool
}
