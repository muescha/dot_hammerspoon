// Action Generic Video

(function () {

    const action = "{{ action }}";

    function log(value) {
        console.log(value);

        return value;
    }

    log(`Action: ${action}`);

    class MediaController {

        static actions = new Set([
            "isGeneric",
            "doPause",
            "speedInc",
            "speedDec",
            "maxSpeed",
            "speedReset",
            "moveForward",
            "moveBackward",
            "nil"
        ]);

        static strategies = {
            speed: {
                inc(currentSpeed) {
                    return currentSpeed + (
                        currentSpeed >= 1
                            ? 0.5
                            : 0.25
                    );
                },

                dec(currentSpeed) {
                    return currentSpeed - (
                        currentSpeed <= 1
                            ? 0.25
                            : 0.5
                    );
                }
            },

            time: {
                forward(currentTime, jump) {
                    return currentTime + jump;
                },

                backward(currentTime, jump) {
                    return currentTime - jump;
                }
            }
        };

        static computeJumpSeconds(
            rate,
            base = 4,
            minJump = 3,
            maxJump = 30
        ) {
            const safeRate = Math.max(0.1, rate || 1);

            return Math.min(
                maxJump,
                Math.max(minJump, base * safeRate)
            );
        }

        static formatTime(
            timestampInSeconds,
            showMilliseconds = false
        ) {
            const hoursValue = Math.floor(
                timestampInSeconds / 3600
            );
            const minutesValue = Math.floor(
                (timestampInSeconds % 3600) / 60
            );
            const secondsValue = Math.floor(
                timestampInSeconds % 60
            );
            const millisecondsValue = Math.floor(
                (timestampInSeconds % 1) * 1000
            );

            const hours = hoursValue
                .toString()
                .padStart(2, "0");
            const minutes = minutesValue
                .toString()
                .padStart(2, "0");
            const seconds = secondsValue
                .toString()
                .padStart(2, "0");
            const milliseconds = millisecondsValue
                .toString()
                .padStart(4, "0");

            return showMilliseconds
                ? `${hours}:${minutes}:${seconds}.${milliseconds}`
                : `${hours}:${minutes}:${seconds}`;
        }

        constructor(mediaAdapter) {
            this.mediaAdapter = mediaAdapter;
        }

        hasAction(action) {
            return MediaController.actions.has(action)
                && typeof this[action] === "function";
        }

        executeAction(action) {
            if (!this.hasAction(action)) {
                const info = `no function controller.${action}() found - params.action="${action}"`;

                return log(info);
            }

            return log(this[action]());
        }

        isGeneric() {
            return this.mediaAdapter.getMediaType();
        }

        doPause() {
            if (this.mediaAdapter.isPaused()) {
                this.mediaAdapter.play();
            } else {
                this.mediaAdapter.pause();
            }

            return this.mediaAdapter.isPaused();
        }

        changeSpeed(calculateSpeed) {
            const currentSpeed = this.mediaAdapter.getPlaybackRate();

            this.mediaAdapter.setPlaybackRate(
                calculateSpeed(currentSpeed)
            );

            return this.mediaAdapter.getPlaybackRate();
        }

        speedInc() {
            return this.changeSpeed(
                MediaController.strategies.speed.inc
            );
        }

        speedDec() {
            return this.changeSpeed(
                MediaController.strategies.speed.dec
            );
        }

        maxSpeed() {
            this.mediaAdapter.setMaxPlaybackRate();

            if (this.mediaAdapter.skipAd()) {
                return `${this.mediaAdapter.getPlaybackRate()} & skipButton clicked`;
            }

            return this.mediaAdapter.getPlaybackRate();
        }

        speedReset() {
            this.mediaAdapter.resetPlaybackRate();

            return this.mediaAdapter.getPlaybackRate();
        }

        changeTime(calculateTime, operator) {
            const jump = MediaController.computeJumpSeconds(
                this.mediaAdapter.getPlaybackRate()
            );
            const currentTime = this.mediaAdapter.getCurrentTime();

            const info = MediaController.formatTime(currentTime)
                + " "
                + operator
                + " "
                + jump
                + " = ";

            this.mediaAdapter.setCurrentTime(
                calculateTime(currentTime, jump)
            );

            return info + MediaController.formatTime(
                this.mediaAdapter.getCurrentTime()
            );
        }

        moveForward() {
            return this.changeTime(
                MediaController.strategies.time.forward,
                "+"
            );
        }

        moveBackward() {
            return this.changeTime(
                MediaController.strategies.time.backward,
                "-"
            );
        }

        nil() {
            return "function not defined in params.action";
        }
    }

    class NativeMediaAdapter {

        constructor(player) {
            this.player = player;
        }

        static detect() {
            const player = document.querySelector("video, audio");

            return player
                ? new NativeMediaAdapter(player)
                : null;
        }

        getPlayer() {
            return this.player;
        }

        getMediaType() {
            return this.player.tagName;
        }

        isPaused() {
            return this.player.paused;
        }

        play() {
            return this.player.play();
        }

        pause() {
            return this.player.pause();
        }

        getPlaybackRate() {
            return this.player.playbackRate;
        }

        setPlaybackRate(value) {
            this.player.playbackRate = value;
        }

        getDefaultPlaybackRate() {
            return this.player.defaultPlaybackRate;
        }

        resetPlaybackRate() {
            this.setPlaybackRate(
                this.getDefaultPlaybackRate()
            );
        }

        getMaxPlaybackRate() {
            return 16;
        }

        setMaxPlaybackRate() {
            this.setPlaybackRate(
                this.getMaxPlaybackRate()
            );
        }

        getCurrentTime() {
            return this.player.currentTime;
        }

        setCurrentTime(value) {
            this.player.currentTime = value;
        }

        skipAd() {
            const skipButton = document.querySelector(
                "button.ytp-skip-ad-button"
            );

            log(skipButton);

            if (skipButton) {
                skipButton.click();
                return true;
            }

            return false;
        }
    }

    class YouTubePostMessageAdapter {

        static iframeSelector =
            'iframe[src*="youtube.com/embed/"], '
            + 'iframe[src*="youtube-nocookie.com/embed/"]';

        static listenerFlag = "pgcYt";
        static stateKey = "pgcYtState";
        static overlayClass =
            "player-global-control-youtube-loading";

        constructor(iframe) {
            this.iframe = iframe;
        }

        static readState() {
            const raw =
                document.documentElement.dataset[this.stateKey];

            if (!raw) {
                return null;
            }

            try {
                return JSON.parse(raw);
            } catch (_) {
                return null;
            }
        }

        static writeState(next) {
            document.documentElement.dataset[this.stateKey] =
                JSON.stringify(next);
        }

        static mergeState(patch) {
            const prev = this.readState() || {};

            Object.assign(prev, patch, { at: Date.now() });
            this.writeState(prev);
        }

        static installListener() {
            if (
                document.documentElement.dataset[this.listenerFlag]
                === "1"
            ) {
                return;
            }

            window.addEventListener("message", event => {
                if (typeof event.data !== "string") {
                    return;
                }

                let message;

                try {
                    message = JSON.parse(event.data);
                } catch (_) {
                    return;
                }

                if (
                    !message
                    || !message.info
                    || (
                        message.event !== "infoDelivery"
                        && message.event !== "initialDelivery"
                        && message.event !== "apiInfoDelivery"
                    )
                ) {
                    return;
                }

                const info = message.info;
                const patch = {};

                if (info.currentTime !== undefined) {
                    patch.currentTime = info.currentTime;
                }
                if (info.playbackRate !== undefined) {
                    patch.playbackRate = info.playbackRate;
                }
                if (info.playerState !== undefined) {
                    patch.playerState = info.playerState;
                }
                if (info.duration !== undefined) {
                    patch.duration = info.duration;
                }
                if (info.availablePlaybackRates !== undefined) {
                    patch.rates = info.availablePlaybackRates;
                }

                YouTubePostMessageAdapter.mergeState(patch);

                const readyIframe = document.querySelector(
                    YouTubePostMessageAdapter.iframeSelector
                );

                if (readyIframe) {
                    YouTubePostMessageAdapter.removeOverlay(
                        readyIframe
                    );
                }
            });

            document.documentElement.dataset[this.listenerFlag] =
                "1";
        }

        static sendListening(iframe) {
            iframe.contentWindow.postMessage(
                JSON.stringify({
                    event: "listening",
                    id: 1,
                    channel: "widget"
                }),
                "*"
            );
        }

        static showOverlay(iframe, message, isError = false) {
            const parent = iframe.parentElement;

            if (!parent) {
                return;
            }

            if (getComputedStyle(parent).position === "static") {
                parent.dataset.pgcYtPos =
                    parent.style.position || "";
                parent.style.position = "relative";
            }

            let overlay = parent.querySelector(
                ":scope > ." + this.overlayClass
            );

            if (!overlay) {
                overlay = document.createElement("div");
                overlay.className = this.overlayClass;

                Object.assign(overlay.style, {
                    position: "absolute",
                    inset: "0",
                    zIndex: "2147483647",
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    padding: "24px",
                    boxSizing: "border-box",
                    background: "rgba(0, 0, 0, 0.78)",
                    color: "#ffffff",
                    fontFamily: "system-ui, sans-serif",
                    fontSize: "18px",
                    fontWeight: "600",
                    textAlign: "center",
                    pointerEvents: "none"
                });

                parent.appendChild(overlay);
            }

            overlay.textContent = message;
            overlay.style.background = isError
                ? "rgba(120, 0, 0, 0.88)"
                : "rgba(0, 0, 0, 0.78)";

            // Guarantee the connecting overlay never lingers: even if no
            // infoDelivery arrives (e.g. a paused video), auto-remove it
            // after a short warmup window. Data arrival removes it sooner
            // via the message listener.
            if (!isError) {
                setTimeout(
                    () => this.removeOverlay(iframe),
                    3000
                );
            }
        }

        static removeOverlay(iframe) {
            const parent = iframe.parentElement;

            if (!parent) {
                return;
            }

            const overlay = parent.querySelector(
                ":scope > ." + this.overlayClass
            );

            if (overlay) {
                overlay.remove();
            }

            if (
                Object.prototype.hasOwnProperty.call(
                    parent.dataset,
                    "pgcYtPos"
                )
            ) {
                parent.style.position = parent.dataset.pgcYtPos;
                delete parent.dataset.pgcYtPos;
            }
        }

        static detect() {
            const iframe = document.querySelector(
                this.iframeSelector
            );

            if (!iframe) {
                return null;
            }

            this.installListener();

            let url;

            try {
                url = new URL(iframe.src);
            } catch (_) {
                url = null;
            }

            if (
                url
                && url.searchParams.get("enablejsapi") !== "1"
            ) {
                url.searchParams.set("enablejsapi", "1");

                this.showOverlay(iframe, "YouTube connecting…");

                iframe.addEventListener(
                    "load",
                    () => this.sendListening(iframe),
                    { once: true }
                );

                iframe.src = url.toString();

                return {
                    mediaAdapter: null,
                    status: "YouTube connecting…"
                };
            }

            this.sendListening(iframe);

            if (this.readState()) {
                this.removeOverlay(iframe);

                return {
                    mediaAdapter:
                        new YouTubePostMessageAdapter(iframe),
                    status: "YouTube iframe player ready"
                };
            }

            this.showOverlay(iframe, "YouTube connecting…");

            return {
                mediaAdapter: null,
                status: "YouTube connecting…"
            };
        }

        getPlayer() {
            return this.iframe;
        }

        getMediaType() {
            return "YOUTUBE_IFRAME";
        }

        postCommand(func, args = []) {
            this.iframe.contentWindow.postMessage(
                JSON.stringify({
                    event: "command",
                    func: func,
                    args: args
                }),
                "*"
            );
        }

        isPaused() {
            const state =
                YouTubePostMessageAdapter.readState();

            return !state || state.playerState !== 1;
        }

        play() {
            return this.postCommand("playVideo");
        }

        pause() {
            return this.postCommand("pauseVideo");
        }

        getPlaybackRate() {
            const state =
                YouTubePostMessageAdapter.readState();

            return state && state.playbackRate != null
                ? state.playbackRate
                : 1;
        }

        clampRate(value) {
            const state =
                YouTubePostMessageAdapter.readState();
            const rates = (state && state.rates) || [];

            const min = rates.length ? rates[0] : 0.25;
            const max = rates.length
                ? rates[rates.length - 1]
                : 2;

            return Math.min(max, Math.max(min, value));
        }

        setPlaybackRate(value) {
            const rate = this.clampRate(value);

            this.postCommand("setPlaybackRate", [rate]);
            YouTubePostMessageAdapter.mergeState({
                playbackRate: rate
            });
        }

        getDefaultPlaybackRate() {
            return 1;
        }

        resetPlaybackRate() {
            this.setPlaybackRate(
                this.getDefaultPlaybackRate()
            );
        }

        getMaxPlaybackRate() {
            const state =
                YouTubePostMessageAdapter.readState();
            const rates = state && state.rates;

            return (rates && rates.length)
                ? rates[rates.length - 1]
                : 2;
        }

        setMaxPlaybackRate() {
            this.setPlaybackRate(
                this.getMaxPlaybackRate()
            );
        }

        getCurrentTime() {
            const state =
                YouTubePostMessageAdapter.readState();

            return state && state.currentTime != null
                ? state.currentTime
                : 0;
        }

        setCurrentTime(value) {
            const target = Math.max(0, value);

            this.postCommand("seekTo", [target, true]);
            YouTubePostMessageAdapter.mergeState({
                currentTime: target
            });
        }

        skipAd() {
            const skipButton = document.querySelector(
                "button.ytp-skip-ad-button"
            );

            if (skipButton) {
                skipButton.click();
                return true;
            }

            return false;
        }
    }

    const adapters = [
        NativeMediaAdapter,
        YouTubePostMessageAdapter
    ];

    function findMediaAdapter() {
        for (const adapter of adapters) {
            log(`checking adapter: ${adapter.name}`);

            const detectionResult = adapter.detect();

            log({
                adapter: adapter.name,
                detectionResult
            });

            if (!detectionResult) {
                continue;
            }

            if (
                detectionResult.mediaAdapter !== undefined
                || detectionResult.status !== undefined
            ) {
                return detectionResult;
            }

            return {
                mediaAdapter: detectionResult,
                status: `${adapter.name} detected`
            };
        }

        return null;
    }

    const detectionResult = findMediaAdapter();

    if (!detectionResult) {
        return log("no supported player found");
    }

    if (!detectionResult.mediaAdapter) {
        return log(detectionResult.status);
    }

    const mediaAdapter =
        detectionResult.mediaAdapter;

    log("Generic Player:");
    log(mediaAdapter.getPlayer());

    const controller = new MediaController(mediaAdapter);

    return controller.executeAction(action);

})();