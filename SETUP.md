# Publishing jira-nvim Plugin to GitHub

## Steps to Publish

### 1. Initialize Git Repository

```bash
cd /Users/willian.vervalempaiv/Projects/jira-nvim-plugin
git init
git add .
git commit -m "Initial commit: jira-nvim plugin with form-based interfaces

- Interactive forms for issue creation and filtering
- Quick preset commands for common Jira operations  
- LazyVim integration with which-key support
- Comprehensive documentation and help system
- Smart issue key detection and navigation"
```

### 2. Create GitHub Repository

1. Go to [GitHub](https://github.com) and create a new repository
2. Name it `jira-nvim`
3. **Don't** initialize with README (we already have one)
4. Set it to **Public** so others can use it

### 3. Push to GitHub

```bash
# Add your GitHub repository as remote
git remote add origin git@github.com:WillianPaiva/jira-nvim.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### 4. Update LazyVim Configuration

Once published, update your `~/.config/nvim/lua/plugins/jira-nvim.lua`:

```lua
return {
  {
    -- Switch from local to GitHub
    "WillianPaiva/jira-nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      -- ... your config
    },
    keys = {
      -- ... your keymaps  
    },
    config = function(_, opts)
      require("jira-nvim").setup(opts)
    end,
  },
  
  -- which-key integration
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>j", group = "jira", icon = { icon = "󰌨 ", color = "blue" } },
      },
    },
  },
}
```

### 5. Update README.md

After publishing, update the installation examples in README.md to use your actual GitHub username instead of placeholders.

## File Structure

Your plugin now has the proper Neovim plugin structure:

```
jira-nvim/
├── LICENSE                 # MIT License
├── README.md              # Main documentation  
├── CLAUDE.md              # Development guide
├── SETUP.md               # This file
├── .gitignore             # Git ignore rules
├── stylua.toml            # Lua formatting config
├── .github/
│   └── workflows/
│       └── ci.yml         # GitHub Actions CI
├── doc/
│   └── jira-nvim.txt      # Vim help documentation
├── plugin/
│   └── jira-nvim.lua      # Plugin initialization
└── lua/
    └── jira-nvim/
        ├── init.lua       # Main plugin entry point
        ├── config.lua     # Configuration management  
        ├── cli.lua        # Jira CLI wrapper functions
        ├── ui.lua         # User interface and windows
        ├── utils.lua      # Utility functions
        └── form.lua       # Interactive forms
```

## Features to Highlight

When sharing your plugin, emphasize these unique features:

1. **Form-based Interface** - No need to remember jira-cli flags
2. **LazyVim Integration** - Seamless integration with modern Neovim setup
3. **Smart Navigation** - Auto-detects issue keys under cursor
4. **Comprehensive Filtering** - Advanced forms for complex queries
5. **Quick Presets** - One-key access to common operations
6. **Flexible UI** - Floating windows or splits

## Sharing

Once published, you can share it:

- Post on Reddit r/neovim
- Share on Twitter/X with #neovim hashtag
- Submit to awesome-neovim lists
- Share in Neovim Discord communities

## Maintenance

For ongoing maintenance:

1. **Issues**: Monitor GitHub issues for bug reports
2. **Features**: Consider feature requests from users
3. **Updates**: Keep up with jira-cli changes
4. **Documentation**: Update docs based on user feedback