//
//  VideoPlayerView.swift
//  YouTubePlayer
//
//  Created by Giles Van Gruisen on 12/21/14.
//  Copyright (c) 2014 Giles Van Gruisen. All rights reserved.
//

import UIKit

// MARK: - YouTubePlayer Enums

/// Player state.
public enum YouTubePlayerState: String {
    case Unstarted = "-1"
    case Ended = "0"
    case Playing = "1"
    case Paused = "2"
    case Buffering = "3"
    case Queued = "4"
}

/// Player events.
public enum YouTubePlayerEvents: String {
    case YouTubeIframeAPIReady = "onYouTubeIframeAPIReady"
    case Ready = "onReady"
    case StateChange = "onStateChange"
    case PlaybackQualityChange = "onPlaybackQualityChange"
}

/// Video quality.
public enum YouTubePlaybackQuality: String {
    case Small = "small"
    case Medium = "medium"
    case Large = "large"
    case HD720 = "hd720"
    case HD1080 = "hd1080"
    case HighResolution = "highres"
}

// MARK: - YouTubePlayerDelegate Protocol

public protocol YouTubePlayerDelegate {
    func playerReady(videoPlayer: YouTubePlayerView)
	
	func playerStateChanged(videoPlayer: YouTubePlayerView, playerState: YouTubePlayerState)
	
	func playerQualityChanged(videoPlayer: YouTubePlayerView,
		playbackQuality: YouTubePlaybackQuality)
}

private extension NSURL {
    func queryStringComponents() -> [String: AnyObject] {

        var dict = [String: AnyObject]()

        // Check for query string
        if let query = self.query {

            // Loop through pairings (separated by &)
            for pair in query.componentsSeparatedByString("&") {

                // Pull key, val from from pair parts (separated by =) and set dict[key] = value
                let components = pair.componentsSeparatedByString("=")
                dict[components[0]] = components[1]
            }

        }

        return dict
    }
}

public func videoIDFromYouTubeURL(videoURL: NSURL) -> String? {
    if let host = videoURL.host, pathComponents = videoURL.pathComponents where pathComponents.count > 1 && host.hasSuffix("youtu.be") {
        return pathComponents[1]
    }
    return videoURL.queryStringComponents()["v"] as? String
}

/** Embed and control YouTube videos */
public class YouTubePlayerView: UIView, UIWebViewDelegate {

    public typealias YouTubePlayerParameters = [String: AnyObject]

    private var webView: UIWebView!

    /// The readiness of the player.
    private(set) public var ready = false

    /// The current state of the video player.
    private(set) public var playerState = YouTubePlayerState.Unstarted

    /// The current playback quality of the video player.
    private(set) public var playbackQuality = YouTubePlaybackQuality.Small

    /// Used to configure the player.
    public var playerVars = YouTubePlayerParameters()

    /// Used to respond to player events.
    public var delegate: YouTubePlayerDelegate?

    // MARK: Various methods for initialization

    override public init(frame: CGRect) {
        super.init(frame: frame)
        buildWebView(playerParameters())
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        buildWebView(playerParameters())
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        // Remove web view in case it's within view hierarchy, 
		// reset frame, add as subview.
        webView.removeFromSuperview()
        webView.frame = bounds
        addSubview(webView)
    }

    // MARK: Web view initialization

    private func buildWebView(parameters: [String: AnyObject]) {
        webView = UIWebView()
        webView.allowsInlineMediaPlayback = true
        webView.mediaPlaybackRequiresUserAction = false
        webView.delegate = self
        webView.scrollView.scrollEnabled = false
    }


    // MARK: Load player

    public func loadVideoURL(videoURL: NSURL) {
        if let videoID = videoIDFromYouTubeURL(videoURL) {
            loadVideoID(videoID)
        }
    }

    public func loadVideoID(videoID: String) {
        var playerParams = playerParameters()
        playerParams["videoId"] = videoID

        loadWebViewWithParameters(playerParams)
    }

    public func loadPlaylistID(playlistID: String) {
        // No videoId necessary when listType = playlist, list = [playlist Id]
        playerVars["listType"] = "playlist"
        playerVars["list"] = playlistID

        loadWebViewWithParameters(playerParameters())
    }


    // MARK: Player controls

    public func play() {
        evaluatePlayerCommand("playVideo()")
    }

    public func pause() {
        evaluatePlayerCommand("pauseVideo()")
    }

    public func stop() {
        evaluatePlayerCommand("stopVideo()")
    }

    public func clear() {
        evaluatePlayerCommand("clearVideo()")
    }

    public func seekTo(seconds: Float, seekAhead: Bool) {
        evaluatePlayerCommand("seekTo(\(seconds), \(seekAhead))")
    }

    // MARK: Playlist controls

    public func previousVideo() {
        evaluatePlayerCommand("previousVideo()")
    }

    public func nextVideo() {
        evaluatePlayerCommand("nextVideo()")
    }

    private func evaluatePlayerCommand(command: String) {
        let fullCommand = "player." + command + ";"
        webView.stringByEvaluatingJavaScriptFromString(fullCommand)
    }

    // MARK: Player setup

    private func loadWebViewWithParameters(parameters: YouTubePlayerParameters) {
        // Get HTML from player file in bundle.
        let rawHTMLString = htmlStringWithFilePath(playerHTMLPath())!

        // Get JSON serialized parameters string.
        let jsonParameters = serializedJSON(parameters)!

        // Replace %@ in `rawHTMLString` with `jsonParameters` string.
        let htmlString = rawHTMLString.stringByReplacingOccurrencesOfString("%@",
			withString: jsonParameters)

        // Load HTML in web view.
        webView.loadHTMLString(htmlString, baseURL: nil)
    }

    private func playerHTMLPath() -> String {
        return NSBundle(forClass: self.classForCoder).pathForResource("YTPlayer",
			ofType: "html")!
    }

    private func htmlStringWithFilePath(path: String) -> String? {
		do {
            // Get HTML string from path.
            let htmlString = try NSString(contentsOfFile: path,
				encoding: NSUTF8StringEncoding)
            return htmlString as String
        } catch {
            // Error fetching HTML.
            printLog("Lookup error: no HTML file found for path.")
            return nil
        }
    }

    // MARK: Player parameters and defaults

    private func buildPlayerParameters() -> YouTubePlayerParameters {
        return [
            "height": "100%",
            "width": "100%",
            "events": buildPlayerCallbacks(),
            "playerVars": playerVars
        ]
    }

    private func buildPlayerCallbacks() -> YouTubePlayerParameters {
        return [
            "onReady": "onReady",
            "onStateChange": "onStateChange",
            "onPlaybackQualityChange": "onPlaybackQualityChange",
            "onError": "onPlayerError"
        ]
    }

    private func serializedJSON(object: AnyObject) -> String? {
        do {
            // Serialize to JSON string
            let jsonData = try NSJSONSerialization.dataWithJSONObject(object,
				options: NSJSONWritingOptions.PrettyPrinted)

            // Succeeded
            return NSString(data: jsonData, encoding: NSUTF8StringEncoding) as? String

        } catch let jsonError {

            // JSON serialization failed
            print(jsonError)
            printLog("Error parsing JSON")

            return nil
        }
    }

    // MARK: Javascript Event Handling

	public func webView(webView: UIWebView,
	shouldStartLoadWithRequest request: NSURLRequest,
	navigationType: UIWebViewNavigationType) -> Bool {
		// Check if *ytplayer* event and, if so, pass to handleJSEvent.
		if let url = request.URL where url.scheme == "ytplayer" {
			handleJSEvent(url)
		}
		return true
	}
	
    private func handleJSEvent(eventURL: NSURL) {
        // Grab the `data` component of the query string as String.
        let data = eventURL.queryComponents()["data"] as? String
		printLog("event: \(data)")
		
		guard let host = eventURL.host else { return }
		guard let event = YouTubePlayerEvents(rawValue: host) else { return }
		
		// Check event type and handle accordingly
		switch event {
		case .YouTubeIframeAPIReady:
			ready = true
			break

		case .Ready:
			delegate?.playerReady(self)
			break

		case .StateChange:
			if let newState = YouTubePlayerState(rawValue: data!) {
				playerState = newState
				delegate?.playerStateChanged(self, playerState: newState)
			}
			break

		case .PlaybackQualityChange:
			if let newQuality = YouTubePlaybackQuality(rawValue: data!) {
				playbackQuality = newQuality
				delegate?.playerQualityChanged(self, playbackQuality: newQuality)
			}
			break
		}
    }
}

// MARK: - Etc

public extension NSURL {
	
	private func queryComponents() -> [String: AnyObject] {
		// Check for query string.
		guard let query = self.query else { return [:] }

		// Loop through pairings (ie, separated by &).
		var queryComponents = [String: AnyObject]()
		for pair in query.componentsSeparatedByString("&") {
			// Pull key=val from from pair parts.
			let keyAndValue = pair.componentsSeparatedByString("=")
			queryComponents[keyAndValue[0]] = keyAndValue[1]
		}
		return queryComponents
	}
	
	public func videoIdFromYouTubeURL() -> String? {
		if let host = self.host, pathComponents = self.pathComponents
			where pathComponents.count > 1 && host.hasSuffix("youtu.be") {
				return pathComponents[1]
		}
		return self.queryComponents()["v"] as? String
	}
}

private func printLog(strings: String...) {
    let toPrint = ["[YouTubePlayer]"] + strings
    print(toPrint, separator: " ", terminator: "\n")
}
