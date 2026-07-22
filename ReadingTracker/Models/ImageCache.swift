import AppKit

@MainActor
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 200 // Keep up to 200 images in memory to avoid huge RAM usage
    }
    
    func get(forKey key: String) -> NSImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func set(_ image: NSImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
