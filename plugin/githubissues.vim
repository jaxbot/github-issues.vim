" File:        github-issues.vim
" Version:     3.0.0
" Description: Pulls github issues into Vim
" Maintainer:  Jonathan Warner <jaxbot@gmail.com> <http://github.com/jaxbot>
" Homepage:    http://jaxbot.me/
" Repository:  https://github.com/jaxbot/github-issues.vim
" License:     Copyright (C) 2014 Jonathan Warner
"              Released under the MIT license
"        ======================================================================

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

function! s:showGithubIssues(...) 
  call ghissues#init()

  let github_failed = 0
  if a:0 < 1
    python showIssueList(0, "True")
  else
    python showIssueList(vim.eval("a:1"), "True")
  endif

  if github_failed == "1"
    return
  endif

  " its not a real file
  set buftype=nofile

  " map the enter key to copy the line, close the window, and paste it
  nnoremap <buffer> <cr> :normal! 0<cr>:call <SID>showIssue(expand("<cword>"))<cr>
  nnoremap <buffer> i :Giadd<cr>
  nnoremap <buffer> q :q<cr>

endfunction

function! s:showIssue(id)
  call ghissues#init()

  python showIssueBuffer(vim.eval("a:id"))

  call s:setupOmni()

  if a:id == "new"
    normal 0ll
    startinsert
  endif

  setlocal nomodified
endfunction

function! s:setIssueState(state)
  python setIssueData({ 'state': 'open' if vim.eval("a:state") == '1' else 'closed' })
endfunction

function! s:updateIssue()
  call ghissues#init()
  python showIssue()
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

function! s:handleEnter()
  if len(expand("<cword>")) == 40
    echo expand("<cword>")
    execute ":Gedit " . expand("<cword>")
  endif
endfunction

" define the :Gissues command
command! -nargs=* Gissues call s:showGithubIssues(<f-args>)
command! -nargs=0 Giadd call s:showIssue("new")
command! -nargs=* Giedit call s:showIssue(<f-args>)
command! -nargs=0 Giupdate call s:updateIssue()

autocmd BufReadCmd gissues/*/\([0-9]*\|new\) call s:updateIssue()
autocmd BufReadCmd gissues/*/\([0-9]*\|new\) nnoremap <buffer> cc :call <SID>setIssueState(0)<cr>
autocmd BufReadCmd gissues/*/\([0-9]*\|new\) nnoremap <buffer> co :call <SID>setIssueState(1)<cr>
autocmd BufReadCmd gissues/*/\([0-9]*\|new\) nnoremap <buffer> <cr> :call <SID>handleEnter()<cr>
autocmd BufWriteCmd gissues/*/[0-9a-z]* call s:saveIssue()

if !exists("g:github_issues_no_omni")
  " Neocomplete support
  if !exists('g:neocomplete#sources#omni#input_patterns')
    let g:neocomplete#sources#omni#input_patterns = {}
  endif
  let g:neocomplete#sources#omni#input_patterns.gitcommit = '\#\d*'
  let g:neocomplete#sources#omni#input_patterns.gfimarkdown = '.'

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

" force issues and what not to stay in the same window
if !exists("g:github_same_window")
  let g:github_same_window = 0
endif

