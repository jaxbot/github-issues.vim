" File:        github-issues.vim
" Version:     2.0.1
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

function! s:getGithubIssueDetails()
	python pullGithubIssue()
endfunction

" script function for GETing issues
function! s:getGithubIssues() 
	call ghissues#init()

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
	nnoremap <buffer> <cr> :normal! 0<cr>:call <SID>getGithubIssueDetails()<cr>
	nnoremap <buffer> q :q<cr>

	" load issues into buffer
	python pullGithubIssueList()
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
	call ghissues#init()

	setlocal omnifunc=githubissues#CompleteIssues

	" empty array will store the menu items
	let b:omni_options = []

	" figure out the repo URI, download issues, and add to omnicomplete
	python getRepoURI()
	python pullGithubIssueList()
	python populateOmniComplete()
endfunction

" define the :Gissues command
command! -nargs=0 Gissues call s:getGithubIssues()

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

if !exists("g:github_upstream_issues")
	let g:github_upstream_issues = 0
endif

if !exists("g:github_issues_urls")
	let g:github_issues_urls = ["github.com:", "https://github.com/"]
endif

if !exists("g:github_api_url")
	let g:github_api_url = "https://api.github.com/"
endif

if !exists("g:github_issues_max_pages")
	let g:github_issues_max_pages = 1
endif

