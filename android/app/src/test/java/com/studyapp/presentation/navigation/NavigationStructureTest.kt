package com.studyapp.presentation.navigation

import org.junit.Assert.assertEquals
import org.junit.Test

class NavigationStructureTest {
    @Test
    fun `bottom navigation matches iOS compact tab order`() {
        assertEquals(
            listOf("ホーム", "タイマー", "教材", "カレンダー", "More"),
            bottomScreens.map { it.title }
        )
    }

    @Test
    fun `more navigation matches iOS overflow tabs`() {
        assertEquals(
            listOf("科目", "時間割", "レポート", "Screen Time", "設定"),
            moreScreens.map { it.title }
        )
    }
}
