package com.studyapp.widgets

import org.junit.Assert.assertEquals
import org.junit.Test

class StackStudyWidgetConfigStoreTest {

    @Test
    fun `serialize cards removes duplicates and keeps order`() {
        val serialized = StackStudyWidgetConfigStore.serializeCards(
            listOf(
                StudyWidgetCardType.TODAY,
                StudyWidgetCardType.STREAK,
                StudyWidgetCardType.TODAY,
                StudyWidgetCardType.WEEKLY_GOAL
            )
        )

        assertEquals("TODAY,STREAK,WEEKLY_GOAL", serialized)
    }

    @Test
    fun `deserialize cards filters unknown entries and falls back to defaults when empty`() {
        val cards = StackStudyWidgetConfigStore.deserializeCards("WEEKLY_GOAL,UNKNOWN,STREAK")

        assertEquals(
            listOf(StudyWidgetCardType.WEEKLY_GOAL, StudyWidgetCardType.STREAK),
            cards
        )
        assertEquals(
            StudyWidgetCardType.defaultOrder(),
            StackStudyWidgetConfigStore.deserializeCards("")
        )
    }
}
