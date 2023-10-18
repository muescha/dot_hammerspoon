
// Action Generic Video

(function() {
    const mvp = document.querySelector("#movie_player");
    const player = document.querySelector('video');
    console.log("Action: {{ action }}")
    console.log("Generic Player:");
    console.log(player);
    console.log("Youtube Player:");
    console.log(mvp);

    function injectYoutubePlayer(){

        const script = document.createElement('script');
// Set the source of the script to the YouTube Iframe API
        script.src = 'https://www.youtube.com/iframe_api';
        console.log(script);
// Append the script element to the document body
        document.body.appendChild(script);
        const ytp = new YT.Player('player');
        console.log(ytp);
    }

    const controller = {

        getQuality: function () {
            // injectYoutubePlayer();
            const qualityData = mvp.getAvailableQualityData();
            console.log(qualityData);
        },
        // isGeneric: function(){
        //     return player != null;
        // },
        //
        // doPause: function () {
        //     if (player.paused) {
        //         player.play();
        //     } else {
        //         player.pause();
        //     }
        //     return player.paused;
        // },
        // speedInc: function(){
        //     player.playbackRate += 0.25;
        //     return player.playbackRate;
        // },
        // speedDec: function(){
        //     player.playbackRate -= 0.25;
        //     return player.playbackRate;
        // },
        // speedReset: function(){
        //     player.playbackRate = player.defaultPlaybackRate;
        //     return player.playbackRate;
        // },
        // moveForward: function(){
        //     player.currentTime += 5; // jump 5 seconds
        // },
        // moveBackward: function(){
        //     player.currentTime -= 5; // jump 5 seconds backwards
        // },
        nil: function () {
            return 'function not defined in params.action';
        }
    };

    if(controller["{{ action }}"]){
        return controller["{{ action }}"]();
    } else {
        const info = 'no function controller.{{ action }}() found - params.action="{{ action }}"';
        console.log(info);
        return info;
    }

})();
