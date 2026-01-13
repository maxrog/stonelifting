# StoneLifting Backend

💧 A Vapor-based REST API for the StoneLifting iOS app.

## Features

- 🔐 JWT-based authentication
- 🗄️ PostgreSQL database with Fluent ORM
- 📷 Image upload with Cloudinary integration
- 🛡️ Content moderation (images via AWS Rekognition, text via OpenAI)
- 🚫 User reporting system with auto-hiding
- 📍 Geospatial queries for nearby stones

## Getting Started

### Prerequisites

- Swift 6.0+
- PostgreSQL database
- Cloudinary account (for image hosting)
- OpenAI API key (for text moderation - free tier available)

### Environment Configuration

Copy `.env` and configure the following variables:

```bash
# Database
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=stonelifting
DATABASE_PASSWORD=your_password
DATABASE_NAME=stonelifting

# Authentication
JWT_SECRET=your-super-secret-jwt-key

# CORS (for web clients)
CORS_ALLOWED_ORIGIN=http://localhost:3000

# Cloudinary (image hosting with moderation)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# OpenAI (text content moderation - free to use)
# Get your key from: https://platform.openai.com/api-keys
OPENAI_API_KEY=your_openai_api_key
```

### Building & Running

Build the project:
```bash
swift build
```

Run the server:
```bash
swift run
```

Run tests:
```bash
swift test
```

## Database Migrations

The project uses Fluent's migration system for schema management. Migrations run automatically on startup.

**See [Migrations/README.md](Sources/StoneLifting/Migrations/README.md) for:**
- How to add new migrations
- Railway deployment behavior
- Migration best practices
- Common patterns (add columns, indexes, etc.)
- Troubleshooting guide

## Content Moderation

The API includes two layers of content moderation:

1. **Image Moderation**: Cloudinary with AWS Rekognition automatically scans uploaded images for explicit, suggestive, or violent content
2. **Text Moderation**: OpenAI Moderation API checks user-generated text (usernames, stone names, descriptions, location names) for inappropriate content

If moderation fails, users receive helpful error messages asking them to revise their content.

## API Endpoints

### Authentication
- `POST /auth/register` - Create new user account
- `POST /auth/login` - Login and receive JWT token
- `POST /auth/forgot-password` - Request password reset
- `POST /auth/reset-password` - Reset password with token
- `GET /auth/check-username/:username` - Check username availability
- `GET /auth/check-email/:email` - Check email availability

### User
- `GET /me` - Get current user info (authenticated)
- `GET /stats` - Get user statistics (authenticated)

### Stones
- `POST /stones` - Create new stone (authenticated)
- `GET /stones` - Get user's stones (authenticated)
- `GET /stones/public` - Get public stones feed
- `GET /stones/nearby?lat=X&lon=Y&radius=Z` - Get nearby stones (authenticated)
- `PUT /stones/:id` - Update stone (authenticated)
- `DELETE /stones/:id` - Delete stone (authenticated)
- `POST /stones/:id/report` - Report inappropriate stone (authenticated)

### Images
- `POST /upload/image` - Upload image to Cloudinary (authenticated, max 5MB)

## Resources

- [Vapor Website](https://vapor.codes)
- [Vapor Documentation](https://docs.vapor.codes)
- [Vapor GitHub](https://github.com/vapor)
- [OpenAI Moderation API](https://platform.openai.com/docs/guides/moderation)
