import SwiftUI
import SceneKit
import ARKit
import AVKit

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView()
        sceneView.delegate = context.coordinator
        
        let configuration = ARImageTrackingConfiguration()
        guard let arImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("No AR images found")
        }
        configuration.trackingImages = arImages
        sceneView.session.run(configuration)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARViewContainer
        var videoPlayers: [String: [AVPlayer]] = [:]
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
        }
        
        // Dictionary to map image names to corresponding video file names
        let imageToVideoMap: [String: [String]] = [
            "card-1": ["center-video-app", "left-video-app", "right-video-app"],
            "card-2": ["center-video-ID", "left-video-ID", "right-video-ID"]
            // Add more image-video triplets here
        ]
        
        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let imageAnchor = anchor as? ARImageAnchor else { return }
            let referenceImage = imageAnchor.referenceImage
            
            guard let imageName = referenceImage.name, let videoNames = imageToVideoMap[imageName], videoNames.count == 3 else { return }
            
            // Create the central, left, and right video nodes
            let centralVideoNode = createVideoNode(for: referenceImage, videoName: videoNames[0], imageName: imageName, videoIndex: 0)
            let leftVideoNode = createVideoNode(for: referenceImage, videoName: videoNames[1], imageName: imageName, videoIndex: 1)
            let rightVideoNode = createVideoNode(for: referenceImage, videoName: videoNames[2], imageName: imageName, videoIndex: 2)
            
            // Determine positions
            let videoWidth = referenceImage.physicalSize.width
            let spacing = 0.002  // 1 cm spacing
            leftVideoNode.position = SCNVector3(-videoWidth - spacing, 0.04, 0)  // Move left by width + spacing
            leftVideoNode.eulerAngles.z = -.pi / 4
            rightVideoNode.position = SCNVector3(videoWidth + spacing, 0.04, 0)  // Move right by width + spacing
            rightVideoNode.eulerAngles.z = .pi / 4
            
            // Add the nodes to the parent node
            node.addChildNode(centralVideoNode)
            node.addChildNode(leftVideoNode)
            node.addChildNode(rightVideoNode)

            // Play all video players
            videoPlayers[imageName]?.forEach { $0.play() }
        }
        
        func createVideoNode(for referenceImage: ARReferenceImage, videoName: String, imageName: String, videoIndex: Int) -> SCNNode {
            let videoNode = SCNNode()
            let videoPlane = SCNPlane(width: referenceImage.physicalSize.width, height: referenceImage.physicalSize.height)
            videoPlane.cornerRadius = 0.005
            videoNode.geometry = videoPlane
            
            // Load the video file
            guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: ".mp4") else { return videoNode }
            let videoPlayer = AVPlayer(url: videoURL)
            videoPlayer.volume = 0.0  // Mute the video
            
            let videoMaterial = SCNMaterial()
            videoMaterial.diffuse.contents = videoPlayer
            videoMaterial.isDoubleSided = true
            videoPlane.materials = [videoMaterial]
            
            videoNode.eulerAngles.x = -.pi / 2  // Rotate to lie flat on the image
            
            // Ensure each video has its own AVPlayer instance
            if videoPlayers[imageName] == nil {
                videoPlayers[imageName] = []
            }
            videoPlayers[imageName]?.append(videoPlayer)
            
            return videoNode
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let imageAnchor = anchor as? ARImageAnchor else { return }
            let referenceImage = imageAnchor.referenceImage
            
            guard let imageName = referenceImage.name, let players = videoPlayers[imageName] else { return }
            
            if imageAnchor.isTracked {
                players.forEach { $0.play() }
            } else {
                players.forEach { $0.pause() }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        ARViewContainer()
            .edgesIgnoringSafeArea(.all)
    }
}
