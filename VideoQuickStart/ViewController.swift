//
//  ViewController.swift
//  VideoQuickStart
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

import UIKit

import TwilioVideo

class ViewController: UIViewController {

    // MARK: View Controller Members
    
    // Configure access token manually for testing, if desired! Create one manually in the console
    // at https://www.twilio.com/console/video/runtime/testing-tools
    //var accessToken = "TWILIO_ACCESS_TOKEN"
    
    var accessToken: String?
  
    // Configure remote URL to fetch token from
    var tokenUrl = "https://scarlet-chicken-9207.twil.io/video-token?"
    
    // Video SDK components
    var room: Room?
    var camera: CameraSource?
    var localVideoTrack: LocalVideoTrack?
    var localAudioTrack: LocalAudioTrack?
    var remoteParticipant: RemoteParticipant?
    var remoteView: VideoView?
    
    // MARK: UI Element Outlets and handles
    
    // `TVIVideoView` created from a storyboard
    @IBOutlet weak var previewView: VideoView!

    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var roomTextField: UITextField!
    @IBOutlet weak var roomLine: UIView!
    @IBOutlet weak var roomLabel: UILabel!
    @IBOutlet weak var micButton: UIButton!

    // MARK: UIViewController
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "QuickStart"
        self.messageLabel.adjustsFontSizeToFitWidth = true;
        self.messageLabel.minimumScaleFactor = 0.75;

        if PlatformUtils.isSimulator {
            self.previewView.removeFromSuperview()
        } else {
            // Preview our local camera track in the local video preview view.
            self.startPreview()
        }
        
        // Disconnect and mic button will be displayed when the Client is connected to a Room.
        self.disconnectButton.isHidden = true
        self.micButton.isHidden = true
        
        self.roomTextField.autocapitalizationType = .none
        self.roomTextField.delegate = self
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return self.room != nil
    }
    
    func setupRemoteVideoView() {
        // Creating `TVIVideoView` programmatically
        self.remoteView = VideoView.init(frame: CGRect.zero, delegate:self)
        
        self.view.insertSubview(self.remoteView!, at: 0)
        
        // `TVIVideoView` supports scaleToFill, scaleAspectFill and scaleAspectFit
        // scaleAspectFit is the default mode when you create `TVIVideoView` programmatically.
        self.remoteView!.contentMode = .scaleAspectFit;

        let centerX = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: self.view,
                                         attribute: NSLayoutConstraint.Attribute.centerX,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerX)
        let centerY = NSLayoutConstraint(item: self.remoteView!,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         relatedBy: NSLayoutConstraint.Relation.equal,
                                         toItem: self.view,
                                         attribute: NSLayoutConstraint.Attribute.centerY,
                                         multiplier: 1,
                                         constant: 0);
        self.view.addConstraint(centerY)
        let width = NSLayoutConstraint(item: self.remoteView!,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       relatedBy: NSLayoutConstraint.Relation.equal,
                                       toItem: self.view,
                                       attribute: NSLayoutConstraint.Attribute.width,
                                       multiplier: 1,
                                       constant: 0);
        self.view.addConstraint(width)
        let height = NSLayoutConstraint(item: self.remoteView!,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        relatedBy: NSLayoutConstraint.Relation.equal,
                                        toItem: self.view,
                                        attribute: NSLayoutConstraint.Attribute.height,
                                        multiplier: 1,
                                        constant: 0);
        self.view.addConstraint(height)
    }

    // MARK: IBActions
    @IBAction func connectAction() {
        // Configure access token either from server or manually.
        // If the default wasn't changed, try fetching from server.
        if (accessToken == nil) {
            do {
                tokenUrl = tokenUrl + "identity=stan" + "\(arc4random())" + "&room=\(roomTextField.text ?? "")"
                accessToken = try TokenUtils.fetchToken(url: tokenUrl)
            } catch {
                let message = "Failed to fetch access token"
                logMessage(messageText: message)
                return
            }
        }
        
        guard let accessToken = accessToken else {
            return
        }
        
        // Prepare local media which we will share with Room Participants.
        self.prepareLocalMedia()
        
        // Preparing the connect options with the access token that we fetched (or hardcoded).
        let connectOptions = ConnectOptions.init(token: accessToken) { (builder) in
            
            // Use the local media that we prepared earlier.
            builder.audioTracks = self.localAudioTrack != nil ? [self.localAudioTrack!] : [LocalAudioTrack]()
            builder.videoTracks = self.localVideoTrack != nil ? [self.localVideoTrack!] : [LocalVideoTrack]()
            
            // Use the preferred audio codec
            if let preferredAudioCodec = Settings.shared.audioCodec {
                builder.preferredAudioCodecs = [preferredAudioCodec]
            }
            
            // Use the preferred video codec
            if let preferredVideoCodec = Settings.shared.videoCodec {
                builder.preferredVideoCodecs = [preferredVideoCodec]
            }
            
            // Use the preferred encoding parameters
            if let encodingParameters = Settings.shared.getEncodingParameters() {
                builder.encodingParameters = encodingParameters
            }
            
            // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
            // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
            builder.roomName = self.roomTextField.text
        }
        
        // Connect to the Room using the options we provided.
        room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
        
        logMessage(messageText: "Attempting to connect to room \(String(describing: self.roomTextField.text))")
        
        self.showRoomUI(inRoom: true)
        self.dismissKeyboard()
    }
    
    @IBAction func disconnect(sender: AnyObject) {
        self.room!.disconnect()
        logMessage(messageText: "Attempting to disconnect from room \(room!.name)")
    }
    
    @IBAction func toggleMic(sender: AnyObject) {
        if (self.localAudioTrack != nil) {
            self.localAudioTrack?.isEnabled = !(self.localAudioTrack?.isEnabled)!
            
            // Update the button title
            if (self.localAudioTrack?.isEnabled == true) {
                self.micButton.setTitle("Mute", for: .normal)
            } else {
                self.micButton.setTitle("Unmute", for: .normal)
            }
        }
    }

    // MARK: Private
    func startPreview() {
        if PlatformUtils.isSimulator {
            return
        }

        let frontCamera = CameraSource.captureDevice(position: .front)
        let backCamera = CameraSource.captureDevice(position: .back)

        if (frontCamera != nil || backCamera != nil) {
            // Preview our local camera track in the local video preview view.
            camera = CameraSource(delegate: self)
            localVideoTrack = LocalVideoTrack.init(source: camera!, enabled: true, name: "Camera")

            // Add renderer to video track for local preview
            localVideoTrack!.addRenderer(self.previewView)
            logMessage(messageText: "Video track created")

            if (frontCamera != nil && backCamera != nil) {
                // We will flip camera on tap.
                let tap = UITapGestureRecognizer(target: self, action: #selector(ViewController.flipCamera))
                self.previewView.addGestureRecognizer(tap)
            }

            camera!.startCapture(device: frontCamera != nil ? frontCamera! : backCamera!) { (captureDevice, videoFormat, error) in
                if let error = error {
                    self.logMessage(messageText: "Capture failed with error.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                } else {
                    self.previewView.shouldMirror = (captureDevice.position == .front)
                }
            }
        }
        else {
            self.logMessage(messageText:"No front or back capture device found!")
        }
    }

    @objc func flipCamera() {
        var newDevice: AVCaptureDevice?

        if let camera = self.camera, let captureDevice = camera.device {
            if captureDevice.position == .front {
                newDevice = CameraSource.captureDevice(position: .back)
            } else {
                newDevice = CameraSource.captureDevice(position: .front)
            }

            if let newDevice = newDevice {
                camera.selectCaptureDevice(newDevice) { (captureDevice, videoFormat, error) in
                    if let error = error {
                        self.logMessage(messageText: "Error selecting capture device.\ncode = \((error as NSError).code) error = \(error.localizedDescription)")
                    } else {
                        self.previewView.shouldMirror = (captureDevice.position == .front)
                    }
                }
            }
        }
    }

    func prepareLocalMedia() {

        // We will share local audio and video when we connect to the Room.

        // Create an audio track.
        if (localAudioTrack == nil) {
            localAudioTrack = LocalAudioTrack.init(options: nil, enabled: true, name: "Microphone")

            if (localAudioTrack == nil) {
                logMessage(messageText: "Failed to create audio track")
            }
        }

        // Create a video track which captures from the camera.
        if (localVideoTrack == nil) {
            self.startPreview()
        }
   }

    // Update our UI based upon if we are in a Room or not
    func showRoomUI(inRoom: Bool) {
        self.connectButton.isHidden = inRoom
        self.roomTextField.isHidden = inRoom
        self.roomLine.isHidden = inRoom
        self.roomLabel.isHidden = inRoom
        self.micButton.isHidden = !inRoom
        self.disconnectButton.isHidden = !inRoom
        self.navigationController?.setNavigationBarHidden(inRoom, animated: true)
        UIApplication.shared.isIdleTimerDisabled = inRoom

        // Show / hide the automatic home indicator on modern iPhones.
        if #available(iOS 11.0, *) {
            self.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }
    
    @objc func dismissKeyboard() {
        if (self.roomTextField.isFirstResponder) {
            self.roomTextField.resignFirstResponder()
        }
    }
    
    func cleanupRemoteParticipant() {
        if ((self.remoteParticipant) != nil) {
            if ((self.remoteParticipant?.videoTracks.count)! > 0) {
                let remoteVideoTrack = self.remoteParticipant?.remoteVideoTracks[0].remoteTrack
                remoteVideoTrack?.removeRenderer(self.remoteView!)
                self.remoteView?.removeFromSuperview()
                self.remoteView = nil
            }
        }
        self.remoteParticipant = nil
    }
    
    func logMessage(messageText: String) {
        NSLog(messageText)
        messageLabel.text = messageText
    }
}

// MARK: UITextFieldDelegate
extension ViewController : UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.connectAction()
        return true
    }
}

// MARK: TVIRoomDelegate
extension ViewController : RoomDelegate {
    func didConnect(to room: Room) {
        
        // At the moment, this example only supports rendering one Participant at a time.
        
        logMessage(messageText: "Connected to room \(room.name) as \(String(describing: room.localParticipant?.identity))")
        
        if (room.remoteParticipants.count > 0) {
            self.remoteParticipant = room.remoteParticipants[0]
            self.remoteParticipant?.delegate = self
        }
    }
    
    func roomDidDisconnect(room: Room, error: Error?) {
        logMessage(messageText: "Disconnected from room \(room.name), error = \(String(describing: error))")
        
        self.cleanupRemoteParticipant()
        self.room = nil
        
        self.showRoomUI(inRoom: false)
    }
    
    func roomDidFailToConnect(room: Room, error: Error) {
        logMessage(messageText: "Failed to connect to room with error")
        self.room = nil
        self.accessToken = nil
        
        self.showRoomUI(inRoom: false)
    }

    func roomIsReconnecting(room: Room, error: Error) {
        logMessage(messageText: "Reconnecting to room \(room.name), error = \(String(describing: error))")
    }

    func didReconnect(to room: Room) {
        logMessage(messageText: "Reconnected to room \(room.name)")
    }
    
    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        if (self.remoteParticipant == nil) {
            self.remoteParticipant = participant
            self.remoteParticipant?.delegate = self
        }
       logMessage(messageText: "Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
    }
    
    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        if (self.remoteParticipant == participant) {
            cleanupRemoteParticipant()
        }
        logMessage(messageText: "Room \(room.name), Participant \(participant.identity) disconnected")
    }
}

// MARK: TVIRemoteParticipantDelegate
extension ViewController : RemoteParticipantDelegate {
    
    func remoteParticipant(_ participant: RemoteParticipant,
                           publishedVideoTrack publication: RemoteVideoTrackPublication) {
        
        // Remote Participant has offered to share the video Track.
        
        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) video track")
    }

    func remoteParticipant(_ participant: RemoteParticipant,
                           unpublishedVideoTrack publication: RemoteVideoTrackPublication) {
        
        // Remote Participant has stopped sharing the video Track.

        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) video track")
    }

    func remoteParticipant(_ participant: RemoteParticipant,
                           publishedAudioTrack publication: RemoteAudioTrackPublication) {
        
        // Remote Participant has offered to share the audio Track.

        logMessage(messageText: "Participant \(participant.identity) published \(publication.trackName) audio track")
    }

    func remoteParticipant(_ participant: RemoteParticipant,
                           unpublishedAudioTrack publication: RemoteAudioTrackPublication) {
        
        // Remote Participant has stopped sharing the audio Track.

        logMessage(messageText: "Participant \(participant.identity) unpublished \(publication.trackName) audio track")
    }

    func subscribed(to videoTrack: RemoteVideoTrack,
                    publication: RemoteVideoTrackPublication,
                    for participant: RemoteParticipant) {
        
        // We are subscribed to the remote Participant's video Track. We will start receiving the
        // remote Participant's video frames now.
        
        logMessage(messageText: "Subscribed to \(publication.trackName) video track for Participant \(participant.identity)")

        if (self.remoteParticipant == participant) {
            setupRemoteVideoView()
            videoTrack.addRenderer(self.remoteView!)
        }
    }
    
    func unsubscribed(from videoTrack: RemoteVideoTrack,
                      publication: RemoteVideoTrackPublication,
                      for participant: RemoteParticipant) {
        
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")

        if (self.remoteParticipant == participant) {
            videoTrack.removeRenderer(self.remoteView!)
            self.remoteView?.removeFromSuperview()
            self.remoteView = nil
        }
    }
    
    func subscribed(to audioTrack: RemoteAudioTrack,
                    publication: RemoteAudioTrackPublication,
                    for participant: RemoteParticipant) {
        
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.
       
        logMessage(messageText: "Subscribed to \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
    func unsubscribed(from audioTrack: RemoteAudioTrack,
                      publication: RemoteAudioTrackPublication,
                      for participant: RemoteParticipant) {
        
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.
        
        logMessage(messageText: "Unsubscribed from \(publication.trackName) audio track for Participant \(participant.identity)")
    }
    
    func remoteParticipant(_ participant: RemoteParticipant,
                           enabledVideoTrack publication: RemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) video track")
    }
    
    func remoteParticipant(_ participant: RemoteParticipant,
                           disabledVideoTrack publication: RemoteVideoTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) video track")
    }
    
    func remoteParticipant(_ participant: RemoteParticipant,
                           enabledAudioTrack publication: RemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) enabled \(publication.trackName) audio track")
    }
    
    func remoteParticipant(_ participant: RemoteParticipant,
                           disabledAudioTrack publication: RemoteAudioTrackPublication) {
        logMessage(messageText: "Participant \(participant.identity) disabled \(publication.trackName) audio track")
    }

    func failedToSubscribe(toAudioTrack publication: RemoteAudioTrackPublication,
                           error: Error,
                           for participant: RemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }

    func failedToSubscribe(toVideoTrack publication: RemoteVideoTrackPublication,
                           error: Error,
                           for participant: RemoteParticipant) {
        logMessage(messageText: "FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}

// MARK: TVIVideoViewDelegate
extension ViewController : VideoViewDelegate {
    func videoViewDimensionsDidChange(view: VideoView, dimensions: CMVideoDimensions) {
        self.view.setNeedsLayout()
    }
}

// MARK: TVICameraSourceDelegate
extension ViewController : CameraSourceDelegate {
    func cameraSourceDidFail(source: CameraSource, error: Error) {
        logMessage(messageText: "Camera source failed with error: \(error.localizedDescription)")
    }
}
