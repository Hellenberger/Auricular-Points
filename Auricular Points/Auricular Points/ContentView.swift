import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @StateObject private var model = AuricularPointsModel()

    // Interaction state
    @State private var tapPointNorm: CGPoint? = nil
    @State private var lastTapCoords: CGPoint? = nil
    @State private var authorMode = false

    // macOS-only popover state
    @State private var showPicker = false
    @State private var searchText = ""

    // Inline selection + grading (used on iOS/iPadOS, and also for macOS result display)
    @State private var selectedPoint: EarPoint? = nil
    @State private var resultMessage: String? = nil

    // Tolerance (normalized % of image diagonal)
    @State private var tolPercent: Double = 4.0

    // Optional runtime CSV override
    @State private var showImporter = false

    // Update to match your asset name
    private let imageName = "Left_Ear_Points"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ---- Ear image + overlays + hit layer ----
                ZStack {
                    GeometryReader { geo in
                        let drawRect = imageDrawRect(in: geo, imageName: imageName)

                        // Local container pinned to the image's drawn rect
                        ZStack {
                            // 1) Ear image fills the local container
                            Image(imageName)
                                .resizable()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .allowsHitTesting(false)

                            // 2) Study overlay dots (drawn in local coords)
                            Canvas { ctx, size in
                                for p in model.points {
                                    guard let x = p.x, let y = p.y else { continue }
                                    let px = x * size.width
                                    let py = y * size.height
                                    ctx.fill(
                                        Path(ellipseIn: CGRect(x: px - 2.5, y: py - 2.5, width: 5, height: 5)),
                                        with: .color(.blue.opacity(0.22))
                                    )
                                }
                            }
                            .allowsHitTesting(false)

                            // 3) Tap halo (local coords)
                            if let norm = tapPointNorm {
                                let pt = CGPoint(x: norm.x * drawRect.width, y: norm.y * drawRect.height)
                                Circle()
                                    .strokeBorder(.yellow, lineWidth: 2)
                                    .frame(width: 18, height: 18)
                                    .position(pt)
                                    .allowsHitTesting(false)
                            }

                            // 4) Topmost hit layer (local coords)
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                        .onEnded { value in
                                            let nx = min(max(value.location.x / drawRect.width, 0), 1)
                                            let ny = min(max(value.location.y / drawRect.height, 0), 1)
                                            let norm = CGPoint(x: nx, y: ny)

                                            tapPointNorm = norm
                                            if authorMode {
                                                // Quantize to 3 decimals for stable authoring
                                                func q(_ v: CGFloat) -> Double { (Double(v) * 1000).rounded() / 1000 }
                                                let qx = q(norm.x), qy = q(norm.y)
                                                lastTapCoords = CGPoint(x: qx, y: qy)
                                                // CSV-ready line (console if debugger attached)
                                                print(String(format: "PointName,BodyPart,%.3f,%.3f", qx, qy))
                                            }

                                            // Only macOS opens the popover list on tap
                                            #if os(macOS)
                                            searchText = ""
                                            showPicker = true
                                            #endif
                                        }
                                )
                        }
                        // pin local container to the actual drawRect
                        .frame(width: drawRect.width, height: drawRect.height)
                        .position(x: drawRect.midX, y: drawRect.midY)
                    }
                    .padding()

                    // Author Mode HUD (top-left)
                    if authorMode, let c = lastTapCoords {
                        VStack(spacing: 4) {
                            Text("Author Mode").font(.caption).bold()
                            Text(String(format: "x: %.3f   y: %.3f", c.x, c.y))
                                .font(.caption.monospacedDigit())
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }

                    // Status / error line (bottom)
                    VStack {
                        Spacer()
                        HStack {
                            if let err = model.loadError {
                                Text(err).foregroundStyle(.red)
                            } else {
                                Text("Loaded points: \(model.points.count)")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                    }
                }

                // ---- iPhone/iPad inline wheel picker + grading ----
                #if os(iOS)
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("Tolerance")
                        Slider(value: $tolPercent, in: 1...10, step: 0.5) {
                            Text("Tolerance")
                        } minimumValueLabel: { Text("1%") } maximumValueLabel: { Text("10%") }
                        Text("\(Int(tolPercent))%")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }

                    Picker("Select Point", selection: Binding(
                        get: { selectedPoint ?? model.points.first },
                        set: { selectedPoint = $0 }
                    )) {
                        ForEach(model.points, id: \.id) { p in
                            // Show Body Part if present; else show Code/Name
                            Text(p.bodyPart.isEmpty ? p.name : p.bodyPart)
                                .tag(Optional(p))
                        }
                    }
                    .pickerStyle(.wheel)

                    Button("Check Answer") {
                        if let guess = selectedPoint {
                            gradeAnswerInline(guess: guess)
                        } else {
                            resultMessage = "Pick a point from the list."
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if let msg = resultMessage {
                        Text(msg)
                            .font(.headline)
                            .foregroundStyle(msg.hasPrefix("✅") ? .green : .red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                #endif
            } // end VStack

            // Nav mods + toolbars applied to the VStack inside NavigationStack
            .navigationTitle("Auricular Points")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Toggle(isOn: $authorMode) { Text("Author Mode") }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Load CSV…") { showImporter = true }
                }
            }

            // macOS-only popover list; result appears inline (no alerts)
            #if os(macOS)
            .popover(isPresented: $showPicker, arrowEdge: .bottom) {
                PointPickerSheet(points: model.points, searchText: $searchText) { chosen in
                    gradeAnswerInline(guess: chosen)
                }
                .frame(width: 420, height: 520)
                .padding()
            }
            #endif

            // Optional: file importer override
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let ok = url.startAccessingSecurityScopedResource()
                    defer { if ok { url.stopAccessingSecurityScopedResource() } }
                    model.loadCSV(from: url)
                case .failure(let error):
                    model.loadError = "Failed to open CSV: \(error.localizedDescription)"
                }
            }
        } // end NavigationStack
        #if os(macOS)
        .onHover { hovering in if hovering { NSCursor.pointingHand.set() } }
        #endif
    }

    // MARK: - Inline grading (shared)
    private func gradeAnswerInline(guess: EarPoint) {
        guard let tap = tapPointNorm else {
            resultMessage = "⚠️ Tap a location on the ear first."
            return
        }
        guard let nearest = model.nearestPoint(to: tap) else {
            resultMessage = "⚠️ No reference coordinates stored yet."
            return
        }
        let tol = CGFloat(tolPercent / 100.0) // e.g., 0.04 for 4%

        if guess.name == nearest.point.name, nearest.distance <= tol {
            resultMessage = "✅ Correct: \(nearest.point.name) (\(nearest.point.bodyPart))"
        } else {
            resultMessage = "❌ Incorrect. You chose \(guess.name).\n" +
                            "Correct: \(nearest.point.name) (\(nearest.point.bodyPart))"
        }
    }

    // MARK: - Geometry helpers
    private func imagePixelSize(named name: String) -> CGSize? {
        #if canImport(UIKit)
        return UIImage(named: name)?.size
        #elseif canImport(AppKit)
        return NSImage(named: name)?.size
        #else
        return nil
        #endif
    }

    /// Where the image is actually drawn inside the available view (accounts for aspect fit).
    private func imageDrawRect(in geo: GeometryProxy, imageName: String) -> CGRect {
        let view = geo.size
        let img  = imagePixelSize(named: imageName) ?? .init(width: 1, height: 1)
        let imageAspect = img.width / img.height
        let viewAspect  = view.width / view.height

        if viewAspect > imageAspect {
            // pillarbox left/right
            let w = view.height * imageAspect
            let x = (view.width - w) / 2
            return CGRect(x: x, y: 0, width: w, height: view.height)
        } else {
            // letterbox top/bottom
            let h = view.width / imageAspect
            let y = (view.height - h) / 2
            return CGRect(x: 0, y: y, width: view.width, height: h)
        }
    }
}
