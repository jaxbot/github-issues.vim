" File:        github-issues.vim
" Version:     1.0.0
" Description: Pulls github issues into Vim
" Maintainer:  Jonathan Warner <jaxbot@gmail.com> <http://github.com/jaxbot>
" Homepage:    http://jaxbot.me/
" Repository:  https://github.com/jaxbot/github-issues.vim 
" License:     Copyright (C) 2014 Jonathan Warner
"              Released under the MIT license 
"			   ======================================================================
"              

if exists("g:github_issues_loaded") || &cp
    finish
endif
let g:github_issues_loaded = "shi"

python <<NOMAS
import sys
import threading
import time
import vim
import json
import urllib2

def pullGithubAPIData():
	data = urllib2.urlopen("https://api.github.com/repos/jaxbot/chrome-devtools.vim/issues").read()
	issues = json.loads(data)
	for issue in issues:
		vim.current.buffer.append(str(issue["number"]) + " " + issue["title"])
	vim.command("1delete _")
NOMAS

function! s:getGithubIssues() 
	silent split github://issues
	normal ggdG
	set buftype=nofile
	nnoremap <buffer> <cr> :normal ^y$<cr>:q<cr><C-w>pp
	python pullGithubAPIData()
endfunction

command!        -nargs=0 GIssues             call s:getGithubIssues()

