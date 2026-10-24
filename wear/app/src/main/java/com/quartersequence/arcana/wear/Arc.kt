package com.quartersequence.arcana.wear

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * QS Kingdom's Arcana prediction, ported from the web app (sum rule, "QS Bright").
 * All cycle times are New York time. Q = ((A + B + C - 1) mod 4) + 1.
 */
object Arc {
    val NY: ZoneId = ZoneId.of("America/New_York")
    const val MIN = 60_000L
    const val HOUR = 3_600_000L
    const val DAY = 86_400_000L
    const val NANO = 337_500L
    const val PICO = 84_375L
    var fridayWrap = true

    fun z(t: Long): ZonedDateTime = Instant.ofEpochMilli(t).atZone(NY)
    fun ms(y: Int, mo: Int, d: Int, h: Int, mi: Int = 0, s: Int = 0): Long =
        ZonedDateTime.of(y, mo, d, h, mi, s, 0, NY).toInstant().toEpochMilli()
    fun ms(d: LocalDate, h: Int): Long = ms(d.year, d.monthValue, d.dayOfMonth, h)
    /** 0 = Sunday … 6 = Saturday (as in JavaScript) */
    fun wd(x: ZonedDateTime): Int = x.dayOfWeek.value % 7

    fun cmeWeekSunday(t: Long): Long {
        val x = z(t); val w = wd(x)
        val back = if (w == 0) (if (x.hour >= 18) 0 else 7) else w
        return ms(x.toLocalDate().minusDays(back.toLong()), 18)
    }
    fun cmeWeekMonday(t: Long) = cmeWeekSunday(t) + 6 * HOUR
    fun addWeeks(t: Long, w: Int): Long = ms(z(t).toLocalDate().plusWeeks(w.toLong()), 18)
    fun firstSunday(yr: Int, mo: Int): Long {
        for (d in 1..7) if (LocalDate.of(yr, mo, d).dayOfWeek == DayOfWeek.SUNDAY) return ms(yr, mo, d, 18)
        error("no sunday")
    }

    // ── calendar anchors ──
    class YB(val ts: Long, val q: Int, val yr: Int) { var qb: LongArray? = null }
    class YS(val ts: Long, val yr: Int)
    private var anchorYear = 0
    var yearStarts: List<YS> = emptyList(); private set
    var yearly: List<YB> = emptyList(); private set

    fun anchors(t: Long) {
        val y0 = z(t).year
        if (y0 == anchorYear) return
        val ys = ArrayList<YS>(); val yb = ArrayList<YB>()
        for (yr in y0 - 24..y0 + 24) {
            ys.add(YS(firstSunday(yr, 1), yr))
            intArrayOf(1, 4, 7, 10).forEachIndexed { i, mo -> yb.add(YB(firstSunday(yr, mo), i + 1, yr)) }
        }
        ys.sortBy { it.ts }; yb.sortBy { it.ts }
        for (i in 0 until yb.size - 1) {
            val a = yb[i].ts; val n = yb[i + 1].ts
            val qb = longArrayOf(a, 0, 0, 0, n)
            val w = intArrayOf(0, 3, 6, 9)
            for (k in 1..3) { val x = addWeeks(a, w[k]); qb[k] = if (x < n) x else n }
            yb[i].qb = qb
        }
        yearStarts = ys; yearly = yb; anchorYear = y0
    }
    fun <T> bIdx(a: List<T>, ts: Long, key: (T) -> Long): Int {
        if (a.isEmpty() || ts < key(a[0])) return -1
        var lo = 0; var hi = a.size - 1
        while (lo < hi) { val m = (lo + hi + 1) shr 1; if (key(a[m]) <= ts) lo = m else hi = m - 1 }
        return lo
    }
    fun ybIdx(ts: Long): Int { anchors(ts); return bIdx(yearly, ts) { it.ts } }

    fun quadQ(yr: Int) = (((yr - 2023) % 4) + 4) % 4 + 1
    fun weeklyQ(t: Long): Int { val x = z(t); val cd = if (x.hour >= 18) (wd(x) + 1) % 7 else wd(x); return if (cd in 1..4) cd else 0 }
    fun monthlyQ(t: Long): Int { val d = z(cmeWeekMonday(t)).dayOfMonth; return if (d <= 7) 1 else if (d <= 14) 2 else if (d <= 21) 3 else 4 }
    fun yearlyQ(t: Long): Int { val i = ybIdx(t); return if (i < 0) 0 else yearly[i].q }
    fun quarterlyQ(t: Long): Int {
        val i = ybIdx(t); if (i < 0) return 0
        val qb = yearly[i].qb ?: return 0
        for (k in 3 downTo 1) if (t >= qb[k]) return k + 1
        return 1
    }
    fun quadrennialQ(t: Long): Int { anchors(t); val i = bIdx(yearStarts, t) { it.ts }; return if (i < 0) 0 else quadQ(yearStarts[i].yr) }

    /** the clock: current quarter of every level (null = no quarter, e.g. Friday on the weekly cycle) */
    fun clock(t: Long): MutableMap<String, Int?> {
        val x = z(t); val h = x.hour
        val session = if (h >= 18) 1 else if (h < 6) 2 else if (h < 12) 3 else 4
        val sh = if (h >= 18) 18 else if (h < 6) 0 else if (h < 12) 6 else 12
        var rem = t - ms(x.year, x.monthValue, x.dayOfMonth, sh)
        val b90 = (rem / (90 * MIN)).toInt(); val m90 = minOf(b90 + 1, 4); rem -= b90 * 90 * MIN
        val bMi = (rem / (22_500 * 60L)).toInt(); rem -= bMi * 22_500 * 60L
        val bNa = (rem / NANO).toInt(); rem -= bNa * NANO
        val bPi = (rem / PICO).toInt()
        fun n(v: Int): Int? = if (v == 0) null else v
        return mutableMapOf("quad" to n(quadrennialQ(t)), "yearly" to n(yearlyQ(t)), "quarterly" to n(quarterlyQ(t)),
            "monthly" to n(monthlyQ(t)), "weekly" to n(weeklyQ(t)), "session" to session, "m90" to m90,
            "micro" to minOf(bMi + 1, 4), "nano" to minOf(bNa + 1, 4), "pico" to minOf(bPi + 1, 4))
    }

    /** start of each quarter of one level + its end: [s1, s2, s3, s4, end] */
    fun bounds(key: String, t: Long): LongArray {
        val x = z(t); val h = x.hour
        val sh = if (h >= 18) 18 else if (h < 6) 0 else if (h < 12) 6 else 12
        val sess = ms(x.year, x.monthValue, x.dayOfMonth, sh)
        val b90 = minOf(((t - sess) / (90 * MIN)).toInt(), 3); val m90 = sess + b90 * 90 * MIN
        val bmi = minOf(((t - m90) / (22_500 * 60L)).toInt(), 3); val mic = m90 + bmi * 22_500 * 60L
        val bna = minOf(((t - mic) / NANO).toInt(), 3); val nan = mic + bna * NANO
        fun lin(s: Long, u: Long) = LongArray(5) { s + it * u }
        return when (key) {
            "pico" -> lin(nan, PICO)
            "nano" -> lin(mic, NANO)
            "micro" -> lin(m90, 22_500 * 60L)
            "m90" -> lin(sess, 90 * MIN)
            "day" -> { val c = if (h >= 18) x.toLocalDate() else x.toLocalDate().minusDays(1); val s = ms(c, 18); LongArray(5) { s + it * 6 * HOUR } }
            "week" -> { val sun = z(cmeWeekSunday(t)).toLocalDate(); LongArray(5) { ms(sun.plusDays(it.toLong()), 18) } }
            "month" -> {
                val mon = z(cmeWeekMonday(t)); val s = monthCycleStart(mon.year, mon.monthValue)
                val ny = if (mon.monthValue == 12) mon.year + 1 else mon.year; val nm = if (mon.monthValue == 12) 1 else mon.monthValue + 1
                longArrayOf(s, addWeeks(s, 1), addWeeks(s, 2), addWeeks(s, 3), monthCycleStart(ny, nm))
            }
            else -> error(key)
        }
    }
    fun monthCycleStart(yr: Int, mo: Int): Long {
        for (d in 1..7) if (LocalDate.of(yr, mo, d).dayOfWeek == DayOfWeek.MONDAY) return cmeWeekSunday(ms(yr, mo, d, 12))
        error("no monday")
    }

    private val ROWS = listOf(
        "month" to listOf("quad", "yearly", "quarterly"),
        "week" to listOf("yearly", "quarterly", "monthly"),
        "day" to listOf("quarterly", "monthly", "weekly"),
        "m90" to listOf("monthly", "weekly", "@day"),
        "micro" to listOf("weekly", "@day", "@m90"),
        "nano" to listOf("@day", "@m90", "@micro"),
        "pico" to listOf("@m90", "@micro", "@nano"))

    fun friDay(t: Long): Boolean = wd(z(bounds("day", t)[0] + 7 * HOUR)) == 5

    /** the predicted High - Low quarter of every level (sum rule) */
    fun focus(t: Long): Map<String, Int?> {
        val c = clock(t)
        if (fridayWrap && c["weekly"] == null && c["monthly"] != null && friDay(t)) c["weekly"] = 1
        val out = HashMap<String, Int?>()
        for ((key, ins) in ROWS) {
            val v = ins.map { if (it[0] == '@') out[it.substring(1)] else c[it] }
            out[key] = if (v.any { it == null }) null else ((v.sumOf { it!! } - 1) % 4) + 1
        }
        return out
    }

    class Blk(val s: Long, val e: Long, val q: Int, val b: LongArray)
    class Path(val d0: Long, val day: LongArray, val S: Blk, val M: Blk, val C: Blk, val Na: Blk, val Pi: Blk)

    /** the next (or current) predicted day: session → 90 min → Micro → Nano → Pico */
    fun path(n: Long): Path? {
        var d0 = bounds("day", n)[0]
        repeat(10) {
            val f = focus(d0 + 1000)["day"]; val b = bounds("day", d0 + 1000)
            if (f != null && b[f] > n) {
                val S = Blk(b[f - 1], b[f], f, b)
                fun sub(key: String, parent: Blk): Blk {
                    val bb = bounds(key, parent.s + 1000); val q = focus(bb[0] + 1000)[key] ?: 1
                    return Blk(bb[q - 1], bb[q], q, bb)
                }
                val M = sub("m90", S); val C = sub("micro", M); val Na = sub("nano", C); val Pi = sub("pico", Na)
                return Path(d0, b, S, M, C, Na, Pi)
            }
            d0 = bounds("day", b[4] + 1000)[0]
        }
        return null
    }

    // ── Year / Quarter / Month (16-year and 64-year cycles above the 4-year, anchored at 2023) ──
    fun c16Q(yr: Int) = ((Math.floorDiv(yr - 2023, 4) % 4) + 4) % 4 + 1
    fun c64Q(yr: Int) = ((Math.floorDiv(yr - 2023, 16) % 4) + 4) % 4 + 1
    fun sumQ(a: Int, b: Int, c: Int) = ((a + b + c - 1) % 4) + 1
    fun yrOf(t: Long): Int? { anchors(t); val i = bIdx(yearStarts, t) { it.ts }; return if (i < 0) null else yearStarts[i].yr }
    fun yrBounds(yr: Int): LongArray? {
        val b = yearly.filter { it.yr == yr }.sortedBy { it.ts }; val n = yearly.firstOrNull { it.yr == yr + 1 && it.q == 1 }
        return if (b.size == 4 && n != null) longArrayOf(b[0].ts, b[1].ts, b[2].ts, b[3].ts, n.ts) else null
    }
    fun yearPlan(yr: Int): Blk? { val b = yrBounds(yr) ?: return null; val q = sumQ(c64Q(yr), c16Q(yr), quadQ(yr)); return Blk(b[q - 1], b[q], q, b) }
    fun qtrPlan(i: Int): Blk? {
        val y = yearly.getOrNull(i) ?: return null; val b = y.qb ?: return null
        val q = sumQ(c16Q(y.yr), quadQ(y.yr), y.q); return Blk(b[q - 1], b[q], q, b)
    }
    fun monPlan(t: Long): Blk? { val b = bounds("month", t); val q = focus(b[0] + 1000)["month"] ?: return null; return Blk(b[q - 1], b[q], q, b) }

    val SESS = arrayOf("", "ASIA", "LONDON", "NY AM", "NY PM")
    val SESS_S = arrayOf("", "ASIA", "LDN", "NY AM", "NY PM")
    val DAYS = arrayOf("", "MON", "TUE", "WED", "THU")
    val WD = arrayOf("SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT")
    val MO = arrayOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    fun hhmm(t: Long): String { val x = z(t); return "%02d:%02d".format(x.hour, x.minute) }
}
