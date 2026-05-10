// =============================================
// HIDDEN PANTRY – Shared JavaScript
// =============================================

document.addEventListener('DOMContentLoaded', () => {

  // ── Navbar scroll behaviour ──────────────────
  const navbar = document.getElementById('navbar');
  if (navbar) {
    window.addEventListener('scroll', () => {
      navbar.classList.toggle('scrolled', window.scrollY > 40);
    });
  }

  // ── Hamburger / Mobile Menu ──────────────────
  const hamburger  = document.getElementById('hamburger');
  const mobileMenu = document.getElementById('mobileMenu');
  if (hamburger && mobileMenu) {
    hamburger.addEventListener('click', () => {
      hamburger.classList.toggle('open');
      mobileMenu.classList.toggle('open');
      document.body.style.overflow = mobileMenu.classList.contains('open') ? 'hidden' : '';
    });
    // Close on any link click
    mobileMenu.querySelectorAll('a').forEach(a => {
      a.addEventListener('click', () => {
        hamburger.classList.remove('open');
        mobileMenu.classList.remove('open');
        document.body.style.overflow = '';
      });
    });
  }

  // ── Active nav link on scroll ────────────────
  const sections  = document.querySelectorAll('section[id]');
  const navLinks  = document.querySelectorAll('.nav-links a[href^="#"], .mobile-menu a[href^="#"]');
  if (sections.length && navLinks.length) {
    const observer = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          navLinks.forEach(a => a.classList.remove('active'));
          const active = document.querySelectorAll(`a[href="#${entry.target.id}"]`);
          active.forEach(a => a.classList.add('active'));
        }
      });
    }, { rootMargin: '-40% 0px -55% 0px' });
    sections.forEach(s => observer.observe(s));
  }

  // ── Smooth scroll for all #anchor links ──────
  document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', e => {
      const target = document.querySelector(anchor.getAttribute('href'));
      if (target) {
        e.preventDefault();
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    });
  });

  // ── Entrance animations (IntersectionObserver) ─
  const animEls = document.querySelectorAll('[data-anim]');
  if (animEls.length) {
    const style = document.createElement('style');
    style.textContent = `
      [data-anim] {
        opacity: 0;
        transform: translateY(22px);
        transition: opacity 0.35s ease, transform 0.35s ease;
        will-change: opacity, transform;
      }
      [data-anim].visible { opacity: 1; transform: translateY(0); }
    `;
    document.head.appendChild(style);

    // isMobile: skip stagger delays entirely for faster feel
    const isMobile = window.matchMedia('(max-width: 768px)').matches;

    const io = new IntersectionObserver(entries => {
      entries.forEach(e => {
        if (e.isIntersecting) {
          // Cap delay at 150ms on mobile so fast scrollers never wait long
          const rawDelay = parseInt(e.target.dataset.delay || '0', 10);
          const delay = isMobile ? Math.min(rawDelay, 60) : rawDelay;
          setTimeout(() => e.target.classList.add('visible'), delay);
          io.unobserve(e.target);
        }
      });
    }, {
      threshold: 0,              // trigger as soon as 1px enters viewport
      rootMargin: '0px 0px -40px 0px'  // pre-fire 40px before bottom edge
    });
    animEls.forEach(el => io.observe(el));
  }

  // ── Contact form (static, no backend) ────────
  const contactForm = document.getElementById('contactForm');
  if (contactForm) {
    contactForm.addEventListener('submit', e => {
      e.preventDefault();
      const btn = contactForm.querySelector('button[type="submit"]');
      btn.textContent = 'Message Sent! ✓';
      btn.disabled = true;
      btn.style.background = '#27ae60';
      setTimeout(() => { btn.textContent = 'Send Message'; btn.disabled = false; btn.style.background = ''; }, 3000);
    });
  }

  // ── Screenshots horizontal scroll via arrows ─
  const scrollEl = document.getElementById('screenshotsScroll');
  document.getElementById('scrollLeft')?.addEventListener('click', () => {
    scrollEl?.scrollBy({ left: -260, behavior: 'smooth' });
  });
  document.getElementById('scrollRight')?.addEventListener('click', () => {
    scrollEl?.scrollBy({ left: 260, behavior: 'smooth' });
  });

});
