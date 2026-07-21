// Action Generic Video

(function () {

    console.log("Action: {{ action }}");

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

    const speedSteps = {
        speedInc(currentSpeed) {
            if (currentSpeed >= 1) {
                return 0.5;
            } else {
                return 0.25;
            }
        },

        speedDec(currentSpeed) {
            if (currentSpeed <= 1) {
                return 0.25;
            } else {
                return 0.5;
            }
        }
    };

    class MediaController {

        constructor(mediaAdapter) {
            this.mediaAdapter = mediaAdapter;
        }

        isGeneric() {
            return this.mediaAdapter.tagName;
        }

        doPause() {
            if (this.mediaAdapter.isPaused()) {
                this.mediaAdapter.play();
            } else {
                this.mediaAdapter.pause();
            }

            return this.mediaAdapter.isPaused();
        }

        speedInc() {
            const currentSpeed = this.mediaAdapter.getPlaybackRate();
            const speedDiff = speedSteps.speedInc(currentSpeed);

            console.log(speedDiff);

            this.mediaAdapter.setPlaybackRate(currentSpeed + speedDiff);

            return this.mediaAdapter.getPlaybackRate();
        }

        speedDec() {
            const currentSpeed = this.mediaAdapter.getPlaybackRate();
            const speedDiff = speedSteps.speedDec(currentSpeed);

            console.log(speedDiff);

            this.mediaAdapter.setPlaybackRate(currentSpeed - speedDiff);

            return this.mediaAdapter.getPlaybackRate();
        }

        maxSpeed() {
            const skipButton = document.querySelector("button.ytp-skip-ad-button");

            console.log(skipButton);

            this.mediaAdapter.setPlaybackRate(16);

            if (skipButton) {
                skipButton.click();
                return "16 & skipButton clicked";
            } else {
                return this.mediaAdapter.getPlaybackRate();
            }
        }

        speedReset() {
            this.mediaAdapter.setPlaybackRate(
                this.mediaAdapter.getDefaultPlaybackRate()
            );

            return this.mediaAdapter.getPlaybackRate();
        }

        moveForward() {
            const jump = computeJumpSeconds(
                this.mediaAdapter.getPlaybackRate()
            );
            const currentTime = this.mediaAdapter.getCurrentTime();

            var info = formatTime(currentTime)
                + " + "
                + jump
                + " = ";

            this.mediaAdapter.setCurrentTime(currentTime + jump);

            return info + formatTime(
                this.mediaAdapter.getCurrentTime()
            );
        }

        moveBackward() {
            const jump = computeJumpSeconds(
                this.mediaAdapter.getPlaybackRate()
            );
            const currentTime = this.mediaAdapter.getCurrentTime();

            var info = formatTime(currentTime)
                + " - "
                + jump
                + " = ";

            this.mediaAdapter.setCurrentTime(currentTime - jump);

            return info + formatTime(
                this.mediaAdapter.getCurrentTime()
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

        static createController(mediaAdapter) {
            console.log("Generic Player:");
            console.log(mediaAdapter.player);

            return new MediaController(mediaAdapter);
        }

        get tagName() {
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
    }

    const adapters = [
        NativeMediaAdapter
    ];

    function findController() {
        for (const adapter of adapters) {
            const mediaAdapter = adapter.detect();

            if (mediaAdapter) {
                return adapter.createController(mediaAdapter);
            }
        }

        return null;
    }

    const controller = findController();

    function executeAction(controller, action) {
        if (!controller) {
            const info = "no supported player found";
            console.log(info);
            return info;
        }

        if (controller[action]) {
            let info = controller[action]();
            console.log(info);
            return info;
        } else {
            const info = `no function controller.${action}() found - params.action="${action}"`;

            console.log(info);
            return info;
        }
    }

    return executeAction(controller, "{{ action }}");

})();