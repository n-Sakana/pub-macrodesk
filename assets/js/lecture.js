(function (global) {
  "use strict";

  var contentByKey = {
    "L1-1": {
      title: "改修するブックを添付",
      body: [
        "対応形式は .xlsm / .xlam / .xlsb です。",
        "中央へドラッグするか、［ファイルを選ぶ］から指定してください。",
        "Excel で開いているブックは、閉じてから添付します。"
      ].join("\n")
    },
    "L1-2": {
      title: "読み込み完了",
      body: [
        "{moduleCount} 個のモジュールを読み込みました。",
        "この時点では、元のマクロはまだ 1 文字も変更していません。",
        "内容を確認したら［次へ（依頼を作る）］へ進みます。"
      ].join("\n")
    },
    "L2-1": {
      title: "依頼の下書きを作る",
      body: [
        "プリセットを選ぶと、マニュアル本文が依頼欄へ入ります。",
        "入った文章は自由に直し、自分の言葉で書き足せます。",
        "まず、近い内容のプリセットを選んでください。"
      ].join("\n")
    },
    "L2-2": {
      title: "依頼ファイルを作成",
      body: [
        "［依頼ファイルを作成］を押すと、ブックと同じフォルダに txt を作ります。",
        "作成後はエクスプローラーが開き、そのファイルが選択されます。"
      ].join("\n")
    },
    "L2-3": {
      title: "Copilot Chat へ渡す",
      body: [
        "選択された依頼ファイルを Copilot Chat に添付します。",
        "「添付ファイルの依頼に従ってください」と送信してください。",
        "返答が届いたら、③［返答を取り込む］へ進みます。"
      ].join("\n")
    },
    "L2-4": {
      title: "依頼を言い直す",
      body: [
        "「○○モジュールの△△を□□にしてほしい」のように、場所と希望を具体的に足します。",
        "作成し直すと、新しい日時の依頼ファイルが同じフォルダにできます。"
      ].join("\n")
    },
    "L3-1": {
      title: "改修サマリーを確認",
      body: [
        "Copilot の返答冒頭にある「■ 改修サマリー」が今回の指示書です。",
        "そこに挙がったモジュールを、左の一覧から選んでください。"
      ].join("\n")
    },
    "L3-2": {
      title: "返答コードを取り込む",
      body: [
        "返答のコードブロック右上にあるコピーボタンで、コードをコピーします。",
        "［Copilotの返答を貼り付ける］を押します。Ctrl+V でも貼り付けられます。"
      ].join("\n")
    },
    "L3-3": {
      title: "差分を確認",
      body: [
        "左が現在のコード、右が貼り付けたコードです。",
        "赤は消える行、緑は増える行です。意図した変更か確認してください。",
        "意図どおりなら、残りのモジュールを取り込むか、④［改修版をビルド］へ進みます。",
        "違う場合は貼り付けを取り消すか、②へ戻って依頼を言い直します。"
      ].join("\n")
    },
    "L3-4": {
      title: "変更がありません",
      body: [
        "貼り付けた内容は、現在のコードと同じです。",
        "別モジュールのコードをコピーしていないか、改修サマリーと名前を確認してください。"
      ].join("\n")
    },
    "L3-5": {
      title: "残りのモジュールを確認",
      body: [
        "改修サマリーの箇条書きに沿って、残りのモジュールも貼り付けます。",
        "変更しないと書かれたモジュールは、対象外マークで消し込めます。",
        "未処理がなくなったら、④へ進みます。"
      ].join("\n")
    },
    "L3-6": {
      title: "ビルドへ進めます",
      body: [
        "書き戻す変更がそろいました。",
        "④［改修版をビルド］へ進み、対象と出力名を確認してください。"
      ].join("\n")
    },
    "L3-7": {
      title: "新しい標準モジュールを取り込む",
      body: [
        "返答のコードブロックをコピーします。",
        "追加するモジュール名を入力し、［新規モジュールとして取り込む］を押します。",
        "種別は標準モジュールとして追加されます。"
      ].join("\n")
    },
    "L4-1": {
      title: "新しいブックを作成",
      body: [
        "［ビルド］を押すと、同じフォルダに新しいブックを作ります。",
        "元のブックは変更しません。",
        "失敗しても元のブックは残るため、何度でもやり直せます。"
      ].join("\n")
    },
    "L4-2": {
      title: "Excel で動作確認",
      body: [
        "［出力フォルダを開く］を押し、改修版ブックを Excel で開きます。",
        "変更したマクロを実際に動かして、結果を確認してください。",
        "問題があれば元のブックを使い、①からやり直せます。"
      ].join("\n")
    },
    "L-E*": {
      title: "操作を確認してください",
      body: [
        "処理を完了できませんでした。",
        "作業状態は残っています。画面の案内を確認して、もう一度お試しください。"
      ].join("\n")
    }
  };

  var errorContentByCode = {
    "E-ATTACH-01": {
      title: "対応形式を確認",
      body: [
        "MacroDesk で扱えるのは .xlsm / .xlam / .xlsb です。",
        "対応する形式のブックを選び直してください。"
      ].join("\n")
    },
    "E-ATTACH-02": {
      title: "Excel で開いていないか確認",
      body: [
        "Excel で開いているブックは添付できません。",
        "対象ブックを閉じてから、もう一度添付してください。"
      ].join("\n")
    },
    "E-ATTACH-03": {
      title: "マクロのあるブックを確認",
      body: [
        "このブックには VBA マクロがありません。",
        "選んだファイルが改修対象か、もう一度確認してください。"
      ].join("\n")
    },
    "E-ATTACH-04": {
      title: "解析できないブックです",
      body: [
        "このブックのマクロ構造は解析できませんでした。",
        "再発する場合はログを添えて配布元へ連絡してください。"
      ].join("\n")
    },
    "E-ATTACH-05": {
      title: "xlsm 形式で保存し直す",
      body: [
        ".xlsb は現在検証中の形式です。",
        "Excel の［名前を付けて保存］で .xlsm に変換し、もう一度添付してください。"
      ].join("\n")
    },
    "E-GEN-01": {
      title: "保存先を確認",
      body: [
        "依頼ファイルを書き込めませんでした。",
        "ブックのフォルダに書き込めるか、空き容量があるか確認してください。"
      ].join("\n")
    },
    "E-GEN-02": {
      title: "依頼テンプレートを確認",
      body: [
        "依頼テンプレートを読み込めませんでした。",
        "templates\\request-template.txt を UTF-8 で保存し、差し込み変数を確認してください。"
      ].join("\n")
    },
    "E-PASTE-01": {
      title: "コードをコピーし直す",
      body: [
        "貼り付けられるコードがありませんでした。",
        "Copilot のコードブロック右上のコピーボタンで、コードをコピーし直してください。"
      ].join("\n")
    },
    "E-BUILD-01": {
      title: "もう一度ビルド",
      body: [
        "元のブックは変更されていません。もう一度ビルドしてください。",
        "再発する場合はログを添えて配布元へ連絡してください。"
      ].join("\n")
    },
    "E-BUILD-02": {
      title: "検証できない出力を破棄",
      body: [
        "安全のため、一致を確認できなかった出力は破棄しました。",
        "もう一度ビルドし、再発する場合はログを添えて配布元へ連絡してください。"
      ].join("\n")
    },
    "E-BUILD-03": {
      title: "出力先を確認",
      body: [
        "同名の出力を Excel で開いていないか、フォルダへ書き込めるか確認します。",
        "確認後、もう一度ビルドしてください。"
      ].join("\n")
    },
    "E-SYS-01": {
      title: "WebView2 Runtime が必要です",
      body: [
        "画面を表示するための WebView2 Runtime が見つかりません。",
        "起動時の案内に従い、配布元へ連絡してください。"
      ].join("\n")
    },
    "E-SYS-02": {
      title: "ログを添えて連絡",
      body: [
        "作業状態は保持されています。もう一度同じ操作を試してください。",
        "再発する場合は %LOCALAPPDATA%\\MacroDesk\\logs\\ のログを添えて配布元へ連絡してください。"
      ].join("\n")
    }
  };

  var elements = null;
  var observedError = null;

  function findSelectedModule(state) {
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

  function countPending(state) {
    var count = 0;
    state.modules.forEach(function (module) {
      if (module.status === "pending") {
        count += 1;
      }
    });
    return count;
  }

  function countChanged(state) {
    var count = 0;
    state.modules.forEach(function (module) {
      if (module.status === "changed") {
        count += 1;
      }
    });
    return count;
  }

  function getBranchKey(state) {
    var selected;

    if (state.lastError) {
      return "L-E*";
    }

    if (state.currentStep === 1) {
      return state.book ? "L1-2" : "L1-1";
    }

    if (state.currentStep === 2) {
      if (state.returnedFromStep3 && state.requestFilePath) {
        return "L2-4";
      }
      if (state.requestFilePath) {
        return "L2-3";
      }
      return state.requestText.trim() ? "L2-2" : "L2-1";
    }

    if (state.currentStep === 3) {
      if (state.newModuleIntake) {
        return "L3-7";
      }
      selected = findSelectedModule(state);
      if (selected && selected.status === "changed") {
        return "L3-3";
      }
      if (selected && selected.status === "unchanged") {
        return "L3-4";
      }
      if (countPending(state) === 0 && state.modules.length > 0) {
        return "L3-6";
      }
      if (countChanged(state) > 0) {
        return "L3-5";
      }
      return selected ? "L3-2" : "L3-1";
    }

    return state.buildResult ? "L4-2" : "L4-1";
  }

  function getContent(state, key) {
    var content = contentByKey[key];
    var changedCount;

    if (state.lastError) {
      return errorContentByCode[state.lastError.code] ||
        errorContentByCode["E-SYS-02"];
    }

    if (key === "L3-6") {
      changedCount = countChanged(state);
      if (changedCount === 0) {
        return {
          title: "書き戻す変更はありません",
          body: [
            "すべて変更なし、または対象外として確認されています。",
            "改修が必要なら、対象モジュールと貼り付けた内容をもう一度確認してください。"
          ].join("\n")
        };
      }
    }
    return content;
  }

  function formatBody(body, state) {
    return body.replace(
      "{moduleCount}",
      String(state.modules.length));
  }

  function render(state) {
    var key;
    var content;

    if (!elements) {
      return;
    }

    key = getBranchKey(state);
    content = getContent(state, key);

    elements.panel.classList.toggle(
      "is-collapsed",
      state.lectureCollapsed);
    elements.panel.classList.toggle(
      "is-error",
      state.lastError !== null);
    elements.workRegion.classList.toggle(
      "is-lecture-collapsed",
      state.lectureCollapsed);
    elements.toggle.setAttribute(
      "aria-expanded",
      state.lectureCollapsed ? "false" : "true");
    elements.toggle.setAttribute(
      "aria-label",
      state.lectureCollapsed
        ? "操作ガイドを開く"
        : "操作ガイドを折り畳む");
    elements.branch.textContent = state.lastError &&
      state.lastError.code
      ? state.lastError.code
      : key;
    elements.title.textContent = content.title;
    elements.body.textContent = formatBody(content.body, state);
    elements.panel.setAttribute("data-branch", key);
    if (state.lastError && state.lastError.code) {
      elements.panel.setAttribute(
        "data-error-code",
        state.lastError.code);
    } else {
      elements.panel.removeAttribute("data-error-code");
    }
  }

  function onStateChanged(state) {
    var newError = state.lastError;

    if (newError && newError !== observedError) {
      observedError = newError;
      if (state.lectureCollapsed) {
        global.MacroDeskState.setLectureCollapsed(false);
        return;
      }
    } else {
      observedError = newError;
    }

    render(state);
  }

  function initialize() {
    elements = {
      panel: document.getElementById("lecture-panel"),
      toggle: document.getElementById("lecture-toggle"),
      branch: document.getElementById("lecture-branch"),
      title: document.getElementById("lecture-title"),
      body: document.getElementById("lecture-body"),
      workRegion: document.getElementById("work-region")
    };

    elements.toggle.addEventListener("click", function () {
      var state = global.MacroDeskState.getState();
      global.MacroDeskState.setLectureCollapsed(
        !state.lectureCollapsed);
    });

    observedError = global.MacroDeskState.getState().lastError;
    global.MacroDeskState.subscribe(onStateChanged);
    render(global.MacroDeskState.getState());
  }

  global.MacroDeskLecture = {
    contentByKey: contentByKey,
    errorContentByCode: errorContentByCode,
    getBranchKey: getBranchKey,
    getContent: getContent,
    initialize: initialize,
    render: render
  };
}(window));
