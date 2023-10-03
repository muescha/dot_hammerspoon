
// Action Generic Video

(function() {
    var player = document.querySelector('video');

    var controller = {

        isGeneric: function(){
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
        speedInc: function(){
            player.playbackRate += 0.25;
            return player.playbackRate;
        },
        speedDec: function(){
            player.playbackRate -= 0.25;
            return player.playbackRate;
        },
        speedReset: function(){
            player.playbackRate = player.defaultPlaybackRate;
            return player.playbackRate;
        },
        moveForward: function(){
            player.currentTime += 5; // jump 5 seconds
        },
        moveBackward: function(){
            player.currentTime -= 5; // jump 5 seconds backwards
        },
        nil: function(){
            return 'function not defined in params.action';
        }
    };

    if(controller["{{ action }}"]){
        return controller["{{ action }}"]();
    } else {
        var info = 'no function controller.{{ action }}() found - params.action="{{ action }}"'
        console.log(info);
        return info;
    }

})();
