github-issues.vim
=================

Github issue lookup in Vim. Super simple. Comes with two main features:

### Omnicomplete

If you use Fugitive or edit gitcommit files in Vim, github-issues will automatically populate the omnicomplete menu with issues on Github. This is useful when you want to reference commits, close issues, etc., through Github's commit message parsing.

Here's how it works with Neocomplete:

<img src='http://jaxbot.me/pics/vim/vim_gissues2.gif'>

If you use pure omnicomplete, use `C-x C-o` to pull up the menu.

No need to run commands, no need to configure. It just works. ;) (And if it doesn't, it should, so submit an issue) Not bad, huh?

### Lookup menu

To show Github issues for the current repository:
```
:Gissues
```

Press enter to view more details.

<img src='http://jaxbot.me/pics/vim/vim_gissues.gif'>

### Requirements and Installation

Vim with Python 2.7, Python 2.7 installed and working with Vim.

I recommend using [Pathogen](https://github.com/tpope/vim-pathogen) and Git cloning into ~/.vim/bundle. You can also just download the plugin and paste it into your plugin directory.

### Configuration

Github-issues.vim should work out of the box for most cases. That's the goal, anyway. There are some options, however:

```
g:github_issues_no_omni
```

When this is set to any value, github-issues will not set Neocomplete and Omnicomplete hooks.

```
g:github_access_token
```

This is used if you work on private repositories. Grab an access token [from here](
https://github.com/settings/tokens/new), then set this variable, preferably in your Vimrc, like so:

`let g:github_access_token = "9jb19c1189f083d7013i24367lol"`

```
g:github_upstream_issues
```

When this is set to 1, github-issues will use upstream issues (if repo is fork). This will require extra requests for the Github API, however.

```
g:github_api_url = "https://api.github.com/"
```

If you use Github Enterprise, where the Github server is hosted somewhere other than Github.com, set this parameter to your API path. This is specifically for Github Enterprise and will not work for Bitbucket, Gitlab, etc.


# Todo
- Better error handling
- Any others? Make an issue

## Shameless plug

I hack around with Vim plugins, so [follow me](https://github.com/jaxbot) if you're into that kind of stuff (or just want to make my day) ;)


Started as a Hack Day project at Center for Distributed Learning at UCF, New Media team.
