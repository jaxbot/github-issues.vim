" File:        github-issues.vim
" Version:     1.5.0
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

github_repos = {}
current_repo = ""

def getRepoURI():
	global current_repo, github_repos

	# get the directory the current file is in
	filepath = vim.eval("expand('%:p:h')")

	if github_repos.get(filepath,'') != '':
		current_repo = github_repos[filepath]
		return

	cmd = 'git -C "' + filepath + '" remote -v'

	filedata = os.popen(cmd).read()

	# look for git@github.com (ssh url)
	url = filedata.split("git@github.com:")

	# if we split it and find what we're looking for
	if len(url) < 1:
		url = filedata.split("https://github.com/")
	if len(url) > 1:
		# remotes may have .git appended, but the API does not want this, so we trim it out
		s = url[1].split()[0].split(".git")
		github_repos[filepath] = s[0]
		current_repo = s[0]
	else:
		current_repo = ""
	

def pullGithubAPIData():
	global current_repo

	# nothing found? can't continue
	if current_repo == "":
		vim.current.buffer[:] = ["Failed to find a suitable Github remote, sorry!"]
		return

	# load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
	data = urllib2.urlopen("https://api.github.com/repos/" + current_repo + "/issues").read()

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
	" load the repo URI of the current file
	python getRepoURI()

	" open a split window to a dummy file
	" TODO: make this use "new" again
	silent split github://issues
	
	" delete any contents that may exist
	normal ggdG
	
	" its not a real file
	set buftype=nofile

	" map the enter key to copy the line, close the window, and paste it
	nnoremap <buffer> <cr> :normal! yy<cr>:bd<cr><C-w>pp
	nnoremap <buffer> q :q<cr>

	" load issues into buffer
	python pullGithubAPIData()
endfunction

" define the :Gissues command
command!        -nargs=0 Gissues             call s:getGithubIssues()

fun! githubissues#CompleteIssues(findstart, base)
	if a:findstart
		" locate the start of the word
		let line = getline('.')
		let start = col('.') - 1
		while start > 0 && line[start - 1] =~ '\w'
			let start -= 1
		endwhile
		let b:compl_context = getline('.')[start : col('.')]
		return start
	else
		let res = []
		for m in ["14 Omnicomplete", "23 fix issues", "25 who am i kidding"]
			if m =~ '^' . b:compl_context
				call add(res, m)
			endif
		endfor
		return res
	endif
endfun

if !exists('g:neocomplete#sources#omni#input_patterns')
  let g:neocomplete#sources#omni#input_patterns = {}
endif
let g:neocomplete#sources#omni#input_patterns.gitcommit = '\#\d*'

autocmd FileType gitcommit setlocal omnifunc=githubissues#CompleteIssues

