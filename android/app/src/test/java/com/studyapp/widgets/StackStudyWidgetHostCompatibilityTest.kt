package com.studyapp.widgets

import com.studyapp.R
import org.junit.Assert.assertEquals
import org.junit.Test

class StackStudyWidgetHostCompatibilityTest {

    @Test
    fun `resolveCollectionLayout falls back to list for xiaomi devices`() {
        assertEquals(
            R.layout.widget_stack_root_list,
            StackStudyWidgetHostCompatibility.resolveCollectionLayout(
                manufacturer = "Xiaomi",
                brand = "Redmi"
            )
        )
    }

    @Test
    fun `resolveCollectionLayout keeps stack layout for other devices`() {
        assertEquals(
            R.layout.widget_stack_root,
            StackStudyWidgetHostCompatibility.resolveCollectionLayout(
                manufacturer = "Google",
                brand = "Pixel"
            )
        )
    }
}
