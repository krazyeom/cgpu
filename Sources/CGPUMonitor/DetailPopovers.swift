import SwiftUI

public enum MetricHoverType: String, Identifiable, Sendable {
    case cpu
    case gpu
    case ram
    case disk
    case net
    case battery
    
    public var id: String { rawValue }
}

// MARK: - CPU Popover
public struct CPUPopoverView: View {
    let cpu: CPUUsage
    let sensors: SystemSensorOverview
    let lang: AppLanguage
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 13, weight: .bold))
                Text(cpu.modelName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.1f%% %@", cpu.total, L10n.tr("in use", "사용 중", for: lang)))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            
            Divider().opacity(0.3)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                InfoBox(icon: "thermometer.medium", label: L10n.tr("CPU Core Temp", "CPU 코어 온도", for: lang), value: String(format: "%.1f°C", cpu.temperatureC), color: .orange)
                InfoBox(icon: "bolt.fill", label: L10n.tr("Power Draw", "소비 전력", for: lang), value: String(format: "%.1f W", cpu.powerWatts), color: .yellow)
                InfoBox(icon: "fanblades.fill", label: L10n.tr("System Fan", "시스템 팬", for: lang), value: sensors.fanStatusString(for: lang), color: .mint)
                InfoBox(icon: "gauge.medium", label: L10n.tr("Thermal State", "열 관리 상태", for: lang), value: sensors.thermalStatusString(for: lang), color: .green)
            }
            
            Divider().opacity(0.3)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L10n.tr("Core Layout:", "코어 구성:", for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(L10n.tr("\(cpu.coreCount) Cores (\(cpu.pCores)P + \(cpu.eCores)E)", "총 \(cpu.coreCount)개 (성능 \(cpu.pCores)P + 효율 \(cpu.eCores)E)", for: lang))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text(L10n.tr("Load Average:", "로드 에버리지:", for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f · %.2f · %.2f", cpu.loadAverage.0, cpu.loadAverage.1, cpu.loadAverage.2))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                HStack {
                    Text(L10n.tr("Breakdown:", "점유율 상세:", for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "User: %.0f%% · Sys: %.0f%% · Idle: %.0f%%", cpu.user, cpu.system, cpu.idle))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }
}

// MARK: - GPU Popover
public struct GPUPopoverView: View {
    let gpu: GPUMetrics
    let sensors: SystemSensorOverview
    let lang: AppLanguage
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles.tv")
                    .foregroundColor(.purple)
                    .font(.system(size: 13, weight: .bold))
                Text(gpu.modelName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.1f%%", gpu.usagePercentage))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.purple)
            }
            
            Divider().opacity(0.3)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                InfoBox(icon: "thermometer.medium", label: L10n.tr("GPU Core Temp", "GPU 코어 온도", for: lang), value: String(format: "%.1f°C", gpu.temperatureC), color: .orange)
                InfoBox(icon: "bolt.fill", label: L10n.tr("GPU Power", "GPU 소비 전력", for: lang), value: String(format: "%.1f W", gpu.powerWatts), color: .yellow)
                InfoBox(icon: "square.grid.2x2.fill", label: L10n.tr("GPU Cores", "GPU 코어 수", for: lang), value: "\(gpu.coreCount) Cores", color: .indigo)
                InfoBox(icon: "bolt.circle.fill", label: L10n.tr("Total System Power", "시스템 총 전력", for: lang), value: String(format: "%.1f W", sensors.totalSystemPowerWatts), color: .teal)
            }
            
            Divider().opacity(0.3)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L10n.tr("Graphics Engine:", "그래픽 가속:", for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(L10n.tr("Metal 4 (Hardware Acceleration)", "Metal 4 (하드웨어 가속)", for: lang))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
                HStack {
                    Text(L10n.tr("Display:", "디스플레이:", for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Liquid Retina XDR")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 290)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }
}

// MARK: - RAM Popover
public struct RAMPopoverView: View {
    let ram: RAMUsage
    let lang: AppLanguage
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.green)
                    .font(.system(size: 13, weight: .bold))
                Text(L10n.tr("Unified Memory", "통합 메모리", for: lang))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.0f GB", ram.totalGB))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            
            Divider().opacity(0.3)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                InfoBox(icon: "app.fill", label: L10n.tr("App Memory", "앱 메모리", for: lang), value: String(format: "%.1f GB", ram.appMemoryGB), color: .cyan)
                InfoBox(icon: "lock.shield.fill", label: L10n.tr("Wired Memory", "와이어드 메모리", for: lang), value: String(format: "%.1f GB", ram.wiredGB), color: .blue)
                InfoBox(icon: "archivebox.fill", label: L10n.tr("Compressed", "압축 메모리", for: lang), value: String(format: "%.1f GB", ram.compressedGB), color: .purple)
                InfoBox(icon: "sparkles", label: L10n.tr("Free / Cache", "여유/캐시 메모리", for: lang), value: String(format: "%.1f GB", ram.freeGB), color: .green)
            }
            
            Divider().opacity(0.3)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L10n.tr("Swap Memory:", "스왑 메모리(Swap):", for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.2f GB %@ / %.2f GB", ram.swapUsedGB, L10n.tr("used", "사용 중", for: lang), ram.swapTotalGB))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                HStack {
                    Text(L10n.tr("Memory Pressure:", "메모리 압박도:", for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(ram.memoryPressureString(for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ram.percentage > 80 ? .orange : .green)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }
}

// MARK: - Disk Popover
public struct DiskPopoverView: View {
    let disk: DiskUsage
    let lang: AppLanguage
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundColor(.orange)
                    .font(.system(size: 13, weight: .bold))
                Text(disk.volumeName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: "%.0f%% %@", disk.percentage, L10n.tr("used", "사용", for: lang)))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            Divider().opacity(0.3)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                InfoBox(icon: "chart.pie.fill", label: L10n.tr("Used Space", "사용 중인 용량", for: lang), value: String(format: "%.1f GB", disk.usedGB), color: .orange)
                InfoBox(icon: "checkmark.circle.fill", label: L10n.tr("Free Space", "남은 여유 공간", for: lang), value: String(format: "%.1f GB", disk.freeGB), color: .green)
                InfoBox(icon: "externaldrive.badge.icloud", label: L10n.tr("Total Capacity", "전체 용량", for: lang), value: String(format: "%.1f GB", disk.totalGB), color: .blue)
                InfoBox(icon: "lock.fill", label: L10n.tr("Encryption", "암호화 상태", for: lang), value: disk.isEncrypted ? L10n.tr("FileVault Active", "FileVault 활성", for: lang) : L10n.tr("Inactive", "미적용", for: lang), color: .mint)
            }
            
            Divider().opacity(0.3)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(L10n.tr("Drive Type:", "드라이브 유형:", for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Apple Internal NVMe PCIe SSD")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                }
                HStack {
                    Text(L10n.tr("File System:", "파일 시스템:", for: lang))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(disk.fileSystem)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }
}

// MARK: - Network Popover
public struct NetworkPopoverView: View {
    let net: NetworkMetrics
    let lang: AppLanguage
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.blue)
                    .font(.system(size: 13, weight: .bold))
                Text(L10n.tr("Network Activity", "네트워크 활동", for: lang))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(net.interfaceName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Divider().opacity(0.3)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                InfoBox(icon: "arrow.down.circle.fill", label: L10n.tr("Download Speed", "다운로드 속도", for: lang), value: net.downloadSpeedFormatted, color: .cyan)
                InfoBox(icon: "arrow.up.circle.fill", label: L10n.tr("Upload Speed", "업로드 속도", for: lang), value: net.uploadSpeedFormatted, color: .indigo)
                InfoBox(icon: "tray.and.arrow.down.fill", label: L10n.tr("Total Received", "누적 수신량", for: lang), value: String(format: "%.2f GB", net.totalDownloadGB), color: .teal)
                InfoBox(icon: "tray.and.arrow.up.fill", label: L10n.tr("Total Sent", "누적 송신량", for: lang), value: String(format: "%.2f GB", net.totalUploadGB), color: .purple)
            }
        }
        .padding(14)
        .frame(width: 290)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }
}

// MARK: - Battery Popover
public struct BatteryPopoverView: View {
    let battery: BatteryMetrics
    let lang: AppLanguage
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.100")
                    .foregroundColor(.green)
                    .font(.system(size: 13, weight: .bold))
                Text(L10n.tr("Battery & Power", "배터리 및 전원", for: lang))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(battery.percentage)%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }
            
            Divider().opacity(0.3)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                InfoBox(icon: "powerplug.fill", label: L10n.tr("Power Source", "전원 공급원", for: lang), value: battery.isACPowered ? L10n.tr("AC Adapter", "전원 어댑터", for: lang) : L10n.tr("Battery", "배터리", for: lang), color: .yellow)
                InfoBox(icon: "bolt.fill", label: L10n.tr("Charging State", "충전 상태", for: lang), value: battery.isCharging ? L10n.tr("Charging", "충전 중", for: lang) : (battery.isACPowered ? L10n.tr("Fully Charged", "완충됨", for: lang) : L10n.tr("Discharging", "사용 중", for: lang)), color: .green)
                InfoBox(icon: "heart.fill", label: L10n.tr("Battery Condition", "배터리 성능 상태", for: lang), value: L10n.tr("Normal (Optimal)", "정상 (쾌적)", for: lang), color: .pink)
                InfoBox(icon: "clock.fill", label: L10n.tr("Remaining Time", "남은 시간", for: lang), value: battery.timeRemainingMinutes > 0 ? "\(battery.timeRemainingMinutes / 60)h \(battery.timeRemainingMinutes % 60)m" : L10n.tr("Calculating...", "계산 중...", for: lang), color: .cyan)
            }
        }
        .padding(14)
        .frame(width: 290)
        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
    }
}

// MARK: - Reusable Info Box
struct InfoBox: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
