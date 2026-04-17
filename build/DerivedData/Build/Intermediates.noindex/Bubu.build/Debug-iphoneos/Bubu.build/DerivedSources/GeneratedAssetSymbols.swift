import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "bubu" asset catalog image resource.
    static let bubu = DeveloperToolsSupport.ImageResource(name: "bubu", bundle: resourceBundle)

    /// The "bubu-bike" asset catalog image resource.
    static let bubuBike = DeveloperToolsSupport.ImageResource(name: "bubu-bike", bundle: resourceBundle)

    /// The "bubu-scooter" asset catalog image resource.
    static let bubuScooter = DeveloperToolsSupport.ImageResource(name: "bubu-scooter", bundle: resourceBundle)

    /// The "bubu-skate" asset catalog image resource.
    static let bubuSkate = DeveloperToolsSupport.ImageResource(name: "bubu-skate", bundle: resourceBundle)

    /// The "elephant" asset catalog image resource.
    static let elephant = DeveloperToolsSupport.ImageResource(name: "elephant", bundle: resourceBundle)

    /// The "giraffe" asset catalog image resource.
    static let giraffe = DeveloperToolsSupport.ImageResource(name: "giraffe", bundle: resourceBundle)

    /// The "lion" asset catalog image resource.
    static let lion = DeveloperToolsSupport.ImageResource(name: "lion", bundle: resourceBundle)

    /// The "purse" asset catalog image resource.
    static let purse = DeveloperToolsSupport.ImageResource(name: "purse", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "bubu" asset catalog image.
    static var bubu: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bubu)
#else
        .init()
#endif
    }

    /// The "bubu-bike" asset catalog image.
    static var bubuBike: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bubuBike)
#else
        .init()
#endif
    }

    /// The "bubu-scooter" asset catalog image.
    static var bubuScooter: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bubuScooter)
#else
        .init()
#endif
    }

    /// The "bubu-skate" asset catalog image.
    static var bubuSkate: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .bubuSkate)
#else
        .init()
#endif
    }

    /// The "elephant" asset catalog image.
    static var elephant: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .elephant)
#else
        .init()
#endif
    }

    /// The "giraffe" asset catalog image.
    static var giraffe: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .giraffe)
#else
        .init()
#endif
    }

    /// The "lion" asset catalog image.
    static var lion: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .lion)
#else
        .init()
#endif
    }

    /// The "purse" asset catalog image.
    static var purse: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .purse)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "bubu" asset catalog image.
    static var bubu: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bubu)
#else
        .init()
#endif
    }

    /// The "bubu-bike" asset catalog image.
    static var bubuBike: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bubuBike)
#else
        .init()
#endif
    }

    /// The "bubu-scooter" asset catalog image.
    static var bubuScooter: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bubuScooter)
#else
        .init()
#endif
    }

    /// The "bubu-skate" asset catalog image.
    static var bubuSkate: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .bubuSkate)
#else
        .init()
#endif
    }

    /// The "elephant" asset catalog image.
    static var elephant: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .elephant)
#else
        .init()
#endif
    }

    /// The "giraffe" asset catalog image.
    static var giraffe: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .giraffe)
#else
        .init()
#endif
    }

    /// The "lion" asset catalog image.
    static var lion: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .lion)
#else
        .init()
#endif
    }

    /// The "purse" asset catalog image.
    static var purse: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .purse)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

