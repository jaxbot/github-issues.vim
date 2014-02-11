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
		print str(issue["number"]) + " " + issue["title"]
NOMAS

function! s:getGithubIssues() 
	python pullGithubAPIData()
endfunction

command!        -nargs=0 GIssues             call s:getGithubIssues()

