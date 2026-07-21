// Action Generic Video

(function () {

    function log(value) {
        console.log(value);

        return value;
    }

    log("Action: {{ action }}");

    function formatTime(timestampInSeconds, showMilliseconds = false) {
        const hoursValue = Math.floor(timestampInSeconds / 3600);
        const minutesValue = Math.floor((timestampInSeconds % 3600) / 60);
        const secondsValue = Math.floor(timestampInSeconds % 60);
        const millisecondsValue = Math.floor((timestampInSeconds % 1) * 1000);

        const hours = hoursValue.toString().padStart(2, "0");
        const minutes = minutesValue.toString().padStart(2, "0");
        const seconds = secondsValue.toString().padStart(2, "0");
        const milliseconds = millisecondsValue.toString().padStart(4, "0");

        return showMilliseconds
            ? `${hours}:${minutes}:${seconds}.${milliseconds}`
            : `${hours}:${minutes}:${seconds}`;
    }

    function computeJumpSeconds(rate, base = 4, minJump = 3, maxJump = 30) {
        const safeRate = Math.max(0.1, rate || 1);
        return Math.min(maxJump, Math.max(minJump, base * safeRate));
    }

    const speedChanges = {
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
    };

    const timeChanges = {
        forward(currentTime, jump) {
            return currentTime + jump;
        },

        backward(currentTime, jump) {
            return currentTime - jump;
        }
    };

    class MediaController {

        constructor(mediaAdapter) {
            this.mediaAdapter = mediaAdapter;
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
            return this.changeSpeed(speedChanges.inc);
        }

        speedDec() {
            return this.changeSpeed(speedChanges.dec);
        }

        maxSpeed() {
            this.mediaAdapter.setPlaybackRate(16);

            if (this.mediaAdapter.skipAd()) {
                return "16 & skipButton clicked";
            }

            return this.mediaAdapter.getPlaybackRate();
        }

        speedReset() {
            this.mediaAdapter.setPlaybackRate(
                this.mediaAdapter.getDefaultPlaybackRate()
            );

            return this.mediaAdapter.getPlaybackRate();
        }

        changeTime(calculateTime, operator) {
            const jump = computeJumpSeconds(
                this.mediaAdapter.getPlaybackRate()
            );
            const currentTime = this.mediaAdapter.getCurrentTime();

            const info = formatTime(currentTime)
                + " "
                + operator
                + " "
                + jump
                + " = ";

            this.mediaAdapter.setCurrentTime(
                calculateTime(currentTime, jump)
            );

            return info + formatTime(
                this.mediaAdapter.getCurrentTime()
            );
        }

        moveForward() {
            return this.changeTime(
                timeChanges.forward,
                "+"
            );
        }

        moveBackward() {
            return this.changeTime(
                timeChanges.backward,
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

    const adapters = [
        NativeMediaAdapter
    ];

    function findMediaAdapter() {
        for (const adapter of adapters) {
            const mediaAdapter = adapter.detect();

            if (mediaAdapter) {
                return mediaAdapter;
            }
        }

        return null;
    }

    function hasControllerAction(controller, action) {
        const controllerPrototype = Object.getPrototypeOf(controller);

        return action !== "constructor"
            && Object.prototype.hasOwnProperty.call(
                controllerPrototype,
                action
            )
            && typeof controller[action] === "function";
    }

    function executeAction(controller, action) {
        if (!hasControllerAction(controller, action)) {
            const info = `no function controller.${action}() found - params.action="${action}"`;

            return log(info);
        }

        return log(controller[action]());
    }

    const mediaAdapter = findMediaAdapter();

    if (!mediaAdapter) {
        return log("no supported player found");
    }

    log("Generic Player:");
    log(mediaAdapter.player);

    const controller = new MediaController(mediaAdapter);

    return executeAction(controller, "{{ action }}");

})();