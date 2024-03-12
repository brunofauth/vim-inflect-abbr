vim9script
import autoload 'prono/inflect_abbr.vim'


if has_key(g:, "loaded_inflect_abbr")
    finish
endif
g:loaded_inflect_abbr = 1


command! -nargs=+            InflectAbbrCp     call inflect_abbr.AddAbbrCapital(<f-args>)
command! -nargs=+            InflectAbbrCpPl   call inflect_abbr.AddAbbrCapitalPlural(<f-args>)
command! -nargs=+            InflectAbbrCpPlGn call inflect_abbr.AddAbbrCapitalPluralGender(<f-args>)
command! -nargs=0 -bar -bang InflectAbbrLoad  call inflect_abbr.BufLoadAbbrsFromSpellLang(<bang>false)
command! -nargs=0 -bar       InflectAbbrUnload call inflect_abbr.BufUnloadAbbrsAll()

g:inflect_abbr_filetypes = ['markdown', 'text', 'asciidoc']
g:inflect_abbr_enable_load_on_set_ft = v:true
g:inflect_abbr_enable_load_on_enter = v:true
# g:inflect_abbr_enable_cmd_aliases = v:true
g:inflect_abbr_enable_watch_spelllang = v:true

augroup inflect_abbr_filetype
    autocmd!
    execute "autocmd FileType" g:inflect_abbr_filetypes->join(',')
        \ "if get(g:, 'inflect_abbr_enable_load_on_set_ft', v:true) | InflectAbbrLoad | endif"

    autocmd BufNewFile,BufRead *
        \ call prono#inflect_abbr#BufLoadAbbrsOnEnter()
    autocmd OptionSet spelllang
        \ call prono#inflect_abbr#BufUpdateAbbrsFromSpellLang(v:option_old, v:option_new)
    # autocmd SourcePre abbr/*.vim
    #     \ call prono#inflect_abbr#RegisterFtAbbrCommandAliases()
augroup END

call inflect_abbr.RegisterAbbrFiles()
