// Fade-up on scroll. Elements stay visible if JS or IntersectionObserver is missing.
(function () {
  var items = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window)) {
    items.forEach(function (el) { el.classList.add('in'); });
    return;
  }
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) {
      if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

  var heroIndex = 0;
  items.forEach(function (el) {
    if (el.closest('.hero')) el.style.transitionDelay = (heroIndex++ * 80) + 'ms';
    io.observe(el);
  });
})();

// Decorative work timer in the mock: counts up, ring sweeps once a minute,
// and 15% of the elapsed time is "banked" as break (60 s floor), like the app.
(function () {
  var work = document.querySelectorAll('[data-work]');
  var banked = document.querySelector('[data-banked]');
  var ring = document.querySelector('[data-ring]');
  if (!work.length || !ring) return;

  var C = 2 * Math.PI * 52;
  var elapsed = 42 * 60 + 18;

  function fmt(s) {
    var m = Math.floor(s / 60), r = s % 60;
    return (m < 10 ? '0' : '') + m + ':' + (r < 10 ? '0' : '') + r;
  }
  function paint() {
    var t = fmt(elapsed);
    work.forEach(function (el) { el.textContent = t; });
    if (banked) banked.textContent = fmt(Math.max(60, Math.floor(elapsed * 0.15))).replace(/^0/, '');
    var sec = elapsed % 60 || 60;
    // Sweep up to a full circle, then snap (not sweep backwards) to the next minute.
    ring.style.transition = sec === 1 ? 'none' : '';
    ring.style.strokeDashoffset = C * (1 - sec / 60);
  }
  paint();
  setInterval(function () { elapsed++; paint(); }, 1000);
})();
