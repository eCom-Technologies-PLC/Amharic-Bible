package com.ecomtech.amharic_bible

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity keeps one Flutter engine shared with the background
// audio service, so playback continues with the lock-screen controls.
class MainActivity : AudioServiceActivity()
