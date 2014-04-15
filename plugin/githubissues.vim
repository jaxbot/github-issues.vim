" File:        github-issues.vim
" Version:     2.0.1
" Description: Pulls github issues into Vim
" Maintainer:  Jonathan Warner <jaxbot@gmail.com> <http://github.com/jaxbot>
" Homepage:    http://jaxbot.me/
" Repository:  https://github.com/jaxbot/github-issues.vim
" License:     Copyright (C) 2014 Jonathan Warner
"              Released under the MIT license
"			   ======================================================================

" do not load twice
if exists("g:github_issues_loaded") || &cp
    finish
endif

let g:github_issues_loaded = 1

" do not continue if Vim is not compiled with Python2.7 support
if !has("python")
	echo "github-issues.vim requires Python support, sorry :c"
	finish
endif

function! s:showGithubIssues() 
	call ghissues#init()

	python showIssueList()
	
	" its not a real file
	set buftype=nofile

	" map the enter key to copy the line, close the window, and paste it
	nnoremap <buffer> <cr> :normal! 0<cr>:call <SID>showIssue(expand("<cword>"))<cr>
	nnoremap <buffer> i :Giadd<cr>
	nnoremap <buffer> q :q<cr>
	autocmd BufHidden <buffer> :bd!

endfunction

function! s:showIssue(id)
	call ghissues#init()

	python showIssue(vim.eval("a:id"))

	call s:setupOmni()

	autocmd BufWriteCmd <buffer> call s:saveIssue()
	autocmd BufReadCmd <buffer> call s:updateIssue()
	autocmd BufHidden <buffer> :bd!
	nnoremap <buffer> cc :call <SID>setIssueState(0)<cr>
	nnoremap <buffer> co :call <SID>setIssueState(1)<cr>

	normal ggdd
	normal 0ll

	if a:id == "new"
		startinsert
	endif

	setlocal nomodified
endfunction

function! s:setIssueState(state)
	python setIssueData({ 'state': 'open' if vim.eval("a:state") == '1' else 'closed' })
endfunction

function! s:updateIssue()
	call ghissues#init()
	python updateGissue()
	silent execute 'doautocmd BufReadPost '.expand('%:p')
endfunction

function! s:saveIssue()
	call ghissues#init()
	python saveGissue()
	silent execute 'doautocmd BufWritePost '.expand('%:p')
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

	python populateOmniComplete()
endfunction

" define the :Gissues command
command! -nargs=0 Gissues call s:showGithubIssues()
command! -nargs=0 Giadd call s:showIssue("new")
command! -nargs=* Giedit call s:showIssue(<f-args>)
command! -nargs=0 Giupdate call s:updateIssue()

if !exists("g:github_issues_no_omni")
	" Neocomplete support
	if !exists('g:neocomplete#sources#omni#input_patterns')
	  let g:neocomplete#sources#omni#input_patterns = {}
	endif
	let g:neocomplete#sources#omni#input_patterns.gitcommit = '\#\d*'
	let g:neocomplete#sources#omni#input_patterns.markdown = '.'

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

