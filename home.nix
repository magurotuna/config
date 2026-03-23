{ pkgs, lib, homeDirectory, codexPkg, octorusPkg, ... }:

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
        "allow": [
          "Bash(gh search:*)",
          "Bash(gh api:*)"
        ]
      },
      "alwaysThinkingEnabled": true,
      "plansDirectory": "./plans",
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
  home.file.".local/share/sounds/claude-done.oga".source =
    "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/service-login.oga";
  home.file.".local/share/sounds/claude-notification.oga".source =
    "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga";

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

    # Clipboard
    xsel          # X11
    wl-clipboard  # Wayland

    # Network / HTTP
    dnsutils
    nghttp2
    oha
    websocat

    # Browser
    google-chrome

    # Communication
    discord
    slack

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
    minio
    minio-client

    # Databases
    duckdb
    postgresql
    redis

    # Languages / Build tools
    gcc
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
    nodePackages.typescript-language-server
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

    # Editor
    vscode
    zed-editor

    # Screenshot / Recording
    gradia
    obs-studio

    # Git worktree
    git-wt
  ] ++ [
    tree-sitter-cli  # custom build (0.26.x for nvim-treesitter)
    octorusPkg       # TUI PR review tool (github:ushironoko/octorus)
  ];

  # ──────────────────────────────────────────────────────────────
  # Git
  # ──────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;

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
    initContent = ''
      # Additional shell options
      setopt no_global_rcs
      setopt AUTO_PARAM_KEYS

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

      # Library path for native npm modules (e.g., @parcel/watcher) - Linux only
      if [[ "$(uname)" == "Linux" ]]; then
        export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:''${LD_LIBRARY_PATH:-}"
      fi

      # Additional PATH entries
      export PATH="/usr/local/bin:$HOME/bin:$PATH"
      export PATH="$HOME/go/bin:$PATH"
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
      zinit ice wait lucid
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
    '';
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
  services.gpg-agent = {
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
    settings = {
      font-family = [
        "JetBrainsMono Nerd Font"
        "Adwaita Mono"
      ];
      font-size = 10;
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
      config-file = [
        "~/.config/ghostty/overrides"
      ];
    };
  };

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
      set -ga terminal-overrides ",xterm-256color:Tc"
      # OSC52 clipboard for tmux-256color
      set -ga terminal-overrides ",tmux-256color:Ms=\E]52;c;%p1%s\007"
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

      # vi copy mode
      bind-key -T copy-mode-vi v send -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi Enter send-keys -X copy-selection-and-cancel

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
