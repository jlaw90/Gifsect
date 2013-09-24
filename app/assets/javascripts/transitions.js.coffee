# Delegate .transition() calls to .animate()
# if the browser can't do CSS transitions.
unless $.support.transition
  $.fn.transition = $.fn.animate