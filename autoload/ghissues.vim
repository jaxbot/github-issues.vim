" core is written in Python for easy JSON/HTTP support
" do not continue if Vim is not compiled with Python support
if exists("g:github_issues_pyloaded") || !has("python") && !has("python3")
  finish
endif

if has("python3")
	command! -nargs=1 Python python3 <args>
  py3file rplugin/python/ghissues.py
else
	command! -nargs=1 Python python <args>
  pyfile rplugin/python/ghissues.py
endif


" Default to not having loaded xterm
let g:gissues_xterm_colors = 0

function! ghissues#init()
  let g:github_issues_pyloaded = 1

  " Load in colors if we're in terminal mode
  if &term == "xterm-256color"
    call gh_colors#init()
  endif
endfunction

" vim: softtabstop=2 expandtab shiftwidth=2 tabstop=2
