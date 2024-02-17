// Action Generic Video

(function () {
    const player = document.querySelector('video');
    console.log("Action: {{ action }}")
    console.log("Generic Player:");
    console.log(player);

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
        speedReset: function () {
            player.playbackRate = player.defaultPlaybackRate;
            return player.playbackRate;
        },
        moveForward: function () {
            player.currentTime += 5; // jump 5 seconds
            return player.currentTime
        },
        moveBackward: function () {
            player.currentTime -= 5; // jump 5 seconds backwards
            return player.currentTime
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
