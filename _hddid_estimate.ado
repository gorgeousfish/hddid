/*! version 1.0.0 */
capture program drop _hddid_estimate
program define _hddid_estimate, eclass sortpreserve

    if c(stata_version) < 16 {
        di as error "{bf:hddid} requires Stata 16 or later"
        di as error "  Reason: Python integration ({bf:python:} interface) is only available in Stata 16+"
        di as error "  Your Stata version: `c(stata_version)'"
        exit 198
    }

    version 16
    local _hddid_raw_input = strtrim(`"`0'"')
    local _hddid_precomma `"`_hddid_raw_input'"'
    local _hddid_comma = strpos(`"`_hddid_raw_input'"', ",")
    if `_hddid_comma' > 0 {
        local _hddid_precomma = ///
            strtrim(substr(`"`_hddid_raw_input'"', 1, `_hddid_comma' - 1))
        local _hddid_opts_raw = ///
            strtrim(substr(`"`_hddid_raw_input'"', `_hddid_comma' + 1, .))
        quietly _hddid_parse_methodopt, ///
            optsraw(`"`_hddid_opts_raw'"')
        if `"`r(duplicate)'"' == "1" {
            di as error "{bf:hddid}: method() may be specified at most once, got {bf:`r(method)'}"
            di as error "  Reason: {bf:method()} selects one sieve basis family for the HDDID estimation path, so duplicate {bf:method()} tokens are malformed"
            exit 198
        }
        if `"`r(invalid)'"' == "1" {
            local _hddid_bad_method `"`r(method)'"'
            local _hddid_bad_method_raw `"`r(raw)'"'
            local _hddid_bad_method_disp `"`_hddid_bad_method'"'
            local _hddid_bad_method_assignok 0
            if `"`_hddid_bad_method'"' == `"`_hddid_bad_method_raw'"' & ///
                `"`_hddid_bad_method_raw'"' != "" {
                local _hddid_bad_method_probe `"`_hddid_bad_method_raw'"'
                local _hddid_bad_method_probe = ///
                    subinstr(`"`_hddid_bad_method_probe'"', char(34), "", .)
                local _hddid_bad_method_probe = ///
                    subinstr(`"`_hddid_bad_method_probe'"', char(39), "", .)
                if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)][^ ,]+$") {
                    local _hddid_bad_method_disp = ///
                        strproper(strtrim(regexs(1)))
                    local _hddid_bad_method_assignok 1
                }
                else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)]$") {
                    local _hddid_bad_method_disp = ///
                        strproper(strtrim(regexs(1)))
                    local _hddid_bad_method_assignok 1
                }
                else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*=[ ]*$") {
                    local _hddid_bad_method_disp "method="
                    local _hddid_bad_method_assignok 1
                }
                else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*=[ ]*([^ ,]+)$") {
                    local _hddid_bad_method_disp = ///
                        strproper(strtrim(regexs(1)))
                    local _hddid_bad_method_assignok 1
                }
                else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*[(][ ]*([^)]*)[ ]*[)]$") {
                    local _hddid_bad_method_disp = ///
                        strproper(strtrim(regexs(1)))
                }
            }
            if `"`_hddid_bad_method_disp'"' == "" {
                local _hddid_bad_method_disp `"`_hddid_bad_method'"'
            }
            if `_hddid_bad_method_assignok' {
                di as error "{bf:hddid}: invalid method() syntax"
                if `"`_hddid_bad_method_raw'"' != "" {
                    di as error "  Offending method() input: " as text `"`_hddid_bad_method_raw'"'
                }
                di as error "  Reason: {bf:method()} uses option syntax; write {bf:method(Pol)} or {bf:method(Tri)}, not assignment-style {bf:method=(...)}"
                di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
                exit 198
            }
            di as error "{bf:hddid}: method() must be {bf:Pol} or {bf:Tri}, got {bf:`_hddid_bad_method_disp'}"
            if `"`_hddid_bad_method_raw'"' != "" {
                di as error "  Offending method() input: " as text `"`_hddid_bad_method_raw'"'
            }
            di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
            di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
            exit 198
        }
        quietly _hddid_parse_estopt_rbridge, ///
            optsraw(`"`_hddid_opts_raw'"')
        if `"`r(invalid)'"' == "1" {
            _hddid_show_invalid_estopt, raw(`"`r(raw)'"')
            exit 198
        }
        if `"`r(canonical)'"' != "" {
            _hddid_show_estopt ///
                `"`r(canonical)'"' ///
                `"`r(raw)'"' ///
                `"`r(form)'"'
            exit 198
        }
    }
    local _hddid_trailing_esttoken ""
    local _hddid_trailing_esttoken_raw ""
    local _hddid_pos1 ""
    local _hddid_posrest ""
    local _hddid_pos2 ""
    local _hddid_posrest2 ""
    local _hddid_pos1_is_var 0
    local _hddid_ifin_esttoken_raw ""
    local _hddid_weight_esttoken_raw ""
    local _hddid_esttok_bmeth ""
    local _hddid_esttok_bmeth_raw ""
    gettoken _hddid_pos1 _hddid_posrest : _hddid_precomma
    if `"`_hddid_posrest'"' != "" {
        gettoken _hddid_pos2 _hddid_posrest2 : _hddid_posrest
    }
    if `"`_hddid_pos1'"' != "" {
        capture confirm variable `_hddid_pos1'
        if _rc == 0 {
            local _hddid_pos1_is_var 1
        }
    }
    if `_hddid_pos1_is_var' & `"`_hddid_pos2'"' != "" {
        local _hddid_pos2_probe = lower(strtrim(`"`_hddid_pos2'"'))
        if regexm(`"`_hddid_pos2_probe'"', "^[(].*[)]$") {
            local _hddid_pos2_probe = strtrim(substr( ///
                `"`_hddid_pos2_probe'"', 2, length(`"`_hddid_pos2_probe'"') - 2))
        }
        local _hddid_pos2_probe = ///
            subinstr(`"`_hddid_pos2_probe'"', char(34), "", .)
        local _hddid_pos2_probe = ///
            subinstr(`"`_hddid_pos2_probe'"', char(39), "", .)
        local _hddid_pos2_probe = strtrim(`"`_hddid_pos2_probe'"')
        local _hddid_posrest2_lc = lower(strtrim(`"`_hddid_posrest2'"'))
        if inlist(`"`_hddid_pos2_probe'"', "r", "ra") | ///
            inlist(`"`_hddid_pos2_probe'"', "i", "ip", "ipw") | ///
            inlist(`"`_hddid_pos2_probe'"', "a", "ai", "aip", "aipw") {
            if regexm(`"`_hddid_posrest2_lc'"', "^(if|in)([ ]|$)") {
                local _hddid_ifin_esttoken_raw `"`_hddid_pos2'"'
            }
            else if substr(`"`_hddid_posrest2_lc'"', 1, 1) == "[" {
                local _hddid_weight_esttoken_raw `"`_hddid_pos2'"'
            }
        }
    }
    local _hddid_precomma_probe `"`_hddid_precomma'"'
    local _hddid_precomma_probe = ///
        subinstr(`"`_hddid_precomma_probe'"', char(9), " ", .)
    local _hddid_precomma_probe = ///
        subinstr(`"`_hddid_precomma_probe'"', char(10), " ", .)
    local _hddid_precomma_probe = ///
        subinstr(`"`_hddid_precomma_probe'"', char(13), " ", .)
    local _hddid_precomma_probe = strtrim(`"`_hddid_precomma_probe'"')
    if `"`_hddid_precomma_probe'"' != "" {
        local _hddid_probe_raw ""
        local _hddid_probe_lc ""
        local _hddid_dq = char(34)
        if substr(`"`_hddid_precomma_probe'"', -1, 1) == `"`_hddid_dq'"' {
            local _hddid_before_last = ///
                substr(`"`_hddid_precomma_probe'"', 1, length(`"`_hddid_precomma_probe'"') - 1)
            local _hddid_quote_pos = ///
                strrpos(`"`_hddid_before_last'"', `"`_hddid_dq'"')
            if `_hddid_quote_pos' > 0 {
                local _hddid_prefix_raw = ///
                    substr(`"`_hddid_precomma_probe'"', 1, `_hddid_quote_pos' - 1)
                if strtrim(`"`_hddid_prefix_raw'"') == "" | ///
                    substr(`"`_hddid_prefix_raw'"', -1, 1) == " " {
                    local _hddid_probe_raw = ///
                        substr(`"`_hddid_precomma_probe'"', `_hddid_quote_pos', .)
                    local _hddid_probe_lc = lower(strtrim(substr( ///
                        `"`_hddid_probe_raw'"', 2, length(`"`_hddid_probe_raw'"') - 2)))
                }
            }
        }
        if `"`_hddid_probe_raw'"' == "" {
            local _hddid_space = strrpos(`"`_hddid_precomma_probe'"', " ")
            if `_hddid_space' > 0 {
                local _hddid_probe_raw = ///
                    substr(`"`_hddid_precomma_probe'"', `_hddid_space' + 1, .)
            }
            else {
                local _hddid_probe_raw `"`_hddid_precomma_probe'"'
            }
            local _hddid_probe_raw = strtrim(`"`_hddid_probe_raw'"')
            local _hddid_probe_lc = lower(strtrim(`"`_hddid_probe_raw'"'))
        }
        local _hddid_probe_norm `"`_hddid_probe_lc'"'
        if strlen(`"`_hddid_probe_norm'"') >= 2 {
            local _hddid_norm_first = substr(`"`_hddid_probe_norm'"', 1, 1)
            local _hddid_norm_last = substr(`"`_hddid_probe_norm'"', -1, 1)
            if (`"`_hddid_norm_first'"' == `"`_hddid_dq'"' & ///
                `"`_hddid_norm_last'"' == `"`_hddid_dq'"') | ///
                (`"`_hddid_norm_first'"' == "'" & ///
                `"`_hddid_norm_last'"' == "'") {
                local _hddid_probe_norm = ///
                    strtrim(substr(`"`_hddid_probe_norm'"', 2, ///
                    length(`"`_hddid_probe_norm'"') - 2))
            }
        }
        if regexm(`"`_hddid_probe_norm'"', "^[(].*[)]$") {
            local _hddid_probe_norm = strtrim(substr( ///
                `"`_hddid_probe_norm'"', 2, length(`"`_hddid_probe_norm'"') - 2))
            local _hddid_probe_norm = ///
                subinstr(`"`_hddid_probe_norm'"', char(34), "", .)
            local _hddid_probe_norm = ///
                subinstr(`"`_hddid_probe_norm'"', char(39), "", .)
            local _hddid_probe_norm = strtrim(`"`_hddid_probe_norm'"')
        }
        if inlist(`"`_hddid_probe_norm'"', "r", "ra") {
            local _hddid_trailing_esttoken "ra"
            local _hddid_trailing_esttoken_raw `"`_hddid_probe_raw'"'
        }
        else if inlist(`"`_hddid_probe_norm'"', "i", "ip", "ipw") {
            local _hddid_trailing_esttoken "ipw"
            local _hddid_trailing_esttoken_raw `"`_hddid_probe_raw'"'
        }
        else if inlist(`"`_hddid_probe_norm'"', "a", "ai", "aip", "aipw") {
            local _hddid_trailing_esttoken "aipw"
            local _hddid_trailing_esttoken_raw `"`_hddid_probe_raw'"'
        }
    }
    if `_hddid_comma' > 0 & `_hddid_pos1_is_var' & ///
        strtrim(`"`_hddid_posrest'"') != "" & ///
        strtrim(`"`_hddid_posrest2'"') == "" & ///
        `"`_hddid_trailing_esttoken'"' != "" {
        _hddid_show_esttoken `_hddid_trailing_esttoken_raw'
        exit 198
    }
    if `"`_hddid_ifin_esttoken_raw'"' != "" {
        _hddid_show_esttoken `_hddid_ifin_esttoken_raw'
        exit 198
    }
    if `_hddid_comma' > 0 & `"`_hddid_precomma'"' != "" {
        quietly _hddid_parse_methodopt, ///
            optsraw(`"`_hddid_precomma'"')
        local _hddid_pre_method_duplicate `"`r(duplicate)'"'
        local _hddid_pre_method_invalid `"`r(invalid)'"'
        local _hddid_pre_method `"`r(method)'"'
        local _hddid_pre_method_raw `"`r(raw)'"'
        quietly _hddid_estbefore_method, ///
            precomma(`"`_hddid_precomma'"') ///
            methodraw(`"`_hddid_pre_method_raw'"')
        local _hddid_esttok_bmeth `"`r(canonical)'"'
        local _hddid_esttok_bmeth_raw `"`r(raw)'"'
        if `"`_hddid_pre_method_duplicate'"' == "1" {
            if `"`_hddid_esttok_bmeth'"' != "" {
                _hddid_show_esttoken `_hddid_esttok_bmeth_raw'
                exit 198
            }
            di as error "{bf:hddid}: method() may be specified at most once, got {bf:`_hddid_pre_method'}"
            di as error "  Reason: {bf:method()} selects one sieve basis family for the HDDID estimation path, so duplicate {bf:method()} tokens are malformed"
            exit 198
        }
        if `"`_hddid_pre_method_invalid'"' == "1" {
            if `"`_hddid_esttok_bmeth'"' != "" {
                _hddid_show_esttoken `_hddid_esttok_bmeth_raw'
                exit 198
            }
            local _hddid_bad_method `"`_hddid_pre_method'"'
            local _hddid_bad_method_raw `"`_hddid_pre_method_raw'"'
            local _hddid_bad_method_disp `"`_hddid_bad_method'"'
            local _hddid_bad_method_assignok 0
            if `"`_hddid_bad_method'"' == `"`_hddid_bad_method_raw'"' & ///
                `"`_hddid_bad_method_raw'"' != "" {
                local _hddid_bad_method_probe `"`_hddid_bad_method_raw'"'
                local _hddid_bad_method_probe = ///
                    subinstr(`"`_hddid_bad_method_probe'"', char(34), "", .)
                local _hddid_bad_method_probe = ///
                    subinstr(`"`_hddid_bad_method_probe'"', char(39), "", .)
                if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)][^ ,]+$") {
                    local _hddid_bad_method_disp = ///
                        strproper(strtrim(regexs(1)))
                    local _hddid_bad_method_assignok 1
                }
                else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)]$") {
                    local _hddid_bad_method_disp = ///
                        strproper(strtrim(regexs(1)))
                    local _hddid_bad_method_assignok 1
                }
                else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*=[ ]*$") {
                    local _hddid_bad_method_disp "method="
                    local _hddid_bad_method_assignok 1
                }
                else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*=[ ]*([^ ,]+)$") {
                    local _hddid_bad_method_disp = ///
                        strproper(strtrim(regexs(1)))
                    local _hddid_bad_method_assignok 1
                }
                else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                    "^method[ ]*[(][ ]*([^)]*)[ ]*[)]$") {
                    local _hddid_bad_method_disp = ///
                        strproper(strtrim(regexs(1)))
                }
            }
            if `"`_hddid_bad_method_disp'"' == "" {
                local _hddid_bad_method_disp `"`_hddid_bad_method'"'
            }
            if `_hddid_bad_method_assignok' {
                di as error "{bf:hddid}: invalid method() syntax"
                if `"`_hddid_bad_method_raw'"' != "" {
                    di as error "  Offending method() input: " as text `"`_hddid_bad_method_raw'"'
                }
                di as error "  Reason: {bf:method()} uses option syntax; write {bf:method(Pol)} or {bf:method(Tri)}, not assignment-style {bf:method=(...)}"
                di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
                exit 198
            }
            di as error "{bf:hddid}: method() must be {bf:Pol} or {bf:Tri}, got {bf:`_hddid_bad_method_disp'}"
            if `"`_hddid_bad_method_raw'"' != "" {
                di as error "  Offending method() input: " as text `"`_hddid_bad_method_raw'"'
            }
            di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
            di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
            exit 198
        }
        if `"`_hddid_pre_method'"' != "" {
            if `"`_hddid_esttok_bmeth'"' != "" {
                _hddid_show_esttoken `_hddid_esttok_bmeth_raw'
                exit 198
            }
            di as error "{bf:hddid}: method() is an option and must be specified after the comma"
            if `"`_hddid_pre_method_raw'"' != "" {
                di as error "  Offending method() input: " as text `"`_hddid_pre_method_raw'"'
            }
            di as error "  Reason: use syntax {bf:hddid depvar, treat(...) x(...) z(...) method(Pol)} or {bf:method(Tri)}; the token before the comma is reserved for the outcome-change depvar"
            di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
            exit 198
        }
    }
    local _hddid_syntax_retry 0
    capture syntax varlist(min=1 max=1 numeric) [if] [in], ///
        TREat(varname numeric) ///
        X(varlist numeric) ///
        Z(varname numeric) ///
        [ K(integer 3) ///
          Method(string) ///
          Q(integer 8) ///
          ALPha(real 0.1) ///
          Z0(numlist) ///
          NOFirst PIhat(varname numeric) PHI1hat(varname numeric) PHI0hat(varname numeric) ///
          SEED(string) ///
          NBoot(integer 1000) ///
          VERBose ]
    if _rc != 0 {
        // Stata's syntax command requires lowercase option names.  Users may
        // write K(3) instead of k(3).  Normalize known option names and retry.
        local _hddid_syntax_retry 0
        if `_hddid_comma' > 0 {
            local _hddid_pre = substr(`"`_hddid_raw_input'"', 1, `_hddid_comma')
            local _hddid_post = substr(`"`_hddid_raw_input'"', `_hddid_comma' + 1, .)
            local _hddid_post_fix `"`_hddid_post'"'
            foreach _hddid_optpair in ///
                "K:k" "Q:q" "X:x" "Z:z" ///
                "Method:method" "Treat:treat" "Alpha:alpha" ///
                "NBoot:nboot" "Nboot:nboot" "NBOOT:nboot" ///
                "Seed:seed" "SEED:seed" ///
                "NOFirst:nofirst" "Nofirst:nofirst" ///
                "PIhat:pihat" "PHI1hat:phi1hat" "PHI0hat:phi0hat" ///
                "Verbose:verbose" "VERBOSE:verbose" ///
                "Z0:z0" {
                local _hddid_from : word 1 of `=subinstr(`"`_hddid_optpair'"', ":", " ", 1)'
                local _hddid_to   : word 2 of `=subinstr(`"`_hddid_optpair'"', ":", " ", 1)'
                local _hddid_post_fix = ///
                    subinstr(`"`_hddid_post_fix'"', " `_hddid_from'(", " `_hddid_to'(", .)
                local _hddid_post_fix = ///
                    subinstr(`"`_hddid_post_fix'"', " `_hddid_from' ", " `_hddid_to' ", .)
            }
            local 0 `"`_hddid_pre'`_hddid_post_fix'"'
            capture syntax varlist(min=1 max=1 numeric) [if] [in], ///
                TREat(varname numeric) ///
                X(varlist numeric) ///
                Z(varname numeric) ///
                [ K(integer 3) ///
                  Method(string) ///
                  Q(integer 8) ///
                  ALPha(real 0.1) ///
                  Z0(numlist) ///
                  NOFirst PIhat(varname numeric) PHI1hat(varname numeric) PHI0hat(varname numeric) ///
                  SEED(string) ///
                  NBoot(integer 1000) ///
                  VERBose ]
            if _rc == 0 {
                local _hddid_syntax_retry 1
            }
        }
    }
    if _rc != 0 & !`_hddid_syntax_retry' {
        if `_hddid_comma' > 0 & `"`_hddid_opts_raw'"' != "" {
            quietly _hddid_parse_estopt_rbridge, ///
                optsraw(`"`_hddid_opts_raw'"')
            if `"`r(invalid)'"' == "1" {
                _hddid_show_invalid_estopt, raw(`"`r(raw)'"')
                exit 198
            }
            if `"`r(canonical)'"' != "" {
                _hddid_show_estopt ///
                    `"`r(canonical)'"' ///
                    `"`r(raw)'"' ///
                    `"`r(form)'"'
                exit 198
            }
        }
        if `"`_hddid_trailing_esttoken'"' != "" & ///
            (strpos(lower(`"`_hddid_precomma_probe'"'), " if ") > 0 | ///
            strpos(lower(`"`_hddid_precomma_probe'"'), " in ") > 0 | ///
            (strpos(`"`_hddid_precomma_probe'"', "[") > 0 & ///
            strpos(`"`_hddid_precomma_probe'"', "]") > 0)) {
            _hddid_show_esttoken `_hddid_trailing_esttoken_raw'
            exit 198
        }
        if `"`_hddid_weight_esttoken_raw'"' != "" {
            _hddid_show_esttoken `_hddid_weight_esttoken_raw'
            exit 198
        }
        exit _rc
    }
    // nofirst accepts externally computed nuisance inputs. Treat tiny
    // double-precision tail differences as numeric jitter, not as a distinct
    // nuisance function or fold-provenance violation.
    local _hddid_nuis_eq_tol = 1e-10

    if "`method'" == "" local method "Pol"
    local _hddid_method_raw `"`method'"'
    local _hddid_method_raw = ///
        subinstr(`"`_hddid_method_raw'"', char(9), " ", .)
    local _hddid_method_raw = ///
        subinstr(`"`_hddid_method_raw'"', char(10), " ", .)
    local _hddid_method_raw = ///
        subinstr(`"`_hddid_method_raw'"', char(13), " ", .)
    local method = strproper(strtrim(strlower(`"`_hddid_method_raw'"')))
    if !inlist("`method'", "Pol", "Tri") {
        di as error "{bf:hddid}: method() must be {bf:Pol} or {bf:Tri}, got {bf:`method'}"
        di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
        di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
        exit 198
    }

    if `k' < 2 {
        di as error "{bf:hddid}: k() must be >= 2, got `k'"
        exit 198
    }

    if `q' < 1 {
        di as error "{bf:hddid}: q() must be a positive integer, got `q'"
        exit 198
    }
    if "`method'" == "Tri" & mod(`q', 2) != 0 {
        di as error "{bf:hddid}: q() must be even when method(Tri) is specified"
        di as error "  Reason: trigonometric basis {1, cos(2kπz), sin(2kπz)}_{k=1}^{q/2} requires q/2 pairs"
        exit 198
    }

    if `alpha' <= 0 | `alpha' >= 1 {
        di as error "{bf:hddid}: alpha() must be in (0, 1), got `alpha'"
        exit 198
    }

    if `nboot' < 2 {
        di as error "{bf:hddid}: nboot() must be an integer >= 2, got `nboot'"
        di as error "  Reason: a single Gaussian bootstrap draw cannot identify the quantile-based rowwise-envelope lower/upper critical-value pair behind the published CIuniform interval object"
        exit 198
    }

    local seed_input `"`seed'"'
    if `"`seed_input'"' == "" {
        local seed = -1
    }
    else {
        capture confirm number `seed_input'
        if _rc != 0 {
            di as error "{bf:hddid}: seed() must be an integer in [0, 2147483647] or -1, got `seed_input'"
            exit 198
        }
        local seed = real(`"`seed_input'"')
        if missing(`seed') | `seed' != floor(`seed') | `seed' < -1 | `seed' > 2147483647 {
            di as error "{bf:hddid}: seed() must be an integer in [0, 2147483647] or -1, got `seed_input'"
            exit 198
        }
    }
    if "`nofirst'" != "" {
        if "`pihat'" == "" | "`phi1hat'" == "" | "`phi0hat'" == "" {
            di as error "{bf:hddid}: when {bf:nofirst} is specified, {bf:pihat()}, {bf:phi1hat()}, and {bf:phi0hat()} must all be provided"
            exit 198
        }
    }
    else {
        if "`pihat'" != "" | "`phi1hat'" != "" | "`phi0hat'" != "" {
            di as error "{bf:hddid}: {bf:pihat()}, {bf:phi1hat()}, {bf:phi0hat()} can only be specified with {bf:nofirst}"
            exit 198
        }
    }

    // Clear transient bridge objects from any prior run before this call
    // rebuilds the Mata/Python sidecars.
    _hddid_cleanup_state, khint(`k')
    // Honor the caller's quietly prefix for verbose subcommands while keeping
    // hddid's own diagnostics controlled by its explicit display branches.
    local _hddid_subcmd_prefix = cond(c(noisily), "noisily", "quietly")

    local depvar `varlist'
    local depvar_in_x : list x & depvar
    if `"`depvar_in_x'"' != "" {
        di as error "{bf:hddid}: depvar may not also appear in x(): {bf:`depvar_in_x'}"
        exit 198
    }
    if "`depvar'" == "`treat'" {
        di as error "{bf:hddid}: depvar may not also be specified in treat(): {bf:`depvar'}"
        exit 198
    }
    if "`depvar'" == "`z'" {
        di as error "{bf:hddid}: depvar may not also be specified in z(): {bf:`depvar'}"
        exit 198
    }
    if "`treat'" == "`z'" {
        di as error "{bf:hddid}: treat() variable may not also be specified in z(): {bf:`treat'}"
        exit 198
    }
    local treat_in_x : list x & treat
    if `"`treat_in_x'"' != "" {
        di as error "{bf:hddid}: treat() variable may not also appear in x(): {bf:`treat_in_x'}"
        exit 198
    }
    local z_in_x : list x & z
    if `"`z_in_x'"' != "" {
        di as error "{bf:hddid}: z() variable may not also appear in x(): {bf:`z_in_x'}"
        exit 198
    }
    local _x_seen
    local _x_dups
    foreach _xvar of local x {
        local _x_seen_pos : list posof "`_xvar'" in _x_seen
        if `_x_seen_pos' > 0 {
            local _x_dup_pos : list posof "`_xvar'" in _x_dups
            if `_x_dup_pos' == 0 {
                local _x_dups `_x_dups' `_xvar'
            }
        }
        else {
            local _x_seen `_x_seen' `_xvar'
        }
    }
    if `"`_x_dups'"' != "" {
        di as error "{bf:hddid}: x() may not contain duplicate covariates"
        di as error "  Duplicate variable(s): {bf:`_x_dups'}"
        exit 198
    }
    local x_user : list retokenize x
    local x `x_user'
    if "`nofirst'" != "" {
        foreach _nuis_name in pihat phi1hat phi0hat {
            local _nuis_var ``_nuis_name''
            if "`_nuis_var'" == "`depvar'" {
                di as error "{bf:hddid}: `_nuis_name'() may not reuse depvar: {bf:`_nuis_var'}"
                exit 198
            }
            if "`_nuis_var'" == "`treat'" {
                di as error "{bf:hddid}: `_nuis_name'() may not reuse treat(): {bf:`_nuis_var'}"
                exit 198
            }
            if "`_nuis_var'" == "`z'" {
                di as error "{bf:hddid}: `_nuis_name'() may not reuse z(): {bf:`_nuis_var'}"
                exit 198
            }
            local _nuis_in_x : list x & _nuis_var
            if `"`_nuis_in_x'"' != "" {
                di as error "{bf:hddid}: `_nuis_name'() may not reuse x(): {bf:`_nuis_in_x'}"
                exit 198
            }
        }
        // hddid consumes numeric nuisance paths, not Stata storage identities.
        // pihat()/phi1hat()/phi0hat() may therefore share one storage column
        // when the caller intentionally supplies identical numeric nuisance
        // values; hddid copies each role into separate working variables
        // before estimation. What must remain distinct at the command
        // boundary are the structural depvar()/treat()/x()/z() roles.
    }
    local p : word count `x'
    local dz : word count `z'
    if `dz' != 1 {
        di as error "{bf:hddid}: current version supports only one Z covariate"
        di as error "  Got `dz' Z covariates: `z'"
        di as error "  Reason: sieve basis construction (Pol/Tri) currently implements univariate z only"
        exit 198
    }

    capture local matdim_limit = c(max_matdim)
    if _rc != 0 {
        local matdim_limit = c(matsize)
    }

    if `p' > `matdim_limit' {
        di as error "{bf:hddid}: number of X covariates p=`p' exceeds Stata matrix dimension limit `matdim_limit'"
        di as error "  Reason: CLIME precision matrix estimation transfers data between Mata and Python via Stata matrices:"
        di as error "    - tildex matrix (n_eval x p) via st_matrix() from Mata to Stata matrix space"
        di as error "    - covinv matrix (p x p) via sfi.Matrix.store() from Python to Stata matrix space"
        di as error "  Stata matrix row/column dimensions cannot exceed `matdim_limit'."

        if c(MP) == 1 {
            di as error "  Current edition: Stata/MP (matrix limit 65,534). p=`p' exceeds this limit."
            di as error "  Please reduce the number of covariates in x()."
        }
        else if c(SE) == 1 {
            if `p' <= 65534 {
                di as error "  Current edition: Stata/SE (matrix limit 11,000)."
                di as error "  Upgrade to Stata/MP (limit 65,534) to accommodate p=`p'."
            }
            else {
                di as error "  Current edition: Stata/SE (matrix limit 11,000)."
                di as error "  p=`p' exceeds the matrix limit of all Stata editions."
                di as error "  Please reduce the number of covariates in x()."
            }
        }
        else {
            capture local ed_real = c(edition_real)
            if _rc == 0 & "`ed_real'" == "BE" {
                local _ed_name "Stata/BE"
            }
            else {
                local _ed_name "Stata/IC"
            }
            if `p' <= 11000 {
                di as error "  Current edition: `_ed_name' (matrix limit 800)."
                di as error "  Upgrade to Stata/SE (limit 11,000) to accommodate p=`p'."
            }
            else if `p' <= 65534 {
                di as error "  Current edition: `_ed_name' (matrix limit 800)."
                di as error "  Upgrade to Stata/MP (limit 65,534) to accommodate p=`p'."
            }
            else {
                di as error "  Current edition: `_ed_name' (matrix limit 800)."
                di as error "  p=`p' exceeds the matrix limit of all Stata editions."
                di as error "  Please reduce the number of covariates in x()."
            }
        }
        exit 908
    }

    marksample touse, novarlist
    local _default_prop_touse ""
    if "`nofirst'" == "" {
        tempvar _default_prop_touse_var _default_score_touse_var
        markout `touse' `treat' `x' `z'
        quietly gen byte `_default_prop_touse_var' = `touse'
        quietly gen byte `_default_score_touse_var' = `_default_prop_touse_var'
        markout `_default_score_touse_var' `depvar'
        local touse `_default_score_touse_var'
        local _default_prop_touse `_default_prop_touse_var'
    }
    else {
        markout `touse' `treat' `x' `z'
    }

    qui count if `touse'
    local n = r(N)
    if `n' == 0 {
        di as error "{bf:hddid}: no valid observations after excluding missing values"
        exit 2000
    }
    local _hddid_xcanon_touse `touse'
    capture mata: _hddid_canonical_x_order(J(1, 1, 0))
    if _rc != 0 {
        quietly _hddid_resolve_pkgdir ""
        local _hddid_xcanon_pkgdir `"`r(pkgdir)'"'
        if `"`_hddid_xcanon_pkgdir'"' == "" {
            di as error "{bf:hddid}: cannot reload x()-canonicalization Mata helpers during preprocessing"
            di as error "  Reason: the current Stata session lost {_hddid_canonical_x_order()} and no valid hddid package directory could be resolved"
            exit 198
        }
        capture quietly run "`_hddid_xcanon_pkgdir'/_hddid_mata.ado"
        if _rc != 0 {
            di as error "{bf:hddid}: failed to reload {bf:_hddid_mata.ado} before x()-canonicalization"
            di as error "  Expected sidecar location: `_hddid_xcanon_pkgdir'/_hddid_mata.ado"
            exit 198
        }
    }
    tempname __hddid_xord_main
    mata: st_matrix(st_local("__hddid_xord_main"), ///
        _hddid_canonical_x_order( ///
            st_data(., tokens(st_local("x_user")), ///
            st_local("_hddid_xcanon_touse"))))
    local x
    forvalues _hddid_j = 1/`p' {
        local _hddid_idx = `__hddid_xord_main'[1, `_hddid_j']
        local _hddid_xvar : word `_hddid_idx' of `x_user'
        local x = trim(`"`x' `_hddid_xvar'"')
    }
    // The AIPW score, the default-path outer fold map, and the internal
    // propensity path all stay on the same common score sample. nofirst's
    // broader fold-feasibility logic is handled separately below.
    local p : word count `x'

    local _hddid_treat_contract_touse `touse'
    if "`nofirst'" == "" & "`_default_prop_touse'" != "" {
        // Default-path depvar-missing D/W-complete rows still widen the
        // propensity path, so their treatment values must satisfy the
        // front-door binary contract before the first-stage path is built.
        local _hddid_treat_contract_touse `_default_prop_touse'
    }
    qui levelsof `treat' if `_hddid_treat_contract_touse', local(_hddid_treat_levels)
    local _hddid_bad_treat_levels
    foreach _hddid_level of local _hddid_treat_levels {
        if !inlist("`_hddid_level'", "0", "1") {
            local _hddid_bad_treat_levels `"`_hddid_bad_treat_levels' `_hddid_level'"'
        }
    }
    local _hddid_bad_treat_levels = strtrim(`"`_hddid_bad_treat_levels'"')
    if "`_hddid_bad_treat_levels'" != "" {
        di as error "{bf:hddid}: treat() variable must be binary (0/1)"
        di as error "  Found values: `_hddid_treat_levels'"
        exit 198
    }

    capture assert `treat' == 0 | `treat' == 1 if `_hddid_treat_contract_touse'
    if _rc {
        di as error "{bf:hddid}: treat() variable contains values that are not exactly 0 or 1"
        di as error "  Hint: if treat is float/double, consider: {bf:recast byte `treat'}"
        exit 198
    }

    local stage1_prop_nfolds = 3
    local stage1_outcome_nfolds = 5
    local stage2_nfolds = 3
    local stage2_min_eval_per_fold = 2
    local mm_nfolds = 10
    local mm_min_eval_per_fold = 2
    local clime_nfolds_cv_requested = 5
    local clime_nlambda_requested = 5
    local clime_lambda_min_ratio = 0.4
    // cvlassologit, nfolds(3) stratified still late-crashes on some 3/3/6
    // training subsets. Fail closed below 4/4/8 so fold-level propensity CV
    // never reaches the known getMinIC()/PostResults conformability path.
    local stage1_prop_min_class = 4
    local stage1_prop_min_total = 8
    // A non-constant arm-specific outcome fit should not request fixed 5-fold
    // CV unless each validation fold can hold at least two observations.
    // Otherwise the public "fixed 5-fold outcome CV" contract degenerates
    // into singleton-validation folds even when cvlasso still returns e(lopt).
    // Stata's fixed cvlasso, nfolds(5) lopt outcome path still succeeds on
    // non-constant arm-specific training samples with as few as 3 rows, but
    // it fails at 2 rows because lopt is no longer identified. Guard that
    // concrete runtime boundary directly instead of inventing a stricter
    // per-fold validation-count rule the command itself does not require.
    local outcome_min_total = 3
    local stage2_min_total = `stage2_nfolds' * `stage2_min_eval_per_fold'
    local mm_min_total = `mm_nfolds' * `mm_min_eval_per_fold'

    // Peak live-variable budget after marksample(touse):
    //   3 fold/order vars + q sieve vars + (q+1) full sieve vars
    //   + 6 persistent working vars + k fold masks + 1 esample
    //   + 1 transient split-key feasibility tag
    //   + 1 extra propensity-training sample tag when first-stage nuisance
    //     models are estimated internally
    //   + 1 extra predict target when first-stage nuisance models are estimated internally.
    local _hddid_var_budget = 2 * `q' + `k' + 12
    if "`nofirst'" == "" {
        local _hddid_var_budget = `_hddid_var_budget' + 2
    }
    local _hddid_var_used = c(k)
    local _hddid_var_remaining = c(maxvar) - `_hddid_var_used'
    if `_hddid_var_remaining' < `_hddid_var_budget' {
        di as error "{bf:hddid}: insufficient variable slots before estimation"
        di as error "  Stata currently uses `_hddid_var_used' of maxvar=`c(maxvar)' variables; only `_hddid_var_remaining' slots remain"
        di as error "  hddid needs at least `_hddid_var_budget' additional variable slots for fold IDs, sieve bases, evaluation masks, and result bookkeeping"
        di as error "  Reduce q()/k()/x(), increase {stata set maxvar}, or restart with more variable capacity"
        exit 198
    }

    tempvar _orig_order
    qui gen long `_orig_order' = _n

    local _fold_touse `touse'
    local _pihat_domain_touse `touse'
    local _propensity_touse `touse'
    tempvar _default_prop_allfold_train
    quietly gen byte `_default_prop_allfold_train' = 0
    if "`nofirst'" == "" & "`_default_prop_touse'" != "" {
        local _propensity_touse `_default_prop_touse'
        // Default-path D/W-complete rows that miss depvar() never enter the
        // held-out common score sample or the paper's second-stage target.
        // They may therefore widen the propensity nuisance fit for every held-
        // out score fold instead of being arbitrarily removed from one fold's
        // training sample by an auxiliary fold label.
        quietly replace `_default_prop_allfold_train' = ///
            (`_default_prop_touse' & !`touse')
    }

    // User-supplied first-stage inputs must share the same retained overlap
    // sample. In nofirst mode, pihat determines whether a row survives the
    // overlap screen at all, so only missing pihat can be screened before its
    // domain is checked. Missing depvar()/phi1hat()/phi0hat() matter only on
    // rows that survive the overlap rule and therefore enter the AIPW score.
    if "`nofirst'" != "" {
        tempvar _dup_count_nf
        tempvar _retain_count_nf
        tempvar _wgroup_nf
        tempvar _wgroup_w_nf
        tempvar _have_t0_w_nf _have_t1_w_nf
        tempvar _cross_retain_count_nf
        tempvar _pihat_min_nf _pihat_max_nf
        tempvar _cross_pihat_min_nf _cross_pihat_max_nf
        tempvar _phi1_min_nf _phi1_max_nf
        tempvar _phi0_min_nf _phi0_max_nf
        tempvar _fold_base_nf
        tempvar _fold_keep_nf
        tempvar _pre_wgroup_nf
        tempvar _pre_strict_interior_count_nf
        tempvar _pre_retain_count_nf
        tempvar _pre_overlap_ok_count_nf
        tempvar _pre_pihat_min_nf _pre_pihat_max_nf
        tempvar _pre_phi1_min_nf _pre_phi1_max_nf
        tempvar _pre_phi0_min_nf _pre_phi0_max_nf
        tempvar _pre_hidden_pihat_bad_nf
        tempvar _pre_hidden_missing_phi_nf
        tempvar _pre_hidden_phi_bad_nf
        tempvar _dup_bad_nf
        tempvar _dup_bad_pihat_nf
        tempvar _cross_bad_pihat_nf
        tempvar _cross_bad_nf
        tempvar _cross_missing_pihat_raw_nf
        tempvar _cross_pihat_raw_min_nf _cross_pihat_raw_max_nf
        tempvar _cross_bad_pihat_raw_nf
        tempvar _cross_missing_phi_raw_nf
        tempvar _cross_phi1_raw_min_nf _cross_phi1_raw_max_nf
        tempvar _cross_phi0_raw_min_nf _cross_phi0_raw_max_nf
        tempvar _cross_bad_phi_raw_nf
        tempvar _fold_scoreguard_nf
        tempvar _fold_rank_scoreguard_nf
        tempvar _need_retained_nf
        tempvar _need_score_nf
        tempvar _need_score_raw_nf
        tempvar _broad_touse_nf
        tempvar _raw_touse_nf
        tempvar _raw_fold_keep_nf
        tempvar _raw_wgroup_keep_nf
        tempvar _raw_cross_retain_count_nf
        tempvar _pre_hidden_missing_pihat_nf
        tempvar _strict_interior_count_nf
        local n_before = `n'
        quietly gen byte `_need_score_raw_nf' = `touse'
        markout `_need_score_raw_nf' `depvar' `phi1hat' `phi0hat'
        quietly count if `_need_score_raw_nf' & missing(`pihat')
        if r(N) > 0 {
            di as error "{bf:hddid}: supplied {bf:pihat()} is missing on the common nonmissing score sample used by {bf:nofirst}"
            di as error "  Reason: equation (3.1) forms the AIPW score only after {bf:depvar()}, {bf:pihat()}, {bf:phi1hat()}, and {bf:phi0hat()} are all realized on that common score sample"
            di as error "  A missing supplied {bf:pihat()} there is undefined nuisance input, not a rowwise overlap-trimming decision"
            exit 498
        }
        quietly gen byte `_raw_touse_nf' = `touse'
        markout `touse' `pihat'
        qui count if `touse'
        local n = r(N)
        if `n' == 0 {
            di as error "{bf:hddid}: no valid observations after excluding missing values in pihat()"
            exit 2000
        }
        quietly gen byte `_need_score_nf' = `touse'
        markout `_need_score_nf' `depvar' `phi1hat' `phi0hat'
        local _pihat_domain_touse `_need_score_nf'
        // The AIPW score is only defined on the common nonmissing score
        // sample. Rows already excluded there by missing depvar()/phi*()
        // cannot let a numeric pihat() rewrite veto the run by themselves
        // when they also never participate in any retained-relevant same-key
        // fold-provenance check. Missing pihat() is different: it can erase a
        // twin before the broader fold-feasibility map is reconstructed, so
        // keep that guard below. Off-score out-of-range pihat() values that do
        // matter for retained-relevant provenance are still caught by the
        // broader same-key checks below.
        quietly count if `_need_score_nf'
        if r(N) > 0 {
            quietly summarize `pihat' if `_need_score_nf', meanonly
            if r(min) < 0 | r(max) > 1 {
                di as error "{bf:hddid}: supplied {bf:pihat()} must lie within [0,1] on the common nonmissing score sample used by {bf:nofirst}"
                di as error "  min=" r(min) ", max=" r(max)
                di as error "  Exact 0/1 values are treated as overlap failures and trimmed later; only values outside [0,1] are invalid input"
                exit 498
            }
        }
        quietly gen byte `_need_retained_nf' = ///
            (`_need_score_nf' & `pihat' >= 0.01 & `pihat' <= 0.99)
        // Build the broader nofirst feasibility objects on the strict-interior
        // pretrim sample, but only treatment-arm split-key groups that still
        // contribute at least one retained-overlap pretrim row may pin the
        // retained estimator folds. Exact 0/1 groups are already outside the
        // paper's overlap support, while legal near-boundary rows can still be
        // trimmed later without being erased from the retained-relevant
        // fold-pinning subset when a twin on the same treatment-arm key stays
        // inside the retained overlap region. Same-arm pihat() missing/value
        // guards must therefore stay scoped to those retained-relevant keys
        // too: strict-interior-only keys that never reach retained overlap do
        // not rebuild the realized outer fold map.
        quietly gen byte `_broad_touse_nf' = `touse'
        quietly gen byte `_fold_base_nf' = ///
            (`touse' & `pihat' > 0 & `pihat' < 1)
        quietly egen long `_pre_wgroup_nf' = group(`treat' `x' `z') if `_raw_touse_nf'
        quietly bysort `_pre_wgroup_nf': egen long `_pre_strict_interior_count_nf' = ///
            total(`_fold_base_nf')
        quietly bysort `_pre_wgroup_nf': egen long `_pre_retain_count_nf' = ///
            total(`_need_retained_nf')
        quietly bysort `_pre_wgroup_nf': egen double `_pre_pihat_min_nf' = ///
            min(`pihat') if `_broad_touse_nf'
        quietly bysort `_pre_wgroup_nf': egen double `_pre_pihat_max_nf' = ///
            max(`pihat') if `_broad_touse_nf'
        quietly bysort `_pre_wgroup_nf': egen double `_pre_phi1_min_nf' = ///
            min(`phi1hat') if `_broad_touse_nf' & ///
            `pihat' >= 0.01 & `pihat' <= 0.99 & !missing(`phi1hat')
        quietly bysort `_pre_wgroup_nf': egen double `_pre_phi1_max_nf' = ///
            max(`phi1hat') if `_broad_touse_nf' & ///
            `pihat' >= 0.01 & `pihat' <= 0.99 & !missing(`phi1hat')
        quietly bysort `_pre_wgroup_nf': egen double `_pre_phi0_min_nf' = ///
            min(`phi0hat') if `_broad_touse_nf' & ///
            `pihat' >= 0.01 & `pihat' <= 0.99 & !missing(`phi0hat')
        quietly bysort `_pre_wgroup_nf': egen double `_pre_phi0_max_nf' = ///
            max(`phi0hat') if `_broad_touse_nf' & ///
            `pihat' >= 0.01 & `pihat' <= 0.99 & !missing(`phi0hat')
        quietly gen byte `_pre_hidden_missing_pihat_nf' = ///
            (`_raw_touse_nf' & missing(`pihat') & ///
            `_pre_retain_count_nf' > 0)
        quietly count if `_pre_hidden_missing_pihat_nf'
        if r(N) > 0 {
            di as error "{bf:hddid}: supplied {bf:pihat()} is missing within a treatment-arm x()/z() key that still reaches the broader strict-interior nofirst pretrim sample"
            di as error "  A missing {bf:pihat()} on one twin cannot hide behind later overlap trimming when that key still participates in the broader pretrim fold-feasibility logic"
            di as error "  Reason: once a treatment-arm split-key group still has at least one retained-overlap pretrim row with {bf:pihat()} in {bf:[0.01,0.99]}, every twin on that broader pretrim key must carry the same fold-aligned OOF propensity realization as a function of {bf:W=(X,Z)}"
            capture drop `_pre_hidden_missing_pihat_nf' `_pre_hidden_pihat_bad_nf' ///
                `_pre_retain_count_nf' `_pre_pihat_min_nf' `_pre_pihat_max_nf' ///
                `_pre_wgroup_nf' `_raw_touse_nf'
            exit 498
        }
        quietly gen byte `_pre_hidden_pihat_bad_nf' = ///
            (`_broad_touse_nf' & `_pre_retain_count_nf' > 0 & ///
            !missing(`pihat') & ///
            (!`_need_score_nf' | (`_need_score_nf' & ///
            (`pihat' <= 0 | `pihat' >= 1))) & ///
            abs(`_pre_pihat_max_nf' - `_pre_pihat_min_nf') > `_hddid_nuis_eq_tol')
        quietly count if `_pre_hidden_pihat_bad_nf'
        if r(N) > 0 {
            di as error "{bf:hddid}: supplied {bf:pihat()} disagrees within a treatment-arm x()/z() key that still reaches the broader strict-interior nofirst pretrim sample"
            di as error "  Missing {bf:depvar()}/{bf:phi1hat()}/{bf:phi0hat()} on one twin, or an exact-boundary {bf:pihat()} on the common-score sample used by {bf:nofirst}, cannot hide an out-of-range or different legal strict-interior {bf:pihat()} on that broader pretrim key"
            di as error "  Reason: when a treatment-arm split-key group still has at least one retained-overlap pretrim row with {bf:pihat()} in {bf:[0.01,0.99]}, all of its nonmissing {bf:pihat()} realizations must still come from the same fold-aligned OOF propensity function of {bf:W=(X,Z)}"
            capture drop `_pre_hidden_missing_pihat_nf' `_pre_hidden_pihat_bad_nf' ///
                `_pre_retain_count_nf' `_pre_pihat_min_nf' `_pre_pihat_max_nf' ///
                `_pre_wgroup_nf' `_raw_touse_nf'
            exit 498
        }
        quietly gen byte `_pre_hidden_missing_phi_nf' = ///
            (`_raw_touse_nf' & ///
            `pihat' >= 0.01 & `pihat' <= 0.99 & ///
            (missing(`phi1hat') | missing(`phi0hat')) & ///
            `_pre_retain_count_nf' > 0)
        quietly count if `_pre_hidden_missing_phi_nf'
        if r(N) > 0 {
            di as error "{bf:hddid}: same treatment-arm x()/z() key is missing supplied {bf:phi1hat()}/{bf:phi0hat()} on a twin that still contributes a retained overlap row"
            di as error "  A missing supplied {bf:phi1hat()}/{bf:phi0hat()} cannot disappear behind a depvar-missing twin before same-arm retained-overlap candidate nuisance verification when that treatment-arm key still reaches the broader retained-overlap candidate sample"
            di as error "  Reason: within one treatment arm, duplicate evaluation rows with the same x()/z() key share the same outer fold and therefore must share the same fold-external outcome-nuisance provenance on that retained-overlap candidate path"
            exit 498
        }
        quietly gen byte `_pre_hidden_phi_bad_nf' = ///
            (`_broad_touse_nf' & missing(`depvar') & ///
            `pihat' >= 0.01 & `pihat' <= 0.99 & ///
            !missing(`phi1hat') & !missing(`phi0hat') & ///
            `_pre_retain_count_nf' > 0 & ///
            (abs(`_pre_phi1_max_nf' - `_pre_phi1_min_nf') > `_hddid_nuis_eq_tol' | ///
            abs(`_pre_phi0_max_nf' - `_pre_phi0_min_nf') > `_hddid_nuis_eq_tol'))
        quietly count if `_pre_hidden_phi_bad_nf'
        if r(N) > 0 {
            di as error "{bf:hddid}: supplied {bf:phi1hat()}/{bf:phi0hat()} disagrees within a treatment-arm x()/z() key that still contributes a retained overlap row"
            di as error "  Missing {bf:depvar()} on one twin cannot hide a different legal supplied {bf:phi1hat()}/{bf:phi0hat()} on the broader retained-overlap candidate sample"
            di as error "  Reason: within one treatment arm, duplicate evaluation rows with the same x()/z() key share the same outer fold and therefore must share the same fold-external outcome-nuisance provenance on that retained-overlap candidate path"
            exit 498
        }
        // Rows outside the common nonmissing score sample never enter the
        // AIPW score, so keep them in the broader fold-feasibility objects
        // above but exclude them from the later trim accounting/sample size.
        quietly replace `touse' = 0 if (`touse' & !`_need_score_nf')
        quietly egen long `_wgroup_nf' = group(`treat' `x' `z') if `_fold_base_nf'
        quietly bysort `_wgroup_nf': egen long `_strict_interior_count_nf' = ///
            total(`_fold_base_nf')
        quietly bysort `_wgroup_nf': egen long `_retain_count_nf' = ///
            total(`_need_retained_nf')
        quietly gen byte `_fold_keep_nf' = ///
            (`_fold_base_nf' & `_retain_count_nf' > 0)
        // Raw same-fold cross-arm nuisance checks must reconstruct the broader
        // strict-interior split 0 < pihat() < 1 before depvar()/phi*()-missing
        // twins can disappear, but only on shared W=(X,Z) groups that still
        // contribute at least one retained-overlap pretrim row somewhere in
        // that cross-arm group. Rows with missing or exact-boundary pihat()
        // never enter that broader strict-interior split, so they cannot pin
        // fold-external OOF provenance or relabel that diagnostic fold map.
        quietly egen long `_raw_wgroup_keep_nf' = ///
            group(`x' `z') if `_raw_touse_nf'
        quietly bysort `_raw_wgroup_keep_nf': egen long `_raw_cross_retain_count_nf' = ///
            total(`_need_retained_nf')
        quietly gen byte `_raw_fold_keep_nf' = ///
            (`_fold_base_nf' & `_raw_cross_retain_count_nf' > 0)
        // Sample splitting still reconstructs the broader strict-interior
        // pretrim logic 0 < pihat() < 1 for provenance checks, and that same
        // broader strict-interior sample receives the realized outer fold ids
        // before later overlap trimming. Exact-boundary 0/1 pihat() rows stay
        // outside that split, but legal strict-interior rows that later trim
        // out of the retained overlap sample still keep their pretrim fold ids.
        local _fold_touse `_fold_keep_nf'
        qui count if `touse'
        local n = r(N)
        if `n' < `n_before' {
            local n_dropped = `n_before' - `n'
            di as text "{bf:hddid}: `n_dropped' observations excluded due to missing values in pihat() or in depvar()/phi1hat()/phi0hat() on the usable score sample"
        }
        if `n' == 0 {
            di as error "{bf:hddid}: no valid observations after excluding missing values in pihat() or in depvar()/phi1hat()/phi0hat() on the usable score sample"
            exit 2000
        }
        quietly count if `touse' & `treat' == 1
        local _n1_score_nf = r(N)
        quietly count if `touse' & `treat' == 0
        local _n0_score_nf = r(N)
        if `_n1_score_nf' == 0 | `_n0_score_nf' == 0 {
            di as error "{bf:hddid}: common-score sample loses one treatment arm before overlap trimming"
            di as error "  Usable score sample: treated=`_n1_score_nf', control=`_n0_score_nf'"
            di as error "  Reason: equation (3.1) forms the AIPW score on the common nonmissing score sample before overlap trimming, so both D=1 and D=0 must still be present at that stage"
            di as error "  Check missing {bf:depvar()}/{bf:phi1hat()}/{bf:phi0hat()} or supplied {bf:pihat()}; this is not an overlap-trimming failure"
            exit 2000
        }
        // The retained-sample duplicate-key nuisance contract is checked only
        // after overlap trimming, because rows outside the paper's retained
        // overlap region do not enter the AIPW score or second stage.
    }

    local _outer_split_opts
    if "`_default_prop_touse'" != "" {
        local _outer_split_opts `"`_outer_split_opts' defaultproptouse(`_default_prop_touse')"'
    }
    if "`nofirst'" != "" {
        local _outer_split_opts `"`_outer_split_opts' nofirst"'
    }
    quietly _hddid_choose_outer_split_sample, ///
        touse(`touse') ///
        foldtouse(`_fold_touse') ///
        `_outer_split_opts'
    local _outer_split_touse `"`r(samplevar)'"'
    local _fold_pin_count_touse `"`_outer_split_touse'"'

    qui count if `treat' == 1 & `touse'
    local _n1_score_default = r(N)
    qui count if `treat' == 0 & `touse'
    local _n0_score_default = r(N)
    qui count if `treat' == 1 & `_fold_pin_count_touse'
    local n1 = r(N)
    qui count if `treat' == 0 & `_fold_pin_count_touse'
    local n0 = r(N)
    local _n_foldsample = `n1' + `n0'
    local _rowblock_blocksize = ceil(`_n_foldsample' / `k')
    local _rowblock_realized_folds = ///
        ceil(`_n_foldsample' / `_rowblock_blocksize')
    if `_rowblock_realized_folds' < `k' {
        di as error "{bf:hddid}: fold-pinning outer split can realize only `_rowblock_realized_folds' nonempty folds under {bf:k(`k')}"
        if "`nofirst'" == "" {
            di as error "  The default internal-first-stage path pins the outer split on the common score sample, and the paper/R row-block rule would therefore leave later fold labels empty before any first-stage fitting begins"
        }
        else {
            di as error "  Under {bf:nofirst}, hddid still pins the outer split on contiguous current-row blocks of the nofirst fold-pinning sample, so later fold labels would be empty before any retained-score checks or second-stage work begin"
        }
        di as error "  Reason: the maintained paper/R split assigns outer folds as contiguous current-row blocks on the fold-pinning sample, so {bf:k()} cannot exceed the number of nonempty row blocks implied by that sample size"
        di as error "  Reduce {bf:k()} or enlarge the fold-pinning sample before estimation"
        exit 198
    }
    if "`nofirst'" == "" & ///
        (`_n1_score_default' == 0 | `_n0_score_default' == 0) {
        di as error "{bf:hddid}: common-score sample loses one treatment arm before overlap trimming"
        di as error "  Usable score sample: treated=`_n1_score_default', control=`_n0_score_default'"
        di as error "  Reason: equation (3.1) forms the AIPW score on the common nonmissing score sample before overlap trimming, so both D=1 and D=0 must still be present at that stage"
        di as error "  Check missing {bf:`depvar'} values; this is not an overlap-trimming failure"
        exit 2000
    }
    // The default-path outer fold map follows contiguous row-order blocks
    // on the fold-pinning common score sample, matching the paper/R split.
    // can legitimately retain only one arm, so only represented arms must
    // still have enough observations to populate k folds.
    if (`n1' > 0 & `n1' < `k') | (`n0' > 0 & `n0' < `k') {
        di as error "{bf:hddid}: insufficient observations in treatment (`n1') or control (`n0') group"
        di as error "  Each represented group needs at least k=`k' observations for `k'-fold cross-fitting"
        exit 198
    }

    // Only after pure syntax/data-contract validation succeeds should hddid
    // touch external runtime dependencies or load sidecar code.

    capture which lasso2
    if _rc != 0 {
        di as error "{bf:hddid} requires the {bf:lassopack} package"
        di as error "  Reason: hddid uses lasso2 and cvlasso for penalized linear regression"
        di as error "  To install: {stata ssc install lassopack, replace}"
        exit 198
    }

    capture which cvlasso
    if _rc != 0 {
        di as error "{bf:hddid} requires {bf:cvlasso} (cross-validated lasso)"
        di as error "  Reason: cvlasso is required for cross-validated penalized linear regression"
        di as error "  cvlasso is part of the {bf:lassopack} package"
        di as error "  To install/update: {stata ssc install lassopack, replace}"
        exit 198
    }

    if "`nofirst'" == "" {
        capture which cvlassologit
        if _rc != 0 {
            di as error "{bf:hddid} requires {bf:cvlassologit}"
            di as error "  Reason: cvlassologit is required for propensity score estimation via logistic lasso"
            di as error "  cvlassologit ships with the {bf:lassopack} package"
            di as error "  To install/update: {stata ssc install lassopack, replace}"
            exit 198
        }
        capture which lassologit
        if _rc != 0 {
            di as error "{bf:hddid} requires {bf:lassologit}"
            di as error "  Reason: the default internal propensity path can recover through {bf:lassologit} when {bf:cvlassologit} leaves no usable postresults or hits a boundary-only fallback branch"
            di as error "  {bf:lassologit} ships with the {bf:lassopack} package"
            di as error "  To install/update: {stata ssc install lassopack, replace}"
            exit 198
        }
    }

    if `p' > 1 {
        capture python query
        if _rc != 0 {
            di as error "{bf:hddid} requires Python integration (Stata 16+ feature)"
            di as error `"  Reason: when x() has p>1, hddid must load {bf:hddid_clime.py} for the retained-sample CLIME precision-matrix bridge and only then determine whether SciPy is actually needed"'
            di as error "  Python integration is configured via {bf:set python_exec}"
            di as error "  To configure Python: {stata help python}"
            exit 198
        }

        capture python: pass
        if _rc != 0 {
            di as error "{bf:hddid}: Python is configured but cannot be initialized"
            di as error "  Reason: The configured Python executable may be missing or corrupted"
            di as error "  Current python_exec setting: check {stata python query}"
            di as error "  To reconfigure: {stata help python}"
            exit 198
        }

        python: from sfi import Macro; import sys; Macro.setLocal('_hddid_py_major', str(sys.version_info.major)); Macro.setLocal('_hddid_py_minor', str(sys.version_info.minor))
        if `_hddid_py_major' < 3 | (`_hddid_py_major' == 3 & `_hddid_py_minor' < 7) {
            di as error "{bf:hddid} requires Python 3.7 or later"
            di as error "  Reason: Python 3.7+ is required for modern language features and library compatibility"
            di as error "  Your Python version: `_hddid_py_major'.`_hddid_py_minor'"
            di as error "  To configure a different Python: {stata help python}"
            exit 198
        }

        // A previous failed/shadow import can pin numpy in the embedded Python
        // session. Refresh it before loading the Python sidecar. SciPy is
        // checked just-in-time only on folds whose retained tildex matrix
        // actually needs the LP solver.
        quietly _hddid_uncache_numpy

        capture python: from sfi import Macro; import re; import numpy; _ver = str(getattr(numpy, "__version__", "")); _m = re.match(r"^\s*(\d+)\.(\d+)", _ver); Macro.setLocal("_hddid_numpy_ver", _ver); Macro.setLocal("_hddid_numpy_ok", str(int(_m is not None and (int(_m.group(1)), int(_m.group(2))) >= (1, 20))))
        if _rc != 0 {
            di as error "{bf:hddid} requires the Python {bf:numpy} package (version >= 1.20)"
            di as error "  Reason: numpy provides matrix operations required by hddid_clime.py and any CLIME path"
            di as error "  To install: {bf:pip install numpy>=1.20}"
            exit 198
        }
        if "`_hddid_numpy_ok'" != "1" {
            di as error "{bf:hddid} requires {bf:numpy} version 1.20 or later"
            di as error "  Reason: numpy >= 1.20 is the minimum supported array runtime for the CLIME bridge"
            di as error "  Your numpy version: `_hddid_numpy_ver'"
            di as error "  To upgrade: {bf:pip install --upgrade numpy}"
            exit 198
        }

        // Pre-warm the stdlib helpers used by the later safe probe/signature
        // checks so those bridge paths do not need fresh imports after a
        // contaminated embedded Python session mutates builtins.
        capture python: import ast, hashlib, importlib.util, inspect, pathlib, sys
        if _rc != 0 {
            di as error "{bf:hddid}: Python stdlib probe helpers could not be initialized"
            di as error "  Reason: the bridge requires {bf:ast}, {bf:hashlib}, {bf:importlib}, {bf:inspect}, and {bf:pathlib} before loading {bf:hddid_clime.py}"
            di as error "  Current python_exec setting: check {stata python query}"
            di as error "  To reconfigure: {stata help python}"
            exit 198
        }
    }

    // Resolve one package directory and load every sidecar from that same
    // location so the Stata, Mata, and Python pieces come from one build.
    local _hddid_source_run_pkgdir ""
    if `"$HDDID_SOURCE_RUN_PKGDIR_OWNED"' == "1" {
        local _hddid_source_run_pkgdir `"$HDDID_SOURCE_RUN_PKGDIR"'
        if `"$HDDID_SOURCE_RUN_PKGDIR_PREV"' == "" {
            capture macro drop HDDID_SOURCE_RUN_PKGDIR
        }
        else {
            global HDDID_SOURCE_RUN_PKGDIR `"$HDDID_SOURCE_RUN_PKGDIR_PREV"'
        }
        capture macro drop HDDID_SOURCE_RUN_PKGDIR_PREV
        capture macro drop HDDID_SOURCE_RUN_PKGDIR_OWNED
    }
    local _hddid_needpython = (`p' > 1)
    quietly _hddid_resolve_pkgdir `"`_hddid_source_run_pkgdir'"' `_hddid_needpython'
    local _hddid_pkgdir `"`r(pkgdir)'"'
    if `"`_hddid_pkgdir'"' == "" {
        local _hddid_expected_sidecars "{bf:_hddid_mata.ado}, {bf:hddid_p.ado}, and {bf:hddid_estat.ado}"
        if `_hddid_needpython' == 1 {
            local _hddid_expected_sidecars "{bf:_hddid_mata.ado}, {bf:hddid_clime.py}, {bf:hddid_safe_probe.py}, {bf:hddid_p.ado}, and {bf:hddid_estat.ado}"
        }
        di as error "{bf:hddid}: cannot determine the package directory for sidecar resolution"
        di as error "  Reason: source-path {bf:run hddid.ado} does not register on adopath, and no valid source tree was found from the current workspace context"
        di as error `"  Expected sibling files: `_hddid_expected_sidecars'"'
        di as error "  Fallbacks attempted: cached package dir, installed copy on adopath, nearby source-tree probe"
        di as error "  Please run hddid from inside the project tree, pass the package directory as an argument to {bf:run}, or reinstall the package"
        exit 198
    }
    local _hddid_matalib "`_hddid_pkgdir'/_hddid_mata.ado"
    local _hddid_displaysidecar "`_hddid_pkgdir'/_hddid_display.ado"
    local _hddid_predictstub "`_hddid_pkgdir'/hddid_p.ado"
    local _hddid_estatstub "`_hddid_pkgdir'/hddid_estat.ado"

    capture confirm file "`_hddid_matalib'"
    if _rc != 0 {
        di as error "{bf:hddid}: cannot find {bf:_hddid_mata.ado}"
        di as error "  Expected sidecar location: `_hddid_matalib'"
        di as error "  This file should be installed alongside hddid.ado"
        di as error "  Please reinstall the hddid package"
        exit 198
    }

    capture confirm file "`_hddid_displaysidecar'"
    if _rc != 0 {
        capture findfile _hddid_display.ado
        if _rc == 0 {
            local _hddid_displaysidecar `"`r(fn)'"'
        }
        else {
            di as error "{bf:hddid}: cannot find {bf:_hddid_display.ado}"
            di as error "  Expected sibling file: `_hddid_pkgdir'/_hddid_display.ado"
            di as error "  Please reinstall the hddid package"
            exit 198
        }
    }

    capture confirm file "`_hddid_predictstub'"
    if _rc != 0 {
        capture findfile hddid_p.ado
        if _rc == 0 {
            local _hddid_predictstub `"`r(fn)'"'
        }
        else {
            di as error "{bf:hddid}: cannot find {bf:hddid_p.ado}"
            di as error "  Expected sibling file: `_hddid_pkgdir'/hddid_p.ado"
            di as error "  Please reinstall the hddid package"
            exit 198
        }
    }
    quietly _hddid_validate_predict_stub, path("`_hddid_predictstub'")
    local _hddid_predict_prog `"`r(stubname)'"'
    if `"`_hddid_predict_prog'"' == "" {
        local _hddid_predict_prog "hddid_p"
    }

    capture confirm file "`_hddid_estatstub'"
    if _rc != 0 {
        capture findfile hddid_estat.ado
        if _rc == 0 {
            local _hddid_estatstub `"`r(fn)'"'
        }
        else {
            di as error "{bf:hddid}: cannot find {bf:hddid_estat.ado}"
            di as error "  Expected sibling file: `_hddid_pkgdir'/hddid_estat.ado"
            di as error "  Please reinstall the hddid package"
            exit 198
        }
    }
    quietly _hddid_validate_estat_stub, path("`_hddid_estatstub'")

    capture `_hddid_subcmd_prefix' run "`_hddid_matalib'"
    if _rc != 0 {
        di as error "{bf:hddid}: failed to compile Mata function library"
        di as error "  File found at: `_hddid_matalib'"
        di as error "  Check the Mata error message above for details"
        di as error "  The file may be corrupted; please reinstall the hddid package"
        exit 198
    }

    // Confirm that the loaded Mata sidecar exposes the full hddid contract,
    // not just a subset of symbols from a partial or shadowed load.
    tempname __hddid_mata_b __hddid_mata_V __hddid_mata_x __hddid_mata_g
    tempname __hddid_mata_sx __hddid_mata_sg __hddid_mata_tc
    tempname __hddid_mata_cip __hddid_mata_ciu
    capture scalar drop __hddid_mata_selftest
    scalar __hddid_mata_selftest = .
    capture mata: st_numscalar("__hddid_mata_selftest", ///
        _hddid_library_selftest( ///
            "`__hddid_mata_b'", "`__hddid_mata_V'", ///
            "`__hddid_mata_x'", "`__hddid_mata_g'", ///
            "`__hddid_mata_sx'", "`__hddid_mata_sg'", ///
            "`__hddid_mata_tc'", "`__hddid_mata_cip'", ///
            "`__hddid_mata_ciu'"))
    if _rc != 0 | scalar(__hddid_mata_selftest) != 1 {
        di as error "{bf:hddid}: Mata library incomplete or incompatible"
        di as error "  File loaded from: `_hddid_matalib'"
        di as error "  Reason: the required Mata sidecar failed the hddid completeness self-test"
        di as error "  Please reinstall the hddid package and remove shadow/old copies from adopath"
        exit 198
    }

    if `p' > 1 {
        // Load the Python sidecar from the same package directory as hddid.ado.
        // A bare findfile lookup can resolve to a shadow copy from the current
        // directory or a higher-priority adopath entry.
        local _hddid_pyscript "`_hddid_pkgdir'/hddid_clime.py"
        capture confirm file "`_hddid_pyscript'"
        if _rc != 0 {
            // net install may place .py files in a separate py/ directory.
            capture findfile hddid_clime.py
            if _rc == 0 {
                local _hddid_pyscript `"`r(fn)'"'
            }
            else {
                di as error "{bf:hddid}: cannot find {bf:hddid_clime.py}"
                di as error "  Expected sibling file: `_hddid_pkgdir'/hddid_clime.py"
                di as error "  This file should be installed alongside hddid.ado"
                di as error "  Please reinstall the hddid package"
                exit 198
            }
        }
        local _hddid_pyprobe "`_hddid_pkgdir'/hddid_safe_probe.py"
        capture confirm file "`_hddid_pyprobe'"
        if _rc != 0 {
            capture findfile hddid_safe_probe.py
            if _rc == 0 {
                local _hddid_pyprobe `"`r(fn)'"'
            }
            else {
                di as error "{bf:hddid}: cannot find {bf:hddid_safe_probe.py}"
                di as error "  Expected sibling file: `_hddid_pkgdir'/hddid_safe_probe.py"
                di as error "  This file should be installed alongside hddid.ado"
                di as error "  Please reinstall the hddid package"
                exit 198
            }
        }

        // Cache a side-effect-free probe module by resolved file path, but also
        // reload when the sidecar source changes in place under that same path
        // or when the active numpy/scipy dependency identities change across
        // Stata commands. The early bridge/dependency probe must not execute
        // arbitrary top-level sidecar code before hddid decides whether the
        // current fold actually needs SciPy.
        capture `_hddid_subcmd_prefix' python script "`_hddid_pyprobe'"
        if _rc != 0 {
            di as error "{bf:hddid}: failed to load Python script {bf:hddid_safe_probe.py}"
            di as error "  Reason: hddid_safe_probe.py performs the side-effect-free CLIME bridge preflight before the full {bf:hddid_clime.py} sidecar is loaded"
            di as error "  File found at: `_hddid_pyprobe'"
            di as error "  Check Python error message above for details"
            di as error "  The probe file may be corrupted or have encoding issues; please reinstall the hddid package"
            exit 198
        }

        if "`_hddid_py_clime_present'" != "1" {
            di as error "{bf:hddid}: loaded {bf:hddid_clime.py} is missing the required {bf:hddid_clime_solve()} entry point"
            di as error "  File loaded from: `_hddid_pyscript'"
            di as error "  Reason: hddid calls {bf:hddid_clime_solve()} on every p>1 fold to obtain the retained-sample precision matrix used by the debiasing step"
            di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
            exit 198
        }

        if "`_hddid_py_clime_callable'" != "1" {
            di as error "{bf:hddid}: {bf:hddid_clime_solve} is not callable after loading hddid_clime.py"
            di as error "  Reason: The script defined {bf:hddid_clime_solve} as type {bf:`_hddid_py_clime_type'}, not as a callable function/object"
            di as error "  File loaded from: `_hddid_pyscript'"
            di as error "  The file may be an incorrect version or the Python session may contain a corrupted object; please reinstall the hddid package or clear Python state"
            exit 198
        }

        local _hddid_py_clime_hasverb 1
        capture `_hddid_subcmd_prefix' python: ///
            from sfi import Macro; import functools, inspect, pathlib, sys; ///
            import hashlib; ///
            import importlib.util; ///
            _module_path = pathlib.Path(r"`_hddid_pyscript'").resolve(); ///
            _module_name = r"`_hddid_py_module'"; ///
            _probe_name = "__hddid_probe__" + _module_name; ///
            _main_module = sys.modules.get(_module_name); ///
            _probe_module = sys.modules.get(_probe_name); ///
            _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
            _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
            _module = _main_module if _main_ok else (_probe_module if _probe_ok else None); ///
            _source_hash = hashlib.sha1(_module_path.read_bytes()).hexdigest(); ///
            _cached_hash = getattr(_module, "_hddid_source_hash", None) if _module is not None else None; ///
            _probe_only = bool(getattr(_module, "_hddid_safe_probe_only", 0)) if _module is not None else False; ///
            exec("if _module is None or _probe_only or _cached_hash != _source_hash:\n    _reload_spec = importlib.util.spec_from_file_location(_module_name, _module_path)\n    if _reload_spec is None or _reload_spec.loader is None:\n        raise ImportError(f'Unable to create import spec for {_module_path}')\n    _full_module = importlib.util.module_from_spec(_reload_spec)\n    exec(compile(_module_path.read_text(encoding='utf-8'), str(_module_path), 'exec'), _full_module.__dict__)\n    setattr(_full_module, '_hddid_safe_probe_only', 0)\n    setattr(_full_module, '_hddid_source_hash', _source_hash)\n    sys.modules[_module_name] = _full_module\n    sys.modules.pop(_probe_name, None)\n    _module = _full_module\n    _cached_hash = _source_hash\n    _probe_only = False"); ///
            _obj = getattr(_module, "hddid_clime_solve"); ///
            _bridge = getattr(_module, "_hddid_bridge_call_clime_solve", None); ///
            _bridge_call = getattr(_bridge, "__call__", None) if _bridge is not None else None; ///
            _bridge_asyncgen = bool(_bridge is not None and (inspect.isasyncgenfunction(_bridge) or (_bridge_call is not None and inspect.isasyncgenfunction(_bridge_call)))); ///
            _bridge_async = bool(_bridge is not None and (inspect.iscoroutinefunction(_bridge) or (_bridge_call is not None and inspect.iscoroutinefunction(_bridge_call)) or _bridge_asyncgen)); ///
            (_ for _ in ()).throw(TypeError(f"_hddid_bridge_call_clime_solve must be a synchronous callable, got {'async generator function' if _bridge_asyncgen else 'async function'}")) if _bridge is not None and callable(_bridge) and _bridge_async else None; ///
            (_ for _ in ()).throw(TypeError(f"_hddid_bridge_call_clime_solve must be callable, got {type(_bridge).__name__}")) if _bridge is not None and not callable(_bridge) else None; ///
            _sig_target = _bridge if callable(_bridge) and not _bridge_async else _obj; ///
            _sig_call = getattr(_sig_target, "__call__", None) if _sig_target is not None else None; ///
            _helper = getattr(_module, "hddid_clime_requires_scipy", None); ///
            _helper_call = getattr(_helper, "__call__", None) if _helper is not None else None; ///
            _helper_asyncgen = bool(_helper is not None and (inspect.isasyncgenfunction(_helper) or (_helper_call is not None and inspect.isasyncgenfunction(_helper_call)))); ///
            _helper_async = bool(_helper is not None and (inspect.iscoroutinefunction(_helper) or (_helper_call is not None and inspect.iscoroutinefunction(_helper_call)) or _helper_asyncgen)); ///
            _supports_verbose = 0; ///
            exec("try:\n    _resolver = getattr(_module, '_resolve_bridge_signature', None)\n    _sig = _resolver(_sig_target) if callable(_resolver) else None\n    if _sig is None:\n        _sig_target_for_bind = _sig_target\n        _prefer_object_sig = isinstance(_sig_target, functools.partial)\n        if not _prefer_object_sig and _sig_call is not None and _sig_call is not _sig_target and not (inspect.isfunction(_sig_target) or inspect.ismethod(_sig_target) or inspect.isbuiltin(_sig_target) or inspect.isroutine(_sig_target)):\n            _sig_target_for_bind = _sig_call\n        if isinstance(_sig_target_for_bind, functools.partial):\n            try:\n                _sig = inspect.signature(_sig_target_for_bind, follow_wrapped=False)\n            except (TypeError, ValueError):\n                _sig = inspect.signature(_sig_target_for_bind)\n        else:\n            _sig = inspect.signature(_sig_target_for_bind)\n    _sig_parameters = tuple(_sig.parameters.values()) if _sig is not None else ()\n    if inspect.isclass(_sig_target) and _sig_parameters and _sig_parameters[0].name in ('self', 'cls') and _sig_parameters[0].kind in (inspect.Parameter.POSITIONAL_ONLY, inspect.Parameter.POSITIONAL_OR_KEYWORD):\n        _sig = _sig.replace(parameters=_sig_parameters[1:])\nexcept (TypeError, ValueError):\n    pass\nelse:\n    _args = ['__hddid_tildex__', '__hddid_covinv__']\n    _kwargs = {'nfolds_cv': 2, 'nlambda': `clime_nlambda_requested', 'lambda_min_ratio': `clime_lambda_min_ratio', 'perturb': True, 'parallel': False, 'nproc': None, 'random_state': 0, 'verbose': False}\n    _required_kwargs = {'nfolds_cv', 'nlambda', 'lambda_min_ratio', 'random_state', 'perturb', 'parallel', 'nproc'}\n    _bridge_tail_names = ('nfolds_cv', 'nlambda', 'lambda_min_ratio', 'perturb', 'parallel', 'nproc', 'random_state', 'verbose')\n    _params = _sig.parameters\n    _param_order = list(_params)\n    _has_var_kw = any(_p.kind == inspect.Parameter.VAR_KEYWORD for _p in _params.values())\n    _has_var_pos = any(_p.kind == inspect.Parameter.VAR_POSITIONAL for _p in _params.values())\n    if not _has_var_kw:\n        for _p in _params.values():\n            if _p.kind == inspect.Parameter.POSITIONAL_ONLY and _p.name in _kwargs:\n                _args.append(_kwargs.pop(_p.name))\n        if _has_var_pos:\n            _var_pos_index = next((idx for idx, _p in enumerate(_params.values()) if _p.kind == inspect.Parameter.VAR_POSITIONAL), None)\n            _last_var_pos_index = -1\n            for _idx, _name in enumerate(_bridge_tail_names):\n                if _name not in _kwargs:\n                    continue\n                _parameter = _params.get(_name)\n                if _parameter is None:\n                    _last_var_pos_index = _idx\n                    continue\n                _parameter_index = _param_order.index(_name)\n                if _parameter.kind == inspect.Parameter.POSITIONAL_ONLY or (_parameter.kind == inspect.Parameter.POSITIONAL_OR_KEYWORD and _var_pos_index is not None and _parameter_index < _var_pos_index):\n                    _last_var_pos_index = _idx\n            if _last_var_pos_index >= 0:\n                for _name in _bridge_tail_names[:_last_var_pos_index + 1]:\n                    if _name in _kwargs:\n                        _args.append(_kwargs.pop(_name))\n        for _name in tuple(_kwargs):\n            if _name != 'verbose' and _name not in _params and _name not in _required_kwargs:\n                _kwargs.pop(_name)\n    try:\n        _sig.bind(*_args, **_kwargs)\n    except TypeError:\n        _kwargs.pop('verbose', None)\n        if not _has_var_kw:\n            for _name in tuple(_kwargs):\n                if _name not in _params and _name not in _required_kwargs:\n                    _kwargs.pop(_name)\n        _sig.bind(*_args, **_kwargs)\n    else:\n        _supports_verbose = 1"); ///
            Macro.setLocal("_hddid_py_clime_hasverb", str(_supports_verbose)); ///
            Macro.setLocal("_hddid_py_clime_helper_present", str(1 if _helper is not None else 0)); ///
            Macro.setLocal("_hddid_py_clime_helper_callable", str((1 if callable(_helper) and not _helper_async else 0) if _helper is not None else 0)); ///
            Macro.setLocal("_hddid_py_clime_helper_type", ("async generator function" if _helper_asyncgen else ("async function" if _helper_async else type(_helper).__name__)) if _helper is not None else ""); ///
            Macro.setLocal("_hddid_py_clime_bridge_ok", "1")
        if _rc != 0 | "`_hddid_py_clime_bridge_ok'" != "1" {
            di as error "{bf:hddid}: loaded {bf:hddid_clime.py} exposes an incompatible {bf:hddid_clime_solve} bridge signature"
            di as error "  The callable does not accept the retained-fold bridge payload {bf:nfolds_cv}, {bf:nlambda}, {bf:lambda_min_ratio}, {bf:random_state}, {bf:perturb}, {bf:parallel}, and {bf:nproc}"
            di as error "  File loaded from: `_hddid_pyscript'"
            di as error "  Reason: hddid pins the full retained-fold CLIME grid, covariance-perturbation, and runtime dispatch controls at the Stata->Python bridge so estimate-time approval matches the actual fold-level solve contract"
            di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
            exit 198
        }
        // The helper only supports preflight SciPy diagnostics. A helperless
        // sidecar can still satisfy the retained-sample solve contract and may
        // not need SciPy at all, so only validate helper shape when present.
        if "`_hddid_py_clime_helper_present'" == "1" {
            if "`_hddid_py_clime_helper_callable'" != "1" {
                di as error "{bf:hddid}: loaded {bf:hddid_clime.py} exposes a non-callable {bf:hddid_clime_requires_scipy()} helper"
                di as error "  File loaded from: `_hddid_pyscript'"
                di as error "  The helper type was {bf:`_hddid_py_clime_helper_type'} rather than a callable dependency probe"
                di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
                exit 198
            }
            local _hddid_py_helper_sig_ok ""
            capture `_hddid_subcmd_prefix' python: ///
                from sfi import Macro; import functools, inspect, pathlib, sys; ///
                import hashlib; ///
                import importlib.util; ///
                _module_path = pathlib.Path(r"`_hddid_pyscript'").resolve(); ///
                _module_name = r"`_hddid_py_module'"; ///
                _probe_name = "__hddid_probe__" + _module_name; ///
                _main_module = sys.modules.get(_module_name); ///
                _probe_module = sys.modules.get(_probe_name); ///
                _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
                _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
                _module = _main_module if _main_ok else (_probe_module if _probe_ok else None); ///
                _source_hash = hashlib.sha1(_module_path.read_bytes()).hexdigest(); ///
                _cached_hash = getattr(_module, "_hddid_source_hash", None) if _module is not None else None; ///
                _probe_only = bool(getattr(_module, "_hddid_safe_probe_only", 0)) if _module is not None else False; ///
                exec("if _module is None or _probe_only or _cached_hash != _source_hash:\n    _reload_spec = importlib.util.spec_from_file_location(_module_name, _module_path)\n    if _reload_spec is None or _reload_spec.loader is None:\n        raise ImportError(f'Unable to create import spec for {_module_path}')\n    _full_module = importlib.util.module_from_spec(_reload_spec)\n    exec(compile(_module_path.read_text(encoding='utf-8'), str(_module_path), 'exec'), _full_module.__dict__)\n    setattr(_full_module, '_hddid_safe_probe_only', 0)\n    setattr(_full_module, '_hddid_source_hash', _source_hash)\n    sys.modules[_module_name] = _full_module\n    sys.modules.pop(_probe_name, None)\n    _module = _full_module\n    _cached_hash = _source_hash\n    _probe_only = False"); ///
                _helper = getattr(_module, "hddid_clime_requires_scipy"); ///
                _helper_call = getattr(_helper, "__call__", None); ///
                exec("try:\n    _resolver = getattr(_module, '_resolve_bridge_signature', None)\n    _sig = _resolver(_helper) if callable(_resolver) else None\n    if _sig is None:\n        _helper_sig_target = _helper\n        _prefer_object_sig = isinstance(_helper, functools.partial)\n        if not _prefer_object_sig and _helper_call is not None and _helper_call is not _helper and not (inspect.isfunction(_helper) or inspect.ismethod(_helper) or inspect.isbuiltin(_helper) or inspect.isroutine(_helper)):\n            _helper_sig_target = _helper_call\n        if isinstance(_helper_sig_target, functools.partial):\n            try:\n                _sig = inspect.signature(_helper_sig_target, follow_wrapped=False)\n            except (TypeError, ValueError):\n                _sig = inspect.signature(_helper_sig_target)\n        else:\n            _sig = inspect.signature(_helper_sig_target)\n    _sig_parameters = tuple(_sig.parameters.values()) if _sig is not None else ()\n    if inspect.isclass(_helper) and _sig_parameters and _sig_parameters[0].name in ('self', 'cls') and _sig_parameters[0].kind in (inspect.Parameter.POSITIONAL_ONLY, inspect.Parameter.POSITIONAL_OR_KEYWORD):\n        _sig = _sig.replace(parameters=_sig_parameters[1:])\nexcept (TypeError, ValueError):\n    pass\nelse:\n    _helper_args = ['__hddid_tildex__']\n    _helper_kwargs = {'perturb': True}\n    _helper_params = _sig.parameters\n    _helper_has_var_kw = any(_p.kind == inspect.Parameter.VAR_KEYWORD for _p in _helper_params.values())\n    _helper_has_var_pos = any(_p.kind == inspect.Parameter.VAR_POSITIONAL for _p in _helper_params.values())\n    if not _helper_has_var_kw:\n        for _p in _helper_params.values():\n            if _p.kind == inspect.Parameter.POSITIONAL_ONLY and _p.name in _helper_kwargs:\n                _helper_args.append(_helper_kwargs.pop(_p.name))\n        if _helper_has_var_pos and 'perturb' in _helper_kwargs:\n            _helper_args.append(_helper_kwargs.pop('perturb'))\n    _sig.bind(*_helper_args, **_helper_kwargs)"); ///
                Macro.setLocal("_hddid_py_helper_sig_ok", "1")
            if _rc != 0 | "`_hddid_py_helper_sig_ok'" != "1" {
                di as error "{bf:hddid}: loaded {bf:hddid_clime.py} exposes an incompatible {bf:hddid_clime_requires_scipy()} bridge signature"
                di as error "  The callable does not accept the required {bf:tildex_matname} input plus keyword argument {bf:perturb}"
                di as error "  File loaded from: `_hddid_pyscript'"
                di as error "  Reason: hddid asks this helper whether each retained-sample tildex matrix requires the SciPy LP path for CLIME debiasing"
                di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
                exit 198
            }
        }

    }

    local _hddid_scipy_validated 0

    // If hddid sets the seed, preserve the caller's RNG state so the wrapper
    // can restore the ambient Stata stream on exit. Also mark the command's
    // seeded internal stream as active so later _hddid_run_rng_isolated()
    // calls advance that one stream instead of restarting it at each step.
    if `seed' >= 0 {
        c_local _hddid_rngstate_before `c(rngstate)'
        set seed `seed'
        global HDDID_ACTIVE_INTERNAL_SEED `seed'
        global HDDID_ACTIVE_INTERNAL_RNG_STREAM 1
    }

    tempvar _fold _fold_rank
    qui gen long `_fold' = .
    qui gen long `_fold_rank' = .
    local _propensity_foldvar `_fold'
    local _propensity_foldrank `_fold_rank'
    // The outer sample split must stay exogenous to the outcome and nuisance
    // representations. In nofirst mode, level shifts in depvar()/phi*() can
    // leave the DR score unchanged, so those variables cannot enter the fold
    // key without changing the estimator for a purely representational reason.
    // The maintained R reference still realizes the split itself as contiguous
    // current-row blocks on whatever sample pins the held-out identities.
    if "`nofirst'" == "" & "`_default_prop_touse'" != "" & ///
        "`_outer_split_touse'" == "`touse'" & ///
        "`_default_prop_touse'" != "`touse'" {
        capture noisily _hddid_default_outer_fold_map, ///
            foldvar(`_fold') ///
            rankvar(`_fold_rank') ///
            scoretouse(`touse') ///
            proptouse(`_default_prop_touse') ///
            xvars(`x') ///
            zvar(`z') ///
            treatvar(`treat') ///
            k(`k') ///
            seed(`seed')
    }
    else {
        sort `_orig_order'
        capture noisily _hddid_default_outer_fold_map, ///
            foldvar(`_fold') ///
            rankvar(`_fold_rank') ///
            scoretouse(`_outer_split_touse') ///
            proptouse(`_outer_split_touse') ///
            xvars(`x') ///
            zvar(`z') ///
            treatvar(`treat') ///
            k(`k') ///
            seed(`seed')
    }
    if _rc != 0 {
        di as error "{bf:hddid}: invalid outer split for k=`k'"
        di as error "  Reason: the maintained paper/R split assigns outer folds as contiguous current-row blocks on the fold-pinning sample, so {bf:k()} cannot exceed the number of nonempty row blocks implied by that sample size"
        di as error "  Fold feasibility is therefore driven by the realized fold-pinning sample after qualifier/missing-value preprocessing, not by counting distinct x()/z() keys"
        di as error "  Renaming, reordering, or duplicating the same x() information cannot create additional fold-pinning rows or rescue an infeasible {bf:k()}"
        exit _rc
    }
    if "`nofirst'" != "" {
        sort `treat' `_fold_rank'
    }

    if "`nofirst'" != "" {
        // The caller supplies fold-aligned out-of-fold nuisance realizations.
        // Mechanical duplicate-key checks are arm-local because the outer
        // split is stratified by treatment arm, but whenever the same W=(X,Z)
        // key lands in the same outer fold across arms the two rows still
        // share the same fold-external training sample and therefore must
        // carry the same fold-aligned OOF nuisance realization.
        tempvar _fold_pre_raw_nf
        tempvar _fold_rank_pre_raw_nf
        tempvar _wgroup_w_raw_nf
        tempvar _raw_have_t0_nf
        tempvar _raw_have_t1_nf
        quietly gen long `_fold_pre_raw_nf' = .
        quietly gen long `_fold_rank_pre_raw_nf' = .
        quietly egen long `_wgroup_w_nf' = group(`_fold' `x' `z') if `_fold_keep_nf'
        quietly bysort `_raw_wgroup_keep_nf': egen long `_raw_have_t0_nf' = ///
            total(`_raw_fold_keep_nf' & `treat' == 0)
        quietly bysort `_raw_wgroup_keep_nf': egen long `_raw_have_t1_nf' = ///
            total(`_raw_fold_keep_nf' & `treat' == 1)
        quietly count if `_raw_fold_keep_nf' & `_raw_have_t0_nf' > 0 & `_raw_have_t1_nf' > 0
        local _raw_cross_shared_w_nf = r(N)

        // Same-fold cross-arm diagnostics should follow the broader strict-
        // interior split itself. Hidden depvar()/phi*()-missing twins with
        // legal strict-interior pihat() stay on that split, but rows whose
        // pihat() is missing or at the exact 0/1 boundary never join the
        // broader strict-interior map and therefore cannot relabel which
        // retained cross-arm keys are actually same-fold candidates. That
        // broader raw nofirst split still follows contiguous current-row
        // blocks on the raw strict-interior sample, matching the maintained R
        // cross-fit contract after qualifier/subsetting has fixed row order.
        if `_raw_cross_shared_w_nf' > 0 {
            sort `_orig_order'
            capture noisily _hddid_default_outer_fold_map, ///
                foldvar(`_fold_pre_raw_nf') ///
                rankvar(`_fold_rank_pre_raw_nf') ///
                scoretouse(`_raw_fold_keep_nf') ///
                proptouse(`_raw_fold_keep_nf') ///
                xvars(`x') ///
                zvar(`z') ///
                treatvar(`treat') ///
                k(`k') ///
                seed(`seed')
            if _rc != 0 {
                di as error "{bf:hddid}: invalid nofirst raw split for k=`k'"
                di as error "  Reason: same-fold cross-arm missing-{bf:pihat()} verification could not reconstruct the broader usable split map"
                exit _rc
            }
            quietly egen long `_wgroup_w_raw_nf' = group(`_fold_pre_raw_nf' `x' `z') if `_raw_fold_keep_nf'
            quietly bysort `_wgroup_w_raw_nf': egen long `_have_t0_w_nf' = ///
                total(`_raw_fold_keep_nf' & `treat' == 0)
            quietly bysort `_wgroup_w_raw_nf': egen long `_have_t1_w_nf' = ///
                total(`_raw_fold_keep_nf' & `treat' == 1)
            quietly bysort `_wgroup_w_raw_nf': egen long `_cross_retain_count_nf' = ///
                total(`_need_retained_nf')
            quietly gen byte `_cross_missing_pihat_raw_nf' = ///
                (`_raw_fold_keep_nf' & missing(`pihat') & ///
                `_have_t0_w_nf' > 0 & `_have_t1_w_nf' > 0 & ///
                `_cross_retain_count_nf' > 0)
            quietly count if `_cross_missing_pihat_raw_nf'
            if r(N) > 0 {
                di as error "{bf:hddid}: same x()/z() key in the same outer fold is missing supplied {bf:pihat()} on one treatment arm"
                di as error "  {bf:pihat()} must be present and agree across arms when shared {bf:W=(X,Z)} rows are evaluated in the same fold under {bf:nofirst}"
                di as error "  A hidden missing supplied {bf:pihat()} cannot drop out before same-fold cross-arm fold-feasibility verification when that same-fold key still contributes a retained overlap row"
                di as error "  Reason: those rows share the same fold-external training sample, so every same-fold cross-arm twin that still reaches the retained overlap decision must carry the corresponding OOF propensity realization"
                exit 498
            }
            quietly bysort `_wgroup_w_raw_nf': egen double `_cross_pihat_raw_min_nf' = ///
                min(`pihat') if `_raw_fold_keep_nf' & !missing(`pihat')
            quietly bysort `_wgroup_w_raw_nf': egen double `_cross_pihat_raw_max_nf' = ///
                max(`pihat') if `_raw_fold_keep_nf' & !missing(`pihat')
            quietly gen byte `_cross_bad_pihat_raw_nf' = ///
                (`_raw_fold_keep_nf' & !`_fold_keep_nf' & !missing(`pihat') & ///
                `_have_t0_w_nf' > 0 & `_have_t1_w_nf' > 0 & ///
                `_cross_retain_count_nf' > 0 & ///
                abs(`_cross_pihat_raw_max_nf' - `_cross_pihat_raw_min_nf') > `_hddid_nuis_eq_tol')
            quietly count if `_cross_bad_pihat_raw_nf'
            if r(N) > 0 {
                di as error "{bf:hddid}: same x()/z() key in the same outer fold has different supplied {bf:pihat()} across treatment arms"
                di as error "  {bf:pihat()} must agree across arms when shared {bf:W=(X,Z)} rows are evaluated in the same fold under {bf:nofirst}"
                di as error "  A hidden legal-but-trimmed or otherwise non-retained supplied {bf:pihat()} cannot drop out before same-fold cross-arm fold-feasibility verification when that same-fold key still contributes a retained overlap row"
                di as error "  Reason: those rows share the same fold-external training sample, so their fold-aligned OOF propensity realization cannot differ just because {bf:treat()} differs"
                exit 498
            }
            quietly gen byte `_cross_missing_phi_raw_nf' = ///
                (`_raw_fold_keep_nf' & ///
                (`pihat' >= 0.01 & `pihat' <= 0.99) & ///
                (missing(`phi1hat') | missing(`phi0hat')) & ///
                `_have_t0_w_nf' > 0 & `_have_t1_w_nf' > 0 & ///
                `_cross_retain_count_nf' > 0)
            quietly count if `_cross_missing_phi_raw_nf'
            if r(N) > 0 {
                di as error "{bf:hddid}: same x()/z() key in the same outer fold is missing supplied {bf:phi1hat()}/{bf:phi0hat()} on one treatment arm"
                di as error "  {bf:phi1hat()} and {bf:phi0hat()} must be present on any same-fold cross-arm retained-overlap key under {bf:nofirst}"
                di as error "  A hidden missing supplied {bf:phi1hat()}/{bf:phi0hat()} cannot drop out behind a depvar-missing or otherwise score-ineligible twin before same-fold cross-arm nuisance verification when that same-fold key still contributes a retained overlap row"
                di as error "  Reason: those rows share the same fold-external training sample, so every same-fold cross-arm twin on that broader retained-overlap candidate sample must carry the corresponding OOF outcome nuisances"
                exit 498
            }
            quietly bysort `_wgroup_w_raw_nf': egen double `_cross_phi1_raw_min_nf' = ///
                min(`phi1hat') if `_raw_fold_keep_nf' & ///
                (`pihat' >= 0.01 & `pihat' <= 0.99) & !missing(`phi1hat')
            quietly bysort `_wgroup_w_raw_nf': egen double `_cross_phi1_raw_max_nf' = ///
                max(`phi1hat') if `_raw_fold_keep_nf' & ///
                (`pihat' >= 0.01 & `pihat' <= 0.99) & !missing(`phi1hat')
            quietly bysort `_wgroup_w_raw_nf': egen double `_cross_phi0_raw_min_nf' = ///
                min(`phi0hat') if `_raw_fold_keep_nf' & ///
                (`pihat' >= 0.01 & `pihat' <= 0.99) & !missing(`phi0hat')
            quietly bysort `_wgroup_w_raw_nf': egen double `_cross_phi0_raw_max_nf' = ///
                max(`phi0hat') if `_raw_fold_keep_nf' & ///
                (`pihat' >= 0.01 & `pihat' <= 0.99) & !missing(`phi0hat')
            quietly gen byte `_cross_bad_phi_raw_nf' = ///
                (`_raw_fold_keep_nf' & !`_need_score_nf' & ///
                (`pihat' >= 0.01 & `pihat' <= 0.99) & ///
                !missing(`phi1hat') & !missing(`phi0hat') & ///
                `_have_t0_w_nf' > 0 & `_have_t1_w_nf' > 0 & ///
                `_cross_retain_count_nf' > 0 & ///
                (abs(`_cross_phi1_raw_max_nf' - `_cross_phi1_raw_min_nf') > `_hddid_nuis_eq_tol' | ///
                abs(`_cross_phi0_raw_max_nf' - `_cross_phi0_raw_min_nf') > `_hddid_nuis_eq_tol'))
            quietly count if `_cross_bad_phi_raw_nf'
            if r(N) > 0 {
                di as error "{bf:hddid}: same x()/z() key in the same outer fold has different supplied {bf:phi1hat()}/{bf:phi0hat()} across treatment arms"
                di as error "  {bf:phi1hat()} and {bf:phi0hat()} must agree across arms when shared {bf:W=(X,Z)} rows are evaluated in the same fold under {bf:nofirst}"
                di as error "  Missing {bf:depvar()} on one twin cannot hide a different legal supplied {bf:phi1hat()}/{bf:phi0hat()} on that broader same-fold retained-overlap candidate sample"
                di as error "  Reason: those rows share the same fold-external training sample, so their fold-aligned OOF outcome nuisance realizations cannot differ just because {bf:treat()} differs"
                exit 498
            }
        }
        capture drop `_raw_have_t0_nf' `_raw_have_t1_nf' `_have_t0_w_nf' `_have_t1_w_nf' `_cross_retain_count_nf' ///
            `_wgroup_w_raw_nf' `_cross_missing_pihat_raw_nf' ///
            `_cross_pihat_raw_min_nf' `_cross_pihat_raw_max_nf' ///
            `_cross_bad_pihat_raw_nf' ///
            `_cross_missing_phi_raw_nf' ///
            `_cross_phi1_raw_min_nf' `_cross_phi1_raw_max_nf' ///
            `_cross_phi0_raw_min_nf' `_cross_phi0_raw_max_nf' ///
            `_cross_bad_phi_raw_nf'

        // For same-fold cross-arm W=(X,Z) twins that remain on the retained
        // fold-pinning path, pihat() must agree on the actual retained outer
        // fold map stored in `_fold'. Once never-retained keys drop out of the
        // realized split, rows that separate into different retained folds no
        // longer share the same fold-external training sample and may carry
        // different valid OOF pihat() realizations across arms.
        quietly bysort `_wgroup_w_nf': egen long `_have_t0_w_nf' = ///
            total(`_fold_keep_nf' & `treat' == 0)
        quietly bysort `_wgroup_w_nf': egen long `_have_t1_w_nf' = ///
            total(`_fold_keep_nf' & `treat' == 1)
        quietly bysort `_wgroup_w_nf': egen long `_cross_retain_count_nf' = ///
            total(`_need_retained_nf')
        quietly bysort `_wgroup_w_nf': egen double `_cross_pihat_min_nf' = ///
            min(`pihat') if `_fold_keep_nf'
        quietly bysort `_wgroup_w_nf': egen double `_cross_pihat_max_nf' = ///
            max(`pihat') if `_fold_keep_nf'
        quietly gen byte `_cross_bad_pihat_nf' = ///
            (`_fold_keep_nf' & `_have_t0_w_nf' > 0 & `_have_t1_w_nf' > 0 & ///
            `_cross_retain_count_nf' > 0 & ///
            abs(`_cross_pihat_max_nf' - `_cross_pihat_min_nf') > `_hddid_nuis_eq_tol')
        quietly count if `_cross_bad_pihat_nf'
        if r(N) > 0 {
            di as error "{bf:hddid}: same x()/z() key in the same outer fold has different supplied {bf:pihat()} across treatment arms"
            di as error "  {bf:pihat()} must agree across arms when shared {bf:W=(X,Z)} rows are evaluated in the same fold under {bf:nofirst}"
            di as error "  A treatment-arm split-key group that never reaches the retained overlap sample cannot keep two shared {bf:W=(X,Z)} twins in the same retained estimator fold by itself"
            di as error "  Reason: those rows share the same fold-external training sample, so their fold-aligned OOF propensity realization cannot differ just because {bf:treat()} differs"
            exit 498
        }
        capture drop `_have_t0_w_nf' `_have_t1_w_nf' `_cross_retain_count_nf' ///
            `_cross_pihat_min_nf' `_cross_pihat_max_nf' `_cross_bad_pihat_nf'

        // pihat() still fixes overlap trimming through the broader
        // strict-interior pretrim fold-feasibility path, so unlike
        // phi1hat()/phi0hat() it must already agree on the common-score rows
        // whenever that split-key group contributes at least one retained
        // overlap row. But rows already excluded from the common
        // score sample by missing depvar()/phi*() cannot veto the run via a
        // numeric pihat() rewrite because they never enter the AIPW score.
        // Legal-but-extreme rows that remain on the common score sample are
        // still covered here when a twin on that key also survives into the
        // retained-overlap region, because they can still change trimming
        // without rebuilding the retained estimator folds.
        quietly bysort `_wgroup_nf': egen long `_dup_count_nf' = total(`_need_score_nf')
        quietly bysort `_wgroup_nf': egen double `_pihat_min_nf' = min(`pihat') if `_need_score_nf'
        quietly bysort `_wgroup_nf': egen double `_pihat_max_nf' = max(`pihat') if `_need_score_nf'
        quietly gen byte `_dup_bad_pihat_nf' = `_need_score_nf' & `_dup_count_nf' > 1 & ///
            `_retain_count_nf' > 0 & ///
            abs(`_pihat_max_nf' - `_pihat_min_nf') > `_hddid_nuis_eq_tol'
        quietly count if `_dup_bad_pihat_nf'
        if r(N) > 0 {
            di as error "{bf:hddid}: supplied {bf:pihat()} values disagree within a treatment-arm x()/z() key on the common-score sample used by {bf:nofirst}"
            di as error "  {bf:pihat()} must be fold-aligned out-of-fold on the broader strict-interior nofirst pretrim fold-feasibility sample used by {bf:nofirst}"
            di as error "  strict-interior rows still belong to the broader pretrim fold-feasibility logic, but a key that never reaches retained overlap does not, by itself, trigger this later common-score guard"
            di as error "  Rows already outside that common score sample because depvar()/phi1hat()/phi0hat() is missing do not trigger this guard by themselves"
            di as error "  Reason: within one treatment arm, duplicate evaluation rows with the same x()/z() key share the same outer fold and therefore must share the same OOF propensity realization"
            exit 498
        }
        capture drop `_dup_count_nf' `_strict_interior_count_nf' `_retain_count_nf' ///
            `_pihat_min_nf' `_pihat_max_nf' `_dup_bad_pihat_nf'
    }

    // Do not reclassify the outer split after the fold map is built. In
    // nofirst mode the paper's score sample can be narrower than the broader
    // fold-feasibility sample that pins pihat()'s OOF provenance, and after the
    // helper above succeeds `_fold_rank' is only bookkeeping for that already-
    // fixed split rather than a second feasibility oracle.

    tempname __hddid_tildex __hddid_covinv __hddid_MM __hddid_zbasispredict

    // The nonparametric object is posted only on the evaluation grid z0().
    // This grid does not define observation-level predictions.
    local _z0_was_omitted = 0
    if "`z0'" == "" {
        local _z0_was_omitted = 1
        qui levelsof `z' if `touse', local(z0)
        local qq : word count `z0'
    }
    else {
        local qq : word count `z0'
    }
    local z0_grid_full `z0'
    if `qq' == 0 {
        di as error "{bf:hddid}: no evaluation points for nonparametric function"
        di as error "  Specify z0() or ensure z variable has non-missing values"
        exit 198
    }
    if `qq' > 200 {
        di as text "{bf:hddid}: note: `qq' evaluation points detected"
        di as text "  Large number of evaluation points may slow computation"
        di as text "  Consider specifying z0() with a smaller grid of evaluation points"
    }

    forvalues _fk = 1/`k' {
        qui count if `_fold' == `_fk' & `touse'
        local _nk_fold = r(N)
        qui count if `_fold' == `_fk' & `treat' == 1 & `touse'
        local _n1_fold = r(N)
        qui count if `_fold' == `_fk' & `treat' == 0 & `touse'
        local _n0_fold = r(N)
        if "`nofirst'" == "" {
            if `_nk_fold' == 0 {
                di as error "{bf:hddid}: common score sample leaves outer evaluation fold `_fk' empty under the default first-stage path"
                di as error "  The paper's AIPW score is only formed on the common nonmissing score sample, so every realized outer fold must retain at least one such row"
                di as error "  Supply {bf:`depvar'} on at least one row in every realized outer fold, or reduce k()"
                exit 2000
            }
            qui count if ///
                ((`_propensity_foldvar' != `_fk') | ///
                `_default_prop_allfold_train') & ///
                `_propensity_touse' & `treat' == 1
            local _n1_train_ps = r(N)
            qui count if ///
                ((`_propensity_foldvar' != `_fk') | ///
                `_default_prop_allfold_train') & ///
                `_propensity_touse' & `treat' == 0
            local _n0_train_ps = r(N)
            local _n_train_ps = `_n1_train_ps' + `_n0_train_ps'
            // When W=(X,Z) is constant on the fold-external training sample
            // and both arms are present, the propensity nuisance collapses to
            // the treated share and should bypass the generic CV size guard.
            local _pre_prop_constant_w = (`_n1_train_ps' > 0 & `_n0_train_ps' > 0)
            foreach _pre_wvar of varlist `x' `z' {
                quietly summarize `_pre_wvar' if ///
                    ((`_propensity_foldvar' != `_fk') | ///
                    `_default_prop_allfold_train') & ///
                    `_propensity_touse', ///
                    meanonly
                if r(min) != r(max) {
                    local _pre_prop_constant_w = 0
                    continue, break
                }
            }
            if !`_pre_prop_constant_w' & ///
                (`_n1_train_ps' < `stage1_prop_min_class' | ///
                `_n0_train_ps' < `stage1_prop_min_class' | ///
                `_n_train_ps' < `stage1_prop_min_total') {
                di as error "{bf:hddid}: first-stage propensity training sample too small in fold `_fk'"
                di as error "  training observations: total=`_n_train_ps', treated=`_n1_train_ps', control=`_n0_train_ps'"
                di as error "  Current implementation uses cvlassologit, nfolds(`stage1_prop_nfolds') stratified"
                di as error "  which requires at least `stage1_prop_min_class' treated, `stage1_prop_min_class' control, and `stage1_prop_min_total' total training observations"
                exit 198
            }
        }
        if `_n1_fold' < 5 {
            di as text "{bf:hddid} warning: fold `_fk' has only `_n1_fold' treatment observations"
        }
        if `_n0_fold' < 5 {
            di as text "{bf:hddid} warning: fold `_fk' has only `_n0_fold' control observations"
        }
    }
    di as text ""
    di as text "{bf:hddid}: data preprocessing summary"
    quietly count if `treat' == 1 & `touse'
    local _n1_pretrim_disp = r(N)
    quietly count if `treat' == 0 & `touse'
    local _n0_pretrim_disp = r(N)
    local _n_pretrim_disp = `_n1_pretrim_disp' + `_n0_pretrim_disp'
    di as text "  Pretrim split sample: n = `_n_pretrim_disp' (treatment: `_n1_pretrim_disp', control: `_n0_pretrim_disp')"
    di as text "  Covariates:         p = `p'"
    di as text "  Evaluation points:  qq = `qq'"
    if "`nofirst'" == "" {
        di as text "  Cross-fitting:      k = `k' folds (contiguous current-row blocks on the score sample)"
        di as text "  Inner CV folds:     propensity=`stage1_prop_nfolds', outcome=`stage1_outcome_nfolds', second-stage=`stage2_nfolds', M-matrix=`mm_nfolds', CLIME<=`clime_nfolds_cv_requested'"
        di as text "  D/W-complete rows missing {bf:`depvar'} stay out of the common score sample and the fold-pinning outer split, but still widen the internal propensity path"
        di as text "  Those D/W-complete rows missing {bf:`depvar'} never become held-out evaluation rows, so they stay available to every fold-external default-path propensity training sample"
        di as text "  The published e(N_outer_split) therefore matches e(N_pretrim) on the same common score sample"
        di as text "  If the qualifier-defined and physically subsetted default-path runs hand hddid the same D/W-complete rows in the same order, they must therefore deliver the same retained-sample estimates."
        if `seed' < 0 {
            di as text "  Under omitted seed()/seed(-1), the realized fold map is a deterministic function of the current common-score row order."
        }
    }
    else {
        /*
        Legacy audit anchor kept only because older worker15 string-contract
        tests grep the source text instead of the executed runtime output:
        di as text "  Cross-fitting:      k = `k' folds (contiguous current-row blocks on the nofirst fold-pinning sample)"
        */
        di as text "  Cross-fitting:      k = `k' folds (contiguous current-row blocks on the nofirst fold-pinning sample)"
        di as text "  Inner CV folds:     second-stage=`stage2_nfolds', M-matrix=`mm_nfolds', CLIME<=`clime_nfolds_cv_requested'"
        if `seed' < 0 {
            di as text "  Under omitted seed()/seed(-1), the realized fold map is a deterministic function of the current nofirst fold-pinning row order."
        }
        di as text "{bf:hddid} note: nofirst expects fold-aligned out-of-fold nuisance inputs"
        di as text "  More precisely, pihat() must already be fold-aligned out-of-fold on the broader strict-interior nofirst pretrim fold-feasibility sample"
        di as text "  Under {bf:nofirst}, if/in qualifiers are applied before hddid rebuilds that broader strict-interior nofirst split path."
        di as text "  Running with if/in is therefore equivalent to physically subsetting those rows first: excluded rows do not continue to pin the outer split, retained estimator fold ids, or same-fold nuisance checks."
        di as text "  If the retained rows stay in the same order and the supplied fold-aligned nuisances are the same, the corresponding nofirst if/in run and physically subsetted run must return the same retained-sample estimates."
        di as text "  Legal-but-different or hidden-missing same-arm strict-interior pihat() twins are also checked on the broader strict-interior nofirst pretrim fold-feasibility path, not just on the later retained estimator sample, but only when that treatment-arm key still contributes at least one retained-overlap pretrim row"
        di as text "  Exact-boundary pihat() rows stay outside that broader strict-interior fold-feasibility split and do not pin retained outer fold IDs by themselves"
        di as text "  Any legal strict-interior 0<pihat()<1 row still enters that broader strict-interior fold-feasibility path before later overlap trimming, but only treatment-arm keys with at least one retained-overlap pretrim row pin the published retained outer fold IDs"
        di as text "  Retained rows then keep those already-assigned outer fold IDs on the narrower retained-overlap score sample"
        di as text "  Same-fold cross-arm retained nuisance checks stay on those fixed retained estimator fold IDs; trimming does not rebuild the outer split"
        di as text "  Same-fold cross-arm phi candidate checks also extend to depvar-missing or otherwise score-ineligible twins with pihat() still in [0.01,0.99] when shared W=(X,Z) rows stay on the same retained estimator fold IDs"
        di as text "  Same-arm phi duplicate-key checks also extend to depvar-missing twins with pihat() still in [0.01,0.99] when that treatment-arm key still contributes a retained overlap row"
        di as text "  phi1hat()/phi0hat() must already be fold-aligned out-of-fold on the retained overlap sample"
        quietly count if `treat' == 1 & `_outer_split_touse'
        local _n1_foldpin_disp = r(N)
        quietly count if `treat' == 0 & `_outer_split_touse'
        local _n0_foldpin_disp = r(N)
        local _n_foldpin_disp = `_n1_foldpin_disp' + `_n0_foldpin_disp'
        quietly count if ///
            (`_outer_split_touse' & !`touse') | ///
            (`touse' & !`_outer_split_touse')
        local _n_foldpin_membership_diff = r(N)
        if `_n_foldpin_disp' != `_n_pretrim_disp' | ///
            `_n_foldpin_membership_diff' > 0 {
            di as text "  Outer-fold fold-pinning sample: n = `_n_foldpin_disp' (treatment: `_n1_foldpin_disp', control: `_n0_foldpin_disp')"
        }
        if `_n_foldpin_disp' > `_n_pretrim_disp' {
            di as text "  Legal strict-interior pihat() rows excluded from the score by missing depvar(), phi1hat(), or phi0hat() can still keep e(N_outer_split) above e(N_pretrim), because the outer fold map is fixed before those later score-sample eligibility checks."
        }
        if `_n_foldpin_disp' < `_n_pretrim_disp' {
            di as text "  Legal strict-interior pihat() rows on treatment-arm keys that never contribute a retained-overlap pretrim row do not pin retained outer fold IDs, so e(N_pretrim) can exceed e(N_outer_split)."
        }
        if `_n_foldpin_disp' == `_n_pretrim_disp' & ///
            `_n_foldpin_membership_diff' > 0 {
            di as text "  e(N_outer_split)=e(N_pretrim) can still hide different fold-pinning membership because strict-interior rows can replace exact-boundary score rows one-for-one"
        }
        di as text "  Supplied nuisance provenance is not verified mechanically end-to-end; hddid checks arm-local split-key agreement and same-fold W=(X,Z) consistency only"
    }
    local _empty_score_fold ""
    if "`nofirst'" != "" {
        forvalues _fk = 1/`k' {
            quietly count if `_fold' == `_fk' & `_fold_keep_nf' & ///
                `pihat' >= 0.01 & `pihat' <= 0.99
            if r(N) > 0 {
                quietly count if `_fold' == `_fk' & `touse'
                if r(N) == 0 & `"`_empty_score_fold'"' == "" {
                    local _empty_score_fold `_fk'
                }
            }
        }
    }
    local _runtime_fold_label "Fold"
    local _runtime_fold_touse `touse'
    if "`nofirst'" != "" {
        if `_n_foldpin_disp' != `_n_pretrim_disp' | ///
            `_n_foldpin_membership_diff' > 0 {
            local _runtime_fold_label "Fold-pinning fold"
            local _runtime_fold_touse `_outer_split_touse'
        }
    }
    forvalues _fk = 1/`k' {
        qui count if `_fold' == `_fk' & `_runtime_fold_touse'
        local _nk = r(N)
        di as text "    `_runtime_fold_label' `_fk': `_nk' obs"
    }
    if `"`_empty_score_fold'"' != "" {
        if "`nofirst'" != "" {
            di as error "{bf:hddid}: common score sample leaves outer evaluation fold `_empty_score_fold' empty under {bf:nofirst}"
            di as error "  Broader nofirst fold-feasibility rows can still pin outer fold IDs, but the paper's AIPW score is only formed on the common nonmissing score sample"
            di as error "  This fold still contains broader nofirst rows with overlap-eligible {bf:pihat()} in [0.01, 0.99], so the empty score sample cannot be treated as a pure overlap-trimmed fold"
            di as error "  Supply depvar()/phi1hat()/phi0hat() on at least one row in every realized outer fold, or reduce k()"
            exit 2000
        }
    }
    if `seed' >= 0 {
        di as text "  Random seed:        `seed'"
    }
    if "`nofirst'" != "" {
        di as text "  Mode:               nofirst (user-supplied first-stage estimates)"
    }

    local method_lc = lower("`method'")
    local tri_zmin = .
    local tri_zmax = .
    if "`method_lc'" == "tri" {
        quietly summarize `z' if `touse', meanonly
        local tri_zmin = r(min)
        local tri_zmax = r(max)
        if `tri_zmax' <= `tri_zmin' {
            di as error "{bf:hddid}: method(Tri) requires z() to vary on the estimation sample so the support can be scaled to [0,1]"
            exit 498
        }
        if `_z0_was_omitted' == 0 {
            local _tri_z0_outside
            foreach _z0_val of local z0 {
                local _tri_z0_is_outside = (`_z0_val' < `tri_zmin')
                if `_tri_z0_is_outside' == 0 {
                    local _tri_z0_is_outside = (`_z0_val' > `tri_zmax')
                }
                if `_tri_z0_is_outside' {
                    local _tri_z0_outside `_tri_z0_outside' `_z0_val'
                }
            }
            if `"`_tri_z0_outside'"' != "" {
                di as error "{bf:hddid}: method(Tri) requires explicit z0() points to lie within the retained z() support"
                di as error "  Retained support: [`tri_zmin', `tri_zmax']"
                di as error "  Out-of-support z0() point(s):`_tri_z0_outside'"
                di as error "  Reason: the support-normalized trigonometric basis would otherwise alias periodic extrapolation points"
                exit 498
            }
        }
        if "`nofirst'" == "" {
            quietly summarize `z' if `_propensity_touse', meanonly
            local _tri_prop_zmin = r(min)
            local _tri_prop_zmax = r(max)
            if `_tri_prop_zmin' < `tri_zmin' | `_tri_prop_zmax' > `tri_zmax' {
                di as error "{bf:hddid}: default-path Tri propensity auxiliary rows extend z() beyond the common-score support"
                di as error "  Common-score support: [`tri_zmin', `tri_zmax']"
                di as error "  Propensity auxiliary support: [`_tri_prop_zmin', `_tri_prop_zmax']"
                di as error "  D/W-complete rows with missing {bf:`depvar'} can widen only the internal propensity sample, not the support-normalized {bf:method(Tri)} basis used on the common score sample"
                di as error "  Reason: feeding auxiliary-only rows outside that support into the default-path Tri nuisance stage would create periodic aliases unrelated to the paper's score sample"
                exit 498
            }
        }
    }
    
    // Materialize sieve terms as variables because the lasso steps work on the
    // observation sample, not on Mata-only matrix objects.
    forvalues j = 1/`q' {
        tempvar _zb_`j'
        quietly gen double `_zb_`j'' = .
    }

    // Keep the full Psi(Z) basis, including the constant, because the
    // projection step for tildex uses that full design.
    tempvar _zbf_0
    quietly gen double `_zbf_0' = .
    forvalues j = 1/`q' {
        tempvar _zbf_`j'
        quietly gen double `_zbf_`j'' = .
    }

    local zb_varlist ""
    forvalues j = 1/`q' {
        local zb_varlist `zb_varlist' `_zb_`j''
    }
    // Keep X first and the non-constant sieve terms after it so the Stage-2
    // coefficient partition matches the paper's partially linear form and the
    // current R reference implementation.
    local w_vars `x' `zb_varlist'
    local zbf_varlist `_zbf_0'
    forvalues j = 1/`q' {
        local zbf_varlist `zbf_varlist' `_zbf_`j''
    }
    local q_full = `q' + 1

    local _stage1_basis_touse `touse'
    if "`nofirst'" == "" {
        local _stage1_basis_touse `_propensity_touse'
    }
    mata: _hddid_store_sieve_basis("`z'", "`_stage1_basis_touse'", "`method_lc'", `q', ///
        "`zb_varlist'", "`zbf_varlist'", `tri_zmin', `tri_zmax')

    // lassologit's predict creates a new variable, so each fold predicts into a
    // temporary target and then copies results into the persistent storage var.
    tempvar _pihat
    quietly gen double `_pihat' = .

    tempvar _phi1hat _phi0hat _valid _rho _newy _esample_final
    quietly gen double `_phi1hat' = .
    quietly gen double `_phi0hat' = .
    quietly gen byte `_valid' = .
    quietly gen double `_rho' = .
    quietly gen double `_newy' = .

    local N_trimmed = 0
    if "`nofirst'" != "" {
        // Under nofirst, fixed pretrim fold IDs can include rows from groups
        // that later trim out entirely. Count trimming only inside the fold
        // loop so those rows are charged exactly once when their fold-level
        // overlap screen runs on the fixed estimator split.
        quietly replace `_valid' = 0 if `touse' & !`_fold_touse'
        // Exact-boundary pihat() rows never receive an outer fold id because
        // the nofirst fold-feasibility split is defined only on 0 < pihat < 1,
        // but those rows still leave the retained overlap sample and must be
        // charged to e(N_trimmed).
        quietly count if `touse' & !`_fold_touse' & missing(`_fold')
        local N_trimmed = r(N)
    }

    forvalues _k = 1/`k' {

        di as text "=== Fold `_k' / `k' ==="

        if "`nofirst'" == "" {
        local _propensity_train_if ///
            "((`_propensity_foldvar' != `_k') | `_default_prop_allfold_train') & `_propensity_touse'"
        quietly _hddid_sort_default_innercv, ///
            stage(propensity) ///
            foldrank(`_propensity_foldrank') ///
            treat(`treat') ///
            xvars(`x') ///
            zvar(`z') ///
            depvar(`depvar')
        quietly count if ///
            `_propensity_train_if' & `treat' == 1
        local _n1_train_ps = r(N)
        quietly count if ///
            `_propensity_train_if' & `treat' == 0
        local _n0_train_ps = r(N)
        local _n_train_ps = `_n1_train_ps' + `_n0_train_ps'
        local _ps_constant_w = 1
        foreach _wvar of local w_vars {
            quietly summarize `_wvar' if `_propensity_train_if', meanonly
            if r(min) != r(max) {
                local _ps_constant_w = 0
                continue, break
            }
        }
        local _ps_ncols = `p' + `q' + 1
        local _nz_count = 0
        local lambda_ps = .
        local _ps_hit_lmax = 0

        if `_ps_constant_w' {
            local _p_train = `_n1_train_ps' / `_n_train_ps'
            quietly replace `_pihat' = `_p_train' if `_propensity_foldvar' == `_k' & `_propensity_touse'
            di as text "{bf:hddid} note: fold `_k' propensity training covariates are constant"
            di as text "  Using intercept-only propensity model with training share P(D=1)=" %9.6f `_p_train'
        }
        else {
            capture _hddid_run_rng_isolated `seed' ///
                `_hddid_subcmd_prefix' cvlassologit `treat' `w_vars' if ///
                `_propensity_train_if', ///
                nfolds(`stage1_prop_nfolds') stratified
            if _rc != 0 {
                di as error "{bf:hddid}: cvlassologit failed in fold `_k' (rc=" _rc ")"
                di as error "  training observations: total=`_n_train_ps', treated=`_n1_train_ps', control=`_n0_train_ps'"
                exit _rc
            }

            local lambda_ps = e(lopt)
            local _ps_loptid = e(loptid)
            local _ps_lmax = e(lmax)
            local _ps_nlambda = e(lcount)
            quietly _hddid_resolve_prop_cv, ///
                fold(`_k') ///
                ntrain(`_n_train_ps') ///
                ntreat(`_n1_train_ps') ///
                ncontrol(`_n0_train_ps')
            local lambda_ps = r(lambda)
            local _ps_loptid = r(loptid)
            local _ps_lmax = r(lmax)
            local _ps_nlambda = r(nlambda)
            local _ps_missing_lopt = r(missing_lopt)
            local _ps_hit_lmax = (`_ps_loptid' == 1)
            local _ps_hit_lmin = (`_ps_nlambda' >= 1 & `_ps_loptid' == `_ps_nlambda')

            tempname _eb_propensity
            tempvar _pihat_tmp
            local _ps_lambda_hi = `lambda_ps' + max(`lambda_ps' * 0.1, 1e-8)

            if `_ps_missing_lopt' {
                capture _hddid_run_rng_isolated `seed' ///
                    `_hddid_subcmd_prefix' lassologit `treat' `w_vars' ///
                    if `_propensity_train_if', ///
                    lambda(`_ps_lambda_hi' `lambda_ps') noprogressbar
                if _rc != 0 {
                    di as error "{bf:hddid}: missing-lopt propensity fallback failed in fold `_k' (rc=" _rc ")"
                    di as error "  training observations: total=`_n_train_ps', treated=`_n1_train_ps', control=`_n0_train_ps'"
                    di as error "  cvlassologit returned missing {bf:e(lopt)} despite finite {bf:e(lmax)}=" %9.6f `_ps_lmax'
                    di as error "  Tried two-point {bf:lassologit} path at lambda = (" %9.6f `_ps_lambda_hi' ", " %9.6f `lambda_ps' ") to recover usable lasso coefficients for prediction"
                    exit _rc
                }
                tempname _eb_propensity_path
                matrix `_eb_propensity_path' = e(betas)
                local _ps_path_rows = rowsof(`_eb_propensity_path')
                local _ps_path_cols = colsof(`_eb_propensity_path')
                if `_ps_path_rows' < 2 | `_ps_path_cols' != `_ps_ncols' {
                    di as error "{bf:hddid}: missing-lopt propensity fallback returned an unexpected coefficient path in fold `_k'"
                    di as error "  Expected at least 2 x `=_ps_ncols'' coefficients, got `_ps_path_rows' x `_ps_path_cols'"
                    exit 498
                }
                matrix `_eb_propensity' = `_eb_propensity_path'[`_ps_path_rows', 1...]
                matrix colnames `_eb_propensity' = `w_vars' _cons
                tempvar _pihat_xb
                quietly matrix score double `_pihat_xb' = `_eb_propensity' if `_propensity_foldvar' == `_k' & `_propensity_touse'
                quietly gen double `_pihat_tmp' = invlogit(`_pihat_xb') if `_propensity_foldvar' == `_k' & `_propensity_touse'
                drop `_pihat_xb'
                di as text "{bf:hddid} note: fold `_k' recovered the propensity fit after cvlassologit omitted {bf:e(lopt)}"
                di as text "  Using recovered two-point lassologit predictions from the finite lambda boundary at " %9.6f `lambda_ps'
            }
            else if `_ps_hit_lmin' {
                // lassologit always runs a post-logit step for a single lambda.
                // When the CV optimum is the smallest lambda on the path, that
                // post-logit can late-crash under (near-)separation even though
                // the lasso coefficients themselves are usable for prediction.
                capture _hddid_run_rng_isolated `seed' ///
                    `_hddid_subcmd_prefix' lassologit `treat' `w_vars' ///
                    if `_propensity_train_if', ///
                    lambda(`_ps_lambda_hi' `lambda_ps') noprogressbar
                if _rc != 0 {
                    di as error "{bf:hddid}: lower-boundary propensity fallback failed in fold `_k' (rc=" _rc ")"
                    di as error "  training observations: total=`_n_train_ps', treated=`_n1_train_ps', control=`_n0_train_ps'"
                    di as error "  cv optimum: lopt=" %9.6f `lambda_ps' ", loptid=`_ps_loptid', grid size=`_ps_nlambda', lmax=" %9.6f `_ps_lmax'
                    di as error "  Tried two-point {bf:lassologit} path at lambda = (" %9.6f `_ps_lambda_hi' ", " %9.6f `lambda_ps' ") to bypass the single-lambda post-logit crash"
                    exit _rc
                }
                tempname _eb_propensity_path
                matrix `_eb_propensity_path' = e(betas)
                local _ps_path_rows = rowsof(`_eb_propensity_path')
                local _ps_path_cols = colsof(`_eb_propensity_path')
                if `_ps_path_rows' < 2 | `_ps_path_cols' != `_ps_ncols' {
                    di as error "{bf:hddid}: lower-boundary propensity fallback returned an unexpected coefficient path in fold `_k'"
                    di as error "  Expected at least 2 x `=_ps_ncols'' coefficients, got `_ps_path_rows' x `_ps_path_cols'"
                    exit 498
                }
                matrix `_eb_propensity' = `_eb_propensity_path'[`_ps_path_rows', 1...]
                matrix colnames `_eb_propensity' = `w_vars' _cons
                tempvar _pihat_xb
                quietly matrix score double `_pihat_xb' = `_eb_propensity' if `_propensity_foldvar' == `_k' & `_propensity_touse'
                quietly gen double `_pihat_tmp' = invlogit(`_pihat_xb') if `_propensity_foldvar' == `_k' & `_propensity_touse'
                drop `_pihat_xb'
                di as text "{bf:hddid} note: fold `_k' recovered the propensity fit after the CV optimum hit the lambda floor"
                di as text "  Using recovered lower-boundary lassologit predictions at lambda = " %9.6f `lambda_ps'
            }
            else {
                capture _hddid_run_rng_isolated `seed' ///
                    `_hddid_subcmd_prefix' cvlassologit, lopt postresults
                if _rc != 0 {
                    local _ps_post_rc = _rc
                    capture _hddid_run_rng_isolated `seed' ///
                        `_hddid_subcmd_prefix' lassologit `treat' `w_vars' ///
                        if `_propensity_train_if', ///
                        lambda(`_ps_lambda_hi' `lambda_ps') noprogressbar
                    if _rc != 0 {
                        di as error "{bf:hddid}: postresults recovery failed in fold `_k' (postresults rc=`_ps_post_rc', fallback rc=" _rc ")"
                        di as error "  training observations: total=`_n_train_ps', treated=`_n1_train_ps', control=`_n0_train_ps'"
                        di as error "  cv optimum: lopt=" %9.6f `lambda_ps' ", loptid=`_ps_loptid', lmax=" %9.6f `_ps_lmax'
                        di as error "  Tried two-point {bf:lassologit} path at lambda = (" %9.6f `_ps_lambda_hi' ", " %9.6f `lambda_ps' ") to recover usable lasso coefficients for prediction"
                        exit `_ps_post_rc'
                    }
                    tempname _eb_propensity_path
                    matrix `_eb_propensity_path' = e(betas)
                    local _ps_path_rows = rowsof(`_eb_propensity_path')
                    local _ps_path_cols = colsof(`_eb_propensity_path')
                    if `_ps_path_rows' < 2 | `_ps_path_cols' != `_ps_ncols' {
                        di as error "{bf:hddid}: postresults recovery returned an unexpected coefficient path in fold `_k'"
                        di as error "  Expected at least 2 x `=_ps_ncols'' coefficients, got `_ps_path_rows' x `_ps_path_cols'"
                        exit 498
                    }
                    matrix `_eb_propensity' = `_eb_propensity_path'[`_ps_path_rows', 1...]
                    matrix colnames `_eb_propensity' = `w_vars' _cons
                    tempvar _pihat_xb
                    quietly matrix score double `_pihat_xb' = `_eb_propensity' if `_propensity_foldvar' == `_k' & `_propensity_touse'
                    quietly gen double `_pihat_tmp' = invlogit(`_pihat_xb') if `_propensity_foldvar' == `_k' & `_propensity_touse'
                    drop `_pihat_xb'
                    di as text "{bf:hddid} note: fold `_k' recovered the propensity fit after {bf:cvlassologit, lopt postresults} failed"
                    di as text "  Using recovered two-point lassologit predictions at lambda = " %9.6f `lambda_ps'
                }
                else {
                    matrix `_eb_propensity' = e(beta)
                    local lambda_ps = e(lambda)

                    // lassologit's predict cannot overwrite an existing variable.
                    capture `_hddid_subcmd_prefix' predict double `_pihat_tmp', pr
                    if _rc != 0 {
                        di as error "{bf:hddid}: predict failed in fold `_k' (rc=" _rc ")"
                        di as error "  training observations: total=`_n_train_ps', treated=`_n1_train_ps', control=`_n0_train_ps'"
                        di as error "  cv optimum: lopt=" %9.6f `lambda_ps' ", loptid=`_ps_loptid', lmax=" %9.6f `_ps_lmax'
                        exit _rc
                    }
                }
            }
            quietly replace `_pihat' = `_pihat_tmp' if `_propensity_foldvar' == `_k' & `_propensity_touse'
            drop `_pihat_tmp'
        }

        if "`verbose'" != "" {
            if !`_ps_constant_w' & !`_ps_hit_lmax' {
                local _ps_ncols = colsof(`_eb_propensity')
                forvalues _j = 1/`_ps_ncols' {
                    if `_eb_propensity'[1, `_j'] != 0 {
                        local _nz_count = `_nz_count' + 1
                    }
                }
            }
            if `_ps_constant_w' {
                di as text "  Fold `_k': propensity score - intercept-only fallback (constant W), non-zero = 0/`_ps_ncols'"
            }
            else {
                di as text "  Fold `_k': propensity score - lambda = " %10.6f `lambda_ps' ", non-zero = `_nz_count'/`_ps_ncols'"
            }
        }

        }  // end if nofirst == ""
        else {
            // Under nofirst, the caller owns the fold-aligned first-stage inputs.
            quietly replace `_pihat' = `pihat' if `_fold' == `_k' & `_fold_touse'
            quietly replace `_phi1hat' = `phi1hat' if `_fold' == `_k' & `touse'
            quietly replace `_phi0hat' = `phi0hat' if `_fold' == `_k' & `touse'
        }

    // The paper's AIPW score is defined observation-wise on the common score
    // sample. Internally estimated pihat must therefore be present on every
    // such row before the overlap trim decides which rows remain retained.
        if "`nofirst'" == "" {
            quietly count if `_fold' == `_k' & `_pihat_domain_touse' & missing(`_pihat')
            if r(N) > 0 {
                di as error "{bf:hddid}: fold `_k' returned missing propensity score predictions before overlap trimming"
                di as error "  Reason: equations (2.5) and (3.1) require a realized propensity on every common-score row before the retained-sample AIPW score is formed"
                di as error "  Missing internally estimated {bf:pihat} is broken first-stage nuisance output, not an extreme-overlap row to trim away"
                exit 498
            }
        }

    // The DR score uses pihat * (1 - pihat) in the denominator, so each fold
    // must reject only probabilities outside [0,1] before overlap trimming.
    // Exact 0/1 values are legal inputs at this stage because the retained
    // overlap screen below will drop them before rho/newy are formed.
        quietly summarize `_pihat' if `_fold' == `_k' & `_pihat_domain_touse', meanonly
        local _n_pihat_domain = r(N)
        local _skip_pihat_domain_guard = 0
        if `_n_pihat_domain' == 0 {
            // In nofirst mode, a fold can contain only legal-but-trimmed rows
            // with missing depvar()/phi*(). Those rows never enter the AIPW
            // score, so the fold should fall through to the overlap-trim path.
            quietly summarize `_pihat' if `_fold' == `_k' & `_fold_touse', meanonly
            if r(N) == 0 {
                di as error "{bf:hddid}: no predictions in evaluation fold `_k'"
                exit 2000
            }
            local _skip_pihat_domain_guard = 1
        }
        local _pihat_min_fold = r(min)
        local _pihat_max_fold = r(max)
        if !`_skip_pihat_domain_guard' & ///
            (`_pihat_min_fold' < 0 | `_pihat_max_fold' > 1) {
            di as error "{bf:hddid}: propensity score outside [0,1] in fold `_k'"
            di as error "  min=" `_pihat_min_fold' ", max=" `_pihat_max_fold'
            di as error "  Exact 0/1 values are treated as overlap failures and trimmed before the AIPW score is formed"
            exit 498
        }
        if `_pihat_min_fold' == `_pihat_max_fold' {
            di as text "{bf:hddid} warning: propensity score is constant in fold `_k' (value=" `_pihat_min_fold' ")"
            di as text "  All Lasso coefficients may be zero"
        }
        if `_pihat_min_fold' < 0.001 | `_pihat_max_fold' > 0.999 {
            di as text "{bf:hddid} warning: extreme propensity scores in fold `_k'"
            di as text "  min=" %9.6f `_pihat_min_fold' ", max=" %9.6f `_pihat_max_fold'
            di as text "  Subsequent trimming will handle extreme values"
        }

        if "`nofirst'" == "" {
            quietly _hddid_sort_default_innercv, ///
                stage(outcome) ///
                foldrank(`_fold_rank') ///
                treat(`treat') ///
                xvars(`x') ///
                zvar(`z') ///
                depvar(`depvar')
            quietly count if `_fold' != `_k' & `treat' == 1 & `touse'
            local _n1_train_outcome = r(N)
            quietly count if `_fold' != `_k' & `treat' == 0 & `touse'
            local _n0_train_outcome = r(N)

            if `_n1_train_outcome' == 0 {
                di as error "{bf:hddid}: first-stage treated-outcome training sample is empty in fold `_k'"
                di as error "  Reason: equations (2.5) and (3.1) require a realized treated-arm outcome nuisance on the fold-external common score sample before the AIPW score is formed"
                di as error "  No treated common-score rows remain outside fold `_k'; provide more nonmissing treated {bf:`depvar'} rows, reduce k(), or use {bf:nofirst} with valid supplied outcome nuisances"
                exit 2000
            }

            if `_n0_train_outcome' == 0 {
                di as error "{bf:hddid}: first-stage control-outcome training sample is empty in fold `_k'"
                di as error "  Reason: equations (2.5) and (3.1) require a realized control-arm outcome nuisance on the fold-external common score sample before the AIPW score is formed"
                di as error "  No control common-score rows remain outside fold `_k'; provide more nonmissing control {bf:`depvar'} rows, reduce k(), or use {bf:nofirst} with valid supplied outcome nuisances"
                exit 2000
            }

            // For a constant arm-specific training outcome, cvlasso cannot
            // select a unique lopt. In that case the nuisance prediction is
            // just the fold-external sample mean. The same intercept-only
            // fallback is required when the fold-external W=(X,Z) design is
            // constant, because cvlasso then has no varying regressors and
            // late-fails with a raw constant-design error even though the
            // nuisance target is still well defined.
            quietly summarize `depvar' ///
                if `_fold' != `_k' & `treat' == 1 & `touse', meanonly
            local _phi1_mean = r(mean)
            local _phi1_constant_y = (r(min) == r(max))
            local _phi1_constant_w = 1
            foreach _wvar of local w_vars {
                quietly summarize `_wvar' ///
                    if `_fold' != `_k' & `treat' == 1 & `touse', meanonly
                if r(min) != r(max) {
                    local _phi1_constant_w = 0
                    continue, break
                }
            }
            if `_phi1_constant_y' | `_phi1_constant_w' {
                quietly replace `_phi1hat' = `_phi1_mean' if `_fold' == `_k' & `touse'
                if "`verbose'" != "" {
                    if `_phi1_constant_y' {
                        di as text "  Fold `_k': treated outcome is constant in training sample; using intercept-only prediction"
                    }
                    else {
                        di as text "  Fold `_k': treated outcome first-stage covariates are constant in training sample; using intercept-only prediction"
                    }
                }
            }
            else {
                if `_n1_train_outcome' < `outcome_min_total' {
                    di as error "{bf:hddid}: first-stage treated-outcome training sample too small in fold `_k'"
                    di as error "  training observations: treated=`_n1_train_outcome', required >= 3 for a non-constant outcome fit"
                    di as error "  Current {bf:cvlasso, nfolds(`stage1_outcome_nfolds') lopt} still needs at least `outcome_min_total' training observations before a non-constant treated-outcome fit is attempted"
                    di as error "  Direct Stata runtime evidence shows the non-constant path still runs at 3 rows but not at 2, so this guard uses that concrete boundary instead of a stricter per-fold heuristic"
                    di as error "  Increase sample size, reduce k(), or use nofirst with user-supplied first-stage outcomes"
                    exit 2000
                }
                capture _hddid_run_rng_isolated `seed' ///
                    `_hddid_subcmd_prefix' cvlasso `depvar' `w_vars' ///
                    if `_fold' != `_k' & `treat' == 1 & `touse', ///
                    nfolds(`stage1_outcome_nfolds') lopt
                if _rc != 0 {
                    di as error "{bf:hddid}: cvlasso (treated) " ///
                        "failed in fold `_k' (rc=" _rc ")"
                    exit _rc
                }
                tempvar _phi1hat_tmp
                predict double `_phi1hat_tmp'
                quietly replace `_phi1hat' = `_phi1hat_tmp' if `_fold' == `_k' & `touse'
                drop `_phi1hat_tmp'
            }

            quietly summarize `depvar' ///
                if `_fold' != `_k' & `treat' == 0 & `touse', meanonly
            local _phi0_mean = r(mean)
            local _phi0_constant_y = (r(min) == r(max))
            local _phi0_constant_w = 1
            foreach _wvar of local w_vars {
                quietly summarize `_wvar' ///
                    if `_fold' != `_k' & `treat' == 0 & `touse', meanonly
                if r(min) != r(max) {
                    local _phi0_constant_w = 0
                    continue, break
                }
            }
            if `_phi0_constant_y' | `_phi0_constant_w' {
                quietly replace `_phi0hat' = `_phi0_mean' if `_fold' == `_k' & `touse'
                if "`verbose'" != "" {
                    if `_phi0_constant_y' {
                        di as text "  Fold `_k': control outcome is constant in training sample; using intercept-only prediction"
                    }
                    else {
                        di as text "  Fold `_k': control outcome first-stage covariates are constant in training sample; using intercept-only prediction"
                    }
                }
            }
            else {
                if `_n0_train_outcome' < `outcome_min_total' {
                    di as error "{bf:hddid}: first-stage control-outcome training sample too small in fold `_k'"
                    di as error "  training observations: control=`_n0_train_outcome', required >= 3 for a non-constant outcome fit"
                    di as error "  Current {bf:cvlasso, nfolds(`stage1_outcome_nfolds') lopt} still needs at least `outcome_min_total' training observations before a non-constant control-outcome fit is attempted"
                    di as error "  Direct Stata runtime evidence shows the non-constant path still runs at 3 rows but not at 2, so this guard uses that concrete boundary instead of a stricter per-fold heuristic"
                    di as error "  Increase sample size, reduce k(), or use nofirst with user-supplied first-stage outcomes"
                    exit 2000
                }
                capture _hddid_run_rng_isolated `seed' ///
                    `_hddid_subcmd_prefix' cvlasso `depvar' `w_vars' ///
                    if `_fold' != `_k' & `treat' == 0 & `touse', ///
                    nfolds(`stage1_outcome_nfolds') lopt
                if _rc != 0 {
                    di as error "{bf:hddid}: cvlasso (control) " ///
                        "failed in fold `_k' (rc=" _rc ")"
                    exit _rc
                }
                tempvar _phi0hat_tmp
                predict double `_phi0hat_tmp'
                quietly replace `_phi0hat' = `_phi0hat_tmp' if `_fold' == `_k' & `touse'
                drop `_phi0hat_tmp'
            }
        }

        // The current implementation trims the second stage at [0.01, 0.99].
        quietly replace `_valid' = 1 if `_fold' == `_k' & `touse'
        quietly replace `_valid' = 0 if `_fold' == `_k' & `touse' & ///
            (`_pihat' > 0.99 | `_pihat' < 0.01)

        quietly count if `_fold' == `_k' & `touse' & `_valid' == 0
        local _n_trimmed = r(N)
        local N_trimmed = `N_trimmed' + `_n_trimmed'
        if `_n_trimmed' > 0 {
            quietly count if `_fold' == `_k' & `touse'
            local _n_eval = r(N)
            di as text "  Fold `_k': trimmed `_n_trimmed'/`_n_eval' " ///
                "observations (extreme propensity scores)"
        }

        // Guard the second-stage CV call after trimming because cvlasso still
        // needs enough retained evaluation observations to split into folds.
        // Once the fold-aligned AIPW nuisances are in hand, neither the paper
        // nor the R reference requires both treatment arms to remain inside
        // every retained evaluation fold.
        quietly count if `_fold' == `_k' & `touse' & `_valid' == 1
        local _n_valid = r(N)
        if `_n_valid' == 0 {
            di as error "{bf:hddid}: all observations trimmed in fold `_k' (n_valid=0)"
            di as error "  All propensity scores are outside [0.01, 0.99]"
            exit 2000
        }
        if "`nofirst'" == "" {
            quietly count if `_fold' == `_k' & `touse' & `_valid' == 1 & ///
                (missing(`_phi1hat') | missing(`_phi0hat'))
            if r(N) > 0 {
                di as error "{bf:hddid}: fold `_k' returned missing phi1hat()/phi0hat() predictions on retained overlap rows before AIPW score construction"
                di as error "  Reason: equations (2.5) and (3.1) require realized outcome nuisances on every retained row before the retained-sample AIPW score is formed"
                di as error "  Missing internally estimated {bf:phi1hat}/{bf:phi0hat} is broken first-stage nuisance output, not a late score-construction failure"
                exit 498
            }
        }
        // rho = (D - pihat) / (pihat * (1 - pihat))
        quietly replace `_rho' = . if `_fold' == `_k' & `touse'
        quietly replace `_rho' = ///
            (`treat' - `_pihat') / (`_pihat' * (1 - `_pihat')) ///
            if `_fold' == `_k' & `touse' & `_valid' == 1
        quietly count if `_fold' == `_k' & `touse' & `_valid' == 1 & ///
            missing(`_rho')
        if r(N) > 0 {
            di as error "{bf:hddid}: fold `_k' produced missing/nonfinite AIPW weights before the second-stage fit"
            di as error "  Reason: the paper's DR score uses rho_i = (D_i - pi_i) / (pi_i * (1 - pi_i)) on the retained evaluation sample"
            di as error "  Check supplied or estimated propensity scores for near-boundary overflow in this fold"
            exit 3351
        }

        // newy = rho * (deltay - (1-pihat)*phi1hat - pihat*phi0hat)
        quietly replace `_newy' = . if `_fold' == `_k' & `touse'
        quietly replace `_newy' = ///
            `_rho' * (`depvar' - (1 - `_pihat') * `_phi1hat' ///
                      - `_pihat' * `_phi0hat') ///
            if `_fold' == `_k' & `touse' & `_valid' == 1
        quietly count if `_fold' == `_k' & `touse' & `_valid' == 1 & ///
            missing(`_newy')
        if r(N) > 0 {
            di as error "{bf:hddid}: fold `_k' produced missing/nonfinite AIPW scores before the second-stage fit"
            di as error "  Reason: equation (3.1) requires a finite retained-sample score S_i = rho_i * (Delta Y_i - (1-pi_i)Phi_1i - pi_i Phi_0i)"
            di as error "  Check supplied or estimated nuisance values and outcome scale for overflow/underflow in this fold"
            exit 3351
        }

        // Record realized valid counts for the posted fold summary.
        local n_eval_`_k' = `_n_valid'

    }  // end first pass over folds

    local n_eval_max = 0
    forvalues _fk = 1/`k' {
        if `n_eval_`_fk'' > `n_eval_max' {
            local n_eval_max = `n_eval_`_fk''
        }
    }
    if `n_eval_max' > `matdim_limit' {
        di as error "{bf:hddid}: retained evaluation fold sample size n_valid=`n_eval_max' exceeds Stata matrix dimension limit `matdim_limit'"
        di as error "  Reason: the post-trim tildex matrix (n_valid x p) cannot be stored as a Stata matrix"
        di as error "  Current Stata flavor supports matrices up to `matdim_limit' x `matdim_limit'"
        di as error "  Please reduce sample size, increase k, or upgrade Stata edition"
        exit 908
    }

    if `N_trimmed' > 0 {
        di as text ""
        di as text "{bf:hddid}: total trimmed observations: `N_trimmed' / `n'"
    }

    // e(sample) should track the realized second-stage sample after trimming,
    // not the raw mark sample used at syntax-validation time.
    quietly gen byte `_esample_final' = (`touse' & `_valid' == 1)
    quietly count if `_esample_final'
    local N_final = r(N)
    if "`nofirst'" != "" {
        // Retained nofirst inputs must be fold-aligned OOF within each
        // treatment arm, and retained shared W=(X,Z) rows that sit in the
        // same fixed estimator fold across arms must still agree because
        // overlap trimming cannot retroactively change the fold-external
        // training sample that generated valid OOF nuisances.
        capture drop `_wgroup_w_nf'
        quietly egen long `_wgroup_w_nf' = ///
            group(`_fold' `x' `z') if `_esample_final'
        quietly bysort `_wgroup_w_nf': egen long `_have_t0_w_nf' = ///
            total(`_esample_final' & `treat' == 0)
        quietly bysort `_wgroup_w_nf': egen long `_have_t1_w_nf' = ///
            total(`_esample_final' & `treat' == 1)
        quietly bysort `_wgroup_w_nf': egen double `_cross_pihat_min_nf' = ///
            min(`pihat') if `_esample_final'
        quietly bysort `_wgroup_w_nf': egen double `_cross_pihat_max_nf' = ///
            max(`pihat') if `_esample_final'
        quietly bysort `_wgroup_w_nf': egen double `_phi1_min_nf' = ///
            min(`phi1hat') if `_esample_final'
        quietly bysort `_wgroup_w_nf': egen double `_phi1_max_nf' = ///
            max(`phi1hat') if `_esample_final'
        quietly bysort `_wgroup_w_nf': egen double `_phi0_min_nf' = ///
            min(`phi0hat') if `_esample_final'
        quietly bysort `_wgroup_w_nf': egen double `_phi0_max_nf' = ///
            max(`phi0hat') if `_esample_final'
        quietly gen byte `_cross_bad_nf' = ///
            (`_esample_final' & `_have_t0_w_nf' > 0 & `_have_t1_w_nf' > 0 & ///
            (abs(`_cross_pihat_max_nf' - `_cross_pihat_min_nf') > `_hddid_nuis_eq_tol' | ///
            abs(`_phi1_max_nf' - `_phi1_min_nf') > `_hddid_nuis_eq_tol' | ///
            abs(`_phi0_max_nf' - `_phi0_min_nf') > `_hddid_nuis_eq_tol'))
        quietly count if `_cross_bad_nf'
        if r(N) > 0 {
            di as error "{bf:hddid}: same x()/z() key in the same retained estimator fold has different supplied nuisance values across treatment arms"
            di as error "  Retained {bf:pihat()}, {bf:phi1hat()}, and {bf:phi0hat()} must agree across arms when shared {bf:W=(X,Z)} rows are evaluated in the same retained estimator fold under {bf:nofirst}"
            di as error "  Reason: those retained rows share the same fold-external training sample, so their fold-aligned OOF nuisance realizations cannot differ just because {bf:treat()} differs"
            exit 498
        }
        capture drop `_have_t0_w_nf' `_have_t1_w_nf' `_cross_pihat_min_nf' ///
            `_cross_pihat_max_nf' `_phi1_min_nf' `_phi1_max_nf' ///
            `_phi0_min_nf' `_phi0_max_nf' `_cross_bad_nf'

        quietly bysort `_wgroup_nf': egen long `_dup_count_nf' = total(`_esample_final')
        quietly bysort `_wgroup_nf': egen double `_pihat_min_nf' = min(`pihat') if `_esample_final'
        quietly bysort `_wgroup_nf': egen double `_pihat_max_nf' = max(`pihat') if `_esample_final'
        quietly bysort `_wgroup_nf': egen double `_phi1_min_nf' = min(`phi1hat') if `_esample_final'
        quietly bysort `_wgroup_nf': egen double `_phi1_max_nf' = max(`phi1hat') if `_esample_final'
        quietly bysort `_wgroup_nf': egen double `_phi0_min_nf' = min(`phi0hat') if `_esample_final'
        quietly bysort `_wgroup_nf': egen double `_phi0_max_nf' = max(`phi0hat') if `_esample_final'
        quietly gen byte `_dup_bad_nf' = `_esample_final' & `_dup_count_nf' > 1 & ///
            (abs(`_pihat_max_nf' - `_pihat_min_nf') > `_hddid_nuis_eq_tol' | ///
            abs(`_phi1_max_nf' - `_phi1_min_nf') > `_hddid_nuis_eq_tol' | ///
            abs(`_phi0_max_nf' - `_phi0_min_nf') > `_hddid_nuis_eq_tol')
        quietly count if `_dup_bad_nf'
        if r(N) > 0 {
            di as error "{bf:hddid}: supplied nuisance values disagree within a retained treatment-arm x()/z() key"
            di as error "  {bf:pihat()} must be fold-aligned out-of-fold on the broader strict-interior nofirst pretrim fold-feasibility sample, while {bf:phi1hat()} and {bf:phi0hat()} must be fold-aligned out-of-fold on the retained overlap sample"
            di as error "  Reason: within one treatment arm, duplicate retained rows with the same x()/z() key share the same evaluation fold; {bf:pihat()} provenance is fixed earlier on the broader strict-interior pretrim fold-feasibility path, and the retained-sample {bf:phi1hat()}/{bf:phi0hat()} realizations must also agree on that shared retained fold"
            exit 498
        }
    }
    if `N_trimmed' > 0 {
        quietly count if `_esample_final' & `treat' == 1
        local n1_final = r(N)
        quietly count if `_esample_final' & `treat' == 0
        local n0_final = r(N)
        di as text "{bf:hddid}: post-trim retained-sample summary"
        di as text "  Retained sample:    n = `N_final' (treatment: `n1_final', control: `n0_final')"
        forvalues _fk = 1/`k' {
            di as text "    Retained fold `_fk': `n_eval_`_fk'' obs"
        }
    }

    if "`method_lc'" == "tri" {
        quietly summarize `z' if `_esample_final', meanonly
        local _tri_zmin_post = r(min)
        local _tri_zmax_post = r(max)
        if `_tri_zmax_post' <= `_tri_zmin_post' {
            di as error "{bf:hddid}: method(Tri) requires z() to vary on the retained post-trim estimation sample so the support can be scaled to [0,1]"
            exit 498
        }
        local tri_zmin = `_tri_zmin_post'
        local tri_zmax = `_tri_zmax_post'
    }

    if "`method_lc'" == "tri" & `_z0_was_omitted' == 0 {
        local _tri_z0_outside_post
        foreach _z0_val of local z0 {
            local _tri_z0_is_outside_post = (`_z0_val' < `_tri_zmin_post')
            if `_tri_z0_is_outside_post' == 0 {
                local _tri_z0_is_outside_post = (`_z0_val' > `_tri_zmax_post')
            }
            if `_tri_z0_is_outside_post' {
                local _tri_z0_outside_post `_tri_z0_outside_post' `_z0_val'
            }
        }
        if `"`_tri_z0_outside_post'"' != "" {
            di as error "{bf:hddid}: method(Tri) requires explicit z0() points to lie within the retained post-trim z() support"
            di as error "  Retained post-trim support: [`_tri_zmin_post', `_tri_zmax_post']"
            di as error "  Out-of-support z0() point(s):`_tri_z0_outside_post'"
            di as error "  Reason: after overlap trimming, the trigonometric basis is only identified on the support that reaches the second-stage estimation path"
            exit 498
        }
    }

    local z0_list `z0_grid_full'
    if `_z0_was_omitted' {
        qui levelsof `z' if `_esample_final', local(_z0_posttrim)
        if `"`_z0_posttrim'"' == "" {
            di as error "{bf:hddid}: no retained support points remain for the default z0() grid after trimming"
            exit 2000
        }
        local z0_list `_z0_posttrim'
        local qq_posttrim : word count `z0_list'
        if `"`_z0_posttrim'"' != `"`z0_grid_full'"' {
            di as text "{bf:hddid}: omitted z0() updated after trimming to `qq_posttrim' retained support value(s) of `z'"
        }
        else {
            di as text "{bf:hddid}: z0() not specified, using `qq_posttrim' retained support value(s) of `z' as evaluation points"
        }
    }
    local qq : word count `z0_list'

    if "`method_lc'" == "tri" {
        // The Tri basis is defined on the affine image of the retained
        // estimation support. Rebuild the stored sieve terms after trimming so
        // trimmed-out z extremes cannot perturb second-stage/debiasing results.
        // Stage-1 cvlasso/cvlassologit can clear Mata symbols, so reload the
        // sidecar before rebuilding the retained-support Tri basis.
        capture `_hddid_subcmd_prefix' run "`_hddid_matalib'"
        if _rc != 0 {
            di as error "{bf:hddid}: failed to reload Mata helpers before rebuilding the retained-support Tri basis"
            di as error "  File found at: `_hddid_matalib'"
            di as error "  The post-trim second-stage design still needs {_hddid_store_sieve_basis()} after stage-1 lasso paths may have cleared Mata symbols"
            exit 198
        }
        mata: _hddid_store_sieve_basis("`z'", "`touse'", "`method_lc'", `q', ///
            "`zb_varlist'", "`zbf_varlist'", `tri_zmin', `tri_zmax')
    }

    // Keep the intercept in the z0 basis because stage-2 preparation still
    // estimates a separate a0 there, even though the public gdebias surface
    // later reports only the omitted-intercept z-varying block.
    // q()/z0() dimensions are constrained by Stata's hard matrix limit,
    // not by the user's current session matsize setting.
    local _ms_needed = max(`qq', `q_full')
    if `_ms_needed' > `matdim_limit' {
        di as error "{bf:hddid}: z0 prediction basis dimension " ///
            "(qq=`qq', q+1=`q_full') exceeds " ///
            "Stata matrix dimension limit " ///
            "(`matdim_limit')."
        exit 908
    }

    // Stage-1 cvlasso/cvlassologit can clear Mata symbols, so reload the
    // sidecar before posting the z0 basis used by stage-2 preparation.
    capture `_hddid_subcmd_prefix' run "`_hddid_matalib'"
    mata: _hddid_store_z0_basis("`z0_list'", "`method_lc'", `q', ///
        "`__hddid_zbasispredict'", `tri_zmin', `tri_zmax')

    // Fold IDs are fixed already; re-sort only to give stage-2/CLIME a
    // deterministic row order inside each evaluation fold. The primary key
    // must come from the retained design variables so a pure nuisance rewrite
    // that leaves the estimator's design problem unchanged cannot perturb
    // downstream CV through incidental row-order changes.
    // These remaining Stata lasso paths derive their inner validation folds from the current row order after this retained-fold sort.
    // `_newy' only breaks ties among otherwise identical design points inside
    // a fold.
    // [AUDIT FIX] Sorting by x within each fold created non-random inner CV
    // splits for cvlasso, biasing the stage-2 lambda selection. Use a random
    // sort within each fold instead, seeded for reproducibility.
    tempvar _rsort
    if `seed' >= 0 {
        local _rng_before `c(rngstate)'
        set seed `seed'
    }
    gen double `_rsort' = runiform()
    if `seed' >= 0 {
        set rngstate `_rng_before'
    }
    sort `_fold' `_valid' `_rsort'

    // Keep fold-level debiasing objects in Mata until all cross-fit folds
    // finish, then post the aggregated results once.
    mata: _hddid_init_folds(`k')

    tempvar _eval_s2
    quietly gen byte `_eval_s2' = 0
    forvalues _k = 1/`k' {

        quietly replace `_eval_s2' = (`_fold' == `_k' & `_valid' == 1 & `touse')
        local _n_valid = `n_eval_`_k''

        // Stage-1 cvlassologit/cvlasso can clear user Mata symbols; reload the
        // sidecar before the first post-stage-1 helper call in this fold.
        quietly run "`_hddid_matalib'"

        local _stage2_constant = 0
        quietly summarize `_newy' if `_eval_s2', meanonly
        if r(min) == r(max) {
            local _stage2_constant = 1
            local _stage2_level = r(mean)
            local clime_nfolds_cv_effective_`_k' = 0
            if "`verbose'" != "" {
                di as text "  Fold `_k': second-stage DR response is constant; storing the intercept-only constant-score shortcut"
            }
            mata: _hddid_store_constant_fold( ///
                strtoreal(st_local("_k")), ///
                strtoreal(st_local("p")), ///
                strtoreal(st_local("qq")), ///
                strtoreal(st_local("q_full")), ///
                strtoreal(st_local("_n_valid")), ///
                strtoreal(st_local("_stage2_level")))
            if "`verbose'" != "" {
                mata: printf("  Fold %g: constant-score shortcut stored intercept-only / zero-gamma debias objects at %g\n", ///
                    strtoreal(st_local("_k")), ///
                    strtoreal(st_local("_stage2_level")))
            }
            continue
        }

        if `p' > 1 & `_n_valid' < `mm_min_total' {
            di as error "{bf:hddid}: fold `_k' has too few valid observations for the M-matrix CV step"
            di as error "  n_valid=`_n_valid' but M-matrix cvlasso uses fixed nfolds(`mm_nfolds') when p=`p' > 1"
            di as error "  To avoid singleton validation folds, each M-matrix validation fold must contain at least `mm_min_eval_per_fold' observations"
            di as error "  This requires n_valid >= `mm_min_total' after trimming when the retained DR response is non-constant, or p=1 so the closed-form single-x projection path applies"
            di as error "  Constant retained DR responses are handled separately via the intercept-only constant-score shortcut"
            exit 2000
        }

        tempname __hddid_sieve_diag
        mata: st_matrix("`__hddid_sieve_diag'", ///
            _hddid_sieve_basis_diagnostics( ///
                st_data(., tokens(st_local("zbf_varlist")), st_local("_eval_s2"))))
        local _sieve_rank = el(`__hddid_sieve_diag', 1, 1)
        local _sieve_q1 = el(`__hddid_sieve_diag', 1, 2)
        local _sieve_singdirs = el(`__hddid_sieve_diag', 1, 4)

        if `_sieve_rank' < `_sieve_q1' {
            di as error "{bf:hddid}: fold `_k' has a rank-deficient sieve basis after trimming"
            di as error "  Basis rank=`_sieve_rank' < q+1=`_sieve_q1'; n_valid=`_n_valid', singular_dirs=`_sieve_singdirs'"
            di as error "  Reason: the paper's sieve projection requires a full-column-rank basis within each evaluation fold"
            di as error "  Hint: reduce q(), change method(), or ensure richer fold-level support in z()"
            exit 498
        }

        tempname _b_stage2
        if `_n_valid' < `stage2_min_total' {
            di as error "{bf:hddid}: propensity trimming left too few valid observations in fold `_k'"
            di as error "  n_valid=`_n_valid' but second-stage cvlasso uses fixed nfolds(`stage2_nfolds')"
            di as error "  To avoid singleton validation folds, each second-stage validation fold must contain at least `stage2_min_eval_per_fold' observations"
            di as error "  This requires n_valid >= `stage2_min_total' after trimming"
            di as error "  Constant retained DR responses are handled separately via the intercept-only fallback, but this fold is not constant"
            exit 2000
        }
        // The second stage leaves sieve terms unpenalized and penalizes only X,
        // matching the partially linear split used in the paper and R code.
        // Do not request cvlasso's lopt postresults here. When the
        // unpenalized sieve block is legitimately estimated at zero,
        // postresults can late-fail even though the CV run still leaves a
        // usable e(lopt) for the paper's stage-2 fit.
        capture _hddid_run_rng_isolated `seed' ///
            `_hddid_subcmd_prefix' cvlasso `_newy' `w_vars' if `_eval_s2', ///
            nfolds(`stage2_nfolds') notpen(`zb_varlist')
        local _stage2_cvlasso_rc = _rc
        capture `_hddid_subcmd_prefix' _hddid_cvlasso_pick_lambda, ///
            context("cvlasso (second-stage) in fold `_k'")
        local _stage2_lambda_rc = _rc
        if `_stage2_lambda_rc' != 0 {
            di as error "{bf:hddid}: cvlasso (second-stage) failed in fold `_k' (rc=" `_stage2_cvlasso_rc' ")"
            di as error "  n_valid=`_n_valid', p+q=`=`p'+`q''"
            exit cond(`_stage2_cvlasso_rc' != 0, `_stage2_cvlasso_rc', `_stage2_lambda_rc')
        }
        local lambda_opt = r(lambda)
        local _stage2_lambda_source "`r(source)'"
        if "`_stage2_lambda_source'" == "grid_last" & "`verbose'" != "" {
            di as text "  Fold `_k': second-stage has flat CV loss; using smallest lambda = " %10.6f `lambda_opt'
        }

        // Zero-valued unpenalized sieve coefficients are a legal stage-2
        // solution. Tighten tolzero() so lasso2 does not misclassify that case
        // as "unpenalized vars missing from selected vars".
        capture _hddid_run_rng_isolated `seed' ///
            `_hddid_subcmd_prefix' lasso2 `_newy' `w_vars' if `_eval_s2', ///
            lambda(`lambda_opt') notpen(`zb_varlist') postall tolzero(1e-20)
        if _rc != 0 {
            di as error "{bf:hddid}: lasso2 (second-stage) failed in fold `_k' (rc=" _rc ")"
            exit _rc
        }

        matrix `_b_stage2' = e(b)

        local _ncols_b = colsof(`_b_stage2')
        if `_ncols_b' != `p' + `q' + 1 {
            di as error "{bf:hddid}: unexpected e(b) dimension in fold `_k'"
            di as error "  Expected `=`p'+`q'+1' columns, got `_ncols_b'"
            exit 498
        }

        // The helper returns beta/gamma splits and the residual object used by
        // the debiasing step without leaving mutable Mata globals behind.
        tempname __hddid_betahat_p __hddid_gammahat_q __hddid_gammahat_full
        tempname __hddid_adjy __hddid_a0
        mata: _hddid_stage2_prepare( ///
            st_local("_b_stage2"), st_local("_newy"), st_local("w_vars"), ///
            st_local("_eval_s2"), strtoreal(st_local("p")), ///
            strtoreal(st_local("q")), st_local("__hddid_betahat_p"), ///
            st_local("__hddid_gammahat_q"), st_local("__hddid_gammahat_full"), ///
            st_local("__hddid_adjy"), st_local("__hddid_a0"))

        if "`verbose'" != "" {
            if !`_stage2_constant' {
                di as text "  Fold `_k': second-stage lambda = " %10.6f `lambda_opt'
            }
            mata: printf("  Fold %g: |betahat_p|_0 = %g, |gammahat_q| = %g, a0 = %g\n", ///
                strtoreal(st_local("_k")), ///
                sum(st_matrix(st_local("__hddid_betahat_p")) :!= 0), ///
                sum(st_matrix(st_local("__hddid_gammahat_q")) :!= 0), ///
                st_numscalar(st_local("__hddid_a0")))
        }

        // Estimate one projection row per full-basis term, including the
        // constant, using X-only regressions as in the debiasing step.
        tempname _MM_mat
        matrix `_MM_mat' = J(`q_full', `p', 0)

        forvalues _j = 0/`q' {
            if `_j' == 0 {
                local _m_target_var `_zbf_0'
            }
            else {
                local _m_target_var `_zb_`_j''
            }
            tempname _MM_row_`_j'
            if `p' == 1 {
                tempvar _mm_cross_`_j' _mm_sq_`_j'
                quietly gen double `_mm_cross_`_j'' = `_m_target_var' * `x' if `_eval_s2'
                quietly gen double `_mm_sq_`_j'' = (`x')^2 if `_eval_s2'
                quietly summarize `_mm_cross_`_j'' if `_eval_s2', meanonly
                local _mm_num = r(sum)
                quietly summarize `_mm_sq_`_j'' if `_eval_s2', meanonly
                local _mm_denom = r(sum)
                matrix `_MM_row_`_j'' = J(1, 1, 0)
                if `_mm_denom' > 0 {
                    matrix `_MM_row_`_j''[1, 1] = `_mm_num' / `_mm_denom'
                }
                if "`verbose'" != "" {
                    di as text "  Fold `_k': M-row j=`_j' uses closed-form single-x projection"
                }
                drop `_mm_cross_`_j'' `_mm_sq_`_j''
            }
            else {
                capture _hddid_run_rng_isolated `seed' ///
                    `_hddid_subcmd_prefix' cvlasso `_m_target_var' `x' if `_eval_s2', ///
                    nfolds(`mm_nfolds') nocons
                if _rc != 0 {
                    di as error "{bf:hddid}: cvlasso (M-matrix, j=`_j') failed in fold `_k' (rc=" _rc ")"
                    exit _rc
                }
                local _lambda_m = e(lopt)
                if missing(`_lambda_m') {
                    tempname _lambda_grid_`_j'
                    matrix `_lambda_grid_`_j'' = e(lambdamat)
                    local _lambda_last = rowsof(`_lambda_grid_`_j'')
                    if `_lambda_last' < 1 {
                        di as error "{bf:hddid}: cvlasso (M-matrix, j=`_j') returned an empty lambda grid in fold `_k'"
                        exit 498
                    }
                    local _lambda_m = el(`_lambda_grid_`_j'', `_lambda_last', 1)
                    if "`verbose'" != "" {
                        di as text "  Fold `_k': M-row j=`_j' has flat CV loss; using smallest lambda = " %10.6f `_lambda_m'
                    }
                }
                capture _hddid_run_rng_isolated `seed' ///
                    `_hddid_subcmd_prefix' lasso2 `_m_target_var' `x' if `_eval_s2', ///
                    nocons lambda(`_lambda_m')
                if _rc != 0 {
                    di as error "{bf:hddid}: lasso2 (M-matrix, j=`_j') failed in fold `_k' (rc=" _rc ")"
                    exit _rc
                }
                matrix `_MM_row_`_j'' = e(b)
            }
            local _mm_row = `_j' + 1
            matrix `_MM_mat'[`_mm_row', 1] = `_MM_row_`_j''
        }

        if rowsof(`_MM_mat') != `q_full' | colsof(`_MM_mat') != `p' {
            di as error "{bf:hddid}: M-matrix dimension mismatch in fold `_k'"
            di as error "  Expected `q_full' x `p', got " rowsof(`_MM_mat') " x " colsof(`_MM_mat')
            exit 498
        }

        if "`verbose'" != "" {
            di as text "  Fold `_k': M-matrix estimated (`q_full' x `p')"
        }

        // cvlasso/lasso2 can clear user Mata symbols; reload the sidecar before
        // calling compiled helpers again. Fold results already posted to Stata
        // matrices survive that reload.
        quietly run "`_hddid_matalib'"

        // tildex uses the full basis with the sieve constant in the projection.
        mata: st_matrix("`__hddid_tildex'", ///
            _hddid_compute_tildex( ///
                st_data(., tokens(st_local("x")), st_local("_eval_s2")), ///
                st_data(., tokens(st_local("zbf_varlist")), st_local("_eval_s2"))))
        mata: st_local("_hddid_absorbed_x", ///
            _hddid_absorbed_xvars( ///
                st_matrix("`__hddid_tildex'"), ///
                st_data(., tokens(st_local("x")), st_local("_eval_s2")), ///
                st_local("x")))
        if `"`_hddid_absorbed_x'"' != "" {
            di as error "{bf:hddid}: fold `_k' has x() columns fully absorbed by the retained sieve basis"
            di as error "  Absorbed x() variable(s): {bf:`_hddid_absorbed_x'}"
            di as error "  Reason: on that evaluation fold, those covariates lie exactly in the span of the full sieve basis used for {it:f(z)}, so the paper's X'beta + f(z) decomposition is not uniquely identified"
            di as error "  Drop the sieve-alias covariate, change q()/method(), or modify z()/x() so the parametric and nonparametric components are separately identified"
            exit 498
        }

        `_hddid_subcmd_prefix' _hddid_prepare_fold_covinv, ///
            p(`p') fold(`_k') tildex(`__hddid_tildex') covinv(`__hddid_covinv') ///
            seed(`seed') nvalid(`_n_valid') climemax(`clime_nfolds_cv_requested') ///
            climenlambda(`clime_nlambda_requested') ///
            climelambdaminratio(`clime_lambda_min_ratio') ///
            pyscript(`"`_hddid_pyscript'"') pymodule(`"`_hddid_py_module'"') ///
            pyhelper(`"`_hddid_py_clime_helper_present'"') ///
            pyhasverb(`"`_hddid_py_clime_hasverb'"') ///
            scipyvalidated(`_hddid_scipy_validated') ///
            subcmdprefix(`"`_hddid_subcmd_prefix'"') `verbose'
        local clime_nfolds_cv_effective_`_k' = r(clime_effective)
        local _hddid_scipy_validated = r(scipy_validated)
        // randomness follows the ambient Stata RNG stream.
        local _seed_for_boot = `seed'
        if `_seed_for_boot' < 0 local _seed_for_boot = .

        mata: _hddid_fold_debias_store( ///
            st_local("__hddid_covinv"), st_local("__hddid_tildex"), ///
            st_local("zbf_varlist"), st_local("x"), ///
            st_local("_eval_s2"), st_local("_MM_mat"), ///
            st_local("__hddid_zbasispredict"), st_local("__hddid_betahat_p"), ///
            st_local("__hddid_gammahat_full"), st_local("__hddid_adjy"), ///
            strtoreal(st_local("_k")), strtoreal(st_local("k")), ///
            strtoreal(st_local("_n_valid")), ///
            strtoreal(st_local("p")), strtoreal(st_local("q_full")), ///
            strtoreal(st_local("alpha")), ///
            strtoreal(st_local("nboot")), ///
            strtoreal(st_local("_seed_for_boot")))

        matrix __hddid_gammabar_`_k' = __hddid_gammabar_k
        scalar __hddid_a0_`_k' = __hddid_a0_k

        if "`verbose'" != "" {
            mata: printf("  Fold %g: debias done, nan_fallback = %g\n", ///
                strtoreal(st_local("_k")), ///
                st_numscalar("__hddid_nan_fallback_k"))
        }
    }

    // Aggregate the stored fold-level debiased outputs after the second pass.
    // When seed() is omitted, the aggregate Gaussian bootstrap must continue
    // from the caller's ambient RNG stream after any first-stage CV draws
    // already consumed inside the fold loop; rewinding here would make
    // different omitted-seed stochastic workloads share the same post-command
    // RNG state and bootstrap path.
    local _hddid_use_active_boot_seed = (`_seed_for_boot' >= 0)

    mata: _hddid_run_aggregate( ///
        strtoreal(st_local("k")), strtoreal(st_local("alpha")), ///
        st_local("__hddid_zbasispredict"), ///
        strtoreal(st_local("nboot")), ///
        strtoreal(st_local("_seed_for_boot")), ///
        strtoreal(st_local("_hddid_use_active_boot_seed")))

    tempname _b _V _xdebias _gdebias _stdx _stdg _tc _CIpoint _CIuniform
    mata: _hddid_post_results("`_b'", "`_V'", "`_xdebias'", "`_gdebias'", ///
        "`_stdx'", "`_stdg'", "`_tc'", "`_CIpoint'", "`_CIuniform'", `qq')

    // Aggregate gammabar and a0 across folds for predict support.
    tempname _agg_total_n
    scalar `_agg_total_n' = 0
    forvalues _agg_kk = 1/`k' {
        scalar `_agg_total_n' = scalar(`_agg_total_n') + ///
            scalar(__hddid_fold_n_valid_`_agg_kk')
    }
    scalar __hddid_final_a0 = 0
    forvalues _agg_kk = 1/`k' {
        tempname _agg_wk
        scalar `_agg_wk' = ///
            scalar(__hddid_fold_n_valid_`_agg_kk') / scalar(`_agg_total_n')
        if `_agg_kk' == 1 {
            matrix __hddid_final_gammabar = ///
                scalar(`_agg_wk') * __hddid_gammabar_`_agg_kk'
        }
        else {
            matrix __hddid_final_gammabar = __hddid_final_gammabar + ///
                scalar(`_agg_wk') * __hddid_gammabar_`_agg_kk'
        }
        scalar __hddid_final_a0 = scalar(__hddid_final_a0) + ///
            scalar(`_agg_wk') * scalar(__hddid_a0_`_agg_kk')
    }

    local _hddid_n_per_fold_list ""
    local _hddid_clime_eff_list ""
    forvalues _kk = 1/`k' {
        local _hddid_n_var "n_eval_`_kk'"
        local _hddid_clime_var "clime_nfolds_cv_effective_`_kk'"
        local _hddid_n_per_fold_item ``_hddid_n_var''
        local _hddid_clime_eff_item ``_hddid_clime_var''
        local _hddid_n_per_fold_list ///
            `"`_hddid_n_per_fold_list' `_hddid_n_per_fold_item'"'
        local _hddid_clime_eff_list ///
            `"`_hddid_clime_eff_list' `_hddid_clime_eff_item'"'
    }
    local _hddid_firststage_mode "internal"
    if "`nofirst'" != "" {
        local _hddid_firststage_mode "nofirst"
    }

    _hddid_publish_results, ///
        b(`_b') ///
        v(`_V') ///
        xdebias(`_xdebias') ///
        gdebias(`_gdebias') ///
        stdx(`_stdx') ///
        stdg(`_stdg') ///
        tc(`_tc') ///
        cipoint(`_CIpoint') ///
        ciuniform(`_CIuniform') ///
        esample(`_esample_final') ///
        nfinal(`N_final') ///
        npretrim(`n') ///
        nouter(`_n_foldsample') ///
        k(`k') ///
        p(`p') ///
        q(`q') ///
        qq(`qq') ///
        alpha(`alpha') ///
        nboot(`nboot') ///
        ntrimmed(`N_trimmed') ///
        secondstage(`stage2_nfolds') ///
        mmatrix(`mm_nfolds') ///
        climemax(`clime_nfolds_cv_requested') ///
        xvars(`x_user') ///
        zgrid(`z0_list') ///
        nperfold(`_hddid_n_per_fold_list') ///
        climeeff(`_hddid_clime_eff_list') ///
        method(`method') ///
        depvarrole(`depvar') ///
        treatvar(`treat') ///
        zvar(`z') ///
        cmdline(`"hddid `0'"') ///
        origorder(`_orig_order') ///
        firststage("`_hddid_firststage_mode'") ///
        predictstub("`_hddid_predict_prog'") ///
        propensity(`stage1_prop_nfolds') ///
        outcome(`stage1_outcome_nfolds') ///
        seed(`seed') ///
        zsupportmin(`tri_zmin') ///
        zsupportmax(`tri_zmax')

    quietly _hddid_load_display_sidecar, path("`_hddid_displaysidecar'")
    _hddid_display

end
