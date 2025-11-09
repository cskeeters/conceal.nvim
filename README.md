`conceal.nvim` is a [neovim] plugin, that renders [GitHub Emojis] (such as `:+1:` to 👍) and non-visible Unicode characters when [`conceallevel`] is set to `2`.

It simulates what `syntax match ... conceal ... cchar=X` does, but since it uses [extmarks], it still works when [tree-sitter] is applying custom syntax highlighting.

> [!NOTE]
> The replaced text is typically displayed with a dull color so that you know that it was replaced.
> Also the text is not replaced when the cursor on that line.
> See [`concealcursor`].

## Special Characters

Neovim users can configure `list`/`listchars` to make characters that are otherwise not invisible or indistinguishable from spaces or no characters.

This plugin extends this capability to all Unicode characters, but is particularly useful for Unicode characters designed to aid with typesetting such as:

* [Soft Hyphen] — Hint at break/hyphenation point in a word
* [Word Joiner] — Prevent break in word (or acronym)
* [Zero-Width Space] — indicates where a word boundaries is, without displaying a visible space in the rendered text
* [En Space] — A space half the width of an em.
* [Em Space] — A space the width of an em.


# Configuration

## Setup

You need to call setup, but it will work with an empty table.

```lua
require('conceal').setup({})
```

You can customize it with:

```lua
require('conceal').setup({
    priority=111, -- in case there is overlay with other extmarks

    cchars = {
        ["­"] = '-',  -- Soft Hyphen
        ["⁠"] = '⌿',  -- Word Joiner
        ["​"] = "~",  -- Zero Width Space
        [" "] = "n",  -- EN Space
        [" "] = "m",  -- EM Space
    }

    filetypes = {
        'markdown',
        'typst',
        'gitcommit',
    }
})
```

# Usage

Replacing characters works when [`conceallevel`] is set to **2**.  The Neovim describes the behavior of Neovim when 2 is set as follows.

> Concealed text is completely hidden unless it has a custom replacement character defined (see |:syn-cchar|).

This mode can be set with the Lua command:

```lua
vim.opt.conceallevel = 2
```

# Design

When a file is loaded, the extmarks are placed throughout the file.  From then on, only updated or added lines need to have their extmarks refreshed.  `nvim_buf_attach` is used to get the changed lines, clears any existing extmarks within those lines, and then re-processes those lines.


[neovim]: https://neovim.io/
[extmarks]: https://neovim.io/doc/user/api.html#_extmark-functions
[tree-sitter]: https://github.com/nvim-treesitter/nvim-treesitter
[GitHub Emojis]: https://gist.github.com/rxaviers/7360908

[`conceallevel`]: https://neovim.io/doc/user/options.html#'conceallevel'
[`concealcursor`]: https://neovim.io/doc/user/options.html#'concealcursor'

[Soft Hyphen]: https://en.wikipedia.org/wiki/Soft_hyphen
[Word Joiner]: https://en.wikipedia.org/wiki/Word_joiner
[Zero-Width Space]: https://en.wikipedia.org/wiki/Zero-width_space
[En Space]: https://en.wikipedia.org/wiki/Em_(typography)
[Em Space]: https://en.wikipedia.org/wiki/Em_(typography)
