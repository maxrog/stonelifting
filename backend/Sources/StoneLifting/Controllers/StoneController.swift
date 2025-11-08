import Fluent
import Vapor

struct StoneController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let stones = routes.grouped("stones")
        
        let protectedStones = stones.grouped(AuthController.JWTAuthenticator())
        protectedStones.post(use: create)
        protectedStones.get(use: getUserStones)
        protectedStones.get("nearby", use: getNearbyStones)
        protectedStones.get("public", use: getPublicStones)
        protectedStones.delete(":stoneID", use: delete)
        protectedStones.put(":stoneID", use: update)
    }
    
    func create(req: Request) async throws -> StoneResponse {
        let user = try req.auth.require(User.self)
        try CreateStoneRequest.validate(content: req)
        let createStone = try req.content.decode(CreateStoneRequest.self)

        let stone = Stone(
            name: createStone.name,
            weight: createStone.weight,
            estimatedWeight: createStone.estimatedWeight,
            description: createStone.description,
            imageUrl: createStone.imageUrl,
            latitude: createStone.latitude,
            longitude: createStone.longitude,
            locationName: createStone.locationName,
            isPublic: createStone.isPublic,
            liftingLevel: createStone.liftingLevel,
            carryDistance: createStone.carryDistance,
            userID: try user.requireID()
        )
        
        try await stone.save(on: req.db)
        
        return StoneResponse(stone: stone, user: user)
    }
    
    func getUserStones(req: Request) async throws -> [StoneResponse] {
        let user = try req.auth.require(User.self)
        
        let stones = try await Stone.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .sort(\.$createdAt, .descending)
            .all()
        
        return stones.map { StoneResponse(stone: $0, user: user) }
    }
    
    func getNearbyStones(req: Request) async throws -> [StoneResponse] {
        let user = try req.auth.require(User.self)
        
        guard let lat = req.query[Double.self, at: "lat"],
              let lon = req.query[Double.self, at: "lon"],
              let radius = req.query[Double.self, at: "radius"] else {
            throw Abort(.badRequest, reason: "Missing required parameters: lat, lon, radius")
        }
        
        // TODO
        // Simple bounding box query (for production, use PostGIS for proper geospatial queries)
        let latRange = calculateLatRange(centerLat: lat, radiusKm: radius)
        let lonRange = calculateLonRange(centerLon: lon, radiusKm: radius, latitude: lat)
        
        let stones = try await Stone.query(on: req.db)
            .filter(\.$isPublic == true)
            .filter(\.$latitude >= latRange.min)
            .filter(\.$latitude <= latRange.max)
            .filter(\.$longitude >= lonRange.min)
            .filter(\.$longitude <= lonRange.max)
            .with(\.$user)
            .all()
        
        return stones.map { StoneResponse(stone: $0, user: $0.user) }
    }
    
    func getPublicStones(req: Request) async throws -> [StoneResponse] {
        let stones = try await Stone.query(on: req.db)
            .filter(\.$isPublic == true)
            .with(\.$user)
            .sort(\.$createdAt, .descending)
            .limit(100)
            .all()
        
        return stones.map { StoneResponse(stone: $0, user: $0.user) }
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        
        guard let stoneID = req.parameters.get("stoneID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid stone ID")
        }
        
        guard let stone = try await Stone.query(on: req.db)
            .filter(\.$id == stoneID)
            .filter(\.$user.$id == user.requireID())
            .first() else {
            throw Abort(.notFound, reason: "Stone not found")
        }
        
        try await stone.delete(on: req.db)
        
        return .ok
    }
    
    func update(req: Request) async throws -> StoneResponse {
        let user = try req.auth.require(User.self)
        try CreateStoneRequest.validate(content: req)
        let updateStone = try req.content.decode(CreateStoneRequest.self)

        guard let stoneID = req.parameters.get("stoneID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid stone ID")
        }
        
        guard let stone = try await Stone.query(on: req.db)
            .filter(\.$id == stoneID)
            .filter(\.$user.$id == user.requireID())
            .first() else {
            throw Abort(.notFound, reason: "Stone not found")
        }
        
        stone.name = updateStone.name
        stone.weight = updateStone.weight
        stone.estimatedWeight = updateStone.estimatedWeight
        stone.description = updateStone.description
        stone.imageUrl = updateStone.imageUrl
        stone.latitude = updateStone.latitude
        stone.longitude = updateStone.longitude
        stone.locationName = updateStone.locationName
        stone.isPublic = updateStone.isPublic
        stone.liftingLevel = updateStone.liftingLevel
        stone.carryDistance = updateStone.carryDistance
        
        try await stone.save(on: req.db)
        
        return StoneResponse(stone: stone, user: user)
    }
    
    // MARK: - Helper Methods
    private func calculateLatRange(centerLat: Double, radiusKm: Double) -> (min: Double, max: Double) {
        let latDegreesPerKm = 1.0 / 111.0
        let latOffset = radiusKm * latDegreesPerKm
        return (min: centerLat - latOffset, max: centerLat + latOffset)
    }
    
    private func calculateLonRange(centerLon: Double, radiusKm: Double, latitude: Double) -> (min: Double, max: Double) {
        let lonDegreesPerKm = 1.0 / (111.0 * cos(latitude * .pi / 180.0))
        let lonOffset = radiusKm * lonDegreesPerKm
        return (min: centerLon - lonOffset, max: centerLon + lonOffset)
    }
}
