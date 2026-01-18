import Fluent
import Vapor

final class Stone: Model, Content, @unchecked Sendable {
    static let schema = "stones"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String?

    @Field(key: "weight")
    var weight: Double?

    @Field(key: "estimated_weight")
    var estimatedWeight: Double?

    @Field(key: "stone_type")
    var stoneType: String?

    @Field(key: "description")
    var description: String?
    
    @Field(key: "image_url")
    var imageUrl: String?
    
    @Field(key: "latitude")
    var latitude: Double?
    
    @Field(key: "longitude")
    var longitude: Double?

    @Field(key: "is_public")
    var isPublic: Bool
    
    @Field(key: "lifting_level")
    var liftingLevel: String

    @Field(key: "report_count")
    var reportCount: Int

    @Field(key: "is_hidden")
    var isHidden: Bool

    @Parent(key: "user_id")
    var user: User

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil,
         name: String? = nil,
         weight: Double? = nil,
         estimatedWeight: Double? = nil,
         stoneType: String? = nil,
         description: String? = nil,
         imageUrl: String? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil,
         isPublic: Bool = true,
         liftingLevel: String,
         reportCount: Int = 0,
         isHidden: Bool = false,
         userID: UUID) {
        self.id = id
        self.name = name
        self.weight = weight
        self.estimatedWeight = estimatedWeight
        self.stoneType = stoneType
        self.description = description
        self.imageUrl = imageUrl
        self.latitude = latitude
        self.longitude = longitude
        self.isPublic = isPublic
        self.liftingLevel = liftingLevel
        self.reportCount = reportCount
        self.isHidden = isHidden
        self.$user.id = userID
    }
}
