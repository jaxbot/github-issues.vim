github-issues.vim
=================

Github issue lookup in Vim. Super simple. Now comes with two options.

### Omnicomplete

If you use Fugitive or edit gitcommit files in Vim, github-issues will automatically populate the omnicomplete menu with issues on Github.

No need to run commands, no need to configure. It just works. ;) (And if it doesn't, it should, so submit an issue)

Here's how it works with Neocomplete:

<img src='http://jaxbot.me/pics/vim/vim_gissues2.gif'>

Not bad, huh?

### Lookup menu

To show issues for the current repository that are listed on Github:
```
:Gissues
```

Press enter to close and paste them into the buffer.

Example using Fugitive:

```
:Gcommit
<insert> Fix #
:Gissues
<select issue and press enter>
```

<img src='http://jaxbot.me/pics/vim/vim_gissues.gif'>

# Requirements and Installation

Vim with Python 2.7, Python 2.7 installed and working with Vim.

I recommend using [Pathogen](https://github.com/tpope/vim-pathogen) and Git cloning the sucker into ~/.vim/bundle. You can also just download the plugin and paste it into your plugin directory.

# Todo
- Better error handling
- Support private repos
- Ability to create issues
- Any others? Make an issue

## Shameless plug

I hack around with Vim plugins, so [follow me](https://github.com/jaxbot) if you're into that kind of stuff (or just want to make my day) ;)


Created as a Hack Day project at Center for Distributed Learning at UCF, New Media team.
