import SwiftUI

public enum WidgetMode: Int, CaseIterable, Sendable {
    case standard // 보통 (2x3 대시보드 + 스파크라인)
    case compact  // 작게 (6개 원형 링 게이지)
    case minimal  // 완전 한줄 (macOS Title Bar 정확한 높이 28pt)
    
    public var icon: String {
        switch self {
        case .standard: return "rectangle.compress.vertical"
        case .compact: return "menubar.rectangle"
        case .minimal: return "rectangle.expand.vertical"
        }
    }
    
    public func nextTitle(for lang: AppLanguage) -> String {
        switch self {
        case .standard: return L10n.tr("Switch to Compact", "작은 크기로 전환", for: lang)
        case .compact: return L10n.tr("Switch to Minimal", "한 줄 크기로 전환", for: lang)
        case .minimal: return L10n.tr("Switch to Standard", "보통 크기로 전환", for: lang)
        }
    }
    
    public var next: WidgetMode {
        switch self {
        case .standard: return .compact
        case .compact: return .minimal
        case .minimal: return .standard
        }
    }
}

public struct WidgetView: View {
    @ObservedObject var monitor: SystemMonitor
    @Binding var mode: WidgetMode
    @Binding var isAlwaysOnTop: Bool
    @Binding var isOpaque: Bool
    @Binding var language: AppLanguage
    @Binding var config: MetricConfig
    
    @State private var hoveredMetric: MetricHoverType? = nil
    @State private var isShowingConfigPopover: Bool = false
    
    var onModeChange: ((WidgetMode) -> Void)?
    var onTogglePin: ((Bool) -> Void)?
    var onToggleDesktop: ((Bool) -> Void)?
    var onLanguageChange: ((AppLanguage) -> Void)?
    var onConfigChange: ((MetricConfig) -> Void)?
    var onClose: (() -> Void)?
    
    public init(
        monitor: SystemMonitor,
        mode: Binding<WidgetMode>,
        isAlwaysOnTop: Binding<Bool>,
        isOpaque: Binding<Bool>,
        language: Binding<AppLanguage>,
        config: Binding<MetricConfig>,
        onModeChange: ((WidgetMode) -> Void)? = nil,
        onTogglePin: ((Bool) -> Void)? = nil,
        onToggleDesktop: ((Bool) -> Void)? = nil,
        onLanguageChange: ((AppLanguage) -> Void)? = nil,
        onConfigChange: ((MetricConfig) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.monitor = monitor
        self._mode = mode
        self._isAlwaysOnTop = isAlwaysOnTop
        self._isOpaque = isOpaque
        self._language = language
        self._config = config
        self.onModeChange = onModeChange
        self.onTogglePin = onTogglePin
        self.onToggleDesktop = onToggleDesktop
        self.onLanguageChange = onLanguageChange
        self.onConfigChange = onConfigChange
        self.onClose = onClose
    }
    
    public var body: some View {
        ZStack {
            switch mode {
            case .standard:
                standardView
                    .transition(.opacity)
            case .compact:
                compactView
                    .transition(.opacity)
            case .minimal:
                minimalView
                    .transition(.opacity)
            }
        }
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: mode == .minimal ? 7 : 16, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: mode)
        .animation(.easeInOut(duration: 0.2), value: isOpaque)
        .animation(.easeInOut(duration: 0.15), value: language)
    }
    
    // MARK: - Background View
    private var backgroundView: some View {
        let cornerRadius: CGFloat = mode == .minimal ? 7 : 16
        return ZStack {
            if isOpaque {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.48))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isOpaque ? 0.22 : 0.35),
                            Color.white.opacity(isOpaque ? 0.08 : 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - 1. Standard View (보통 2x3 그리드)
    private var standardView: some View {
        VStack(spacing: 12) {
            headerBar(title: "CGPU Monitor")
            
            // 가변 메트릭 그리드 (설정에 따라 표시)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                if config.showCPU {
                    MetricCard(
                        title: "CPU",
                        icon: "cpu",
                        valueString: String(format: "%.0f%%", monitor.cpu.total),
                        subtitle: String(format: "%.0f°C · %.1fW", monitor.cpu.temperatureC, monitor.cpu.powerWatts),
                        percentage: monitor.cpu.total,
                        color: .cyan,
                        history: monitor.cpuHistory,
                        isOpaque: isOpaque
                    )
                    .onHover { h in setHover(.cpu, h) }
                    .popover(isPresented: isHoverBinding(.cpu), arrowEdge: .bottom) {
                        CPUPopoverView(cpu: monitor.cpu, sensors: monitor.sensors, lang: language)
                    }
                }
                
                if config.showGPU {
                    MetricCard(
                        title: "GPU",
                        icon: "sparkles.tv",
                        valueString: String(format: "%.0f%%", monitor.gpu.usagePercentage),
                        subtitle: String(format: "%.0f°C · %.1fW", monitor.gpu.temperatureC, monitor.gpu.powerWatts),
                        percentage: monitor.gpu.usagePercentage,
                        color: .purple,
                        history: monitor.gpuHistory,
                        isOpaque: isOpaque
                    )
                    .onHover { h in setHover(.gpu, h) }
                    .popover(isPresented: isHoverBinding(.gpu), arrowEdge: .bottom) {
                        GPUPopoverView(gpu: monitor.gpu, sensors: monitor.sensors, lang: language)
                    }
                }
                
                if config.showRAM {
                    MetricCard(
                        title: "RAM",
                        icon: "memorychip",
                        valueString: String(format: "%.0f%%", monitor.ram.percentage),
                        subtitle: String(format: "%.1f / %.0f GB", monitor.ram.usedGB, monitor.ram.totalGB),
                        percentage: monitor.ram.percentage,
                        color: .green,
                        history: monitor.ramHistory,
                        isOpaque: isOpaque
                    )
                    .onHover { h in setHover(.ram, h) }
                    .popover(isPresented: isHoverBinding(.ram), arrowEdge: .bottom) {
                        RAMPopoverView(ram: monitor.ram, lang: language)
                    }
                }
                
                if config.showDisk {
                    DiskMetricCard(disk: monitor.disk, isOpaque: isOpaque, lang: language)
                        .onHover { h in setHover(.disk, h) }
                        .popover(isPresented: isHoverBinding(.disk), arrowEdge: .bottom) {
                            DiskPopoverView(disk: monitor.disk, lang: language)
                        }
                }
                
                if config.showNetwork {
                    NetworkMetricCard(net: monitor.net, isOpaque: isOpaque, lang: language)
                        .onHover { h in setHover(.net, h) }
                        .popover(isPresented: isHoverBinding(.net), arrowEdge: .bottom) {
                            NetworkPopoverView(net: monitor.net, lang: language)
                        }
                }
                
                if config.showBattery {
                    BatteryMetricCard(battery: monitor.battery, isOpaque: isOpaque, lang: language)
                        .onHover { h in setHover(.battery, h) }
                        .popover(isPresented: isHoverBinding(.battery), arrowEdge: .bottom) {
                            BatteryPopoverView(battery: monitor.battery, lang: language)
                        }
                }
            }
            
            // 하단 상태바
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text(monitor.sensors.fanStatusString(for: language))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("© 2026 krazyeom · \(AppVersion.displayString)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
                
                Text(String(format: "%@: %.1f W", L10n.tr("Power", "전력", for: language), monitor.sensors.totalSystemPowerWatts))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
            .padding(.horizontal, 4)
        }
        .padding(14)
        .frame(width: 360, height: standardHeight)
    }
    
    private var standardHeight: CGFloat {
        let rows = max(1, (config.enabledCount + 1) / 2)
        return CGFloat(105 + rows * 95)
    }
    
    // MARK: - 2. Compact View (작게 가변 링)
    private var compactView: some View {
        VStack(spacing: 10) {
            headerBar(title: "CGPU")
            
            HStack(spacing: 10) {
                if config.showCPU {
                    CompactRing(title: "CPU", percentage: monitor.cpu.total, color: .cyan)
                        .onHover { h in setHover(.cpu, h) }
                        .popover(isPresented: isHoverBinding(.cpu), arrowEdge: .bottom) {
                            CPUPopoverView(cpu: monitor.cpu, sensors: monitor.sensors, lang: language)
                        }
                }
                
                if config.showGPU {
                    CompactRing(title: "GPU", percentage: monitor.gpu.usagePercentage, color: .purple)
                        .onHover { h in setHover(.gpu, h) }
                        .popover(isPresented: isHoverBinding(.gpu), arrowEdge: .bottom) {
                            GPUPopoverView(gpu: monitor.gpu, sensors: monitor.sensors, lang: language)
                        }
                }
                
                if config.showRAM {
                    CompactRing(title: "RAM", percentage: monitor.ram.percentage, color: .green)
                        .onHover { h in setHover(.ram, h) }
                        .popover(isPresented: isHoverBinding(.ram), arrowEdge: .bottom) {
                            RAMPopoverView(ram: monitor.ram, lang: language)
                        }
                }
                
                if config.showDisk {
                    CompactRing(title: "SSD", percentage: monitor.disk.percentage, color: .orange)
                        .onHover { h in setHover(.disk, h) }
                        .popover(isPresented: isHoverBinding(.disk), arrowEdge: .bottom) {
                            DiskPopoverView(disk: monitor.disk, lang: language)
                        }
                }
                
                if config.showNetwork {
                    CompactSpeedRing(title: "NET", speedString: monitor.net.downloadSpeedFormatted, color: .blue)
                        .onHover { h in setHover(.net, h) }
                        .popover(isPresented: isHoverBinding(.net), arrowEdge: .bottom) {
                            NetworkPopoverView(net: monitor.net, lang: language)
                        }
                }
                
                if config.showBattery {
                    CompactRing(title: "BAT", percentage: Double(monitor.battery.percentage), color: monitor.battery.isCharging ? .green : .yellow)
                        .onHover { h in setHover(.battery, h) }
                        .popover(isPresented: isHoverBinding(.battery), arrowEdge: .bottom) {
                            BatteryPopoverView(battery: monitor.battery, lang: language)
                        }
                }
            }
            .padding(.vertical, 2)
        }
        .padding(12)
        .frame(width: compactWidth, height: 125)
    }
    
    private var compactWidth: CGFloat {
        return max(280, CGFloat(80 + config.enabledCount * 55))
    }
    
    // MARK: - 3. Minimal View (완전 한줄 가변 항목 & 최적화된 너비)
    private var minimalView: some View {
        HStack(spacing: 5) {
            // 미니 타이틀/아이콘
            HStack(spacing: 2.5) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                Text("CGPU")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.trailing, 1)
            
            // CPU, GPU, RAM, SSD, NET, BAT (설정에 따라 표시)
            HStack(spacing: 4) {
                if config.showCPU {
                    MinimalMetricTag(label: "CPU", valueString: String(format: "%2.0f%%", monitor.cpu.total), color: .cyan, isOpaque: isOpaque)
                        .onHover { h in setHover(.cpu, h) }
                        .popover(isPresented: isHoverBinding(.cpu), arrowEdge: .bottom) {
                            CPUPopoverView(cpu: monitor.cpu, sensors: monitor.sensors, lang: language)
                        }
                }
                
                if config.showGPU {
                    MinimalMetricTag(label: "GPU", valueString: String(format: "%2.0f%%", monitor.gpu.usagePercentage), color: .purple, isOpaque: isOpaque)
                        .onHover { h in setHover(.gpu, h) }
                        .popover(isPresented: isHoverBinding(.gpu), arrowEdge: .bottom) {
                            GPUPopoverView(gpu: monitor.gpu, sensors: monitor.sensors, lang: language)
                        }
                }
                
                if config.showRAM {
                    MinimalMetricTag(label: "RAM", valueString: String(format: "%2.0f%%", monitor.ram.percentage), color: .green, isOpaque: isOpaque)
                        .onHover { h in setHover(.ram, h) }
                        .popover(isPresented: isHoverBinding(.ram), arrowEdge: .bottom) {
                            RAMPopoverView(ram: monitor.ram, lang: language)
                        }
                }
                
                if config.showDisk {
                    MinimalMetricTag(label: "SSD", valueString: String(format: "%2.0f%%", monitor.disk.percentage), color: .orange, isOpaque: isOpaque)
                        .onHover { h in setHover(.disk, h) }
                        .popover(isPresented: isHoverBinding(.disk), arrowEdge: .bottom) {
                            DiskPopoverView(disk: monitor.disk, lang: language)
                        }
                }
                
                if config.showNetwork {
                    MinimalMetricTag(label: "NET", valueString: monitor.net.downloadSpeedFormatted, color: .blue, isOpaque: isOpaque)
                        .onHover { h in setHover(.net, h) }
                        .popover(isPresented: isHoverBinding(.net), arrowEdge: .bottom) {
                            NetworkPopoverView(net: monitor.net, lang: language)
                        }
                }
                
                if config.showBattery {
                    MinimalMetricTag(label: "BAT", valueString: "\(monitor.battery.percentage)%", color: monitor.battery.isCharging ? .green : .yellow, isOpaque: isOpaque)
                        .onHover { h in setHover(.battery, h) }
                        .popover(isPresented: isHoverBinding(.battery), arrowEdge: .bottom) {
                            BatteryPopoverView(battery: monitor.battery, lang: language)
                        }
                }
            }
            
            Spacer(minLength: 5)
            
            // 컨트롤 버튼
            HStack(spacing: 3.5) {
                // Config (Gear) Popover Button
                Button(action: { isShowingConfigPopover.toggle() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(isShowingConfigPopover ? .cyan : .secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Displayed Metrics Settings", "표시 항목 설정", for: language))
                .popover(isPresented: $isShowingConfigPopover, arrowEdge: .bottom) {
                    ConfigPopoverView(config: $config, lang: language, onConfigChanged: onConfigChange)
                }
                
                Button(action: toggleLanguage) {
                    Text(language == .en ? "KO" : "EN")
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help(language == .en ? "Switch to Korean" : "Switch to English")
                
                Button(action: { isOpaque.toggle() }) {
                    Image(systemName: isOpaque ? "circle.righthalf.filled" : "circle.lefthalf.filled")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(isOpaque ? .cyan : .secondary)
                }
                .buttonStyle(.plain)
                .help(isOpaque ? L10n.tr("Switch to Translucent", "반투명 블러로 변경", for: language) : L10n.tr("Switch to Opaque", "불투명 배경으로 변경", for: language))
                
                Button(action: cycleMode) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help(mode.nextTitle(for: language))
                
                Button(action: {
                    isAlwaysOnTop.toggle()
                    onTogglePin?(isAlwaysOnTop)
                }) {
                    Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(isAlwaysOnTop ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Always on Top", "항상 화면 위에 표시", for: language))
                
                Button(action: { onClose?() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help(L10n.tr("Close Widget", "위젯 닫기", for: language))
            }
        }
        .padding(.horizontal, 7)
        .frame(width: minimalWidth, height: 28)
    }
    
    private var minimalWidth: CGFloat {
        var width: CGFloat = 160 // 최적화된 컴팩트 베이스 (타이틀 38 + 버튼들 86 + 여백 36)
        if config.showCPU { width += 75 }
        if config.showGPU { width += 75 }
        if config.showRAM { width += 75 }
        if config.showDisk { width += 75 }
        if config.showNetwork { width += 94 }
        if config.showBattery { width += 73 }
        return max(320, width)
    }
    
    // MARK: - Helper Methods
    private func toggleLanguage() {
        let newLang: AppLanguage = (language == .en ? .ko : .en)
        language = newLang
        onLanguageChange?(newLang)
    }
    
    private func setHover(_ type: MetricHoverType, _ hovering: Bool) {
        if hovering {
            hoveredMetric = type
        } else if hoveredMetric == type {
            hoveredMetric = nil
        }
    }
    
    private func isHoverBinding(_ type: MetricHoverType) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.hoveredMetric == type },
            set: { isPresenting in
                if !isPresenting && self.hoveredMetric == type {
                    self.hoveredMetric = nil
                }
            }
        )
    }
    
    // MARK: - Header Bar (Standard & Compact 공용)
    private func headerBar(title: String) -> some View {
        HStack {
            Image(systemName: "cpu.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
            
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: toggleLanguage) {
                Text(language == .en ? "KO" : "EN")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .help(language == .en ? "Switch to Korean" : "Switch to English")
            
            // Config (Gear) Popover Button
            Button(action: { isShowingConfigPopover.toggle() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isShowingConfigPopover ? .cyan : .secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Displayed Metrics Settings", "표시 항목 설정", for: language))
            .popover(isPresented: $isShowingConfigPopover, arrowEdge: .bottom) {
                ConfigPopoverView(config: $config, lang: language, onConfigChanged: onConfigChange)
            }
            
            Button(action: { isOpaque.toggle() }) {
                Image(systemName: isOpaque ? "circle.righthalf.filled" : "circle.lefthalf.filled")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isOpaque ? .cyan : .secondary)
            }
            .buttonStyle(.plain)
            .help(isOpaque ? L10n.tr("Switch to Translucent", "반투명 블러로 변경", for: language) : L10n.tr("Switch to Opaque", "불투명 배경으로 변경", for: language))
            
            Button(action: cycleMode) {
                Image(systemName: mode.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(mode.nextTitle(for: language))
            
            Button(action: {
                isAlwaysOnTop.toggle()
                onTogglePin?(isAlwaysOnTop)
            }) {
                Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isAlwaysOnTop ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Always on Top", "항상 화면 위에 표시", for: language))
            
            Button(action: { onClose?() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help(L10n.tr("Close Widget", "위젯 닫기", for: language))
        }
        .padding(.horizontal, 2)
    }
    
    private func cycleMode() {
        let nextMode = mode.next
        mode = nextMode
        onModeChange?(nextMode)
    }
}

// MARK: - Minimal Metric Tag
struct MinimalMetricTag: View {
    let label: String
    let valueString: String
    let color: Color
    var isOpaque: Bool = true
    
    var body: some View {
        HStack(spacing: 2.5) {
            Circle()
                .fill(color)
                .frame(width: 4.5, height: 4.5)
            
            Text(label)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(color)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            Text(valueString)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 4.5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(isOpaque ? Color.white.opacity(0.08) : Color.white.opacity(0.10))
        )
    }
}

// MARK: - Metric Card (Standard)
struct MetricCard: View {
    let title: String
    let icon: String
    let valueString: String
    let subtitle: String
    let percentage: Double
    let color: Color
    let history: [Double]
    var isOpaque: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Text(valueString)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(percentage / 100.0))), height: 5)
                }
            }
            .frame(height: 5)
            
            MiniSparkline(values: history, color: color)
                .frame(height: 16)
            
            Text(subtitle)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isOpaque ? Color.white.opacity(0.06) : Color.black.opacity(0.18))
        )
    }
}

// MARK: - Disk Metric Card (Standard)
struct DiskMetricCard: View {
    let disk: DiskUsage
    var isOpaque: Bool = true
    var lang: AppLanguage = .en
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("SSD", systemImage: "internaldrive")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.orange)
                Spacer()
                Text(String(format: "%.0f%%", disk.percentage))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.7), Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(disk.percentage / 100.0))), height: 5)
                }
            }
            .frame(height: 5)
            
            HStack {
                Text(String(format: "%.0f GB %@", disk.freeGB, L10n.tr("Free", "여유", for: lang)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%@ %.0f GB", L10n.tr("Total", "총", for: lang), disk.totalGB))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
            
            Text(disk.volumeName)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
                .lineLimit(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isOpaque ? Color.white.opacity(0.06) : Color.black.opacity(0.18))
        )
    }
}

// MARK: - Network Metric Card (Standard)
struct NetworkMetricCard: View {
    let net: NetworkMetrics
    var isOpaque: Bool = true
    var lang: AppLanguage = .en
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("NET", systemImage: "network")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.blue)
                Spacer()
                Text(net.downloadSpeedFormatted)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            HStack {
                Image(systemName: "arrow.down")
                    .font(.system(size: 9))
                    .foregroundColor(.cyan)
                Text(net.downloadSpeedFormatted)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "arrow.up")
                    .font(.system(size: 9))
                    .foregroundColor(.indigo)
                Text(net.uploadSpeedFormatted)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(L10n.tr("Total", "누적", for: lang))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f GB", net.totalDownloadGB))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
            
            Text(net.interfaceName)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
                .lineLimit(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isOpaque ? Color.white.opacity(0.06) : Color.black.opacity(0.18))
        )
    }
}

// MARK: - Battery Metric Card (Standard)
struct BatteryMetricCard: View {
    let battery: BatteryMetrics
    var isOpaque: Bool = true
    var lang: AppLanguage = .en
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("BAT", systemImage: battery.isCharging ? "battery.100.bolt" : "battery.100")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(battery.isCharging ? .green : .yellow)
                Spacer()
                Text("\(battery.percentage)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 5)
                    
                    Capsule()
                        .fill(battery.isCharging ? Color.green : Color.yellow)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(battery.percentage) / 100.0)), height: 5)
                }
            }
            .frame(height: 5)
            
            HStack {
                Text(battery.isACPowered ? L10n.tr("Power Adapter", "전원 어댑터 연결", for: lang) : L10n.tr("On Battery", "배터리 전원 사용", for: lang))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                if battery.isCharging {
                    Text(L10n.tr("Charging", "충전 중", for: lang))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
            .padding(.top, 2)
            
            Text(battery.condition)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
                .lineLimit(1)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isOpaque ? Color.white.opacity(0.06) : Color.black.opacity(0.18))
        )
    }
}

// MARK: - Compact Ring (Compact)
struct CompactRing: View {
    let title: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: CGFloat(min(1.0, max(0.0, percentage / 100.0))))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Text(String(format: "%.0f", percentage))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(width: 40, height: 40)
            
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Compact Speed Ring
struct CompactSpeedRing: View {
    let title: String
    let speedString: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 4)
                
                Circle()
                    .stroke(color, lineWidth: 4)
                
                Text(speedString.replacingOccurrences(of: "/s", with: ""))
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 40, height: 40)
            
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Mini Sparkline Graph
struct MiniSparkline: View {
    let values: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            let points = values
            let width = geo.size.width
            let height = geo.size.height
            
            if points.count > 1 {
                Path { path in
                    let step = width / CGFloat(points.count - 1)
                    for (index, val) in points.enumerated() {
                        let normalizedVal = max(0.0, min(100.0, val)) / 100.0
                        let y = height - (CGFloat(normalizedVal) * height)
                        let x = CGFloat(index) * step
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color.opacity(0.7), lineWidth: 1.5)
            }
        }
    }
}
