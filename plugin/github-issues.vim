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

function! s:getGithubIssues() 
	python ws.send(vim.eval("a:js"))
endfunction

function! s:get_visual_selection()
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][: col2 - 2]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, " ")
endfunction

function! s:setupHandlers() 
    au BufWritePost *.html,*.js,*.php :BLReloadPage
endfunction

command! -range -nargs=0 BLEvaluateSelection call s:EvaluateSelection()
command!        -nargs=0 BLEvaluateBuffer    call s:EvaluateBuffer()
command!        -nargs=0 BLEvaluateWord      call s:EvaluateWord()
command!        -nargs=1 BLEval              call s:evaluateJS(<f-args>)
command!        -nargs=0 BLReloadPage        call s:ReloadPage()
command!        -nargs=0 BLReloadTemplate    call s:ReloadTemplate()
command!        -nargs=0 BLReloadCSS         call s:ReloadCSS()
command!        -nargs=0 BLDisconnect        call s:Disconnect()
command!        -nargs=0 BLStart             call s:Start()

if !exists("g:bl_no_mappings")
    vmap <silent><Leader>be :BLEvaluateSelection<CR>
    nmap <silent><Leader>be :BLEvaluateBuffer<CR>
    nmap <silent><Leader>bf :BLEvaluateWord<CR>
    nmap <silent><Leader>br :BLReloadPage<CR>
    nmap <silent><Leader>bc :BLReloadCSS<CR>
endif

