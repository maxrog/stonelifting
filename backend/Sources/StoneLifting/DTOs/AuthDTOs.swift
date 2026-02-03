import Vapor

// MARK: - OAuth Authentication

struct LoginResponse: Content {
    let user: UserResponse
    let token: String
}

struct MessageResponse: Content {
    let message: String
}

struct AvailabilityResponse: Content {
    let available: Bool
}

struct AppleSignInRequest: Content {
    let identityToken: String
    let authorizationCode: String
    let fullName: AppleUserName?
    let email: String?
    let nonce: String
}

struct AppleUserName: Content {
    let givenName: String?
    let familyName: String?
}

struct GoogleSignInRequest: Content {
    let idToken: String
    let accessToken: String?
}

extension AppleSignInRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("identityToken", as: String.self, is: !.empty)
        validations.add("authorizationCode", as: String.self, is: !.empty)
        validations.add("nonce", as: String.self, is: !.empty)
    }
}

extension GoogleSignInRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("idToken", as: String.self, is: !.empty)
    }
}
