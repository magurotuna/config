{ pkgs, lib, homeDirectory, codexPkg, ... }:

let
  tree-sitter-cli = pkgs.rustPlatform.buildRustPackage rec {
    pname = "tree-sitter";
    version = "0.26.3";
    src = pkgs.fetchFromGitHub {
      owner = "tree-sitter";
      repo = "tree-sitter";
      rev = "v${version}";
      hash = "sha256-G1C5IhRIVcWUwEI45ELxCKfbZnsJoqan7foSzPP3mMg=";
    };
    cargoHash = "sha256-kHYLaiCHyKG+DL+T2s8yumNHFfndrB5aWs7ept0X4CM=";
    nativeBuildInputs = [ pkgs.libclang pkgs.pkg-config pkgs.clang ];
    buildInputs = [ pkgs.openssl ];
    LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-isystem ${pkgs.stdenv.cc.libc.dev}/include";
    doCheck = false;  # tests require grammar fixtures
  };
  # mise 2026.6.11's OCI-layer test asserts a setuid bit (mode 0o4755) survives
  # packing, but the Nix build sandbox strips special permission bits, so it sees
  # 0o755 and fails. Skip just that one test; the other ~1349 still run. Remove
  # this override once nixpkgs disables the test upstream. Shadows pkgs.mise via
  # let-over-with, same as tree-sitter-cli above.
  mise = pkgs.mise.overrideAttrs (old: {
    checkFlags = (old.checkFlags or []) ++ [
      "--skip=oci::layer::tests::preserve_metadata_dir_layer_keeps_special_permission_bits"
    ];
  });
  tmuxCopyAction =
    if pkgs.stdenv.isDarwin
    then ''copy-pipe-and-cancel "/usr/bin/pbcopy"''
    else "copy-selection-and-cancel";

  # App that the skhd ctrl+. hotkey visibility-toggles (macOS).
  hotkeyTerminalApp = "cmux";

  # Compiled Cocoa helper that visibility-toggles an app entirely in-process
  # (NSWorkspace/NSRunningApplication), so skhd's ctrl+. is near-instant. The old
  # osascript approach paid a ~190ms Apple Event round-trip to System Events on
  # every press; reading the same state in-process is ~0.0001ms, so the dominant
  # cost is gone. Built from skhd/toggle-app.m with the stdenv clang and the
  # default macOS SDK. Only referenced from the darwin-gated services.skhd below,
  # so it is never built on Linux.
  toggleAppHelper = pkgs.stdenv.mkDerivation {
    pname = "skhd-toggle-app";
    version = "1.0";
    src = ./skhd;
    dontConfigure = true;
    buildPhase = ''
      runHook preBuild
      $CC -fobjc-arc -Wno-deprecated-declarations -O2 \
        -framework AppKit -framework Foundation \
        -o skhd-toggle-app toggle-app.m
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 skhd-toggle-app $out/bin/skhd-toggle-app
      runHook postInstall
    '';
  };
in
{
  # Home Manager needs these to know where to install things
  home.username = "yusuke";
  home.homeDirectory = homeDirectory;

  # Version of Home Manager state - don't change this casually
  home.stateVersion = "24.11";

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # ──────────────────────────────────────────────────────────────
  # XDG Config Files
  # ──────────────────────────────────────────────────────────────
  xdg.configFile."nvim/init.lua".source = ./nvim/init.lua;
  xdg.configFile."nvim/lua".source = ./nvim/lua;

  # Karabiner-Elements (macOS only). Declarative config: edit
  # ./karabiner/karabiner.json in this repo and `home-manager switch`.
  # NOTE: this deploys a read-only symlink into the Nix store, so the
  # Karabiner GUI can no longer save changes — manage keybinds here instead.
  xdg.configFile."karabiner/karabiner.json" =
    lib.mkIf pkgs.stdenv.isDarwin { source = ./karabiner/karabiner.json; };

  # cmux terminal (macOS only). tmux-style `C-t` prefix chords so the muscle
  # memory from programs.tmux below carries over to cmux's native splits/tabs
  # (which is what keeps its per-surface agent progress tracking working).
  # Action IDs verified against cmux docs; edit ./cmux/cmux.json + `home-manager switch`.
  #
  # NOT xdg.configFile (read-only store symlink): cmux re-saves this file on
  # launch via atomic write-and-rename, which replaces the symlink with a fresh
  # default template and wipes our bindings. Instead seed a *writable* copy cmux
  # can read and re-own. Overwrite on every switch (unlike seedGhosttyOverrides'
  # seed-if-missing) so the repo stays the source of truth and a clobbered file
  # self-heals; cmux.json is an override layer, so keys we omit fall back to
  # cmux's own Settings store.
  home.activation.seedCmuxConfig = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dest="${homeDirectory}/.config/cmux/cmux.json"
      mkdir -p "$(dirname "$dest")"
      install -m600 ${./cmux/cmux.json} "$dest"
    ''
  );

  # skhd (macOS only): simple global hotkey daemon, installed from nixpkgs and
  # run as a launchd agent that Home Manager manages. ctrl+. visibility-toggles
  # the terminal app (summon to front; press again to hide). One-time manual
  # step: grant skhd Accessibility permission in System Settings > Privacy.
  # Note: 0x2F is the period key (0x2B is comma). skhd only accepts UPPERCASE
  # hex keycodes (0x2f is rejected with a parse error) and has no "." key token.
  services.skhd = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = ''
      ctrl - 0x2F : ${toggleAppHelper}/bin/skhd-toggle-app ${hotkeyTerminalApp}
    '';
  };

  # Clawpatrol.app (macOS only). The clawpatrol CLI is a normal Nix package in
  # home.packages; but `clawpatrol run` also needs Clawpatrol.app installed in
  # /Applications, because it hosts the NetworkExtension system extension that
  # intercepts per-process flows. macOS validates and activates a system
  # extension from a real bundle in /Applications, so a Nix store symlink won't
  # do — we copy the store-staged bundle in, exactly like install.sh does.
  #
  # This is an imperative side effect outside the Nix store: it is NOT rolled
  # back on generation switch and NOT garbage-collected. Removing this block
  # won't uninstall the app — `sudo rm -rf /Applications/Clawpatrol.app` for that.
  # Activating the system extension itself is still a one-time manual step:
  # run `clawpatrol run`, then approve it in System Settings > Privacy & Security
  # (and allow the network filter). install.sh doesn't automate that either.
  home.activation.clawpatrolApp = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      src="${pkgs.clawpatrol-app}/Applications/Clawpatrol.app"
      dest="/Applications/Clawpatrol.app"
      # Only touch /Applications when the bundle actually differs, so routine
      # `home-manager switch` runs stay no-ops.
      if [ ! -e "$dest" ] || ! /usr/bin/diff -rq "$src" "$dest" >/dev/null 2>&1; then
        $DRY_RUN_CMD rm -rf "$dest"
        $DRY_RUN_CMD cp -R "$src" "$dest"
        # Store copy is read-only (0444/0555); make the installed bundle
        # writable so a later rm/refresh doesn't need sudo. Does not affect
        # the code signature.
        $DRY_RUN_CMD chmod -R u+w "$dest"
      fi
    ''
  );

  # ──────────────────────────────────────────────────────────────
  # Claude Code
  # ──────────────────────────────────────────────────────────────
  home.file.".claude/settings.json".text = ''
    {
      "statusLine": {
        "type": "command",
        "command": "${homeDirectory}/.claude/statusline-command.sh"
      },
      "enabledPlugins": {
        "rust-analyzer-lsp@claude-plugins-official": false,
        "code-simplifier@claude-plugins-official": true,
        "gopls-lsp@claude-plugins-official": true,
        "typescript-lsp@claude-plugins-official": true
      },
      "permissions": {
        "defaultMode": "auto",
        "allow": [
          "Bash(gh search:*)",
          "Bash(gh api:*)"
        ]
      },
      "alwaysThinkingEnabled": true,
      "plansDirectory": "./plans",
      "outputStyle": "Explanatory",
      "hooks": {
        "Stop": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "pw-play ${homeDirectory}/.local/share/sounds/claude-done.oga 2>/dev/null || afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true"
              }
            ]
          }
        ],
        "Notification": [
          {
            "hooks": [
              {
                "type": "command",
                "command": "pw-play ${homeDirectory}/.local/share/sounds/claude-notification.oga 2>/dev/null || afplay /System/Library/Sounds/Ping.aiff 2>/dev/null || true"
              }
            ]
          }
        ]
      }
    }
  '';
  # Sound files for Claude Code hooks (Linux only; macOS uses built-in sounds).
  # mkIf on the whole entry keeps it (and the Linux-only package reference) off
  # darwin entirely, where the hooks fall back to afplay.
  home.file.".local/share/sounds/claude-done.oga" = lib.mkIf pkgs.stdenv.isLinux {
    source = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/service-login.oga";
  };
  home.file.".local/share/sounds/claude-notification.oga" = lib.mkIf pkgs.stdenv.isLinux {
    source = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga";
  };

  home.file.".claude/agents/codex-reviewer.md".text = ''
    ---
    name: codex-reviewer
    description: Delegate code review to Codex CLI in headless mode
    ---

    You are a review orchestrator that delegates code review to OpenAI Codex CLI (`codex exec`) in headless mode.

    ## Overview

    You do NOT review the code yourself. Instead, you:

    1. Determine the review target from the user's request
    2. Invoke `codex exec review` to get Codex's review
    3. Present the results as-is

    ## Execution Flow

    ### Phase 1: Determine Review Target

    Based on the user's request, decide the appropriate review mode:

    - **Default (current branch vs base)**: Review changes on the current branch against the default base branch.
    - **Uncommitted changes**: If the user asks to review uncommitted / staged / working tree changes, use `--uncommitted`.
    - **Specific base branch**: If the user specifies a base branch, use `--base <branch>`.
    - **Specific commit**: If the user specifies a commit SHA, use `--commit <sha>`.

    ### Phase 2: Codex Exec Invocation

    Run `codex exec review` in headless mode with `--sandbox read-only`.

    Examples:

    ```bash
    # Review current branch changes
    codex exec review --sandbox read-only

    # Review uncommitted changes
    codex exec review --sandbox read-only --uncommitted

    # Review against a specific base branch
    codex exec review --sandbox read-only --base main

    # Review a specific commit
    codex exec review --sandbox read-only --commit abc1234
    ```

    If the user provides additional review instructions, pass them as the prompt argument:

    ```bash
    codex exec review --sandbox read-only "Focus on error handling and security"
    ```

    **Important**:
    - Set a generous timeout (up to 600 seconds)
    - Do NOT use the `-m` option — let Codex use its default model
    - `--sandbox read-only` ensures safe read-only file access

    ### Phase 3: Result Presentation

    Present the stdout output from Codex CLI as-is. Do not add edits or interpretation.
    If `codex exec` fails, report the exit code and stderr content.

    ## Error Handling

    | Situation               | Response                                   |
    | ----------------------- | ------------------------------------------ |
    | codex command not found | Guide user to install the `codex` CLI      |
    | codex exec timeout      | Report the timeout and suggest retry       |
    | Authentication error    | Guide user to verify API key configuration |
    | Empty stdout            | Report the codex exec exit code            |

    ## Notes

    - The actual review is performed by Codex CLI — this agent only handles orchestration
    - Uses stdin/stdout — no temporary files needed
  '';

  # ── Claude Code Skills ──

  home.file.".claude/skills/dig/SKILL.md".text = ''
    ---
    name: dig
    description: Iteratively ask clarifying questions to enrich the current Plan before review.
    allowed-tools: Skill(plan-review)
    ---

    # Dig

    Read the current Plan file, identify missing information needed for implementation, and iteratively ask the user clarifying questions via AskUserQuestion. Incorporate answers into the Plan, re-analyze, and repeat until sufficiently detailed.

    ## Prerequisites

    - A plan file must already exist (created via Plan mode)

    ## Execution Flow

    ### Phase 1: Detect the Latest Plan File

    ```bash
    ls -t ./plans/*.md 2>/dev/null | head -1
    ```

    If no file is found, report an error and stop.
    Use the Read tool to load the detected plan file.

    ### Phase 2: Gap Analysis

    Analyze the plan from the following perspectives and identify information gaps that would block implementation:

    #### Analysis Perspectives

    1. **Technical Design Decisions**
       - Are library / framework choices explicitly stated?
       - Are data structures and algorithms clearly chosen?
       - Is the API design (endpoints, request/response shapes) concrete?

    2. **Business Requirements Clarity**
       - Are edge-case behaviors defined?
       - Are error-state user experiences decided?
       - Are input constraints and validation rules clear?
       - Are success / failure criteria defined?

    3. **Consistency with Existing Code**
       - Is compatibility with existing APIs and type definitions considered?
       - Are naming conventions and coding standards consistent?
       - Are dependencies on existing modules clear?

    4. **Implementation Specificity**
       - Is each step broken down to an implementable granularity?
       - Are target files for creation / modification identified?
       - Is the test strategy (what to test and how) clear?

    ### Phase 3: Question Cycle

    When gaps are found, repeat this cycle:

    ```
    +-> Identify gaps
    |   |
    |   v
    |   Ask 1-3 related questions via AskUserQuestion
    |   |
    |   v
    |   Receive the user's answers
    |   |
    |   v
    |   Update the Plan file with the Edit tool
    |   |
    |   v
    |   Re-read and re-analyze the updated Plan
    |   |
    +-- If gaps remain, repeat
    ```

    #### Question Rules

    - **1-3 related questions per round** — too many at once is overwhelming.
    - **Be specific**: instead of "How will you design this?", ask "Should the return type be `Result<T, E>` or `Option<T>`?" — provide choices and concrete examples.
    - **Leverage the codebase**: read relevant code before asking. Do not ask about information already available in the code.
    - **Prioritize**: ask about implementation blockers first.

    #### Exit Conditions

    Stop the cycle when either:

    1. All analysis perspectives are sufficiently covered.
    2. The user signals completion ("that's enough", "looks good", etc.).

    ### Phase 4: Completion Report & Auto-Review

    After the cycle ends, report:

    ```
    === Dig Complete ===

    Updated Plan file: <path>

    Information added:
    - [key decisions added, as bullet points]

    Running /plan-review automatically...
    ```

    Then invoke `/plan-review` via the Skill tool automatically.

    ## Error Handling

    | Situation              | Response                                          |
    | ---------------------- | ------------------------------------------------- |
    | No plan file found     | Notify that the plans directory has no files       |
    | Plan file update fails | Report the error and suggest manual editing        |

    ## Notes

    - Plans directory: `./plans` (relative to project root)
    - The latest file is auto-detected — no path input required from the user
    - Use before `/plan-review` to improve review quality
    - Read related code before asking questions to avoid asking about things already evident in the codebase
  '';

  home.file.".claude/skills/output-learn/SKILL.md".text = ''
    ---
    name: output-learn
    description: Extract technical learnings from the session and save them to the learn repository.
    ---

    # Output Learn

    Extract and organize technical learnings from the current Claude Code session and save them to the `learn` repository.

    ## Output Destination

    ```
    ${homeDirectory}/Repo/github.com/magurotuna/learn/<category>/<topic-slug>.md
    ```

    ## Execution Flow

    ### Phase 1: Session Analysis

    Analyze the conversation history and extract technical learnings.

    Extraction targets:

    - **New knowledge**: newly learned concepts, APIs, library usage
    - **Design decisions**: architecture choices, pattern application rationale
    - **Troubleshooting**: error investigation processes and solutions
    - **Best practices**: efficient implementation methods, recommended patterns
    - **Code examples**: reusable snippets, implementation patterns

    If no learnings are found, notify the user that the session lacks technical content and stop.

    ### Phase 2: Category Selection

    Auto-detect candidate categories from keywords and confirm with the user via AskUserQuestion.

    Example categories:

    | Category         | Scope                                  |
    | ---------------- | -------------------------------------- |
    | `typescript`     | TypeScript language features, types    |
    | `rust`           | Rust language, cargo, crates           |
    | `go`             | Go language, modules                   |
    | `nix`            | Nix, NixOS, home-manager, flakes      |
    | `testing`        | Test methodology, frameworks           |
    | `git`            | Git operations, workflows              |
    | `cli`            | CLI development, command-line tools    |
    | `architecture`   | Design patterns, architecture          |
    | `library/<name>` | Specific library usage                 |
    | `devops`         | CI/CD, infrastructure                  |
    | `k8s`            | Kubernetes, Helm, k9s                  |
    | `performance`    | Performance optimization               |

    ```
    Via AskUserQuestion:
    - Present detected category candidates
    - Allow custom category input
    ```

    ### Phase 3: Markdown Generation

    Generate a markdown file based on this template.

    Filename: `<topic-slug>.md` (lowercase kebab-case)

    **Template:**

    ````markdown
    # <Title>

    ## Summary

    <1-2 sentence overview of the learning>

    ## Background

    <What situation led to this learning>

    ## What I Learned

    ### <Subtopic>

    <Detailed explanation>

    ```<language>
    // code example
    ```

    ## Key Takeaways

    - <Key point 1>
    - <Key point 2>

    ## References

    - [Link text](URL)
    ````

    ### Phase 4: User Confirmation

    Display a preview of the generated markdown and ask for confirmation via AskUserQuestion.

    Confirmation items:

    1. **Preview**: show the full generated markdown
    2. **Duplicate check**: warn if a file with the same name exists

    ```
    Via AskUserQuestion:
    - Approve and save
    - Request modifications (provide instructions)
    - Change filename
    - Cancel
    ```

    If a file with the same name exists:

    ```
    Via AskUserQuestion:
    - Overwrite
    - Save with a different name (add suffix)
    - Append to existing file
    - Cancel
    ```

    ### Phase 5: Save & Push

    After approval, save and push:

    ```bash
    LEARN_REPO="${homeDirectory}/Repo/github.com/magurotuna/learn"

    if [ ! -d "$LEARN_REPO" ]; then
      echo "learn repository not found"
      echo "Run: ghq get magurotuna/learn"
      exit 1
    fi

    # Create category directory if needed
    mkdir -p "$LEARN_REPO/<category>"

    # Write the markdown file via the Write tool

    # Git operations
    cd "$LEARN_REPO"
    git add "<category>/<topic-slug>.md"
    git commit -m "Add: <title>"
    git push origin main
    ```

    ## Error Handling

    | Situation                    | Response                                              |
    | ---------------------------- | ----------------------------------------------------- |
    | learn repo not cloned        | Suggest running `ghq get magurotuna/learn`            |
    | No technical learnings found | Notify that the session lacks technical content, stop  |
    | Git push fails               | Show the error and suggest manual resolution           |
    | Duplicate filename           | Offer overwrite / rename / append via AskUserQuestion  |
    | Directory creation fails     | Report permission error                                |

    ## Notes

    - Analyze the entire conversation history; best used toward the end of a session
    - When multiple learnings exist, pick the most important one
    - Keep code examples minimal; focus on explanation
    - Only include reference URLs that were mentioned during the session
  '';

  home.file.".claude/skills/smart-compact/SKILL.md".text = ''
    ---
    name: smart-compact
    description: Analyze session context and generate a targeted prompt for /compact to preserve important information.
    disable-model-invocation: true
    ---

    # Smart Compact

    Analyze the session context and generate a user-tailored `/compact` prompt that preserves the most important information.

    ## Execution Flow

    ### Phase 1: Session Context Analysis

    Analyze the full conversation history and extract:

    - **Active tasks**: current implementation, fix, or investigation in progress
    - **Key technical decisions**: architecture, library, or design choices made
    - **Unresolved issues**: remaining errors, bugs, or open questions
    - **File change history**: files modified/created during the session and their purpose
    - **Context-dependent information**: prerequisites and constraints needed for follow-up work

    Display the analysis as concise bullet points.

    ### Phase 2: User Interview

    Based on the Phase 1 analysis, ask the user via AskUserQuestion what to preserve.

    **Question generation rules:**

    - Dynamically generate choices based on the session content
    - Choices must include session-specific context (task names, file names, tech stack, etc.)
    - Use multiSelect: true for multiple selections
    - Provide 2-4 choices

    **Question template:**

    ```
    Question: "Which information should /compact prioritize preserving?"
    header: "Preserve"
    multiSelect: true

    Example choices (dynamically generated from session):
    - "Implementation progress and remaining work for <specific task>"
    - "Error investigation context around <filename>"
    - "Design decisions and rationale for <technology>"
    - "API specification and type definitions for <feature>"
    ```

    **Important**: Generate concrete choices derived from the session analysis, not generic presets.

    ### Phase 3: Prompt Generation

    Based on the user's selections, generate a `/compact` prompt.

    **Prompt generation guidelines:**

    1. Prioritize items the user selected
    2. Include the minimum context needed to continue the current task
    3. Include specific file names, function names, error messages, and other identifiers
    4. Frame as "what to preserve" rather than "what to discard"

    **Output format:**

    ```
    Please compress the context while prioritizing the following information:

    1. [Specific content of preserve item 1]
    2. [Specific content of preserve item 2]
    3. [Specific content of preserve item 3]

    Preserve the following accurately:
    - [Important identifiers, paths, commands, etc.]
    ```

    ### Phase 4: Confirmation & Execution Guidance

    Present the generated prompt and confirm via AskUserQuestion.

    ```
    Via AskUserQuestion:
    - "Run compact with this prompt?"
      - "Run it" — display the command
      - "Modify" — apply modifications
      - "Cancel"
    ```

    **On approval:**

    Output the command in a copyable format:

    ````
    Copy and run the following command:

    ```
    /compact <generated prompt>
    ```
    ````

    **On modification request:**

    Regenerate the prompt reflecting the user's feedback and re-confirm.

    ## Error Handling

    | Situation                        | Response                                     |
    | -------------------------------- | -------------------------------------------- |
    | Session too short for compaction | Notify that compact is likely unnecessary     |
    | Nothing worth preserving         | Suggest a bare `/compact` with no arguments  |
    | User cancels                     | Do nothing and exit                          |

    ## Notes

    - `/compact` is a built-in Claude Code command and cannot be invoked programmatically from a skill
    - The generated command must be copied and run manually by the user
    - Most effective when the session is long and context is running low
  '';

  home.file.".claude/skills/plan-refine/SKILL.md".text = ''
    ---
    name: plan-refine
    description: Iteratively refine the current Plan by applying Codex review feedback until Codex has no more issues to raise.
    allowed-tools: Bash(codex exec *), Bash(ls *), Read, Edit
    ---

    # Plan Refine

    Improve the latest plan file by running Codex review in a loop: each round, apply Codex's feedback to the plan and re-review. Stop when Codex signals no further issues, or when the iteration cap is reached.

    ## Prerequisites

    - A plan file must already exist under `./plans/` (created via Plan mode)
    - The `codex` CLI must be installed and authenticated (`which codex` succeeds)

    ## Arguments

    | Argument        | Required | Default | Description                                                       |
    | --------------- | -------- | ------- | ----------------------------------------------------------------- |
    | plan-name       | No       | —       | Plan filename to refine (with or without `.md`). If omitted, ask the user to pick one interactively. |
    | max-iterations  | No       | 8       | Hard cap on review rounds to prevent runaway loops                |

    ## Execution Flow

    ### Phase 1: Resolve the Plan File

    Resolve `<plan_path>` using one of the two paths below.

    #### 1a: Plan name provided

    If the user passed a `plan-name` argument:

    1. Normalize it: strip any leading `./plans/`, then append `.md` if the argument has no extension.
    2. Check that `./plans/<normalized>` exists. If it does not, list the available plans under `./plans/` and stop with a clear error — do NOT silently fall back to auto-selection.
    3. Set `<plan_path>` to the resolved path.

    #### 1b: No plan name provided — ask the user

    1. List candidates:

       ```bash
       ls -t ./plans/*.md 2>/dev/null
       ```

    2. If the list is empty, report that `./plans/` has no markdown files and stop.
    3. If exactly one candidate exists, use it directly and tell the user which file was picked.
    4. If two or more candidates exist, use `AskUserQuestion` to let the user choose. Present the filenames (most recently modified first) as options, with a short preview (e.g. the plan's H1 title) as the option description when easily available. Wait for the user's answer; do NOT guess.

    Once `<plan_path>` is set, use the Read tool to load it before entering the refinement loop.

    ### Phase 2: Refinement Loop

    Run the following cycle up to `max-iterations` times:

    ```
    +-> Run Codex review on <plan_path>
    |   |
    |   v
    |   Parse review output
    |   |
    |   +--> Contains "NO_FURTHER_ISSUES" marker? --> exit loop
    |   |
    |   v
    |   Edit the plan to incorporate feedback
    |   |
    |   v
    |   Re-read the updated plan
    |   |
    +-- Next iteration
    ```

    #### 2a: Codex Review Invocation

    Invoke Codex directly with a prompt that forces a deterministic termination signal. Use `--sandbox read-only` so Codex cannot modify the plan itself — only Claude edits the plan based on the feedback.

    ```bash
    codex exec --sandbox read-only "$(cat <<'EOF'
    You are reviewing a software implementation plan. Read the file at <plan_path> and critique it from these angles:

    1. Technical correctness and feasibility
    2. Missing steps, edge cases, or error handling
    3. Inconsistencies or ambiguities
    4. Risks, unclear ownership, or untested assumptions
    5. Concrete improvements (name specific sections / lines)

    Output format:
    - If substantive issues remain, list them as a numbered list. Each item: (a) what is wrong, (b) why it matters, (c) a concrete suggested fix. Do not include the marker below.
    - If the plan is solid and you have no remaining substantive issues, output exactly one line: NO_FURTHER_ISSUES
    - Do not nitpick wording. Only raise issues that would materially affect implementation quality.
    EOF
    )" < /dev/null
    ```

    **Critical: the `< /dev/null` redirect is mandatory.** When stdin is not a TTY (which is always the case inside Claude Code's Bash tool), `codex exec` treats stdin as piped input to be appended to the prompt and will block forever waiting for EOF. Redirecting from `/dev/null` closes stdin immediately so Codex stops waiting and proceeds. Never omit this, even when using `run_in_background`.

    Substitute `<plan_path>` with the actual path. Do NOT use `-m` — let Codex pick its default model.

    **Run the command as a background Bash job** (`run_in_background: true`) to avoid the 10-minute foreground timeout — long reviews can exceed that cap. After starting the job:

    1. Wait for the background-job completion notification from the harness. Do NOT poll or sleep in a loop; the notification arrives automatically.
    2. Once notified, read the job's stdout via the background-job handle and use it as the review output.
    3. If the job exits non-zero, treat it as a Codex failure per the Safety Guards below (report exit code and stderr; do not retry).

    #### 2b: Termination Check

    - If stdout contains the exact line `NO_FURTHER_ISSUES`, exit the loop successfully.
    - Otherwise, treat stdout as the review feedback and continue.

    #### 2c: Apply Feedback

    For each substantive issue in the review:

    1. Decide whether the feedback is actionable and correct. If a suggestion conflicts with explicit decisions already recorded in the plan, note the tension in the plan rather than silently reversing the decision.
    2. Use the Edit tool to update `<plan_path>` — clarify ambiguities, add missing steps, tighten error handling, resolve inconsistencies.
    3. After editing, re-read the file so the next Codex round sees the current version from disk.

    #### 2d: Safety Guards

    - **Iteration cap**: never exceed `max-iterations` rounds (default 8). If hit, exit the loop and report that Codex still had open issues.
    - **No-progress detection**: if two consecutive rounds return nearly identical feedback, exit the loop and surface the stuck issue to the user rather than looping fruitlessly.
    - **Codex failure**: if `codex exec` returns a non-zero exit code, stop the loop and report the exit code plus stderr. Do not silently retry.

    ### Phase 3: Completion Report

    Report to the user in this format:

    ```
    === Plan Refine Complete ===

    Plan file: <plan_path>
    Rounds completed: <N>
    Termination reason: <no-further-issues | max-iterations-reached | no-progress | codex-error>

    Key changes applied:
    - <bullet point per substantive edit>

    Final Codex verdict:
    <last review output, or "NO_FURTHER_ISSUES">
    ```

    ## Error Handling

    | Situation                     | Response                                                   |
    | ----------------------------- | ---------------------------------------------------------- |
    | No plan file found            | Notify that `./plans/` has no markdown files and stop      |
    | `codex` CLI not on PATH       | Instruct the user to install and authenticate `codex`      |
    | `codex exec` runs very long   | Expected — it's backgrounded. Keep waiting for the completion notification, don't kill it |
    | `codex exec` hangs with 0 bytes output | Almost always a missing `< /dev/null`. Kill it, add the stdin redirect, retry |
    | Authentication error          | Guide the user to check `codex login` status               |
    | Plan edit fails               | Report the error and stop — do not continue reviewing stale content |

    ## Notes

    - Plans directory: `./plans/` (relative to project root)
    - Only the latest plan file by modification time is refined
    - Codex runs `--sandbox read-only`: it cannot modify the plan — only Claude does, based on Codex feedback
    - The `NO_FURTHER_ISSUES` sentinel is the sole termination signal; never infer "good enough" from vibes
    - Prefer this skill *after* `/dig` (which fills gaps via user Q&A) and *before* `/plan-review` (which produces a final report)
  '';

  home.file.".claude/skills/plan-review/SKILL.md".text = ''
    ---
    name: plan-review
    description: Review the current plan by auto-selecting appropriate reviewer agents based on project characteristics.
    allowed-tools: Bash(codex exec *)
    ---

    # Plan Review

    Review the latest plan file by analyzing project characteristics, selecting appropriate reviewer agents, and running them in parallel.

    ## Prerequisites

    - A plan file must already exist (created via Plan mode)
    - Reviewer agents must be defined in `~/.claude/agents/`

    ## Arguments

    | Argument   | Required | Description                                             |
    | ---------- | -------- | ------------------------------------------------------- |
    | agent-name | No       | Explicit agent name. Omit for auto-selection (recommended) |

    ## Execution Flow

    ### Phase 1: Detect the Latest Plan File

    ```bash
    ls -t ./plans/*.md 2>/dev/null | head -1
    ```

    If no file is found, report an error and stop.
    Use the Read tool to load the detected plan file.

    ### Phase 2: Reviewer Selection

    If an agent name is provided as an argument, use only that agent (manual mode).

    If no argument is given (recommended), auto-select reviewers based on project signals.

    #### 2a: Project Signal Detection

    Collect the following signals **in parallel**:

    | Signal             | Detection Method                                         |
    | ------------------ | -------------------------------------------------------- |
    | Rust project       | `Cargo.toml` exists, or `*.rs` files present             |
    | Go project         | `go.mod` exists, or `*.go` files present                 |
    | TypeScript project | `tsconfig.json` exists, or `*.ts` files present          |
    | codex CLI available| `which codex` succeeds                                   |
    | Refactoring-related| Plan body contains refactoring keywords (see below)      |
    | Test infrastructure| Test files, test config, or test directories exist        |

    **Refactoring keywords** (checked against plan body):

    - refactor / refactoring / duplication / DRY / extract / consolidate / deduplicate

    **Test infrastructure detection** — at least one primary signal:

    - Test files: `*.test.ts`, `*.spec.ts`, `*.test.tsx`, `*.spec.tsx`, `*.test.js`, `*.spec.js`, `*_test.go`, `*_test.rs`
    - Test configs: `vitest.config.*`, `jest.config.*`, `playwright.config.*`
    - Test directories: `tests/`, `__tests__/`, `test/`

    #### 2b: Reviewer Matching Rules

    Based on collected signals, select reviewers:

    | Condition                         | Reviewer to Launch  |
    | --------------------------------- | ------------------- |
    | codex CLI is available            | `codex-reviewer`    |

    <!-- Future reviewers can be added here:
    | Rust project detected             | `rust-reviewer`     |
    | Refactoring keywords in plan      | `similarity`        |
    | Test infrastructure exists        | `tdd-reviewer`      |
    -->

    - If multiple conditions match, launch **all** matching reviewers (in parallel).
    - If no conditions match, notify the user and suggest manual agent selection.

    #### 2c: Display Selection Results

    Before launching, show the selection summary:

    ```
    Project analysis:
      - codex CLI: Y (available)

    Launching reviewers: codex-reviewer
    ```

    ### Phase 3: Parallel Review Execution

    Launch **all selected agents in parallel** via the Agent tool.

    Prompt passed to each agent:

    ```
    Please review the following Plan file.
    Based on your expertise, provide feedback on:
    1. Technical accuracy
    2. Potential issues and risks
    3. Improvement suggestions
    4. Overlooked considerations

    ---

    Plan File: <path>

    ---

    <content>
    ```

    **Important**: Agent tool calls are independent — always invoke multiple agents in a **single message** for true parallelism.

    ### Phase 4: Result Aggregation & Report

    Aggregate all reviewer results in this format:

    ```
    === Plan Review Results ===

    --- codex-reviewer ---
    [feedback from codex-reviewer]

    === Summary ===
    Cross-cutting summary of all reviewer feedback, with high-severity issues listed first.
    ```

    ## Reviewer Registry

    | Agent Name      | Auto-Select Condition                | Expertise                              |
    | --------------- | ------------------------------------ | -------------------------------------- |
    | codex-reviewer  | codex CLI is available               | General architecture & design review   |

    <!-- To add a new reviewer:
    1. Create the agent in ~/.claude/agents/<name>.md
    2. Add a row to this table
    3. Add a matching rule in Phase 2b
    -->

    ## Error Handling

    | Situation                            | Response                                          |
    | ------------------------------------ | ------------------------------------------------- |
    | No plan file found                   | Notify that the plans directory has no files       |
    | No matching reviewers in auto-select | List available agents and suggest manual selection |
    | Specified agent not found            | List available agents and report error             |
    | Some agents fail                     | Report successful results and note failures        |

    ## Notes

    - Plans directory: `./plans` (relative to project root)
    - Latest file is auto-detected — no path input required
    - Both signal collection and review execution are **parallelized** for speed
    - Manual mode is fully supported for backward compatibility
    - To add a new reviewer, update the Reviewer Registry table and the Phase 2b matching rules
  '';

  home.file.".claude/skills/standup/SKILL.md".text = ''
    ---
    name: standup
    description: Summarize your recent GitHub activity (PRs, reviews, issues) for standup reporting.
    allowed-tools: Bash(gh *), AskUserQuestion
    ---

    # Standup

    Summarize your recent GitHub activity to help prepare for standup meetings.

    ## Execution Flow

    ### Phase 1: Determine Time Range

    Use AskUserQuestion to ask the user:

    > What time range should I cover? (default: yesterday)
    >
    > Examples: "yesterday", "last 3 days", "this week", "2026-03-18..2026-03-20"

    If the user accepts the default or says something like "yesterday" / "default", use yesterday's date range.
    Otherwise, parse the user's input into a date range.

    Compute the `--since` ISO 8601 date string (e.g. `2026-03-21T00:00:00`) accordingly.

    ### Phase 2: Gather GitHub Activity

    Run the following `gh` commands in parallel to collect activity. Replace `SINCE` with the computed date and `USERNAME` with the output of `gh api user -q .login`.

    **PRs authored:**
    ```bash
    gh search prs --author=USERNAME --created=">SINCE" --json repository,title,url,state,createdAt,closedAt --limit 50
    ```

    **PRs reviewed:**
    ```bash
    gh search prs --reviewed-by=USERNAME --updated=">SINCE" --json repository,title,url,state,createdAt --limit 50
    ```

    **Issues authored or assigned:**
    ```bash
    gh search issues --author=USERNAME --created=">SINCE" --json repository,title,url,state,createdAt --limit 50
    gh search issues --assignee=USERNAME --updated=">SINCE" --json repository,title,url,state,createdAt --limit 50
    ```

    **Review comments (optional, for richer context):**
    ```bash
    gh api "search/issues?q=commenter:USERNAME+updated:>SINCE+type:pr" --jq '.items[] | {title,html_url,repository_url}' 2>/dev/null
    ```

    ### Phase 3: Summarize

    Deduplicate results and organize into a concise standup summary using this format:

    ```
    ## Standup Summary (DATE_RANGE)

    ### PRs Created
    - [repo] title (status) — url

    ### PRs Reviewed
    - [repo] title — url

    ### Issues
    - [repo] title (status) — url

    ### Other Activity
    - (any review comments on PRs not already listed)
    ```

    Omit sections that have no items. Keep descriptions brief — this is for a quick verbal standup.

    ### Phase 4: Offer Follow-up

    After presenting the summary, ask:

    > Would you like me to go deeper on any item, or adjust the time range?

    ## Notes

    - Requires `gh` CLI to be authenticated (`gh auth status`)
    - All data comes from GitHub's search API via `gh`
    - If API rate limits are hit, report the error and suggest narrowing the time range
  '';

  home.file.".claude/statusline-command.sh" = {
    executable = true;
    text = ''
      #!/bin/bash

      # Read JSON input
      input=$(cat)

      # Extract current directory from JSON
      cwd=$(echo "$input" | jq -r '.workspace.current_dir')

      # Get username
      user=$(whoami)

      # Get hostname (short form)
      host=$(hostname -s)

      # Get current directory (use basename for short form, or full path)
      current_dir="$cwd"

      # Get git branch if in a git repository
      git_branch=""
      if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
          # Skip optional locks to avoid blocking
          branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
          if [ -n "$branch" ]; then
              git_branch=" ($branch)"
          fi
      fi

      # Format the output with colors (using printf for ANSI codes)
      # Note: Colors will be dimmed by Claude Code
      printf "\033[01;32m%s@%s\033[00m:\033[01;34m%s\033[00m%s" "$user" "$host" "$current_dir" "$git_branch"
    '';
  };

  # ──────────────────────────────────────────────────────────────
  # Packages to install
  # ──────────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    # Core CLI tools
    ripgrep
    fd
    eza
    bat
    fzf
    jq
    tree
    dust
    tokei
    neovim
    fastfetch
    htop
    openssl
    unzip

    # Git tools
    ghq
    git-lfs
    delta
    gnupg
    lazygit

    # Network / HTTP
    dnsutils
    nghttp2
    oha
    websocat
    tailscale

    # Kubernetes
    k9s
    stern
    kubectl
    kubernetes-helm
    minikube
    talosctl

    # Cloud / Infrastructure
    awscli2
    terraform
    google-cloud-sdk
    google-cloud-sql-proxy
    minio-client

    # Databases
    duckdb
    postgresql
    redis

    # Languages / Build tools
    lld
    protobuf
    typst
    ast-grep
    deno
    nodejs
    pnpm
    zig
    rustc
    cargo
    clippy
    rustfmt
    cargo-edit
    cargo-expand
    bun
    go

    # Language servers
    lua-language-server
    typescript-language-server
    rust-analyzer
    gopls
    pyright
    # it's somehow broken now on Feb 11 2026
    # zls

    # File watching
    watchman

    # Other
    imagemagick
    sox

    # Load testing
    k6
    hey

    # Python
    python3
    uv

    # Learning
    codecrafters-cli

    # AI
    codexPkg # from codex-cli-nix flake, not nixpkgs
    gemini-cli
    claude-code
    clawpatrol # security firewall for agents; overlays/clawpatrol.nix

    # Git worktree
    git-wt

    # Shell enhancements (migrated from brew)
    atuin          # shell history with sync
    direnv         # per-directory env vars
    starship       # cross-shell prompt

    # CLI tools (migrated from brew)
    cmake
    findutils      # GNU find/xargs (gfind, gxargs on darwin)
    git-filter-repo
    gnused         # GNU sed (available as gsed on darwin)
    hyperfine      # benchmarking
    jnv            # interactive jq TUI
    mosh           # mobile shell
    silicon        # code screenshot (source → image)
    watch          # watch command
    wget

    # GitHub CLI
    gh

    # Databases (migrated from brew). clickhouse: prebuilt client binary on
    # darwin (server runs in Docker), nixpkgs build on Linux; see
    # overlays/clickhouse.nix.
    clickhouse
    # NOTE: postgresql NOT migrated as v14 — `postgresql` (v17) is already in
    # home.packages above; can't have two versions (pg_rewind etc. collide).
    # If a project needs PG14 specifically, keep `postgresql@14` in brew.
    # NOTE: minio (server) intentionally NOT migrated — nixpkgs marks it
    # insecure (abandoned upstream, unpatched CVEs). Kept in Homebrew.

    # Network
    ngrok

    # Kubernetes
    kubectx

    # Build tools / Java
    maven
    cargo-make

    # Multimedia
    mkvtoolnix

    # Runtime version managers (migrated from brew)
    volta
    mise
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    tree-sitter-cli  # custom build (0.26.x for nvim-treesitter); see let-binding above

    gcc  # on macOS the native clang from stdenv is used instead

    # Clipboard (X11 / Wayland)
    xsel
    wl-clipboard

    # GUI apps. On macOS these come from Homebrew casks (see darwin.nix),
    # because nixpkgs has no (or no reliable) darwin build for them.
    google-chrome
    discord
    slack
    vscode
    zed-editor
    obs-studio
    gradia
  ] ++ lib.optionals pkgs.stdenv.isDarwin [
    tree-sitter  # nixpkgs CLI (the custom 0.26.x build above is Linux-only for now)

    # macOS-specific pinentry for GPG (integrates with macOS Keychain)
    pinentry_mac

    # Fonts (replaces brew cask font-jetbrains-mono-nerd-font)
    nerd-fonts.jetbrains-mono

    # GUI apps / tools with nixpkgs darwin builds (migrated from brew casks)
    _1password-cli
    rectangle
    wezterm

    # On NixOS this comes from nixos/common.nix's fonts.packages; darwin needs it via home-manager.
    (pkgs.google-fonts.override { fonts = [ "Google Sans Code" ]; })
  ];

  # ──────────────────────────────────────────────────────────────
  # Git
  # ──────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    signing.format = "openpgp";

    # Global gitignore patterns
    ignores = [
      # Personal
      "MAGURO_LOCAL_NOTE.md"

      # macOS
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      "._*"

      # Windows
      "Thumbs.db"
      "Desktop.ini"

      # Editors
      "*~"
      # Some frameworks use a literal "~" directory in route paths.
      # Keep backup-file ignores, but unignore "~" directories and their contents.
      "!**/~/"
      "!**/~/**"
      "*.swp"
      "*.swo"
      ".idea/"
      "*.iml"

      # Vim
      "Session.vim"
      ".netrwhist"

      # direnv
      ".direnv/"

      # Environment files (secrets)
      ".env.local"
      ".env.*.local"
    ];

    signing = {
      # Don't specify the signing key so that git will look up a key maching the email
      # key = "do-not-comment-out";
      signByDefault = true;
    };

    settings = {
      init.defaultBranch = "main";
      wt = {
        basedir = "../{gitroot}-wt";
        copyignored = true;
        copyuntracked = true;
      };
      user = {
        name = "Yusuke Tanaka";
        email = "wing0920@gmail.com";
      };
      ghq.root = "~/Repo";
      filter.lfs = {
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
      };
      credential = {
        "https://github.com" = {
          helper = [
            ""
            "!gh auth git-credential"
          ];
        };
        "https://gist.github.com" = {
          helper = [
            ""
            "!gh auth git-credential"
          ];
        };
        "https://github.gatech.edu" = {
          helper = [
            ""
            "!gh auth git-credential"
          ];
        };
      };
    };
  };

  # ──────────────────────────────────────────────────────────────
  # GitHub CLI
  # ──────────────────────────────────────────────────────────────
  programs.gh = {
    enable = true;
    extensions = [ pkgs.gh-markdown-preview ];
  };

  # ──────────────────────────────────────────────────────────────
  # Zsh
  # ──────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    enableCompletion = false; # We call compinit manually after zinit loads completions

    # History settings
    history = {
      size = 100000;
      save = 1000000;
      path = "$HOME/.zsh_history";
      ignoreDups = true;
      ignoreAllDups = true;
      expireDuplicatesFirst = true;
      share = true;
    };

    # Shell options
    autocd = true;
    defaultKeymap = "emacs";

    # Environment variables
    sessionVariables = {
      # Language
      LANGUAGE = "en_US.UTF-8";
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
      LC_CTYPE = "en_US.UTF-8";

      # Editor
      EDITOR = "nvim";
      CVSEDITOR = "nvim";
      SVN_EDITOR = "nvim";
      GIT_EDITOR = "nvim";

      # Pager
      PAGER = "less";
      LESS = "-R -f -X -i -P ?f%f:(stdin). ?lb%lb?L/%L.. [?eEOF:?pb%pb\\%..]";
      LESSCHARSET = "utf-8";
      # Note: LESS_TERMCAP_* variables are set in initContent with proper escaping

      # ls colors
      LSCOLORS = "exfxcxdxbxegedabagacad";
      LS_COLORS = "di=34:ln=35:so=32:pi=33:ex=31:bd=46;34:cd=43;34:su=41;30:sg=46;30:tw=42;30:ow=43;30";

      # XDG
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";

      # fzf
      FZF_DEFAULT_OPTS = "--extended --ansi --multi";

      # GPG - Note: GPG_TTY is set in initContent since $(tty) needs evaluation

      # k8s
      KUBECONFIG = "$HOME/.kube/config";
    };

    # Aliases
    shellAliases = {
      # eza
      l = "eza";
      ls = "eza";
      ll = "eza -l";
      la = "eza -a";
      lla = "eza -la";

      # Common tools
      cat = "bat";
      cp = "cp -i";
      mv = "mv -i";
      rm = "rm -i";

      # Docker
      dc = "docker-compose";

      # Git
      g = "git";
      gs = "git status";
      gc = "git commit";
      gco = "git checkout";
      gsw = "git switch";
      gr = "git restore";
      ga = "git add";
      gp = "git push origin HEAD";
      gpf = "git push origin HEAD --force-with-lease";
      gdi = "git diff";
      gpu = "git pull";

      # Editors
      vi = "nvim";
      vim = "nvim";

      # Cargo
      ca = "cargo";

      # Deno (same as `deno x --install-alias`, but in a nix friendly way)
      dx = "deno x";


      # Deno Deploy environments
      local_deployctl = "DENO_TLS_CA_STORE=system DEPLOY_API_ENDPOINT=\"https://deno-local.com\" deployctl";
      dev_deployctl = "DEPLOY_API_ENDPOINT=\"https://dash.deno-dev.com\" deployctl";
      staging_deployctl = "DEPLOY_API_ENDPOINT=\"https://deno-staging.com\" deployctl";
    };

    # Raw zsh configuration
    initContent = lib.mkMerge [
      ''
      # Additional shell options
      setopt no_global_rcs
      setopt AUTO_PARAM_KEYS

      # zsh-autosuggestions searches zsh's in-memory history, while Home
      # Manager sets HISTFILE after zsh's startup history import point.
      # Import the persistent history before loading autosuggestions so fresh
      # terminals can suggest commands from previous sessions.
      [[ -r "$HISTFILE" ]] && fc -R "$HISTFILE" 2>/dev/null || true

      # Disable accept-line-and-down-history
      bindkey -r "^O"

      # LESS man page colors (must use $'...' for escape codes)
      export LESS_TERMCAP_mb=$'\E[01;31m'
      export LESS_TERMCAP_md=$'\E[01;31m'
      export LESS_TERMCAP_me=$'\E[0m'
      export LESS_TERMCAP_se=$'\E[0m'
      export LESS_TERMCAP_so=$'\E[00;44;37m'
      export LESS_TERMCAP_ue=$'\E[0m'
      export LESS_TERMCAP_us=$'\E[01;32m'

      # GPG
      export GPG_TTY=$(tty)

      ${lib.optionalString pkgs.stdenv.isLinux ''
        # Clipboard (auto-detect X11 vs Wayland)
        if [[ -n "$WAYLAND_DISPLAY" ]]; then
          pbcopy() { printf '\e]52;c;'; base64 -w0; printf '\a'; }
          # Avoid wl-copy because it causes a terminal window opened by quake-terminal (GNOME extension) to disappear
          alias pbpaste='xsel --clipboard --output | tr -d "\r"'
          alias pbcopy-wl='wl-copy'
          alias pbpaste-wl='wl-paste'
        else
          alias pbcopy='xsel --clipboard --input'
          alias pbpaste='xsel --clipboard --output | tr -d "\r"'
        fi
      ''}

      # Library path for native npm modules (e.g., @parcel/watcher) - Linux only.
      # Guarded in Nix (not just at runtime) so pkgs.stdenv.cc.cc.lib is never
      # forced on darwin, where that output doesn't exist.
      ${lib.optionalString pkgs.stdenv.isLinux ''
        export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:''${LD_LIBRARY_PATH:-}"
      ''}

      # Homebrew (kept for GUI casks during/after the Nix migration). Note this
      # prepends /opt/homebrew/bin, so during migration a brew copy can shadow
      # the Nix one for duplicated tools — uninstall the brew copy to let Nix win.
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        eval "$(/opt/homebrew/bin/brew shellenv)"
      ''}

      # Additional PATH entries
      export PATH="/usr/local/bin:$HOME/bin:$PATH"
      export PATH="$HOME/go/bin:$PATH"
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="/snap/bin:$PATH"

      # uv (Python) completions - cached for speed
      () {
        local cache="''${XDG_DATA_HOME:-$HOME/.local/share}/zsh/uv-completion.zsh"
        local uv_bin="${pkgs.uv}/bin/uv"
        if [[ ! -f $cache || $uv_bin -nt $cache ]]; then
          mkdir -p "''${cache:h}"
          "$uv_bin" generate-shell-completion zsh > "$cache"
        fi
        source "$cache"
      }


      # ─────────────────────────────────────────────────────────────
      # Zinit (plugin manager)
      # ─────────────────────────────────────────────────────────────
      ZINIT_HOME="''${XDG_DATA_HOME:-''${HOME}/.local/share}/zinit/zinit.git"
      if [[ ! -d $ZINIT_HOME ]]; then
        mkdir -p "$(dirname $ZINIT_HOME)"
        git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
      fi
      source "''${ZINIT_HOME}/zinit.zsh"
      autoload -Uz _zinit
      (( ''${+_comps} )) && _comps[zinit]=_zinit

      # Completions (compinit runs synchronously; plugins deferred via turbo mode)
      autoload -Uz compinit
      compinit -C

      zinit ice wait lucid blockf atpull'zinit creinstall -q .'
      zinit light zsh-users/zsh-completions

      # fzf-tab (must be loaded after compinit, before autosuggestions/syntax-highlighting)
      zinit ice wait lucid
      zinit light Aloxaf/fzf-tab

      # Syntax highlighting and autosuggestions
      zinit ice wait lucid
      zinit light zdharma-continuum/fast-syntax-highlighting
      # atload'!_zsh_autosuggest_start' is required when loading autosuggestions
      # under turbo (wait): otherwise the plugin sources after the first prompt's
      # precmd has run, its widget hooks never bind, and the inline "shadow"
      # suggestions never appear. atload runs the start function right after load.
      zinit ice wait lucid atload'!_zsh_autosuggest_start'
      zinit light zsh-users/zsh-autosuggestions

      # fzf integration
      [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

      # ─────────────────────────────────────────────────────────────
      # Custom functions
      # ─────────────────────────────────────────────────────────────
      # Repository fuzzy finder (ghq + fzf)
      function select_ghq() {
        local target_dir=$(ghq list -p | fzf --scheme=path --layout=reverse --no-multi --query="$LBUFFER" --prompt="Repo > ")
        if [ -n "$target_dir" ]; then
          BUFFER="cd ''${target_dir}"
          zle accept-line
        fi
        zle reset-prompt
      }
      zle -N select_ghq
      bindkey "^g" select_ghq

      # ─────────────────────────────────────────────────────────────
      # Secrets (not tracked in git)
      # ─────────────────────────────────────────────────────────────
      [ -f ~/.secrets.zsh ] && source ~/.secrets.zsh
      ''
      (lib.mkOrder 1500 ''
        # Atuin prepends its own autosuggestion strategy, which bypasses zsh's
        # in-memory history. Keep Atuin widgets, but make inline suggestions use
        # the history imported above.
        if [[ $options[zle] = on ]]; then
          ZSH_AUTOSUGGEST_STRATEGY=(history)
          (( $+functions[_zsh_autosuggest_start] )) && _zsh_autosuggest_start
        fi
      '')
      (lib.mkIf pkgs.stdenv.isDarwin ''
        # cmux uses libghostty as its rendering engine and turns on the kitty
        # keyboard protocol's "disambiguate" flag at the PTY level, with no option
        # to disable it (cmux#3837). Unlike the Linux setup there is no tmux layer
        # to shield the shell, so Ctrl+M / Ctrl+I / Ctrl+[ arrive as CSI-u
        # sequences instead of their legacy bytes, so Ctrl+M stops acting as Enter
        # and Ctrl+[ stops acting as Esc. Map the leaked sequences back to their
        # legacy meaning. These are no-ops whenever the protocol is inactive (the
        # sequences never arrive), so they are safe to set unconditionally on
        # macOS. Ctrl+[ uses `bindkey -s` to re-inject a real Esc byte because Esc
        # is a Meta prefix in our emacs keymap, not a single widget.
        bindkey '\e[109;5u' accept-line   # Ctrl+M (kitty CSI-u) -> Enter
        bindkey -s '\e[91;5u' '\e'        # Ctrl+[ (kitty CSI-u) -> Esc (Meta prefix)
      '')
      (lib.mkOrder 1550 ''
        # Ghostty shell integration, hardened. We disable the home-manager
        # ghostty module's own injection (programs.ghostty.enableZshIntegration
        # = false) because its guard only checks that GHOSTTY_RESOURCES_DIR is
        # set, not that the script exists. cmux renders with libghostty and sets
        # that var to its app bundle (.../cmux.app/Contents/Resources/ghostty),
        # which ships no shell-integration script, so the unguarded `source`
        # errored on every new tab. Add a `-r` file check: real Ghostty loads
        # integration, cmux/other libghostty hosts silently skip it.
        if [[ -n $GHOSTTY_RESOURCES_DIR \
              && -r "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration" ]]; then
          source "$GHOSTTY_RESOURCES_DIR/shell-integration/zsh/ghostty-integration"
        fi
      '')
    ];
  };

  # ──────────────────────────────────────────────────────────────
  # SSH
  # ──────────────────────────────────────────────────────────────
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519_github";
      };
      "github.com-magurobot" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/magurobot_auth";
        identitiesOnly = true;
      };
      "codeberg.org" = {
        identityFile = "~/.ssh/id_ed25519_codeberg";
      };
      "avocet.deno.co" = {
        identityFile = "~/.ssh/id_ed25519_avocet";
      };
    };
  };

  # ──────────────────────────────────────────────────────────────
  # GPG
  # ──────────────────────────────────────────────────────────────
  programs.gpg.enable = true;
  # home-manager's gpg-agent service is systemd-based, so it's Linux-only. On
  # macOS gpg-agent is started on demand; set `pinentry-program` in
  # ~/.gnupg/gpg-agent.conf (e.g. pkgs.pinentry_mac) if you want a GUI prompt.
  services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    # Set a default pinentry here. Use pinentry-curses unless another module overrides it.
    pinentry.package = lib.mkDefault pkgs.pinentry-curses;
  };

  # ──────────────────────────────────────────────────────────────
  # Starship prompt
  # ──────────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      character = {
        success_symbol = "[➜](bold green)";
      };
      package = {
        disabled = false;
      };
      kubernetes = {
        disabled = false;
      };
    };
  };

  # ──────────────────────────────────────────────────────────────
  # Direnv
  # ──────────────────────────────────────────────────────────────
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # ──────────────────────────────────────────────────────────────
  # Atuin (shell history)
  # ──────────────────────────────────────────────────────────────
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      enter_accept = false;
      invert = true;
    };
  };

  # ──────────────────────────────────────────────────────────────
  # Ghostty
  # ──────────────────────────────────────────────────────────────
  programs.ghostty = {
    enable = true;
    # nixpkgs has no macOS build of ghostty, so on darwin install it via the
    # Homebrew cask and let home-manager manage only the config file.
    package = if pkgs.stdenv.isDarwin then null else pkgs.ghostty;
    # Replaced by a file-existence-guarded `source` in programs.zsh.initContent
    # above: the module's injection only checks that GHOSTTY_RESOURCES_DIR is
    # set, which breaks under cmux (libghostty sets the var but ships no script).
    enableZshIntegration = false;
    settings = {
      font-family = [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono CJK JP"
        "Adwaita Mono"
      ];
      theme = "Dracula";
      cursor-style = "block";
      background-opacity = 0.85;
      window-padding-x = 8;
      gtk-tabs-location = "hidden";
      keybind = [
        "ctrl+enter=text:\\n"
        "shift+enter=text:\\n"
      ];
      # Allow interacting with clipboard through OSC 52
      clipboard-read = "allow";
      clipboard-write = "allow";
      app-notifications = "no-clipboard-copy";
      shell-integration-features = "no-cursor";
      # macOS-only: don't persist window state, so macOS won't auto-relaunch
      # Ghostty at login (its "Reopen windows" restoration). No-op on Linux.
      window-save-state = "never";
      # `?` prefix = optional: Ghostty won't error if the local override file
      # is absent. On macOS we seed this file below, but keep it mutable.
      config-file = [
        "?~/.config/ghostty/overrides"
      ];
    } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
      font-size = 10;
    };
  };

  home.activation.seedGhosttyOverrides = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      overrides="${homeDirectory}/.config/ghostty/overrides"
      if [[ ! -s "$overrides" ]]; then
        mkdir -p "$(dirname "$overrides")"
        cat > "$overrides" <<'EOF'
font-size = 13
EOF
      fi
    ''
  );

  # ──────────────────────────────────────────────────────────────
  # Tmux
  # ──────────────────────────────────────────────────────────────
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    prefix = "C-t";
    escapeTime = 0;
    baseIndex = 1;
    mouse = true;
    keyMode = "vi";
    terminal = "tmux-256color";

    extraConfig = ''
      # enable true color
      set -g terminal-overrides "xterm-256color:Tc"
      # OSC52 clipboard. `%p2%s` is the base64-encoded selection payload.
      set -ga terminal-overrides ",*:Ms=\E]52;c;%p2%s\007"
      # Cursor shape passthrough (Ss=set style, Se=reset to terminal default)
      set -ga terminal-overrides ",*:Ss=\\E[%p1%d q:Se=\\E[ q"

      # pane base index
      set-option -g pane-base-index 1

      # keybindings
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R
      bind -n C-s select-pane -t :.+
      bind | split-window -h -c '#{pane_current_path}'
      bind - split-window -v -c '#{pane_current_path}'
      bind c new-window -c '#{pane_current_path}'
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"

      # OSC52 clipboard
      set-option -s set-clipboard on
      ${lib.optionalString pkgs.stdenv.isDarwin ''
        set-option -s copy-command "/usr/bin/pbcopy"
      ''}

      # vi copy mode
      bind-key -T copy-mode-vi v send -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X ${tmuxCopyAction}
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X ${tmuxCopyAction}
      bind-key -T copy-mode-vi Enter send-keys -X ${tmuxCopyAction}

      ##################
      #   Appearance   #
      ##################

      # status bar
      set-option -g status-left-length 90
      set-option -g status-right-length 90
      set-option -g status-right '[%Y-%m-%d(%a) %H:%M]'
      set-option -g status-interval 1
      set-option -g status-position top
      set-option -g status-justify left
      set-option -g status-left ' '
      set-option -g status-left-length 10
      set-option -g status-bg "colour238"
      set-option -g status-fg "colour255"

      # base16-gruvbox-dark-pale
      set-option -g status-style "fg=#949494,bg=#3a3a3a"
      set-window-option -g window-status-style "fg=#949494,bg=default"
      set-window-option -g window-status-current-style "fg=#ffaf00,bg=default"
      set-option -g pane-border-style "fg=#4e4e4e,bg=default"
      set-option -g pane-active-border-style "fg=#ffaf00,bg=default,bold"
      set-option -g pane-border-status top
      set-option -g pane-border-format " #P: #{pane_current_command} "
      set-option -g pane-border-lines double
      set-option -g pane-border-indicators arrows
      set-option -g display-panes-active-colour "#afaf00"
      set-option -g display-panes-colour "#ffaf00"
      set-option -g message-style "fg=#dab997,bg=#3a3a3a"
      set-window-option -g clock-mode-colour "#afaf00"
      set-window-option -g mode-style "fg=#949494,bg=#4e4e4e"
      set-window-option -g window-status-bell-style "fg=#3a3a3a,bg=#d75f5f"
    '';
  };
}
