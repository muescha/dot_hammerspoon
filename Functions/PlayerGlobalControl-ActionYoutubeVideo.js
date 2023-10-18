
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

        // here I expect to have the YouTube API available...
        // but I get an error
        const ytp = new YT.Player('player');
        console.log(ytp);
    }

    const controller = {

        getQuality: function () {

            // test if I can inject the script
            // injectYoutubePlayer();

            // the getAvailableQualityData is undefined, because mvp is onlye a html node
            const qualityData = mvp.getAvailableQualityData();
            console.log(qualityData);
        },

        // housekeeping for undefined values
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
