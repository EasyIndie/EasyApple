// tools/uiscan.swift — 原生 OCR 文本提取(Apple Vision 框架)
//
// 为什么用 OCR 而不是无障碍树:见 docs/06-ui-acceptance.md。
//   - 无障碍树(宿主 AX API)需要 Simulator.app GUI + 人工辅助功能授权,与「无头」冲突;
//   - XCUITest 需要 .xcodeproj(与 D4/D5 冲突);
//   - Vision OCR 完全原生、免授权、可无头 + CI 运行。代价:识别是「有损」的,断言用稳定串。
//
// 用法:
//   uiscan <png> [--json] [--fast] [--min-confidence N] [--lang zh-Hans,en-US]
// 文本模式: 每行一条,按「自上而下」排序
// JSON 模式: [{"text","confidence","x","y","width","height"}](坐标为归一化 0..1,原点左上)
import Foundation
import Vision
import ImageIO

func fail(_ msg: String, _ code: Int32) -> Never {
  FileHandle.standardError.write(Data("uiscan: \(msg)\n".utf8))
  exit(code)
}

func usage() -> Never {
  FileHandle.standardError.write(Data(
    "用法: uiscan <png> [--json] [--fast] [--min-confidence N] [--lang a,b]\n".utf8))
  exit(2)
}

var path = ""
var json = false
var fast = false
var langs = ["zh-Hans", "en-US"]
var minConfidence: Float = 0

let argv = CommandLine.arguments
var i = 1
while i < argv.count {
  switch argv[i] {
  case "--json": json = true
  case "--fast": fast = true
  case "--lang":
    i += 1; guard i < argv.count else { usage() }
    langs = argv[i].split(separator: ",").map(String.init)
  case "--min-confidence":
    i += 1; guard i < argv.count, let v = Float(argv[i]) else { usage() }
    minConfidence = v
  default:
    if argv[i].hasPrefix("--") { usage() }
    path = argv[i]
  }
  i += 1
}
guard !path.isEmpty else { usage() }

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
  fail("无法读取图片: \(path)", 3)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = fast ? .fast : .accurate
request.usesLanguageCorrection = !fast
request.recognitionLanguages = langs

do {
  try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
} catch {
  fail("OCR 失败: \(error)", 4)
}

struct Line: Codable {
  let text: String
  let confidence: Double
  let x: Double
  let y: Double
  let width: Double
  let height: Double
}

// Vision 的 boundingBox 原点在左下;这里转成「原点左上」的归一化坐标
let lines: [Line] = (request.results ?? [])
  .compactMap { obs -> Line? in
    guard let c = obs.topCandidates(1).first, c.confidence >= minConfidence else { return nil }
    let b = obs.boundingBox
    return Line(text: c.string,
                confidence: Double(c.confidence),
                x: Double(b.origin.x),
                y: Double(1 - b.origin.y - b.size.height),
                width: Double(b.size.width),
                height: Double(b.size.height))
  }
  .sorted { $0.y < $1.y }

if json {
  let enc = JSONEncoder()
  enc.outputFormatting = [.prettyPrinted, .sortedKeys]
  guard let data = try? enc.encode(lines) else { fail("JSON 编码失败", 5) }
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write(Data("\n".utf8))
} else {
  for l in lines { print(l.text) }
}
