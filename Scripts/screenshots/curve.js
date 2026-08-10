// One curve across the whole set. Each frame renders the same path and shows
// its own window through the SVG viewBox, so continuity is a property of the
// geometry rather than of eight numbers agreeing.
//
// The jitter is a fixed linear congruential sequence, not Math.random: the
// same sheet has to render the same way on every machine and every rerun.
(function (global) {
  var UNITS_PER_FRAME = 400;
  var HEIGHT = 867;

  function points(frameCount) {
    var width = UNITS_PER_FRAME * frameCount;
    var seed = 7;
    function rnd() {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      return seed / 2147483648;
    }
    var pts = [];
    for (var x = -40; x <= width + 40; x += 40) {
      var t = x / width;
      // Math.pow rejects a negative base with a fractional exponent (NaN in
      // JS), which the leftmost off-canvas padding point (x=-40) hits since
      // t is briefly negative there. That point is never inside any frame's
      // viewBox — it only shapes the invisible lead-in tangent — so clamping
      // just its exponent base to 0 changes nothing visible while keeping
      // every on-canvas point (t >= 0) numerically identical.
      var arc = 600 - 300 * Math.sin(Math.PI * Math.pow(Math.max(t, 0), 0.85)) + 70 * Math.sin(t * 7.5);
      pts.push([x, arc + (rnd() - 0.5) * 70]);
    }
    return pts;
  }

  function path(pts, close, frameCount) {
    var width = UNITS_PER_FRAME * frameCount;
    var d = 'M' + pts[0][0] + ',' + pts[0][1].toFixed(1);
    for (var i = 1; i < pts.length; i++) {
      var a = pts[i - 1], b = pts[i], mx = (a[0] + b[0]) / 2;
      d += ' C' + mx + ',' + a[1].toFixed(1) + ' ' + mx + ',' + b[1].toFixed(1) +
           ' ' + b[0] + ',' + b[1].toFixed(1);
    }
    if (close) d += ' L' + (width + 40) + ',' + (HEIGHT + 40) + ' L-40,' + (HEIGHT + 40) + ' Z';
    return d;
  }

  var counter = 0;

  global.PlotlineCurve = {
    /// `viewTop`/`viewHeight` let the iPad sheet crop the curve vertically
    /// without changing where it runs horizontally.
    svg: function (windowIndex, frameCount, viewTop, viewHeight) {
      var pts = points(frameCount);
      var line = path(pts, false, frameCount);
      var fill = path(pts, true, frameCount);
      var id = 'plc' + (counter++);
      var top = viewTop === undefined ? 0 : viewTop;
      var height = viewHeight === undefined ? HEIGHT : viewHeight;
      return '<svg class="curve" preserveAspectRatio="none" viewBox="' +
        (windowIndex * UNITS_PER_FRAME) + ' ' + top + ' ' + UNITS_PER_FRAME + ' ' + height + '">' +
        '<defs><linearGradient id="' + id + '" x1="0" y1="0" x2="0" y2="1">' +
        '<stop offset="0%" stop-color="#E8A33D" stop-opacity=".13"/>' +
        '<stop offset="100%" stop-color="#E8A33D" stop-opacity="0"/>' +
        '</linearGradient></defs>' +
        '<path d="' + fill + '" fill="url(#' + id + ')"/>' +
        '<path d="' + line + '" fill="none" stroke="#E8A33D" stroke-opacity=".78" ' +
        'stroke-width="3.2" stroke-linecap="round"/></svg>';
    }
  };
})(window);
