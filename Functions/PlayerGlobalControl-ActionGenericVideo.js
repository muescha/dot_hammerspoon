// Action Generic Video

(function () {
    const player = document.querySelector('video');
    console.log("Action: {{ action }}")
    console.log("Generic Player:");
    console.log(player);

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
            player.playbackRate += 0.25;
            return player.playbackRate;
        },
        speedDec: function () {
            player.playbackRate -= 0.25;
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
