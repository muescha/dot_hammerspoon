// Action Generic Video

(function () {

    const action = "{{ action }}";

    function log(...values) {
        console.log(...values);

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
                    YouTubePostMessageAdapter.finishWarmup(
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

        static sendCommand(iframe, func, args = []) {
            iframe.contentWindow.postMessage(
                JSON.stringify({
                    event: "command",
                    func: func,
                    args: args
                }),
                "*"
            );
        }

        // Force the player to actually start so YouTube begins emitting
        // infoDelivery. currentTime/duration are only reported once playback
        // has begun -- until then the cache stays empty and every command sees
        // "connecting…". Chrome blocks unmuted, script-initiated playback
        // because Hammerspoon key events are not a page user-gesture, but MUTED
        // playback is allowed, so we start it muted just to fill the cache.
        static nudgePlayback(iframe) {
            log("nudgePlayback: mute + playVideo");
            document.documentElement.dataset.pgcYtWarmup = "1";
            // Remember that WE muted the player just for warmup, so the first
            // real user play() can undo it and give sound. This flag outlives
            // finishWarmup (which clears pgcYtWarmup but leaves the mute).
            document.documentElement.dataset.pgcYtMuted = "1";
            this.sendCommand(iframe, "mute");
            this.sendCommand(iframe, "playVideo");
        }

        // The player may already be autoplaying on its own (mini.html sets
        // autoplay). sendListening() then makes it report and fill the cache
        // within a moment. So only nudge -- which mutes + plays and later leads
        // to a finishWarmup pause -- when the cache is STILL empty after a short
        // grace period, i.e. the video is genuinely not playing. This stops us
        // from muting/pausing a video that is already running.
        static scheduleWarmupNudge(iframe, delayMs = 400) {
            setTimeout(() => {
                const state = this.readState();

                if (state) {
                    log("scheduleWarmupNudge: already reporting -> skip nudge");
                    // We joined mid-playback: the ongoing infoDelivery stream
                    // carries currentTime but usually NOT playerState (that only
                    // comes on state CHANGES, which happened before our listener
                    // existed). A flowing stream means it is playing, so seed a
                    // playing state -- otherwise isPaused() stays wrongly true and
                    // doPause() only ever calls play(). Real pause/play commands
                    // emit a fresh playerState afterwards and keep it in sync.
                    if (state.playerState === undefined) {
                        this.mergeState({ playerState: 1 });
                    }
                    this.removeOverlay(iframe);
                    return;
                }
                log("scheduleWarmupNudge: still silent -> nudgePlayback");
                this.nudgePlayback(iframe);
            }, delayMs);
        }

        // Finish warmup exactly once, as soon as state is flowing: pause the
        // video again so it sits still at the start position instead of running
        // on. We deliberately do NOT unMute -- Chrome rejects a script-initiated
        // unmute without a real page click and PAUSES the element instead
        // ("Unmuting failed and the element was paused instead"), which is more
        // confusing than helpful here. Sound is instead attempted on the first
        // real user-initiated start (see ensureUnmute(), called from play()); if
        // Chrome still rejects that without a page gesture, playback continues
        // muted and one manual page click per load is needed for sound.
        static finishWarmup(iframe) {
            if (
                document.documentElement.dataset.pgcYtWarmup === "1"
            ) {
                log("finishWarmup: pauseVideo");
                this.sendCommand(iframe, "pauseVideo");
                delete document.documentElement.dataset.pgcYtWarmup;
            }
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
                this.finishWarmup(iframe);

                return {
                    mediaAdapter:
                        new YouTubePostMessageAdapter(iframe),
                    status: "YouTube iframe player ready"
                };
            }

            // Cache still empty. The player might already be autoplaying on its
            // own (mini.html sets autoplay) -- sendListening() above makes it
            // report within a moment. Show the overlay and give it a short grace
            // period: only if NO infoDelivery has populated the cache by then do
            // we actively nudge. That avoids muting/pausing a running video.
            this.showOverlay(iframe, "YouTube connecting…");
            this.scheduleWarmupNudge(iframe);

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

        // Undo the warmup mute exactly once, on the first real user-initiated
        // start. Shared by every start path -- direct play() and the doPause
        // toggle (which routes through play() when it resumes). The user wants
        // to hear now, so we unmute before playing. Order matters at the call
        // site -- unMute first, playVideo second: if Chrome rejects the script
        // unmute without a page gesture it pauses the element, and the following
        // playVideo resumes it (muted). Worst case: muted playback continues;
        // best case: sound.
        ensureUnmute() {
            if (
                document.documentElement.dataset.pgcYtMuted === "1"
            ) {
                log("ensureUnmute: undo warmup mute -> unMute");
                this.postCommand("unMute");
                delete document.documentElement.dataset.pgcYtMuted;
            }
        }

        play() {
            this.ensureUnmute();

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