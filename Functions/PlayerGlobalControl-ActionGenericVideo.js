// Action Generic Video

(function () {
    const player = document.querySelector('video');
    console.log("Action: {{ action }}")
    console.log("Generic Player:");
    console.log(player);

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
    const speedSteps = {
        speedInc: function(currentSpeed){
            if(currentSpeed >= 1){
                return 0.5
            } else {
                return 0.25
            }
        },
        speedDec: function(currentSpeed){
            if(currentSpeed <= 1){
                return 0.25
            } else {
                return 0.5
            }
        }
    }

    const controller = {

        isGeneric: function () {
            return player != null;
        },

        doPause: function () {
            if (player.paused) {
                player.play();
            } else {
                player.pause();
            }
            return player.paused;
        },
        speedInc: function () {
            let speedDiff = speedSteps.speedInc(player.playbackRate);
            console.log(speedDiff);
            player.playbackRate += speedDiff;
            return player.playbackRate;
        },
        speedDec: function () {
            let speedDiff = speedSteps.speedDec(player.playbackRate);
            console.log(speedDiff);
            player.playbackRate -= speedDiff;
            return player.playbackRate;
        },
        maxSpeed: function () {
            player.playbackRate = 16;
            return player.playbackRate;
        },
        speedReset: function () {
            player.playbackRate = player.defaultPlaybackRate;
            return player.playbackRate;
        },
        moveForward: function () {
            player.currentTime += 5; // jump 5 seconds
            return formatTime(player.currentTime)
        },
        moveBackward: function () {
            player.currentTime -= 5; // jump 5 seconds backwards
            return formatTime(player.currentTime)
        },
        nil: function () {
            return 'function not defined in params.action';
        }
    };

    if (controller["{{ action }}"]) {
        let info = controller["{{ action }}"]();
        console.log(info);
        return info;
    } else {
        const info = 'no function controller.{{ action }}() found - params.action="{{ action }}"';
        console.log(info);
        return info;
    }

})();
