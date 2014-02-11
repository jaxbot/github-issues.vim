github-issues.vim
=================

Github issue lookup in Vim. Super simple. Run
```
:Gissues
```
To show issues for the current repository that are listed on Github.

I use this for Fugitive, so I can easily reference issues in my commit messages. Example:
```
:Gcommit
<insert> Fix #
:Gissues
<select issue and press enter>
```

This will add the number and issue title to my commit message, so I don't have to dig around Github to find it. There are other cool uses for it, too, and I hope to make it more robust and complete in the future.

Created as a Hack Day project at Center for Distributed Learning at UCF, New Media team.

# Todo
- Better error handling
- HTTP remote support
- Ability to create issues
- Any others? Make an issue

## Shameless plug

I hack around with Vim plugins, so [follow me](https://github.com/jaxbot) if you're into that kind of stuff (or just want to make my day) ;)
