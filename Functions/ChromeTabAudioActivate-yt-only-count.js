(function() {

    var chrome = Application('Google Chrome');
    var windows = chrome.windows();

    var pattern = new RegExp('youtube.com|youtu.be');

    var foundTabs = [];
    var count = 0;

    var commandMute = `
      (function() {
          var pausedCount = 0;
          // Pause all audio/video elements and count them
          Array.from(document.querySelectorAll('video, audio')).forEach(el => {
              console.log(el)
              if (!el.paused) {
                  
                  el.pause();
                  pausedCount++;
              }
          });
          return pausedCount;  // Return the count of paused elements
      })();
    `;

    windows.forEach(function(window) {
        window.tabs().forEach(function(tab) {
            var result = 0;

            console.log({url: tab.url(), id: tab.id(), title: tab.title(), mediaCount: result});

            if (pattern.test(tab.url())) {
                result = tab.execute({javascript: commandMute});
            }

            if (result > 0) {
                count++;
                foundTabs.push({url: tab.url(), id: tab.id(), title: tab.title(), mediaCount: result});
            }
        });
    });

    return {foundTabs: foundTabs, totalCount: count};

})();
