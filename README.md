# CGPU Monitor 🖥️⚡

macOS 실시간 시스템 모니터링 데스크톱 위젯 & 메뉴바 애플리케이션 (SwiftUI + AppKit)

Apple Silicon 및 Intel Mac에서 **CPU, GPU, RAM, SSD** 상태를 바탕화면에 세련된 글래스모피즘(Glassmorphism) 반투명 위젯으로 실시간(1초 주기) 표시합니다.

---

## 주요 기능

1. **CPU 모니터링**:
   - 실시간 전체 CPU 사용률 (%)
   - 활성 코어 수 및 프로세서 모델명
   - 실시간 스파크라인 추이 그래프
2. **GPU 모니터링**:
   - Apple Silicon GPU 가속기 실시간 점유율 (%)
   - GPU 사용량 스파크라인 그래프
3. **RAM 모니터링**:
   - 실시간 메모리 사용률 (%) 및 실제 사용량 / 총 용량 (GB)
   - 앱 메모리, 와이어드 메모리, 압축 메모리 정밀 계산
4. **SSD (디스크) 모니터링**:
   - 메인 스토리지(Macintosh HD) 점유율 (%)
   - 남은 여유 용량(GB) 및 전체 디스크 용량(GB)
5. **편리한 UI & 컨트롤**:
   - **글래스모피즘 디자인**: macOS 네이티브 블러(`ultraThinMaterial`) 및 부드러운 애니메이션
   - **자유로운 드래그 이동**: 위젯 어디든 마우스로 잡고 바탕화면 원하는 위치로 이동
   - **뷰 모드 전환**: 상세 2x2 대시보드 ↔ 컴팩트 4열 원형 게이지
   - **항상 위 (Pin) 고정**: 다른 창에 가려지지 않게 고정
   - **상단 메뉴바 통합**: 상단 메뉴바 아이콘 클릭으로 언제든 열기/닫기/위치 리셋 지원
   - **초경량 네이티브**: 백그라운드 CPU 및 메모리 점유율 극소화

---

## 빌드 및 실행

```bash
# 빌드
./build.sh

# 실행
open CGPUMonitor.app
```

---

## 함께 제공되는 3가지 모니터링 솔루션

1. **iStat Menus 7 (기존 설치됨)**:
   - 바탕화면 우클릭 → `위젯 편집` → `iStat Menus` 위젯을 바탕화면이나 알림 센터에 추가
2. **오픈소스 eul & Stats (설치 완료)**:
   - `eul`: macOS 공식 WidgetKit 바탕화면/알림 센터 위젯 지원 (`open /Applications/eul.app`)
   - `stats`: 메뉴바 실시간 모니터링 최고 오픈소스 (`open /Applications/Stats.app`)
3. **CGPU Monitor (현재 프로젝트)**:
   - 바탕화면에 자유롭게 떠 있는 실시간 플로팅 데스크톱 위젯 (`open CGPUMonitor.app`)
