/* Static, dependency-free enhancements. */
const tabs = [...document.querySelectorAll('[role="tab"]')];
function activateTab(tab) {
  for (const item of tabs) {
    const active = item === tab;
    item.setAttribute("aria-selected", String(active));
    item.tabIndex = active ? 0 : -1;
    document.getElementById(item.getAttribute("aria-controls")).hidden =
      !active;
  }
}
for (const tab of tabs) {
  tab.addEventListener("click", () => activateTab(tab));
  tab.addEventListener("keydown", (event) => {
    const index = tabs.indexOf(tab);
    const destinations = {
      ArrowRight: (index + 1) % tabs.length,
      ArrowLeft: (index + tabs.length - 1) % tabs.length,
      Home: 0,
      End: tabs.length - 1,
    };
    if (!(event.key in destinations)) return;
    event.preventDefault();
    const destination = tabs[destinations[event.key]];
    activateTab(destination);
    destination.focus();
  });
}

// Theme choice persists locally. Auto continues following live system changes.
const systemTheme = matchMedia("(prefers-color-scheme: dark)");
const themeButtons = [...document.querySelectorAll("[data-theme-choice]")];
function applyTheme(theme) {
  const choice = ["system", "light", "dark"].includes(theme) ? theme : "system";
  document.documentElement.dataset.theme = choice;
  for (const button of themeButtons) {
    button.setAttribute(
      "aria-pressed",
      String(button.dataset.themeChoice === choice),
    );
  }
  const dark =
    choice === "dark" || (choice === "system" && systemTheme.matches);
  for (const meta of document.querySelectorAll('meta[name="theme-color"]')) {
    meta.content = dark ? "#13171b" : "#f7f8fa";
  }
}
for (const button of themeButtons) {
  button.addEventListener("click", () => {
    const choice = button.dataset.themeChoice;
    applyTheme(choice);
    try {
      localStorage.setItem("notchdo-theme", choice);
    } catch {
      // The control remains usable when browser storage is unavailable.
    }
  });
}
systemTheme.addEventListener("change", () =>
  applyTheme(document.documentElement.dataset.theme),
);
window.addEventListener("storage", (event) => {
  if (event.key === "notchdo-theme" || event.key === null)
    applyTheme(event.newValue);
});
applyTheme(document.documentElement.dataset.theme);

// Use the original GIF without resampling. A still image is the no-script and
// reduced-motion default; pause it offscreen and when the tab is in the background.
const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
const stillSource = document.getElementById("overview-still");
const motionToggle = document.getElementById("motion-toggle");
const overview = document.querySelector(".hero-visual");
let wantsMotion = !reducedMotion.matches;
let overviewVisible = true;
function updateMotion() {
  const playing = wantsMotion && overviewVisible && !document.hidden;
  stillSource.media = playing ? "not all" : "all";
  motionToggle.textContent = wantsMotion ? "Pause animation" : "Play animation";
}
motionToggle.addEventListener("click", () => {
  wantsMotion = !wantsMotion;
  updateMotion();
});
reducedMotion.addEventListener("change", (event) => {
  wantsMotion = !event.matches;
  updateMotion();
});
document.addEventListener("visibilitychange", updateMotion);
if ("IntersectionObserver" in window) {
  new IntersectionObserver(([entry]) => {
    overviewVisible = entry.isIntersecting;
    updateMotion();
  }).observe(overview);
}
updateMotion();

// The source remains readable when scripting is disabled or unavailable.
activateTab(tabs[0]);
for (const element of document.querySelectorAll("[data-enhanced]"))
  element.hidden = false;

// No version is baked into the page. A failed, limited or unavailable API leaves
// generic latest-release links intact instead of showing a stale version.
async function updateRelease() {
  const repository = "https://github.com/lkuczborski/NotchDo";
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch(
      "https://api.github.com/repos/lkuczborski/NotchDo/releases/latest",
      {
        credentials: "omit",
        signal: controller.signal,
        headers: { Accept: "application/vnd.github+json" },
      },
    );
    if (!response.ok) return;
    const release = await response.json();
    const tag = release.tag_name;
    if (
      release.draft !== false ||
      release.prerelease !== false ||
      typeof tag !== "string" ||
      tag.length > 32 ||
      !/^v\d+(?:\.\d+)+$/.test(tag) ||
      !release.published_at ||
      !Number.isFinite(Date.parse(release.published_at))
    )
      return;
    const releaseURL = `${repository}/releases/tag/${encodeURIComponent(tag)}`;
    if (release.html_url !== releaseURL) return;
    const version = tag.slice(1);
    for (const label of document.querySelectorAll("[data-release-label]")) {
      label.textContent = `Version ${version} is here`;
    }
    for (const label of document.querySelectorAll("[data-release-version]")) {
      label.textContent = `Version ${version} · `;
    }
    for (const link of document.querySelectorAll("[data-release-link]"))
      link.href = releaseURL;
    const filename = `NotchDo-${tag}-macos-universal.zip`;
    const downloadURL = `${repository}/releases/download/${encodeURIComponent(tag)}/${filename}`;
    const asset =
      Array.isArray(release.assets) &&
      release.assets.find(
        (asset) =>
          asset.name === filename &&
          asset.state === "uploaded" &&
          asset.size > 0 &&
          asset.browser_download_url === downloadURL,
      );
    if (asset) {
      for (const link of document.querySelectorAll("[data-download-link]"))
        link.href = downloadURL;
    }
  } catch {
    // The release page is always available through the original HTML links.
  } finally {
    clearTimeout(timeout);
  }
}
updateRelease();
