import SwiftUI
import WebKit

enum YouTubePlayerPlaybackState: Equatable {
    case idle
    case ready
    case playing
    case paused
    case buffering
    case ended
    case cued
}

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String
    let requestedSeekTime: Double?
    let onReady: (Double) -> Void
    let onPlaybackStateChange: (YouTubePlayerPlaybackState) -> Void
    let onTimeUpdate: (Double, Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: Coordinator.messageHandlerName)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        context.coordinator.attach(webView)
        context.coordinator.load(videoID: videoID)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.load(videoID: videoID)
        if let requestedSeekTime {
            context.coordinator.seek(to: requestedSeekTime)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.messageHandlerName)
    }
}

extension YouTubePlayerView {
    final class Coordinator: NSObject, WKScriptMessageHandler {
        static let messageHandlerName = "youtubePlayer"

        var parent: YouTubePlayerView
        private weak var webView: WKWebView?
        private var loadedVideoID: String?
        private var lastSeekTime: Double?
        private var pendingSeekTime: Double?
        private var isPlayerReady = false

        init(parent: YouTubePlayerView) {
            self.parent = parent
        }

        func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        func load(videoID: String) {
            guard loadedVideoID != videoID, let webView else { return }
            loadedVideoID = videoID
            lastSeekTime = nil
            pendingSeekTime = nil
            isPlayerReady = false
            webView.loadHTMLString(
                html(for: videoID),
                baseURL: refererURL()
            )
        }

        func seek(to seconds: Double) {
            guard let webView else { return }
            guard let loadedVideoID else { return }
            let clampedSeconds = max(0, seconds)
            if let lastSeekTime, abs(lastSeekTime - clampedSeconds) < 0.2 {
                return
            }
            self.loadedVideoID = loadedVideoID

            guard isPlayerReady else {
                pendingSeekTime = clampedSeconds
                return
            }

            performSeek(clampedSeconds, in: webView)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.messageHandlerName,
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                return
            }

            switch type {
            case "ready":
                isPlayerReady = true
                let duration = body["duration"] as? Double ?? 0
                parent.onReady(duration)
                parent.onPlaybackStateChange(.ready)
                flushPendingSeekIfNeeded()
            case "state":
                let stateCode = body["value"] as? Int ?? -2
                parent.onPlaybackStateChange(playbackState(for: stateCode))
            case "time":
                let currentTime = body["currentTime"] as? Double ?? 0
                let duration = body["duration"] as? Double ?? 0
                parent.onTimeUpdate(currentTime, duration)
            default:
                break
            }
        }

        private func flushPendingSeekIfNeeded() {
            guard isPlayerReady, let pendingSeekTime, let webView else { return }
            self.pendingSeekTime = nil
            performSeek(pendingSeekTime, in: webView)
        }

        private func performSeek(_ seconds: Double, in webView: WKWebView) {
            lastSeekTime = seconds
            let script = "window.languageReaderPlayerBridge && window.languageReaderPlayerBridge.seekTo(\(seconds));"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        private func playbackState(for code: Int) -> YouTubePlayerPlaybackState {
            switch code {
            case 0:
                return .ended
            case 1:
                return .playing
            case 2:
                return .paused
            case 3:
                return .buffering
            case 5:
                return .cued
            default:
                return .idle
            }
        }

        private func refererURL() -> URL? {
            let bundleID = (Bundle.main.bundleIdentifier ?? "com.local.languagereader").lowercased()
            return URL(string: "https://\(bundleID)")
        }

        private func html(for videoID: String) -> String {
            let origin = refererURL()?.absoluteString ?? "https://com.local.languagereader"
            return """
            <!DOCTYPE html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
              <style>
                html, body {
                  margin: 0;
                  padding: 0;
                  background: #000;
                  width: 100%;
                  height: 100%;
                  overflow: hidden;
                }
                #player {
                  width: 100%;
                  height: 100%;
                }
              </style>
            </head>
            <body>
              <div id="player"></div>
              <script>
                let player;
                let pollTimer = null;

                function postMessage(payload) {
                  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.youtubePlayer) {
                    window.webkit.messageHandlers.youtubePlayer.postMessage(payload);
                  }
                }

                function publishTime() {
                  if (!player || typeof player.getCurrentTime !== 'function') {
                    return;
                  }
                  postMessage({
                    type: 'time',
                    currentTime: player.getCurrentTime() || 0,
                    duration: player.getDuration() || 0
                  });
                }

                function startPolling() {
                  stopPolling();
                  pollTimer = window.setInterval(publishTime, 250);
                }

                function stopPolling() {
                  if (pollTimer !== null) {
                    window.clearInterval(pollTimer);
                    pollTimer = null;
                  }
                }

                window.languageReaderPlayerBridge = {
                  seekTo(seconds) {
                    if (!player || typeof player.seekTo !== 'function') {
                      return;
                    }
                    player.seekTo(seconds, true);
                    publishTime();
                  }
                };

                function onYouTubeIframeAPIReady() {
                  player = new YT.Player('player', {
                    videoId: '\(videoID)',
                    playerVars: {
                      playsinline: 1,
                      rel: 0,
                      origin: '\(origin)'
                    },
                    events: {
                      onReady: function() {
                        postMessage({
                          type: 'ready',
                          duration: player.getDuration() || 0
                        });
                        startPolling();
                        publishTime();
                      },
                      onStateChange: function(event) {
                        postMessage({
                          type: 'state',
                          value: event.data
                        });
                        if (event.data === YT.PlayerState.PLAYING) {
                          startPolling();
                        } else if (event.data === YT.PlayerState.PAUSED || event.data === YT.PlayerState.ENDED) {
                          publishTime();
                        }
                      }
                    }
                  });
                }

                const tag = document.createElement('script');
                tag.src = 'https://www.youtube.com/iframe_api';
                document.head.appendChild(tag);
              </script>
            </body>
            </html>
            """
        }
    }
}
