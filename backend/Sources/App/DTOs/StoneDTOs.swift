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
    let liftingLevel: String
    let carryDistance: Double?
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
    let liftingLevel: String
    let carryDistance: Double?
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
        self.liftingLevel = stone.liftingLevel
        self.carryDistance = stone.carryDistance
        self.createdAt = stone.createdAt
        self.user = UserResponse(user: user)
    }
}
