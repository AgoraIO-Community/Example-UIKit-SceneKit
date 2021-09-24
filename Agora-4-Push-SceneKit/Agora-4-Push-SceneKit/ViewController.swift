//
//  ViewController.swift
//  Agora-4-Push-SceneKit
//
//  Created by Max Cobb on 22/09/2021.
//

import UIKit
import ARKit
import AgoraUIKit_iOS
import AgoraRtcKit
import ARVideoKit

class ViewController: UIViewController {

    var agoraView: AgoraVideoViewer?

    public var sceneView: ARSCNView!
    var arvkRenderer: RecordAR?

    override func viewDidLoad() {
        super.viewDidLoad()

        var agSettings = AgoraSettings()
        agSettings.externalVideoSource = AgoraSettings.ExternalVideoSettings(
            enabled: true, texture: true, encoded: false
        )
        agSettings.enabledButtons = [.cameraButton, .micButton]

        let agoraView = AgoraVideoViewer(
            connectionData: AgoraConnectionData(
                appId: <#Agora App ID#>,
                appToken: <#Agora Token or nil#>
            ),
            style: .collection,
            agoraSettings: agSettings
        )

        self.view.backgroundColor = .tertiarySystemBackground
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

extension ViewController: RenderARDelegate {
    // MARK: ARVidoeKit Renderer
    open func frame(didRender buffer: CVPixelBuffer, with time: CMTime, using rawBuffer: CVPixelBuffer) {
        let videoFrame = AgoraVideoFrame()
        videoFrame.format = 12
        videoFrame.textureBuf = buffer
        videoFrame.time = time
        let currentOrientation = UIDevice.current.orientation
        switch currentOrientation {
        case .portraitUpsideDown:
            videoFrame.rotation = Int32(180)
        case .landscapeLeft:
            videoFrame.rotation = Int32(270)
        case .landscapeRight:
            videoFrame.rotation = Int32(90)
        default: break
        }

        self.agoraView?.agkit.pushExternalVideoFrame(videoFrame)
    }
}


