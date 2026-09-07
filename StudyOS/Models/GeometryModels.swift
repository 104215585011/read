import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// 可序列化的矩形定义，单位为 PDF Points
public struct CodableRect: Codable, Sendable, Hashable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    #if canImport(CoreGraphics)
    public init(_ cgRect: CGRect) {
        self.x = Double(cgRect.origin.x)
        self.y = Double(cgRect.origin.y)
        self.width = Double(cgRect.size.width)
        self.height = Double(cgRect.size.height)
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
    #endif
}

/// 可序列化的点定义，单位为 PDF Points
public struct CodablePoint: Codable, Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    #if canImport(CoreGraphics)
    public init(_ cgPoint: CGPoint) {
        self.x = Double(cgPoint.x)
        self.y = Double(cgPoint.y)
    }

    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
    #endif
}

/// 可序列化的 2D 仿射变换矩阵
public struct CodableTransform: Codable, Sendable, Hashable {
    public var a: Double
    public var b: Double
    public var c: Double
    public var d: Double
    public var tx: Double
    public var ty: Double

    public init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    public static let identity = CodableTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    #if canImport(CoreGraphics)
    public init(_ transform: CGAffineTransform) {
        self.a = Double(transform.a)
        self.b = Double(transform.b)
        self.c = Double(transform.c)
        self.d = Double(transform.d)
        self.tx = Double(transform.tx)
        self.ty = Double(transform.ty)
    }

    public var cgAffineTransform: CGAffineTransform {
        CGAffineTransform(a: CGFloat(a), b: CGFloat(b), c: CGFloat(c), d: CGFloat(d), tx: CGFloat(tx), ty: CGFloat(ty))
    }
    #endif
}
