# CGPU Monitor 🖥️⚡ `v1.1.0`

[![macOS](https://img.shields.io/badge/macOS-12.0%2B-black?logo=apple&style=flat-square)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white&style=flat-square)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/badge/Release-v1.1.0%20(Build%202)-teal?style=flat-square)](https://github.com/krazyeom/cgpu/releases)

> **Languages**: [English](#english) · [한국어 (Korean)](#korean)

---

<a name="english"></a>
## English

An ultra-lightweight, native macOS real-time system monitoring desktop floating widget & menu bar utility built with **SwiftUI + AppKit**.

Engineered for both **Apple Silicon (M1/M2/M3/M4)** and **Intel Macs**, CGPU Monitor continuously displays real-time telemetry (1-second update cycle) for **CPU, GPU, RAM, SSD, Network, and Battery** through a modern glassmorphic translucent desktop HUD.

### ✨ Key Features

1. **CPU Monitoring**:
   - Real-time overall CPU load percentage (%)
   - Active core count & Apple Silicon / Intel model identification
   - Real-time 20-second sparkline history trend graph
2. **GPU Monitoring**:
   - Apple Silicon hardware GPU accelerator occupancy (%)
   - Dedicated GPU load sparkline waveform
3. **RAM (Memory) Monitoring**:
   - Real-time memory pressure & usage percentage (%)
   - Precise breakdown of App Memory, Wired Memory, and Compressed Memory
4. **SSD (Disk) Monitoring**:
   - Primary storage (`Macintosh HD`) utilization percentage (%)
   - Free storage capacity (GB) vs. total capacity (GB)
5. **Network & Battery Telemetry**:
   - Real-time upload/download throughput per second (MB/s, KB/s, B/s)
   - Battery health, charge percentage (%), power source (AC/Battery), and charging status
   - **Connected Bluetooth Accessories Battery**: Real-time battery levels for connected **AirPods** (individual Left / Right earbuds and Charging Case), **Apple Pencil**, **Magic Mouse**, **Magic Keyboard**, **Magic Trackpad**, and Bluetooth headphones/controllers.
6. **Three Window Sizing Modes**:
   - **Standard**: 2-column rich dashboard with model details, core splits, and 20s telemetry history waveforms.
   - **Compact (125pt)**: Space-efficient circular ring gauges for clean glancing.
   - **Minimal (28pt Titlebar Height)**: Ultra-slim single-line status bar (530pt for all 6 metrics, 391pt for 4 metrics) with zero text truncation (`.fixedSize`) and natural spacing.
7. **Interactive Sensor Telemetry Popovers (Mouse Hover)**:
   - Hover your mouse over any metric tag (`CPU`, `GPU`, `RAM`, `SSD`, `NET`, `BAT`) to instantly reveal detailed hardware cards:
     - Temperatures (°C), Power Draw (W), Fan Speed (RPM)
     - Performance (P) vs. Efficiency (E) core splits
     - Swap memory allocation, APFS disk formatting, network lifecycle totals
8. **Customizable Metric Indicators (Config ⚙️)**:
   - Select exactly which indicators to display via the in-app gear popover (⚙️) or the `Displayed Metrics` menu bar item.
   - The widget automatically recalculates its width/height with smooth native animations.
9. **UI & Usability Enhancements**:
   - **True Alpha Glass Translucency**: 48% optical blur translucency that blends over background windows ↔ 100% solid dark mode.
   - **Menu Bar Snapping (`⌘T`)**: Magnetically dock the widget directly below the macOS top menu bar without a single pixel gap.
   - **Freely Draggable**: Drag from any part of the widget to position it anywhere on your desktop.
   - **State Persistence**: Window coordinates, selected sizing mode, language, opacity, pin state, and enabled metrics persist across restarts (`UserDefaults(suiteName: "com.cgpu.monitor")`).
   - **Always on Top (Pin 📌)**: Keep the HUD floating above all full-screen or focused application windows.
   - **Bilingual Support (EN / KO)**: English-first by default, toggleable to Korean with one click (`KO / EN` button or menu bar).
   - **Direct Copyright & About Access**: Click the "CGPU" logo in any mode to open the native macOS About panel, or hover for quick version & copyright info.

---

### ⌨️ Keyboard Shortcuts

| Shortcut | Description |
| :--- | :--- |
| `⌘1` | Switch to Standard Mode (360x295) |
| `⌘2` | Switch to Compact Mode (320x125) |
| `⌘3` | Switch to Minimal Mode (28pt height, 530pt width) |
| `⌘T` | Magnetically snap to top screen edge (under menu bar) |
| `⌘O` | Toggle Alpha Glass Translucency ↔ Solid Dark Opaque |
| `⌘L` | Toggle Launch at Login (macOS ServiceManagement) |
| `⌘M` | Toggle Widget Window Visibility |
| `⌘Q` | Quit Application |

---

### 🚀 Installation & Quick Start

#### Option A: Drag-and-Drop DMG Installer (Recommended)
1. Download the latest release `CGPUMonitor-v1.1.0.dmg` from the [Releases](https://github.com/krazyeom/cgpu/releases) page.
2. Double-click the DMG to open the stylized Retina installer window.
3. Drag `CGPUMonitor.app` into the `Applications` folder shortcut.
4. Launch `CGPUMonitor` from Spotlight or Launchpad.

#### Option B: Compile from Source
```bash
# Clone the repository
git clone https://github.com/krazyeom/cgpu.git
cd cgpu

# Compile the standalone .app bundle
./build.sh

# Run immediately
open CGPUMonitor.app

# Optional: Generate a custom Retina DMG installer package
./make_dmg.sh
# -> Outputs CGPUMonitor-v1.1.0.dmg
```

---

<a name="korean"></a>
## 한국어 (Korean)

Apple Silicon(M1/M2/M3/M4) 및 Intel Mac에서 **CPU, GPU, RAM, SSD, Network, Battery** 6대 핵심 자원의 실시간(1초 주기) 상태를 바탕화면에 세련된 글래스모피즘(Glassmorphism) 반투명 위젯으로 표시하는 네이티브 macOS 모니터링 애플리케이션입니다.

### 🌟 주요 기능 요약

1. **실시간 6대 지표 모니터링**:
   - **CPU**: 전체 점유율(%), 코어 수 및 칩셋 모델명, 20초 스파크라인 그래프
   - **GPU**: Apple Silicon 가속기 점유율(%) 및 실시간 스파크라인
   - **RAM**: 메모리 사용률(%) 및 실제 점유/총 용량(GB), 앱/와이어드/압축 메모리 상세
   - **SSD**: 주 스토리지(`Macintosh HD`) 점유율(%) 및 잔여 여유 공간(GB)
   - **Network**: 초당 실시간 다운로드/업로드 속도 (MB/s, KB/s, B/s)
   - **Battery**: 본체 배터리 잔여량(%) 및 충전 어댑터 연결/충전 상태, 그리고 연결된 **에어팟(AirPods 좌/우 유닛 및 충전 케이스), 애플펜슬(Apple Pencil), 매직 마우스, 매직 키보드, 트랙패드, 블루투스 헤드셋** 실시간 잔량 통합 모니터링
2. **3단계 창 크기 모드**:
   - **보통 (Standard)**: 2열 상세 대시보드 + 모델명/코어 분할 + 실시간 추이 그래프
   - **작게 (Compact, 125pt)**: 원형(Ring) 게이지로 깔끔하게 축소
   - **완전 한줄 (Minimal, 28pt)**: macOS 표준 창의 제목표시줄(Titlebar) 높이(28pt)로 한 줄에 메트릭을 보여주는 초슬림 바 위젯! (6개 지표 기준 **530pt**, 4개 지표 기준 **391pt**로 정밀 다이어트 완료)
3. **마우스 호버(Hover) 상세 센서 팝오버**:
   - 각 지표 위에 마우스를 올리면 **온도(°C), 소비 전력(W), 팬 속도(RPM), P/E 코어 분할, 스왑 메모리, APFS 포맷, 네트워크 누적 통계** 카드가 즉시 노출됩니다.
4. **표시 항목 맞춤 설정 (Metrics Config ⚙️)**:
   - 위젯의 ⚙️ 아이콘 또는 상단 메뉴바의 `Displayed Metrics` 메뉴에서 원하는 지표만 선택 표시 가능 (너비 자동 최적화).
5. **글래스모피즘 & 편의 제어**:
   - **알파 글래스 투과**: 다른 작업 창 위에 띄워도 뒤의 내용이 은은하게 비치는 48% 투과율 ↔ 완전 불투명 솔리드 원클릭 전환
   - **화면 최상단 스냅 (`⌘T`)**: 상단 메뉴바 바로 아래 1픽셀 오차 없이 자석 밀착
   - **자유로운 드래그 이동**: 위젯 어디든 마우스로 잡고 바탕화면 원하는 위치로 이동
   - **상태 영속화**: 앱을 재실행하거나 `killall`로 종료되어도 창 위치, 크기 모드, 활성 지표 완벽 복원
   - **항상 위 고정 (Pin 📌)**: 다른 작업 창 위에 위젯 상시 고정
   - **미니멀 바 로고 인터랙션**: "CGPU" 로고 클릭 시 macOS 공식 About 패널 호출 및 호버 시 저작권 툴팁 표시
   - **다국어 지원**: 영문(English) 모드가 기본값으로 실행되며, `KO / EN` 버튼을 통해 한국어로 원클릭 전환 가능

---

### ⌨️ 단축키 안내

| 단축키 | 기능 |
| :--- | :--- |
| `⌘1` | 보통 크기 (Standard, 360x295) |
| `⌘2` | 작은 크기 (Compact, 320x125) |
| `⌘3` | 완전 한줄 (Minimal, 530x28 타이틀바 크기) |
| `⌘T` | 화면 최상단(메뉴바 바로 밑)으로 자석 스냅 |
| `⌘O` | 불투명 다크 ↔ 반투명 알파 글래스 토글 |
| `⌘L` | Mac 로그인 시 자동 실행 등록/해제 |
| `⌘M` | CGPU Monitor 위젯 열기 / 닫기 |
| `⌘Q` | 애플리케이션 종료 |

---

### 🛠️ 빌드 및 설치

```bash
# 1. 앱 컴파일 및 패키징
./build.sh

# 2. 실행
open CGPUMonitor.app

# 3. 배포용 원클릭 DMG 인스톨러 생성
./make_dmg.sh
# -> CGPUMonitor-v1.1.0.dmg 생성 완료!
```

---

## 📚 Technical Architecture & Blog

* **Architecture Deep Dive**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
  - Mach Kernel API, IOKit SMC Sensor Bridge, AppKit/SwiftUI Window Layering, Dynamic Width Engineering
* **Engineering Blog Post**: [docs/BLOG_POST.md](docs/BLOG_POST.md)
  - 1인칭 개발기 (No AI-cliche, strictly following `epoko77-ai/im-not-ai` style guide)

---

## 👨‍💻 Author & License

* **Developer**: krazyeom ([@krazyeom](https://github.com/krazyeom))
* **Repository**: [https://github.com/krazyeom/cgpu](https://github.com/krazyeom/cgpu)
* **Copyright**: Copyright © 2026 krazyeom. All rights reserved.
* **License**: Licensed under the [MIT License](LICENSE).
