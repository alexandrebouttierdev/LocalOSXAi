# Third-party notices

LocalOSXAi is released under the [MIT License](LICENSE). It includes or depends on the
following third-party work, each under its own license.

| Component | Use | License |
|---|---|---|
| [GRDB.swift](https://github.com/groue/GRDB.swift) by Gwendal Roué | SQLite access (the only package dependency) | MIT |
| [Inter](https://rsms.me/inter/) by The Inter Project Authors | The interface typeface, bundled as `App/Resources/Fonts/InterVariable.ttf` | SIL Open Font License 1.1, [full text](App/Resources/Fonts/Inter-LICENSE.txt), shipped in the app |
| [@lobehub/icons-static-svg](https://github.com/lobehub/lobe-icons) by LobeHub | Vector logos of Ollama and LM Studio (`App/Resources/Assets.xcassets/Provider*.imageset`), and of Ollama, LM Studio and vLLM on the website (`site/`) | MIT |

## Trademarks

“Ollama”, “LM Studio”, “vLLM” and their logos are trademarks of their respective owners. They are used
only to show which model server a model comes from. LocalOSXAi is an independent project, not
affiliated with or endorsed by them. The same applies to other names mentioned in the
documentation (llama.cpp, vLLM, Jan, LocalAI, Linear, Claude, Cline, OpenCode).

## Development tools

[XcodeGen](https://github.com/yonaskolb/XcodeGen) (MIT) and
[SwiftLint](https://github.com/realm/SwiftLint) (MIT) are used to build and check the project.
They are not shipped with the app.
