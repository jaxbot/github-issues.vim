" File:        github-issues.vim
" Version:     1.0.1
" Description: Pulls github issues into Vim
" Maintainer:  Jonathan Warner <jaxbot@gmail.com> <http://github.com/jaxbot>
" Homepage:    http://jaxbot.me/
" Repository:  https://github.com/jaxbot/github-issues.vim
" License:     Copyright (C) 2014 Jonathan Warner
"              Released under the MIT license
"			   ======================================================================
"

" do not load twice
if exists("g:github_issues_loaded") || &cp
    finish
endif
let g:github_issues_loaded = "shi"

" do not continue if Vim is not compiled with Python2.7 support
if !has("python")
	echo "github-issues.vim requires Python support, sorry :c"
	finish
endif

" core is written in Python for easy JSON/HTTP support
python <<NOMAS
import os
import sys
import threading
import time
import vim
import json
import urllib2

def pullGithubAPIData():
	# read the git config
	# TODO: THIS RETURNS GITHUB BECAUSE THE PREVIEW WINDOW IS ALREADY OPEN! NOT GOOD!
	cmd = 'git -C "' + vim.eval("expand('%:p:h')") + '" remote -v'
	print cmd
	return
	filedata = os.popen().read()
	print filedata
	return

	# look for git@github.com (ssh url)
	url = filedata.split("git@github.com:")

	github_repo = ""

	# if we split it and find what we're looking for
	if len(url) < 1:
		url = filedata.split("https://github.com/")
	if len(url) > 1:
		# remotes have .git appended, but the API does not want this, so we trim it out
		s = url[1].split()[0].split(".git")
		github_repo = s[0]

	# Set buffer name to include repo.
	vim.current.buffer.name = 'github://' + github_repo + '/issues'

	# nothing found? can't continue
	if github_repo == "":
		vim.current.buffer[:] = ["Failed to find a suitable Github remote, sorry!"]
		return

	# load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
	data = urllib2.urlopen("https://api.github.com/repos/" + github_repo + "/issues").read()

	# JSON parse the API response
	issues = json.loads(data)

	# its an array, so dump these into the current (issues) buffer
	for issue in issues:
		vim.current.buffer.append(str(issue["number"]) + " " + issue["title"])

	# append leaves an unwanted beginning line. delete it.
	vim.command("1delete _")
NOMAS

" script function for GETing issues
function! s:getGithubIssues() 
	" open a spit window to a dummy file
	silent new
	
	" its not a real file
	set buftype=nofile

	" map the enter key to copy the line, close the window, and paste it
	nnoremap <buffer> <cr> :normal! yy<cr>:q<cr>p

	" load issues into buffer
	python pullGithubAPIData()
endfunction

" define the :Gissues command
command!        -nargs=0 Gissues             call s:getGithubIssues()

