---
layout: fragment
title: macOS Extraction .dmg Contents of the file
tags: [mac]
description: macOS 下提取 dmg 文件里的内容
keywords: macOS, dmg 
---

In some scenarios, you cannot directly use .dmg files to mount and install applications. You can only find a way to extract the .pkg or .app in the .dmg file to install it. In this case, you can use 7-zip.

```
brew install 7-zip
7zz x x.dmg
```

If the decompressed file is a .pkg file, you can directly double-click it to install it;

If it is a .app file, you can copy and paste it into the application.
