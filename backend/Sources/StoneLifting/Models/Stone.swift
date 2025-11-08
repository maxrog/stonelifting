import Fluent
import Vapor

final class Stone: Model, Content, @unchecked Sendable {
    static let schema = "stones"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String?
    
    @Field(key: "weight")
    var weight: Double
    
    @Field(key: "estimated_weight")
    var estimatedWeight: Double?
    
    @Field(key: "description")
    var description: String?
    
    @Field(key: "image_url")
    var imageUrl: String?
    
    @Field(key: "latitude")
    var latitude: Double?
    
    @Field(key: "longitude")
    var longitude: Double?
    
    @Field(key: "location_name")
    var locationName: String?
    
    @Field(key: "is_public")
    var isPublic: Bool
    
    @Field(key: "lifting_level")
    var liftingLevel: String
    
    @Field(key: "carry_distance")
    var carryDistance: Double?
    
    @Parent(key: "user_id")
    var user: User
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         name: String? = nil,
         weight: Double,
         estimatedWeight: Double? = nil,
         description: String? = nil,
         imageUrl: String? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil,
         locationName: String? = nil,
         isPublic: Bool = true,
         liftingLevel: String,
         carryDistance: Double? = nil,
         userID: UUID) {
        self.id = id
        self.name = name
        self.weight = weight
        self.estimatedWeight = estimatedWeight
        self.description = description
        self.imageUrl = imageUrl
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.isPublic = isPublic
        self.liftingLevel = liftingLevel
        self.carryDistance = carryDistance
        self.$user.id = userID
    }
}
