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

    class NativeController {

        constructor(player) {
            this.player = player;
        }

        isGeneric() {
            return this.player.tagName;
        }

        doPause() {
            if (this.player.paused) {
                this.player.play();
            } else {
                this.player.pause();
            }

            return this.player.paused;
        }

        speedInc() {
            let speedDiff = speedSteps.speedInc(this.player.playbackRate);
            console.log(speedDiff);
            this.player.playbackRate += speedDiff;
            return this.player.playbackRate;
        }

        speedDec() {
            let speedDiff = speedSteps.speedDec(this.player.playbackRate);
            console.log(speedDiff);
            this.player.playbackRate -= speedDiff;
            return this.player.playbackRate;
        }

        maxSpeed() {
            const skipButton = document.querySelector("button.ytp-skip-ad-button");

            console.log(skipButton);
            this.player.playbackRate = 16;

            if (skipButton) {
                skipButton.click();
                return "16 & skipButton clicked";
            } else {
                return this.player.playbackRate;
            }
        }

        speedReset() {
            this.player.playbackRate = this.player.defaultPlaybackRate;
            return this.player.playbackRate;
        }

        moveForward() {
            const jump = computeJumpSeconds(this.player.playbackRate);
            var info = formatTime(this.player.currentTime) + " + " + jump + " = ";

            this.player.currentTime += jump;

            return info + formatTime(this.player.currentTime);
        }

        moveBackward() {
            const jump = computeJumpSeconds(this.player.playbackRate);
            var info = formatTime(this.player.currentTime) + " - " + jump + " = ";

            this.player.currentTime -= jump;

            return info + formatTime(this.player.currentTime);
        }

        nil() {
            return "function not defined in params.action";
        }
    }

    class NativeMediaAdapter {

        static detect() {
            return document.querySelector("video, audio");
        }

        static createController(player) {
            console.log("Generic Player:");
            console.log(player);

            return new NativeController(player);
        }
    }

    const adapters = [
        NativeMediaAdapter
    ];

    function findController() {
        for (const adapter of adapters) {
            const player = adapter.detect();

            if (player) {
                return adapter.createController(player);
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