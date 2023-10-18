# Info how to Use Events

# `.click()` vs `new Event('click')`

`.click()` also bubble up the DOM Tree while with `Event` I need to allow this bubble 

use `bubbles` and `terminates`:

```javascript
let clickEvent = new Event('click',
    {
        bubbles: true,
        cancelable: true,
    });
```

Source:
- https://developer.mozilla.org/en-US/docs/Web/Events/Creating_and_triggering_events



For Youtube there is an PlayerAPI

```java
YT.PlayerState.ENDED = 0
YT.PlayerState.PLAYING = 1
YT.PlayerState.PAUSED = 2
YT.PlayerState.BUFFERING = 3
YT.PlayerState.CUED = 5
```

Disabled:

- Enhancer for YouTube™  2.0.121
- Magic Actions for YouTube™ 7.9.5.2


https://developers.google.com/youtube/iframe_api_reference?hl=de

useful snippets:

```javascript

const mvp = document.querySelector("#movie_player")
mvp.getPlayerState()
mvp.getAvailableQualityData()
mvp.getPlaybackRate()
mvp.setPlaybackRate(2)

if (mvp.getPlayerState() == 1) {
    mvp.pauseVideo();
} else {
    mvp.playVideo();
}
```

```json
[
  {
    "qualityLabel": "2160p",
    "quality": "hd2160",
    "isPlayable": true
  },
  {
    "qualityLabel": "1440p",
    "quality": "hd1440",
    "isPlayable": true
  },
  {
    "qualityLabel": "1080p",
    "quality": "hd1080",
    "isPlayable": true
  },
  {
    "qualityLabel": "720p",
    "quality": "hd720",
    "isPlayable": true
  },
  {
    "qualityLabel": "480p",
    "quality": "large",
    "isPlayable": true
  },
  {
    "qualityLabel": "360p",
    "quality": "medium",
    "isPlayable": true
  },
  {
    "qualityLabel": "240p",
    "quality": "small",
    "isPlayable": true
  },
  {
    "qualityLabel": "144p",
    "quality": "tiny",
    "isPlayable": true
  }
]
```

```javascript
function onYouTubePlayerReady(playerId) {
  ytplayer = document.getElementById("myytplayer");
  ytplayer.addEventListener("onStateChange", "onytplayerStateChange");
}

function onytplayerStateChange(newState) {
  alert("Player's new state: " + newState);
}
```
source: https://stackoverflow.com/questions/38816361/youtube-api-play-pause-toggle-button

