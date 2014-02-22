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
current_issues = []
debug_remotes = ""
github_datacache = {}
cache_count = 0

def getRepoURI():
	global current_repo, github_repos, debug_remotes

	# get the directory the current file is in
	filepath = vim.eval("expand('%:p:h')")

	# cache the github repo for performance
	if github_repos.get(filepath,'') != '':
		current_repo = github_repos[filepath]
		return

	cmd = 'git -C "' + filepath + '" remote -v'

	filedata = os.popen(cmd).read()
	debug_remotes = filedata

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
	global current_repo, current_issues, cache_count, github_datacache

	# nothing found? can't continue
	if current_repo == "":
		return
	
	if github_datacache.get(current_repo,'') == '' or cache_count > 3:
		# load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
		github_datacache[current_repo] = urllib2.urlopen("https://api.github.com/repos/" + current_repo + "/issues").read()
		cache_count = 0
	else:
		cache_count += 1

	# JSON parse the API response
	current_issues = json.loads(github_datacache[current_repo])

def dumpIssuesIntoBuffer():
	global current_repo, current_issues, debug_remotes

	if current_repo == "":
		vim.current.buffer[:] = ["Failed to find a suitable Github remote, sorry! We found these remotes: "+debug_remotes]
		return

	# its an array, so dump these into the current (issues) buffer
	for issue in current_issues:
		issuestr = str(issue["number"]) + " " + issue["title"]
		vim.current.buffer.append(issuestr)

	# append leaves an unwanted beginning line. delete it.
	vim.command("1delete _")

def populateOmniComplete():
	global current_repo, current_issues
	for issue in current_issues:
		issuestr = str(issue["number"]) + " " + issue["title"]
		vim.command("call add(b:omni_options, "+json.dumps(issuestr)+")")

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
	python dumpIssuesIntoBuffer()
endfunction

" omnicomplete function, also used by neocomplete
function! githubissues#CompleteIssues(findstart, base)
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
		for m in b:omni_options
			if m =~ '^' . b:compl_context
				call add(res, m)
			endif
		endfor
		return res
	endif
endfunction

" set omnifunc for the buffer
function! s:setupOmni()
	setlocal omnifunc=githubissues#CompleteIssues

	" empty array will store the menu items
	let b:omni_options = []

	" figure out the repo URI, download issues, and add to omnicomplete
	python getRepoURI()
	python pullGithubAPIData()
	python populateOmniComplete()
endfunction

" define the :Gissues command
command!        -nargs=0 Gissues             call s:getGithubIssues()

" Neocomplete support
if !exists('g:neocomplete#sources#omni#input_patterns')
  let g:neocomplete#sources#omni#input_patterns = {}
endif
let g:neocomplete#sources#omni#input_patterns.gitcommit = '\#\d*'

" Install omnifunc on gitcommit files
autocmd FileType gitcommit call s:setupOmni()

