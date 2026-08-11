const header = document.querySelector("[data-header]");
const revealItems = document.querySelectorAll(".reveal");

const updateHeader = () => {
  header?.classList.toggle("scrolled", window.scrollY > 24);
};

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("visible");
      observer.unobserve(entry.target);
    });
  },
  { threshold: 0.12 }
);

revealItems.forEach((item) => observer.observe(item));
window.addEventListener("scroll", updateHeader, { passive: true });
updateHeader();
