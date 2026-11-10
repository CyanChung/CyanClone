import SwiftUI

// MARK: - 底栏彩蛋的礼花

/// 第 1、3、5、7、9… 次点 C 的那一下，「星漢燦爛」浮现的同时，在字四周炸一小圈礼花：
/// 细碎的✦、小圆点和几道短光尾，从字的边缘向外飞散、闪烁，很快就散掉。
///
/// 粒子的位置只跟时间有关（`TimelineView` 推进），没有状态残留，所以每次点击都从头播一遍；
/// `seed` 换一次，角度、远近、配色也跟着换，不会两次一样。
struct SparkleBurst: View {
    private let sparks: [SparkleField.Spark]
    @State private var started = Date()

    /// 等字的淡入走出来一点点再炸，别抢在字前面
    private static let leadIn: Double = 0.12

    init(seed: Int) {
        // 粒子只在建视图时算一次：TimelineView 每帧重画，不能每帧都重新撒一遍
        self.sparks = SparkleField.Spark.burst(seed: seed)
        _started = State(initialValue: Date())
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            SparkleField(sparks: sparks,
                         time: timeline.date.timeIntervalSince(started) - Self.leadIn)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 某一时刻的礼花

/// 纯函数式的画面：给定 seed 和时间，就画出那一刻的礼花。
/// `SparkleBurst` 用 TimelineView 往里喂时间，排版预览稿直接喂固定时刻。
struct SparkleField: View {
    var time: Double

    private let sparks: [Spark]

    init(sparks: [Spark], time: Double) {
        self.time = time
        self.sparks = sparks
    }

    /// 预览稿用：直接给种子，按固定时刻画一张
    init(seed: Int, time: Double) {
        self.init(sparks: Spark.burst(seed: seed), time: time)
    }

    /// 粒子最长寿命，超过就整片不再画
    private static let lifespan: Double = 1.6

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // 字刚冒出来那一下，先亮一小片暖光，再散开
                flash(in: size)
                if time > 0 && time < Self.lifespan {
                    ForEach(sparks) { spark in
                        particle(spark, at: time, in: size)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
    }

    // MARK: 起手的一团柔光

    @ViewBuilder
    private func flash(in size: CGSize) -> some View {
        let k = max(0, 1 - time / 0.42)
        if k > 0.01 {
            let w = size.width + 44
            let h = size.height + 26
            Ellipse()
                .fill(RadialGradient(
                    colors: [palette[0].opacity(0.20 * pow(k, 1.8)), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: max(w, h) * 0.46))
                .frame(width: w, height: h)
                .blur(radius: 4)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }

    // MARK: 画一颗粒子

    @ViewBuilder
    private func particle(_ spark: Spark, at time: Double, in size: CGSize) -> some View {
        let p = min(max((time - spark.delay) / spark.life, 0), 1)
        let ease = CGFloat(1 - pow(1 - p, 2.2))        // 先快后慢，像真的炸开
        let alpha = opacity(spark, p)

        if alpha > 0.012 {
            // 出发点在字的边缘，方向朝外，所以粒子是「从字里往外炸」，不是围成一圈
            let (origin, normal) = borderPoint(spark.t, in: size)
            let ang = atan2(normal.y, normal.x) + spark.spread
            let ux = cos(ang), uy = sin(ang)
            let travel = spark.reach * ease
            let start = CGPoint(x: origin.x + normal.x * 3.5, y: origin.y + normal.y * 3.5)

            let x = start.x + CGFloat(ux) * travel - CGFloat(uy) * spark.curl * ease
            let y = start.y + CGFloat(uy) * travel + CGFloat(ux) * spark.curl * ease
                    - spark.rise * CGFloat(p * p) * 5

            let tone = palette[spark.tone % palette.count]
            let grow = 0.5 + 0.5 * min(1, p / 0.18)
            let shrink = 1 - 0.32 * max(0, (p - 0.55) / 0.45)
            let s = spark.size * CGFloat(grow * shrink)

            Group {
                switch spark.kind {
                case .star:
                    SparkleShape()
                        .fill(tone.opacity(alpha))
                        .frame(width: s, height: s)
                        .rotationEffect(.radians(spark.still
                                                  ? spark.spin + p * spark.turn
                                                  : ang + .pi / 2 + spark.spin + p * spark.turn))
                        .shadow(color: tone.opacity(alpha * 0.45), radius: s * 0.35)

                case .dot:
                    Circle()
                        .fill(tone.opacity(alpha * 0.85))
                        .frame(width: s, height: s)

                case .streak:
                    // 一小段光尾，落在粒子飞出去的那条线上、略微拖在后面
                    Capsule()
                        .fill(tone.opacity(alpha * 0.80))
                        .frame(width: s * 1.9, height: max(1, s * 0.16))
                        .rotationEffect(.radians(ang))
                        .offset(x: -CGFloat(ux) * s * 0.85,
                                y: -CGFloat(uy) * s * 0.85)
                }
            }
            .position(x: x, y: y)
        }
    }

    /// 一颗粒子在 p（0→1）处的不透明度：
    /// 飞出去的那批越飞越淡；留在字边上的几颗一亮一暗地闪。
    private func opacity(_ spark: Spark, _ p: Double) -> Double {
        let fadeIn = min(1, p / 0.12)
        let fadeOut = pow(max(0, 1 - max(0, (p - 0.26) / 0.74)), 1.65)
        if spark.still {
            let pulse = 0.18 + 0.82 * abs(sin(p * 2.6 * Double.pi + spark.phase))
            return spark.alpha * fadeIn * fadeOut * pulse * 0.92
        }
        let twinkle = 0.80 + 0.20 * abs(sin(p * 8.5 + spark.phase))
        return spark.alpha * fadeIn * fadeOut * twinkle
    }

    /// 沿字的外框走一圈：给 0…1 的位置，还回那一点和它的朝外法线
    private func borderPoint(_ t: Double, in size: CGSize) -> (CGPoint, CGPoint) {
        let w = size.width, h = size.height
        let total = 2 * (w + h)
        guard total > 0 else { return (CGPoint(x: 0, y: 0), CGPoint(x: 0, y: -1)) }

        var d = CGFloat(t.truncatingRemainder(dividingBy: 1)) * total
        if d < w { return (CGPoint(x: d, y: 0), CGPoint(x: 0, y: -1)) }
        d -= w
        if d < h { return (CGPoint(x: w, y: d), CGPoint(x: 1, y: 0)) }
        d -= h
        if d < w { return (CGPoint(x: w - d, y: h), CGPoint(x: 0, y: 1)) }
        d -= w
        return (CGPoint(x: 0, y: h - d), CGPoint(x: -1, y: 0))
    }

    /// 深色底用亮金 / 奶白，浅色底压深一点，免得在浅灰侧栏上糊成一片
    private var palette: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 1.00, green: 0.85, blue: 0.47),
                Color(red: 0.99, green: 0.72, blue: 0.27),
                Color(red: 1.00, green: 0.97, blue: 0.87)
            ]
        }
        return [
            Color(red: 0.87, green: 0.56, blue: 0.10),
            Color(red: 0.95, green: 0.68, blue: 0.18),
            Color(red: 0.76, green: 0.47, blue: 0.11)
        ]
    }
}

// MARK: - 一颗粒子的参数

extension SparkleField {
    struct Spark: Identifiable {
        enum Kind {
            case star
            case dot
            case streak
        }

        let id: Int
        let t: Double          // 在字框边缘上的位置（0…1）
        let spread: Double     // 偏离法线的角度
        let reach: CGFloat     // 往外飞多远
        let size: CGFloat
        let delay: Double
        let life: Double
        let alpha: Double
        let rise: CGFloat      // 稍微往上飘一点
        let spin: Double
        let turn: Double       // 边飞边转
        let curl: CGFloat      // 轻微侧偏，别全是直线
        let phase: Double
        let tone: Int
        let kind: Kind
        var still: Bool = false    // true = 不飞，只在字边上闪

        /// 八簇「亮星 + 短光尾 + 碎点」+ 几颗原地闪的星。
        /// 用黄金比错开，看着随机但在字框上分布均匀；同一个 seed 永远是同一把。
        static func burst(seed: Int) -> [Spark] {
            var rng = SeededRandom(seed: seed)
            let jets = 7
            let stills = 8
            var out: [Spark] = []
            out.reserveCapacity(jets * 3 + stills)
            var id = 0

            for j in 0..<jets {
                let t = (Double(j) * 0.618 + 0.13).truncatingRemainder(dividingBy: 1)
                    + Double.random(in: -0.02...0.02, using: &rng)
                let spread = Double.random(in: -0.13...0.13, using: &rng)
                let delay = Double.random(in: 0...0.07, using: &rng)

                // 同一簇里的三颗：主星最远，光尾在中间，碎点贴着字边
                for k in 0..<3 {
                    let kind: Kind = k == 0 ? .star : (k == 1 ? .streak : .dot)
                    let size: CGFloat
                    switch kind {
                    case .star:   size = CGFloat(Double.random(in: 5.6...9.0, using: &rng))
                    case .streak: size = CGFloat(Double.random(in: 4.5...7.0, using: &rng))
                    case .dot:    size = CGFloat(Double.random(in: 1.8...3.0, using: &rng))
                    }
                    let reach: CGFloat
                    switch k {
                    case 0:  reach = CGFloat(Double.random(in: 11...18, using: &rng))
                    case 1:  reach = CGFloat(Double.random(in: 4...9, using: &rng))
                    default: reach = CGFloat(Double.random(in: 1...3, using: &rng))
                    }

                    out.append(Spark(
                        id: id,
                        t: t + Double.random(in: -0.012...0.012, using: &rng),
                        spread: spread + Double.random(in: -0.07...0.07, using: &rng),
                        reach: reach,
                        size: size,
                        delay: delay + Double.random(in: 0...0.10, using: &rng),
                        life: Double.random(in: 0.82...1.12, using: &rng),
                        alpha: Double.random(in: 0.82...1.0, using: &rng),
                        rise: CGFloat(Double.random(in: 0.1...0.7, using: &rng)),
                        spin: Double.random(in: -0.22...0.22, using: &rng),
                        turn: Double.random(in: -0.5...0.5, using: &rng),
                        curl: CGFloat(Double.random(in: -2.5...2.5, using: &rng)),
                        phase: Double.random(in: 0...(2 * Double.pi), using: &rng),
                        tone: Int.random(in: 0...2, using: &rng),
                        kind: kind))
                    id += 1
                }
            }

            // 贴着字边一亮一暗的那几颗，负责「闪」
            for j in 0..<stills {
                let t = (Double(j) * 0.618 + 0.55).truncatingRemainder(dividingBy: 1)
                    + Double.random(in: -0.02...0.02, using: &rng)
                out.append(Spark(
                    id: id,
                    t: t,
                    spread: Double.random(in: -0.25...0.25, using: &rng),
                    reach: CGFloat(Double.random(in: 0.5...3, using: &rng)),
                    size: CGFloat(Double.random(in: 4.5...6.8, using: &rng)),
                    delay: Double.random(in: 0.02...0.20, using: &rng),
                    life: Double.random(in: 1.0...1.45, using: &rng),
                    alpha: Double.random(in: 0.80...1.0, using: &rng),
                    rise: 0,
                    spin: Double.random(in: 0...(2 * Double.pi), using: &rng),
                    turn: Double.random(in: -0.5...0.5, using: &rng),
                    curl: 0,
                    phase: Double.random(in: 0...(2 * Double.pi), using: &rng),
                    tone: Int.random(in: 0...2, using: &rng),
                    kind: .star,
                    still: true))
                id += 1
            }

            return out
        }
    }
}

// MARK: - 四角星（✨ 那种瘦长带凹口的）

struct SparkleShape: Shape {
    var thinness: CGFloat = 0.18

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * thinness

        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y),
                       control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r),
                       control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y),
                       control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r),
                       control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

// MARK: - 可复现的随机数

/// 礼花参数要"随机但不跳变"：视图重算多少次，同一个 seed 都得是同一把。
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        var s = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15
        s = s &+ 0x2545_F491_4F6C_DD1D
        if s == 0 { s = 0x1234_5678_9ABC_DEF0 }
        state = s
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
