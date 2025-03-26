---
title: Shutting down my Matrix server
description: Official shutdown of my matrix server and reasons for doing so.
categories:
- Technology
tags:
- Matrix
- Synapse
- MatrixSynapse
- Shutdown
- Internet
- NixOS
- Issues
- Captcha
published_date: 2025-03-26 17:26:28.146565409 +0000

layout: post.liquid
is_draft: false

data:
  language: en
---
As of today, I have officially shutdown my Matrix server, `matrix.duanin2.top`.

This is mainly because of some problems, that I haven't found a solution to yet, like:
- Even though I have setup E-mail verification as a replacement for captcha, the server still requires captcha.
- The captcha is broken, which means that a user can't register without my intervention.
- [It also doesn't support 'deep-merging' configuration values](https://github.com/element-hq/synapse/issues/17677), meaning I have to duplicate values in my main config file by the NixOS module and my `/var/lib/secrets` config file, wher I store secrets like database passwords, which I don't want to appear in my NixOS configuration or the nix store.
- Because of limitations in [the Synapse matrix server](https://github.com/element-hq/synapse), I can't change the server URL to my new domain, which means I would have to rewrite parts of my NixOS configuration and it could also cause problems with the actual URL and the servers internal URL not matching.

I may one day decide to start a new matrix server or start up this server again, though if it's gonna happen, it's not gonna be any time soon.