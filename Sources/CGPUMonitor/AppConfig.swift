import Foundation
import SwiftUI

// MARK: - Application Versioning
public enum AppVersion {
    public static let version = "1.1.0"
    public static let build = "2"
    public static let displayString = "v1.1.0"
    public static let fullDisplay = "CGPU Monitor v1.1.0 (Build 2)"
    public static let releaseDate = "2026-10-31"
}

// MARK: - Metric Configuration (빼고 넣고 설정)
public struct MetricConfig: Codable, Equatable, Sendable {
    public var showCPU: Bool
    public var showGPU: Bool
    public var showRAM: Bool
    public var showDisk: Bool
    public var showNetwork: Bool
    public var showBattery: Bool
    
    public init(
        showCPU: Bool = true,
        showGPU: Bool = true,
        showRAM: Bool = true,
        showDisk: Bool = true,
        showNetwork: Bool = true,
        showBattery: Bool = true
    ) {
        self.showCPU = showCPU
        self.showGPU = showGPU
        self.showRAM = showRAM
        self.showDisk = showDisk
        self.showNetwork = showNetwork
        self.showBattery = showBattery
    }
    
    public var enabledCount: Int {
        var count = 0
        if showCPU { count += 1 }
        if showGPU { count += 1 }
        if showRAM { count += 1 }
        if showDisk { count += 1 }
        if showNetwork { count += 1 }
        if showBattery { count += 1 }
        return count
    }
    
    public func canDisable(metric: MetricType) -> Bool {
        // 최소 1개는 반드시 켜져 있어야 함
        return enabledCount > 1
    }
    
    public mutating func toggle(_ metric: MetricType) {
        switch metric {
        case .cpu:
            if showCPU && !canDisable(metric: .cpu) { return }
            showCPU.toggle()
        case .gpu:
            if showGPU && !canDisable(metric: .gpu) { return }
            showGPU.toggle()
        case .ram:
            if showRAM && !canDisable(metric: .ram) { return }
            showRAM.toggle()
        case .disk:
            if showDisk && !canDisable(metric: .disk) { return }
            showDisk.toggle()
        case .network:
            if showNetwork && !canDisable(metric: .network) { return }
            showNetwork.toggle()
        case .battery:
            if showBattery && !canDisable(metric: .battery) { return }
            showBattery.toggle()
        }
    }
    
    // UserDefaults Serialization
    private static let key = "cgpu_metric_config_v1"
    private static var appDefaults: UserDefaults {
        UserDefaults(suiteName: "com.cgpu.monitor") ?? UserDefaults.standard
    }
    
    public static func load() -> MetricConfig {
        guard let data = appDefaults.data(forKey: key),
              let config = try? JSONDecoder().decode(MetricConfig.self, from: data) else {
            return MetricConfig()
        }
        // 만약 모든 메트릭이 꺼져있는 비정상 상태라면 기본값 반환
        if config.enabledCount == 0 {
            return MetricConfig()
        }
        return config
    }
    
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            MetricConfig.appDefaults.set(data, forKey: MetricConfig.key)
            MetricConfig.appDefaults.synchronize()
        }
    }
    
    public mutating func resetToDefault() {
        self.showCPU = true
        self.showGPU = true
        self.showRAM = true
        self.showDisk = true
        self.showNetwork = true
        self.showBattery = true
    }
}

public enum MetricType: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case gpu
    case ram
    case disk
    case network
    case battery
    
    public var id: String { rawValue }
    
    public func title(for lang: AppLanguage) -> String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .ram: return "RAM"
        case .disk: return L10n.tr("SSD (Disk)", "SSD (디스크)", for: lang)
        case .network: return L10n.tr("Network", "네트워크", for: lang)
        case .battery: return L10n.tr("Battery", "배터리", for: lang)
        }
    }
    
    public func icon() -> String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "sparkles.tv"
        case .ram: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .battery: return "battery.100.bolt"
        }
    }
    
    public func color() -> Color {
        switch self {
        case .cpu: return .cyan
        case .gpu: return .purple
        case .ram: return .green
        case .disk: return .orange
        case .network: return .blue
        case .battery: return .yellow
        }
    }
}

// MARK: - Config Popover View (위젯 내부 설정 창)
public struct ConfigPopoverView: View {
    @Binding var config: MetricConfig
    let lang: AppLanguage
    var onConfigChanged: ((MetricConfig) -> Void)?
    
    public init(
        config: Binding<MetricConfig>,
        lang: AppLanguage,
        onConfigChanged: ((MetricConfig) -> Void)? = nil
    ) {
        self._config = config
        self.lang = lang
        self.onConfigChanged = onConfigChanged
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                Text(L10n.tr("Displayed Metrics", "표시 항목 설정", for: lang))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(AppVersion.displayString)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 2)
            
            Divider()
                .opacity(0.3)
            
            // Toggle Rows
            VStack(spacing: 6) {
                metricToggleRow(metric: .cpu, isOn: Binding(
                    get: { config.showCPU },
                    set: { _ in toggleMetric(.cpu) }
                ))
                
                metricToggleRow(metric: .gpu, isOn: Binding(
                    get: { config.showGPU },
                    set: { _ in toggleMetric(.gpu) }
                ))
                
                metricToggleRow(metric: .ram, isOn: Binding(
                    get: { config.showRAM },
                    set: { _ in toggleMetric(.ram) }
                ))
                
                metricToggleRow(metric: .disk, isOn: Binding(
                    get: { config.showDisk },
                    set: { _ in toggleMetric(.disk) }
                ))
                
                metricToggleRow(metric: .network, isOn: Binding(
                    get: { config.showNetwork },
                    set: { _ in toggleMetric(.network) }
                ))
                
                metricToggleRow(metric: .battery, isOn: Binding(
                    get: { config.showBattery },
                    set: { _ in toggleMetric(.battery) }
                ))
            }
            
            Divider()
                .opacity(0.3)
            
            // Footer
            HStack {
                Text(L10n.tr("Min. 1 metric required", "최소 1개 항목 필수", for: lang))
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: resetDefault) {
                    Text(L10n.tr("Reset", "초기화", for: lang))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .opacity(0.3)
            
            // Copyright & Author Information
            HStack {
                Text("© 2026 krazyeom")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    if let url = URL(string: "https://github.com/krazyeom/cgpu") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "link")
                            .font(.system(size: 8))
                        Text("GitHub")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 230)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.96))
        )
    }
    
    private func toggleMetric(_ metric: MetricType) {
        config.toggle(metric)
        config.save()
        onConfigChanged?(config)
    }
    
    private func resetDefault() {
        config.resetToDefault()
        config.save()
        onConfigChanged?(config)
    }
    
    private func metricToggleRow(metric: MetricType, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: metric.icon())
                .font(.system(size: 11))
                .foregroundColor(metric.color())
                .frame(width: 14)
            
            Text(metric.title(for: lang))
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: metric.color()))
                .scaleEffect(0.7)
                .disabled(isOn.wrappedValue && !config.canDisable(metric: metric))
        }
    }
}
