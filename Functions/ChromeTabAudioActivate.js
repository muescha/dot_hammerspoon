(function() {

    var chrome = Application('Google Chrome');
    var windows = chrome.windows();

    // Pattern to match YouTube URLs or YT embedded links
    var pattern = new RegExp('youtube.com|youtu.be');

    // Variables to store results
    var foundTabs = [];
    var count = 0;

    // JavaScript to mute/stop media on non-YouTube pages
    var commandMute = `
      (function() {
          // Pause all audio/video elements
          Array.from(document.querySelectorAll('video, audio')).forEach(el => el.pause());
      })();
    `;

    // JavaScript to stop media in YouTube iframes
    var commandMuteIframe = `
      (function() {
          Array.from(document.querySelectorAll('video, audio')).forEach(el => el.pause());
          // Stop YouTube video
          document.querySelectorAll('iframe').forEach(iframe => {
            if (iframe.src.includes('youtube.com') || iframe.src.includes('youtu.be')) {
              iframe.contentWindow.postMessage('{"event":"command","func":"stopVideo","args":""}', '*');
            }
          });
      })();
    `;

    // Iterate over all open Chrome windows and tabs
    windows.forEach(function(window) {
        window.tabs().forEach(function(tab) {
            // Check if the tab URL matches the YouTube pattern
            if (pattern.test(tab.url())) {
                // Execute the command to stop videos in YouTube iframes
                var result = tab.execute({javascript: commandMuteIframe});
            } else {
                // Execute the command to mute other media elements
                var result = tab.execute({javascript: commandMute});
            }

            // If media was stopped or paused, increase the count and add the tab to foundTabs
            if (result) {
                count++;  // Increment the count of processed tabs
                foundTabs.push({url: tab.url(), id: tab.id(), title: tab.title()});
            }
        });
    });

    // Return the result: foundTabs and the count of affected tabs
    return {foundTabs: foundTabs, count: count};

})();
