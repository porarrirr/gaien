import CoreLocation
import MapKit
import SwiftUI

struct LocationZoneEditorSheet: View {
    @ObservedObject var focusController: ScreenTimeFocusController
    let zoneID: String
    let canEdit: Bool
    let onUpdate: (String, (inout FocusLocationZone) -> Void) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeleteConfirmation = false
    @State private var isLocating = false

    private var zone: FocusLocationZone? {
        focusController.settings.locationZones.first { $0.id == zoneID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let zone {
                    editor(zone)
                } else {
                    Color.clear
                        .onAppear { dismiss() }
                }
            }
            .strictScreen()
            .navigationTitle("場所")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                        .font(.body.weight(.bold))
                }
            }
            .confirmationDialog("この場所を削除しますか？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
                Button("削除する", role: .destructive) {
                    onDelete(zoneID)
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    @ViewBuilder
    private func editor(_ zone: FocusLocationZone) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard(zone)
                mapGroup(zone)
                nameGroup(zone)
                radiusGroup(zone)
                lockGroup(zone)
                deleteButton
            }
            .padding(.horizontal, 17)
            .padding(.top, 14)
            .padding(.bottom, 32)
            .disabled(!canEdit)
        }
    }

    private func summaryCard(_ zone: FocusLocationZone) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(zone.title)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(summaryDetail(zone))
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private func summaryDetail(_ zone: FocusLocationZone) -> String {
        if !zone.coordinateWasSet {
            return "地図をタップするか、現在地を指定してください。"
        }
        let radius = "半径\(zone.radiusMeters)m"
        if zone.isNonNegotiableBlock {
            return "\(radius)・解除不可"
        }
        return radius
    }

    private func mapGroup(_ zone: FocusLocationZone) -> some View {
        group(title: "位置") {
            LocationZoneMapView(
                latitude: zone.latitude,
                longitude: zone.longitude,
                radiusMeters: zone.radiusMeters,
                isCoordinateSet: zone.coordinateWasSet,
                onCoordinateChange: { coordinate in
                    onUpdate(zone.id) { current in
                        current.setCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        if !current.isEnabled {
                            current.isEnabled = true
                        }
                    }
                }
            )
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.vertical, 4)

            Divider()
                .padding(.vertical, 8)

            Button {
                Task { await useCurrentLocation(for: zone) }
            } label: {
                HStack(spacing: 10) {
                    if isLocating {
                        ProgressView()
                    } else {
                        Image(systemName: "location.fill")
                    }
                    Text("現在地を使う")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                }
                .foregroundStyle(AppColors.success)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(isLocating)

            Text("学校や図書館など、制限したい場所の中心を指定します。場所は端末ごとに設定し、サーバーには送りません。")
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nameGroup(_ zone: FocusLocationZone) -> some View {
        group(title: "名前") {
            TextField("学校、図書館など", text: Binding(
                get: { zone.title },
                set: { title in
                    onUpdate(zone.id) { $0.title = title }
                }
            ))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.textPrimary)
            .frame(minHeight: 44)
        }
    }

    private func radiusGroup(_ zone: FocusLocationZone) -> some View {
        group(title: "半径") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(zone.radiusMeters)m")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    Text("建物まわりは150m、キャンパスは300mが目安です")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Slider(
                    value: Binding(
                        get: { Double(zone.radiusMeters) },
                        set: { meters in
                            onUpdate(zone.id) {
                                $0.radiusMeters = FocusLocationZone.clampedRadius(Int(meters.rounded()))
                            }
                        }
                    ),
                    in: Double(FocusLocationZone.minimumRadiusMeters)...Double(FocusLocationZone.maximumRadiusMeters),
                    step: 50
                )
                .tint(AppColors.success)
            }
            .padding(.vertical, 4)
        }
    }

    private func lockGroup(_ zone: FocusLocationZone) -> some View {
        group(title: "この場所の動作") {
            Toggle(isOn: Binding(
                get: { zone.isEnabled },
                set: { enabled in
                    onUpdate(zone.id) { $0.isEnabled = enabled }
                }
            )) {
                Text("この場所を使う")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
            }
            .tint(AppColors.success)
            .frame(minHeight: 44)

            Divider()
                .padding(.vertical, 8)

            Toggle(isOn: Binding(
                get: { !zone.allowsTicketBypass },
                set: { locked in
                    onUpdate(zone.id) { $0.allowsTicketBypass = !locked }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("チケットでも開けられない")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("授業中のように、交渉の余地をなくしたい場所に使います。")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(AppColors.danger)
            .frame(minHeight: 44)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            Label("この場所を削除", systemImage: "trash")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(AppColors.danger)
                .background(AppColors.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func useCurrentLocation(for zone: FocusLocationZone) async {
        isLocating = true
        defer { isLocating = false }
        do {
            try await focusController.requestLocationAuthorization()
        } catch {
            // 現在地の取得は When In Use でも足りる。Always が拒否されても位置が取れれば使う。
        }
        guard let location = await ScreenTimeLocationMonitor.shared.requestCurrentLocation() else {
            return
        }
        onUpdate(zone.id) { current in
            current.setCoordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            if !current.isEnabled {
                current.isEnabled = true
            }
        }
    }

    private func group<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout.weight(.bold))
                .foregroundStyle(AppColors.textSecondary)
                .padding(.leading, 11)
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
    }
}

private struct LocationZoneMapView: UIViewRepresentable {
    var latitude: Double
    var longitude: Double
    var radiusMeters: Int
    var isCoordinateSet: Bool
    var onCoordinateChange: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        map.addGestureRecognizer(tap)
        context.coordinator.apply(to: map, recenter: true)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.apply(to: map, recenter: false)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationZoneMapView
        private var lastLatitude: Double?
        private var lastLongitude: Double?
        private var lastRadius: Int?

        init(parent: LocationZoneMapView) {
            self.parent = parent
        }

        func apply(to map: MKMapView, recenter: Bool) {
            let coordinateChanged = lastLatitude != parent.latitude || lastLongitude != parent.longitude
            let radiusChanged = lastRadius != parent.radiusMeters
            lastLatitude = parent.latitude
            lastLongitude = parent.longitude
            lastRadius = parent.radiusMeters

            guard parent.isCoordinateSet else {
                map.removeOverlays(map.overlays)
                map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
                if recenter, map.region.span.latitudeDelta > 20 {
                    map.setRegion(
                        MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
                        ),
                        animated: false
                    )
                }
                return
            }

            let coordinate = CLLocationCoordinate2D(latitude: parent.latitude, longitude: parent.longitude)
            if coordinateChanged || radiusChanged || map.overlays.isEmpty {
                map.removeOverlays(map.overlays)
                map.addOverlay(MKCircle(center: coordinate, radius: CLLocationDistance(parent.radiusMeters)))
                map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
                let pin = MKPointAnnotation()
                pin.coordinate = coordinate
                map.addAnnotation(pin)
            }

            if recenter || coordinateChanged {
                let region = MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: max(CLLocationDistance(parent.radiusMeters) * 6, 600),
                    longitudinalMeters: max(CLLocationDistance(parent.radiusMeters) * 6, 600)
                )
                map.setRegion(region, animated: !recenter)
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let map = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: map)
            parent.onCoordinateChange(map.convert(point, toCoordinateFrom: map))
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.18)
            renderer.strokeColor = UIColor.systemGreen
            renderer.lineWidth = 2
            return renderer
        }
    }
}
