const console = {
    log(message) {
        webkit.messageHandlers.consoleLog.postMessage(message);
    },
    error(message) {
        webkit.messageHandlers.consoleError.postMessage(message);
    }
};

