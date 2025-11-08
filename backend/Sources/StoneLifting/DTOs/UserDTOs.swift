import Vapor

struct UserResponse: Content {
    let id: UUID?
    let username: String
    let email: String
    let createdAt: Date?
    
    init(user: User) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.createdAt = user.createdAt
    }
}

struct UserStatsResponse: Content {
    let id: UUID?
    let username: String
    let email: String
    let createdAt: Date?
    let stones: [StoneResponse]
    
    init(user: User, stones: [StoneResponse]) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.createdAt = user.createdAt
        self.stones = stones
    }
}
