// Tab panels
document.querySelectorAll('.tab-btn').forEach(function (btn) {
  btn.addEventListener('click', function () {
    var tabGroup = this.closest('.tab-container') || this.parentElement.parentElement;
    var tabId = this.dataset.tab;

    // Deactivate all buttons in this group
    this.parentElement.querySelectorAll('.tab-btn').forEach(function (b) {
      b.classList.remove('active');
    });
    this.classList.add('active');

    // Hide all panels, show target
    tabGroup.querySelectorAll('.tab-panel').forEach(function (p) {
      p.classList.remove('active');
    });
    var target = document.getElementById('tab-' + tabId);
    if (target) target.classList.add('active');
  });
});

// Mobile navigation toggle
(function () {
  const toggle = document.querySelector('.nav-toggle');
  const nav = document.querySelector('.site-nav');

  if (!toggle || !nav) return;

  toggle.addEventListener('click', function () {
    const isOpen = nav.classList.toggle('is-open');
    toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');

    // Animate hamburger lines
    const spans = toggle.querySelectorAll('span');
    if (isOpen) {
      spans[0].style.transform = 'translateY(7px) rotate(45deg)';
      spans[1].style.opacity = '0';
      spans[2].style.transform = 'translateY(-7px) rotate(-45deg)';
    } else {
      spans[0].style.transform = '';
      spans[1].style.opacity = '';
      spans[2].style.transform = '';
    }
  });

  // Close menu when clicking outside
  document.addEventListener('click', function (e) {
    if (!toggle.contains(e.target) && !nav.contains(e.target)) {
      nav.classList.remove('is-open');
      toggle.setAttribute('aria-expanded', 'false');
      const spans = toggle.querySelectorAll('span');
      spans.forEach(function (s) {
        s.style.transform = '';
        s.style.opacity = '';
      });
    }
  });
})();

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(function (anchor) {
  anchor.addEventListener('click', function (e) {
    const target = document.querySelector(this.getAttribute('href'));
    if (target) {
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  });
});
