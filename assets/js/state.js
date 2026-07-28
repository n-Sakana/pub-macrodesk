(function (global) {
  "use strict";

  var listeners = [];

  var transitionTable = {
    "1-unattached": {
      1: false,
      2: false,
      3: false,
      4: false
    },
    "1-attached": {
      1: false,
      2: true,
      3: true,
      4: "changed"
    },
    "2": {
      1: true,
      2: false,
      3: true,
      4: "changed"
    },
    "3": {
      1: true,
      2: true,
      3: false,
      4: "changed"
    },
    "4": {
      1: true,
      2: true,
      3: true,
      4: false
    }
  };

  function createInitialState() {
    return {
      currentStep: 1,
      appInfo: null,
      book: null,
      modules: [],
      selectedModuleName: null,
      newModuleIntake: false,
      requestText: "",
      requestFilePath: null,
      returnedFromStep3: false,
      buildTimestamp: null,
      buildResult: null,
      lastError: null,
      lectureCollapsed: false,
      busyAction: null
    };
  }

  var state = createInitialState();

  function notify() {
    listeners.slice().forEach(function (listener) {
      listener(state);
    });
  }

  function getState() {
    return state;
  }

  function getChangedModuleCount() {
    var count = 0;
    state.modules.forEach(function (module) {
      if (module.status === "changed") {
        count += 1;
      }
    });
    return count;
  }

  function getGuideTarget() {
    var presets;
    var pendingName = null;
    var selected = null;
    var pendingCount = 0;
    var changedCount = getChangedModuleCount();

    if (state.busyAction !== null) {
      return null;
    }
    state.modules.forEach(function (module) {
      if (module.name === state.selectedModuleName) {
        selected = module;
      }
      if (module.status === "pending") {
        pendingCount += 1;
        if (pendingName === null) {
          pendingName = module.name;
        }
      }
    });

    if (state.currentStep === 1) {
      return state.book
        ? {
          id: "step1-next",
          label: "［次へ（依頼を作る）］"
        }
        : {
          id: "attach",
          label: "［ファイルを選ぶ］"
        };
    }
    if (state.currentStep === 2) {
      presets = state.appInfo && state.appInfo.presets
        ? state.appInfo.presets
        : [];
      if (state.requestFilePath) {
        return {
          id: "step2-next",
          label: "［次へ（返答を取り込む）］"
        };
      }
      if (state.requestText.trim().length === 0) {
        return presets.length > 0
          ? {
            id: "presets",
            label: "ひな形を選ぶ"
          }
          : {
            id: "request-field",
            label: "依頼内容を入力する"
          };
      }
      return {
        id: "create-request",
        label: "［依頼ファイルを作成］"
      };
    }
    if (state.currentStep === 3) {
      if (state.newModuleIntake) {
        return {
          id: "import-new-module",
          label: "［新規モジュールとして取り込む］"
        };
      }
      if (pendingCount === 0) {
        return changedCount > 0
          ? {
            id: "step3-next",
            label: "［次へ（ビルドの確認）］"
          }
          : null;
      }
      if (selected && selected.status === "pending") {
        return {
          id: "paste-response",
          label: "［返答コードを貼り付ける］"
        };
      }
      return {
        id: "module",
        moduleName: pendingName,
        label: "左の一覧で ［" + pendingName + "］ を選ぶ"
      };
    }
    if (state.buildResult &&
        state.buildResult.status === "success") {
      return {
        id: "reveal-build-output",
        label: "［出力フォルダを開く］"
      };
    }
    if (state.buildResult &&
        state.buildResult.status === "error") {
      return {
        id: "retry-build",
        label: "［もう一度ビルド］"
      };
    }
    return {
      id: "build-book",
      label: "［ビルド］"
    };
  }

  function getLineCount(value) {
    var text = typeof value === "string" ? value : "";
    var lines;

    if (!text) {
      return 0;
    }
    lines = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
    if (lines.length > 0 && lines[lines.length - 1] === "") {
      lines.pop();
    }
    return lines.length;
  }

  function getTransitionRow() {
    var key = String(state.currentStep);
    var source;
    var target = {};
    var step;

    if (state.currentStep === 1) {
      key += state.book ? "-attached" : "-unattached";
    }

    source = transitionTable[key];
    for (step = 1; step <= 4; step += 1) {
      target[step] = source[step] === "changed"
        ? getChangedModuleCount() > 0
        : source[step];
    }
    return target;
  }

  function canNavigate(targetStep) {
    var step = Number(targetStep);
    var row;

    if (step < 1 || step > 4 || step % 1 !== 0) {
      return false;
    }

    row = getTransitionRow();
    return row[step] === true;
  }

  function navigate(targetStep) {
    var step = Number(targetStep);
    var fromStep = state.currentStep;

    if (!canNavigate(step)) {
      return false;
    }

    state.currentStep = step;
    if (step !== 3) {
      state.newModuleIntake = false;
    }
    if (step === 2 && fromStep === 3) {
      state.returnedFromStep3 = true;
    }
    notify();
    return true;
  }

  function setBook(book, modules) {
    state.currentStep = 1;
    state.book = book;
    state.modules = modules || [];
    state.modules.forEach(function (module) {
      module.status = "pending";
      module.changedLineCount = 0;
      module.written = false;
      module.pastedCode = null;
      module.showChangesOnly = module.lineCount > 200;
      module.wrapDiff = false;
    });
    state.selectedModuleName = null;
    state.newModuleIntake = false;
    state.requestText = "";
    state.requestFilePath = null;
    state.returnedFromStep3 = false;
    state.buildTimestamp = null;
    state.buildResult = null;
    state.lastError = null;
    state.lectureCollapsed = false;
    notify();
  }

  function setAppInfo(appInfo) {
    state.appInfo = appInfo;
    notify();
  }

  function hasImportedModules() {
    return state.modules.some(function (module) {
      return module.status === "changed" ||
        module.status === "unchanged";
    });
  }

  function selectModule(moduleName) {
    var found = state.modules.some(function (module) {
      return module.name === moduleName;
    });

    if (!found) {
      return false;
    }

    state.selectedModuleName = moduleName;
    state.newModuleIntake = false;
    notify();
    return true;
  }

  function findModule(moduleName) {
    var found = null;

    state.modules.some(function (module) {
      if (module.name === moduleName) {
        found = module;
        return true;
      }
      return false;
    });
    return found;
  }

  function acceptModuleCode(moduleName, code, changedLineCount) {
    var module = findModule(moduleName);

    if (!module || module.status === "excluded") {
      return null;
    }

    module.pastedCode = code;
    module.changedLineCount = changedLineCount || 0;
    module.status = code === module.code ? "unchanged" : "changed";
    if (module.status === "unchanged") {
      module.changedLineCount = 0;
    }
    module.written = false;
    module.showChangesOnly = Math.max(
      module.lineCount || 0,
      getLineCount(code)) > 200;
    module.wrapDiff = false;
    notify();
    return module;
  }

  function beginNewModuleIntake() {
    if (state.currentStep !== 3 || !state.book) {
      return false;
    }

    state.selectedModuleName = null;
    state.newModuleIntake = true;
    notify();
    return true;
  }

  function cancelNewModuleIntake() {
    if (!state.newModuleIntake) {
      return false;
    }

    state.newModuleIntake = false;
    notify();
    return true;
  }

  function addNewModule(
    name,
    code,
    changedLineCount,
    lineCount
  ) {
    if (!state.newModuleIntake ||
        typeof name !== "string" ||
        typeof code !== "string" ||
        findModule(name)) {
      return null;
    }

    var module = {
      name: name,
      type: "standard",
      typeLabel: "標準モジュール",
      ext: "bas",
      lineCount: lineCount || 0,
      code: "",
      attributes: "",
      pastedCode: code,
      status: "changed",
      changedLineCount: changedLineCount || 0,
      showChangesOnly: lineCount > 200,
      wrapDiff: false,
      written: false,
      isNew: true
    };
    state.modules.push(module);
    state.selectedModuleName = name;
    state.newModuleIntake = false;
    notify();
    return module;
  }

  function cancelModulePaste(moduleName) {
    var module = findModule(moduleName);

    if (!module ||
        (module.status !== "changed" &&
         module.status !== "unchanged")) {
      return false;
    }

    if (module.isNew === true) {
      state.modules.splice(
        state.modules.indexOf(module),
        1);
      state.selectedModuleName = null;
      notify();
      return true;
    }

    module.status = "pending";
    module.changedLineCount = 0;
    module.pastedCode = null;
    module.written = false;
    module.showChangesOnly = module.lineCount > 200;
    module.wrapDiff = false;
    notify();
    return true;
  }

  function toggleModuleExcluded(moduleName) {
    var module = findModule(moduleName);

    if (!module) {
      return false;
    }
    if (module.status === "pending") {
      module.status = "excluded";
    } else if (module.status === "excluded") {
      module.status = "pending";
    } else {
      return false;
    }

    notify();
    return true;
  }

  function setModuleShowChangesOnly(moduleName, showChangesOnly) {
    var module = findModule(moduleName);

    if (!module ||
        (module.status !== "changed" &&
         module.status !== "unchanged")) {
      return false;
    }

    module.showChangesOnly = showChangesOnly === true;
    notify();
    return true;
  }

  function setModuleWrapDiff(moduleName, wrapDiff) {
    var module = findModule(moduleName);

    if (!module ||
        (module.status !== "changed" &&
         module.status !== "unchanged")) {
      return false;
    }

    module.wrapDiff = wrapDiff === true;
    notify();
    return true;
  }

  function setRequestState(requestText, requestFilePath) {
    state.requestText = requestText || "";
    state.requestFilePath = requestFilePath || null;
    notify();
  }

  function setRequestText(requestText) {
    state.requestText = requestText || "";
    notify();
  }

  function setRequestFilePath(requestFilePath) {
    state.requestFilePath = requestFilePath || null;
    notify();
  }

  function setBuildResult(result) {
    state.buildResult = result || null;
    notify();
  }

  function setBuildConfirmation(timestamp) {
    state.buildTimestamp = timestamp || null;
    state.buildResult = null;
    state.lastError = null;
    notify();
  }

  function markModulesWritten(results) {
    (results || []).forEach(function (result) {
      var module;

      if (!result || result.result !== "written") {
        return;
      }
      module = findModule(result.name);
      if (module) {
        module.written = true;
      }
    });
    notify();
  }

  function setLastError(error) {
    state.lastError = error || null;
    notify();
  }

  function setLectureCollapsed(collapsed) {
    state.lectureCollapsed = collapsed === true;
    notify();
  }

  function setBusyAction(action) {
    state.busyAction = action || null;
    notify();
  }

  function subscribe(listener) {
    listeners.push(listener);
    return function () {
      var index = listeners.indexOf(listener);
      if (index >= 0) {
        listeners.splice(index, 1);
      }
    };
  }

  function reset() {
    state = createInitialState();
    notify();
  }

  function loadDemoState() {
    state = createInitialState();
    state.currentStep = 3;
    state.appInfo = {
      version: "1.0",
      presets: [
        {
          name: "サンプル_新端末移行",
          file: "サンプル_新端末移行.md"
        }
      ]
    };
    state.book = {
      name: "受注管理.xlsm",
      path: "samples\\受注管理.xlsm",
      ext: ".xlsm"
    };
    state.modules = [
      {
        name: "Sheet1",
        type: "document",
        typeLabel: "ドキュメントモジュール",
        lineCount: 31,
        code: "Option Explicit\r\n\r\nPrivate Sub Worksheet_Activate()\r\nEnd Sub\r\n",
        pastedCode: "Option Explicit\r\n\r\nPrivate Sub Worksheet_Activate()\r\nEnd Sub\r\n",
        status: "unchanged",
        changedLineCount: 0,
        showChangesOnly: false,
        written: false
      },
      {
        name: "ThisWorkbook",
        type: "document",
        typeLabel: "ドキュメントモジュール",
        lineCount: 18,
        code: "Option Explicit\r\n",
        pastedCode: null,
        status: "pending",
        changedLineCount: 0,
        showChangesOnly: false,
        written: false
      },
      {
        name: "受注入力",
        type: "form",
        typeLabel: "フォームモジュール",
        lineCount: 76,
        code: "Option Explicit\r\n",
        pastedCode: null,
        status: "excluded",
        changedLineCount: 0,
        showChangesOnly: false,
        written: false
      },
      {
        name: "ExportHelpers",
        type: "standard",
        typeLabel: "標準モジュール",
        lineCount: 54,
        code: "Option Explicit\r\n\r\nPublic Sub ExportData()\r\nEnd Sub\r\n",
        pastedCode: "Option Explicit\r\n\r\nPublic Sub ExportData()\r\n    Debug.Print \"done\"\r\nEnd Sub\r\n",
        status: "changed",
        changedLineCount: 2,
        showChangesOnly: false,
        written: true
      },
      {
        name: "Main",
        type: "standard",
        typeLabel: "標準モジュール",
        lineCount: 84,
        code: "Option Explicit\r\n\r\nPrivate Sub SaveRecord()\r\n    If Range(\"A2\").Value = \"\" Then Exit Sub\r\n    Range(\"D2\").Value = Now\r\nEnd Sub\r\n",
        pastedCode: "Option Explicit\r\n\r\nPrivate Sub SaveRecord()\r\n    If Len(Trim$(Range(\"A2\").Value)) = 0 Then\r\n        MsgBox \"伝票番号を入力してください。\"\r\n        Exit Sub\r\n    End If\r\n    Range(\"D2\").Value = Now\r\nEnd Sub\r\n",
        status: "changed",
        changedLineCount: 4,
        showChangesOnly: false,
        written: false
      },
      {
        name: "OrderRecord",
        type: "class",
        typeLabel: "クラスモジュール",
        lineCount: 43,
        code: "Option Explicit\r\n",
        pastedCode: null,
        status: "pending",
        changedLineCount: 0,
        showChangesOnly: false,
        written: false
      }
    ];
    state.selectedModuleName = "Main";
    notify();
  }

  global.MacroDeskState = {
    transitionTable: transitionTable,
    getState: getState,
    getTransitionRow: getTransitionRow,
    getChangedModuleCount: getChangedModuleCount,
    getGuideTarget: getGuideTarget,
    canNavigate: canNavigate,
    navigate: navigate,
    setBook: setBook,
    setAppInfo: setAppInfo,
    hasImportedModules: hasImportedModules,
    selectModule: selectModule,
    findModule: findModule,
    acceptModuleCode: acceptModuleCode,
    beginNewModuleIntake: beginNewModuleIntake,
    cancelNewModuleIntake: cancelNewModuleIntake,
    addNewModule: addNewModule,
    cancelModulePaste: cancelModulePaste,
    toggleModuleExcluded: toggleModuleExcluded,
    setModuleShowChangesOnly: setModuleShowChangesOnly,
    setModuleWrapDiff: setModuleWrapDiff,
    setRequestState: setRequestState,
    setRequestText: setRequestText,
    setRequestFilePath: setRequestFilePath,
    setBuildResult: setBuildResult,
    setBuildConfirmation: setBuildConfirmation,
    markModulesWritten: markModulesWritten,
    setLastError: setLastError,
    setLectureCollapsed: setLectureCollapsed,
    setBusyAction: setBusyAction,
    subscribe: subscribe,
    reset: reset,
    loadDemoState: loadDemoState
  };
}(window));
