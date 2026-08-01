# MELPA
```
  (progn
    (require 'package)
    (add-to-list 'package-archives
                 '("melpa" . "https://melpa.org/packages/")
                 t)
    (package-refresh-contents)
    (package-install 'quelpa))
```


# NonGNU ELPA 安装 Eat
```
  (progn
    (require 'package)
    (add-to-list 'package-archives
                 '("nongnu" . "https://elpa.nongnu.org/nongnu/")
                 t)
    (package-refresh-contents)
    (package-install 'eat))
```


# Eat 中 DEL 键异常

## 现象

在 Eat 终端中按下 `DEL`（Backspace）键时，光标反而向右移动，且没有删除字符。

## 原因

Eat 的 terminfo 数据库没有正确编译，导致 shell 输出的终端控制序列未被正确处理。

## 解决方法

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
