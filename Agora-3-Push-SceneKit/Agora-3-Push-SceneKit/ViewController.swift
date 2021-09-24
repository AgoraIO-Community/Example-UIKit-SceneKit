//
//  ViewController.swift
//  Agora-3-Push-SceneKit
//
//  Created by Max Cobb on 22/09/2021.
//

import UIKit
import AgoraUIKit_iOS

import AgoraRtcKit
import ARVideoKit
import SceneKit
import ARKit

/**
 A custom video source for the AgoraRtcEngine. This class conforms to the AgoraVideoSourceProtocol and is used to pass the AR pixel buffer as a video source of the Agora stream.
 */
public class ARVideoSource: NSObject, AgoraVideoSourceProtocol {
    public func captureType() -> AgoraVideoCaptureType { .camera }

    public func contentHint() -> AgoraVideoContentHint { .none }

    public var consumer: AgoraVideoFrameConsumer?
    public var rotation: AgoraVideoRotation = .rotationNone

    public func shouldInitialize() -> Bool { return true }

    public func shouldStart() { }

    public func shouldStop() { }

    public func shouldDispose() { }

    public func bufferType() -> AgoraVideoBufferType {
        return .pixelBuffer
    }

    func sendBuffer(_ buffer: CVPixelBuffer, timestamp: TimeInterval) {
        let time = CMTime(seconds: timestamp, preferredTimescale: 1000)
        let currentOrientation = UIDevice.current.orientation
        var pbRotation: AgoraVideoRotation
        switch currentOrientation {
        case .portrait:
            pbRotation = .rotationNone
        case .portraitUpsideDown:
            pbRotation = .rotation180
        case .landscapeLeft:
            pbRotation = .rotation270
        case .landscapeRight:
            pbRotation = .rotation90
        default:
            pbRotation = .rotationNone
        }
        consumer?.consumePixelBuffer(buffer, withTimestamp: time, rotation: pbRotation)
    }
}

class ViewController: UIViewController {

    var agoraView: AgoraVideoViewer?
    var arVideoSource: ARVideoSource = ARVideoSource()  // for passing the AR camera as the stream

    public var sceneView: ARSCNView!
    var arvkRenderer: RecordAR?

    override func viewDidLoad() {
        super.viewDidLoad()

        var agSettings = AgoraSettings()
        agSettings.videoSource = self.arVideoSource
        agSettings.enabledButtons = [.cameraButton, .micButton]

        let agoraView = AgoraVideoViewer(
            connectionData: AgoraConnectionData(
                appId: <#Agora App ID#>,
                appToken: <#Agora Token or nil#>
            ),
            style: .collection,
            agoraSettings: agSettings
        )

        agoraView.fills(view: self.view)

        agoraView.join(channel: "test", as: .broadcaster)

        self.agoraView = agoraView

        self.setupARView()
    }

    func setupARView() {
        self.sceneView = ARSCNView()
        let node = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0.3))
        node.position.z = -3
        self.sceneView.scene.rootNode.addChildNode(node)
        self.view.addSubview(self.sceneView)
        self.view.sendSubviewToBack(self.sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        sceneView.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        sceneView.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        sceneView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true

        // setup ARViewRecorder
        self.arvkRenderer = RecordAR(ARSceneKit: self.sceneView)
        self.arvkRenderer?.renderAR = self // Set the renderer's delegate
        // Configure the renderer to always render the scene
        self.arvkRenderer?.onlyRenderWhileRecording = false
        // Configure ARKit content mode. Default is .auto
        self.arvkRenderer?.contentMode = .aspectFill
        // Set the UIViewController orientations
        self.arvkRenderer?.inputViewOrientations = [.portrait, .landscapeLeft, .landscapeRight]
        self.arvkRenderer?.enableAudio = false

    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.setARConfiguration()
    }

    open func setARConfiguration() {
        let configuration = ARWorldTrackingConfiguration()
        // run the config to start the ARSession
        self.sceneView.session.run(configuration)
        self.arvkRenderer?.prepare(configuration)
    }

}

/**
 `ARBroadcaster` implements the `RenderARDelegate` from ARVideoKit to pass the composited rendered frame to the active Agora stream as the custom video source.
 */
extension ViewController: RenderARDelegate {
    // MARK: ARVidoeKit Renderer
    open func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        self.arVideoSource.sendBuffer(buffer, timestamp: time.seconds)
    }
}


