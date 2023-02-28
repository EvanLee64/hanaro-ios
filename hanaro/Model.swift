import Foundation

struct AppleLoginResponse: Codable {
    let ret: String?
    let code: String?
    let msg: String?
    let data: ClientSecret
    
    enum CodingKeys: String, CodingKey {
        case ret
        case code
        case msg
        case data
    }
}

struct ClientSecret: Codable {
    let clientSecret: String?
    
    enum CodingKeys: String, CodingKey {
        case clientSecret = "client_secret"
    }
}
