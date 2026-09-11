import CoreLocation
import PDFKit
import UIKit

/// Displays a GeoPDF and, when supported, tracks the user's location as a dot.
/// Falls back to a plain PDF view (with an explanatory banner) for unsupported
/// maps, and shows an error banner for files that can't be opened at all.
public final class GeoPDFMapViewController: UIViewController {

    private let pdfView = PDFView()
    private let dotView = LocationDotView()
    private let bannerLabel = PaddedLabel()
    private let locationManager = CLLocationManager()
    private let loader = GeoPDFLoader()

    private var georeferencer: Georeferencer?
    private var page: PDFPage?
    private var displayLink: CADisplayLink?
    private var lastCoordinate: CLLocationCoordinate2D?
    private var currentURL: URL?

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupPDFView()
        setupOverlay()
        setupBanner()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
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
            stopTracking()
            showBanner(message, style: .error)

        case .unsupported(let document, let reason):
            pdfView.document = document
            pdfView.autoScales = true
            georeferencer = nil
            page = nil
            stopTracking()
            showBanner(reason.message, style: .warning)

        case .georeferenced(let document, let geo, let warnings):
            pdfView.document = document
            pdfView.autoScales = true
            georeferencer = geo
            page = document.page(at: 0)
            warnings.isEmpty ? hideBanner() : showBanner(warnings.joined(separator: "\n"), style: .info)
            startTracking()
        }
    }

    // MARK: - Location tracking

    private func startTracking() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            showBanner("Enable location access in Settings to see your position on the map.", style: .warning)
        }
        startDisplayLink()
    }

    private func stopTracking() {
        locationManager.stopUpdatingLocation()
        stopDisplayLink()
        dotView.isHidden = true
    }

    // PDFView exposes no single reliable "viewport changed" callback, so a
    // display link keeps the dot glued to the map through scroll and zoom.
    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(updateDotPosition))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateDotPosition() {
        guard let geo = georeferencer, let page = page, let coordinate = lastCoordinate,
              geo.contains(coordinate), let pagePoint = geo.pagePoint(for: coordinate) else {
            dotView.isHidden = true
            return
        }
        let pointInPDFView = pdfView.convert(pagePoint, from: page)
        dotView.center = view.convert(pointInPDFView, from: pdfView)
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
        dotView.isHidden = true
        view.addSubview(dotView) // sits above the PDF, below the banner
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

// MARK: - CLLocationManagerDelegate

extension GeoPDFMapViewController: CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            showBanner("Location access is off; your position won't be shown.", style: .warning)
        default:
            break
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastCoordinate = locations.last?.coordinate
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient failures are common outdoors; keep the last known position.
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
