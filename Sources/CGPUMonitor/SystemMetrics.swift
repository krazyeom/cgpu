import Foundation
import MachO
import IOKit

public struct CPUUsage: Sendable {
    public var total: Double = 0.0
    public var user: Double = 0.0
    public var system: Double = 0.0
    public var idle: Double = 100.0
    public var coreCount: Int = ProcessInfo.processInfo.activeProcessorCount
    public var modelName: String = ""
}

public struct RAMUsage: Sendable {
    public var usedGB: Double = 0.0
    public var totalGB: Double = 0.0
    public var percentage: Double = 0.0
    public var appMemoryGB: Double = 0.0
    public var wiredGB: Double = 0.0
    public var compressedGB: Double = 0.0
}

public struct DiskUsage: Sendable {
    public var usedGB: Double = 0.0
    public var freeGB: Double = 0.0
    public var totalGB: Double = 0.0
    public var percentage: Double = 0.0
    public var volumeName: String = "Macintosh HD"
}

@MainActor
public final class SystemMonitor: ObservableObject {
    @Published public var cpu = CPUUsage()
    @Published public var gpu: Double = 0.0
    @Published public var ram = RAMUsage()
    @Published public var disk = DiskUsage()
    
    // 최근 20초간의 히스토리 데이터 (미니 그래프용)
    @Published public var cpuHistory: [Double] = Array(repeating: 0.0, count: 20)
    @Published public var gpuHistory: [Double] = Array(repeating: 0.0, count: 20)
    @Published public var ramHistory: [Double] = Array(repeating: 0.0, count: 20)
    
    private var timer: Timer?
    private var previousCpuLoad: host_cpu_load_info?
    private let modelName: String
    
    public init() {
        self.modelName = Self.readCpuBrand()
        self.cpu.modelName = self.modelName
        updateAll()
        startMonitoring()
    }
    
    public func startMonitoring(interval: TimeInterval = 1.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateAll()
            }
        }
    }
    
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    public func updateAll() {
        self.cpu = readCpuUsage()
        self.gpu = readGpuUsage()
        self.ram = readRamUsage()
        self.disk = readDiskUsage()
        
        cpuHistory.append(self.cpu.total)
        if cpuHistory.count > 20 { cpuHistory.removeFirst() }
        
        gpuHistory.append(self.gpu)
        if gpuHistory.count > 20 { gpuHistory.removeFirst() }
        
        ramHistory.append(self.ram.percentage)
        if ramHistory.count > 20 { ramHistory.removeFirst() }
    }
    
    // MARK: - CPU
    private func readCpuUsage() -> CPUUsage {
        var cpuLoad = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return CPUUsage(modelName: self.modelName)
        }
        
        defer { previousCpuLoad = cpuLoad }
        guard let prev = previousCpuLoad else {
            return CPUUsage(modelName: self.modelName)
        }
        
        let userDelta = Double(cpuLoad.cpu_ticks.0 >= prev.cpu_ticks.0 ? cpuLoad.cpu_ticks.0 - prev.cpu_ticks.0 : 0)
        let systemDelta = Double(cpuLoad.cpu_ticks.1 >= prev.cpu_ticks.1 ? cpuLoad.cpu_ticks.1 - prev.cpu_ticks.1 : 0)
        let idleDelta = Double(cpuLoad.cpu_ticks.2 >= prev.cpu_ticks.2 ? cpuLoad.cpu_ticks.2 - prev.cpu_ticks.2 : 0)
        let niceDelta = Double(cpuLoad.cpu_ticks.3 >= prev.cpu_ticks.3 ? cpuLoad.cpu_ticks.3 - prev.cpu_ticks.3 : 0)
        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        
        if totalDelta > 0 {
            let userPercent = min(100.0, max(0.0, (userDelta / totalDelta) * 100.0))
            let systemPercent = min(100.0, max(0.0, (systemDelta / totalDelta) * 100.0))
            let idlePercent = min(100.0, max(0.0, (idleDelta / totalDelta) * 100.0))
            let totalPercent = min(100.0, max(0.0, ((userDelta + systemDelta + niceDelta) / totalDelta) * 100.0))
            return CPUUsage(
                total: totalPercent,
                user: userPercent,
                system: systemPercent,
                idle: idlePercent,
                coreCount: ProcessInfo.processInfo.activeProcessorCount,
                modelName: self.modelName
            )
        }
        return CPUUsage(modelName: self.modelName)
    }
    
    private static func readCpuBrand() -> String {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var brand = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &brand, &size, nil, 0)
            let brandStr = String(cString: brand).trimmingCharacters(in: .whitespacesAndNewlines)
            if !brandStr.isEmpty { return brandStr }
        }
        
        // Apple Silicon M series fallback
        var appleSiliconSize: Int = 0
        sysctlbyname("hw.model", nil, &appleSiliconSize, nil, 0)
        if appleSiliconSize > 0 {
            var model = [CChar](repeating: 0, count: appleSiliconSize)
            sysctlbyname("hw.model", &model, &appleSiliconSize, nil, 0)
            return String(cString: model)
        }
        return "Apple Silicon / Mac Processor"
    }
    
    // MARK: - GPU
    private func readGpuUsage() -> Double {
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOAccelerator")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        guard result == kIOReturnSuccess else { return 0.0 }
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        var totalUtil: Double = 0.0
        var count = 0
        
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["PerformanceStatistics"] as? [String: Any] {
                if let util = stats["Device Utilization %"] as? Int {
                    totalUtil += Double(util)
                    count += 1
                } else if let util = stats["Device Utilization %"] as? Double {
                    totalUtil += util
                    count += 1
                }
            }
        }
        
        return count > 0 ? min(100.0, max(0.0, totalUtil / Double(count))) : 0.0
    }
    
    // MARK: - RAM
    private func readRamUsage() -> RAMUsage {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return RAMUsage() }
        
        let pageSize = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let usedBytes = active + wired + compressed
        
        var totalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMemory, &size, nil, 0)
        let totalBytes = Double(totalMemory)
        
        let usedGB = usedBytes / (1024 * 1024 * 1024)
        let totalGB = totalBytes / (1024 * 1024 * 1024)
        let percent = totalBytes > 0 ? min(100.0, max(0.0, (usedBytes / totalBytes) * 100.0)) : 0.0
        
        return RAMUsage(
            usedGB: usedGB,
            totalGB: totalGB,
            percentage: percent,
            appMemoryGB: active / (1024 * 1024 * 1024),
            wiredGB: wired / (1024 * 1024 * 1024),
            compressedGB: compressed / (1024 * 1024 * 1024)
        )
    }
    
    // MARK: - Disk
    private func readDiskUsage() -> DiskUsage {
        do {
            let rootURL = URL(fileURLWithPath: "/")
            let values = try rootURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeNameKey])
            let total = Double(values.volumeTotalCapacity ?? 0)
            let free = Double(values.volumeAvailableCapacityForImportantUsage ?? 0)
            let used = max(0, total - free)
            
            let totalGB = total / (1024 * 1024 * 1024)
            let freeGB = free / (1024 * 1024 * 1024)
            let usedGB = used / (1024 * 1024 * 1024)
            let percent = total > 0 ? min(100.0, max(0.0, (used / total) * 100.0)) : 0.0
            let name = values.volumeName ?? "Macintosh HD"
            
            return DiskUsage(usedGB: usedGB, freeGB: freeGB, totalGB: totalGB, percentage: percent, volumeName: name)
        } catch {
            return DiskUsage()
        }
    }
}
