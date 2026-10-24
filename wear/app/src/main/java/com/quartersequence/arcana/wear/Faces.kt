package com.quartersequence.arcana.wear

import android.view.SurfaceHolder
import androidx.wear.watchface.ComplicationSlotsManager
import androidx.wear.watchface.WatchFace
import androidx.wear.watchface.WatchFaceService
import androidx.wear.watchface.WatchFaceType
import androidx.wear.watchface.WatchState
import androidx.wear.watchface.style.CurrentUserStyleRepository

/** One service per face, so each shows up on its own in the watch's face list. */
abstract class ArcanaFace(private val faceId: String) : WatchFaceService() {
    override suspend fun createWatchFace(
        surfaceHolder: SurfaceHolder,
        watchState: WatchState,
        complicationSlotsManager: ComplicationSlotsManager,
        currentUserStyleRepository: CurrentUserStyleRepository,
    ): WatchFace {
        val renderer = FaceRenderer(applicationContext, faceId, surfaceHolder, watchState, currentUserStyleRepository)
        return WatchFace(if (faceId == "digital") WatchFaceType.DIGITAL else WatchFaceType.ANALOG, renderer)
    }
}

class PredictionChronoFace : ArcanaFace("turq")
class DiverFace : ArcanaFace("diver")
class DressFace : ArcanaFace("dress")
class PilotFace : ArcanaFace("pilot")
class ChronoFace : ArcanaFace("chrono")
class ChampagneFace : ArcanaFace("champ")
class DigitalFace : ArcanaFace("digital")
