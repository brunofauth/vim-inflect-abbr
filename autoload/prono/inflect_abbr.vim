vim9script


var SOURCE_ABBRS_SUCCESS: number = 1
var SOURCE_ABBRS_ALREADY_SOURCED: number = 2

var ADD_ABBR_SUCCESS: number = 1
var ADD_ABBR_ALREADY_EXISTS: number = 2


class AbbrRegistry
    var language: string
    var file_path: string
    var _loaded: bool = false
    var abbrs: dict<string> = {}
    var _force_reloading: bool = false

    def new(this.language, this.file_path, this._loaded = v:none, this.abbrs = v:none,
            this._force_reloading = v:none)
    enddef

    def SourceAbbrs(force_reload: bool = false): number
        if this._loaded && ! force_reload | return SOURCE_ABBRS_ALREADY_SOURCED | endif
        this._force_reloading = force_reload
        SetCurrentLangRegistry(this)
        execute "source" this.file_path
        UnsetCurrentLangRegistry()
        this._loaded = true
        return SOURCE_ABBRS_SUCCESS
    enddef

    def AddAbbr(key: string, val: string): number
        if this.abbrs->has_key(key)
            if this._force_reloading | return ADD_ABBR_SUCCESS
            else                     | return ADD_ABBR_ALREADY_EXISTS
            endif
        endif

        this.abbrs[key] = val
        return ADD_ABBR_SUCCESS
    enddef
endclass



def GetGlobalRegistry(): dict<AbbrRegistry>
    if ! has_key(g:, "inflect_abbr_global_registry")
        g:inflect_abbr_global_registry = {}
    endif
    return g:inflect_abbr_global_registry
enddef


def GetFileTypes(): list<string>
    return get(g:, "inflect_abbr_filetypes", ['markdown', 'text', 'asciidoc'])
enddef


def SetCurrentLangRegistry(registry: AbbrRegistry): void
    g:inflect_abbr_current_registry = registry
enddef


def UnsetCurrentLangRegistry(): void
    remove(g:, "inflect_abbr_current_registry")
enddef


def Capitalize(word: string): string
    return toupper(word[0]) .. word[1 : ]
enddef


export def AddAbbrCapital(base_abbr: string, full: string): bool
    if ! has_key(g:, "inflect_abbr_current_registry")
        echoerr "No language registry selected; can't add abbr"
        return false
    endif
    var registry: AbbrRegistry = g:inflect_abbr_current_registry

    if registry.AddAbbr(base_abbr, full) == ADD_ABBR_ALREADY_EXISTS
        echoerr printf(
            "There's already an abbr '%s' registered for lang '%s'",
            base_abbr, registry.language)
        return false
    endif

    var char_nr = base_abbr[0]->char2nr()
    # Quit if abbr starts with a digit
    if char_nr >= 48 && char_nr < 58 | return true | endif

    var base_abbr_cap = Capitalize(base_abbr)
    if ! registry.AddAbbr(base_abbr_cap, Capitalize(full))
        echoerr printf(
            "There's already an abbr '%s' registered for lang '%s'",
            base_abbr_cap, registry.language)
        return false
    endif

    return true
enddef


export def AddAbbrCapitalPlural(base_abbr: string, full_sg: string, full_pl: string = ""): bool
    if ! AddAbbrCapital(base_abbr, full_sg)
        return false
    endif
    if ! AddAbbrCapital(base_abbr .. 's', (full_pl != "" ? full_pl : full_sg .. "s"))
        return false
    endif
    return true
enddef


export def AddAbbrCapitalPluralGender(
    base_abbr: string, stem: string,
    m_sg: string="", f_sg: string="", m_pl: string="", f_pl: string=""
): bool
    if ! AddAbbrCapital(base_abbr .. (m_sg == "" ? "o"  : m_sg), stem .. (m_sg == "" ? "o"  : m_sg))
        return false
    endif
    if ! AddAbbrCapital(base_abbr .. (f_sg == "" ? "a"  : f_sg), stem .. (f_sg == "" ? "a"  : f_sg))
        return false
    endif
    if ! AddAbbrCapital(base_abbr .. (m_pl == "" ? "os" : m_pl), stem .. (m_pl == "" ? "os" : m_pl))
        return false
    endif
    if ! AddAbbrCapital(base_abbr .. (f_pl == "" ? "as" : f_pl), stem .. (f_pl == "" ? "as" : f_pl))
        return false
    endif
    return true
enddef


export def RegisterAbbrFiles(): void
    var global_registry = GetGlobalRegistry()
    for file_name in globpath(&runtimepath, "abbr/*.vim", v:false, v:true)
        var language = fnamemodify(file_name, ":t:r")
        if match(language, '^[a-zA-Z0-0_-]\+$') == -1
            echoerr "Bad file basename (must be alphanum or - or _):" file_name
            continue
        endif
        global_registry[language] = AbbrRegistry.new(language, file_name)
    endfor
enddef


def ParseSpellLang(value: string): list<string>
    return value->split(',')->map( (_, lang) => lang->trim() )
enddef


def BufLoadAbbrs(lang: string, force_reload: bool = false): void
    var global_registry = GetGlobalRegistry()
    if ! global_registry->has_key(lang) | return | endif
    var abbr_registry = global_registry[lang]
    abbr_registry.SourceAbbrs(force_reload)

    for [key, val] in abbr_registry.abbrs->items()
        silent execute "iabbr <buffer>" key val
    endfor

    var loaded_abbrs = get(b:, "inflect_abbr_loaded_langs", [])
    loaded_abbrs->add(lang)
    b:inflect_abbr_loaded_langs = loaded_abbrs
enddef


export def BufLoadAbbrsFromSpellLang(force_reload: bool = false): void
    for lang in ParseSpellLang(&spelllang)
        BufLoadAbbrs(lang, force_reload)
    endfor
enddef


def BufUnloadAbbrs(lang: string): void
    var index = get(b:, "inflect_abbr_loaded_langs", [])->index(lang)
    if index == -1 | return | endif

    var global_registry = GetGlobalRegistry()
    if ! global_registry->has_key(lang) | return | endif
    var abbr_registry = global_registry[lang]

    for key in abbr_registry.abbrs->keys()
        silent execute "iunabbrev <buffer>" key
    endfor

    b:inflect_abbr_loaded_langs->remove(index)
enddef


export def BufUnloadAbbrsAll(): void
    var langs = get(b:, "inflect_abbr_loaded_langs", [])
    for lang in langs
        BufUnloadAbbrs(lang)
    endfor
enddef


def IsProseFile(): bool
    for file_type in GetFileTypes()
        if &filetype =~? file_type | return true | endif
    endfor
    return false
enddef


export def BufLoadAbbrsOnEnter(): void
    if ! get(g:, "inflect_abbr_enable_load_on_enter", v:true) | return | endif
    if IsProseFile()
        BufLoadAbbrsFromSpellLang()
    endif
enddef


# Although this is quadratic, it should be fine for small lists
def ListDifference(a: list<any>, b: list<any>): list<any>
    var result = []
    for item in a
        if b->index(item) == -1
            result->add(item)
        endif
    endfor
    return result
enddef


export def BufUpdateAbbrsFromSpellLang(old: string, new: string): void
    if ! get(g:, "inflect_abbr_enable_watch_spelllang", v:true) | return | endif

    var old_langs = ParseSpellLang(old)
    var new_langs = ParseSpellLang(new)

    for lang in ListDifference(old_langs, new_langs)
        BufUnloadAbbrs(lang)
    endfor

    for lang in ListDifference(new_langs, old_langs)
        BufLoadAbbrs(lang)
    endfor
enddef


# export def RegisterFtAbbrCommandAliases(): void
#     if ! get(g:, "inflect_abbr_enable_cmd_aliases", v:true) | return | endif
#     command! -buffer -keepscript -nargs=+ Cp     call AddAbbrCapital(<f-args>)
#     command! -buffer -keepscript -nargs=+ CpPl   call AddAbbrCapitalPlural(<f-args>)
#     command! -buffer -keepscript -nargs=+ CpPlGn call AddAbbrCapitalPluralGender(<f-args>)
# enddef
