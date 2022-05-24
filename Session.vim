let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
silent only
silent tabonly
cd ~/work/zelda
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
set shortmess=aoO
badd +263 src/main.jai
badd +441 ~/jai/modules/Simp/immediate.jai
badd +1 term://~/work/zelda/src//12097:/bin/sh
badd +132 ~/jai/modules/Simp/backend/gl.jai
badd +1 src/input.jai
badd +1 ~/jai/modules/Simp/shader.jai
badd +32 ~/jai/modules/Simp/module.jai
badd +167 ~/jai/modules/Simp/examples/example.jai
badd +43 ~/jai/modules/Input/module.jai
badd +296 ~/jai/modules/GetRect/module.jai
badd +616 ~/jai/modules/GetRect/examples/example.jai
badd +622 ~/jai/modules/Input/windows.jai
badd +568 ~/jai/modules/Input/x11.jai
badd +115 ~/jai/modules/GetRect/system/active_widgets.jai
badd +114 ~/jai/modules/GetRect/system/pointer_image.jai
badd +1 ~/jai/modules/GetRect/system/system.jai
badd +538 ~/jai/modules/GetRect/widgets/button.jai
badd +1 ~/jai/modules/GetRect/widgets/widgets.jai
badd +150 ~/jai/modules/GetRect/widgets/checkbox.jai
badd +1 ~/jai/modules/GetRect/system/common_text_input.jai
badd +1 ~/jai/modules/GetRect/system/occlusion.jai
badd +1 ~/jai/modules/GetRect/system/state.jai
badd +1 ~/jai/modules/Window_Creation/module.jai
badd +177 ~/jai/modules/Window_Creation/linux.jai
badd +1 ~/jai
badd +2 ~/jai/CHANGELOG.txt
badd +3 ~/jai/examples/code_type.jai
badd +0 vimspector.Variables
badd +0 vimspector.Watches
badd +0 vimspector.StackTrace
badd +0 vimspector.Console
argglobal
%argdel
set stal=2
tabnew +setlocal\ bufhidden=wipe
tabrewind
edit src/main.jai
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 158 + 158) / 317)
exe 'vert 2resize ' . ((&columns * 158 + 158) / 317)
argglobal
balt ~/jai/modules/Simp/immediate.jai
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
let &fdl = &fdl
let s:l = 252 - ((60 * winheight(0) + 38) / 76)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 252
normal! 05|
wincmd w
argglobal
if bufexists(fnamemodify("src/main.jai", ":p")) | buffer src/main.jai | else | edit src/main.jai | endif
if &buftype ==# 'terminal'
  silent file src/main.jai
endif
balt ~/jai/modules/Input/module.jai
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
let &fdl = &fdl
let s:l = 75 - ((0 * winheight(0) + 38) / 76)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 75
normal! 05|
lcd ~/work/zelda
wincmd w
2wincmd w
exe 'vert 1resize ' . ((&columns * 158 + 158) / 317)
exe 'vert 2resize ' . ((&columns * 158 + 158) / 317)
tabnext
edit ~/jai/examples
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 79 + 158) / 317)
exe 'vert 2resize ' . ((&columns * 237 + 158) / 317)
argglobal
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
let &fdl = &fdl
let s:l = 8 - ((7 * winheight(0) + 38) / 76)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 8
normal! 0
lcd ~/work/zelda
wincmd w
argglobal
if bufexists(fnamemodify("~/jai/examples/code_type.jai", ":p")) | buffer ~/jai/examples/code_type.jai | else | edit ~/jai/examples/code_type.jai | endif
if &buftype ==# 'terminal'
  silent file ~/jai/examples/code_type.jai
endif
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
let &fdl = &fdl
let s:l = 3 - ((2 * winheight(0) + 38) / 76)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 3
normal! 0
lcd ~/work/zelda
wincmd w
exe 'vert 1resize ' . ((&columns * 79 + 158) / 317)
exe 'vert 2resize ' . ((&columns * 237 + 158) / 317)
tabnext 1
set stal=1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=20
let &shortmess = s:shortmess_save
let &winminheight = s:save_winminheight
let &winminwidth = s:save_winminwidth
let s:sx = expand("<sfile>:p:r")."x.vim"
if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &g:so = s:so_save | let &g:siso = s:siso_save
set hlsearch
nohlsearch
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
