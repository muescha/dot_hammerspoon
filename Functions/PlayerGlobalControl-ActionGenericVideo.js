// Action Generic Video

(function () {

    const action = "{{ action }}";

    function log(...values) {
        console.log("[PGC]", ...values);

        return values[0];
    }

    log(`Action: ${action}`);

    class MediaController {

        static actions = new Set([
            "isGeneric",
            "play",
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

        play() {
            this.mediaAdapter.play();

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

                log("EventListener:message:", message);

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
            log("sendListening(iframe)");
            iframe.contentWindow.postMessage(
                JSON.stringify({
                    event: "listening",
                    id: 1,
                    channel: "widget"
                }),
                "*"
            );
        }

        // After sendListening() the player may report on its own (mini.html
        // autoplays; a player the user has started keeps streaming). Give it a
        // short grace period, then react to what we heard -- we never force a
        // muted warmup start, because a muted start cannot be un-muted without a
        // real page gesture (Hammerspoon keys don't count) and would leave the
        // video stuck muted. If it is silent, we simply wait for the user to
        // press play once (with sound); then it reports and becomes controllable.
        static scheduleStateProbe(iframe, delayMs = 400) {
            setTimeout(() => {
                const state = this.readState();

                if (state) {
                    // We joined mid-playback: the ongoing infoDelivery stream
                    // carries currentTime but usually NOT playerState (that only
                    // comes on state CHANGES, which happened before our listener
                    // existed). A flowing stream means it is playing, so seed a
                    // playing state -- otherwise isPaused() stays wrongly true and
                    // doPause() only ever calls play(). Real pause/play commands
                    // emit a fresh playerState afterwards and keep it in sync.
                    log("scheduleStateProbe: reporting -> seed playerState");
                    if (state.playerState === undefined) {
                        this.mergeState({ playerState: 1 });
                    }
                } else {
                    log("scheduleStateProbe: still silent -> wait for user play");
                }
                this.removeOverlay(iframe);
            }, delayMs);
        }

        static showOverlay(iframe, message) {
            const parent = iframe.parentElement;

            if (!parent) {
                return;
            }

            log("showOverlay:message:", message);

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

            // Bump a monotonic counter on this element for every show (create
            // OR recycle) and schedule a timer that captures that id. Only the
            // newest id matches when a timer fires, so older timers become
            // no-ops -> the overlay is auto-removed exactly the warmup window
            // after the LAST message, never sooner. A DOM counter (not
            // Date.now/UUID) is used deliberately: it is collision-free even
            // for multiple shows within the same millisecond, and works on
            // plain http where crypto.randomUUID is unavailable. The reset
            // travels purely through the shared DOM, so a recycled show from a
            // fresh injected script context needs no reference to the timer.
            const showId =
                (Number(overlay.dataset.pgcShowId) || 0) + 1;

            overlay.dataset.pgcShowId = String(showId);
            overlay.textContent = message;
            log("showOverlay #" + showId + ": " + message)

            this.scheduleOverlayTimeout(iframe, overlay, showId);
        }

        static scheduleOverlayTimeout(iframe, overlay, showId) {
            setTimeout(
                () => {
                    // My element was already removed (e.g. by an infoDelivery).
                    // Do nothing so this stale timer can't touch a newer
                    // overlay that may have replaced it.
                    if (!overlay.isConnected) {
                        log(
                            "removeOverlay: skipped - overlay #",
                            showId,
                            "already gone"
                        );
                        return;
                    }

                    // A newer message recycled this element and bumped the
                    // id. That newer show scheduled its own timer, so this
                    // one just steps aside.
                    if (
                        overlay.dataset.pgcShowId !== String(showId)
                    ) {
                        log(
                            "removeOverlay: skipped - overlay #",
                            showId,
                            "replaced by #",
                            overlay.dataset.pgcShowId
                        );
                        return;
                    }

                    log("removeOverlay: remove overlay #", showId);
                    this.removeOverlay(iframe);
                },
                3000
            );
        }

        static removeOverlay(iframe) {
            const parent = iframe.parentElement;

            log("removeOverlay:Start");

            if (!parent) {
                log("removeOverlay:NoParent:exit");
                return;
            }

            const overlay = parent.querySelector(
                ":scope > ." + this.overlayClass
            );

            if (overlay) {
                log("removeOverlay:OverlayExists:Remove");
                overlay.remove();
            } else {
                log("removeOverlay:NoOverlay:exit");
            }

            if (
                Object.prototype.hasOwnProperty.call(
                    parent.dataset,
                    "pgcYtPos"
                )
            ) {
                parent.style.position = parent.dataset.pgcYtPos;
                log("removeOverlay:pgcYtPos exists:delete:parent.dataset.pgcYtPos");
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
                // Third-party embed without the JS API. We MUST reload once to
                // turn it on -- but deliberately do NOT force autoplay+mute+
                // warmup here: on a cross-origin embed Chrome only allows MUTED
                // autoplay, and a muted warmup can never be un-muted again
                // without a real user gesture (Hammerspoon key events don't
                // count) -> the video ends up stuck muted / "broken". Instead we
                // just enable the API and leave the poster untouched. The user
                // presses the real Big Play button once (a genuine gesture ->
                // plays WITH sound); after that infoDelivery fills the cache and
                // hyper+O controls it normally.
                url.searchParams.set("enablejsapi", "1");

                this.showOverlay(iframe, "YouTube: Play drücken");

                iframe.addEventListener(
                    "load",
                    () => {
                        log("Eventlistener:Event:load (enable jsapi only)");
                        this.sendListening(iframe);
                    },
                    { once: true }
                );

                iframe.src = url.toString();

                return {
                    mediaAdapter: null,
                    status: "YouTube: Play drücken"
                };
            }

            this.sendListening(iframe);
            log("readState:test");
            if (this.readState()) {
                log("readState:ok");
                log("removeOverlay: readstate");
                this.removeOverlay(iframe);

                return {
                    mediaAdapter:
                        new YouTubePostMessageAdapter(iframe),
                    status: "YouTube iframe player ready"
                };
            }

            // Cache still empty. The player might already be autoplaying on its
            // own (mini.html sets autoplay) -- sendListening() above makes it
            // report within a moment. Show the overlay and give it a short grace
            // period to hear back (see scheduleStateProbe). If it stays silent
            // the user just needs to press play once (with sound).
            this.showOverlay(iframe, "YouTube connecting…");
            this.scheduleStateProbe(iframe);

            return {
                mediaAdapter: null,
                status: "YouTube connecting…"
            };
        }

        getPlayer() {
            return this.iframe;
        }

        getMediaType() {
            return "YouTube IFrame";
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