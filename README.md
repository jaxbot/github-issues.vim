github-issues.vim
=================

Github issue integration in Vim. It's kind of awesome.

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

<img src='http://jaxbot.me/pics/vim/vim-github-issues-1.gif'>

### Handling issues

You can open and close issues using `co` and `cc` in the issue view.

<img src='http://jaxbot.me/pics/vim/vim-github-issues-2.gif'>

They're also totally editable buffers, and saving the file will sync with Github's servers. You can use this to write comments, too:

<img src='http://jaxbot.me/pics/vim/vim-github-issues-4.gif'>

### Creating issues

You can even use `:Giadd` to create a blank issue. Saving the buffer will generate a new issue and update the buffer with an issue number and the ability to add comments.

<img src='http://jaxbot.me/pics/vim/vim-github-issues-6.gif'>

How awesome is that!?

### Fugitive integration

Github will show any commits that reference the issue. That's what the omnicomplete helps with. But to make things even more awesome, github-issues.vim integrates with Fugitive.vim to make commit hashes clickable with the return key.

<img src='http://jaxbot.me/pics/vim/vim-github-issues-3.gif'>

### Requirements and Installation

Vim with Python 2.7, Python 2.7 installed and working with Vim.

I recommend using [Pathogen](https://github.com/tpope/vim-pathogen) and Git cloning into ~/.vim/bundle. You can also just download the plugin and paste it into your plugin directory.

### Configuration

The omnicomplete and lookup features will work out of the box for public repos.

If you have private repos, or would like the ability to comment, open, close, and add issues, you will need to set an access token. Don't worry, this is super easy.

```
g:github_access_token
```

Grab an access token [from here](
https://github.com/settings/tokens/new), then set this variable, preferably in your Vimrc, like so:

`let g:github_access_token = "9jb19c1189f083d7013i24367lol"`


Other options include:

```
g:github_issues_no_omni
```

When this is set to any value, github-issues will not set Neocomplete and Omnicomplete hooks.


```
g:github_upstream_issues
```

When this is set to 1, github-issues will use upstream issues (if repo is fork). This will require extra requests for the Github API, however.

```
g:github_api_url = "https://api.github.com/"
```

If you use Github Enterprise, where the Github server is hosted somewhere other than Github.com, set this parameter to your API path. This is specifically for Github Enterprise and will not work for Bitbucket, Gitlab, etc.

When this is set to 1, github-issues will use the current window instead of splitting the screen via the `:new` command.

```
g:github_same_window = 1
```

### Contributing

Pull requests, feature requests, and issues are always welcome!

## Shameless plug

I hack around with Vim plugins, so [follow me](https://github.com/jaxbot) if you're into that kind of stuff (or just want to make my day) ;)

