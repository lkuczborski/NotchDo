// Apply the saved appearance before styles render. Storage is optional.
(() => {
  let theme = "system";
  try {
    const saved = localStorage.getItem("notchdo-theme");
    if (["system", "light", "dark"].includes(saved)) theme = saved;
  } catch {
    // Private browsing or blocked storage still follows system appearance.
  }
  document.documentElement.dataset.theme = theme;
})();
