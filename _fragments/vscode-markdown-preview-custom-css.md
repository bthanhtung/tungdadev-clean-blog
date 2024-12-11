---
layout: fragment
title: VSCode 自定义 Markdown 预览样式
tags: [vscode, markdown]
description: VSCode 自定义 Markdown 预览样式
keywords: VSCode, Markdown
mermaid: false
sequence: false
flow: false
mathjax: false
mindmap: false
mindmap2: false
---

The default Markdown preview style in VSCode is not very good-looking, you can customize the style.

The method is to find Extensions > Markdown > Markdown: Styles in the VSCode configuration, and then Add Item. You can add the local css file in the current working directory or the URL address.

Problems encountered:

1. The local css file cannot be an absolute path outside the current working directory, otherwise an error will be reported;

2. The media type corresponding to the URL address cannot be text/plain, otherwise an error `Could not load 'markdown.styles'` will be reported, refer to: <https://github.com/microsoft/vscode/issues/148677>.
