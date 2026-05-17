(function () {
  var storageKey = "zero-release-theme";
  var toggle = document.querySelector("[data-theme-toggle]");
  var media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null;

  function getStoredTheme() {
    try {
      return window.localStorage.getItem(storageKey);
    } catch (error) {
      return null;
    }
  }

  function storeTheme(theme) {
    try {
      window.localStorage.setItem(storageKey, theme);
    } catch (error) {
      return;
    }
  }

  function preferredTheme() {
    return media && media.matches ? "dark" : "light";
  }

  function currentTheme() {
    return document.documentElement.getAttribute("data-theme") || getStoredTheme() || preferredTheme();
  }

  function applyTheme(theme, persist) {
    document.documentElement.setAttribute("data-theme", theme);

    if (window.jtd && typeof window.jtd.setTheme === "function") {
      window.jtd.setTheme(theme);
    }

    if (persist) {
      storeTheme(theme);
    }

    if (toggle) {
      var dark = theme === "dark";
      var nextTheme = dark ? "light" : "dark";
      toggle.hidden = false;
      toggle.setAttribute("aria-label", "Use " + nextTheme + " mode");
      toggle.setAttribute("title", "Use " + nextTheme + " mode");
      toggle.setAttribute("aria-pressed", dark ? "true" : "false");
    }
  }

  applyTheme(getStoredTheme() || currentTheme(), false);

  if (toggle) {
    toggle.addEventListener("click", function () {
      applyTheme(currentTheme() === "dark" ? "light" : "dark", true);
    });
  }

  if (media && media.addEventListener) {
    media.addEventListener("change", function () {
      if (!getStoredTheme()) {
        applyTheme(preferredTheme(), false);
      }
    });
  }
}());
