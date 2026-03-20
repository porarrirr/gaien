package com.studyapp.testutil

import io.mockk.every
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import org.junit.rules.TestRule
import org.junit.runner.Description
import org.junit.runners.model.Statement

object LogMock {
    fun setup() {
        mockkStatic(android.util.Log::class)
        every { android.util.Log.d(any<String>(), any<String>()) } returns 0
        every { android.util.Log.d(any<String>(), any<String>(), any<Throwable>()) } returns 0
        every { android.util.Log.i(any<String>(), any<String>()) } returns 0
        every { android.util.Log.i(any<String>(), any<String>(), any<Throwable>()) } returns 0
        every { android.util.Log.w(any<String>(), any<String>()) } returns 0
        every { android.util.Log.w(any<String>(), any<Throwable>()) } returns 0
        every { android.util.Log.e(any<String>(), any<String>()) } returns 0
        every { android.util.Log.e(any<String>(), any<String>(), any<Throwable>()) } returns 0
        every { android.util.Log.v(any<String>(), any<String>()) } returns 0
        every { android.util.Log.v(any<String>(), any<String>(), any<Throwable>()) } returns 0
    }
    
    fun teardown() {
        unmockkStatic(android.util.Log::class)
    }
}

class LogMockRule : TestRule {
    override fun apply(base: Statement, description: Description): Statement {
        return object : Statement() {
            override fun evaluate() {
                LogMock.setup()
                try {
                    base.evaluate()
                } finally {
                    LogMock.teardown()
                }
            }
        }
    }
}