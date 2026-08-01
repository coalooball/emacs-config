# Emacs 开发环境安装

本配置面向 Emacs 30，支持以下开发环境：

- JavaScript、TypeScript 和 React（JSX/TSX）
- Python
- Rust
- C 和 C++

配置使用 Tree-sitter 提供语法解析，Eglot 提供 LSP 功能，Apheleia 在保存后调用对应的格式化工具。

## 1. 前置条件

建议使用 Emacs 30 或更高版本，并确保编译时启用了 Tree-sitter。进入 Emacs 后可以检查：

```text
M-x emacs-version
M-: (treesit-available-p)
```

第二条命令应返回 `t`。

还需要 Git、C/C++ 编译器和 ripgrep。Tree-sitter grammar 会在本机编译，因此必须存在可用的 `cc`。

macOS：

```sh
xcode-select --install
brew install ripgrep uv clang-format
```

Debian/Ubuntu：

```sh
sudo apt update
sudo apt install git ripgrep clangd clang-format build-essential
```

## 2. 启用配置文件

Emacs 默认从 `~/.emacs.d/init.el` 或 `~/.config/emacs/init.el` 读取配置。可以将仓库中的文件链接到其中一个位置。

macOS 当前仓库路径：

```sh
mkdir -p ~/.emacs.d
ln -s /Users/mawangdan/code/emacs-config/init.el ~/.emacs.d/init.el
```

如果目标位置已经存在 `init.el`，上述 `ln` 命令会停止并报错；应先比较并合并已有配置，不要直接覆盖。Linux 上将源文件路径换成实际的仓库路径。

也可以从命令行临时测试配置：

```sh
emacs --init-directory=/Users/mawangdan/code/emacs-config
```

## 3. 安装 Emacs 包

`init.el` 配置了 MELPA 和 NonGNU ELPA，并通过 `use-package` 自动安装以下包：

- `exec-path-from-shell`
- `vertico`、`orderless`、`marginalia`
- `consult`
- `corfu`、`cape`
- `treesit-auto`
- `apheleia`
- `magit`
- `diff-hl`

Eglot 已包含在 Emacs 30 中，不需要单独安装。

首次启动后，如果包列表尚未更新，执行：

```text
M-x package-refresh-contents
```

然后重新启动 Emacs。需要排查启动错误时，可以运行：

```sh
emacs --debug-init
```

Eat 需要单独安装：

```text
M-x package-install RET eat RET
```

## 4. 安装语言服务器和格式化工具

### JavaScript、TypeScript 和 React

先安装 Node.js 和 npm，再执行：

```sh
npm install -g typescript-language-server typescript pyright prettier
```

其中：

- `typescript-language-server` 为 JavaScript、TypeScript、JSX 和 TSX 提供 LSP 功能。
- `typescript` 提供 `tsserver`。
- `prettier` 负责保存时格式化 JS、TS、JSX 和 TSX。
- `pyright` 是本配置使用的 Python language server。

React 项目仍应在项目目录安装自己的依赖：

```sh
npm install
```

打开 `.jsx` 文件时使用 `js-ts-mode`，打开 `.tsx` 文件时使用 `tsx-ts-mode`。

### Python

安装 Ruff，用于 Python 格式化：

```sh
uv tool install ruff@latest
```

如果 uv 提示工具目录不在 `PATH` 中，再执行：

```sh
uv tool update-shell
```

Python 项目建议在项目根目录使用 `.venv`：

```sh
uv venv
uv sync
```

### Rust

通过 rustup 安装 Rust 分析器、格式化工具和标准库源码：

```sh
rustup component add rust-analyzer rustfmt rust-src
```

配置会使用 `rust-analyzer` 提供 LSP 功能，并使用 `rustfmt` 格式化 `.rs` 文件。

### C 和 C++

需要以下两个命令：

```sh
clangd --version
clang-format --version
```

`clangd` 提供 LSP 功能，`clang-format` 负责保存时格式化。CMake 项目应生成编译数据库，让 clangd 获得准确的 include 路径和编译参数：

```sh
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

clangd 会自动寻找 `build/compile_commands.json`。

## 5. 安装 Tree-sitter grammar

配置只启用了当前需要的 grammar：

- JavaScript、TypeScript、TSX
- Python
- Rust
- C、C++

首次打开对应源文件时，`treesit-auto` 会询问是否下载并编译 grammar，输入 `y`。安装完成后，可以通过当前 major mode 确认是否生效，例如：

```text
M-x describe-mode
```

对应模式应为 `js-ts-mode`、`typescript-ts-mode`、`tsx-ts-mode`、`python-ts-mode`、`rust-ts-mode`、`c-ts-mode` 或 `c++-ts-mode`。

## 6. 验证开发环境

在 Emacs 中检查外部命令是否都能找到：

```elisp
M-: (mapcar #'executable-find
            '("rg"
              "typescript-language-server"
              "pyright-langserver"
              "ruff"
              "rust-analyzer"
              "rustfmt"
              "clangd"
              "clang-format"
              "prettier"))
```

结果中不应出现 `nil`。

打开项目中的源文件后，Eglot 会自动启动。mode line 中应出现 `[eglot:项目名]`。常用检查命令：

```text
M-x eglot-events-buffer
M-x apheleia-format-buffer
M-x magit-status
```

常用快捷键：

| 快捷键 | 功能 |
| --- | --- |
| `M-.` | 跳转到定义 |
| `M-,` | 返回 |
| `M-?` | 查找引用 |
| `C-s` | 在当前 buffer 搜索 |
| `M-s r` | 使用 ripgrep 搜索项目 |
| `C-x b` | 切换 buffer |
| `C-x g` | 打开 Magit |

## 7. 使用 Org mode

Org mode 已包含在 Emacs 中，本配置不需要额外安装包。Org 文件默认保存在
`~/.emacs.d/org/`；如果使用 `--init-directory` 启动本仓库，则保存在仓库的
`org/` 目录中。第一次启动时会自动创建该目录。

常用入口：

| 快捷键 | 功能 |
| --- | --- |
| `C-c c t` | 快速记录任务到 `inbox.org` |
| `C-c c n` | 快速记录笔记到 `notes.org` |
| `C-c a a` | 查看 Agenda |
| `C-c l` | 保存当前位置的 Org 链接 |
| `C-c C-t` | 在 Org 标题上切换任务状态 |
| `C-c C-s` | 为任务安排日期 |
| `C-c C-d` | 为任务设置截止日期 |

例如在 `inbox.org` 中记录一个带截止日期的任务：

```org
* TODO 完成项目说明
  DEADLINE: <2026-08-05 Wed>
```

`org-agenda-files` 默认包含整个 Org 目录，因此该目录下的所有 `.org` 文件都会
进入 Agenda。任务完成时会自动记录完成时间。

## 8. Eat 的 DEL 键异常

### 现象

在 Eat 终端中按下 `DEL`（Backspace）键时，光标反而向右移动，且没有删除字符。

### 原因

Eat 的 terminfo 数据库没有正确编译，导致 shell 输出的终端控制序列未被正确处理。

### 解决方法

在 Emacs 中执行：

```text
M-x eat-compile-terminfo
```

关闭已有的 Eat buffer，然后重新执行 `M-x eat`。重新打开后，`DEL` 键即可正常删除光标前的字符。

可以在新的 Eat 终端中检查 terminfo 是否生效：

```sh
echo "$TERM"
infocmp "$TERM" >/dev/null && echo OK
```

`TERM` 应类似于 `eat-truecolor`，并且第二条命令应输出 `OK`。
