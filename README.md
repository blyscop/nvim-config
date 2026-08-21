# Configuration Neovim

Configuration artisanale orientée développement **.NET / C#**, écrite pour
remplacer JetBrains Rider au quotidien.

Un seul `init.lua`, lisible d'un bout à l'autre — pas de distribution.

## Installation

```bash
git clone https://github.com/blyscop/nvim-config.git ~/.config/nvim
nvim
```

lazy.nvim s'installe seul au premier lancement, puis télécharge les plugins.

Prérequis : Neovim >= 0.12, `git`, `ripgrep`, `fd`, un compilateur C, et une
Nerd Font dans le terminal.

Pour le C# : le SDK .NET, `roslyn-language-server` (`dotnet tool install -g
Microsoft.CodeAnalysis.LanguageServer`) et `netcoredbg` pour le débogage.
Pense à ajouter `~/.dotnet/tools` au `PATH`, sinon Neovim ne trouvera pas le
serveur de langage.

## Ce qu'elle contient

| Domaine | Choix |
|---|---|
| Gestionnaire | lazy.nvim |
| Recherche / explorateur | mini.pick, mini.files, mini.clue |
| Langage C# | roslyn.nvim |
| Débogage | nvim-dap + nvim-dap-ui + netcoredbg |
| Complétion | nvim-cmp — LSP, snippets, buffers, chemins, dictionnaire fr/en |
| Coloration | Treesitter, 27 langages |
| Base de données | vim-dadbod |
| Thème | `vsdark`, transcrit du schéma « Visual Studio Dark » de Rider |

## Raccourcis

La touche de préfixe est **Espace**. Appuie dessus et attends : mini.clue
affiche les suites possibles.

| Touche | Action |
|---|---|
| `<leader>ff` / `fg` / `fb` | fichiers / recherche dans le contenu / buffers |
| `<leader>e` | explorateur mini.files |
| `gd` `gr` `gi` `K` | définition, références, implémentations, documentation |
| `<leader>rn` | renommer |
| `<leader>rp` | ajouter un paramètre et le propager aux appels |
| `<leader>ca` | actions de code |
| `<F5>` `<F7>` `<F8>` `<S-F8>` | débogage : continuer, pas dans, au-dessus, hors |
| `<leader>b` | point d'arrêt |

## Deux détails qui ne vont pas de soi

**Le thème `vsdark`** n'est pas un relevé approximatif : les couleurs sont
transcrites depuis `colorSchemes/VisualStudioDark.xml`, extrait du plugin
`rider-theme-pack`. Il reproduit notamment la distinction que fait Rider entre
les mots-clés de contrôle de flux (mauve) et les autres (bleu), que peu de
thèmes Neovim respectent.

**Le renommage attend l'indexation.** Interrogé avant d'avoir chargé la
solution, Roslyn répond sans erreur mais ne connaît que le document courant :
`vim.lsp.buf.rename()` ne toucherait qu'un fichier sur cinq, silencieusement.
Le garde-fou le refuse tant que `workspace/projectInitializationComplete` n'est
pas arrivé.

## Plugin associé

[csharp-signature.nvim](https://github.com/blyscop/csharp-signature.nvim) —
ajoute un paramètre à une méthode C# et le propage à tous ses appels. Extrait
de cette config, développé pour combler l'absence du `Change Signature` de
Rider dans le protocole LSP.
