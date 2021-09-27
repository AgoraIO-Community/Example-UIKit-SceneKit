# Streaming an ARKit Session with Agora UIKit

With Agora's UIKit package, streaming a live Augmented Reality session has never been easier.

## Prerequisites

- An Agora developer account (see [How To Get Started with Agora](https://www.agora.io/en/blog/how-to-get-started-with-agora?utm_source=medium&utm_medium=blog&utm_campaign=live-streaming-arkit))
- Xcode 12.0 or later
- iOS device with iOS 13.0 or later (as this project uses SF Symbols)
- A basic understanding of iOS development

## Setup

Let’s start with a new, single-view iOS project. Create the project in Xcode, and then add Agora's UIKit Package.

Add the package by opening selecting `File > Swift Packages > Add Package Dependency`, then paste in the link to this Swift Package:

```
https://github.com/AgoraIO-Community/iOS-UIKit.git
```

At the time post is written, the latest release is `4.0.0-preview.2`. The 4.x preview version of the SDK is used in this post, but a working version of this example with the Agora's Video SDK 3.x is also included in the example repository.

We also want to add [ARVideoKit](https://github.com/AFathi/ARVideoKit), a Swift package that helps to capture audio and video from SceneKit views:

```
https://github.com/AFathi/ARVideoKit.git
```

If you want to jump ahead, you can find the full example project here:

https://github.com/AgoraIO-Community/Example-UIKit-SceneKit

---

Once those packages are installed, the camera and microphone usage descriptions need to be added. To see how to do that, check out Apple's documentation here:

https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/requesting_authorization_for_media_capture_on_ios#2962313

## Create the UI

There are only two views that need to be added to our app:

1. Augmented Reality SceneKit view (`ARSCNView`)
2. Agora UIKit view, set to the `.collection` style.

The SceneKit view won't be anything special in this example. All we will do is create an ARSCNView that fills the screen, and place a cube in front of the camera (at `[0, 0, -3]`).

### SceneKit

The SceneKit view setup would look similar to this:

```swift
// Initialise and frame SceneKit view
self.sceneView = ARSCNView()
self.view.addSubview(sceneView)
self.view.sendSubviewToBack(sceneView)
sceneView.translatesAutoresizingMaskIntoConstraints = false
sceneView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
sceneView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
sceneView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
sceneView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true

// Add cube to SceneKit
let node = SCNNode(
  geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.3)
)
node.position.z = -3
sceneView.scene.rootNode.addChildNode(node)
```

> Note that all the snippets are from within methods of the ViewController class.

After that, we need to create the AR Recorder, from ARVideoKit. This class wraps the ARSCNView, so that it can grab the appropriate camera and SceneKit frames, and stitch them together:

```swift
// setup ARViewRecorder
self.arvkRenderer = RecordAR(ARSceneKit: self.sceneView)
self.arvkRenderer?.renderAR = self // Set the renderer's delegate
// Configure the renderer to always render the scene
self.arvkRenderer?.onlyRenderWhileRecording = false
// Configure ARKit content mode. Default is .auto
self.arvkRenderer?.contentMode = .aspectFill
// Set the UIViewController orientations
self.arvkRenderer?.inputViewOrientations = [.portrait]
self.arvkRenderer?.enableAudio = false

```

In the above example, we set the renderAR delegate as self, being the `ViewController`.

We need to add the RenderARDelegate protocol to the ViewController, and add the delegate method that gives us the video frame:

```swift
extension ViewController: RenderARDelegate {
  // MARK: ARVideoKit Renderer
  open func frame(
    didRender buffer: CVPixelBuffer, with time: CMTime,
    using rawBuffer: CVPixelBuffer
  ) {
    // Create AgoraVideoFrame, and push to Agora engine.
    // This part will be filled in later.
  }
}
```

The final step for the ARKit session is that we need to configure and run the AR session. I typically put this into the `viewDidAppear` method. We just want a basic AR session; `ARWorldTrackingConfiguration` is a good basic configuration to use:

```swift
open func setARConfiguration() {
  let configuration = ARWorldTrackingConfiguration()
  // run the config to start the ARSession
  self.arvkRenderer?.prepare(configuration)
}
```

Typically we would call `self.sceneView.session.run(configuration)` to start it up, but as we have it wrapped in a `RecordAR` object, we can call it on the `arvkRenderer` object instead.

### Agora UIKit

Now we need to join the Agora Video channel using Agora UIKit.

We need to tell the engine that we will be using an external camera, otherwise Agora UIKit will immediately go for the default builtin cameras.

Inside AgoraSettings there is a setting for this called `externalVideoSettings`. This property can tell the engine that an external video source should be used, and also tells the engine a few details about it, including whether it is textured video data, and if the video source is encoded.

In our case, textured video data is used, and the source is not encoded. We also don't want to show the option to flip the camera, so the settings property gets created like this:

```swift
var agSettings = AgoraSettings()
agSettings.externalVideoSettings = AgoraSettings.ExternalVideoSettings(
  enabled: true, texture: true, encoded: false
)
agSettings.enabledButtons = [.cameraButton, .micButton]
```

Then we create an instance of AgoraVideoViewer, with the above settings, and `.collection` style mentioned earlier.

```swift
let agoraView = AgoraVideoViewer(
  connectionData: AgoraConnectionData(
    appId: <#Agora App ID#>,
    appToken: <#Agora Token or nil#>
  ),
  style: .collection,
  agoraSettings: agSettings
)
```

Then fill the view with the AgoraVideoViewer, join the channel, and keep a reference to agoraView inside of the ViewController.

```swift
agoraView.fills(view: self.view)
agoraView.join(channel: "test", as: .broadcaster)
self.agoraView = agoraView
```

## Push Frames to Agora

Now the Augmented Reality scene is rendering correctly in the background, and anyone who joins the same channel with their camera will appear across the top of the view; but our device is not pushing anything, so our camera feed never arrives for any of the remote users.

Going back to the frame delegate method from earlier, we need to create an AgoraVideoFrame object, assign the format, pixel buffer, and a timestamp for the video frame:

```swift
extension ViewController: RenderARDelegate {
  // MARK: ARVideoKit Renderer
  open func frame(
    didRender buffer: CVPixelBuffer, with time: CMTime,
    using rawBuffer: CVPixelBuffer
  ) {
    let videoFrame = AgoraVideoFrame()
    videoFrame.format = 12
    videoFrame.textureBuf = buffer
    videoFrame.time = time

    self.agoraView?.agkit.pushExternalVideoFrame(videoFrame)
  }
}
```

For the format, `12` means that we are using an iOS texture (CVPixelBufferRef). The textureBuf is our incoming pixel buffer,a nd time is also provided by the RenderARDelegate method, so add that to the AgoraVideoFrame.

Then we grab the `AgoraRtcEngineKit` instance through the `AgoraVideoViewer` class, and push the video frame to it.

## Audio

If you also want to stream audio from SceneKit, there are a couple more settings that need to happen.

- Within Agora UIKit, add the setting for `externalAudioSource` to enabled.
- In the ARWorldTrackingConfiguration, you need to set the `providesAudioData` to `true`.

- Add the ARSessionDelegate method [didOutputAudioSampleBuffer](https://developer.apple.com/documentation/arkit/arsessionobserver/2923544-session).
- Call [pushExternalAudioFrameSampleBuffer](https://docs.agora.io/en/All/API%20Reference/oc/Classes/AgoraRtcEngineKit.html#//api/name/pushExternalAudioFrameSampleBuffer:) on the Agora engine instance.

## Conclusion

Try this example out using either the 3.x or 4.x SDK through Agora UIKit here:

https://github.com/AgoraIO-Community/Example-UIKit-SceneKit

There are some known issues from ARVideoKit to do with device orientation, so for this specific example I would only recommend trying it with the device upright (portrait).

