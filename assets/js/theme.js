(function (global) {
  "use strict";

  var STORAGE_KEY = "macrodesk.theme";
  var button = null;

  function getTheme() {
    return document.documentElement.getAttribute("data-theme") === "dark"
      ? "dark"
      : "light";
  }

  function updateButton(theme) {
    var isDark;
    var moon;
    var sun;
    var currentLabel;

    if (!button) {
      return;
    }

    isDark = theme === "dark";
    currentLabel = isDark ? "ダーク" : "ライト";
    moon = button.querySelector(".theme-icon--moon");
    sun = button.querySelector(".theme-icon--sun");
    moon.hidden = isDark;
    sun.hidden = !isDark;
    button.setAttribute(
      "aria-label",
      "テーマを切り替える（現在: " + currentLabel + "）");
    button.title =
      "テーマを切り替える（現在: " + currentLabel + "）";
  }

  function announce(theme) {
    var announcer = document.getElementById("status-announcer");

    if (!announcer) {
      return;
    }
    announcer.textContent = "";
    global.setTimeout(function () {
      announcer.textContent =
        (theme === "dark" ? "ダーク" : "ライト") +
        "テーマに切り替えました";
    }, 0);
  }

  function applyTheme(theme, persist) {
    document.documentElement.setAttribute("data-theme", theme);
    updateButton(theme);
    if (persist) {
      try {
        global.localStorage.setItem(STORAGE_KEY, theme);
      } catch (error) {
        /* The selected theme remains active for this session. */
      }
      announce(theme);
    }
  }

  function initialize() {
    button = document.getElementById("theme-toggle");
    applyTheme(getTheme(), false);
    if (!button) {
      return;
    }
    button.addEventListener("click", function () {
      applyTheme(getTheme() === "dark" ? "light" : "dark", true);
    });
  }

  global.MacroDeskTheme = {
    getTheme: getTheme,
    applyTheme: applyTheme
  };

  document.addEventListener("DOMContentLoaded", initialize);
}(window));
