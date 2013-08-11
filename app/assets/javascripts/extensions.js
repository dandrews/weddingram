// Generated by CoffeeScript 1.3.1
(function() {

  (function($) {
    var inherit;
    inherit = ['font', 'letter-spacing'];
    return $.fn.autoGrow = function(options) {
      var comfortZone, remove, _ref;
      remove = (options === 'remove' || options === false) || !!(options != null ? options.remove : void 0);
      comfortZone = (_ref = options != null ? options.comfortZone : void 0) != null ? _ref : options;
      if (comfortZone != null) {
        comfortZone = +comfortZone;
      }
      return this.each(function() {
        var check, cz, input, prop, styles, testSubject, _i, _j, _len, _len1;
        input = $(this);
        testSubject = input.next().filter('pre.autogrow');
        if (testSubject.length && remove) {
          input.unbind('input.autogrow');
          return testSubject.remove();
        } else if (testSubject.length) {
          styles = {};
          for (_i = 0, _len = inherit.length; _i < _len; _i++) {
            prop = inherit[_i];
            styles[prop] = input.css(prop);
          }
          testSubject.css(styles);
          if (comfortZone != null) {
            check = function() {
              testSubject.text(input.val());
              return input.width(testSubject.width() + comfortZone);
            };
            input.unbind('input.autogrow');
            input.bind('input.autogrow', check);
            return check();
          }
        } else if (!remove) {
          if (input.css('min-width') === '0px') {
            input.css('min-width', "" + (input.width()) + "px");
          }
          styles = {
            position: 'absolute',
            top: -99999,
            left: -99999,
            width: 'auto',
            visibility: 'hidden'
          };
          for (_j = 0, _len1 = inherit.length; _j < _len1; _j++) {
            prop = inherit[_j];
            styles[prop] = input.css(prop);
          }
          testSubject = $('<pre class="autogrow"/>').css(styles);
          testSubject.insertAfter(input);
          cz = comfortZone != null ? comfortZone : 70;
          check = function() {
            testSubject.text(input.val());
            return input.width(testSubject.width() + cz);
          };
          input.bind('input.autogrow', check);
          return check();
        }
      });
    };
  })(typeof Zepto !== "undefined" && Zepto !== null ? Zepto : jQuery);

}).call(this);