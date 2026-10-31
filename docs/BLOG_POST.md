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

## 9. 써보며 느낀 점

Xcode GUI를 켜지 않고 터미널에서 `swiftc`로 1초 만에 빌드해 `.app` 번들로 묶어 쓰니 정말 가볍다. 백그라운드에서 CPU 점유율은 0.1% 미만이고 메모리도 20MB 남짓만 먹는다.

무엇보다 화면 상단에 28pt 두께의 반투명 바로 얹어두니, 어떤 작업을 하든 시야를 가리지 않으면서 시스템 상태를 한눈에 훑어볼 수 있어 마음이 편안하다.

코드는 모두 정리해서 저장소([https://github.com/krazyeom/cgpu](https://github.com/krazyeom/cgpu))에 올려두었다. 나와 비슷한 고민을 했던 맥 유저라면 직접 빌드해서 써보길 권한다.
