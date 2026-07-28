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
      module.showChangesOnly = false;
    });
    state.selectedModuleName = null;
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
    module.showChangesOnly = false;
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

    module.status = "pending";
    module.changedLineCount = 0;
    module.pastedCode = null;
    module.written = false;
    module.showChangesOnly = false;
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
      path: "C:\\Work\\受注管理.xlsm",
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
    canNavigate: canNavigate,
    navigate: navigate,
    setBook: setBook,
    setAppInfo: setAppInfo,
    hasImportedModules: hasImportedModules,
    selectModule: selectModule,
    findModule: findModule,
    acceptModuleCode: acceptModuleCode,
    cancelModulePaste: cancelModulePaste,
    toggleModuleExcluded: toggleModuleExcluded,
    setModuleShowChangesOnly: setModuleShowChangesOnly,
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
