//
//  ImageDTOs.swift
//  App
//
//  Created by Max Rogers on 9/22/25.
//

import Vapor

struct ImageUploadRequest: Content {
    let imageData: String // base64 encoded
    let contentType: String
}

struct ImageUploadResponse: Content {
    let success: Bool
    let imageUrl: String
    let message: String?
}
