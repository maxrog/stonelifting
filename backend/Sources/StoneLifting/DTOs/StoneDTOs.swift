import Vapor

struct CreateStoneRequest: Content {
    let name: String?
    let weight: Double?
    let estimatedWeight: Double?
    let stoneType: String?
    let description: String?
    let imageUrl: String?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let isPublic: Bool
    let liftingLevel: String
}

extension CreateStoneRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        // Name: optional but max 100 chars if provided
        validations.add("name", as: String?.self, is: .nil || .count(...100), required: false)

        // Weight: optional, positive, reasonable range (1-1000 lbs) if provided
        validations.add("weight", as: Double?.self, is: .nil || .range(1...1000), required: false)

        // Estimated weight: optional, positive (1-1000 lbs) if provided
        validations.add("estimatedWeight", as: Double?.self, is: .nil || .range(1...1000), required: false)

        // Stone type: valid enum value if provided (granite, limestone, sandstone, basalt, marble)
        validations.add("stoneType", as: String?.self, is: .nil || .in("granite", "limestone", "sandstone", "basalt", "marble"), required: false)

        // Description: max 1000 chars if provided
        validations.add("description", as: String?.self, is: .nil || .count(...1000), required: false)

        // Image URL: max 500 chars if provided
        validations.add("imageUrl", as: String?.self, is: .nil || .count(...500), required: false)

        // Latitude: valid range if provided
        validations.add("latitude", as: Double?.self, is: .nil || .range(-90...90), required: false)

        // Longitude: valid range if provided
        validations.add("longitude", as: Double?.self, is: .nil || .range(-180...180), required: false)

        // Location name: max 200 chars if provided
        validations.add("locationName", as: String?.self, is: .nil || .count(...200), required: false)

        // Lifting level: max 50 chars (should be enum in future)
        validations.add("liftingLevel", as: String.self, is: .count(...50))
    }
}

struct StoneResponse: Content {
    let id: UUID?
    let name: String?
    let weight: Double?
    let estimatedWeight: Double?
    let stoneType: String?
    let description: String?
    let imageUrl: String?
    let latitude: Double?
    let longitude: Double?
    let locationName: String?
    let isPublic: Bool
    let liftingLevel: String
    let createdAt: Date?
    let user: UserResponse

    init(stone: Stone, user: User) {
        self.id = stone.id
        self.name = stone.name
        self.weight = stone.weight
        self.estimatedWeight = stone.estimatedWeight
        self.stoneType = stone.stoneType
        self.description = stone.description
        self.imageUrl = stone.imageUrl
        self.latitude = stone.latitude
        self.longitude = stone.longitude
        self.locationName = stone.locationName
        self.isPublic = stone.isPublic
        self.liftingLevel = stone.liftingLevel
        self.createdAt = stone.createdAt
        self.user = UserResponse(user: user)
    }
}
