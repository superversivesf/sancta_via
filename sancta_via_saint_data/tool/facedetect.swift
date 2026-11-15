// One-off face-detection probe: prints face bounding boxes (normalized)
// for an image, using the macOS Vision framework.
import AppKit
import Vision

func detectFaces(_ path: String) -> [CGRect] {
    guard let source = CGImageSourceCreateWithURL(
        NSURL(fileURLWithPath: path), nil
    ) else {
        fputs("cannot open \(path)\n", stderr)
        exit(2)
    }
    let request = VNDetectFaceRectanglesRequest()
    let handler = VNImageRequestHandler(cgImage: CGImageSourceCreateImageAtIndex(source, 0, nil)!, options: [:])
    try? handler.perform([request])
    return (request.results ?? []).map { $0.boundingBox }
}

let found = detectFaces(CommandLine.arguments[1])
print("[")
for (i, f) in found.enumerated() {
    let sep = i < found.count - 1 ? "," : ""
    // Vision uses a bottom-left origin; consumers expect top-left.
    let yTop = 1 - (f.origin.y + f.size.height)
    print("{\"x\": \(f.origin.x), \"y\": \(yTop), \"w\": \(f.size.width), \"h\": \(f.size.height)}\(sep)")
}
print("]")
