# mr-boxington

Home Manager installs mr-boxington, activates its stable Cargo shim, and gives
its action store plus managed targets a combined 40 GiB ceiling. The config
uses a smaller ceiling than the disk-scaled default because `nixos-mini` uses
ext4, which cannot reflink restored outputs.

## Celld benchmark

The measurements below are single runs, so they establish the size and the
large performance effects rather than a statistical distribution.

- Date: 2026-08-31
- Celld commit: `8537826`
- Command: `cargo check --locked -p celld`
- Toolchain: Cargo 1.97.0 and rustc 1.97.1
- Machine: 16 logical CPUs, 60 GiB RAM, ext4
- mr-boxington: 1.1.0 GNU archive; Home Manager installs the same-version
  static musl archive for Nix sandbox compatibility
- Incremental compilation: disabled in both the Cargo and mbx runs

| Scenario | Wall time | Result |
| --- | ---: | --- |
| Plain Cargo, empty target | 167.1 s | Baseline |
| mbx, empty action store and target | 170.2 s | 1.9% cold overhead |
| mbx, warm store in a different worktree | 39.4 s | 76.4% faster than the baseline |
| Two warm mbx worktrees in parallel | 47.3 s total | Both finish in 1.2 times one warm build |

The warm worktree restored 455 compilations and avoided an estimated 256.6
seconds of compiler time. It copied 456.1 MiB across 912 outputs and reflinked
zero outputs, which confirms the expected ext4 fallback.

The plain target occupied 902 MiB. After one cold and one cross-worktree warm
mbx run, the action store occupied 791 MiB, the two target views occupied 1.5
GiB and 1.3 GiB, and the complete mbx cache occupied 3.5 GiB. mbx therefore
does not reduce the live physical bytes for this isolated workload on ext4.
Its disk benefit comes from automatic target collection, a combined size cap,
and avoiding unbounded Cargo incremental state. Its speed benefit remains
large because compiling is slower than copying the restored output bytes.

A two-worktree cold run took 313.8 seconds because both `rusty_v8` build
scripts downloaded the same 37.9 MiB compressed archive from GitHub. mbx
cannot cache that build-script execution because the script declares no input
set. `home.nix` places the v152.1.0 archive in rusty_v8's URL-keyed Cargo cache,
so new Celld worktrees read one Nix store object instead of downloading it.

## Operations

Run `mbx doctor` after a Home Manager switch. Run `mbx gc --dry-run` to preview
collection, and set `MBX_DISABLE=1` for one Cargo command that must bypass mbx.

mbx does not replace an existing real `target` directory in a non-interactive
command. It also does not relocate an explicit `CARGO_TARGET_DIR`. Convert an
existing target only after checking that deleting its outputs is acceptable.
An explicit target path can use mbx normally after that path is an mbx-owned
symlink.

The latest documentation is at <https://mr-boxington.jdx.dev/>.
