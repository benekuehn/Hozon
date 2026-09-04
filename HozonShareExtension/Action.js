var HozonAction = function() {};

HozonAction.prototype = {
    run: function(arguments) {
        arguments.completionFunction({ "url": document.URL });
    },

    finalize: function(arguments) {}
};

var ExtensionPreprocessingJS = new HozonAction();
