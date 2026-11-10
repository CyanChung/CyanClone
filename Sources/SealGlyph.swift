import SwiftUI

// MARK: - 小篆字形（等粗铁线）
//
// 骨架取自《说文》系统的篆文：单字先栅格化成 1200px，取中轴骨架，
// 去掉木刻的双钩毛刺、把近横近竖的笔画拉正，再按玉箸笔法统一笔宽、
// 圆头收笔重画一遍——所以放大到任何尺寸都是干净的等粗线，不会发毛。
// 「燦」「爛」两字刻本原字潦草，改由「火＋粲」「火＋闌」两个部件重新组织。
// 坐标空间：高 1000，x 以字身中线为 0。

enum SealGlyph {
    struct Glyph {
        /// 字身宽高比
        var aspect: CGFloat
        /// 视觉配重（笔画总长不同，按面积补正，让四个字看起来一样重）
        var optical: CGFloat
        /// 墨色浓淡：笔画密的字（燦、爛）稍稍减笔，免得糊成一团
        var ink: CGFloat = 1
        var polys: [[CGPoint]]
    }

    /// 星 · 日＋生，小篆省体
    static let xing = Glyph(aspect: 0.662, optical: 1.245, polys: [
        [CGPoint(x: -298.8, y: 298.8), CGPoint(x: -217.6, y: 298.7), CGPoint(x: -140.5, y: 295.5), CGPoint(x: -86.9, y: 296.6), CGPoint(x: -46.5, y: 298.8), CGPoint(x: -28.6, y: 298.8)],
        [CGPoint(x: -45.2, y: 486.9), CGPoint(x: -55.8, y: 489.2), CGPoint(x: -74.2, y: 490.5), CGPoint(x: -148.9, y: 493.7), CGPoint(x: -227.0, y: 493.0), CGPoint(x: -246.4, y: 494.3), CGPoint(x: -259.5, y: 496.4)],
        [CGPoint(x: -239.3, y: -308.3), CGPoint(x: -241.2, y: -332.6), CGPoint(x: -240.4, y: -353.9), CGPoint(x: -237.0, y: -377.8), CGPoint(x: -231.0, y: -401.2)],
        [CGPoint(x: -38.1, y: 127.4), CGPoint(x: -34.8, y: 106.8), CGPoint(x: -32.9, y: 89.1), CGPoint(x: -31.5, y: 16.2), CGPoint(x: -28.6, y: -10.7)],
        [CGPoint(x: -45.2, y: -496.4), CGPoint(x: -3.5, y: -499.8), CGPoint(x: 20.7, y: -500.0), CGPoint(x: 69.1, y: -498.8), CGPoint(x: 90.1, y: -497.1), CGPoint(x: 128.6, y: -490.5)],
        [CGPoint(x: 206.0, y: -225.0), CGPoint(x: 213.7, y: -289.3), CGPoint(x: 215.0, y: -312.9), CGPoint(x: 213.2, y: -363.4), CGPoint(x: 210.9, y: -380.8), CGPoint(x: 207.1, y: -401.2)],
        [CGPoint(x: 331.0, y: 494.0), CGPoint(x: 296.2, y: 494.8), CGPoint(x: 260.8, y: 493.8), CGPoint(x: 213.3, y: 495.2), CGPoint(x: 174.3, y: 495.2), CGPoint(x: 123.5, y: 494.0), CGPoint(x: 66.6, y: 494.6), CGPoint(x: 45.9, y: 494.0), CGPoint(x: 10.5, y: 491.4), CGPoint(x: -0.9, y: 489.3), CGPoint(x: -16.1, y: 483.1), CGPoint(x: -23.0, y: 478.6), CGPoint(x: -28.6, y: 473.8)],
        [CGPoint(x: 131.0, y: -142.9), CGPoint(x: 113.4, y: -138.7), CGPoint(x: 96.2, y: -136.4), CGPoint(x: 27.8, y: -134.2), CGPoint(x: -10.4, y: -131.4), CGPoint(x: -25.1, y: -131.2), CGPoint(x: -63.3, y: -133.9), CGPoint(x: -118.8, y: -141.6), CGPoint(x: -139.3, y: -145.2)],
        [CGPoint(x: -25.0, y: 304.8), CGPoint(x: 1.4, y: 299.8), CGPoint(x: 39.8, y: 296.4), CGPoint(x: 75.7, y: 294.6), CGPoint(x: 144.9, y: 293.2), CGPoint(x: 205.0, y: 293.7), CGPoint(x: 252.4, y: 289.3)],
        [CGPoint(x: -27.4, y: 138.1), CGPoint(x: 37.2, y: 127.0), CGPoint(x: 54.4, y: 123.1), CGPoint(x: 63.1, y: 120.2)],
        [CGPoint(x: -261.9, y: 497.6), CGPoint(x: -280.4, y: 499.4), CGPoint(x: -298.3, y: 499.6), CGPoint(x: -317.9, y: 497.3), CGPoint(x: -331.0, y: 494.0)],
        [CGPoint(x: -129.8, y: -479.8), CGPoint(x: -89.1, y: -490.0), CGPoint(x: -71.4, y: -492.7), CGPoint(x: -47.6, y: -495.2)],
        [CGPoint(x: -39.3, y: 128.6), CGPoint(x: -98.8, y: 119.9), CGPoint(x: -115.7, y: 115.9), CGPoint(x: -131.0, y: 110.7)],
        [CGPoint(x: -28.6, y: 297.6), CGPoint(x: -28.6, y: 139.3)],
        [CGPoint(x: 110.7, y: -321.4), CGPoint(x: 42.0, y: -321.9), CGPoint(x: -58.4, y: -315.9), CGPoint(x: -127.4, y: -315.5)],
        [CGPoint(x: -28.0, y: 306.0), CGPoint(x: -28.0, y: 472.6)],
    ])

    /// 漢 · 水＋堇
    static let han = Glyph(aspect: 0.846, optical: 1.093, polys: [
        [CGPoint(x: 310.4, y: -359.8), CGPoint(x: 310.4, y: -429.9)],
        [CGPoint(x: 210.8, y: -201.9), CGPoint(x: 226.1, y: -199.2), CGPoint(x: 245.8, y: -197.4), CGPoint(x: 345.8, y: -197.3), CGPoint(x: 366.4, y: -196.0), CGPoint(x: 384.3, y: -193.0)],
        [CGPoint(x: 304.2, y: -495.6), CGPoint(x: 309.2, y: -472.7), CGPoint(x: 314.2, y: -435.5)],
        [CGPoint(x: 205.2, y: -82.9), CGPoint(x: 208.4, y: -65.1), CGPoint(x: 210.2, y: -47.9), CGPoint(x: 212.5, y: 38.7), CGPoint(x: 216.4, y: 91.8)],
        [CGPoint(x: 179.6, y: -319.8), CGPoint(x: 215.2, y: -309.8)],
        [CGPoint(x: -137.4, y: -47.3), CGPoint(x: -142.6, y: -12.0), CGPoint(x: -143.9, y: 18.0), CGPoint(x: -143.6, y: 84.8), CGPoint(x: -140.7, y: 141.8)],
        [CGPoint(x: -94.0, y: -318.7), CGPoint(x: -90.8, y: -333.9), CGPoint(x: -90.1, y: -353.5), CGPoint(x: -94.0, y: -400.7), CGPoint(x: -96.6, y: -416.0), CGPoint(x: -99.6, y: -426.6)],
        [CGPoint(x: 423.2, y: 475.5), CGPoint(x: 410.4, y: 472.8), CGPoint(x: 391.4, y: 471.0), CGPoint(x: 328.7, y: 471.0), CGPoint(x: 257.3, y: 468.3), CGPoint(x: 237.7, y: 465.2), CGPoint(x: 223.0, y: 460.0)],
        [CGPoint(x: 219.7, y: 330.4), CGPoint(x: 58.4, y: 330.4)],
        [CGPoint(x: 29.5, y: 466.6), CGPoint(x: 42.3, y: 469.2), CGPoint(x: 61.5, y: 471.6), CGPoint(x: 91.2, y: 472.4), CGPoint(x: 171.8, y: 471.3), CGPoint(x: 195.1, y: 469.0), CGPoint(x: 213.0, y: 465.5)],
        [CGPoint(x: -254.2, y: -151.8), CGPoint(x: -260.7, y: -111.2), CGPoint(x: -263.9, y: -69.9), CGPoint(x: -264.4, y: -49.2), CGPoint(x: -262.6, y: 28.4), CGPoint(x: -256.9, y: 105.4), CGPoint(x: -249.6, y: 157.7), CGPoint(x: -237.5, y: 233.0)],
        [CGPoint(x: 120.7, y: -409.9), CGPoint(x: 49.5, y: -409.9)],
        [CGPoint(x: -366.5, y: 240.8), CGPoint(x: -373.2, y: 209.7)],
        [CGPoint(x: 134.0, y: -427.7), CGPoint(x: 310.9, y: -427.7)],
        [CGPoint(x: 185.2, y: 106.2), CGPoint(x: 208.6, y: 96.2)],
        [CGPoint(x: -362.1, y: 248.6), CGPoint(x: -362.1, y: 288.7)],
        [CGPoint(x: -216.4, y: -280.9), CGPoint(x: -211.9, y: -304.6), CGPoint(x: -210.4, y: -322.7), CGPoint(x: -210.8, y: -340.9), CGPoint(x: -213.0, y: -374.3)],
        [CGPoint(x: -337.6, y: -294.2), CGPoint(x: -335.6, y: -309.8), CGPoint(x: -335.5, y: -326.8), CGPoint(x: -337.5, y: -344.1), CGPoint(x: -340.9, y: -362.1)],
        [CGPoint(x: -119.6, y: 228.6), CGPoint(x: -130.9, y: 191.0), CGPoint(x: -135.4, y: 170.5), CGPoint(x: -139.6, y: 144.0)],
        [CGPoint(x: 131.8, y: -413.2), CGPoint(x: 136.6, y: -395.1), CGPoint(x: 141.6, y: -357.5), CGPoint(x: 145.2, y: -344.3)],
        [CGPoint(x: 371.0, y: 327.6), CGPoint(x: 355.9, y: 324.5), CGPoint(x: 336.2, y: 323.0), CGPoint(x: 255.2, y: 324.5), CGPoint(x: 225.3, y: 324.2)],
        [CGPoint(x: 220.2, y: 324.2), CGPoint(x: 220.2, y: 240.8)],
        [CGPoint(x: 247.5, y: 107.3), CGPoint(x: 217.5, y: 92.9)],
        [CGPoint(x: 375.4, y: -112.9), CGPoint(x: 379.3, y: -123.1), CGPoint(x: 382.2, y: -138.2), CGPoint(x: 384.3, y: -191.9)],
        [CGPoint(x: -377.1, y: -15.0), CGPoint(x: -377.1, y: 48.4)],
        [CGPoint(x: 221.9, y: 330.9), CGPoint(x: 221.9, y: 460.0)],
        [CGPoint(x: 409.9, y: -433.3), CGPoint(x: 315.4, y: -433.3)],
        [CGPoint(x: 385.4, y: -194.1), CGPoint(x: 388.2, y: -207.7), CGPoint(x: 389.3, y: -221.3), CGPoint(x: 388.6, y: -236.2), CGPoint(x: 386.5, y: -245.3)],
        [CGPoint(x: 276.4, y: -322.0), CGPoint(x: 223.0, y: -313.1)],
        [CGPoint(x: 206.3, y: -84.0), CGPoint(x: 293.9, y: -86.9), CGPoint(x: 311.5, y: -88.5), CGPoint(x: 332.0, y: -91.8)],
        [CGPoint(x: -382.1, y: 50.6), CGPoint(x: -386.1, y: 79.9), CGPoint(x: -386.8, y: 94.7), CGPoint(x: -386.5, y: 109.7), CGPoint(x: -383.1, y: 154.6), CGPoint(x: -374.3, y: 207.5)],
        [CGPoint(x: 132.9, y: -424.4), CGPoint(x: 130.6, y: -437.3), CGPoint(x: 127.9, y: -474.1), CGPoint(x: 125.5, y: -487.2), CGPoint(x: 121.8, y: -500.0)],
        [CGPoint(x: 213.6, y: -308.7), CGPoint(x: 213.6, y: -203.0)],
        [CGPoint(x: 51.7, y: -195.2), CGPoint(x: 55.6, y: -185.1), CGPoint(x: 66.2, y: -170.1), CGPoint(x: 78.9, y: -157.3), CGPoint(x: 90.7, y: -148.3), CGPoint(x: 103.7, y: -141.5), CGPoint(x: 117.9, y: -136.8), CGPoint(x: 138.0, y: -132.4), CGPoint(x: 156.3, y: -130.7)],
    ])

    /// 燦 · 火＋粲
    static let can = Glyph(aspect: 0.743, optical: 0.891, ink: 0.79, polys: [
        [CGPoint(x: 170.6, y: 44.8), CGPoint(x: 150.7, y: 44.8)],
        [CGPoint(x: -267.2, y: 209.5), CGPoint(x: -250.2, y: 223.4)],
        [CGPoint(x: -101.0, y: -45.3), CGPoint(x: -101.0, y: 466.2)],
        [CGPoint(x: 316.9, y: 139.8), CGPoint(x: 318.5, y: 150.6), CGPoint(x: 319.1, y: 166.0), CGPoint(x: 316.3, y: 216.5), CGPoint(x: 316.5, y: 240.5), CGPoint(x: 326.9, y: 365.1), CGPoint(x: 331.8, y: 412.4)],
        [CGPoint(x: -32.3, y: -390.5), CGPoint(x: -18.9, y: -391.9), CGPoint(x: 27.8, y: -394.0), CGPoint(x: 45.3, y: -393.8), CGPoint(x: 54.2, y: -392.5)],
        [CGPoint(x: 146.8, y: -399.5), CGPoint(x: 179.6, y: -401.5), CGPoint(x: 200.5, y: -401.6), CGPoint(x: 239.6, y: -399.9), CGPoint(x: 272.1, y: -396.5)],
        [CGPoint(x: -34.3, y: -500.0), CGPoint(x: -34.1, y: -486.9), CGPoint(x: -37.6, y: -449.7), CGPoint(x: -38.3, y: -428.4), CGPoint(x: -37.4, y: -405.1), CGPoint(x: -35.3, y: -389.6)],
        [CGPoint(x: -192.5, y: 419.4), CGPoint(x: -204.5, y: 390.5)],
        [CGPoint(x: 314.9, y: -277.1), CGPoint(x: 308.3, y: -280.4), CGPoint(x: 297.7, y: -283.7), CGPoint(x: 265.2, y: -291.0)],
        [CGPoint(x: 253.2, y: -294.0), CGPoint(x: 220.9, y: -297.9), CGPoint(x: 194.3, y: -299.3), CGPoint(x: 173.7, y: -298.6), CGPoint(x: 144.8, y: -295.9), CGPoint(x: 124.9, y: -295.0)],
        [CGPoint(x: -301.0, y: 263.2), CGPoint(x: -296.0, y: 245.3)],
        [CGPoint(x: 347.8, y: 44.3), CGPoint(x: 323.6, y: 46.0), CGPoint(x: 312.4, y: 45.7), CGPoint(x: 305.0, y: 44.3)],
        [CGPoint(x: 314.9, y: -276.1), CGPoint(x: 314.9, y: -246.3)],
        [CGPoint(x: -80.1, y: -239.3), CGPoint(x: -87.6, y: -204.5), CGPoint(x: -90.5, y: -178.1), CGPoint(x: -91.9, y: -106.6), CGPoint(x: -90.0, y: -47.3)],
        [CGPoint(x: 309.5, y: -110.9), CGPoint(x: 309.5, y: 43.3)],
        [CGPoint(x: -219.4, y: 346.8), CGPoint(x: -230.3, y: 307.0)],
        [CGPoint(x: 36.3, y: 380.6), CGPoint(x: 36.3, y: -44.3)],
        [CGPoint(x: 28.4, y: -45.8), CGPoint(x: -89.1, y: -45.8)],
        [CGPoint(x: 136.3, y: 378.6), CGPoint(x: 136.3, y: 358.7)],
        [CGPoint(x: -208.5, y: 380.6), CGPoint(x: -216.4, y: 354.7)],
        [CGPoint(x: -349.8, y: -345.8), CGPoint(x: -344.5, y: -229.8), CGPoint(x: -342.6, y: -119.1), CGPoint(x: -343.6, y: -71.4), CGPoint(x: -348.0, y: -9.3), CGPoint(x: -349.8, y: 29.4)],
        [CGPoint(x: 364.7, y: -154.7), CGPoint(x: 360.7, y: -167.7)],
        [CGPoint(x: 235.3, y: -124.9), CGPoint(x: 231.1, y: -93.0), CGPoint(x: 229.3, y: -48.9), CGPoint(x: 229.4, y: 19.7), CGPoint(x: 231.0, y: 36.8), CGPoint(x: 233.3, y: 45.3)],
        [CGPoint(x: -231.3, y: 305.0), CGPoint(x: -238.3, y: 272.1)],
        [CGPoint(x: -256.2, y: -481.1), CGPoint(x: -254.6, y: -470.3), CGPoint(x: -253.4, y: -451.8), CGPoint(x: -253.3, y: -397.7), CGPoint(x: -261.1, y: -17.5), CGPoint(x: -262.8, y: 110.9), CGPoint(x: -268.2, y: 208.5)],
        [CGPoint(x: 325.9, y: -353.7), CGPoint(x: 325.9, y: -285.1)],
        [CGPoint(x: 229.4, y: 47.3), CGPoint(x: 172.6, y: 47.3)],
        [CGPoint(x: 231.3, y: 49.3), CGPoint(x: 231.3, y: 500.0)],
        [CGPoint(x: 143.8, y: 43.3), CGPoint(x: 143.8, y: -65.2)],
        [CGPoint(x: 146.8, y: 48.2), CGPoint(x: 110.0, y: 48.2)],
        [CGPoint(x: 45.8, y: 461.2), CGPoint(x: 45.8, y: 382.6)],
        [CGPoint(x: -36.3, y: -388.6), CGPoint(x: -36.3, y: -278.1)],
        [CGPoint(x: -0.5, y: -267.2), CGPoint(x: -15.9, y: -272.3), CGPoint(x: -36.3, y: -277.1)],
        [CGPoint(x: -59.2, y: -269.2), CGPoint(x: -39.3, y: -276.1)],
        [CGPoint(x: 21.4, y: -238.3), CGPoint(x: 25.1, y: -225.6), CGPoint(x: 27.9, y: -212.5), CGPoint(x: 30.3, y: -186.1), CGPoint(x: 31.3, y: -141.3), CGPoint(x: 29.4, y: -46.3)],
        [CGPoint(x: 234.3, y: 46.3), CGPoint(x: 303.0, y: 46.3)],
        [CGPoint(x: 136.8, y: -200.5), CGPoint(x: 187.5, y: -198.2), CGPoint(x: 208.3, y: -198.7), CGPoint(x: 232.3, y: -200.5)],
        [CGPoint(x: -153.7, y: 42.3), CGPoint(x: -159.3, y: -19.2), CGPoint(x: -161.6, y: -82.0), CGPoint(x: -162.7, y: -157.3), CGPoint(x: -162.7, y: -269.1), CGPoint(x: -159.7, y: -340.8)],
        [CGPoint(x: 137.8, y: 356.7), CGPoint(x: 142.6, y: 282.3), CGPoint(x: 144.2, y: 240.4), CGPoint(x: 145.4, y: 162.5), CGPoint(x: 144.8, y: 141.8)],
    ])

    /// 爛 · 火＋門＋柬
    static let lan = Glyph(aspect: 0.86, optical: 0.891, ink: 0.77, polys: [
        [CGPoint(x: -86.4, y: -425.9), CGPoint(x: -60.7, y: -425.9)],
        [CGPoint(x: 130.8, y: 0.0), CGPoint(x: 56.9, y: 0.0)],
        [CGPoint(x: 413.1, y: 402.9), CGPoint(x: 413.1, y: 370.9)],
        [CGPoint(x: 132.0, y: 0.9), CGPoint(x: 132.0, y: 147.3)],
        [CGPoint(x: -313.8, y: -311.1), CGPoint(x: -314.6, y: -254.6), CGPoint(x: -313.8, y: -146.7), CGPoint(x: -315.4, y: -29.9), CGPoint(x: -314.7, y: 5.9), CGPoint(x: -312.3, y: 56.3)],
        [CGPoint(x: 390.9, y: -207.1), CGPoint(x: 289.7, y: -207.1)],
        [CGPoint(x: 67.8, y: -334.5), CGPoint(x: 68.7, y: -325.4), CGPoint(x: 68.8, y: -310.5), CGPoint(x: 66.2, y: -277.3)],
        [CGPoint(x: -137.4, y: -308.5), CGPoint(x: -137.4, y: -363.1)],
        [CGPoint(x: -142.5, y: -199.3), CGPoint(x: -144.2, y: 113.3), CGPoint(x: -145.2, y: 179.2), CGPoint(x: -149.5, y: 289.4)],
        [CGPoint(x: -138.6, y: -307.6), CGPoint(x: -114.5, y: -309.4), CGPoint(x: -93.4, y: -312.2), CGPoint(x: 18.8, y: -332.0), CGPoint(x: 40.0, y: -334.2), CGPoint(x: 66.9, y: -335.4)],
        [CGPoint(x: 45.9, y: 143.8), CGPoint(x: 38.1, y: 133.5), CGPoint(x: 31.0, y: 122.3), CGPoint(x: 22.3, y: 103.6), CGPoint(x: 18.9, y: 92.2), CGPoint(x: 17.5, y: 83.7), CGPoint(x: 16.9, y: 70.4), CGPoint(x: 17.9, y: 63.3)],
        [CGPoint(x: -205.6, y: -6.1), CGPoint(x: -201.7, y: 17.3)],
        [CGPoint(x: 214.1, y: -72.8), CGPoint(x: 202.5, y: -70.1), CGPoint(x: 188.0, y: -67.8), CGPoint(x: 137.0, y: -65.0)],
        [CGPoint(x: 135.5, y: 148.6), CGPoint(x: 213.3, y: 148.6)],
        [CGPoint(x: 288.1, y: -211.4), CGPoint(x: 266.4, y: -211.4)],
        [CGPoint(x: 5.5, y: 321.5), CGPoint(x: 0.8, y: 348.4)],
        [CGPoint(x: 420.5, y: 404.7), CGPoint(x: 420.5, y: 473.1)],
        [CGPoint(x: 343.4, y: -422.0), CGPoint(x: 317.0, y: -427.2), CGPoint(x: 298.4, y: -429.1), CGPoint(x: 260.5, y: -429.8), CGPoint(x: 211.5, y: -429.3), CGPoint(x: 190.0, y: -430.7)],
        [CGPoint(x: -207.9, y: -13.0), CGPoint(x: -207.9, y: -31.2)],
        [CGPoint(x: -415.1, y: 2.6), CGPoint(x: -410.9, y: -56.7), CGPoint(x: -410.0, y: -116.8), CGPoint(x: -411.0, y: -155.8), CGPoint(x: -413.5, y: -200.5), CGPoint(x: -419.8, y: -259.1)],
        [CGPoint(x: 11.7, y: 298.1), CGPoint(x: 6.2, y: 319.8)],
        [CGPoint(x: 186.9, y: -331.0), CGPoint(x: 186.9, y: -429.8)],
        [CGPoint(x: -143.2, y: -303.3), CGPoint(x: -143.2, y: -201.0)],
        [CGPoint(x: 84.9, y: -66.3), CGPoint(x: 132.4, y: -66.3)],
        [CGPoint(x: 133.9, y: -171.6), CGPoint(x: 133.9, y: -67.6)],
        [CGPoint(x: 68.6, y: -338.8), CGPoint(x: 68.6, y: -430.7)],
        [CGPoint(x: 133.2, y: -2.6), CGPoint(x: 165.1, y: -0.7), CGPoint(x: 196.7, y: 2.5), CGPoint(x: 206.5, y: 5.3), CGPoint(x: 217.3, y: 11.8), CGPoint(x: 224.8, y: 19.5), CGPoint(x: 231.4, y: 28.8), CGPoint(x: 240.2, y: 43.8), CGPoint(x: 245.0, y: 54.4), CGPoint(x: 247.3, y: 62.6), CGPoint(x: 248.4, y: 73.7), CGPoint(x: 247.7, y: 84.9), CGPoint(x: 245.3, y: 93.6)],
        [CGPoint(x: 65.4, y: -429.8), CGPoint(x: -59.2, y: -429.8)],
        [CGPoint(x: 264.7, y: -214.0), CGPoint(x: 247.7, y: -217.5)],
        [CGPoint(x: 46.7, y: 146.9), CGPoint(x: 130.8, y: 146.9)],
        [CGPoint(x: -141.7, y: -205.8), CGPoint(x: -4.7, y: -205.8)],
        [CGPoint(x: 269.4, y: 441.9), CGPoint(x: 270.5, y: 415.4), CGPoint(x: 269.5, y: 392.0), CGPoint(x: 266.8, y: 368.4), CGPoint(x: 258.5, y: 315.4)],
        [CGPoint(x: -181.4, y: 275.6), CGPoint(x: -168.8, y: 283.2), CGPoint(x: -151.1, y: 290.3)],
        [CGPoint(x: 133.9, y: 453.2), CGPoint(x: 131.4, y: 396.8), CGPoint(x: 133.2, y: 273.1), CGPoint(x: 132.4, y: 221.8)],
        [CGPoint(x: 182.2, y: 224.0), CGPoint(x: 133.2, y: 224.0)],
        [CGPoint(x: 67.8, y: 230.5), CGPoint(x: 79.4, y: 226.9), CGPoint(x: 94.0, y: 223.8), CGPoint(x: 131.6, y: 220.1)],
        [CGPoint(x: 186.1, y: -319.8), CGPoint(x: 390.9, y: -319.8)],
        [CGPoint(x: 188.4, y: -499.1), CGPoint(x: 188.8, y: -488.2), CGPoint(x: 187.3, y: -454.9), CGPoint(x: 187.8, y: -442.4), CGPoint(x: 189.3, y: -431.5)],
        [CGPoint(x: 391.7, y: -205.4), CGPoint(x: 392.4, y: -175.6), CGPoint(x: 391.7, y: -61.7), CGPoint(x: 394.6, y: 180.7), CGPoint(x: 398.2, y: 248.7), CGPoint(x: 409.6, y: 363.1)],
        [CGPoint(x: 133.9, y: -3.5), CGPoint(x: 133.9, y: -64.1)],
        [CGPoint(x: -3.9, y: 350.1), CGPoint(x: -3.9, y: 435.9)],
        [CGPoint(x: -210.3, y: -32.9), CGPoint(x: -217.1, y: -94.3), CGPoint(x: -219.4, y: -132.8), CGPoint(x: -217.2, y: -219.3), CGPoint(x: -215.0, y: -257.4)],
        [CGPoint(x: 66.9, y: -433.3), CGPoint(x: 66.9, y: -500.0)],
        [CGPoint(x: 185.3, y: -289.4), CGPoint(x: 185.3, y: -329.3)],
        [CGPoint(x: 133.2, y: 219.2), CGPoint(x: 133.2, y: 155.1)],
        [CGPoint(x: -150.3, y: 291.2), CGPoint(x: -152.3, y: 354.4), CGPoint(x: -158.7, y: 449.8), CGPoint(x: -161.5, y: 476.2), CGPoint(x: -165.9, y: 496.5)],
        [CGPoint(x: 393.2, y: -208.0), CGPoint(x: 393.2, y: -308.5)],
        [CGPoint(x: 390.9, y: -366.6), CGPoint(x: 390.9, y: -310.2)],
    ])
    static func glyph(for ch: Character) -> Glyph? {
        switch ch {
        case "星", "曐": return xing
        case "漢", "汉": return han
        case "燦", "灿": return can
        case "爛", "烂": return lan
        default: return nil
        }
    }
}

// MARK: - 排成一行的小篆

/// 一行小篆。默认右起（碑刻习惯）。
///
/// 「古朴」的几件事都做在参数里：
/// · 笔宽厚（默认 76/1000 字高），不是线框字；
/// · 字形修长——纵向拉伸、横向微收，接近秦篆的长方体势；
/// · 起笔略重、行笔中段微鼓、收笔提锋（taper），像写出来而不是画出来；
/// · 字距收紧，四字并立如碑额。
struct SealLine: View {
    var text: String = "星漢燦爛"
    var height: CGFloat = 20          // 字高（点）
    var weight: CGFloat = 80          // 每 1000 字高的笔宽
    var tracking: CGFloat = 0.09      // 字距（相对字高）
    var color: Color = .secondary
    var rightToLeft: Bool = true
    var vStretch: CGFloat = 1.10      // 纵向拉伸（篆书修长）
    var hSquash: CGFloat = 0.97       // 横向收（配合拉伸）
    var taper: CGFloat = 0.14         // 收笔提锋比例（0 为等粗）
    var cap: CGLineCap = .round        // 圆头（玉箸）/ 方头（刻石）
    var simplifyEps: CGFloat = 24      // 简笔阈值（去木刻锯齿）
    var smoothPasses: Int = 3          // 磨圆次数
    var inkBleed: CGFloat = 0.16       // 墨晕强度（拓本洇边）

    private var chars: [Character] {
        rightToLeft ? Array(text.reversed()) : Array(text)
    }

    var body: some View {
        HStack(alignment: .center, spacing: height * tracking) {
            ForEach(Array(chars.enumerated()), id: \.offset) { idx, ch in
                let g = SealGlyph.glyph(for: ch)
                let k = (g?.optical ?? 1) * height          // 字身基准高
                let chH = k * vStretch
                Canvas { ctx, size in
                    guard let g else { return }
                    var c = ctx
                    c.translateBy(x: size.width / 2, y: size.height / 2)
                    c.scaleBy(x: k * hSquash / 1000, y: chH / 1000)

                    // 墨晕：极淡的一层模糊底，像拓本在纸上洇开的边
                    if inkBleed > 0 {
                        c.drawLayer { layer in
                            layer.addFilter(.blur(radius: 10))
                            let halo = StrokeStyle(lineWidth: weight * g.ink * 1.10,
                                                   lineCap: .round, lineJoin: .round)
                            for poly in g.polys where poly.count > 1 {
                                let clean = chaikin(simplify(poly, eps: simplifyEps), passes: smoothPasses)
                                guard clean.count > 1 else { continue }
                                var p = Path()
                                p.move(to: clean[0])
                                for q in clean.dropFirst() { p.addLine(to: q) }
                                layer.stroke(p, with: .color(color.opacity(inkBleed)), style: halo)
                            }
                        }
                    }

                    for (i, poly) in g.polys.enumerated() {
                        strokeInked(poly, in: &c, base: weight * g.ink,
                                    color: color, taper: taper, seed: Double(i) + Double(idx) * 7,
                                    eps: simplifyEps, passes: smoothPasses)
                    }
                }
                .frame(width: k * (g?.aspect ?? 1) * hSquash + weight * k / 1000,
                       height: chH)
            }
        }
    }

    /// 一笔：先去木刻锯齿、磨圆，再按弧长重采样，逐段变宽描出。
    /// 圆头收笔，接缝靠圆帽融合，放大看是一条温润的玉箸线。
    private func strokeInked(_ poly: [CGPoint],
                             in ctx: inout GraphicsContext,
                             base: CGFloat,
                             color: Color,
                             taper: CGFloat,
                             seed: Double,
                             eps: CGFloat,
                             passes: Int) {
        guard poly.count > 1 else { return }

        let clean = chaikin(simplify(poly, eps: eps), passes: passes)
        guard clean.count > 1 else { return }

        // 重采样：每段不超过 ~34 单位，既够平滑又不至于画上千段
        var pts: [CGPoint] = [clean[0]]
        for i in 1..<clean.count {
            let a = clean[i - 1], b = clean[i]
            let dx = b.x - a.x, dy = b.y - a.y
            let d = (dx * dx + dy * dy).squareRoot()
            let n = max(1, Int(d / 34))
            for j in 1...n {
                let t = CGFloat(j) / CGFloat(n)
                pts.append(CGPoint(x: a.x + dx * t, y: a.y + dy * t))
            }
        }
        guard pts.count > 1 else { return }

        var acc: [CGFloat] = [0]
        acc.reserveCapacity(pts.count)
        for i in 1..<pts.count {
            acc.append(acc[i - 1] + ((pts[i].x - pts[i - 1].x) * (pts[i].x - pts[i - 1].x)
                                     + (pts[i].y - pts[i - 1].y) * (pts[i].y - pts[i - 1].y)).squareRoot())
        }
        let total = max(acc.last ?? 1, 0.001)

        // 每笔 ±1.5% 的天然差，避免机械复制感
        let natural = 1 + 0.015 * CGFloat(sin(seed * 1.7))

        func width(at t: CGFloat) -> CGFloat {
            let press = 1 + 0.05 * CGFloat(sin(Double.pi * min(max(t, 0), 1)))  // 中段微鼓
            let lift = 1 - taper * t                                            // 收笔提锋
            return base * natural * press * lift
        }

        for i in 0..<(pts.count - 1) {
            var p = Path()
            p.move(to: pts[i])
            p.addLine(to: pts[i + 1])
            let w = (width(at: acc[i] / total) + width(at: acc[i + 1] / total)) / 2
            ctx.stroke(p, with: .color(color),
                       style: StrokeStyle(lineWidth: w, lineCap: cap, lineJoin: cap == .round ? .round : .miter))
        }
    }

    // MARK: 笔形工具

    /// Ramer–Douglas–Peucker：把木刻的双钩毛刺简掉，只留骨架转折
    private func simplify(_ pts: [CGPoint], eps: CGFloat) -> [CGPoint] {
        guard pts.count > 2, eps > 0 else { return pts }
        var keep = [Bool](repeating: false, count: pts.count)
        keep[0] = true
        keep[pts.count - 1] = true
        var stack: [(Int, Int)] = [(0, pts.count - 1)]
        while let (a, b) = stack.popLast() {
            guard b > a + 1 else { continue }
            let p0 = pts[a], p1 = pts[b]
            let dx = p1.x - p0.x, dy = p1.y - p0.y
            let len = max((dx * dx + dy * dy).squareRoot(), 0.0001)
            var far: CGFloat = -1
            var idx = a
            for i in (a + 1)..<b {
                let d = abs(dy * (pts[i].x - p0.x) - dx * (pts[i].y - p0.y)) / len
                if d > far { far = d; idx = i }
            }
            if far > eps {
                keep[idx] = true
                stack.append((a, idx))
                stack.append((idx, b))
            }
        }
        return pts.enumerated().filter { keep[$0.offset] }.map { $0.element }
    }

    /// Chaikin 割角：把折点磨成圆转
    private func chaikin(_ pts: [CGPoint], passes: Int) -> [CGPoint] {
        guard pts.count > 2, passes > 0 else { return pts }
        var cur = pts
        for _ in 0..<passes {
            var out: [CGPoint] = [cur[0]]
            out.reserveCapacity(cur.count * 2)
            for i in 0..<(cur.count - 1) {
                let a = cur[i], b = cur[i + 1]
                out.append(CGPoint(x: a.x * 0.75 + b.x * 0.25, y: a.y * 0.75 + b.y * 0.25))
                out.append(CGPoint(x: a.x * 0.25 + b.x * 0.75, y: a.y * 0.25 + b.y * 0.75))
            }
            out.append(cur[cur.count - 1])
            cur = out
        }
        return cur
    }
}
