import CoreLocation
import PDFKit
import UIKit

/// Displays a GeoPDF, draws the recorded track as an overlay, and shows the
/// user's current location as a dot. Location and recording are owned by the
/// injected `TrackRecorder`; this controller only renders its state. Unsupported
/// maps still display (with a banner) but get no dot/track.
public final class GeoPDFMapViewController: UIViewController {

    /// Injected by `GeoPDFMapView`. The controller reads its `latest` and
    /// `points` each frame; it never drives location itself.
    var recorder: TrackRecorder?

    private let pdfView = PDFView()
    private let overlayView = UIView()          // holds the track layer + dot, above the PDF
    private let trackLayer = CAShapeLayer()
    private let dotView = LocationDotView()
    private let bannerLabel = PaddedLabel()
    private let loader = GeoPDFLoader()

    private var georeferencer: Georeferencer?
    private var page: PDFPage?
    private var displayLink: CADisplayLink?
    private var currentURL: URL?

    /// Cheap signature of "does the track need redrawing": point count + the
    /// PDF's pan/zoom state. Rebuilds the path only when one of these changes.
    private struct TrackSignature: Equatable {
        var count: Int
        var originX: CGFloat
        var originY: CGFloat
        var scale: CGFloat
    }
    private var lastSignature: TrackSignature?

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupPDFView()
        setupOverlay()
        setupBanner()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        trackLayer.frame = overlayView.bounds
    }

    /// Open a GeoPDF. Safe to call repeatedly with the same URL (no-op).
    public func open(url: URL) {
        guard url != currentURL else { return }
        currentURL = url

        switch loader.load(url: url) {
        case .failed(let message):
            pdfView.document = nil
            georeferencer = nil
            page = nil
            stopRendering()
            showBanner(message, style: .error)

        case .unsupported(let document, let reason):
            pdfView.document = document
            pdfView.autoScales = true
            georeferencer = nil
            page = nil
            stopRendering()
            showBanner(reason.message, style: .warning)

        case .georeferenced(let document, let geo, let warnings):
            pdfView.document = document
            pdfView.autoScales = true
            georeferencer = geo
            page = document.page(at: 0)
            warnings.isEmpty ? hideBanner() : showBanner(warnings.joined(separator: "\n"), style: .info)
            startRendering()
        }
    }

    // MARK: - Rendering loop

    // PDFView exposes no single reliable "viewport changed" callback, so a
    // display link keeps the dot and track glued to the map through scroll/zoom.
    private func startRendering() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopRendering() {
        displayLink?.invalidate()
        displayLink = nil
        dotView.isHidden = true
        trackLayer.path = nil
        lastSignature = nil
    }

    @objc private func tick() {
        guard let geo = georeferencer, let page = page else {
            dotView.isHidden = true
            trackLayer.path = nil
            return
        }
        updateTrack(geo: geo, page: page)
        updateDot(geo: geo, page: page)
    }

    private func updateTrack(geo: Georeferencer, page: PDFPage) {
        let points = recorder?.points ?? []
        let origin = pdfView.convert(CGPoint.zero, from: page)
        let signature = TrackSignature(count: points.count, originX: origin.x,
                                       originY: origin.y, scale: pdfView.scaleFactor)
        guard signature != lastSignature else { return }
        lastSignature = signature

        guard points.count > 1 else { trackLayer.path = nil; return }
        let path = UIBezierPath()
        var started = false
        for point in points {
            guard let pagePoint = geo.pagePoint(for: point.coordinate) else { continue }
            let viewPoint = overlayView.convert(pdfView.convert(pagePoint, from: page), from: pdfView)
            if started {
                path.addLine(to: viewPoint)
            } else {
                path.move(to: viewPoint)
                started = true
            }
        }
        trackLayer.path = path.cgPath
    }

    private func updateDot(geo: Georeferencer, page: PDFPage) {
        guard let coordinate = recorder?.latest?.coordinate,
              geo.contains(coordinate), let pagePoint = geo.pagePoint(for: coordinate) else {
            dotView.isHidden = true
            return
        }
        dotView.center = overlayView.convert(pdfView.convert(pagePoint, from: page), from: pdfView)
        dotView.isHidden = false
    }

    // MARK: - Setup

    private func setupPDFView() {
        pdfView.autoScales = true
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupOverlay() {
        overlayView.isUserInteractionEnabled = false
        overlayView.backgroundColor = .clear
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.systemBlue.cgColor
        trackLayer.lineWidth = 4
        trackLayer.lineJoin = .round
        trackLayer.lineCap = .round
        trackLayer.opacity = 0.9
        overlayView.layer.addSublayer(trackLayer)

        dotView.isHidden = true
        overlayView.addSubview(dotView)
    }

    private func setupBanner() {
        bannerLabel.numberOfLines = 0
        bannerLabel.isHidden = true
        bannerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerLabel)
        NSLayoutConstraint.activate([
            bannerLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            bannerLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            bannerLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Banner

    private enum BannerStyle { case info, warning, error }

    private func showBanner(_ text: String, style: BannerStyle) {
        bannerLabel.text = text
        bannerLabel.isHidden = false
        switch style {
        case .info:
            bannerLabel.backgroundColor = .secondarySystemBackground
            bannerLabel.textColor = .label
        case .warning:
            bannerLabel.backgroundColor = .systemYellow
            bannerLabel.textColor = .black
        case .error:
            bannerLabel.backgroundColor = .systemRed
            bannerLabel.textColor = .white
        }
    }

    private func hideBanner() {
        bannerLabel.isHidden = true
    }
}

// MARK: - Views

/// A blue "you are here" marker with a white ring.
final class LocationDotView: UIView {
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 22, height: 22))
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setShadow(offset: .zero, blur: 3, color: UIColor.black.withAlphaComponent(0.4).cgColor)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: rect).fill()
        context?.setShadow(offset: .zero, blur: 0, color: nil)
        UIColor.systemBlue.setFill()
        UIBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4)).fill()
    }
}

/// A label with interior padding and rounded corners, used for status banners.
final class PaddedLabel: UILabel {
    private let inset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: inset))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + inset.left + inset.right,
                      height: size.height + inset.top + inset.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = 10
        layer.masksToBounds = true
    }
}
