import Foundation
import CryptoKit

/// AWS Signature Version 4 signing for S3 requests.
/// Compatible with Digital Ocean Spaces and other S3-compatible services.
///
/// Reference: https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html
class AWSV4Signer {
    
    private let accessKey: String
    private let secretKey: String
    private let region: String
    private let service: String = "s3"
    
    init(accessKey: String, secretKey: String, region: String) {
        self.accessKey = accessKey
        self.secretKey = secretKey
        self.region = region
    }
    
    // MARK: - Public Methods
    
    /// Sign an HTTP request with AWS Signature V4
    func sign(request: inout URLRequest, payload: Data? = nil) {
        guard let url = request.url else { return }
        
        // Step 1: Create canonical request
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let datestamp = String(timestamp.prefix(8))
        
        // Add required headers
        request.setValue(url.host, forHTTPHeaderField: "Host")
        request.setValue(timestamp, forHTTPHeaderField: "X-Amz-Date")
        
        // Calculate payload hash
        let payloadHash: String
        if let payload = payload {
            payloadHash = sha256(data: payload)
        } else {
            payloadHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" // Empty hash
        }
        request.setValue(payloadHash, forHTTPHeaderField: "X-Amz-Content-SHA256")
        
        // Build canonical request
        let canonicalRequest = buildCanonicalRequest(
            method: request.httpMethod ?? "GET",
            url: url,
            headers: request.allHTTPHeaderFields ?? [:],
            payloadHash: payloadHash
        )
        
        // Step 2: Create string to sign
        let credentialScope = "\(datestamp)/\(region)/\(service)/aws4_request"
        let stringToSign = buildStringToSign(
            timestamp: timestamp,
            credentialScope: credentialScope,
            canonicalRequest: canonicalRequest
        )
        
        // Step 3: Calculate signature
        let signature = calculateSignature(
            stringToSign: stringToSign,
            datestamp: datestamp,
            secretKey: secretKey
        )
        
        // Step 4: Add authorization header
        let signedHeaders = getSignedHeaders(from: request.allHTTPHeaderFields ?? [:])
        let authorization = "AWS4-HMAC-SHA256 " +
            "Credential=\(accessKey)/\(credentialScope), " +
            "SignedHeaders=\(signedHeaders), " +
            "Signature=\(signature)"
        
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }
    
    // MARK: - Canonical Request
    
    private func buildCanonicalRequest(
        method: String,
        url: URL,
        headers: [String: String],
        payloadHash: String
    ) -> String {
        // Canonical URI
        let canonicalURI = url.path.isEmpty ? "/" : url.path
        
        // Canonical query string
        let canonicalQueryString = buildCanonicalQueryString(from: url)
        
        // Canonical headers
        let canonicalHeaders = buildCanonicalHeaders(from: headers)
        
        // Signed headers
        let signedHeaders = getSignedHeaders(from: headers)
        
        // Combine
        return [
            method,
            canonicalURI,
            canonicalQueryString,
            canonicalHeaders,
            "",
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")
    }
    
    private func buildCanonicalQueryString(from url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return ""
        }
        
        // Sort query parameters by name
        let sorted = queryItems.sorted { $0.name < $1.name }
        
        return sorted.map { item in
            let name = urlEncode(item.name)
            let value = urlEncode(item.value ?? "")
            return "\(name)=\(value)"
        }.joined(separator: "&")
    }
    
    private func buildCanonicalHeaders(from headers: [String: String]) -> String {
        // Convert to lowercase and sort
        let sorted = headers
            .map { (key: $0.key.lowercased(), value: $0.value.trimmingCharacters(in: .whitespaces)) }
            .sorted { $0.key < $1.key }
        
        return sorted.map { "\($0.key):\($0.value)\n" }.joined()
    }
    
    private func getSignedHeaders(from headers: [String: String]) -> String {
        headers.keys
            .map { $0.lowercased() }
            .sorted()
            .joined(separator: ";")
    }
    
    // MARK: - String to Sign
    
    private func buildStringToSign(
        timestamp: String,
        credentialScope: String,
        canonicalRequest: String
    ) -> String {
        let hashedCanonicalRequest = sha256(string: canonicalRequest)
        
        return [
            "AWS4-HMAC-SHA256",
            timestamp,
            credentialScope,
            hashedCanonicalRequest
        ].joined(separator: "\n")
    }
    
    // MARK: - Signature Calculation
    
    private func calculateSignature(
        stringToSign: String,
        datestamp: String,
        secretKey: String
    ) -> String {
        // Derive signing key
        let kDate = hmac(key: "AWS4\(secretKey)", data: datestamp)
        let kRegion = hmac(key: kDate, data: region)
        let kService = hmac(key: kRegion, data: service)
        let kSigning = hmac(key: kService, data: "aws4_request")
        
        // Calculate signature
        let signature = hmac(key: kSigning, data: stringToSign)
        
        return signature.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Cryptographic Functions
    
    private func sha256(string: String) -> String {
        sha256(data: Data(string.utf8))
    }
    
    private func sha256(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func hmac(key: String, data: String) -> Data {
        hmac(key: Data(key.utf8), data: Data(data.utf8))
    }
    
    private func hmac(key: Data, data: String) -> Data {
        hmac(key: key, data: Data(data.utf8))
    }
    
    private func hmac(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(authenticationCode)
    }
    
    // MARK: - URL Encoding
    
    private func urlEncode(_ string: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }
}

// MARK: - Convenience Extensions

extension URLRequest {
    
    /// Sign this request with AWS Signature V4
    mutating func signWithAWSV4(
        accessKey: String,
        secretKey: String,
        region: String,
        payload: Data? = nil
    ) {
        let signer = AWSV4Signer(accessKey: accessKey, secretKey: secretKey, region: region)
        signer.sign(request: &self, payload: payload)
    }
}

// MARK: - S3 Request Builder

struct S3Request {
    let endpoint: String
    let bucket: String
    let region: String
    let accessKey: String
    let secretKey: String
    
    /// Build a signed PUT request for uploading to S3
    func buildPutRequest(path: String, data: Data, contentType: String = "application/json") -> URLRequest {
        let url = URL(string: "https://\(bucket).\(endpoint)/\(path)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        
        // Sign with AWS V4
        request.signWithAWSV4(
            accessKey: accessKey,
            secretKey: secretKey,
            region: region,
            payload: data
        )
        
        return request
    }
    
    /// Build a signed GET request for downloading from S3
    func buildGetRequest(path: String) -> URLRequest {
        let url = URL(string: "https://\(bucket).\(endpoint)/\(path)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Sign with AWS V4
        request.signWithAWSV4(
            accessKey: accessKey,
            secretKey: secretKey,
            region: region
        )
        
        return request
    }
    
    /// Build a signed HEAD request for checking if object exists
    func buildHeadRequest(path: String) -> URLRequest {
        let url = URL(string: "https://\(bucket).\(endpoint)/\(path)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        // Sign with AWS V4
        request.signWithAWSV4(
            accessKey: accessKey,
            secretKey: secretKey,
            region: region
        )
        
        return request
    }
    
    /// Build a signed DELETE request for deleting from S3
    func buildDeleteRequest(path: String) -> URLRequest {
        let url = URL(string: "https://\(bucket).\(endpoint)/\(path)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        // Sign with AWS V4
        request.signWithAWSV4(
            accessKey: accessKey,
            secretKey: secretKey,
            region: region
        )
        
        return request
    }
    
    /// Build a signed LIST request for listing bucket contents
    func buildListRequest(prefix: String? = nil, maxKeys: Int = 1000) -> URLRequest {
        var urlComponents = URLComponents(string: "https://\(bucket).\(endpoint)/")!
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "list-type", value: "2"),
            URLQueryItem(name: "max-keys", value: "\(maxKeys)")
        ]
        
        if let prefix = prefix {
            queryItems.append(URLQueryItem(name: "prefix", value: prefix))
        }
        
        urlComponents.queryItems = queryItems
        
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"
        
        // Sign with AWS V4
        request.signWithAWSV4(
            accessKey: accessKey,
            secretKey: secretKey,
            region: region
        )
        
        return request
    }
}
