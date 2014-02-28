" File:        github-issues.vim
" Version:     1.6.0
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

	cmd = '(cd ' + filepath + ' && git remote -v)'

	filedata = os.popen(cmd).read()
	debug_remotes = filedata

	current_repo = ""

	# possible URLs
	urls = vim.eval("g:github_issues_urls")
	for url in urls:
		s = filedata.split(url)
		if len(s) > 1:
			s = s[1].split()[0].split(".git")
			github_repos[filepath] = s[0]
			current_repo = s[0]
			break
	
def pullGithubAPIData():
	global current_repo, current_issues, cache_count, github_datacache

	# nothing found? can't continue
	if current_repo == "":
		return
	
	if github_datacache.get(current_repo,'') == '' or cache_count > 3:
		params = ""
		token = vim.eval("g:github_access_token")
		if token != "":
			params = "?access_token=" + token
		# load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
		url = "https://api.github.com/repos/" + urllib2.quote(current_repo) + "/issues" + params
		github_datacache[current_repo] = urllib2.urlopen(url).read()
		cache_count = 0
	else:
		cache_count += 1

	# JSON parse the API response
	current_issues = json.loads(github_datacache[current_repo])

def dumpIssuesIntoBuffer():
	global current_repo, current_issues, debug_remotes

	if current_repo == "":
		vim.current.buffer[:] = ["Failed to find a suitable Github remote, sorry!"]
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

def pullGithubIssue():
	global current_repo, current_issues, cache_count, github_datacache

	# nothing found? can't continue
	if current_repo == "":
		return
	
	params = ""
	token = vim.eval("g:github_access_token")
	if token != "":
		params = "?access_token=" + token
	# load the github API. github_repo looks like "jaxbot/github-issues.vim", for ex.
	url = "https://api.github.com/repos/" + urllib2.quote(current_repo) + "/issues/" + vim.eval("expand('<cword>')") + params
	data = urllib2.urlopen(url).read()

	vim.command("normal ggdG")

	# JSON parse the API response
	issue = json.loads(data)
	# its an array, so dump these into the current (issues) buffer
	vim.current.buffer.append("#" + str(issue["number"]) + " " + issue["title"])
	vim.current.buffer.append("=========")
	vim.current.buffer.append("Reported By: " + issue["user"]["login"])
	vim.current.buffer.append("")
	vim.current.buffer.append(issue["body"])

	# append leaves an unwanted beginning line. delete it.
	vim.command("1delete _")

NOMAS

function! s:getGithubIssueDetails()
	python pullGithubIssue()
endfunction

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
	nnoremap <buffer> <cr> :normal! 0<cr>:GissueDetails<cr>
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

function! s:get_visual_selection()
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][: col2 - 2]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, " ")
endfunction

" define the :Gissues command
command!        -nargs=0 Gissues             call s:getGithubIssues()
command! -nargs=0 GissueDetails call s:getGithubIssueDetails()

if !exists("g:github_issues_no_omni")
	" Neocomplete support
	if !exists('g:neocomplete#sources#omni#input_patterns')
	  let g:neocomplete#sources#omni#input_patterns = {}
	endif
	let g:neocomplete#sources#omni#input_patterns.gitcommit = '\#\d*'

	" Install omnifunc on gitcommit files
	autocmd FileType gitcommit call s:setupOmni()
endif

if !exists("g:github_access_token")
	let g:github_access_token = ""
endif

let g:github_issues_urls = ["git@github.com:","https://github.com/"]

