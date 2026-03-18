package com.example.change_your_life

import android.app.Activity
import android.os.Bundle
import android.widget.Button
import android.widget.TextView

class BlockActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_block)

        val appName = intent.getStringExtra("appName") ?: "App"
        val packageName = intent.getStringExtra("packageName") ?: ""

        val titleText = findViewById<TextView>(R.id.blockTitle)
        val packageText = findViewById<TextView>(R.id.blockPackage)
        val closeButton = findViewById<Button>(R.id.closeButton)

        titleText.text = "$appName está bloqueada"
        packageText.text = "Package: $packageName"

        closeButton.setOnClickListener {
            finish()
        }
    }
}