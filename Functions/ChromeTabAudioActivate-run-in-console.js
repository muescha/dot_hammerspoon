function stopAllVideos() {
    // Stop all native HTML video elements
    document.querySelectorAll('video').forEach(video => {
        if (!video.paused) {
            video.pause();
            console.log('Paused native video:', video);
        }
    });

    // Stop all YouTube iframe videos
    document.querySelectorAll('iframe').forEach(iframe => {
        if (iframe.src.includes('youtube.com') || iframe.src.includes('youtu.be')) {
            try {
                // Send a stop command via postMessage
                iframe.contentWindow.postMessage(
                    '{"event":"command","func":"stopVideo","args":""}', '*'
                );
                console.log('Sent stop command to YouTube iframe:', iframe);
            } catch (error) {
                console.warn('Unable to stop YouTube iframe due to cross-origin restrictions:', iframe);
            }
        }
    });
}

// Call the function to stop all videos
stopAllVideos();