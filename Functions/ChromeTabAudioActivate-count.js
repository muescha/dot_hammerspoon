(function() {

    var chrome = Application('Google Chrome');
    var windows = chrome.windows();

    // Pattern to match YouTube URLs or YT embedded links
    var pattern = new RegExp('youtube.com|youtu.be');

    // Variables to store results
    var foundTabs = [];
    var count = 0;

    // JavaScript to mute/stop media on non-YouTube pages and return the count
    var commandMute = `
      (function() {
          var pausedCount = 0;
          // Pause all audio/video elements and count them
          Array.from(document.querySelectorAll('video, audio')).forEach(el => {
              if (!el.paused) {
                  el.pause();
                  pausedCount++;
              }
          });
          return pausedCount;  // Return the count of paused elements
      })();
    `;

    // JavaScript to stop media in YouTube iframes and return the count
    var commandMuteIframe = `
      (function() {
          var pausedCount = 0;
          Array.from(document.querySelectorAll('video, audio')).forEach(el => {
              if (!el.paused) {
                  el.pause();
                  pausedCount++;
              }
          });
          // Stop YouTube video iframes and count them
          document.querySelectorAll('iframe').forEach(iframe => {
            if (iframe.src.includes('youtube.com') || iframe.src.includes('youtu.be')) {
              iframe.contentWindow.postMessage('{"event":"command","func":"stopVideo","args":""}', '*');
              // var src = iframe.src;
              // iframe.src = src;
              pausedCount++;  // Increment count for the iframe action
            }
          });
          return pausedCount;  // Return the count of paused elements (audio, video, iframes)
      })();
    `;

    // Iterate over all open Chrome windows and tabs
    windows.forEach(function(window) {
        window.tabs().forEach(function(tab) {
            var result = 0;

            // Check if the tab URL matches the YouTube pattern
            if (pattern.test(tab.url())) {
                // Execute the command to stop videos in YouTube iframes and get the count
                result = tab.execute({javascript: commandMute});
            } else {
                // Execute the command to mute other media elements and get the count
                result = tab.execute({javascript: commandMuteIframe});
            }

            // If media was stopped or paused, increase the count and add the tab to foundTabs
            if (result > 0) {
                count++;  // Increment the count of processed tabs
                foundTabs.push({url: tab.url(), id: tab.id(), title: tab.title(), mediaCount: result});
            }
        });
    });

    // Return the result: foundTabs and the count of affected tabs
    return {foundTabs: foundTabs, count: count};

})();
