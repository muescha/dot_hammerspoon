// Action Generic Video
// (async function () {
//     return "abc";
// })();

(async function () {
    const mvp = document.querySelector("#movie_player");
    const player = document.querySelector('video');
    console.log("Action: {{ action }}")
    console.log("Generic Player:");
    console.log(player);
    console.log("Youtube Player:");
    console.log(mvp);
    console.log(window);

    // https://github.com/acidburn0zzz/media-player/blob/master/src/data/content_script/chrome_inject.js

    function injectScript(callback) {
        function inject_0() {
            document.body.addEventListener("iplayer-send-command", function (e) {
                var iyp_1 = document.getElementById('movie_player') || document.getElementById('movie_player-flash');
                switch (e.detail.cmd) {
                    case "play":
                        iyp_1.playVideo();
                        break;
                    case "pause":
                        iyp_1.pauseVideo();
                        break;
                    case "stop":
                        iyp_1.stopVideo();
                        iyp_1.clearVideo();
                        break;
                    case "setVolume":
                        iyp_1.setVolume(e.detail.volume);
                        break;
                    case "seekTo":
                        iyp_1.seekTo(e.detail.second, true);
                        break;
                    case "currentTime":
                        var currentTime = iyp_1.getCurrentTime();
                        document.body.dispatchEvent(new CustomEvent("iplayer-currentTime-event", {detail: {time: currentTime}}));
                        break;
                    case "getQualityLevels":
                        console.log("getQualityLevels");
                        var qualityLevels = iyp_1.getAvailableQualityLevels();
                        console.log(qualityLevels);
                        document.body.dispatchEvent(new CustomEvent("iplayer-qualityLevels-event", {detail: {quality: qualityLevels}}));
                        break;

                    case "getAvailableQualityData":
                        console.log("getAvailableQualityData");
                        var qualityData = iyp_1.getAvailableQualityData();
                        console.log(qualityData);
                        document.body.dispatchEvent(new CustomEvent("iplayer-qualityData-event", {detail: {quality: qualityData}}));
                        break;
                    case "setPlaybackQuality":
                        iyp_1.setPlaybackQuality(e.detail.quality);
                        break;
                }
            });
        }

        var attributeName = 'custom-hammerspoon-youtube-script';

        function isScriptInjected(attributeName) {
            return document.querySelectorAll('script[' + attributeName + ']').length > 0;
        }


        // if (!isScriptInjected(attributeName)) {
        //     var code = '(' + inject_0 + ')();';
        //     var script = document.createElement("script");
        //     script.type = 'text/javascript';
        //     // need src to fire onload event
        //     script.src = "data:text/plain," + code;
        //     // script.textContent = code;
        //     script.setAttribute(attributeName, 'yes');
        //     script.onload = function () {
        //         // Code to be executed after the script has loaded and initialized
        //         // ...
        //         console.log("Script loaded and initialized!");
        //         console.log("running callback");
        //         callback();
        //     };
        //     console.log(script);
        //     document.body.appendChild(script);
        // } else {
        //     console.log("Script already loaded");
        //     console.log("running callback direct");
        //     callback()
        // }
        return new Promise(resolve => {
                if (!isScriptInjected(attributeName)) {
                    var code = '(' + inject_0 + ')();';
                    var script = document.createElement("script");
                    script.type = 'text/javascript';

                    // need src and not the textContent to fire onload event
                    script.src = "data:text/plain," + code;
                    // script.textContent = code;

                    script.setAttribute(attributeName, 'yes');
                    script.onload = function () {
                        // Code to be executed after the script has loaded and initialized
                        // ...
                        console.log("Script loaded and initialized!");
                        console.log("running callback");
                        callback();
                        resolve();
                    };
                    console.log(script);
                    document.body.appendChild(script);
                } else {
                    console.log("Script already loaded");
                    console.log("running callback direct");
                    callback();
                    resolve();
                }
            }
        )
    }


    function waitForQualityData() {
        console.log("waitForQualityData");
        return new Promise(resolve => {
            const qualityDataHandler = event => {
                document.body.removeEventListener('iplayer-qualityData-event', qualityDataHandler);
                resolve(event.detail.quality);
            };
            document.body.addEventListener('iplayer-qualityData-event', qualityDataHandler);

            ytGetAvailableQualityData();
        });
    }

    function ytGetAvailableQualityLevels() {
        document.body.dispatchEvent(new CustomEvent("iplayer-send-command", {detail: {cmd: "getQualityLevels"}}));
    }

    function ytGetAvailableQualityData() {
        document.body.dispatchEvent(new CustomEvent("iplayer-send-command", {detail: {cmd: "getAvailableQualityData"}}));
    }

    const controller = {

        getQuality: async function () {

            // test if I can inject the script
            // injectYoutubePlayer();

            // the getAvailableQualityData is undefined, because mvp is onlye a html node
            // const qualityData = mvp.getAvailableQualityData();
            ytGetAvailableQualityLevels();


            const qualityData = await waitForQualityData();
            console.log("Received quality data:", qualityData);

            // try to stringify - maybe I can not return JSON?
            const returnText = JSON.stringify(qualityData)
            console.log(returnText);
            return returnText;
        },

        // housekeeping for undefined values
        nil: async function () {
            return 'function not defined in params.action';
        }
    };

    async function doMain() {
        console.log("script inject: START")
        await injectScript(() => console.log("callback run"));
        console.log("script inject: END")
        const returnValue = await controller["{{ action }}"]();
        console.log(returnValue);
        return returnValue;
    }

    if (controller["{{ action }}"]) {
        const returnValue2 = await doMain();
        console.log(returnValue2);
        return returnValue2;
    } else {
        const info = 'no function controller.{{ action }}() found - params.action="{{ action }}"';
        console.log(info);
        return info;
    }

})();
