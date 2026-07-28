(function (global) {
  "use strict";

  var elements = null;
  var toastTimer = null;
  var newModuleNameDraft = "";

  var typeIcons = {
    document:
      '<svg viewBox="0 0 20 20" aria-hidden="true">' +
      '<path d="M5 2.5h6l4 4V17.5H5Z"></path>' +
      '<path d="M11 2.5v4h4"></path>' +
      "</svg>",
    form:
      '<svg viewBox="0 0 20 20" aria-hidden="true">' +
      '<rect x="3" y="4" width="14" height="12" rx="1.5"></rect>' +
      '<path d="M3 7h14"></path><path d="M6 10h3v3H6Z"></path>' +
      "</svg>",
    standard:
      '<svg viewBox="0 0 20 20" aria-hidden="true">' +
      '<path d="m7 5-4 5 4 5"></path>' +
      '<path d="m13 5 4 5-4 5"></path>' +
      '<path d="m11.5 3-3 14"></path>' +
      "</svg>",
    "class":
      '<svg viewBox="0 0 20 20" aria-hidden="true">' +
      '<rect x="3.5" y="3.5" width="13" height="13" rx="2"></rect>' +
      '<path d="M12.5 7.5a3 3 0 1 0 0 5"></path>' +
      "</svg>"
  };

  var typeNames = {
    document: "ドキュメントモジュール",
    form: "フォームモジュール",
    standard: "標準モジュール",
    "class": "クラスモジュール"
  };

  var badgeDetails = {
    pending: {
      text: "未",
      label: "未処理"
    },
    changed: {
      text: "確",
      label: "確定、変更あり"
    },
    "new": {
      text: "新",
      label: "新規、変更あり"
    },
    unchanged: {
      text: "同",
      label: "確定、変更なし"
    },
    excluded: {
      text: "外",
      label: "対象外"
    },
    written: {
      text: "済",
      label: "書き込み済み"
    }
  };

  var attachErrorMessages = {
    "E-ATTACH-01":
      "対応していないファイル形式です。.xlsm、.xlam、.xlsb のいずれかを選んでください。",
    "E-ATTACH-02":
      "ブックを開けませんでした。Excel で開いている場合は閉じて、もう一度お試しください。",
    "E-ATTACH-03":
      "このブックにはマクロがありません。選んだファイルが正しいか確認してください。",
    "E-ATTACH-04":
      "ブックのマクロ構造を解析できませんでした。ログを添えて配布元へ連絡してください。",
    "E-ATTACH-05":
      ".xlsb は現在検証中の形式です。Excel で .xlsm 形式に保存し直してお試しください。"
  };

  var generalErrorMessages = {
    "E-GEN-01":
      "依頼ファイルを作成できませんでした。保存先の書き込み権限と空き容量を確認してください。",
    "E-GEN-02":
      "依頼テンプレートを読み込めませんでした。templates\\request-template.txt の存在、UTF-8 形式、差し込み変数を確認してください。",
    "E-PASTE-01":
      "貼り付けるコードがありません。Copilot のコードブロックをコピーして、もう一度お試しください。",
    "E-SYS-01":
      "WebView2 Runtime が見つかりません。起動時の案内に従って配布元へ連絡してください。",
    "E-SYS-02":
      "処理を完了できませんでした。再発する場合は %LOCALAPPDATA%\\MacroDesk\\logs\\ のログを添えて配布元へ連絡してください。"
  };

  var buildErrorMessages = {
    "E-BUILD-01":
      "ビルド処理を完了できませんでした。もう一度ビルドし、再発する場合は管理担当へ連絡してください。",
    "E-BUILD-02":
      "読み直し検証で一致しなかったため、出力ファイルを破棄しました。もう一度ビルドしてください。",
    "E-BUILD-03":
      "出力ファイルを書き込めませんでした。同名ファイルを開いていないか、保存先の権限を確認してください。"
  };

  var diffReportErrorMessage =
    "差分 HTML ファイルを作成できませんでした。改修版ブックは正常に作成されています。";

  var buildResultLabels = {
    written: "書き込み・検証 OK",
    verify_failed: "読み直し検証で不一致",
    io_error: "書き込み失敗",
    skipped_no_change: "変更なし"
  };

  function createElement(tagName, className, text) {
    var element = document.createElement(tagName);
    if (className) {
      element.className = className;
    }
    if (text !== undefined) {
      element.textContent = text;
    }
    return element;
  }

  function createActionButton(label, className, action) {
    var button = createElement(
      "button",
      "action-button " + className,
      label);
    button.type = "button";
    button.setAttribute("data-action", action);
    return button;
  }

  function getFileName(path) {
    var parts = String(path || "").split(/[\\/]/);
    return parts[parts.length - 1] || "";
  }

  function getSelectedModule(state) {
    var selected = null;
    state.modules.some(function (module) {
      if (module.name === state.selectedModuleName) {
        selected = module;
        return true;
      }
      return false;
    });
    return selected;
  }

  function showToast(message, tone) {
    var toast;
    var label;

    if (!elements || !elements.toastRegion) {
      return;
    }

    clearToast();
    toast = createElement(
      "div",
      "toast toast--" + (tone || "info"));
    label = createElement(
      "strong",
      "toast-label",
      tone === "error" ? "確認" : "完了");
    toast.setAttribute(
      "role",
      tone === "error" ? "alert" : "status");
    toast.appendChild(label);
    toast.appendChild(createElement("span", "toast-message", message));
    elements.toastRegion.appendChild(toast);

    toastTimer = global.setTimeout(function () {
      elements.toastRegion.textContent = "";
      toastTimer = null;
    }, 5000);
  }

  function clearToast() {
    if (!elements || !elements.toastRegion) {
      return;
    }
    if (toastTimer !== null) {
      global.clearTimeout(toastTimer);
      toastTimer = null;
    }
    elements.toastRegion.textContent = "";
  }

  function announce(message) {
    elements.statusAnnouncer.textContent = "";
    global.setTimeout(function () {
      elements.statusAnnouncer.textContent = message;
    }, 0);
  }

  function renderProgress(state) {
    elements.progressButtons.forEach(function (button) {
      var step = Number(button.getAttribute("data-step"));
      var current = step === state.currentStep;
      var available = global.MacroDeskState.canNavigate(step);
      var stepFourReady = step === 4 && !current && available;
      var stepFourGuided = stepFourReady &&
        state.currentStep === 3 &&
        !state.newModuleIntake &&
        getFirstPendingModuleName(state) === null;

      button.disabled = state.busyAction !== null ||
        current ||
        !available;
      button.classList.toggle(
        "is-ready",
        stepFourReady);
      button.classList.toggle(
        "is-guided-target",
        stepFourGuided);
      if (current) {
        button.setAttribute("aria-current", "step");
      } else {
        button.removeAttribute("aria-current");
      }
    });
  }

  function createModuleIcon(type) {
    var icon = createElement(
      "span",
      "module-type-icon module-type-icon--" + type);
    icon.setAttribute("aria-hidden", "true");
    icon.innerHTML = typeIcons[type] || typeIcons.standard;
    return icon;
  }

  function getBadge(module) {
    var status = module.written
      ? "written"
      : module.isNew === true
        ? "new"
        : module.status;
    var details = badgeDetails[status] || badgeDetails.pending;
    var text = details.text;

    if (status === "changed" && module.changedLineCount > 0) {
      text += " +" + module.changedLineCount;
    }

    return {
      status: status,
      text: text,
      label: details.label
    };
  }

  function getFirstPendingModuleName(state) {
    var name = null;

    state.modules.some(function (module) {
      if (module.status === "pending") {
        name = module.name;
        return true;
      }
      return false;
    });
    return name;
  }

  function getConfirmedModuleCount(state) {
    var count = 0;

    state.modules.forEach(function (module) {
      if (module.status === "changed" ||
          module.status === "unchanged") {
        count += 1;
      }
    });
    return count;
  }

  function getGlowingModuleName(state) {
    var selected;
    var confirmedCount;

    if (state.currentStep !== 3 ||
        state.newModuleIntake) {
      return null;
    }

    selected = getSelectedModule(state);
    confirmedCount = getConfirmedModuleCount(state);
    if (confirmedCount > 0) {
      return getFirstPendingModuleName(state);
    }
    if (!selected) {
      return getFirstPendingModuleName(state);
    }
    return null;
  }

  function renderModuleList(state) {
    var glowingModuleName = getGlowingModuleName(state);

    elements.moduleList.textContent = "";
    elements.moduleCount.textContent = String(state.modules.length);
    elements.moduleCount.setAttribute(
      "aria-label",
      state.modules.length + " モジュール");
    elements.bookName.textContent = state.book
      ? state.book.name
      : "ブック未添付";
    elements.moduleRegion.classList.toggle(
      "has-book",
      state.book !== null);
    elements.moduleEmpty.hidden = state.modules.length > 0;
    elements.moduleList.hidden = state.modules.length === 0;

    state.modules.forEach(function (module) {
      var item = createElement("li", "module-item");
      var row = createElement("div", "module-row");
      var button = createElement("button", "module-button");
      var name = createElement("span", "module-name", module.name);
      var lines = createElement(
        "span",
        "module-lines",
        module.lineCount + " 行");
      var badge = getBadge(module);
      var badgeElement = createElement(
        "span",
        "module-badge module-badge--" + badge.status,
        badge.text);
      var statusControl;
      var selected = module.name === state.selectedModuleName;
      var typeLabel = module.typeLabel ||
        typeNames[module.type] ||
        "VBA モジュール";

      if (module.status === "excluded") {
        item.classList.add("is-excluded");
      }
      if (module.name === glowingModuleName) {
        item.classList.add("is-next-target");
        item.classList.add("is-guided-target");
      }

      button.type = "button";
      button.setAttribute("data-module-name", module.name);
      button.setAttribute("aria-pressed", selected ? "true" : "false");
      button.setAttribute(
        "aria-label",
        module.name + "、" +
        typeLabel + "、" +
        module.lineCount + " 行、" +
        badge.label);
      badgeElement.setAttribute("title", badge.label);
      badgeElement.setAttribute("aria-hidden", "true");

      button.appendChild(createModuleIcon(module.type));
      button.appendChild(name);
      button.appendChild(lines);
      if (module.status === "pending" ||
          module.status === "excluded") {
        statusControl = createElement(
          "button",
          "module-status-button");
        statusControl.type = "button";
        statusControl.setAttribute(
          "data-module-toggle",
          module.name);
        statusControl.setAttribute(
          "aria-label",
          module.status === "excluded"
            ? module.name + " の対象外を解除"
            : module.name + " を対象外にする");
        statusControl.appendChild(badgeElement);
      } else {
        statusControl = createElement(
          "span",
          "module-status-static");
        statusControl.appendChild(badgeElement);
      }

      row.setAttribute("data-module-row-name", module.name);
      row.appendChild(button);
      row.appendChild(statusControl);
      item.appendChild(row);
      elements.moduleList.appendChild(item);
    });

    if (state.currentStep === 3 && state.book) {
      var addItem = createElement(
        "li",
        "module-add-item");
      var addButton = createElement(
        "button",
        "module-add-button",
        "新規モジュールとして取り込む");

      addButton.type = "button";
      addButton.setAttribute(
        "data-new-module-intake",
        "true");
      addButton.setAttribute(
        "aria-pressed",
        state.newModuleIntake ? "true" : "false");
      addItem.appendChild(addButton);
      elements.moduleList.appendChild(addItem);
    }
  }

  function createScreenHeader(step, title, meta) {
    var header = createElement("header", "screen-header");
    var heading = createElement("div", "screen-heading");
    var eyebrow = createElement(
      "p",
      "screen-eyebrow",
      "STEP " + step);
    var titleElement = createElement("h2", "screen-title", title);
    var metaElement = createElement("span", "screen-meta", meta || "");

    titleElement.id = "step-title-" + step;
    heading.appendChild(eyebrow);
    heading.appendChild(titleElement);
    header.appendChild(heading);
    header.appendChild(metaElement);
    return header;
  }

  function createPlaceholder(step, title, body) {
    var screen = createElement("section", "screen");
    var screenBody = createElement("div", "screen-body");
    var card = createElement("div", "placeholder-card");
    var index = createElement(
      "span",
      "placeholder-index",
      "0" + step);
    var heading = createElement("h3", "", title);
    var description = createElement("p", "", body);

    screen.setAttribute("data-step", String(step));
    screen.setAttribute("aria-labelledby", "step-title-" + step);
    card.appendChild(index);
    card.appendChild(heading);
    card.appendChild(description);
    screenBody.appendChild(card);
    screen.appendChild(createScreenHeader(step, title));
    screen.appendChild(screenBody);
    return screen;
  }

  function createDropIcon() {
    var icon = createElement("span", "drop-zone-icon");
    icon.setAttribute("aria-hidden", "true");
    icon.innerHTML =
      '<svg viewBox="0 0 24 24">' +
      '<path d="M7 3.5h7l4 4V20.5H7Z"></path>' +
      '<path d="M14 3.5v4h4"></path>' +
      '<path d="M12.5 16V9.5"></path>' +
      '<path d="m9.5 12.5 3-3 3 3"></path>' +
      "</svg>";
    return icon;
  }

  function createAttachErrorCard(error) {
    var card = createElement("section", "inline-error-card");
    var heading = createElement(
      "h3",
      "",
      getFileName(error.path) || "マクロが見つかりません");
    var message = createElement(
      "p",
      "",
      attachErrorMessages["E-ATTACH-03"]);

    card.setAttribute("role", "alert");
    card.appendChild(
      createElement("span", "inline-error-code", "E-ATTACH-03"));
    card.appendChild(heading);
    card.appendChild(message);
    return card;
  }

  function createBookCard(state) {
    var card = createElement("section", "book-card");
    var details = createElement("div", "book-card-details");
    var heading = createElement("h3", "", state.book.name);
    var path = createElement("p", "book-card-path", state.book.path);
    var stats = createElement("dl", "book-stats");
    var nextButton = createActionButton(
      "次へ（依頼を作る）",
      "action-button--primary is-guided-target",
      "step1-next");

    details.appendChild(
      createElement("span", "book-card-label", "ATTACHED BOOK"));
    details.appendChild(heading);
    details.appendChild(path);
    stats.appendChild(createElement("dt", "", "モジュール"));
    stats.appendChild(
      createElement("dd", "", String(state.modules.length)));
    stats.appendChild(createElement("dt", "", "合計行数"));
    stats.appendChild(
      createElement("dd", "", String(state.book.totalLines)));

    nextButton.disabled = state.busyAction !== null;
    card.appendChild(details);
    card.appendChild(stats);
    card.appendChild(nextButton);
    return card;
  }

  function createStepOne(state) {
    var screen = createElement("section", "screen");
    var body = createElement("div", "screen-body step-body-scroll");
    var stack = createElement("div", "step-stack step-one-stack");
    var dropZone = createElement("section", "book-drop-zone");
    var dropText = createElement("div", "drop-zone-text");
    var pickButton = createActionButton(
      state.busyAction === "pickBook"
        ? "ファイル選択を開いています"
        : state.busyAction === "attachBook"
          ? "ブックを読み込んでいます"
          : "ファイルを選ぶ",
      state.book
        ? "action-button--secondary"
        : "action-button--primary",
      "pick-book");

    screen.setAttribute("data-step", "1");
    screen.setAttribute("aria-labelledby", "step-title-1");
    dropZone.classList.toggle("is-primary-target", state.book === null);
    dropZone.classList.toggle("is-guided-target", state.book === null);
    dropText.appendChild(
      createElement("h3", "", "Excel ブックをここにドロップ"));
    dropText.appendChild(createElement(
      "p",
      "",
      "対応形式: .xlsm / .xlam / .xlsb"));
    pickButton.disabled = state.busyAction !== null;
    if (state.busyAction === "attachBook") {
      pickButton.insertBefore(
        createElement("span", "loading-spinner"),
        pickButton.firstChild);
    }

    dropZone.appendChild(createDropIcon());
    dropZone.appendChild(dropText);
    dropZone.appendChild(pickButton);
    stack.appendChild(dropZone);

    if (state.lastError &&
        state.lastError.code === "E-ATTACH-03") {
      stack.appendChild(createAttachErrorCard(state.lastError));
    }
    if (state.book) {
      stack.appendChild(createBookCard(state));
    }

    body.appendChild(stack);
    screen.appendChild(createScreenHeader(
      1,
      state.book ? "添付したブックを確認" : "対象ブックを添付",
      state.book ? state.book.ext.toUpperCase() : ""));
    screen.appendChild(body);
    return screen;
  }

  function getPresetSignature(state) {
    var presets = state.appInfo && state.appInfo.presets
      ? state.appInfo.presets
      : [];
    return presets.map(function (preset) {
      return preset.file;
    }).join("|");
  }

  function createPresetSection(state) {
    var presets = state.appInfo && state.appInfo.presets
      ? state.appInfo.presets
      : [];
    var section = createElement("section", "preset-section");
    var label = createElement("p", "field-label", "プリセット");
    var helper = createElement(
      "p",
      "field-helper",
      "選ぶと、現在の依頼文の末尾へ追記します。");
    var buttons = createElement("div", "preset-buttons");

    section.classList.toggle(
      "is-guided-target",
      !state.requestFilePath &&
        state.requestText.trim().length === 0);
    presets.forEach(function (preset) {
      var button = createActionButton(
        preset.name,
        "action-button--preset",
        "load-preset");
      button.setAttribute("data-preset-file", preset.file);
      button.disabled = state.busyAction !== null;
      buttons.appendChild(button);
    });

    section.appendChild(label);
    section.appendChild(helper);
    section.appendChild(buttons);
    return section;
  }

  function createTemplateNotice() {
    var details = createElement("details", "fixed-preview");
    var summary = createElement(
      "summary",
      "",
      "依頼ファイルのテンプレート");
    var pre = createElement(
      "pre",
      "fixed-preview-text",
      "依頼ファイルはテンプレートから生成されます。\n" +
        "内容を変えたい場合は templates\\request-template.txt を編集してください。");

    pre.setAttribute("aria-label", "依頼ファイルテンプレートの案内");
    details.appendChild(summary);
    details.appendChild(pre);
    return details;
  }

  function createRequestSuccess(state) {
    var card = createElement("section", "request-success");
    var heading = createElement(
      "h3",
      "",
      "作成済み: " + getFileName(state.requestFilePath));
    var text = createElement(
      "p",
      "",
      "選択された依頼ファイルを Copilot Chat に添付してください。");
    var actions = createElement("div", "step-actions");
    var createAgain = createActionButton(
      "もう一度作成する",
      "action-button--secondary",
      "create-request");
    var next = createActionButton(
      "次へ（返答を取り込む）",
      "action-button--primary is-guided-target",
      "step2-next");

    createAgain.disabled = state.busyAction !== null;
    next.disabled = state.busyAction !== null;
    card.appendChild(
      createElement("span", "success-label", "REQUEST FILE READY"));
    card.appendChild(heading);
    card.appendChild(text);
    actions.appendChild(createAgain);
    actions.appendChild(next);
    card.appendChild(actions);
    return card;
  }

  function createStepTwo(state) {
    var screen = createElement("section", "screen");
    var body = createElement("div", "screen-body step-body-scroll");
    var workspace = createElement("div", "request-workspace");
    var field = createElement("div", "request-field");
    var label = createElement(
      "label",
      "field-label",
      "改修してほしい内容");
    var helper = createElement(
      "p",
      "field-helper",
      "マニュアルを選んだあとも、自由に書き足せます。");
    var textarea = createElement("textarea", "request-textarea");
    var createButton;
    var presets = state.appInfo && state.appInfo.presets
      ? state.appInfo.presets
      : [];

    screen.setAttribute("data-step", "2");
    screen.setAttribute(
      "data-request-created",
      state.requestFilePath ? "1" : "0");
    screen.setAttribute(
      "data-preset-signature",
      getPresetSignature(state));
    screen.setAttribute("aria-labelledby", "step-title-2");
    label.htmlFor = "request-text";
    textarea.id = "request-text";
    textarea.value = state.requestText;
    textarea.placeholder =
      "例: 新しい端末でも同じ保存先を使えるようにしてください。";
    textarea.setAttribute("aria-describedby", "request-helper");
    textarea.disabled = state.busyAction !== null;
    helper.id = "request-helper";

    field.appendChild(label);
    field.appendChild(helper);
    field.appendChild(textarea);
    workspace.appendChild(field);
    if (presets.length > 0) {
      workspace.appendChild(createPresetSection(state));
    }
    workspace.appendChild(createTemplateNotice());

    if (state.requestFilePath) {
      workspace.appendChild(createRequestSuccess(state));
    } else {
      createButton = createActionButton(
        state.busyAction === "writeRequestFile"
          ? "依頼ファイルを作成しています"
          : "依頼ファイルを作成",
        "action-button--primary action-button--wide",
        "create-request");
      createButton.classList.toggle(
        "is-guided-target",
        state.requestText.trim().length > 0);
      createButton.disabled = state.busyAction !== null;
      if (state.busyAction === "writeRequestFile") {
        createButton.insertBefore(
          createElement("span", "loading-spinner"),
          createButton.firstChild);
      }
      workspace.appendChild(createButton);
    }

    body.appendChild(workspace);
    screen.appendChild(createScreenHeader(
      2,
      "改修依頼を作成",
      state.book ? state.book.name : ""));
    screen.appendChild(body);
    return screen;
  }

  function updateStepTwo(screen, state) {
    var expectedCreated = state.requestFilePath ? "1" : "0";
    var textarea;
    var presetSection;
    var createButton;

    if (screen.getAttribute("data-request-created") !==
        expectedCreated ||
        screen.getAttribute("data-preset-signature") !==
        getPresetSignature(state)) {
      return false;
    }

    textarea = screen.querySelector("#request-text");
    if (textarea.value !== state.requestText) {
      textarea.value = state.requestText;
    }
    textarea.disabled = state.busyAction !== null;
    presetSection = screen.querySelector(".preset-section");
    if (presetSection) {
      presetSection.classList.toggle(
        "is-guided-target",
        !state.requestFilePath &&
          state.requestText.trim().length === 0);
    }
    createButton = screen.querySelector(
      '[data-action="create-request"]');
    if (createButton && !state.requestFilePath) {
      createButton.classList.toggle(
        "is-guided-target",
        state.requestText.trim().length > 0);
    }
    Array.prototype.forEach.call(
      screen.querySelectorAll("[data-action]"),
      function (button) {
        button.disabled = state.busyAction !== null;
      });
    return true;
  }

  function normalizePastedText(value) {
    var text = String(
      value === undefined || value === null ? "" : value);
    var lines = text
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n")
      .split("\n");
    var withoutFences = [];
    var blockEnd = 0;
    var sawAttribute = false;

    lines.forEach(function (line) {
      if (line.indexOf("```") !== 0) {
        withoutFences.push(line);
      }
    });
    lines = withoutFences;

    while (blockEnd < lines.length) {
      if (/^\s*Attribute VB_/i.test(lines[blockEnd])) {
        sawAttribute = true;
        blockEnd += 1;
      } else if (/^\s*$/.test(lines[blockEnd])) {
        blockEnd += 1;
      } else {
        break;
      }
    }
    if (sawAttribute) {
      lines = lines.slice(blockEnd);
    }

    while (lines.length > 0 && /^\s*$/.test(lines[0])) {
      lines.shift();
    }
    while (lines.length > 0 &&
        /^\s*$/.test(lines[lines.length - 1])) {
      lines.pop();
    }

    return lines.length > 0
      ? lines.join("\r\n") + "\r\n"
      : "";
  }

  function padDatePart(value) {
    return value < 10 ? "0" + value : String(value);
  }

  function createOutputTimestamp(dateValue) {
    var value = dateValue || new Date();

    return String(value.getFullYear()) +
      padDatePart(value.getMonth() + 1) +
      padDatePart(value.getDate()) +
      "_" +
      padDatePart(value.getHours()) +
      padDatePart(value.getMinutes()) +
      padDatePart(value.getSeconds());
  }

  function createBuildOutputName(book, timestamp, buildFileLabel) {
    var name = book && book.name ? String(book.name) : "";
    var extension = book && book.ext ? String(book.ext) : "";
    var baseName = name;
    var label = buildFileLabel ? String(buildFileLabel) : "";

    if (extension &&
        name.slice(-extension.length).toLowerCase() ===
          extension.toLowerCase()) {
      baseName = name.slice(0, -extension.length);
    }
    if (!label) {
      throw new Error("Build file label is missing.");
    }
    return baseName + "_" + label + "_" + timestamp + extension;
  }

  function joinFinalCode(attributes, normalizedCode) {
    var header = attributes || "";
    var code = normalizedCode || "";

    if (!header) {
      return code;
    }
    if (header.slice(-2) === "\r\n") {
      return header + code;
    }
    return header + "\r\n" + code;
  }

  function createBuildModules(state) {
    var modules = [];

    state.modules.forEach(function (module) {
      var item;

      if (module.status !== "changed") {
        return;
      }
      if (typeof module.pastedCode !== "string") {
        throw new Error(
          "Changed module has no accepted code: " + module.name);
      }
      item = {
        name: module.name,
        code: module.isNew === true
          ? module.pastedCode
          : joinFinalCode(
            module.attributes,
            module.pastedCode)
      };
      if (module.isNew === true) {
        item.isNew = true;
      }
      modules.push(item);
    });
    return modules;
  }

  function getBuildCounts(state) {
    var counts = {
      changed: 0,
      pending: 0,
      excluded: 0,
      unchanged: 0
    };

    state.modules.forEach(function (module) {
      if (counts[module.status] !== undefined) {
        counts[module.status] += 1;
      }
    });
    return counts;
  }

  function createPasteIcon() {
    var icon = createElement("span", "paste-target-icon");

    icon.setAttribute("aria-hidden", "true");
    icon.innerHTML =
      '<svg viewBox="0 0 24 24">' +
      '<path d="M9 5.5h6"></path>' +
      '<path d="M9.5 3.5h5a1 1 0 0 1 1 1v2h-7v-2a1 1 0 0 1 1-1Z"></path>' +
      '<path d="M7 5.5H5.5v15h13v-15H17"></path>' +
      '<path d="M9 12h6M9 16h4"></path>' +
      "</svg>";
    return icon;
  }

  function createPasteTarget(state) {
    var pane = createElement("section", "code-pane paste-pane");
    var header = createElement("header", "code-pane-header");
    var target = createElement(
      "div",
      "paste-target is-primary-target");
    var button = createActionButton(
      state.busyAction === "readClipboard"
        ? "クリップボードを読み取っています"
        : "Copilotの返答を貼り付ける",
      "action-button--primary paste-target-button",
      "paste-response");

    if (getConfirmedModuleCount(state) === 0) {
      target.classList.add("is-guided-target");
    }
    header.appendChild(createElement("span", "", "貼り付けるコード"));
    header.appendChild(
      createElement("span", "code-pane-note", "COPILOT"));
    target.appendChild(createPasteIcon());
    target.appendChild(createElement(
      "p",
      "paste-target-lead",
      "コードブロックのコピーボタンでコピーしてから貼り付けます。"));
    button.disabled = state.busyAction !== null;
    if (state.busyAction === "readClipboard") {
      button.insertBefore(
        createElement("span", "loading-spinner"),
        button.firstChild);
    }
    target.appendChild(button);
    target.appendChild(createElement(
      "p",
      "paste-target-shortcut",
      "Ctrl+V でも貼り付けられます"));
    pane.appendChild(header);
    pane.appendChild(target);
    return pane;
  }

  function createExcludedTarget(module) {
    var pane = createElement(
      "section",
      "code-pane paste-pane paste-pane--excluded");
    var header = createElement("header", "code-pane-header");
    var target = createElement("div", "paste-target");
    var button = createActionButton(
      "対象外を解除",
      "action-button--secondary",
      "toggle-selected-excluded");

    header.appendChild(createElement("span", "", "貼り付けるコード"));
    header.appendChild(
      createElement("span", "code-pane-note", "EXCLUDED"));
    target.appendChild(createElement(
      "span",
      "paste-target-state",
      "対象外"));
    target.appendChild(createElement(
      "p",
      "paste-target-lead",
      module.name + " はチェックリスト上で対象外になっています。"));
    target.appendChild(button);
    pane.appendChild(header);
    pane.appendChild(target);
    return pane;
  }

  function createWaitingWorkspace(state, module) {
    var workspace = createElement(
      "div",
      "step-three-workspace step-three-workspace--waiting");

    workspace.appendChild(
      global.MacroDeskDiffView.createSourceView(
        document,
        module.code || ""));
    workspace.appendChild(
      module.status === "excluded"
        ? createExcludedTarget(module)
        : createPasteTarget(state));
    return workspace;
  }

  function createDiffHeadings() {
    var headings = createElement("div", "diff-column-headings");
    var left = createElement("div", "diff-column-heading");
    var right = createElement("div", "diff-column-heading");

    left.appendChild(createElement("strong", "", "現在のコード"));
    left.appendChild(
      createElement("span", "code-pane-note", "ORIGINAL"));
    right.appendChild(createElement("strong", "", "貼り付けたコード"));
    right.appendChild(
      createElement("span", "code-pane-note", "COPILOT"));
    headings.appendChild(left);
    headings.appendChild(right);
    return headings;
  }

  function createDiffWorkspace(state, module) {
    var workspace = createElement(
      "div",
      "step-three-workspace step-three-workspace--diff");
    var toolbar = createElement("div", "diff-toolbar");
    var resultGroup = createElement("div", "diff-result-group");
    var result = createElement(
      "span",
      "diff-result diff-result--" + module.status,
      module.status === "unchanged"
        ? "変更なし"
        : "変更 " + module.changedLineCount + " 行");
    var actions = createElement("div", "diff-actions");
    var rows = global.MacroDeskDiff.compare(
      module.code || "",
      module.pastedCode || "");
    var largestLineCount = Math.max(
      global.MacroDeskDiff.toLines(module.code || "").length,
      global.MacroDeskDiff.toLines(module.pastedCode || "").length);
    var tableHost = createElement("div", "diff-table-host");
    var cancel = createActionButton(
      "貼り付けを取り消す",
      "action-button--secondary action-button--compact",
      "cancel-paste");
    var repaste = createActionButton(
      state.busyAction === "readClipboard"
        ? "読み取っています"
        : "貼り直す",
      "action-button--secondary action-button--compact",
      "repaste-response");
    var contextToggle;

    result.setAttribute("role", "status");
    resultGroup.appendChild(result);
    resultGroup.appendChild(createElement(
      "span",
      "diff-result-note",
      module.status === "unchanged"
        ? "現在のコードと同一です"
        : "非 equal の diff 行数"));

    if (largestLineCount > 5000) {
      contextToggle = createActionButton(
        "変更箇所のみ表示",
        "action-button--secondary action-button--compact",
        "toggle-diff-context");
      contextToggle.setAttribute(
        "aria-pressed",
        module.showChangesOnly ? "true" : "false");
      contextToggle.classList.toggle(
        "is-active",
        module.showChangesOnly === true);
      actions.appendChild(contextToggle);
    }

    cancel.disabled = state.busyAction !== null;
    repaste.disabled = state.busyAction !== null;
    if (state.busyAction === "readClipboard") {
      repaste.insertBefore(
        createElement("span", "loading-spinner"),
        repaste.firstChild);
    }
    actions.appendChild(cancel);
    actions.appendChild(repaste);
    toolbar.appendChild(resultGroup);
    toolbar.appendChild(actions);
    workspace.appendChild(toolbar);
    workspace.appendChild(createDiffHeadings());
    workspace.appendChild(tableHost);
    global.MacroDeskDiffView.renderDiff(
      tableHost,
      rows,
      module.showChangesOnly === true);
    return workspace;
  }

  function createStepThreeEmpty() {
    var empty = createElement("div", "step-three-empty");
    var mark = createElement("span", "step-three-empty-mark", "03");

    empty.appendChild(mark);
    empty.appendChild(createElement(
      "h3",
      "",
      "取り込むモジュールを選択"));
    empty.appendChild(createElement(
      "p",
      "",
      "Copilot の改修サマリーを見て、左の一覧から対象モジュールを選んでください。"));
    return empty;
  }

  function getNewModuleNameError(state, name) {
    var identifierPattern =
      /^\p{L}[\p{L}\p{Nd}_]*$/u;
    var duplicate = false;

    if (typeof name !== "string" ||
        name.length === 0 ||
        name.length > 31 ||
        /[\uD800-\uDFFF]/.test(name) ||
        !identifierPattern.test(name)) {
      return "モジュール名は31文字以内のVBA識別子で入力してください。";
    }

    state.modules.some(function (module) {
      if (module.name.toLowerCase() ===
          name.toLowerCase()) {
        duplicate = true;
        return true;
      }
      return false;
    });
    if (duplicate) {
      return "同じ名前のモジュールが既にあります。";
    }
    return "";
  }

  function createNewModuleIntake(state) {
    var intake = createElement(
      "div",
      "new-module-intake");
    var field = createElement(
      "div",
      "new-module-field");
    var label = createElement(
      "label",
      "",
      "モジュール名");
    var input = createElement("input", "new-module-input");
    var actions = createElement(
      "div",
      "new-module-actions");
    var cancel = createActionButton(
      "キャンセル",
      "action-button--secondary",
      "cancel-new-module");
    var importButton = createActionButton(
      state.busyAction === "readClipboard"
        ? "クリップボードを読み取っています"
        : "新規モジュールとして取り込む",
      "action-button--primary is-guided-target",
      "import-new-module");

    intake.appendChild(createElement(
      "p",
      "region-kicker",
      "NEW STANDARD MODULE"));
    intake.appendChild(createElement(
      "h3",
      "",
      "新しい標準モジュールを取り込む"));
    intake.appendChild(createElement(
      "p",
      "new-module-lead",
      "コードブロックをコピーし、追加するモジュール名だけを入力します。"));
    label.htmlFor = "new-module-name";
    input.id = "new-module-name";
    input.type = "text";
    input.maxLength = 31;
    input.autocomplete = "off";
    input.spellcheck = false;
    input.value = newModuleNameDraft;
    input.disabled = state.busyAction !== null;
    input.setAttribute(
      "aria-describedby",
      "new-module-name-hint");
    field.appendChild(label);
    field.appendChild(input);
    field.appendChild(createElement(
      "p",
      "new-module-hint",
      "31文字以内のVBA識別子。種別は標準モジュールです。"));
    field.lastChild.id = "new-module-name-hint";
    cancel.disabled = state.busyAction !== null;
    importButton.disabled = state.busyAction !== null;
    if (state.busyAction === "readClipboard") {
      importButton.insertBefore(
        createElement("span", "loading-spinner"),
        importButton.firstChild);
    }
    actions.appendChild(cancel);
    actions.appendChild(importButton);
    intake.appendChild(field);
    intake.appendChild(actions);
    return intake;
  }

  function createStepThree(state) {
    var selected = getSelectedModule(state);
    var screen = createElement("section", "screen");
    var body = createElement("div", "step-three-body");

    screen.setAttribute("data-step", "3");
    screen.setAttribute("aria-labelledby", "step-title-3");
    screen.appendChild(createScreenHeader(
      3,
      state.newModuleIntake
        ? "新規モジュール"
        : selected
          ? selected.name
          : "モジュールを選択",
      state.newModuleIntake
        ? "STANDARD MODULE"
        : selected
        ? selected.typeLabel + " / " + selected.lineCount + " LINES"
        : ""));
    if (state.newModuleIntake) {
      body.appendChild(createNewModuleIntake(state));
    } else if (!selected) {
      body.appendChild(createStepThreeEmpty());
    } else if (selected.status === "changed" ||
        selected.status === "unchanged") {
      body.appendChild(createDiffWorkspace(state, selected));
    } else {
      body.appendChild(createWaitingWorkspace(state, selected));
    }
    screen.appendChild(body);
    return screen;
  }

  function createBuildStatusIcon(tone) {
    var icon = createElement(
      "span",
      "build-status-icon build-status-icon--" + tone);

    icon.setAttribute("aria-hidden", "true");
    if (tone === "success") {
      icon.innerHTML =
        '<svg viewBox="0 0 24 24">' +
        '<circle cx="12" cy="12" r="8.5"></circle>' +
        '<path d="m8.5 12 2.3 2.4 4.9-5"></path>' +
        "</svg>";
    } else {
      icon.innerHTML =
        '<svg viewBox="0 0 24 24">' +
        '<path d="M12 3.5 21 20H3Z"></path>' +
        '<path d="M12 9v5"></path>' +
        '<path d="M12 17.2v.1"></path>' +
        "</svg>";
    }
    return icon;
  }

  function createBuildCountGrid(state) {
    var counts = getBuildCounts(state);
    var grid = createElement("dl", "build-count-grid");
    var items = [
      {
        label: "書き戻し",
        value: counts.changed,
        tone: "changed"
      },
      {
        label: "未処理",
        value: counts.pending,
        tone: "pending"
      },
      {
        label: "対象外",
        value: counts.excluded,
        tone: "excluded"
      },
      {
        label: "変更なし",
        value: counts.unchanged,
        tone: "unchanged"
      }
    ];

    items.forEach(function (item) {
      var card = createElement(
        "div",
        "build-count build-count--" + item.tone);
      var value = createElement(
        "dd",
        "build-count-value",
        String(item.value));

      card.appendChild(
        createElement("dt", "build-count-label", item.label));
      card.appendChild(value);
      grid.appendChild(card);
    });
    return grid;
  }

  function createBuildTargetTable(state) {
    var section = createElement("section", "build-panel");
    var heading = createElement(
      "h3",
      "build-panel-title",
      "書き戻すモジュール");
    var tableWrap = createElement("div", "build-table-wrap");
    var table = createElement("table", "build-table");
    var thead = createElement("thead");
    var headRow = createElement("tr");
    var tbody = createElement("tbody");

    heading.id = "build-target-title";
    section.setAttribute("aria-labelledby", heading.id);
    [
      "モジュール",
      "種別",
      "変更行数"
    ].forEach(function (label) {
      var cell = createElement("th", "", label);
      cell.scope = "col";
      headRow.appendChild(cell);
    });

    state.modules.forEach(function (module) {
      var row;
      var name;
      var type;
      var count;

      if (module.status !== "changed") {
        return;
      }
      row = createElement("tr");
      name = createElement("th", "build-module-name", module.name);
      type = createElement(
        "td",
        "build-module-type",
        module.typeLabel || typeNames[module.type] || "");
      count = createElement(
        "td",
        "build-module-lines",
        module.changedLineCount + " 行");
      name.scope = "row";
      row.appendChild(name);
      row.appendChild(type);
      row.appendChild(count);
      tbody.appendChild(row);
    });

    thead.appendChild(headRow);
    table.appendChild(thead);
    table.appendChild(tbody);
    tableWrap.appendChild(table);
    section.appendChild(heading);
    section.appendChild(tableWrap);
    return section;
  }

  function createBuildOutputPanel(state) {
    var section = createElement("section", "build-panel build-output-panel");
    var heading = createElement(
      "h3",
      "build-panel-title",
      "出力ファイル");
    var fileName = createBuildOutputName(
      state.book,
      state.buildTimestamp,
      state.appInfo && state.appInfo.buildFileLabel);
    var name = createElement("code", "build-output-name", fileName);

    heading.id = "build-output-title";
    section.setAttribute("aria-labelledby", heading.id);
    name.title = fileName;
    section.appendChild(heading);
    section.appendChild(name);
    section.appendChild(createElement(
      "p",
      "build-output-note",
      "元のブックは変更せず、同じフォルダに別名で作成します。"));
    return section;
  }

  function createBuildConfirmation(state) {
    var workspace = createElement(
      "div",
      "build-workspace build-workspace--confirmation");
    var actions = createElement("div", "step-actions");
    var back = createActionButton(
      "取り込みへ戻る",
      "action-button--secondary",
      "build-back");
    var build = createActionButton(
      "ビルド",
      "action-button--primary build-primary-action is-guided-target",
      "build-book");

    build.disabled = !state.buildTimestamp ||
      state.busyAction !== null;
    back.disabled = state.busyAction !== null;
    workspace.setAttribute("data-build-view", "confirmation");
    workspace.appendChild(createBuildCountGrid(state));
    workspace.appendChild(createBuildTargetTable(state));
    workspace.appendChild(createBuildOutputPanel(state));
    actions.appendChild(back);
    actions.appendChild(build);
    workspace.appendChild(actions);
    return workspace;
  }

  function createBuildProgress(state) {
    var workspace = createElement(
      "div",
      "build-workspace build-workspace--status");
    var card = createElement("section", "build-status-card");
    var spinner = createElement("span", "build-progress-spinner");
    var outputName = createBuildOutputName(
      state.book,
      state.buildTimestamp,
      state.appInfo && state.appInfo.buildFileLabel);

    spinner.setAttribute("aria-hidden", "true");
    card.setAttribute("role", "status");
    card.setAttribute("aria-live", "polite");
    card.appendChild(spinner);
    card.appendChild(createElement(
      "h3",
      "",
      "改修版ブックをビルドしています"));
    card.appendChild(createElement(
      "p",
      "",
      "書き込み後にブックを読み直して検証しています。"));
    card.appendChild(createElement(
      "code",
      "build-progress-name",
      outputName));
    workspace.setAttribute("data-build-view", "progress");
    workspace.appendChild(card);
    return workspace;
  }

  function createBuildResultTable(results) {
    var section = createElement("section", "build-panel");
    var heading = createElement(
      "h3",
      "build-panel-title",
      "モジュール別の結果");
    var tableWrap;
    var table;
    var thead;
    var headRow;
    var tbody;

    heading.id = "build-result-title";
    section.setAttribute("aria-labelledby", heading.id);
    section.appendChild(heading);
    if (!results || results.length === 0) {
      section.appendChild(createElement(
        "p",
        "build-empty-results",
        "モジュール別の結果はありません。"));
      return section;
    }

    tableWrap = createElement("div", "build-table-wrap");
    table = createElement("table", "build-table build-result-table");
    thead = createElement("thead");
    headRow = createElement("tr");
    tbody = createElement("tbody");
    ["モジュール", "結果"].forEach(function (label) {
      var cell = createElement("th", "", label);
      cell.scope = "col";
      headRow.appendChild(cell);
    });
    results.forEach(function (result) {
      var row = createElement("tr");
      var name = createElement(
        "th",
        "build-module-name",
        result.name || "ビルド全体");
      var value = createElement(
        "td",
        "build-result-value build-result-value--" +
          (result.result || "unknown"),
        buildResultLabels[result.result] || result.result || "失敗");

      name.scope = "row";
      row.appendChild(name);
      row.appendChild(value);
      tbody.appendChild(row);
    });
    thead.appendChild(headRow);
    table.appendChild(thead);
    table.appendChild(tbody);
    tableWrap.appendChild(table);
    section.appendChild(tableWrap);
    return section;
  }

  function createBuildSuccess(state) {
    var result = state.buildResult;
    var workspace = createElement(
      "div",
      "build-workspace build-workspace--result");
    var card = createElement(
      "section",
      "build-result-card build-result-card--success");
    var headingGroup = createElement("div", "build-result-heading");
    var output = createElement(
      "code",
      "build-result-path",
      result.outputPath);
    var actions = createElement("div", "step-actions");
    var continueButton = createActionButton(
      "続けて改修する",
      "action-button--secondary",
      "build-continue");
    var reveal = createActionButton(
      state.busyAction === "revealPath"
        ? "出力フォルダを開いています"
        : "出力フォルダを開く",
      "action-button--primary is-guided-target",
      "reveal-build-output");

    output.title = result.outputPath;
    reveal.disabled = state.busyAction !== null;
    continueButton.disabled = state.busyAction !== null;
    if (state.busyAction === "revealPath") {
      reveal.insertBefore(
        createElement("span", "loading-spinner"),
        reveal.firstChild);
    }

    headingGroup.appendChild(createBuildStatusIcon("success"));
    headingGroup.appendChild(createElement(
      "div",
      "",
      ""));
    headingGroup.lastChild.appendChild(createElement(
      "span",
      "success-label",
      "BUILD VERIFIED"));
    headingGroup.lastChild.appendChild(createElement(
      "h3",
      "",
      "改修版ブックを作成しました"));
    card.appendChild(headingGroup);
    card.appendChild(output);
    card.appendChild(createElement(
      "p",
      "build-result-guidance",
      "Excel で開いてマクロの動作を確認してください。"));
    actions.appendChild(continueButton);
    actions.appendChild(reveal);
    card.appendChild(actions);
    workspace.setAttribute("data-build-view", "success");
    workspace.appendChild(card);
    workspace.appendChild(createBuildResultTable(result.results));
    return workspace;
  }

  function createBuildFailure(state) {
    var result = state.buildResult;
    var workspace = createElement(
      "div",
      "build-workspace build-workspace--result");
    var card = createElement(
      "section",
      "build-result-card build-result-card--error");
    var headingGroup = createElement("div", "build-result-heading");
    var headingText = createElement("div");
    var actions = createElement("div", "step-actions");
    var back = createActionButton(
      "取り込みへ戻る",
      "action-button--secondary",
      "build-back");
    var retry = createActionButton(
      "もう一度ビルド",
      "action-button--primary is-guided-target",
      "retry-build");

    headingText.appendChild(createElement(
      "span",
      "inline-error-code",
      result.code || "E-BUILD-01"));
    headingText.appendChild(createElement(
      "h3",
      "",
      "改修版ブックを作成できませんでした"));
    headingGroup.appendChild(createBuildStatusIcon("error"));
    headingGroup.appendChild(headingText);
    card.appendChild(headingGroup);
    card.appendChild(createElement(
      "p",
      "build-result-guidance",
      result.message));
    card.appendChild(createElement(
      "p",
      "build-output-discarded",
      "失敗した出力ファイルは残していません。元のブックは無傷です。"));
    actions.appendChild(back);
    actions.appendChild(retry);
    card.appendChild(actions);
    workspace.setAttribute("data-build-view", "error");
    workspace.appendChild(card);
    workspace.appendChild(createBuildResultTable(result.results));
    return workspace;
  }

  function createStepFour(state) {
    var screen = createElement("section", "screen");
    var body = createElement("div", "screen-body step-body-scroll");
    var counts = getBuildCounts(state);
    var workspace;

    screen.setAttribute("data-step", "4");
    screen.setAttribute("aria-labelledby", "step-title-4");
    if (state.busyAction === "buildBook") {
      workspace = createBuildProgress(state);
    } else if (state.buildResult &&
        state.buildResult.status === "success") {
      workspace = createBuildSuccess(state);
    } else if (state.buildResult &&
        state.buildResult.status === "error") {
      workspace = createBuildFailure(state);
    } else {
      workspace = createBuildConfirmation(state);
    }

    body.appendChild(workspace);
    screen.appendChild(createScreenHeader(
      4,
      "改修版ブックをビルド",
      "書き戻し " + counts.changed + " モジュール"));
    screen.appendChild(body);
    return screen;
  }

  function renderMain(state) {
    var existing = elements.main.firstElementChild;
    var screen;

    if (existing &&
        existing.getAttribute("data-step") ===
          String(state.currentStep) &&
        state.currentStep === 2 &&
        updateStepTwo(existing, state)) {
      return;
    }

    elements.main.textContent = "";
    if (state.currentStep === 1) {
      screen = createStepOne(state);
    } else if (state.currentStep === 2) {
      screen = createStepTwo(state);
    } else if (state.currentStep === 3) {
      screen = createStepThree(state);
    } else {
      screen = createStepFour(state);
    }

    elements.main.appendChild(screen);
  }

  function render(state) {
    renderProgress(state);
    renderModuleList(state);
    renderMain(state);
  }

  function getHostErrorMessage(error) {
    if (error &&
        error.data &&
        typeof error.data.userMessage === "string" &&
        error.data.userMessage) {
      return error.data.userMessage;
    }
    if (attachErrorMessages[error.code]) {
      return attachErrorMessages[error.code];
    }
    if (buildErrorMessages[error.code]) {
      return buildErrorMessages[error.code];
    }
    if (generalErrorMessages[error.code]) {
      return generalErrorMessages[error.code];
    }
    return generalErrorMessages["E-SYS-02"];
  }

  function recordClientError(error, path) {
    var code = error && error.code
      ? error.code
      : "E-SYS-02";
    var detail = error && (error.stack || error.message)
      ? error.stack || error.message
      : "No client error detail.";
    var location = path ? " path=" + path : "";

    global.hostBridge.request("writeLog", {
      level: "ERROR",
      message:
        "client error: " + code + location + " " + detail
    }).then(function () {
      return null;
    }, function () {
      return null;
    });
  }

  function handleHostError(error, path) {
    var code = error.code || "E-SYS-02";
    var viewError = {
      code: code,
      message: getHostErrorMessage(error),
      path: path || ""
    };

    global.MacroDeskState.setLastError(viewError);
    if (viewError.code !== "E-ATTACH-03") {
      showToast(viewError.message, "error");
    } else {
      clearToast();
    }
    recordClientError(error, path);
    return null;
  }

  function prepareBuildConfirmation() {
    var timestamp = createOutputTimestamp(new Date());

    global.MacroDeskState.setBuildConfirmation(timestamp);
    clearToast();
    return timestamp;
  }

  function recordInfo(message) {
    global.hostBridge.request("writeLog", {
      level: "INFO",
      message: message
    }).then(function () {
      return null;
    }, function () {
      return null;
    });
  }

  function failBuild(error) {
    var code = error && error.code
      ? error.code
      : "E-BUILD-01";
    var data = error && error.data
      ? error.data
      : {};
    var message = buildErrorMessages[code] ||
      "ビルド処理を完了できませんでした。もう一度お試しください。";
    var result = {
      status: "error",
      code: code,
      message: message,
      outputPath: data.outputPath || "",
      results: data.results || []
    };

    global.MacroDeskState.setBuildResult(result);
    global.MacroDeskState.setLastError({
      code: code,
      message: message,
      path: ""
    });
    global.MacroDeskState.setBusyAction(null);
    clearToast();
    announce("ビルドに失敗しました。" + message);
    recordInfo("build failed: " + code);
    return null;
  }

  function buildBook() {
    var state = global.MacroDeskState.getState();
    var modules;
    var outputName;
    var diffHtml = null;
    var diffGenerationError = null;

    if (state.currentStep !== 4 || state.busyAction) {
      return Promise.resolve(null);
    }
    try {
      modules = createBuildModules(state);
      if (modules.length === 0) {
        throw new Error("No changed modules are ready to build.");
      }
    } catch (error) {
      return Promise.resolve(failBuild({
        code: "E-BUILD-01",
        message: error.message
      }));
    }

    try {
      diffHtml = global.MacroDeskDiffReport.buildReport({
        bookName: state.book.name,
        buildTimestamp: state.buildTimestamp,
        modules: state.modules
      });
    } catch (error) {
      diffGenerationError = error;
    }

    outputName = createBuildOutputName(
      state.book,
      state.buildTimestamp,
      state.appInfo && state.appInfo.buildFileLabel);
    global.MacroDeskState.setLastError(null);
    global.MacroDeskState.setBusyAction("buildBook");
    clearToast();
    announce("ビルドを開始しました。");
    recordInfo(
      "build start: " + outputName +
      " (" + modules.length + " modules)");
    if (diffGenerationError) {
      recordClientError(diffGenerationError, "");
    }

    return global.hostBridge.request("buildBook", {
      outputTimestamp: state.buildTimestamp,
      modules: modules,
      diffHtml: diffHtml
    }).then(function (result) {
      var viewResult = {
        status: "success",
        outputPath: result.outputPath,
        results: result.results || [],
        diffPath: result.diffPath || "",
        diffError: result.diffError || ""
      };

      global.MacroDeskState.setLastError(null);
      global.MacroDeskState.setBuildResult(viewResult);
      global.MacroDeskState.markModulesWritten(
        viewResult.results);
      global.MacroDeskState.setBusyAction(null);
      clearToast();
      if (viewResult.diffError) {
        showToast(diffReportErrorMessage, "error");
        announce(
          "改修版ブックを作成しました。" +
          "差分 HTML ファイルは作成できませんでした。");
      } else {
        announce(
          "改修版ブックと差分 HTML ファイルを作成しました。");
      }
      recordInfo(
        "build success: " + result.outputPath +
        " (" + viewResult.results.length + " results)");
      return result;
    }, function (error) {
      return failBuild(error);
    });
  }

  function revealBuildOutput() {
    var state = global.MacroDeskState.getState();
    var result = state.buildResult;

    if (state.busyAction ||
        !result ||
        result.status !== "success" ||
        !result.outputPath) {
      return Promise.resolve(null);
    }

    global.MacroDeskState.setBusyAction("revealPath");
    return global.hostBridge.request("revealPath", {
      path: result.outputPath
    }).then(function () {
      global.MacroDeskState.setLastError(null);
      global.MacroDeskState.setBusyAction(null);
      announce("出力ファイルをエクスプローラーで選択しました。");
      return result.outputPath;
    }, function (error) {
      handleHostError(error, result.outputPath);
      global.MacroDeskState.setBusyAction(null);
      return null;
    });
  }

  function returnToBuildEdit() {
    global.MacroDeskState.setLastError(null);
    clearToast();
    if (global.MacroDeskState.navigate(3)) {
      elements.main.focus();
      return true;
    }
    return false;
  }

  function retryBuild() {
    var timestamp = prepareBuildConfirmation();

    elements.main.focus();
    announce("出力名を更新しました。内容を確認してビルドしてください。");
    return timestamp;
  }

  function attachPath(path) {
    var state = global.MacroDeskState.getState();

    if (!path || state.busyAction) {
      return Promise.resolve(null);
    }
    if (global.MacroDeskState.hasImportedModules() &&
        !global.confirm(
          "取り込み済みの内容が破棄されます。別のブックを添付しますか？")) {
      return Promise.resolve(null);
    }

    global.MacroDeskState.setBusyAction("attachBook");
    return global.hostBridge.request(
      "attachBook",
      { path: path }
    ).then(function (data) {
      newModuleNameDraft = "";
      global.MacroDeskState.setBook(data.book, data.modules);
      global.MacroDeskState.setBusyAction(null);
      clearToast();
      announce(
        data.book.name + "、" +
        data.modules.length + " モジュールを読み込みました。");
      recordInfo(
        "attach: " + data.book.path +
        " (" + data.modules.length + " modules)");
      return data;
    }, function (error) {
      handleHostError(error, path);
      global.MacroDeskState.setBusyAction(null);
      return null;
    });
  }

  function pickBook() {
    var state = global.MacroDeskState.getState();

    if (state.busyAction) {
      return Promise.resolve(null);
    }

    global.MacroDeskState.setBusyAction("pickBook");
    return global.hostBridge.request("pickBook").then(
      function (result) {
        global.MacroDeskState.setBusyAction(null);
        if (!result) {
          return null;
        }
        return attachPath(result.path);
      },
      function (error) {
        handleHostError(error, "");
        global.MacroDeskState.setBusyAction(null);
        return null;
      });
  }

  function loadPreset(file) {
    var state = global.MacroDeskState.getState();

    if (!file || state.busyAction) {
      return Promise.resolve(null);
    }

    global.MacroDeskState.setBusyAction("readPreset");
    return global.hostBridge.request(
      "readPreset",
      { file: file }
    ).then(function (result) {
      var current = global.MacroDeskState.getState();
      var nextText = global.MacroDeskPrompt.appendPreset(
        current.requestText,
        result.content);
      var textarea;

      global.MacroDeskState.setLastError(null);
      global.MacroDeskState.setRequestText(nextText);
      global.MacroDeskState.setBusyAction(null);
      clearToast();
      textarea = document.getElementById("request-text");
      if (textarea) {
        textarea.focus();
        textarea.setSelectionRange(
          textarea.value.length,
          textarea.value.length);
      }
      return result;
    }, function (error) {
      handleHostError(error, "");
      global.MacroDeskState.setBusyAction(null);
      return null;
    });
  }

  function createRequestFile() {
    var state = global.MacroDeskState.getState();
    var textarea;

    if (state.busyAction) {
      return Promise.resolve(null);
    }
    if (state.requestText.trim().length === 0) {
      showToast(
        "依頼が空です。改修してほしい内容を入力してください。",
        "error");
      textarea = document.getElementById("request-text");
      if (textarea) {
        textarea.setAttribute("aria-invalid", "true");
        textarea.focus();
      }
      return Promise.resolve(null);
    }

    global.MacroDeskState.setBusyAction("writeRequestFile");
    return global.hostBridge.request(
      "readRequestTemplate"
    ).then(function (templateResult) {
      var content;

      try {
        content = global.MacroDeskPrompt.buildRequestFile({
          template: templateResult.content,
          requestText: state.requestText,
          book: state.book,
          modules: state.modules
        });
      } catch (error) {
        handleHostError({
          code: "E-GEN-02",
          message: error.message
        }, "");
        global.MacroDeskState.setBusyAction(null);
        return null;
      }

      return global.hostBridge.request(
        "writeRequestFile",
        { content: content }
      ).then(function (result) {
        global.MacroDeskState.setLastError(null);
        global.MacroDeskState.setRequestFilePath(result.path);
        global.MacroDeskState.setBusyAction(null);
        showToast("依頼ファイルを作成しました。", "success");
        announce("依頼ファイルを作成しました。");
        recordInfo("request created: " + result.path);
        return result;
      }, function (error) {
        handleHostError(error, "");
        global.MacroDeskState.setBusyAction(null);
        return null;
      });
    }, function (error) {
      handleHostError(error, "");
      global.MacroDeskState.setBusyAction(null);
      return null;
    });
  }

  function showPasteError(focusAction) {
    var error = {
      code: "E-PASTE-01",
      message: generalErrorMessages["E-PASTE-01"]
    };
    var button;

    global.MacroDeskState.setLastError(error);
    showToast(error.message, "error");
    button = document.querySelector(
      '[data-action="' +
      (focusAction || "paste-response") +
      '"]');
    if (button) {
      button.focus();
    }
    error.stack = (new Error("Normalized paste text is empty.")).stack;
    recordClientError(error, "");
  }

  function recordPaste(module, normalizedText) {
    var lineCount = global.MacroDeskDiff.toLines(normalizedText).length;

    global.hostBridge.request("writeLog", {
      level: "INFO",
      message:
        "paste: " + module.name + " (" + lineCount + " lines)"
    }).then(function () {
      return null;
    }, function (error) {
      handleHostError(error, "");
      return null;
    });
  }

  function acceptPastedText(value, moduleName) {
    var state = global.MacroDeskState.getState();
    var name = moduleName || state.selectedModuleName;
    var module = global.MacroDeskState.findModule(name);
    var normalizedText;
    var rows;
    var changedLineCount;
    var accepted;

    if (!module || module.status === "excluded") {
      return false;
    }

    normalizedText = normalizePastedText(value);
    if (normalizedText.length === 0) {
      showPasteError();
      return false;
    }

    rows = global.MacroDeskDiff.compare(
      module.code || "",
      normalizedText);
    changedLineCount =
      global.MacroDeskDiff.countChangedLines(rows);
    global.MacroDeskState.setLastError(null);
    accepted = global.MacroDeskState.acceptModuleCode(
      name,
      normalizedText,
      changedLineCount);
    clearToast();
    announce(
      module.name +
      (accepted.status === "unchanged"
        ? " は変更なしで確定しました。"
        : " を変更 " + changedLineCount + " 行で確定しました。"));
    recordPaste(module, normalizedText);
    return true;
  }

  function pasteFromClipboard(moduleName) {
    var state = global.MacroDeskState.getState();
    var name = moduleName || state.selectedModuleName;
    var module = global.MacroDeskState.findModule(name);

    if (state.busyAction ||
        !module ||
        module.status === "excluded") {
      return Promise.resolve(false);
    }

    global.MacroDeskState.setBusyAction("readClipboard");
    return global.hostBridge.request("readClipboard").then(
      function (result) {
        global.MacroDeskState.setBusyAction(null);
        return acceptPastedText(
          result ? result.text : "",
          name);
      },
      function (error) {
        handleHostError(error, "");
        global.MacroDeskState.setBusyAction(null);
        return false;
      });
  }

  function importNewModuleFromClipboard() {
    var state = global.MacroDeskState.getState();
    var name = newModuleNameDraft;
    var nameError = getNewModuleNameError(state, name);
    var input;

    if (state.busyAction || !state.newModuleIntake) {
      return Promise.resolve(false);
    }
    if (nameError) {
      showToast(nameError, "error");
      input = document.getElementById("new-module-name");
      if (input) {
        input.setAttribute("aria-invalid", "true");
        input.focus();
      }
      return Promise.resolve(false);
    }

    global.MacroDeskState.setBusyAction("readClipboard");
    return global.hostBridge.request("readClipboard").then(
      function (result) {
        var normalizedText;
        var rows;
        var changedLineCount;
        var lineCount;
        var module;

        global.MacroDeskState.setBusyAction(null);
        normalizedText = normalizePastedText(
          result ? result.text : "");
        if (normalizedText.length === 0) {
          showPasteError("import-new-module");
          return false;
        }

        rows = global.MacroDeskDiff.compare(
          "",
          normalizedText);
        changedLineCount =
          global.MacroDeskDiff.countChangedLines(rows);
        lineCount =
          global.MacroDeskDiff.toLines(
            normalizedText).length;
        module = global.MacroDeskState.addNewModule(
          name,
          normalizedText,
          changedLineCount,
          lineCount);
        if (!module) {
          return false;
        }

        newModuleNameDraft = "";
        global.MacroDeskState.setLastError(null);
        clearToast();
        announce(
          name +
          " を新規標準モジュールとして取り込みました。");
        recordPaste(module, normalizedText);
        return true;
      },
      function (error) {
        handleHostError(error, "");
        global.MacroDeskState.setBusyAction(null);
        return false;
      });
  }

  function cancelSelectedPaste() {
    var state = global.MacroDeskState.getState();
    var name = state.selectedModuleName;
    var module = global.MacroDeskState.findModule(name);
    var wasNew = module && module.isNew === true;

    if (!name ||
        !global.MacroDeskState.cancelModulePaste(name)) {
      return false;
    }
    global.MacroDeskState.setLastError(null);
    clearToast();
    announce(name + " の貼り付けを取り消しました。");
    global.setTimeout(function () {
      var button = document.querySelector(
        wasNew
          ? '[data-new-module-intake="true"]'
          : '[data-action="paste-response"]');
      if (button) {
        button.focus();
      }
    }, 0);
    return true;
  }

  function toggleModuleExcluded(moduleName) {
    var module = global.MacroDeskState.findModule(moduleName);
    var wasExcluded;

    if (!module) {
      return false;
    }
    wasExcluded = module.status === "excluded";
    if (!global.MacroDeskState.toggleModuleExcluded(moduleName)) {
      return false;
    }
    global.MacroDeskState.setLastError(null);
    clearToast();
    announce(
      moduleName +
      (wasExcluded
        ? " の対象外を解除しました。"
        : " を対象外にしました。"));
    return true;
  }

  function toggleSelectedDiffContext() {
    var state = global.MacroDeskState.getState();
    var module = global.MacroDeskState.findModule(
      state.selectedModuleName);

    if (!module) {
      return false;
    }
    return global.MacroDeskState.setModuleShowChangesOnly(
      module.name,
      !module.showChangesOnly);
  }

  function loadAppInfo() {
    return global.hostBridge.request("getAppInfo").then(
      function (appInfo) {
        global.MacroDeskState.setAppInfo(appInfo);
        return appInfo;
      },
      function (error) {
        handleHostError(error, "");
        return null;
      });
  }

  function onProgressClick(event) {
    var button = event.currentTarget;
    var targetStep = Number(button.getAttribute("data-step"));

    if (!global.MacroDeskState.canNavigate(targetStep)) {
      return;
    }
    if (targetStep === 4) {
      prepareBuildConfirmation();
    }
    if (global.MacroDeskState.navigate(targetStep)) {
      elements.main.focus();
    }
  }

  function onModuleClick(event) {
    var toggle = event.target.closest("[data-module-toggle]");
    var button = event.target.closest("[data-module-name]");
    var newModuleButton = event.target.closest(
      "[data-new-module-intake]");

    if (toggle) {
      toggleModuleExcluded(
        toggle.getAttribute("data-module-toggle"));
      return;
    }
    if (newModuleButton) {
      newModuleNameDraft = "";
      global.MacroDeskState.setLastError(null);
      clearToast();
      global.MacroDeskState.beginNewModuleIntake();
      global.setTimeout(function () {
        var input = document.getElementById(
          "new-module-name");
        if (input) {
          input.focus();
        }
      }, 0);
      return;
    }
    if (!button) {
      return;
    }
    global.MacroDeskState.setLastError(null);
    clearToast();
    global.MacroDeskState.selectModule(
      button.getAttribute("data-module-name"));
  }

  function onModuleContextMenu(event) {
    var row = event.target.closest("[data-module-row-name]");
    var module;

    if (!row) {
      return;
    }
    module = global.MacroDeskState.findModule(
      row.getAttribute("data-module-row-name"));
    if (!module ||
        (module.status !== "pending" &&
         module.status !== "excluded")) {
      return;
    }
    event.preventDefault();
    toggleModuleExcluded(module.name);
  }

  function onMainClick(event) {
    var button = event.target.closest("[data-action]");
    var action;

    if (!button || button.disabled) {
      return;
    }

    action = button.getAttribute("data-action");
    if (action === "pick-book") {
      pickBook();
    } else if (action === "step1-next") {
      global.MacroDeskState.navigate(2);
      elements.main.focus();
    } else if (action === "load-preset") {
      loadPreset(button.getAttribute("data-preset-file"));
    } else if (action === "create-request") {
      createRequestFile();
    } else if (action === "step2-next") {
      global.MacroDeskState.navigate(3);
      elements.main.focus();
    } else if (action === "paste-response" ||
        action === "repaste-response") {
      pasteFromClipboard();
    } else if (action === "cancel-paste") {
      cancelSelectedPaste();
    } else if (action === "import-new-module") {
      importNewModuleFromClipboard();
    } else if (action === "cancel-new-module") {
      newModuleNameDraft = "";
      global.MacroDeskState.cancelNewModuleIntake();
    } else if (action === "toggle-selected-excluded") {
      toggleModuleExcluded(
        global.MacroDeskState.getState().selectedModuleName);
    } else if (action === "toggle-diff-context") {
      toggleSelectedDiffContext();
    } else if (action === "build-book") {
      buildBook();
    } else if (action === "reveal-build-output") {
      revealBuildOutput();
    } else if (action === "build-back" ||
        action === "build-continue") {
      returnToBuildEdit();
    } else if (action === "retry-build") {
      retryBuild();
    }
  }

  function onMainInput(event) {
    if (event.target.id === "new-module-name") {
      newModuleNameDraft = event.target.value;
      event.target.removeAttribute("aria-invalid");
      return;
    }
    if (event.target.id !== "request-text") {
      return;
    }

    event.target.removeAttribute("aria-invalid");
    global.MacroDeskState.setRequestText(event.target.value);
  }

  function onDocumentPaste(event) {
    var state = global.MacroDeskState.getState();
    var selected;
    var text = "";

    if (state.currentStep !== 3 || state.busyAction) {
      return;
    }
    selected = global.MacroDeskState.findModule(
      state.selectedModuleName);
    if (!selected || selected.status === "excluded") {
      return;
    }

    event.preventDefault();
    if (event.clipboardData) {
      text = event.clipboardData.getData("text");
    }
    acceptPastedText(text, selected.name);
  }

  function hasDemoQuery() {
    var query = global.location.search || "";
    return /(?:^\?|&)demo=1(?:&|$)/.test(query);
  }

  function initialize() {
    elements = {
      progressButtons: Array.prototype.slice.call(
        document.querySelectorAll(".progress-step")),
      moduleRegion: document.querySelector(".module-region"),
      moduleCount: document.getElementById("module-count"),
      bookName: document.getElementById("book-name"),
      moduleList: document.getElementById("module-list"),
      moduleEmpty: document.getElementById("module-empty"),
      main: document.getElementById("main-content"),
      statusAnnouncer: document.getElementById("status-announcer"),
      toastRegion: document.getElementById("toast-region")
    };

    elements.progressButtons.forEach(function (button) {
      button.addEventListener("click", onProgressClick);
    });
    elements.moduleList.addEventListener("click", onModuleClick);
    elements.moduleList.addEventListener(
      "contextmenu",
      onModuleContextMenu);
    elements.main.addEventListener("click", onMainClick);
    elements.main.addEventListener("input", onMainInput);
    document.addEventListener("paste", onDocumentPaste);

    global.MacroDeskState.subscribe(render);
    if (hasDemoQuery()) {
      global.MacroDeskState.loadDemoState();
    } else {
      render(global.MacroDeskState.getState());
    }

    global.MacroDeskLecture.initialize();
    global.hostBridge.on("bookDropped", function (data) {
      attachPath(data.path);
    });
    loadAppInfo();
  }

  global.MacroDeskApp = {
    initialize: initialize,
    render: render,
    showToast: showToast,
    handleHostError: handleHostError,
    attachPath: attachPath,
    pickBook: pickBook,
    loadPreset: loadPreset,
    createRequestFile: createRequestFile,
    normalizePastedText: normalizePastedText,
    createOutputTimestamp: createOutputTimestamp,
    createBuildOutputName: createBuildOutputName,
    getHostErrorMessage: getHostErrorMessage,
    getNewModuleNameError: getNewModuleNameError,
    joinFinalCode: joinFinalCode,
    createBuildModules: createBuildModules,
    prepareBuildConfirmation: prepareBuildConfirmation,
    buildBook: buildBook,
    revealBuildOutput: revealBuildOutput,
    acceptPastedText: acceptPastedText,
    pasteFromClipboard: pasteFromClipboard,
    importNewModuleFromClipboard: importNewModuleFromClipboard,
    cancelSelectedPaste: cancelSelectedPaste,
    toggleModuleExcluded: toggleModuleExcluded,
    loadAppInfo: loadAppInfo,
    loadDemoState: global.MacroDeskState.loadDemoState
  };

  document.addEventListener("DOMContentLoaded", initialize);
}(window));
