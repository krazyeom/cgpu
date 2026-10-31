# macOS 데스크톱에 딱 달라붙는 나만의 시스템 위젯 만들기 (SwiftUI + AppKit 삽질기)

맥북을 쓰다 보면 늘 아쉬운 게 하나 있었다. iStat Menus나 Stats 같은 훌륭한 앱들이 있지만, 메뉴바는 이미 온갖 아이콘으로 꽉 차 있고 알림 센터 위젯은 굳이 쓸어 넘겨야 보인다. 내가 원한 건 단순했다.

> "코드 에디터 위든 브라우저 위든, 화면 맨 위에 얇은 타이틀바처럼 착 달라붙어서 CPU, GPU, RAM, SSD, 네트워크, 배터리 상태를 실시간으로 보여주는 가벼운 글래스 위젯."

시중에 마음에 쏙 드는 게 없어서, Swift 6와 SwiftUI, 그리고 AppKit을 엮어 직접 만들기로 했다. 이름은 단순하게 **CGPU Monitor**로 정했다. 주말 반나절 동안 저수준 커널 API를 뒤지고 윈도우 서버와 씨름하며 겪은 기술적 삽질과 해결 과정을 기록해 둔다.

---

## 1. 커널에서 지표 털어오기: Mach와 IOKit

맥에서 하드웨어 지표를 제대로 읽으려면 터미널 명령어를 파싱하는 꼼수를 쓰면 안 된다. 프로세스가 무거워지고 배터리를 갉아먹기 때문이다. C 기반의 Mach 커널 API와 IOKit 프레임워크를 직접 호출했다.

### CPU 틱(Tick) 계산의 함정
CPU 사용률은 단순히 현재 상태를 조회한다고 나오지 않는다. 이전 시점의 CPU 틱(User, System, Idle, Nice)과 현재 시점의 누적 틱 차이(Delta)를 계산해야 정확한 순간 점유율이 나온다.

```swift
var cpuLoad = host_cpu_load_info()
var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

let result = withUnsafeMutablePointer(to: &cpuLoad) {
    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
    }
}
```

여기에 `sysctlbyname`을 찔러서 M-시리즈 칩의 **성능 코어(P-Core)**와 **효율 코어(E-Core)** 개수를 각각 분리해 냈고, `getloadavg`로 1분·5분·15분 로드 에버리지까지 끌어왔다.

### Apple Silicon GPU 긁어오기
M 시리즈 맥의 GPU 점유율은 어디서 가져올까? IOKit 레지스트리의 `IOAccelerator` 노드를 뒤지면 `PerformanceStatistics`라는 딕셔너리가 숨어 있다.

```swift
let matchDict = IOServiceMatching("IOAccelerator")
// ... iterator 순회 ...
if let stats = dict["PerformanceStatistics"] as? [String: Any],
   let util = stats["Device Utilization %"] as? Int {
    gpuUtil = Double(util)
}
```

이걸로 별도 외부 툴 없이도 M5 Pro GPU의 실시간 가속률을 바로 뽑아낼 수 있었다.

---

## 2. 골치 아팠던 화면 렌더링 문제들

UI를 짤 때 부딪힌 문제들은 대부분 SwiftUI와 AppKit의 경계면에서 터져 나왔다.

### 첫 번째 삽질: "다른 창 위에 올리면 왜 뒤가 까맣게 가려지지?"
처음에는 애플이 자랑하는 `.ultraThinMaterial`을 배경에 둘렀다. 바탕화면 위에 얹었을 때는 그럴싸한 블러가 먹혀서 만족스러웠는데, 웹 브라우저나 VS Code 위로 창을 드래그하자마자 웬 짙은 회색 플라스틱 덩어리로 변해버렸다.

알고 보니 macOS의 `Material`은 보안과 성능 핑계로 **바탕화면(Desktop Wallpaper)만 블러 처리**하도록 OS 수준에서 막혀 있었다. 다른 앱 창의 텍스트나 그래픽은 블렌딩해주지 않는다.

해결은 의외로 단순했다. OS 블러를 버리고 **순수 알파 반투명(`Color.black.opacity(0.48)`)**을 입힌 것이다.

```swift
RoundedRectangle(cornerRadius: 7, style: .continuous)
    .fill(Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.48))
    .overlay(
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .stroke(LinearGradient(...), lineWidth: 1)
    )
```

이렇게 바꾸자 아래에 놓인 브라우저 기사나 터미널 코드가 100% 훤히 비쳐 보였다. 내가 진짜 원했던 투명 글래스 느낌이 바로 이거였다.

---

### 두 번째 삽질: 화면 최상단으로 왜 안 올라갈까?
위젯을 메뉴바 바로 밑에 1픽셀도 남기지 않고 딱 붙이고 싶었다. 그런데 마우스로 아무리 밀어 올려도 메뉴바 아래 약 25픽셀 지점에서 턱 하고 걸렸다.

범인은 `NSWindow`의 `styleMask`였다. 창에 `.titled` 속성이 묻어 있으면, 윈도우 서버가 "이 창은 타이틀바가 있으니 메뉴바 아래 여백을 둬야 해"라며 `constrainFrameRect`로 강제 제약을 걸어버린다.

`NSPanel`을 상속받아 제약 함수를 가차 없이 오버라이드했다.

```swift
final class WidgetPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        guard let screen = screen else { return frameRect }
        var rect = frameRect
        let visible = screen.visibleFrame
        
        // 메뉴바 바로 밑 최상단(visible.maxY)에 딱 달라붙도록 강제 보정
        if rect.maxY > visible.maxY {
            rect.origin.y = visible.maxY - rect.height
        }
        return rect
    }
}
```

동시에 `styleMask`를 `.borderless`로 완전히 깎아냈다. 이제 마우스로 던져도 상단 메뉴바 밑에 자석처럼 찰떡같이 밀착된다. 단축키 `⌘T` 하나로 중앙 상단에 바로 스냅되게 만든 건 덤이다.

---

### 세 번째 삽질: 28pt 한 줄 모드와 애니메이션 덜컹거림
이 앱의 핵심은 3단계 크기 변환이다:
1. **Standard (360x380)**: 2x3 전체 메트릭 카드와 20초 스파크라인 그래프
2. **Compact (380x125)**: 6개 원형 링 게이지
3. **Minimal (580x28)**: 실제 창 제목표시줄 두께인 28pt 초슬림 바

문제는 모드를 바꿀 때 창 크기를 줄이는 AppKit 애니메이션과 SwiftUI의 뷰 교체 스프링 애니메이션이 박자가 안 맞아 창이 찌그러지며 덜컹거렸다는 점이다.

SwiftUI 쪽의 통통 튀는 스프링 효과를 싹 걷어내고 `ZStack` 기반의 `.transition(.opacity)` 페이드로 통일한 뒤, AppKit 애니메이션 시간과 정확히 0.2초 Ease-In-Out으로 맞췄다.

```swift
NSAnimationContext.runAnimationGroup { context in
    context.duration = 0.2
    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    window.animator().setFrame(newFrame, display: true)
}
```

이제 단축키 `⌘1`, `⌘2`, `⌘3`을 누르면 위젯이 스르륵 녹아들듯 크기를 바꾼다.

---

## 3. 손맛을 더한 마우스 호버(Hover) 팝오버

28pt짜리 얇은 바 모드를 기본으로 쓰다 보니, 가끔은 "지금 CPU 온도가 몇 도지?", "팬이 돌고 있나?" 같은 상세 정보가 궁금할 때가 있다.

그렇다고 창을 키우기는 귀찮아서, **마우스 호버 팝오버**를 달았다. 얇은 한 줄 상태에서도 `CPU`, `GPU`, `RAM`, `SSD`, `NET`, `BAT` 글자 위에 마우스를 슥 얹으면 아래로 화살표와 함께 묵직한 상세 카드가 펼쳐진다.

* **CPU**: 코어 온도(°C), 실시간 전력(W), 스마트 팬(0 RPM 무소음 여부), P/E 코어 분할, 로드 에버리지
* **GPU**: 칩셋 온도, GPU 소비 전력, Metal 4 하드웨어 가속 상태
* **RAM**: 64GB 중 앱/와이어드/압축 메모리 상세 분할, 스왑 사용량
* **SSD**: 실시간 가용 용량, APFS 포맷, FileVault 하드웨어 암호화 상태
* **NET**: 초당 다운로드/업로드 속도(MB/s, KB/s), 누적 송수신량
* **BAT**: 전원 어댑터 연결 여부, 실시간 충전 와트수, 배터리 잔여 시간

---

## 4. 껐다 켜면 제자리로: 창 위치와 설정 기억시키기

모든 기능을 다 만들고 맥을 재부팅해 봤는데, 짜증 나는 일이 하나 생겼다.
화면 최상단 메뉴바 바로 밑에 곱게 맞춰둔 28pt 미니멀 바가, 앱을 껐다 켤 때마다 화면 정중앙 360x380짜리 기본 크기로 떡하니 초기화되는 것이었다.

"내가 끌어다 둔 자리랑 쓰던 모드는 그대로 살아있어야 진짜 데스크톱 앱이지."

곧바로 `NSWindowDelegate`를 붙이고 `windowDidMove`를 연결했다. 창을 드래그해서 마우스를 떼는 순간 현재 x, y 좌표를 `UserDefaults`에 박아넣도록 만들었다.

```swift
nonisolated func windowDidMove(_ notification: Notification) {
    Task { @MainActor in
        self.saveCurrentState()
    }
}
```

여기에 윈도우 크기 모드(Standard/Compact/Minimal), 반투명 모드 온/오프, 항상 위 고정 핀, 그리고 언어(EN/KO) 설정까지 죄다 직렬화해 두었다.

그런데 여기서 또 하나의 복병이 있었다. 만약 맥북을 외장 모니터에 물려서 쓰다가 외장 모니터를 뽑아버리면 어떻게 될까? 이전에 외장 모니터 구석에 띄워뒀던 좌표를 그대로 복원하면, 창이 허공(화면 밖)에 떠서 눈에 보이지도 않고 만질 수도 없는 '유령 창'이 되어버린다.

그래서 실행할 때 현재 연결된 모니터들의 가시 영역(`NSScreen.screens.visibleFrame`)과 복원할 좌표의 교집합(`intersects`)을 체크하는 안전장치를 넣었다. 화면 밖으로 탈출한 좌표라면 얌전하게 현재 주 모니터의 상단 중앙으로 재배치하도록 했다. 이제 맥북을 들고 회의실을 오가도 창을 잃어버릴 염려가 없다.

---

## 5. 저장소 공개와 마무리: 바이너리 및 개인 설정 털어내기

이제 내 로컬 맥북에서만 쓰던 녀석을 깃허브([https://github.com/krazyeom/cgpu](https://github.com/krazyeom/cgpu))에 퍼블릭으로 올릴 차례였다.
깃에 푸시하기 전에 늘 신경 쓰이는 게 두 가지다. 첫째는 개인 로컬 경로(예: `/Users/username/...`)나 비밀 키, `.env` 파일 같은 민감한 데이터가 딸려 올라가는 사고이고, 둘째는 뚱뚱한 컴파일 바이너리가 깃 히스토리에 박혀버리는 일이다.

실제로 처음에 커밋했을 때 `build.sh`로 생성된 `CGPUMonitor` 실행 파일과 `.app` 번들 내부 바이너리가 깃에 묻어있었다. 바로 `.gitignore`를 손봤다.

```gitignore
# Compiled Binaries & App Executables
/CGPUMonitor
/CGPUMonitor.app/Contents/MacOS/CGPUMonitor
*.o
*.dSYM/

# Secrets & Local Environment
.env*
*.key
*.pem
id_rsa*
.netrc
```

여기서 재밌는 삽질이 하나 있었는데, `.gitignore` 맨 위에 그냥 `CGPUMonitor`라고 적어뒀더니 `Sources/CGPUMonitor/` 소스 코드 디렉토리까지 통째로 무시되어 버리는 대참사가 일어날 뻔했다. 루트 실행 파일만 무시하도록 `/CGPUMonitor`로 슬래시를 딱 붙여서 깔끔하게 해결했다.

그리고 위젯 하단과 상단 메뉴바의 크레딧 메뉴에 만든 사람(`by krazyeom`)과 깃허브 링크를 걸어두었다.

---

## 6. 글자가 "C..", "G.."로 잘리는 굴욕: 28pt 미니멀 바의 한계와 가변 폭 설계

네트워크 속도와 배터리 지표까지 야심 차게 얹고 나서 흡족해하고 있었는데, 28pt 한 줄 모드로 전환하자마자 말문이 턱 막혔다.

`C.. 12%  G.. 5%  R.. 48%  S.. 65%  N.. 1.2 MB/s  B.. 100%`

예상했던 깔끔한 태그 대신, SwiftUI 레이아웃 엔진이 좁아터진 580pt 폭 안에서 텍스트를 마구 쥐어짜며 라벨 끝을 얄밉게 말줄임표(...)로 날려버린 것이다.

원인은 명확했다.
* 태그 6개 × 약 85~110pt = 약 530pt
* 좌측 타이틀 로고 + 우측 언어/설정/투명도/모드/핀/닫기 버튼들 = 약 180pt
* 여기에 패딩과 간격까지 더하면 아무리 쥐어짜도 750pt 이상이 필요했다. 580pt 고정 폭으로는 물리적으로 들어갈 수가 없었다.

두 가지 조치를 취했다.
첫 번째로, 텍스트가 어떤 상황에서도 찌그러지거나 잘리지 않도록 강제 제약을 걸었다.

```swift
Text(label)
    .font(.system(size: 10, weight: .bold))
    .foregroundColor(color)
    .lineLimit(1)
    .fixedSize(horizontal: true, vertical: false)

Text(valueString)
    .font(.system(size: 10, weight: .bold, design: .monospaced))
    .foregroundColor(.primary)
    .lineLimit(1)
    .fixedSize(horizontal: true, vertical: false)
```

`.fixedSize(horizontal: true, vertical: false)`를 먹이자마자 라벨이 본래 길이를 당당하게 되찾았다.

두 번째로, 창 폭을 무식하게 800pt로 고정하는 대신 **활성화된 지표 수에 따라 유연하게 늘고 주는 가변 폭 계산식**을 넣었다.

```swift
private var minimalWidth: CGFloat {
    var width: CGFloat = 240 // 타이틀, 여백, 우측 컨트롤 버튼 6개 기준선
    if config.showCPU { width += 88 }
    if config.showGPU { width += 88 }
    if config.showRAM { width += 88 }
    if config.showDisk { width += 88 }
    if config.showNetwork { width += 112 } // MB/s 단위를 위한 넉넉한 공간
    if config.showBattery { width += 88 }
    return max(360, width)
}
```

이제 6개 항목을 전부 켜면 792pt로 시원하게 열리고, 텍스트가 잘리는 일은 영원히 안녕이다.

---

## 7. 내가 보고 싶은 것만 골라 담기: Config 시스템과 팝오버

"나는 맥 스튜디오라 배터리 항목이 필요 없는데?"
"나는 CPU랑 GPU만 딱 두 개 띄워두고 싶은데?"

이런 요구는 너무나 자연스럽다. 사용자가 직접 원하는 지표를 빼고 넣을 수 있는 설정(Config) 시스템을 만들었다.

`MetricConfig` 구조체를 파고, `Codable`로 묶어 `UserDefaults`에 직렬화했다. 실수로 모든 지표를 다 꺼버려서 창이 텅 비는 사태를 막으려고 `canDisable` 방어 로직(최소 1개 지표 필수)도 챙겼다.

그리고 위젯 헤더와 미니멀 바에 조그마한 톱니바퀴(⚙️) 아이콘을 달았다. 이걸 누르면 작고 예쁜 설정 팝오버가 슥 열린다.

```swift
Toggle("", isOn: isOn)
    .labelsHidden()
    .toggleStyle(SwitchToggleStyle(tint: metric.color()))
    .scaleEffect(0.7)
    .disabled(isOn.wrappedValue && !config.canDisable(metric: metric))
```

상단 메뉴바의 `Displayed Metrics` 메뉴와도 양방향으로 연동시켰다. 메뉴바에서 체크를 끄든, 위젯 팝오버에서 스위치를 끄든, 위젯 창이 0.2초 Ease-In-Out 애니메이션과 함께 지표 개수에 맞춰 스르륵 줄어들거나 늘어난다. 이 손맛이 제법 쏠쏠하다.

---

## 8. v1.1.0 버저닝과 태그 릴리즈

단순한 개인 토이 프로젝트로 시작했지만 기능이 제법 어엿해졌다. 이제 체계적인 시맨틱 버저닝을 도입하기로 했다.

* 버전 상수: `AppVersion.version = "1.1.0"`, `build = "2"`
* `Info.plist`의 `CFBundleShortVersionString`과 `CFBundleVersion` 동기화
* 위젯 하단 크레딧: `v1.1.0 by krazyeom`
* 상단 메뉴바: `CGPU Monitor v1.1.0 (Build 2) (by krazyeom)`

깃 커밋을 남기고 `git tag -a v1.1.0`으로 첫 마이너 버전 태그를 깔끔하게 발행했다.

---

## 9. killall로 껐다 켰는데 왜 위치를 못 잡을까? (UserDefaults의 숨겨진 함정)

v1.1.0 태그까지 신나게 찍고 나서 테스트를 해보는데, 덜컥 이상한 현상이 터졌다.
터미널에서 `killall CGPUMonitor; open CGPUMonitor.app`으로 앱을 재시작했더니, 기껏 상단에 맞춰둔 미니멀 바가 또다시 화면 한가운데에 뚱뚱한 보통 크기로 리셋되어 버리는 것이었다.

"아까 분명히 `UserDefaults`에 저장 로직 다 넣어뒀는데 대체 왜?"

스위프트 REPL을 열고 `UserDefaults.standard`를 찔러보고서야 무릎을 쳤다. 범인은 두 가지였다.

첫째, `UserDefaults.standard.object(forKey:) as? Int`의 타입 캐스팅 실패다. 스위프트 표준 라이브러리에서 `object(forKey:)`가 반환하는 내부 `NSNumber`가 일부 컨텍스트에서 `as? Int`로 부드럽게 넘어오지 않고 뻔뻔하게 `nil`을 뱉고 있었다.
`as? Int` 대신 `defaults.integer(forKey:)`와 `defaults.double(forKey:)`를 써야 안전했다.

둘째, macOS의 `cfprefsd` 캐싱 정책과 강제 종료(`killall`)의 충돌이었다. `UserDefaults`는 성능을 위해 메모리에 썼다가 비동기로 디스크 plist에 내린다. 사용자가 창을 옮기고 1초도 안 돼서 `killall`을 날리면 프로세스가 시그널을 맞고 즉사하면서 미처 파일에 쓰이지 못한 데이터가 증발해 버린다.

게다가 앱 번들 컨텍스트와 무관하게 언제나 같은 도메인을 바라보도록 명시적인 **Suite Domain (`UserDefaults(suiteName: "com.cgpu.monitor")`)**을 박아두고, 저장할 때마다 `synchronize()`로 디스크에 즉시 도장을 찍었다.

```swift
private let appDefaults: UserDefaults = {
    return UserDefaults(suiteName: "com.cgpu.monitor") ?? UserDefaults.standard
}()

private func saveCurrentState() {
    guard let window = self.window else { return }
    let frame = window.frame
    appDefaults.set(Double(frame.origin.x), forKey: DefaultsKey.windowX)
    appDefaults.set(Double(frame.origin.y), forKey: DefaultsKey.windowY)
    appDefaults.set(currentMode.rawValue, forKey: DefaultsKey.widgetMode)
    appDefaults.set(isOpaque, forKey: DefaultsKey.isOpaque)
    appDefaults.set(isAlwaysOnTop, forKey: DefaultsKey.isAlwaysOnTop)
    appDefaults.set(currentLanguage.rawValue, forKey: DefaultsKey.language)
    currentConfig.save()
    appDefaults.synchronize() // 강제 종료 대비 즉시 플러시
}
```

여기에 정상 종료 상황까지 대비해 `applicationWillTerminate` 델리게이트까지 걸어두니, 이제 아무리 사정없이 `killall`을 날려도 살아날 땐 원래 있던 자리와 쓰던 모드로 1픽셀 오차 없이 딱 복원된다.

---

## 10. 포토샵 없이 코드로 깎아 만든 1024px 네이티브 AppIcon

앱이 기능적으로 완성되자, Dock과 Finder에서 기본 흰색 도화지 아이콘으로 뜨는 게 영 눈에 밟혔다. 디자이너도 없고 무거운 포토샵이나 피그마를 켜기도 귀찮아서, 맥에 내장된 `CoreGraphics`와 `AppKit`으로 직접 아이콘을 코딩하기로 했다.

`generate_icon.swift`라는 100줄짜리 스크립트를 짜서 1024x1024 비트맵 캔버스에 직접 벡터를 그렸다:
* macOS 정규 규격인 824x824 크기의 스퀘어클(Squircle, r:185) 외곽선과 흑요석 다크 글래스 그라데이션.
* 중앙에 애플 실리콘 칩 패키지와 4개 서브시스템(CPU: 청록, GPU: 보라, RAM: 초록, SSD: 주황)의 네온 버스 라인.
* 다이 한가운데에 레이저 각인된 "CGPU" 타이포와 실시간 텔레메트리 파형.

```bash
# 1. 1024px 마스터 PNG 생성
swift generate_icon.swift

# 2. sips로 16~1024px 레티나 아이콘셋 일괄 리사이즈
sips -z 16 16 AppIcon_1024.png --out AppIcon.iconset/icon_16x16.png
# ... (32, 64, 128, 256, 512, 1024 생성) ...

# 3. macOS 공식 icns 컴파일
iconutil -c icns AppIcon.iconset -o AppIcon.icns
```

터미널 엔터 한 번 치자 680KB짜리 정규 `AppIcon.icns`가 1초 만에 툭 떨어졌다. `Info.plist`에 연결해 앱을 빌드하니, 상단 메뉴바와 독에 매끄러운 글래스 실리콘 칩 아이콘이 선명하게 떠오른다.

---

## 11. 맥북 감성 듬뿍 담은 배포용 DMG 인스톨러 자동화

마지막 퍼즐은 배포 파일이었다. 보통 맥 앱을 깃허브에서 받으면 압축 파일(`.zip`)로 풀기보다, 더블클릭했을 때 예쁜 창이 열리면서 "앱을 Applications 폴더로 끌어다 놓으세요" 하는 그 특유의 DMG 설치 창을 만나는 게 훨씬 기분 좋다.

외부 툴(create-dmg 등)을 설치하지 않고, 순수 맥 내장 `hdiutil`과 `osascript`로 원클릭 DMG 빌더(`make_dmg.sh`)를 구현했다.

### 또 터진 버그: 배경 이미지가 왜 이렇게 거대해?
DMG를 만들어 더블클릭해보니, 뭔가 크게 이상했다. 창은 아담한 600x400인데, 안쪽에 깔린 배경 이미지가 2배로 뻥튀기되어 렌더링되고 있었다. 앱 아이콘과 Applications 폴더는 옹기종기 모여 있는데, 정작 배경의 드롭 타깃 플레이트와 네온 화살표는 저 멀리 창 밖으로 밀려나 있었다.

원인을 파고들어 보니 두 가지 복합적인 문제가 얽혀 있었다:
1. **Finder는 배경 이미지를 창 크기에 맞춰 줄여주지 않는다**: 웹 브라우저처럼 `background-size: contain` 같은 동작을 기대하면 안 된다. 72 DPI의 1200x800 PNG를 던져주면 Finder는 그 크기 그대로 1200x800 포인트로 인식해서 화면을 클리핑해버린다.
2. **CoreGraphics와 Finder의 상하 반전 좌표계**:
   - Finder AppleScript: 창 **좌상단(Top-Left)**이 (0,0), 아래로 갈수록 y 증가.
   - CoreGraphics: 이미지 **좌하단(Bottom-Left)**이 (0,0), 위로 갈수록 y 증가.

### 해결책: 660x440 통일과 멀티 레졸루션 TIFF
완벽한 싱크를 위해 캔버스를 660pt x 440pt로 통일하고 고해상도 패키징 파이프라인을 정립했다:

1. **`tiffutil -cathidpicheck`로 레티나 다중 해상도 TIFF 빌드**:
   `generate_dmg_background.swift`에서 논리 포인트 660x440을 기준으로 1x(`660x440.png`)와 2x(`1320x880.png`) 이미지를 각각 렌더링한 뒤, macOS 기본 유틸리티인 `tiffutil`로 하나로 합쳤다.
   ```bash
   /usr/bin/tiffutil -cathidpicheck dmg_background.png dmg_background@2x.png -out dmg_background.tiff
   ```
   이렇게 묶인 TIFF를 배경으로 지정하면, 일반 맥에서는 1x를, 레티나 맥에서는 2x 고선명 텍스처를 불러오면서도 두 환경 모두 **정확히 660x440 논리 포인트 크기로 꽉 채워 렌더링**한다.

2. **좌표계 수학적 보정**:
   창 높이가 $H = 440$pt이므로 $y_{\text{cg}} = 440 - y_{\text{finder}}$ 공식이 성립한다.
   - Finder 아이콘 위치: 좌측 앱 `{170, 210}`, 우측 Applications `{490, 210}`
   - 배경 드롭 플레이트 중심: 좌측 `(170, 230)`, 우측 `(490, 230)`
   - 중앙 네온 화살표: $x = 265$부터 $x = 395$, $y = 230$

```applescript
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 140, 860, 580}
        
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 120
        set background picture of theViewOptions to file ".background:background.tiff"
        
        set position of item "CGPUMonitor.app" of container window to {170, 210}
        set position of item "Applications" of container window to {490, 210}
        
        update without registering applications
        delay 2
        close
    end tell
end tell
```

다시 빌드하고 DMG를 열어보니, 마침내 감탄이 나오는 깔끔한 인스톨러 창이 떴다. 120pt 크기의 앱 아이콘이 좌측 글래스 플레이트 한가운데에 쏙 들어가 있고, 우측 Applications 타깃으로 매끄러운 그라데이션 화살표가 한 치의 어긋남 없이 연결되었다.

### 마운트했을 때 볼륨 아이콘이 왜 흰색 디스크로 뜨지? (Finder의 속성 리셋 버그)
인스톨러 창은 완벽해졌는데, DMG를 마운트했을 때 바탕화면과 Finder 사이드바에 뜬 드라이브 아이콘을 보고 멈칫했다. 앱 아이콘이 아니라 밋밋한 기본 흰색 외장 디스크가 덩그러니 앉아 있었다. 자매 프로젝트로 만들고 있던 `aWord`도 똑같은 증상이었다.

스크립트 안에서는 분명 `SetFile -a C`도 쳤고 `.VolumeIcon.icns`도 복사하도록 짜여 있었는데 왜 안 먹힐까? 터미널에서 `GetFileInfo`로 마운트된 디스크의 내부 플래그를 찍어보았다:
```bash
GetFileInfo "/Volumes/CGPU Monitor"
# attributes: avbstclinmedz (소문자 c = 커스텀 아이콘 속성 꺼짐!)
ls -la "/Volumes/CGPU Monitor/.VolumeIcon.icns"
# No such file or directory (파일 어디 갔어?!)
```

도대체 누가 `.VolumeIcon.icns`를 지우고 속성을 껐을까? 한 줄씩 추적하며 범인을 잡았다. 범인은 다름 아닌 **Finder의 AppleScript 창 저장 로직**이었다.
AppleScript가 창 크기와 위치를 정하고 `update without registering applications`로 `.DS_Store`를 기록한 뒤 창을 닫는(`close`) 순간, Finder가 볼륨 루트 디렉터리의 속성을 통째로 다시 직렬화하면서 이전에 설정해 둔 `kHasCustomIconBit`(대문자 `C`)를 소문자 `c`로 강제 초기화하고 정체 모를 숨김 파일로 분류된 `.VolumeIcon.icns`를 밀어버린 것이었다.

해결책은 순서를 뒤집는 것이었다:
**Finder 창 설정과 `close`가 완전히 끝난 직후**, 볼륨 루트에 아이콘을 집어넣고 속성을 박는 것이다.

```bash
# Finder가 창을 닫고 디스크를 떠난 뒤에 볼륨 아이콘 주입
echo "🎨 Applying custom VolumeIcon to mounted DMG volume..."
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "$MOUNT_DIR/.VolumeIcon.icns"
    SetFile -a C "$MOUNT_DIR"
    SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"
fi
sync
```

이렇게 순서를 바꾸자 `GetFileInfo` 결과에 드디어 대문자 `C`(`avbstClinmedz`)가 선명하게 살아남았다.
이 로직을 `cgpu`는 물론이고 자매 프로젝트인 `aWord`의 `create_dmg.sh`에도 똑같이 적용해 다시 빌드했다. 이제 DMG를 더블클릭해 마운트하는 순간, 바탕화면과 Finder 사이드바 "위치" 목록에 각각 `CGPU Monitor`와 `aWord`의 영롱한 고유 칩셋/타이포 아이콘이 완벽하게 떠오른다.

---

## 12. 530pt로 깎아낸 미니멀 바와 저작권(Copyright)의 정석

### 스크린샷 한 장이 알려준 75px의 유휴 공백
627pt로 1차 다이어트를 마치고 기분 좋게 릴리즈했더니, 실제 맥북 화면에 띄운 스크린샷이 도착했다. 텍스트 잘림은 완벽하게 사라졌는데, 오른쪽 끝 배터리 태그(BAT)와 제어 아이콘(⚙️) 사이에 70~80px 정도 휑한 빈 공간이 보였다. 사용자 입장에선 "아직도 필요 이상으로 넓다"고 느낄 만한 어색한 여백이었다.

무작정 숫자만 줄이면 긴 네트워크 속도(`999 KB/s`)나 RAM(`16.4G`)에서 다시 말줄임표가 터질 수 있으니, 각 태그의 마이크로 타이포그래피부터 다시 뜯어고쳤다:
* 태그 내부 패딩을 4.0pt, 폰트를 9.0pt, 컬러 도트를 4.0pt로 0.5pt씩 정밀하게 다듬었다.
* 지표 간 간격을 3.0pt로 맞추고, 우측 제어 버튼 간격도 2.5pt로 밀착시켰다.
* 이렇게 깎아내니 6개 전체 지표를 켰을 때 가로폭이 **627pt에서 530pt로 97pt(누적 262pt / 33%)나 줄어들었다.** 기본 4개 지표만 켜면 **391pt**의 앙증맞은 크기로 딱 떨어진다. 유휴 공백은 자연스러운 10pt 남짓의 숨통만 남기고 깔끔하게 사라졌다.

### "미니멀 바에서 개발자 정보는 어떻게 봐요?"
보통 모드에선 하단에 저작권이 보이지만, 미니멀 바만 띄워두면 개발자 정보가 어디 있는지 찾기 어려웠다. 맥 앱의 정석적인 UI 경험을 살려 총 다섯 가지 경로로 정리했다:

1. **미니멀 "CGPU" 로고 원클릭 (신규)**: 미니멀 바 맨 왼쪽의 "CGPU" 로고에 마우스를 올리면 `CGPU Monitor v1.1.0 · © 2026 krazyeom` 툴팁이 뜨고, 클릭하면 시스템 공식 About 정보창이 바로 열린다.
2. **macOS 공식 About 패널**: 상단 메뉴바 트레이 메뉴에서 `About CGPU Monitor`를 누르면 `Copyright © 2026 krazyeom. All rights reserved.`와 크레딧, 라이선스가 시스템 표준 창으로 뜬다.
3. **번들 메타데이터 (`Info.plist`)**: 시스템이 인식하는 `NSHumanReadableCopyright` 키 등록.
4. **위젯 설정 팝오버**: 톱니바퀴 클릭 시 하단에 `© 2026 krazyeom`과 깃허브 바로가기 링크 명시.
5. **보통(Standard) 모드 하단 바**: 메인 뷰 하단에 버전과 함께 상시 노출.

### 글로벌 오픈소스를 위한 영어 우선(English-First) README
깃허브에 코드를 올려두고 가만히 생각해보니, 전 세계 어디서 방문하더라도 첫 화면에서 바로 이해할 수 있게 만드는 게 오픈소스의 기본 예의였다.
그래서 Antigravity 에이전트 룰에 **'README 파일은 무조건 영어 우선 작성 후 한국어 병기'**라는 원칙을 공식 등록했다.
상단에 영어로 아키텍처 개요, 3가지 윈도우 모드, 단축키 표, DMG 설치 가이드를 깔끔하게 배치하고, 바로 아래에 완전한 한국어 가이드를 덧붙여 두 언어 모두 손쉽게 오갈 수 있도록 링크까지 연결해 두었다.

---

## 13. 마무리하며

주말 반나절 동안 Mach 커널 API 수집부터 시작해서, 28pt 미니멀 바, 마우스 호버 센서 팝오버, 다국어 지원, `UserDefaults` 영속화 버그 잡기, 네이티브 AppIcon 렌더링, 그리고 배포용 DMG 패키징까지 한달음에 달려왔다.

터미널에서 가볍게 빌드되고, 맥북 화면 상단에 얇은 글래스 타이틀바처럼 붙어서 배터리와 리소스를 한눈에 보여주는 나만의 위젯이 생기니 맥을 켤 때마다 뿌듯하다.

빌드 스크립트와 완성된 DMG는 깃허브 저장소([https://github.com/krazyeom/cgpu](https://github.com/krazyeom/cgpu))에 모두 공개해 두었다. 직접 빌드해서 써보고 싶은 분들은 저장소를 들러보시길!
