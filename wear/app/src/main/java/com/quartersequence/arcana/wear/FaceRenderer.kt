package com.quartersequence.arcana.wear

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.view.SurfaceHolder
import androidx.wear.watchface.CanvasType
import androidx.wear.watchface.DrawMode
import androidx.wear.watchface.Renderer
import androidx.wear.watchface.WatchState
import androidx.wear.watchface.style.CurrentUserStyleRepository
import java.time.ZonedDateTime
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Draws one Arcana face. Everything is laid out on an 800 × 800 dial, then scaled to the screen. */
class FaceRenderer(
    private val ctx: Context,
    private val id: String,
    surfaceHolder: SurfaceHolder,
    watchState: WatchState,
    repo: CurrentUserStyleRepository,
) : Renderer.CanvasRenderer2<FaceRenderer.Assets>(surfaceHolder, repo, watchState, CanvasType.HARDWARE, 1000L, false) {

    class Assets : Renderer.SharedAssets { override fun onDestroy() {} }
    override suspend fun createSharedAssets() = Assets()

    private val dial: Bitmap? = when (id) {
        "diver" -> R.drawable.dial_diver; "dress" -> R.drawable.dial_dress; "pilot" -> R.drawable.dial_pilot
        "chrono" -> R.drawable.dial_chrono; "champ" -> R.drawable.dial_champ; "turq" -> R.drawable.dial_turq
        else -> null
    }?.let { BitmapFactory.decodeResource(ctx.resources, it) }

    private val bmpPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val bold: Typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    private val mono: Typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
    private val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER; typeface = bold }

    private val QC = intArrayOf(0, c("#939fae"), c("#f67584"), c("#10b562"), c("#5aa4e4"))
    private val HL = c("#ef8a47")
    private val GOLD = c("#e0b556")
    private fun c(s: String) = Color.parseColor(s)
    private fun a(col: Int, alpha: Float) = Color.argb((alpha * 255).toInt(), Color.red(col), Color.green(col), Color.blue(col))

    private val CX = 400f
    private val CY = 400f
    private fun px(r: Float, ang: Double, cx: Float = CX) = cx + r * sin(ang).toFloat()
    private fun py(r: Float, ang: Double, cy: Float = CY) = cy - r * cos(ang).toFloat()

    override fun renderHighlightLayer(canvas: Canvas, bounds: Rect, zonedDateTime: ZonedDateTime, sharedAssets: Assets) {
        renderParameters.highlightLayer?.let { canvas.drawColor(it.backgroundTint) }
    }

    override fun render(canvas: Canvas, bounds: Rect, zonedDateTime: ZonedDateTime, sharedAssets: Assets) {
        val t = zonedDateTime.toInstant().toEpochMilli()
        val ambient = renderParameters.drawMode == DrawMode.AMBIENT
        canvas.drawColor(Color.BLACK)
        canvas.save()
        val s = min(bounds.width(), bounds.height()) / 800f
        canvas.translate(bounds.exactCenterX() - 400f * s, bounds.exactCenterY() - 400f * s)
        canvas.scale(s, s)
        try {
            when {
                id == "digital" -> digital(canvas, t, zonedDateTime, ambient)
                ambient -> ambientAnalog(canvas, t, zonedDateTime)
                else -> analog(canvas, t, zonedDateTime)
            }
        } catch (e: Exception) {
            text.color = Color.WHITE; text.textSize = 40f
            canvas.drawText("%02d:%02d".format(zonedDateTime.hour, zonedDateTime.minute), CX, CY, text)
        }
        canvas.restore()
    }

    // ── analog faces ──
    private fun analog(cv: Canvas, t: Long, now: ZonedDateTime) {
        dial?.let { cv.drawBitmap(it, null, RectF(0f, 0f, 800f, 800f), bmpPaint) }
        when (id) {
            "diver" -> {
                band(cv, t, 320f, 334f, HL, .45f)
                date(cv, now, 548f, 380f, c("#f7f7f2"), c("#141a22"), true)
                sub(cv, t, CX, CY + 168, 62f, "micro", "90 MIN")
                gmtDiver(cv, t)
                diverHands(cv, now)
            }
            "dress" -> {
                band(cv, t, 326f, 342f, c("#b8862f"), .55f)
                date(cv, now, 560f, 380f, Color.WHITE, c("#1f2a3a"), false)
                sub(cv, t, CX, CY + 160, 64f, "micro", "90 MIN", c("#f3eee0"), c("#b9ab88"), c("#b8862f"), .35f, c("#1d3b8f"), c("#6b7280"))
                hands(cv, now, Hand(Shape.DAUPHINE, c("#1d3b8f"), c("#0c1d4a"), c("#1d3b8f"), c("#1d3b8f"), hw = 20f, mw = 15f))
            }
            "pilot" -> {
                band(cv, t, 334f, 350f, HL, .5f)
                date(cv, now, 568f, 380f, c("#0d0f12"), c("#f2f2ee"), false)
                sub(cv, t, CX, CY + 150, 62f, "micro", "90 MIN")
                gmt(cv, t, 330f, HL)
                hands(cv, now, Hand(Shape.SWORD, c("#f2f2ee"), c("#1a1d22"), c("#f2f2ee"), c("#1a1d22"), lume = c("#cfe8b8"), hl = 165f, ml = 262f))
            }
            "chrono" -> {
                band(cv, t, 322f, 334f, HL, .55f)
                val bg = c("#1a1f26"); val rim = c("#7d8794")
                sub(cv, t, CX - 140, CY, 74f, "day", "DAY", bg, rim)
                sub(cv, t, CX + 140, CY, 74f, "m90", "SESSION", bg, rim)
                sub(cv, t, CX, CY + 150, 74f, "micro", "90 MIN", bg, rim)
                hands(cv, now, Hand(Shape.BATON, c("#f6f7f9"), c("#1d232b"), c("#e5484d"), c("#1d232b"), lume = c("#1d232b"), hw = 16f, mw = 12f, hl = 175f, ml = 265f))
            }
            "champ" -> {
                band(cv, t, 308f, 322f, c("#7a5414"), .42f)
                date(cv, now, 548f, 380f, c("#fffdf5"), c("#2a2010"), true)
                sub(cv, t, CX, CY + 158, 60f, "micro", "90 MIN", c("#e9d7a8"), c("#8a6420"), c("#7a5414"), .35f, c("#4a3510"), c("#6b5220"))
                gmt(cv, t, 318f, c("#7a5414"))
                hands(cv, now, Hand(Shape.BATON, c("#f6e2a6"), c("#7a5a1c"), c("#7a5414"), c("#d8b260"), lume = c("#fff6dc"), hw = 18f, mw = 13f))
            }
            "turq" -> turq(cv, t, now)
        }
    }

    /** the four sessions of the trading day as a ring (18:00 NY at the top), the predicted one lit */
    private fun band(cv: Canvas, t: Long, r0: Float, r1: Float, hl: Int, dim: Float) {
        val b = Arc.bounds("day", t); val f = Arc.focus(b[0] + 1000)["day"]
        val ang = { x: Long -> (x - b[0]).toDouble() / (24 * Arc.HOUR) * 2 * PI }
        for (q in 1..4) {
            fill.color = if (q == f) a(hl, .95f) else a(QC[q], dim)
            annulus(cv, CX, CY, r0, r1, ang(b[q - 1]) + .008, ang(b[q]) - .008, fill)
        }
    }

    private fun annulus(cv: Canvas, cx: Float, cy: Float, r0: Float, r1: Float, a0: Double, a1: Double, p: Paint) {
        val st = (a0 * 180 / PI - 90).toFloat(); val sw = ((a1 - a0) * 180 / PI).toFloat()
        val path = Path()
        path.arcTo(RectF(cx - r1, cy - r1, cx + r1, cy + r1), st, sw, true)
        path.arcTo(RectF(cx - r0, cy - r0, cx + r0, cy + r0), st + sw, -sw)
        path.close(); cv.drawPath(path, p)
    }

    /** a sub-dial: the 4 quarters of one cycle, the predicted one lit, a hand at now */
    private fun sub(cv: Canvas, t: Long, cx: Float, cy: Float, R: Float, key: String, label: String,
                    bg: Int = c("#070a0e"), rim: Int = c("#3a4350"), hl: Int = HL, dim: Float = .45f,
                    hand: Int = c("#f2f4f7"), lab: Int = c("#9aa7b8")) {
        val b = Arc.bounds(key, t); val f = Arc.focus(b[0] + 1000)[key]
        val ang = { x: Long -> (x - b[0]).toDouble() / (b[4] - b[0]) * 2 * PI }
        fill.color = bg; cv.drawCircle(cx, cy, R, fill)
        line.color = rim; line.strokeWidth = 2f; cv.drawCircle(cx, cy, R, line)
        for (q in 1..4) {
            fill.color = if (q == f) a(hl, .95f) else a(QC[q], dim)
            annulus(cv, cx, cy, R * .64f, R * .9f, ang(b[q - 1]) + .05, ang(b[q]) - .05, fill)
        }
        val aa = ang(t)
        line.color = hand; line.strokeWidth = 3f
        cv.drawLine(cx, cy, px(R * .72f, aa, cx), py(R * .72f, aa, cy), line)
        fill.color = hand; cv.drawCircle(cx, cy, 4.5f, fill)
        text.color = lab; text.textSize = max(8f, R * .16f); text.letterSpacing = 1f / text.textSize
        cv.drawText(label, cx, cy + R * .42f + text.textSize * .35f, text); text.letterSpacing = 0f
    }

    private fun date(cv: Canvas, now: ZonedDateTime, x: Float, y: Float, bg: Int, fg: Int, day: Boolean) {
        val w = if (day) 118f else 54f
        fill.color = bg; cv.drawRoundRect(RectF(x, y, x + w, y + 40), 4f, 4f, fill)
        line.color = c("#9aa3ad"); line.strokeWidth = 2.5f; line.strokeCap = Paint.Cap.BUTT
        cv.drawRoundRect(RectF(x, y, x + w, y + 40), 4f, 4f, line)
        text.color = fg
        if (day) {
            line.color = c("#b9c0c8"); line.strokeWidth = 2f; cv.drawLine(x + 64, y + 1, x + 64, y + 39, line)
            text.textSize = 21f; cv.drawText(Arc.WD[now.dayOfWeek.value % 7], x + 32, y + 28, text)
            text.textSize = 22f; cv.drawText(now.dayOfMonth.toString(), x + 91, y + 28, text)
        } else { text.textSize = 22f; cv.drawText(now.dayOfMonth.toString(), x + 27, y + 28, text) }
        line.strokeCap = Paint.Cap.ROUND
    }

    /** the GMT hand: where the New York trading day is on the 24-hour scale */
    private fun gmt(cv: Canvas, t: Long, len: Float, col: Int) {
        val b = Arc.bounds("day", t); val aa = (t - b[0]).toDouble() / (24 * Arc.HOUR) * 2 * PI
        line.color = col; line.strokeWidth = 3.5f; line.strokeCap = Paint.Cap.BUTT
        cv.drawLine(CX, CY, px(len - 20, aa), py(len - 20, aa), line); line.strokeCap = Paint.Cap.ROUND
        val p = Path(); p.moveTo(px(len, aa), py(len, aa)); p.lineTo(px(len - 22, aa - .035), py(len - 22, aa - .035)); p.lineTo(px(len - 22, aa + .035), py(len - 22, aa + .035)); p.close()
        fill.color = col; cv.drawPath(p, fill)
    }
    private fun gmtDiver(cv: Canvas, t: Long) {
        val b = Arc.bounds("day", t); val aa = (t - b[0]).toDouble() / (24 * Arc.HOUR) * 2 * PI
        line.color = HL; line.strokeWidth = 4f; line.strokeCap = Paint.Cap.BUTT
        cv.drawLine(CX, CY, px(296f, aa), py(296f, aa), line); line.strokeCap = Paint.Cap.ROUND
        val p = Path(); p.moveTo(px(318f, aa), py(318f, aa)); p.lineTo(px(296f, aa - .035), py(296f, aa - .035)); p.lineTo(px(296f, aa + .035), py(296f, aa + .035)); p.close()
        fill.color = HL; cv.drawPath(p, fill); line.color = c("#5a3010"); line.strokeWidth = 1.5f; cv.drawPath(p, line)
    }

    enum class Shape { SWORD, DAUPHINE, BATON }
    class Hand(val shape: Shape, val fill: Int, val stroke: Int, val sec: Int?, val cap: Int, val lume: Int? = null,
               val hw: Float = 24f, val mw: Float = 17f, val hl: Float = 170f, val ml: Float = 255f, val sl: Float = 275f)

    private fun handPath(aa: Double, len: Float, w: Float, tail: Float, shape: Shape): Path {
        fun pt(r: Float, side: Int) = floatArrayOf(px(r, aa) + side * w / 2 * cos(aa).toFloat(), py(r, aa) + side * w / 2 * sin(aa).toFloat())
        val pts = when (shape) {
            Shape.DAUPHINE -> listOf(floatArrayOf(px(-tail, aa), py(-tail, aa)), pt(len * .12f, -1), floatArrayOf(px(len, aa), py(len, aa)), pt(len * .12f, 1))
            Shape.BATON -> listOf(pt(-tail, -1), pt(len, -1), pt(len, 1), pt(-tail, 1))
            Shape.SWORD -> listOf(floatArrayOf(px(-tail, aa), py(-tail, aa)), pt(0f, -1), pt(len * .8f, -1), floatArrayOf(px(len, aa), py(len, aa)), pt(len * .8f, 1), pt(0f, 1))
        }
        val p = Path(); p.moveTo(pts[0][0], pts[0][1]); for (i in 1 until pts.size) p.lineTo(pts[i][0], pts[i][1]); p.close(); return p
    }
    private fun oneHand(cv: Canvas, aa: Double, len: Float, w: Float, tail: Float, h: Hand) {
        val p = handPath(aa, len, w, tail, h.shape)
        fill.color = h.fill; cv.drawPath(p, fill)
        line.color = h.stroke; line.strokeWidth = 1.5f; line.strokeJoin = Paint.Join.ROUND; cv.drawPath(p, line)
        h.lume?.let { line.color = it; line.strokeWidth = w * .42f; cv.drawLine(px(len * .25f, aa), py(len * .25f, aa), px(len * .75f, aa), py(len * .75f, aa), line) }
    }
    private fun angles(now: ZonedDateTime): Triple<Double, Double, Double> {
        val h = now.hour % 12 + now.minute / 60.0; val m = now.minute + now.second / 60.0
        return Triple(h / 12 * 2 * PI, m / 60 * 2 * PI, now.second / 60.0 * 2 * PI)
    }
    private fun hands(cv: Canvas, now: ZonedDateTime, h: Hand) {
        val (ha, ma, sa) = angles(now)
        oneHand(cv, ha, h.hl, h.hw, 28f, h); oneHand(cv, ma, h.ml, h.mw, 32f, h)
        h.sec?.let { line.color = it; line.strokeWidth = 3f; cv.drawLine(px(-55f, sa), py(-55f, sa), px(h.sl, sa), py(h.sl, sa), line) }
        fill.color = h.cap; cv.drawCircle(CX, CY, 12f, fill)
        line.color = c("#30353c"); line.strokeWidth = 2f; cv.drawCircle(CX, CY, 12f, line)
        fill.color = h.sec ?: c("#30353c"); cv.drawCircle(CX, CY, 4.5f, fill)
    }
    private fun diverHands(cv: Canvas, now: ZonedDateTime) {
        val (ha, ma, sa) = angles(now); val lume = c("#e9f2d2"); val red = c("#e5484d")
        val h = Hand(Shape.SWORD, c("#dfe3e8"), c("#30353c"), null, c("#c9ced6"), lume)
        oneHand(cv, ha, 170f, 26f, 30f, h); oneHand(cv, ma, 262f, 18f, 34f, h)
        line.color = red; line.strokeWidth = 3.5f; cv.drawLine(px(-60f, sa), py(-60f, sa), px(282f, sa), py(282f, sa), line)
        fill.color = lume; cv.drawCircle(px(206f, sa), py(206f, sa), 11f, fill)
        line.strokeWidth = 4f; cv.drawCircle(px(206f, sa), py(206f, sa), 11f, line)
        fill.color = c("#c9ced6"); cv.drawCircle(CX, CY, 14f, fill)
        line.color = c("#30353c"); line.strokeWidth = 2f; cv.drawCircle(CX, CY, 14f, line)
        fill.color = red; cv.drawCircle(CX, CY, 5f, fill)
    }

    // ── Prediction Chrono ──
    private fun turq(cv: Canvas, t: Long, now: ZonedDateTime) {
        band(cv, t, 300f, 312f, GOLD, .55f)
        val P = Arc.path(t)
        subV(cv, t, CX - 128, CY, 76f, "week", P?.let { it.d0 + 7 * Arc.HOUR } ?: t, "WEEK") { q, _ -> Arc.DAYS.getOrElse(q) { "Q$q" } }
        subV(cv, t, CX + 128, CY, 76f, "day", P?.let { it.d0 + 1000 } ?: t, "DAY") { q, _ -> Arc.SESS_S.getOrElse(q) { "Q$q" } }
        subV(cv, t, CX, CY + 130, 76f, "m90", P?.let { it.S.s + 1000 } ?: t, P?.let { Arc.SESS[it.S.q] + " 90 MIN" } ?: "90 MIN") { q, b -> "Q$q " + Arc.hhmm(b[q - 1]) }
        text.color = c("#13403f"); text.textSize = 12f; text.letterSpacing = 2f / 12f
        cv.drawText(higher(t), CX, CY - 104 + 4, text)
        text.color = c("#0f2a2a"); text.letterSpacing = 2f / 12f
        P?.let { cv.drawText("NEXT HIGH - LOW  " + Arc.WD[Arc.wd(Arc.z(it.S.s + 1000))] + "  " + Arc.SESS[it.S.q] + "  " + Arc.hhmm(it.S.s) + " NY", CX, CY + 236 + 4, text) }
        text.letterSpacing = 0f
        gmt(cv, t, 300f, GOLD)
        hands(cv, now, Hand(Shape.BATON, c("#e8c97a"), c("#8a6420"), c("#e8c97a"), c("#d8b260"), lume = c("#f6f3e8"), hw = 16f, mw = 12f, hl = 168f, ml = 258f, sl = 280f))
    }
    private fun higher(t: Long): String {
        val out = ArrayList<String>()
        try {
            Arc.yrOf(t)?.let { Arc.yearPlan(it) }?.let { out.add("YEAR Q${it.q}") }
            Arc.qtrPlan(Arc.ybIdx(t))?.let { out.add("QTR Q${it.q}") }
            Arc.monPlan(t)?.let { out.add("MONTH Q${it.q}") }
        } catch (e: Exception) { }
        return out.joinToString("  ·  ")
    }
    private fun subV(cv: Canvas, t: Long, cx: Float, cy: Float, R: Float, key: String, T: Long, lab: String, vf: (Int, LongArray) -> String) {
        val b = Arc.bounds(key, T); val f = Arc.focus(b[0] + 1000)[key]
        val ang = { x: Long -> max(0.0, min(1.0, (x - b[0]).toDouble() / (b[4] - b[0]))) * 2 * PI }
        val goldRim = c("#c9a24a")
        fill.color = c("#0b0d10"); cv.drawCircle(cx, cy, R, fill)
        line.color = goldRim; line.strokeWidth = 3f; cv.drawCircle(cx, cy, R, line)
        for (i in 0 until 40) {
            val aa = i / 40.0 * 2 * PI; val r0 = if (i % 10 != 0) R * .93f else R * .86f
            line.strokeWidth = if (i % 10 != 0) 1f else 2f; line.strokeCap = Paint.Cap.BUTT
            cv.drawLine(px(R * .98f, aa, cx), py(R * .98f, aa, cy), px(r0, aa, cx), py(r0, aa, cy), line)
        }
        line.strokeCap = Paint.Cap.ROUND
        for (q in 1..4) {
            fill.color = if (q == f) a(GOLD, .95f) else a(QC[q], .4f)
            annulus(cv, cx, cy, R * .6f, R * .82f, ang(b[q - 1]) + .05, ang(b[q]) - .05, fill)
        }
        val hc = c("#e9c46a")
        if (t >= b[0] && t < b[4]) { val aa = ang(t); line.color = hc; line.strokeWidth = 3f; cv.drawLine(cx, cy, px(R * .74f, aa, cx), py(R * .74f, aa, cy), line) }
        fill.color = hc; cv.drawCircle(cx, cy, 5f, fill)
        if (f != null) { text.color = c("#f4e3b0"); text.textSize = R * .21f; cv.drawText(vf(f, b), cx, cy - R * .22f + text.textSize * .35f, text) }
        text.color = goldRim; text.textSize = R * .15f; text.letterSpacing = 1.5f / text.textSize
        cv.drawText(lab, cx, cy + R * .4f + text.textSize * .35f, text); text.letterSpacing = 0f
    }

    // ── ambient (always-on): black, outlines only ──
    private fun ambientAnalog(cv: Canvas, t: Long, now: ZonedDateTime) {
        val grey = c("#7a7a7a")
        line.color = grey; line.strokeWidth = 3f
        for (i in 0 until 12) { val aa = i / 12.0 * 2 * PI; val r0 = if (i % 3 == 0) 300f else 316f; cv.drawLine(px(r0, aa), py(r0, aa), px(336f, aa), py(336f, aa), line) }
        // the predicted session on a thin ring
        val b = Arc.bounds("day", t); val f = Arc.focus(b[0] + 1000)["day"]
        val ang = { x: Long -> (x - b[0]).toDouble() / (24 * Arc.HOUR) * 2 * PI }
        line.style = Paint.Style.STROKE
        for (q in 1..4) {
            val st = (ang(b[q - 1]) * 180 / PI - 90 + 1).toFloat(); val sw = (90.0 - 2).toFloat()
            line.color = if (q == f) Color.WHITE else c("#3a3a3a"); line.strokeWidth = if (q == f) 8f else 4f
            cv.drawArc(RectF(CX - 360, CY - 360, CX + 360, CY + 360), st, sw, false, line)
        }
        Arc.path(t)?.let {
            text.color = grey; text.textSize = 24f
            cv.drawText(Arc.SESS[it.S.q] + "  " + Arc.hhmm(it.S.s) + " NY", CX, CY + 190, text)
            text.textSize = 16f; cv.drawText("NEXT HIGH - LOW", CX, CY + 160, text)
        }
        val (ha, ma, _) = angles(now)
        for ((aa, len, w) in listOf(Triple(ha, 170f, 22f), Triple(ma, 262f, 16f))) {
            val p = handPath(aa, len, w, 24f, Shape.SWORD)
            line.color = Color.WHITE; line.strokeWidth = 3f; cv.drawPath(p, line)
        }
        fill.color = Color.BLACK; cv.drawCircle(CX, CY, 10f, fill); line.color = Color.WHITE; line.strokeWidth = 3f; cv.drawCircle(CX, CY, 10f, line)
    }

    // ── Arcana Digital ──
    private fun dur(ms: Long): String {
        val m = ms / Arc.MIN; val h = m / 60; val d = h / 24
        return if (m < 60) "${m}m" else if (h < 24) "${h}h ${m % 60}m" else "${d}d ${h % 24}h"
    }
    private fun digital(cv: Canvas, t: Long, now: ZonedDateTime, ambient: Boolean) {
        val muted = c("#8c8c8c")
        val b = Arc.bounds("day", t); val fd = Arc.focus(b[0] + 1000)["day"]
        val ang = { x: Long -> (x - b[0]).toDouble() / (24 * Arc.HOUR) * 2 * PI }
        if (!ambient) {
            fill.color = c("#0b0b0b"); cv.drawCircle(CX, CY, 400f, fill)
            for (q in 1..4) { fill.color = if (q == fd) a(GOLD, .95f) else a(QC[q], .45f); annulus(cv, CX, CY, 370f, 392f, ang(b[q - 1]) + .01, ang(b[q]) - .01, fill) }
            val aa = ang(t); fill.color = Color.WHITE; cv.drawCircle(px(381f, aa), py(381f, aa), 9f, fill)
        } else {
            line.color = c("#3a3a3a"); line.strokeWidth = 3f
            for (q in 1..4) { if (q == fd) { line.color = Color.WHITE } else line.color = c("#3a3a3a")
                cv.drawArc(RectF(CX - 380, CY - 380, CX + 380, CY + 380), (ang(b[q - 1]) * 180 / PI - 89).toFloat(), 88f, false, line) }
        }
        text.typeface = bold; text.color = muted; text.textSize = 24f; text.letterSpacing = 6f / 24f
        cv.drawText("ARCANA", CX, 150f, text); text.letterSpacing = 0f
        text.typeface = mono; text.color = Color.WHITE; text.textSize = 150f
        cv.drawText("%02d:%02d".format(now.hour, now.minute), CX, 300f, text)
        val ny = Arc.z(t)
        text.typeface = bold; text.color = muted; text.textSize = 28f
        cv.drawText("NY %02d:%02d  ·  %s %d".format(ny.hour, ny.minute, Arc.WD[Arc.wd(ny)], ny.dayOfMonth), CX, 350f, text)
        val P = Arc.path(t)
        if (P != null && !ambient) {
            val items = listOf("Day" to P.S.q, "Session" to P.M.q, "90 min" to P.C.q, "Micro" to P.Na.q, "Nano" to P.Pi.q)
            val x0 = 150f; val step = 125f
            items.forEachIndexed { i, (lv, q) ->
                val x = x0 + i * step
                text.typeface = mono; text.color = QC[q]; text.textSize = 46f; cv.drawText("Q$q", x, 440f, text)
                text.typeface = bold; text.color = muted; text.textSize = 17f; cv.drawText(lv, x, 466f, text)
                if (i < items.size - 1) { text.color = c("#555555"); text.textSize = 30f; cv.drawText("›", x + step / 2, 432f, text) }
            }
            text.color = muted; text.textSize = 20f; text.letterSpacing = 1f / 20f
            cv.drawText(higher(t) + "  ·  WEEK " + (Arc.focus(Arc.bounds("week", P.d0 + 7 * Arc.HOUR)[0] + 1000)["week"]?.let { "Q$it" } ?: "—"), CX, 520f, text)
            text.letterSpacing = 0f
        }
        if (P != null) {
            text.typeface = bold; text.color = if (ambient) muted else c("#bdbdbd"); text.textSize = 20f; text.letterSpacing = 3f / 20f
            cv.drawText("NEXT HIGH - LOW", CX, 580f, text); text.letterSpacing = 0f
            text.color = if (ambient) Color.WHITE else GOLD; text.textSize = 34f
            cv.drawText(Arc.WD[Arc.wd(Arc.z(P.S.s + 1000))] + "  " + Arc.SESS[P.S.q] + "  " + Arc.hhmm(P.S.s), CX, 622f, text)
            text.color = muted; text.textSize = 24f
            val st = if (t < P.S.s) "in " + dur(P.S.s - t) else "NOW · " + dur(P.S.e - t) + " left"
            cv.drawText(st, CX, 660f, text)
        }
        text.typeface = bold
    }
}
