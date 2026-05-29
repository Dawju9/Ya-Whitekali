(function() {
    'use strict';

    // Intersection Observer for scroll-triggered animations
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('motion-visible');
                if (entry.target.classList.contains('motion-stagger')) {
                    entry.target.querySelectorAll('> *').forEach((el, i) => {
                        el.style.opacity = '1';
                        el.style.transform = 'translateY(0)';
                    });
                }
            }
        });
    }, { threshold: 0.1 });

    document.querySelectorAll('.motion-hidden, .motion-stagger').forEach(el => {
        observer.observe(el);
    });

    // Typewriter effect
    document.querySelectorAll('.motion-typewriter').forEach(el => {
        const text = el.textContent;
        el.textContent = '';
        el.style.width = '0';
        let i = 0;
        const interval = setInterval(() => {
            el.textContent += text[i];
            el.style.width = (el.scrollWidth) + 'px';
            i++;
            if (i >= text.length) clearInterval(interval);
        }, 50);
    });

    // Parallax on mouse move
    document.querySelectorAll('.motion-parallax').forEach(el => {
        el.addEventListener('mousemove', (e) => {
            const rect = el.getBoundingClientRect();
            const x = (e.clientX - rect.left) / rect.width - 0.5;
            const y = (e.clientY - rect.top) / rect.height - 0.5;
            el.style.backgroundPosition = `${50 + x * 10}% ${50 + y * 10}%`;
        });
    });

    // Interactive boxes - click counter
    document.querySelectorAll('.interactive-box[data-count]').forEach(box => {
        let count = parseInt(box.dataset.count) || 0;
        const display = box.querySelector('.click-count');
        box.addEventListener('click', () => {
            count++;
            if (display) display.textContent = count;
            box.style.transform = 'scale(0.98)';
            setTimeout(() => { box.style.transform = ''; }, 150);
        });
    });

    // Super links - analytics
    document.querySelectorAll('.super-link').forEach(link => {
        link.addEventListener('click', function(e) {
            console.log(`Super link clicked: ${this.href}`);
        });
    });

    // Ripple effect on buttons
    document.querySelectorAll('.motion-ripple').forEach(btn => {
        btn.addEventListener('click', function(e) {
            const ripple = document.createElement('span');
            const rect = this.getBoundingClientRect();
            ripple.style.cssText = `
                position: absolute;
                border-radius: 50%;
                background: rgba(255,255,255,0.3);
                width: 20px;
                height: 20px;
                left: ${e.clientX - rect.left - 10}px;
                top: ${e.clientY - rect.top - 10}px;
                transform: scale(0);
                animation: ripple 0.6s ease-out;
                pointer-events: none;
            `;
            this.style.position = 'relative';
            this.style.overflow = 'hidden';
            this.appendChild(ripple);
            setTimeout(() => ripple.remove(), 600);
        });
    });

    // Smooth scroll for anchor links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                e.preventDefault();
                target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        });
    });

    // Floating particles background generator
    document.querySelectorAll('.motion-particles').forEach(container => {
        for (let i = 0; i < 20; i++) {
            const dot = document.createElement('div');
            const size = Math.random() * 4 + 2;
            dot.style.cssText = `
                position: absolute;
                width: ${size}px;
                height: ${size}px;
                background: rgba(0, 142, 214, ${Math.random() * 0.3 + 0.1});
                border-radius: 50%;
                left: ${Math.random() * 100}%;
                top: ${Math.random() * 100}%;
                animation: float ${Math.random() * 3 + 2}s ease-in-out infinite;
                animation-delay: ${Math.random() * 2}s;
                pointer-events: none;
            `;
            container.appendChild(dot);
        }
    });

    console.log('Motion.js initialized');
})();
