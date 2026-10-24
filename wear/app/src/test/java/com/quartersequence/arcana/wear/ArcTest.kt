package com.quartersequence.arcana.wear

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonParser
import org.junit.Assert.assertEquals
import org.junit.Test

/** Compares the Kotlin port with values computed by Arcana (the web app) for the same moments. */
class ArcTest {
    private fun arr(e: JsonElement): List<Long>? = if (e.isJsonNull) null else (e as JsonArray).map { it.asLong }
    private fun int(e: JsonElement?): Int? = if (e == null || e.isJsonNull) null else e.asInt

    @Test fun matchesArcana() {
        val text = javaClass.classLoader!!.getResource("vectors.json")!!.readText()
        val v = JsonParser.parseString(text).asJsonArray
        var n = 0
        for (el in v) {
            val o = el.asJsonObject; val t = o["t"].asLong; val tag = "t=$t ${Arc.z(t)}"
            val c = Arc.clock(t)
            for ((k, x) in o["c"].asJsonObject.entrySet()) assertEquals("$tag clock $k", int(x), c[k])
            val f = Arc.focus(t)
            for ((k, x) in o["f"].asJsonObject.entrySet()) assertEquals("$tag focus $k", int(x), f[k])
            for (key in listOf("day", "week", "month", "m90", "micro"))
                assertEquals("$tag bounds $key", arr(o[key]), Arc.bounds(key, t).toList())
            val p = Arc.path(t)
            assertEquals("$tag path", arr(o["P"]), p?.let { listOf(it.S.s, it.S.q.toLong(), it.M.s, it.M.q.toLong(), it.C.s, it.C.q.toLong(), it.Na.q.toLong(), it.Pi.q.toLong()) })
            val yr = Arc.yrOf(t)
            val y = yr?.let { Arc.yearPlan(it) }
            assertEquals("$tag year", arr(o["Y"]), y?.let { listOf(it.q.toLong(), it.s, it.e) })
            val q = Arc.qtrPlan(Arc.ybIdx(t))
            assertEquals("$tag quarter", arr(o["Q"]), q?.let { listOf(it.q.toLong(), it.s, it.e) })
            val m = Arc.monPlan(t)
            assertEquals("$tag month", arr(o["M"]), m?.let { listOf(it.q.toLong(), it.s, it.e) })
            n++
        }
        println("checked $n moments")
    }
}
