import Vapor

struct CreateStoneRequest: Content {
    let name: String?
    let weight: Double
    let estimatedWeight: Double?
    let description: String?
    let imageUrl: String?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let isPublic: Bool
    let difficultyRating: Int?
}

struct StoneResponse: Content {
    let id: UUID?
    let name: String?
    let weight: Double
    let estimatedWeight: Double?
    let description: String?
    let imageUrl: String?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let isPublic: Bool
    let difficultyRating: Int?
    let createdAt: Date?
    let user: UserResponse
    
    init(stone: Stone, user: User) {
        self.id = stone.id
        self.name = stone.name
        self.weight = stone.weight
        self.estimatedWeight = stone.estimatedWeight
        self.description = stone.description
        self.imageUrl = stone.imageUrl
        self.latitude = stone.latitude
        self.longitude = stone.longitude
        self.locationName = stone.locationName
        self.isPublic = stone.isPublic
        self.difficultyRating = stone.difficultyRating
        self.createdAt = stone.createdAt
        self.user = UserResponse(user: user)
    }
}
