import SwiftUI

public struct WidgetView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var isExpanded: Bool = true
    @State private var isAlwaysOnTop: Bool = true
    @State private var isPinnedToDesktop: Bool = false
    
    var onTogglePin: ((Bool) -> Void)?
    var onToggleDesktop: ((Bool) -> Void)?
    var onClose: (() -> Void)?
    
    public init(
        monitor: SystemMonitor,
        onTogglePin: ((Bool) -> Void)? = nil,
        onToggleDesktop: ((Bool) -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.monitor = monitor
        self.onTogglePin = onTogglePin
        self.onToggleDesktop = onToggleDesktop
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 상단 헤더 바
            headerBar
            
            if isExpanded {
                expandedDashboard
            } else {
                compactDashboard
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05),
                                    Color.black.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
        )
        .frame(width: isExpanded ? 340 : 310)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
    
    // MARK: - Header
    private var headerBar: some View {
        HStack {
            Image(systemName: "cpu.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
            
            Text("CGPU Monitor")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Spacer()
            
            // 컴팩트/확장 토글
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "컴팩트 뷰로 전환" : "상세 뷰로 전환")
            
            // 항상 위 (Pin)
            Button(action: {
                isAlwaysOnTop.toggle()
                if isAlwaysOnTop { isPinnedToDesktop = false }
                onTogglePin?(isAlwaysOnTop)
            }) {
                Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isAlwaysOnTop ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help("항상 화면 위에 표시")
            
            // 닫기 버튼
            Button(action: { onClose?() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .help("위젯 닫기 (메뉴바에서 다시 열기 가능)")
        }
        .padding(.horizontal, 2)
    }
    
    // MARK: - Expanded Dashboard
    private var expandedDashboard: some View {
        VStack(spacing: 10) {
            // 2x2 그리드
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                MetricCard(
                    title: "CPU",
                    icon: "cpu",
                    valueString: String(format: "%.0f%%", monitor.cpu.total),
                    subtitle: "\(monitor.cpu.coreCount) Cores",
                    percentage: monitor.cpu.total,
                    color: .cyan,
                    history: monitor.cpuHistory
                )
                
                MetricCard(
                    title: "GPU",
                    icon: "sparkles.tv",
                    valueString: String(format: "%.0f%%", monitor.gpu),
                    subtitle: "Apple Silicon",
                    percentage: monitor.gpu,
                    color: .purple,
                    history: monitor.gpuHistory
                )
                
                MetricCard(
                    title: "RAM",
                    icon: "memorychip",
                    valueString: String(format: "%.0f%%", monitor.ram.percentage),
                    subtitle: String(format: "%.1f / %.0f GB", monitor.ram.usedGB, monitor.ram.totalGB),
                    percentage: monitor.ram.percentage,
                    color: .green,
                    history: monitor.ramHistory
                )
                
                DiskMetricCard(
                    disk: monitor.disk
                )
            }
            
            // 하단 상태바
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("실시간 1초 갱신")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(monitor.cpu.modelName)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.top, 2)
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Compact Dashboard
    private var compactDashboard: some View {
        HStack(spacing: 12) {
            CompactRing(title: "CPU", percentage: monitor.cpu.total, color: .cyan)
            CompactRing(title: "GPU", percentage: monitor.gpu, color: .purple)
            CompactRing(title: "RAM", percentage: monitor.ram.percentage, color: .green)
            CompactRing(title: "SSD", percentage: monitor.disk.percentage, color: .orange)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let title: String
    let icon: String
    let valueString: String
    let subtitle: String
    let percentage: Double
    let color: Color
    let history: [Double]
    
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
            
            // 프로그레스 바
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
            
            // 미니 스파크라인 그래프
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
                .fill(Color.black.opacity(0.18))
        )
    }
}

// MARK: - Disk Metric Card
struct DiskMetricCard: View {
    let disk: DiskUsage
    
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
            
            // 프로그레스 바
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
            
            // 여유 용량 표시
            HStack {
                Text(String(format: "%.0f GB 여유", disk.freeGB))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "총 %.0f GB", disk.totalGB))
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
                .fill(Color.black.opacity(0.18))
        )
    }
}

// MARK: - Compact Ring
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
            .frame(width: 42, height: 42)
            
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
