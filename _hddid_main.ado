capture program drop _hddid_probe_pkgdir_from_context
capture program drop _hddid_canonical_pkgdir
capture program drop _hddid_resolve_pkgdir
capture program drop _hddid_uncache_scipy
capture program drop _hddid_uncache_numpy
capture program drop _hddid_clime_scipy_probe
capture program drop _hddid_clime_feas_ok
capture program drop _hddid_cvlasso_pick_lambda
capture program drop _hddid_run_rng_isolated
capture program drop _hddid_resolve_prop_cv
capture program drop _hddid_count_split_groups
capture program drop _hddid_choose_outer_split_sample
capture program drop _hddid_default_outer_fold_map
capture program drop _hddid_sort_default_innercv
capture program drop _hddid_canonicalize_xvars
capture program drop _hddid_main
capture program drop _hddid_load_estimate_sidecar
capture program drop _hddid_load_display_sidecar
capture program drop _hddid_validate_predict_stub
capture program drop _hddid_validate_estat_stub
capture program drop _hddid_estimate
capture program drop _hddid_publish_results
capture program drop _hddid_cleanup_state
capture program drop _hddid_display
capture mata: mata drop _hddid_canonical_x_standardize()
capture mata: mata drop _hddid_canonical_x_order()
capture mata: mata drop _hddid_canonical_group_counts()
program define _hddid_main, eclass
    local _hddid_first_token ""
    gettoken _hddid_first_token _hddid_rest : 0, parse(" ,")
    local _hddid_first_token_lc = lower(strtrim(`"`_hddid_first_token'"'))
    local _hddid_input_trim = strtrim(`"`0'"')
    local _hddid_precomma `"`_hddid_input_trim'"'
    local _hddid_comma = strpos(`"`_hddid_input_trim'"', ",")
    if `_hddid_comma' > 0 {
        local _hddid_precomma = ///
            strtrim(substr(`"`_hddid_input_trim'"', 1, `_hddid_comma' - 1))
    }
    local _hddid_pos1 ""
    local _hddid_posrest ""
    gettoken _hddid_pos1 _hddid_posrest : _hddid_precomma
    local _hddid_pos2 ""
    if `"`_hddid_posrest'"' != "" {
        gettoken _hddid_pos2 _hddid_posrest2 : _hddid_posrest
    }
    local _hddid_posrest_trim = strtrim(`"`_hddid_posrest'"')
    local _hddid_pos1_lc = lower(strtrim(`"`_hddid_pos1'"'))
    local _hddid_pos2_lc = lower(strtrim(`"`_hddid_pos2'"'))
    local _hddid_posrest_lc = lower(`"`_hddid_posrest_trim'"')
    local _hddid_precomma_lc = lower(strtrim(`"`_hddid_precomma'"'))
    local _hddid_pos1_is_var 0
    local _hddid_pos2_is_var 0
    if `"`_hddid_pos1'"' != "" {
        capture confirm variable `_hddid_pos1'
        if _rc == 0 {
            local _hddid_pos1_is_var 1
        }
    }
    if `"`_hddid_pos2'"' != "" {
        capture confirm variable `_hddid_pos2'
        if _rc == 0 {
            local _hddid_pos2_is_var 1
        }
    }
    local _hddid_trailing_esttoken ""
    local _hddid_trailing_esttoken_raw ""
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
    local _hddid_bad_esttoken ""
    local _hddid_bad_esttoken_raw ""
    if `_hddid_comma' > 0 & !`_hddid_pos1_is_var' & ///
        `"`_hddid_pos2'"' == "" & ///
        `"`_hddid_trailing_esttoken'"' != "" {
        local _hddid_bad_esttoken `"`_hddid_trailing_esttoken'"'
        local _hddid_bad_esttoken_raw `"`_hddid_trailing_esttoken_raw'"'
    }
    else if `_hddid_pos1_is_var' & ///
        `"`_hddid_pos2'"' != "" & ///
        strtrim(`"`_hddid_posrest2'"') == "" & ///
        `"`_hddid_trailing_esttoken'"' != "" {
        local _hddid_bad_esttoken `"`_hddid_trailing_esttoken'"'
        local _hddid_bad_esttoken_raw `"`_hddid_trailing_esttoken_raw'"'
    }
    else if `_hddid_pos1_is_var' & ///
        regexm(`"`_hddid_posrest_lc'"', "^[(][ ]*(r|ra)[ ]*[)]$") {
        local _hddid_bad_esttoken "ra"
        local _hddid_bad_esttoken_raw `"`_hddid_posrest_trim'"'
    }
    else if `_hddid_pos1_is_var' & ///
        regexm(`"`_hddid_posrest_lc'"', "^[(][ ]*(i|ip|ipw)[ ]*[)]$") {
        local _hddid_bad_esttoken "ipw"
        local _hddid_bad_esttoken_raw `"`_hddid_posrest_trim'"'
    }
    else if `_hddid_pos1_is_var' & ///
        regexm(`"`_hddid_posrest_lc'"', "^[(][ ]*(a|ai|aip|aipw)[ ]*[)]$") {
        local _hddid_bad_esttoken "aipw"
        local _hddid_bad_esttoken_raw `"`_hddid_posrest_trim'"'
    }
    else if (`_hddid_pos1_is_var' | !`_hddid_pos2_is_var') & ///
        inlist(`"`_hddid_pos2_lc'"', "r", "ra") {
        local _hddid_bad_esttoken "ra"
        local _hddid_bad_esttoken_raw `"`_hddid_pos2'"'
    }
    else if (`_hddid_pos1_is_var' | !`_hddid_pos2_is_var') & ///
        inlist(`"`_hddid_pos2_lc'"', "i", "ip", "ipw") {
        local _hddid_bad_esttoken "ipw"
        local _hddid_bad_esttoken_raw `"`_hddid_pos2'"'
    }
    else if (`_hddid_pos1_is_var' | !`_hddid_pos2_is_var') & ///
        inlist(`"`_hddid_pos2_lc'"', "a", "ai", "aip", "aipw") {
        local _hddid_bad_esttoken "aipw"
        local _hddid_bad_esttoken_raw `"`_hddid_pos2'"'
    }
    else if regexm(`"`_hddid_precomma_lc'"', "^[(][ ]*(r|ra)[ ]*[)]$") {
        local _hddid_bad_esttoken "ra"
        local _hddid_bad_esttoken_raw `"`_hddid_precomma'"'
    }
    else if regexm(`"`_hddid_precomma_lc'"', "^[(][ ]*(i|ip|ipw)[ ]*[)]$") {
        local _hddid_bad_esttoken "ipw"
        local _hddid_bad_esttoken_raw `"`_hddid_precomma'"'
    }
    else if regexm(`"`_hddid_precomma_lc'"', "^[(][ ]*(a|ai|aip|aipw)[ ]*[)]$") {
        local _hddid_bad_esttoken "aipw"
        local _hddid_bad_esttoken_raw `"`_hddid_precomma'"'
    }
    else if replay() & ///
        inlist(`"`_hddid_pos1_lc'"', "r", "ra") {
        local _hddid_bad_esttoken "ra"
        local _hddid_bad_esttoken_raw `"`_hddid_pos1'"'
    }
    else if replay() & ///
        inlist(`"`_hddid_pos1_lc'"', "i", "ip", "ipw") {
        local _hddid_bad_esttoken "ipw"
        local _hddid_bad_esttoken_raw `"`_hddid_pos1'"'
    }
    else if replay() & ///
        inlist(`"`_hddid_pos1_lc'"', "a", "ai", "aip", "aipw") {
        local _hddid_bad_esttoken "aipw"
        local _hddid_bad_esttoken_raw `"`_hddid_pos1'"'
    }
    local _hddid_active_surface = (`"`e(cmd)'"' == "hddid")
    if `_hddid_active_surface' == 0 {
        local _hddid_depvar_probe = strtrim(`"`e(depvar)'"')
        local _hddid_depvar_role_probe = strtrim(`"`e(depvar_role)'"')
        local _hddid_treat_probe = strtrim(`"`e(treat)'"')
        local _hddid_xvars_probe = strtrim(`"`e(xvars)'"')
        local _hddid_zvar_probe = strtrim(`"`e(zvar)'"')
        local _hddid_method_probe = strtrim(`"`e(method)'"')
        local _hddid_cmdline_probe = strtrim(`"`e(cmdline)'"')
        local _hddid_cmdline_parse = `"`e(cmdline)'"'
        local _hddid_cmdline_lc = ""
        local _hddid_cmdline_depvar_probe = ""
        local _hddid_cmdline_opts = ""
        if `"`_hddid_cmdline_probe'"' != "" {
            local _hddid_cmdline_parse = ///
                subinstr(`"`_hddid_cmdline_parse'"', char(9), " ", .)
            local _hddid_cmdline_parse = ///
                subinstr(`"`_hddid_cmdline_parse'"', char(10), " ", .)
            local _hddid_cmdline_parse = ///
                subinstr(`"`_hddid_cmdline_parse'"', char(13), " ", .)
            local _hddid_cmdline_lc = lower(`"`_hddid_cmdline_parse'"')
            if regexm(`"`_hddid_cmdline_lc'"', "^[ ]*hddid[ ]+([^, ]+)") {
                local _hddid_cmdline_depvar_probe = strtrim(regexs(1))
            }
            if regexm(`"`_hddid_cmdline_lc'"', "^[ ]*hddid[^,]*,[ ]*(.*)$") {
                local _hddid_cmdline_opts = strtrim(regexs(1))
            }
        }
        if `"`_hddid_depvar_probe'"' == "" & ///
            `"`_hddid_depvar_role_probe'"' == "" & ///
            `"`_hddid_cmdline_depvar_probe'"' != "" {
            local _hddid_depvar_role_probe `"`_hddid_cmdline_depvar_probe'"'
        }
        if `"`_hddid_treat_probe'"' == "" & ///
            regexm(`"`_hddid_cmdline_opts'"', "(^|[ ,])tr(e(a(t)?)?)?[(]([^)]*)[)]") {
            local _hddid_treat_probe = strtrim(regexs(5))
        }
        if `"`_hddid_zvar_probe'"' == "" & ///
            regexm(`"`_hddid_cmdline_opts'"', "(^|[ ,])z[(]([^)]*)[)]") {
            local _hddid_zvar_probe = strtrim(regexs(2))
        }
        if `"`_hddid_method_probe'"' == "" & ///
            `"`_hddid_cmdline_opts'"' != "" {
            if regexm(`"`_hddid_cmdline_opts'"', "(^|[ ,])method[(]([^)]*)[)]") {
                local _hddid_cmdline_method_probe = strtrim(regexs(2))
                if inlist(lower(`"`_hddid_cmdline_method_probe'"'), "pol", "tri") {
                    local _hddid_method_probe = ///
                        strproper(strlower(`"`_hddid_cmdline_method_probe'"'))
                }
            }
            else {
                local _hddid_method_probe "Pol"
            }
        }
        if `"`_hddid_xvars_probe'"' == "" {
            capture confirm matrix e(b)
            if _rc == 0 {
                tempname _hddid_surface_b_probe
                matrix `_hddid_surface_b_probe' = e(b)
                local _hddid_xvars_probe : colnames `_hddid_surface_b_probe'
                local _hddid_xvars_probe : list retokenize _hddid_xvars_probe
            }
        }
        capture confirm scalar e(p)
        local _hddid_has_p = (_rc == 0)
        if `_hddid_has_p' == 0 {
            capture confirm matrix e(b)
            if _rc == 0 {
                tempname _hddid_surface_bdim_probe
                matrix `_hddid_surface_bdim_probe' = e(b)
                if colsof(`_hddid_surface_bdim_probe') >= 1 {
                    local _hddid_has_p 1
                }
            }
        }
        capture confirm scalar e(k)
        local _hddid_has_k = (_rc == 0)
        if `_hddid_has_k' == 0 {
            capture confirm matrix e(N_per_fold)
            if _rc == 0 {
                tempname _hddid_surface_npf_probe
                matrix `_hddid_surface_npf_probe' = e(N_per_fold)
                if rowsof(`_hddid_surface_npf_probe') == 1 & ///
                    colsof(`_hddid_surface_npf_probe') >= 2 {
                    local _hddid_has_k 1
                }
            }
        }
        capture confirm scalar e(q)
        local _hddid_has_q = (_rc == 0)
        if `_hddid_has_q' == 0 & `"`_hddid_cmdline_opts'"' != "" {
            if regexm(`"`_hddid_cmdline_opts'"', "(^|[ ,])q[(]([^)]*)[)]") {
                local _hddid_cmdline_q_probe = strtrim(regexs(2))
                if regexm(`"`_hddid_cmdline_q_probe'"', "^[+]?[0-9]+$") {
                    local _hddid_has_q = ///
                        (real(`"`_hddid_cmdline_q_probe'"') >= 1)
                }
            }
            else {
                local _hddid_has_q 1
            }
        }
        capture confirm scalar e(alpha)
        local _hddid_has_alpha = (_rc == 0)
        capture confirm scalar e(N)
        local _hddid_has_N = (_rc == 0)
        capture confirm scalar e(N_trimmed)
        local _hddid_has_N_trimmed = (_rc == 0)
        capture confirm matrix e(xdebias)
        local _hddid_has_xdebias = (_rc == 0)
        capture confirm matrix e(stdx)
        local _hddid_has_stdx = (_rc == 0)
        capture confirm matrix e(gdebias)
        local _hddid_has_gdebias = (_rc == 0)
        capture confirm matrix e(stdg)
        local _hddid_has_stdg = (_rc == 0)
        capture confirm matrix e(CIpoint)
        local _hddid_has_CIpoint = (_rc == 0)
        capture confirm matrix e(CIuniform)
        local _hddid_has_CIuniform = (_rc == 0)
        capture confirm matrix e(z0)
        local _hddid_has_z0 = (_rc == 0)
        // Bare replay should still classify a current surface as HDDID when
        // current role provenance remains recoverable from e(cmdline) or the
        // posted beta labels and only ancillary wrapper summaries such as
        // e(N_trimmed) or one role helper local are missing. If e(stdg) or
        // e(alpha) is malformed but CIpoint/CIuniform still advertise the
        // surrounding current nonparametric surface, _hddid_display should own
        // the HDDID-specific fail-closed guidance instead of generic rc301.
        if `_hddid_has_p' & `_hddid_has_k' & `_hddid_has_q' & ///
            `_hddid_has_N' & ///
            `_hddid_has_xdebias' & `_hddid_has_stdx' & ///
            `_hddid_has_gdebias' & ///
            (`_hddid_has_stdg' | `_hddid_has_CIpoint' | `_hddid_has_CIuniform') & ///
            `_hddid_has_z0' & ///
            `"`_hddid_treat_probe'"' != "" & `"`_hddid_xvars_probe'"' != "" & ///
            `"`_hddid_zvar_probe'"' != "" & `"`_hddid_method_probe'"' != "" & ///
            (`"`_hddid_depvar_probe'"' != "" | `"`_hddid_depvar_role_probe'"' != "") {
            local _hddid_active_surface 1
        }
    }
    if !`_hddid_active_surface' & replay() {
        error 301
    }
    if `"`_hddid_bad_esttoken'"' != "" {
        local _hddid_replaylike_esttoken = 0
        if !`_hddid_pos1_is_var' & ///
            (`_hddid_comma' > 0 | ///
            regexm(`"`_hddid_precomma_lc'"', ///
            "^[(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)]$")) {
            local _hddid_replaylike_esttoken = 1
        }
        if !`_hddid_active_surface' & `_hddid_replaylike_esttoken' {
            error 301
        }
        _hddid_show_esttoken `_hddid_bad_esttoken_raw'
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
        quietly _hddid_parse_estopt_rbridge, ///
            optsraw(`"`_hddid_precomma'"')
        if `"`r(invalid)'"' == "1" {
            _hddid_show_invalid_estopt, raw(`"`r(raw)'"')
            exit 198
        }
        if `"`r(canonical)'"' != "" & `"`r(form)'"' != "bare" {
            _hddid_show_esttoken `r(raw)'
            exit 198
        }
    }
    if `_hddid_comma' > 0 {
        local _hddid_postcomma = ///
            strtrim(substr(`"`_hddid_input_trim'"', `_hddid_comma' + 1, .))
        local _hddid_postcomma_lc = lower(`"`_hddid_postcomma'"')
        local _hddid_has_roleopt = ///
            regexm(`"`_hddid_postcomma_lc'"', "(^|[ ,])tr(e(a(t)?)?)?[(]") | ///
            regexm(`"`_hddid_postcomma_lc'"', "(^|[ ,])x[(]") | ///
            regexm(`"`_hddid_postcomma_lc'"', "(^|[ ,])z[(]")
        // With stored hddid results in memory, a single depvar plus unrelated
        // comma options is still replay misuse unless the caller is actually
        // supplying at least one structural role option for re-estimation.
        if `_hddid_active_surface' & !replay() & ///
            `_hddid_pos1_is_var' & `"`_hddid_pos2'"' == "" & ///
            !`_hddid_has_roleopt' {
            di as error "{bf:hddid}: replay does not accept positional arguments"
            di as error "  Reason: replay is display-only and must reuse the stored e() surface rather than reinterpret new depvar-like text"
            di as error "  Use bare {bf:hddid} for replay, or re-estimate with {bf:hddid depvar, treat(...) x(...) z(...)}"
            exit 198
        }
        quietly _hddid_parse_methodopt, ///
            optsraw(`"`_hddid_postcomma'"')
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
            // Keep the exact offending token for the follow-up echo, but show
            // a clean payload in the main "got ..." slot when assignment-form
            // method input preserved quotes/parentheses verbatim.
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
            optsraw(`"`_hddid_postcomma'"')
        if `"`r(invalid)'"' == "1" {
            // A bare depvar literally named "estimator" is legal in the
            // documented first positional slot. Only reject estimator-style
            // misuse when the precomma text is not exactly one existing
            // variable name.
            if !(`"`r(form)'"' == "bare" & `_hddid_pos1_is_var' & ///
                `"`_hddid_pos2'"' == "" & ///
                lower(strtrim(`"`r(raw)'"')) == ///
                lower(strtrim(`"`_hddid_pos1'"'))) {
                _hddid_show_invalid_estopt, raw(`"`r(raw)'"')
                exit 198
            }
        }
        if `"`r(canonical)'"' != "" & `"`r(form)'"' != "bare" {
            local _hddid_show_canonical `"`r(canonical)'"'
            local _hddid_show_raw `"`r(raw)'"'
            local _hddid_show_form `"`r(form)'"'
            _hddid_show_estopt_safe, ///
                canonical("`_hddid_show_canonical'") ///
                raw("`_hddid_show_raw'") ///
                form("`_hddid_show_form'")
            exit 198
        }
    }
    if `_hddid_comma' == 0 & `"`_hddid_precomma'"' != "" {
        quietly _hddid_parse_estopt_rbridge, ///
            optsraw(`"`_hddid_precomma'"')
        if `"`r(invalid)'"' == "1" {
            _hddid_show_invalid_estopt, raw(`"`r(raw)'"')
            exit 198
        }
        if `"`r(canonical)'"' != "" & `"`r(form)'"' != "bare" {
            _hddid_show_esttoken `r(raw)'
            exit 198
        }
    }

    if `_hddid_active_surface' & ///
        inlist(`"`_hddid_first_token_lc'"', "if", "in") {
        di as error "{bf:hddid}: replay does not accept if/in qualifiers"
        di as error "  Reason: replay is display-only and must reuse the stored retained sample behind e(b), e(V), and the published f(z0) objects"
        di as error "  To change the estimation sample, re-estimate on that subsample"
        exit 198
    }
    if `_hddid_active_surface' & ///
        substr(`"`_hddid_input_trim'"', 1, 1) == "[" {
        di as error "{bf:hddid}: replay does not accept weights"
        di as error "  Reason: replay is display-only and must reuse the stored retained sample and published HDDID target behind e(b), e(V), and f(z0)"
        di as error "  Replay is bare {bf:hddid} only; weighted syntax is not part of the published replay contract"
        exit 198
    }
    if `_hddid_active_surface' & ///
        !replay() & `_hddid_comma' == 0 & ///
        `"`_hddid_input_trim'"' != "" {
        di as error "{bf:hddid}: replay does not accept positional arguments"
        di as error "  Reason: replay is display-only and must reuse the stored e() surface rather than reinterpret new depvar-like text"
        di as error "  Use bare {bf:hddid} for replay, or re-estimate with {bf:hddid depvar, treat(...) x(...) z(...)}"
        exit 198
    }

    // Replay is display-only: it reads posted e() results and must not touch
    // estimation-side effects such as cross-fitting, sidecar loading, or RNG.
    if replay() {
        if !`_hddid_active_surface' {
            error 301
        }
        local _hddid_replay_comma = strpos(`"`_hddid_input_trim'"', ",")
        if `_hddid_replay_comma' > 0 {
            local _hddid_replay_opts_raw = ///
                strtrim(substr(`"`_hddid_input_trim'"', `_hddid_replay_comma' + 1, .))
            // Stata's syntax parser can mangle parenthesized bare tokens like
            // (ra) or ("ra") before helper option parsing sees them. Catch
            // those replay-only estimator-family spellings directly from the
            // raw command tail so they keep the same fixed-AIPW guidance as
            // bare ra/ipw/aipw misuse. The same malformed family switch can
            // also arrive with one redundant outer parenthesis layer, e.g.
            // ((ra)) or (("ra")), so preserve that exact raw token too
            // instead of degrading it to generic replay-option guidance.
            if regexm(`"`_hddid_replay_opts_raw'"', ///
                "(^|[ ])(([(][ ]*[(][ ]*([A-Za-z][A-Za-z0-9_]*)[ ]*[)][ ]*[)]))([ ]|$)") {
                local _hddid_replay_bad_raw = strtrim(regexs(2))
                local _hddid_replay_bad_est = lower(strtrim(regexs(4)))
                if inlist(`"`_hddid_replay_bad_est'"', "r", "ra") {
                    _hddid_show_estopt "ra" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "i", "ip", "ipw") {
                    _hddid_show_estopt "ipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "a", "ai", "aip", "aipw") {
                    _hddid_show_estopt "aipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
            }
            if regexm(`"`_hddid_replay_opts_raw'"', ///
                "(^|[ ])(([(][ ]*([A-Za-z][A-Za-z0-9_]*)[ ]*[)]))([ ]|$)") {
                local _hddid_replay_bad_raw = strtrim(regexs(2))
                local _hddid_replay_bad_est = lower(strtrim(regexs(4)))
                if inlist(`"`_hddid_replay_bad_est'"', "r", "ra") {
                    _hddid_show_estopt "ra" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "i", "ip", "ipw") {
                    _hddid_show_estopt "ipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "a", "ai", "aip", "aipw") {
                    _hddid_show_estopt "aipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
            }
            if regexm(`"`_hddid_replay_opts_raw'"', ///
                `"(^|[ ])(([(][ ]*[(][ ]*["]([^"]*)["][ ]*[)][ ]*[)]))([ ]|$)"') {
                local _hddid_replay_bad_raw = strtrim(regexs(2))
                local _hddid_replay_bad_est = lower(strtrim(regexs(4)))
                if inlist(`"`_hddid_replay_bad_est'"', "r", "ra") {
                    _hddid_show_estopt "ra" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "i", "ip", "ipw") {
                    _hddid_show_estopt "ipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "a", "ai", "aip", "aipw") {
                    _hddid_show_estopt "aipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
            }
            if regexm(`"`_hddid_replay_opts_raw'"', ///
                "(^|[ ])(([(][ ]*[(][ ]*'([^']*)'[ ]*[)][ ]*[)]))([ ]|$)") {
                local _hddid_replay_bad_raw = strtrim(regexs(2))
                local _hddid_replay_bad_est = lower(strtrim(regexs(4)))
                if inlist(`"`_hddid_replay_bad_est'"', "r", "ra") {
                    _hddid_show_estopt "ra" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "i", "ip", "ipw") {
                    _hddid_show_estopt "ipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "a", "ai", "aip", "aipw") {
                    _hddid_show_estopt "aipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
            }
            if regexm(`"`_hddid_replay_opts_raw'"', ///
                `"(^|[ ])(([(][ ]*["]([^"]*)["][ ]*[)]))([ ]|$)"') {
                local _hddid_replay_bad_raw = strtrim(regexs(2))
                local _hddid_replay_bad_est = lower(strtrim(regexs(4)))
                if inlist(`"`_hddid_replay_bad_est'"', "r", "ra") {
                    _hddid_show_estopt "ra" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "i", "ip", "ipw") {
                    _hddid_show_estopt "ipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "a", "ai", "aip", "aipw") {
                    _hddid_show_estopt "aipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
            }
            if regexm(`"`_hddid_replay_opts_raw'"', ///
                "(^|[ ])(([(][ ]*'([^']*)'[ ]*[)]))([ ]|$)") {
                local _hddid_replay_bad_raw = strtrim(regexs(2))
                local _hddid_replay_bad_est = lower(strtrim(regexs(4)))
                if inlist(`"`_hddid_replay_bad_est'"', "r", "ra") {
                    _hddid_show_estopt "ra" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "i", "ip", "ipw") {
                    _hddid_show_estopt "ipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
                if inlist(`"`_hddid_replay_bad_est'"', "a", "ai", "aip", "aipw") {
                    _hddid_show_estopt "aipw" `"`_hddid_replay_bad_raw'"' "parenthesized"
                    exit 198
                }
            }
            quietly _hddid_parse_estopt_rbridge, ///
                optsraw(`"`_hddid_replay_opts_raw'"')
            if `"`r(invalid)'"' == "1" {
                _hddid_show_invalid_estopt, raw(`"`r(raw)'"')
                exit 198
            }
            if `"`r(canonical)'"' != "" {
                local _hddid_replay_show_canonical `"`r(canonical)'"'
                local _hddid_replay_show_raw `"`r(raw)'"'
                local _hddid_replay_show_form `"`r(form)'"'
                _hddid_show_estopt_safe, ///
                    canonical("`_hddid_replay_show_canonical'") ///
                    raw("`_hddid_replay_show_raw'") ///
                    form("`_hddid_replay_show_form'")
                exit 198
            }
        }
        if `"`_hddid_input_trim'"' == "," {
            di as error "{bf:hddid}: replay does not accept a trailing comma"
            di as error "  Reason: replay is a bare display-only call over the stored e() surface"
            di as error "  Use bare {bf:hddid} with no comma, qualifiers, weights, or options"
            exit 198
        }
        syntax [, *]
        if `"`options'"' != "" {
            di as error "{bf:hddid}: replay does not accept options"
            di as error "  Reason: replay displays the published interval objects stored at estimation time"
            di as error "  To change the confidence level, re-estimate with {bf:alpha()}"
            exit 198
        }
        local _hddid_replay_bound_pkgdir `"$HDDID_SOURCE_RUN_PKGDIR"'
        if `"`_hddid_replay_bound_pkgdir'"' == "" {
            local _hddid_replay_bound_pkgdir `"$HDDID_WRAPPER_PKGDIR"'
        }
        quietly _hddid_resolve_pkgdir `"`_hddid_replay_bound_pkgdir'"' 0
        local _hddid_replay_pkgdir `"`r(pkgdir)'"'
        if `"`_hddid_replay_pkgdir'"' == "" {
            di as error "{bf:hddid}: replay cannot locate sibling display implementation {bf:_hddid_display.ado}"
            di as error "  Reason: replay is display-only, so it must source the exact display sidecar from the active hddid bundle instead of autoloading an arbitrary adopath copy"
            exit 198
        }
        quietly _hddid_load_display_sidecar, ///
            path(`"`_hddid_replay_pkgdir'/_hddid_display.ado"')
        _hddid_display
        exit
    }

    local _hddid_est_comma = strpos(`"`_hddid_input_trim'"', ",")
    if `_hddid_est_comma' > 0 {
        local _hddid_est_opts_raw = ///
            strtrim(substr(`"`_hddid_input_trim'"', `_hddid_est_comma' + 1, .))
        quietly _hddid_parse_estopt_rbridge, ///
            optsraw(`"`_hddid_est_opts_raw'"')
        if `"`r(invalid)'"' == "1" {
            _hddid_show_invalid_estopt, raw(`"`r(raw)'"')
            exit 198
        }
        if `"`r(canonical)'"' != "" {
            local _hddid_est_show_canonical `"`r(canonical)'"'
            local _hddid_est_show_raw `"`r(raw)'"'
            local _hddid_est_show_form `"`r(form)'"'
            _hddid_show_estopt_safe, ///
                canonical("`_hddid_est_show_canonical'") ///
                raw("`_hddid_est_show_raw'") ///
                form("`_hddid_est_show_form'")
            exit 198
        }
    }

    local _hddid_had_estimates 0
    tempname _hddid_hold_est
    if `"`e(cmd)'"' != "" {
        local _hddid_had_estimates 1
        quietly estimates store `_hddid_hold_est', copy
    }
    local _hddid_had_clime_nf 0
    local _hddid_had_clime_raw 0
    tempname _hddid_cnf_pr
    tempname _hddid_craw_pr
    capture confirm scalar __hddid_clime_effective_nfolds
    if _rc == 0 {
        scalar `_hddid_cnf_pr' = scalar(__hddid_clime_effective_nfolds)
        local _hddid_had_clime_nf 1
    }
    capture confirm scalar __hddid_clime_raw_feasible
    if _rc == 0 {
        scalar `_hddid_craw_pr' = scalar(__hddid_clime_raw_feasible)
        local _hddid_had_clime_raw 1
    }

    local _hddid_est_bound_pkgdir `"$HDDID_SOURCE_RUN_PKGDIR"'
    if `"`_hddid_est_bound_pkgdir'"' == "" {
        local _hddid_est_bound_pkgdir `"$HDDID_WRAPPER_PKGDIR"'
    }
    quietly _hddid_resolve_pkgdir `"`_hddid_est_bound_pkgdir'"' 0
    local _hddid_est_pkgdir `"`r(pkgdir)'"'
    if `"`_hddid_est_pkgdir'"' == "" {
        di as error "{bf:hddid}: cannot locate sibling estimation implementation {bf:_hddid_estimate.ado}"
        di as error "  Reason: command entry must source the exact estimation-sidecar contract from the active hddid bundle instead of autoloading an arbitrary adopath copy"
        exit 198
    }
    quietly _hddid_load_estimate_sidecar, ///
        path(`"`_hddid_est_pkgdir'/_hddid_estimate.ado"')

    local _hddid_rngstate_before
    local _hddid_failure_rngstate_before `c(rngstate)'
    capture noisily _hddid_estimate `0'
    local _hddid_rc = _rc
    if `_hddid_rc' != 0 {
        quietly set rngstate `_hddid_failure_rngstate_before'
    }
    else if `"`_hddid_rngstate_before'"' != "" {
        quietly set rngstate `_hddid_rngstate_before'
    }
    if `_hddid_rc' != 0 {
        quietly _hddid_cleanup_state
        if `_hddid_had_clime_nf' {
            capture scalar drop __hddid_clime_effective_nfolds
            scalar __hddid_clime_effective_nfolds = scalar(`_hddid_cnf_pr')
        }
        if `_hddid_had_clime_raw' {
            capture scalar drop __hddid_clime_raw_feasible
            scalar __hddid_clime_raw_feasible = scalar(`_hddid_craw_pr')
        }
        // Failed estimation should not clobber the caller's prior e() results.
        if `_hddid_had_estimates' {
            quietly estimates restore `_hddid_hold_est'
            capture estimates drop `_hddid_hold_est'
        }
        else {
            quietly ereturn clear
        }
        exit `_hddid_rc'
    }
    if `_hddid_had_estimates' {
        capture estimates drop `_hddid_hold_est'
    }
end

capture program drop _hddid_validate_predict_stub
capture program drop _hddid_validate_estat_stub
program define _hddid_probe_pkgdir_from_context, rclass
    version 16
    args explicit needpython

    return clear
    local _hddid_needpython 0
    if `"`needpython'"' != "" {
        capture confirm number `needpython'
        if _rc != 0 {
            di as error "{bf:hddid}: internal package-dir probe received a nonnumeric Python-sidecar contract"
            exit 198
        }
        local _hddid_needpython = real(`"`needpython'"')
        if missing(`_hddid_needpython') | ///
            `_hddid_needpython' != floor(`_hddid_needpython') | ///
            !inlist(`_hddid_needpython', 0, 1) {
            di as error "{bf:hddid}: internal package-dir probe requires needpython() equal to 0 or 1"
            exit 198
        }
    }

    // Probe upward from the current working tree because `run hddid.ado`
    // does not register sibling sidecars on adopath.
    local _probe_queue
    if `"`explicit'"' != "" {
        local _probe_queue `"`_probe_queue' `"`explicit'"'"'
    }

    local _cursor `"`c(pwd)'"'
    while `"`_cursor'"' != "" {
        local _probe_queue `"`_probe_queue' `"`_cursor'"' `"`_cursor'/hddid-stata'"'"'

        local _sep = strrpos(`"`_cursor'"', "/")
        if `_sep' == 0 {
            local _sep = strrpos(`"`_cursor'"', "\")
        }
        if `_sep' <= 1 {
            continue, break
        }
        local _cursor = substr(`"`_cursor'"', 1, `_sep' - 1)
    }

    foreach _candidate in `_probe_queue' {
        if `"`_candidate'"' == "" {
            continue
        }
        capture confirm file "`_candidate'/hddid.ado"
        if _rc != 0 {
            continue
        }
        capture confirm file "`_candidate'/_hddid_mata.ado"
        if _rc != 0 {
            continue
        }
        capture confirm file "`_candidate'/hddid_p.ado"
        if _rc != 0 {
            continue
        }
        capture confirm file "`_candidate'/hddid_estat.ado"
        if _rc != 0 {
            continue
        }
        capture confirm file "`_candidate'/_hddid_prepare_fold_covinv.ado"
        if _rc != 0 {
            continue
        }
        if `_hddid_needpython' == 1 {
            capture confirm file "`_candidate'/hddid_clime.py"
            if _rc != 0 {
                continue
            }
            capture confirm file "`_candidate'/hddid_safe_probe.py"
            if _rc != 0 {
                continue
            }
        }
        return local pkgdir `"`_candidate'"'
        exit
    }
end

program define _hddid_canonical_pkgdir, rclass
    version 16
    args candidate

    return clear
    if `"`candidate'"' == "" {
        return local pkgdir ""
        exit
    }

    local _pwd `"`c(pwd)'"'
    capture cd `"`candidate'"'
    if _rc != 0 {
        capture cd `"`_pwd'"'
        return local pkgdir ""
        exit
    }

    local _pkgdir `"`c(pwd)'"'
    capture cd `"`_pwd'"'
    return local pkgdir `"`_pkgdir'"'
end

program define _hddid_resolve_pkgdir, rclass
    version 16
    args explicit needpython

    return clear
    local _hddid_needpython 0
    if `"`needpython'"' != "" {
        capture confirm number `needpython'
        if _rc != 0 {
            di as error "{bf:hddid}: internal package-dir resolver received a nonnumeric Python-sidecar contract"
            exit 198
        }
        local _hddid_needpython = real(`"`needpython'"')
        if missing(`_hddid_needpython') | ///
            `_hddid_needpython' != floor(`_hddid_needpython') | ///
            !inlist(`_hddid_needpython', 0, 1) {
            di as error "{bf:hddid}: internal package-dir resolver requires needpython() equal to 0 or 1"
            exit 198
        }
    }

    // An explicit package directory passed via `run hddid.ado "<pkgdir>"`
    // must bind this source-loaded command to that exact sidecar bundle, even
    // if an older cached or adopath copy is also available.
    if `"`explicit'"' != "" {
        capture confirm file "`explicit'/hddid.ado"
        if _rc == 0 {
            capture confirm file "`explicit'/_hddid_mata.ado"
            if _rc == 0 {
                capture confirm file "`explicit'/hddid_p.ado"
                if _rc == 0 {
                    capture confirm file "`explicit'/hddid_estat.ado"
                    if _rc == 0 {
                        capture confirm file "`explicit'/_hddid_prepare_fold_covinv.ado"
                        if _rc == 0 {
                        if `_hddid_needpython' == 1 {
                            capture confirm file "`explicit'/hddid_clime.py"
                            if _rc == 0 {
                                capture confirm file "`explicit'/hddid_safe_probe.py"
                            }
                        }
                        if _rc == 0 {
                            quietly _hddid_canonical_pkgdir `"`explicit'"'
                            local _explicit_pkgdir `"`r(pkgdir)'"'
                            if `"`_explicit_pkgdir'"' != "" {
                                global HDDID_PACKAGE_DIR `"`_explicit_pkgdir'"'
                                return local pkgdir `"`_explicit_pkgdir'"'
                                exit
                            }
                        }
                        }
                    }
                }
            }
        }
        // When the explicit directory is the wrapper's auto-resolved adopath
        // entry (e.g. _/ from net install), it will not contain the full
        // co-located bundle. Fall through to findfile-based resolution instead
        // of failing closed.
    }

    // First prefer the command's currently discoverable bundle on adopath or
    // in the nearby source tree. A stale global cache must not override a
    // newly source-run or shadowed hddid.ado that already has its own sibling
    // sidecars available.
    //
    // An installed copy is acceptable only if the full sidecar bundle sits in
    // the same directory as hddid.ado.
    capture findfile hddid.ado
    if _rc == 0 {
        local _pkgmain "`r(fn)'"
        local _pkgsep = strrpos(`"`_pkgmain'"', "/")
        if `_pkgsep' == 0 {
            local _pkgsep = strrpos(`"`_pkgmain'"', "\")
        }
        if `_pkgsep' > 0 {
            local _pkgdir = substr(`"`_pkgmain'"', 1, `_pkgsep' - 1)
            capture confirm file "`_pkgdir'/_hddid_mata.ado"
            if _rc == 0 {
                capture confirm file "`_pkgdir'/hddid_p.ado"
                if _rc == 0 {
                    capture confirm file "`_pkgdir'/hddid_estat.ado"
                    if _rc == 0 {
                        capture confirm file "`_pkgdir'/_hddid_prepare_fold_covinv.ado"
                        if _rc == 0 {
                        if `_hddid_needpython' == 1 {
                            capture confirm file "`_pkgdir'/hddid_clime.py"
                            if _rc == 0 {
                                capture confirm file "`_pkgdir'/hddid_safe_probe.py"
                            }
                        }
                        if _rc == 0 {
                            quietly _hddid_canonical_pkgdir `"`_pkgdir'"'
                            local _resolved_pkgdir `"`r(pkgdir)'"'
                            if `"`_resolved_pkgdir'"' != "" {
                                global HDDID_PACKAGE_DIR `"`_resolved_pkgdir'"'
                                return local pkgdir `"`_resolved_pkgdir'"'
                                exit
                            }
                        }
                        }
                    }
                }
            }
        }
    }

    // Stata net install distributes files by first letter, so sidecars
    // starting with h/ and _/ end up in different directories. When the
    // co-located check above fails, fall back to findfile-based resolution
    // using the directory of _hddid_main.ado as the canonical pkgdir.
    capture findfile _hddid_main.ado
    if _rc == 0 {
        local _findfile_main "`r(fn)'"
        local _findfile_sep = strrpos(`"`_findfile_main'"', "/")
        if `_findfile_sep' == 0 {
            local _findfile_sep = strrpos(`"`_findfile_main'"', "\")
        }
        if `_findfile_sep' > 0 {
            local _findfile_dir = substr(`"`_findfile_main'"', 1, `_findfile_sep' - 1)
            local _findfile_ok 1
            foreach _findfile_sidecar in ///
                _hddid_mata.ado _hddid_estimate.ado ///
                _hddid_display.ado _hddid_prepare_fold_covinv.ado ///
                _hddid_pst_cmdroles.ado {
                capture confirm file "`_findfile_dir'/`_findfile_sidecar'"
                if _rc != 0 {
                    local _findfile_ok 0
                    continue, break
                }
            }
            if `_findfile_ok' {
                // For p>1 Python sidecars, check via findfile since they may
                // be in a separate py/ directory under the adopath root.
                local _findfile_py_ok 1
                if `_hddid_needpython' == 1 {
                    capture findfile hddid_clime.py
                    if _rc != 0 local _findfile_py_ok 0
                    capture findfile hddid_safe_probe.py
                    if _rc != 0 local _findfile_py_ok 0
                }
                if `_findfile_py_ok' {
                    quietly _hddid_canonical_pkgdir `"`_findfile_dir'"'
                    local _findfile_pkgdir `"`r(pkgdir)'"'
                    if `"`_findfile_pkgdir'"' != "" {
                        global HDDID_PACKAGE_DIR `"`_findfile_pkgdir'"'
                        return local pkgdir `"`_findfile_pkgdir'"'
                        exit
                    }
                }
            }
        }
    }

    quietly _hddid_probe_pkgdir_from_context `"`explicit'"' `_hddid_needpython'
    if `"`r(pkgdir)'"' != "" {
        quietly _hddid_canonical_pkgdir `"`r(pkgdir)'"'
        local _context_pkgdir `"`r(pkgdir)'"'
        if `"`_context_pkgdir'"' != "" {
            global HDDID_PACKAGE_DIR `"`_context_pkgdir'"'
            return local pkgdir `"`_context_pkgdir'"'
            exit
        }
    }

    // Reuse a previously validated package directory only as a final fallback
    // when neither the current adopath resolution nor the nearby workspace
    // context yields a complete sibling sidecar bundle.
    local _cached `"$HDDID_PACKAGE_DIR"'
    if `"`_cached'"' != "" {
        capture confirm file "`_cached'/hddid.ado"
        if _rc == 0 {
            capture confirm file "`_cached'/_hddid_mata.ado"
            if _rc == 0 {
                capture confirm file "`_cached'/hddid_p.ado"
                if _rc == 0 {
                    capture confirm file "`_cached'/hddid_estat.ado"
                    if _rc == 0 {
                        capture confirm file "`_cached'/_hddid_prepare_fold_covinv.ado"
                        if _rc == 0 {
                        if `_hddid_needpython' == 1 {
                            capture confirm file "`_cached'/hddid_clime.py"
                            if _rc == 0 {
                                capture confirm file "`_cached'/hddid_safe_probe.py"
                            }
                        }
                        if _rc == 0 {
                            return local pkgdir `"`_cached'"'
                            exit
                        }
                        }
                    }
                }
            }
        }
    }
end

program define _hddid_uncache_scipy
    version 16
    // The embedded Python session persists across Stata calls, so drop scipy
    // modules before dependency retries to avoid stale shadow imports pinned
    // in sys.modules.
    capture python: import importlib, sys; _mods = [m for m in list(sys.modules) if m == "scipy" or m.startswith("scipy.")]; _trash = [sys.modules.pop(m, None) for m in _mods]; importlib.invalidate_caches()
end

program define _hddid_uncache_numpy
    version 16
    // Clear cached numpy modules so version/path checks reflect the current
    // environment instead of an earlier shadow import or mutated session copy.
    capture python: import importlib, sys; _mods = [m for m in list(sys.modules) if m == "numpy" or m.startswith("numpy.")]; _trash = [sys.modules.pop(m, None) for m in _mods]; importlib.invalidate_caches()
end

program define _hddid_clime_scipy_probe, rclass
    version 16
    syntax , SCRIPT(string) MODULE(string) TILDEX(name)

    return clear
    local _hddid_clime_needs_scipy ""
    capture python: ///
        import inspect, pathlib, sys; ///
        import hashlib; ///
        import importlib.util; ///
        _module_path = pathlib.Path(r"`script'").resolve(); ///
        _module_name = r"`module'"; ///
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
        (_ for _ in ()).throw(ImportError(f"Cached module {_module_name} not available for {_module_path}")) if _module is None else None; ///
        _helper = getattr(_module, "hddid_clime_requires_scipy", None); ///
        _helper_call = getattr(_helper, "__call__", None) if _helper is not None else None; ///
        _helper_generator = bool(_helper is not None and callable(_helper) and (inspect.isgeneratorfunction(_helper) or (_helper_call is not None and inspect.isgeneratorfunction(_helper_call)))); ///
        _helper_asyncgen = bool(_helper is not None and (inspect.isasyncgenfunction(_helper) or (_helper_call is not None and inspect.isasyncgenfunction(_helper_call)))); ///
        _helper_async = bool(_helper is not None and (inspect.iscoroutinefunction(_helper) or (_helper_call is not None and inspect.iscoroutinefunction(_helper_call)) or _helper_asyncgen)); ///
        (_ for _ in ()).throw(AttributeError("hddid_clime_requires_scipy() helper missing")) if _helper is None else None; ///
        (_ for _ in ()).throw(TypeError("hddid_clime_requires_scipy() must be a synchronous callable, got generator function")) if (callable(_helper) and _helper_generator) else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must be a synchronous callable, got {'async generator function' if _helper_asyncgen else 'async function'}")) if (callable(_helper) and _helper_async) else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must be callable, got {type(_helper).__name__}")) if (not callable(_helper)) else None
    if _rc != 0 {
        exit _rc
    }
    capture python: ///
        from sfi import Macro; import functools, inspect, numpy as _np, pathlib, sys; ///
        import hashlib; ///
        import importlib.util; ///
        _module_path = pathlib.Path(r"`script'").resolve(); ///
        _module_name = r"`module'"; ///
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
        _helper_positional = []; ///
        _helper_kwargs = {"perturb": True}; ///
        exec("try:\n    _helper_sig_target = _helper\n    _prefer_object_sig = isinstance(_helper, functools.partial)\n    if _prefer_object_sig:\n        _helper_partial_func = _helper.func\n        _helper_partial_call = getattr(_helper_partial_func, \"__call__\", None)\n        if _helper_partial_call is not None and _helper_partial_call is not _helper_partial_func and not inspect.isclass(_helper_partial_func) and not (inspect.isfunction(_helper_partial_func) or inspect.ismethod(_helper_partial_func) or inspect.isbuiltin(_helper_partial_func) or inspect.isroutine(_helper_partial_func)):\n            try:\n                _helper_sig_target = functools.partial(_helper_partial_call, *(_helper.args or ()), **(_helper.keywords or {}))\n                _prefer_object_sig = False\n            except TypeError:\n                _helper_sig_target = _helper\n                _prefer_object_sig = True\n    if not _prefer_object_sig and _helper_call is not None and _helper_call is not _helper and not (inspect.isfunction(_helper) or inspect.ismethod(_helper) or inspect.isbuiltin(_helper) or inspect.isroutine(_helper)):\n        _helper_sig_target = _helper_call\n    _helper_sig = ((_module._resolve_bridge_signature(_helper)) or inspect.signature(_helper_sig_target, follow_wrapped=False)) if callable(getattr(_module, \"_resolve_bridge_signature\", None)) else inspect.signature(_helper_sig_target, follow_wrapped=False)\nexcept (TypeError, ValueError):\n    _helper_sig = None\nif _helper_sig is not None:\n    _helper_params = _helper_sig.parameters\n    _helper_has_var_pos = any(_p.kind == inspect.Parameter.VAR_POSITIONAL for _p in _helper_params.values())\n    _helper_has_var_kw = any(_p.kind == inspect.Parameter.VAR_KEYWORD for _p in _helper_params.values())\n    for _p in _helper_params.values():\n        if _p.kind == inspect.Parameter.POSITIONAL_ONLY and _p.name in _helper_kwargs:\n            _helper_positional.append(_helper_kwargs.pop(_p.name))\n    if _helper_has_var_pos and 'perturb' in _helper_kwargs:\n        _helper_positional.append(_helper_kwargs.pop('perturb'))\n    if 'perturb' in _helper_kwargs and not _helper_has_var_kw and 'perturb' not in _helper_params:\n        _helper_kwargs.pop('perturb')\n_raw_needs = _helper(r'`tildex'', *_helper_positional, **_helper_kwargs)"); ///
        _raw_needs_generator = bool(inspect.isgenerator(_raw_needs)); ///
        _raw_needs_asyncgen = bool(inspect.isasyncgen(_raw_needs)) if not _raw_needs_generator else False; ///
        _raw_needs_awaitable = bool(inspect.isawaitable(_raw_needs)) if not _raw_needs_generator and not _raw_needs_asyncgen else False; ///
        _raw_needs_close = getattr(_raw_needs, "close", None) if _raw_needs_generator else (getattr(_raw_needs, "aclose", None) if _raw_needs_asyncgen else (getattr(_raw_needs, "close", None) if _raw_needs_awaitable else None)); ///
        _raw_needs_close_ret = _raw_needs_close() if callable(_raw_needs_close) else None; ///
        _raw_needs_close_ret_close = getattr(_raw_needs_close_ret, "close", None) if _raw_needs_asyncgen else None; ///
        _raw_needs_close_ret_close() if callable(_raw_needs_close_ret_close) else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got generator {type(_raw_needs).__name__}")) if _raw_needs_generator else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got async generator {type(_raw_needs).__name__}")) if _raw_needs_asyncgen else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got awaitable {type(_raw_needs).__name__}")) if _raw_needs_awaitable else None; ///
        (_ for _ in ()).throw(TypeError("hddid_clime_requires_scipy() must return a bool")) if not isinstance(_raw_needs, (bool, _np.bool_)) else None; ///
        Macro.setLocal("_hddid_clime_needs_scipy", str(int(bool(_raw_needs))))
    if _rc != 0 {
        exit _rc
    }
    return local needs_scipy "`_hddid_clime_needs_scipy'"
end

program define _hddid_clime_feas_ok, rclass
    version 16
    args gap cap tol raw

    return clear

    local _raw_feasible 0
    if "`raw'" != "" {
        local _raw_feasible = `raw'
    }

    if missing(`gap') | missing(`cap') | missing(`tol') | missing(`_raw_feasible') {
        di as error "{bf:hddid}: CLIME published-feasibility helper received missing numeric input"
        exit 198
    }
    if `cap' < 0 | `tol' < 0 {
        di as error "{bf:hddid}: CLIME published-feasibility helper requires nonnegative cap() and tol()"
        exit 198
    }
    if `gap' < 0 {
        di as error "{bf:hddid}: CLIME published-feasibility helper requires a nonnegative gap()"
        exit 198
    }
    if `_raw_feasible' != floor(`_raw_feasible') | !inlist(`_raw_feasible', 0, 1) {
        di as error "{bf:hddid}: CLIME published-feasibility helper requires rawfeasible() to be 0 or 1"
        exit 198
    }

    if `_raw_feasible' == 1 {
        return scalar allowed = 1
        return scalar raw_feasible = 1
        return scalar relaxed_gap = `gap'
        return scalar cap = `cap'
        return scalar tol = `tol'
        exit
    }

    return scalar allowed = (`gap' <= `cap' + `tol')
    return scalar raw_feasible = 0
    return scalar relaxed_gap = `gap'
    return scalar cap = `cap'
    return scalar tol = `tol'
end

program define _hddid_probe_fail_classify, rclass
    version 16
    syntax , SCRIPT(string) MODULE(string) TILDEX(name)

    return clear
    local _hddid_probe_reason ""
    capture python: ///
        from sfi import Macro; import functools, inspect, numpy as _np, pathlib, sys; ///
        import hashlib; ///
        import importlib.util; ///
        _module_path = pathlib.Path(r"`script'").resolve(); ///
        _module_name = r"`module'"; ///
        _probe_name = "__hddid_probe__" + _module_name; ///
        _main_module = sys.modules.get(_module_name); ///
        _probe_module = sys.modules.get(_probe_name); ///
        _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
        _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
        _module = _main_module if _main_ok else (_probe_module if _probe_ok else (_main_module if _main_module is not None else _probe_module)); ///
        _source_hash = hashlib.sha1(_module_path.read_bytes()).hexdigest(); ///
        _cached_hash = getattr(_module, "_hddid_source_hash", None) if _module is not None else None; ///
        _cache_ok = (_main_ok or _probe_ok) and (_cached_hash == _source_hash); ///
        exec("if not _cache_ok:\n    _reload_spec = importlib.util.spec_from_file_location(_module_name, _module_path)\n    if _reload_spec is None or _reload_spec.loader is None:\n        raise ImportError(f'Unable to create import spec for {_module_path}')\n    _full_module = importlib.util.module_from_spec(_reload_spec)\n    exec(compile(_module_path.read_text(encoding='utf-8'), str(_module_path), 'exec'), _full_module.__dict__)\n    setattr(_full_module, '_hddid_safe_probe_only', 0)\n    setattr(_full_module, '_hddid_source_hash', _source_hash)\n    sys.modules[_module_name] = _full_module\n    sys.modules.pop(_probe_name, None)\n    _module = _full_module\n    _cache_ok = True") if _module is None or not _cache_ok else None; ///
        Macro.setLocal("_hddid_probe_reason", "cache_missing" if not _cache_ok else ""); ///
        _helper = None if not _cache_ok else getattr(_module, "hddid_clime_requires_scipy", None); ///
        _helper_call = getattr(_helper, "__call__", None) if _helper is not None else None; ///
        _helper_generator = bool(_helper is not None and callable(_helper) and (inspect.isgeneratorfunction(_helper) or (_helper_call is not None and inspect.isgeneratorfunction(_helper_call)))); ///
        _helper_asyncgen = bool(_helper is not None and (inspect.isasyncgenfunction(_helper) or (_helper_call is not None and inspect.isasyncgenfunction(_helper_call)))); ///
        _helper_async = bool(_helper is not None and (inspect.iscoroutinefunction(_helper) or (_helper_call is not None and inspect.iscoroutinefunction(_helper_call)) or _helper_asyncgen)); ///
        Macro.setLocal("_hddid_probe_reason", "helper_missing" if _cache_ok and _helper is None else Macro.getLocal("_hddid_probe_reason")); ///
        Macro.setLocal("_hddid_probe_reason", "helper_noncallable" if _cache_ok and _helper is not None and ((not callable(_helper)) or _helper_generator or _helper_async) else Macro.getLocal("_hddid_probe_reason")); ///
        _raw_needs = None; ///
        _helper_positional = []; ///
        _helper_kwargs = {"perturb": True}; ///
        exec("try:\n    _helper_sig_target = _helper\n    _prefer_object_sig = isinstance(_helper, functools.partial)\n    if _prefer_object_sig:\n        _helper_partial_func = _helper.func\n        _helper_partial_call = getattr(_helper_partial_func, \"__call__\", None)\n        if _helper_partial_call is not None and _helper_partial_call is not _helper_partial_func and not inspect.isclass(_helper_partial_func) and not (inspect.isfunction(_helper_partial_func) or inspect.ismethod(_helper_partial_func) or inspect.isbuiltin(_helper_partial_func) or inspect.isroutine(_helper_partial_func)):\n            try:\n                _helper_sig_target = functools.partial(_helper_partial_call, *(_helper.args or ()), **(_helper.keywords or {}))\n                _prefer_object_sig = False\n            except TypeError:\n                _helper_sig_target = _helper\n                _prefer_object_sig = True\n    if not _prefer_object_sig and _helper_call is not None and _helper_call is not _helper and not (inspect.isfunction(_helper) or inspect.ismethod(_helper) or inspect.isbuiltin(_helper) or inspect.isroutine(_helper)):\n        _helper_sig_target = _helper_call\n    _helper_sig = ((_module._resolve_bridge_signature(_helper)) or inspect.signature(_helper_sig_target, follow_wrapped=False)) if callable(getattr(_module, \"_resolve_bridge_signature\", None)) else inspect.signature(_helper_sig_target, follow_wrapped=False)\nexcept Exception:\n    pass\nelse:\n    _helper_params = _helper_sig.parameters\n    _helper_has_var_pos = any(_p.kind == inspect.Parameter.VAR_POSITIONAL for _p in _helper_params.values())\n    _helper_has_var_kw = any(_p.kind == inspect.Parameter.VAR_KEYWORD for _p in _helper_params.values())\n    for _p in _helper_params.values():\n        if _p.kind == inspect.Parameter.POSITIONAL_ONLY and _p.name in _helper_kwargs:\n            _helper_positional.append(_helper_kwargs.pop(_p.name))\n    if _helper_has_var_pos and 'perturb' in _helper_kwargs:\n        _helper_positional.append(_helper_kwargs.pop('perturb'))\n    if 'perturb' in _helper_kwargs and not _helper_has_var_kw and 'perturb' not in _helper_params:\n        _helper_kwargs.pop('perturb')") if Macro.getLocal("_hddid_probe_reason") == "" and callable(_helper) and not _helper_async else None; ///
        _probe_reason = Macro.getLocal("_hddid_probe_reason"); ///
        _raw_needs = _helper("`tildex'", *_helper_positional, **_helper_kwargs) if _probe_reason == "" else None; ///
        _raw_needs_generator = bool(inspect.isgenerator(_raw_needs)) if Macro.getLocal("_hddid_probe_reason") == "" else False; ///
        _raw_needs_asyncgen = bool(inspect.isasyncgen(_raw_needs)) if Macro.getLocal("_hddid_probe_reason") == "" and not _raw_needs_generator else False; ///
        _raw_needs_awaitable = bool(inspect.isawaitable(_raw_needs)) if Macro.getLocal("_hddid_probe_reason") == "" and not _raw_needs_generator and not _raw_needs_asyncgen else False; ///
        _raw_needs_close = getattr(_raw_needs, "close", None) if _raw_needs_generator else (getattr(_raw_needs, "aclose", None) if _raw_needs_asyncgen else (getattr(_raw_needs, "close", None) if _raw_needs_awaitable else None)); ///
        _raw_needs_close_ret = _raw_needs_close() if callable(_raw_needs_close) else None; ///
        _raw_needs_close_ret_close = getattr(_raw_needs_close_ret, "close", None) if _raw_needs_asyncgen else None; ///
        _raw_needs_close_ret_close() if callable(_raw_needs_close_ret_close) else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got generator {type(_raw_needs).__name__}")) if Macro.getLocal("_hddid_probe_reason") == "" and _raw_needs_generator else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got async generator {type(_raw_needs).__name__}")) if Macro.getLocal("_hddid_probe_reason") == "" and _raw_needs_asyncgen else None; ///
        (_ for _ in ()).throw(TypeError(f"hddid_clime_requires_scipy() must return synchronously, got awaitable {type(_raw_needs).__name__}")) if Macro.getLocal("_hddid_probe_reason") == "" and _raw_needs_awaitable else None; ///
        Macro.setLocal("_hddid_probe_reason", "helper_nonbool" if Macro.getLocal("_hddid_probe_reason") == "" and not isinstance(_raw_needs, (bool, _np.bool_)) else Macro.getLocal("_hddid_probe_reason")); ///
        Macro.setLocal("_hddid_probe_reason", "ok" if Macro.getLocal("_hddid_probe_reason") == "" else Macro.getLocal("_hddid_probe_reason"))
    if _rc != 0 {
        capture python: ///
            from sfi import Macro; import functools, inspect, numpy as _np, pathlib, sys; ///
            import hashlib; ///
            import importlib.util; ///
            _module_path = pathlib.Path(r"`script'").resolve(); ///
            _module_name = r"`module'"; ///
            _probe_name = "__hddid_probe__" + _module_name; ///
            _main_module = sys.modules.get(_module_name); ///
            _probe_module = sys.modules.get(_probe_name); ///
            _main_ok = _main_module is not None and pathlib.Path(str(getattr(_main_module, "__file__", ""))).resolve() == _module_path; ///
            _probe_ok = _probe_module is not None and pathlib.Path(str(getattr(_probe_module, "__file__", ""))).resolve() == _module_path; ///
            _module = _main_module if _main_ok else (_probe_module if _probe_ok else (_main_module if _main_module is not None else _probe_module)); ///
            _source_hash = hashlib.sha1(_module_path.read_bytes()).hexdigest(); ///
            _cached_hash = getattr(_module, "_hddid_source_hash", None) if _module is not None else None; ///
            _cache_ok = (_main_ok or _probe_ok) and (_cached_hash == _source_hash); ///
            exec("if not _cache_ok:\n    _reload_spec = importlib.util.spec_from_file_location(_module_name, _module_path)\n    if _reload_spec is None or _reload_spec.loader is None:\n        raise ImportError(f'Unable to create import spec for {_module_path}')\n    _full_module = importlib.util.module_from_spec(_reload_spec)\n    exec(compile(_module_path.read_text(encoding='utf-8'), str(_module_path), 'exec'), _full_module.__dict__)\n    setattr(_full_module, '_hddid_safe_probe_only', 0)\n    setattr(_full_module, '_hddid_source_hash', _source_hash)\n    sys.modules[_module_name] = _full_module\n    sys.modules.pop(_probe_name, None)\n    _module = _full_module\n    _cache_ok = True") if _module is None or not _cache_ok else None; ///
            Macro.setLocal("_hddid_probe_reason", "cache_missing" if not _cache_ok else ""); ///
            _helper = None if not _cache_ok else getattr(_module, "hddid_clime_requires_scipy", None); ///
            _helper_call = getattr(_helper, "__call__", None) if _helper is not None else None; ///
            _helper_generator = bool(_helper is not None and callable(_helper) and (inspect.isgeneratorfunction(_helper) or (_helper_call is not None and inspect.isgeneratorfunction(_helper_call)))); ///
            _helper_asyncgen = bool(_helper is not None and (inspect.isasyncgenfunction(_helper) or (_helper_call is not None and inspect.isasyncgenfunction(_helper_call)))); ///
            _helper_async = bool(_helper is not None and (inspect.iscoroutinefunction(_helper) or (_helper_call is not None and inspect.iscoroutinefunction(_helper_call)) or _helper_asyncgen)); ///
            Macro.setLocal("_hddid_probe_reason", "helper_missing" if _cache_ok and _helper is None else Macro.getLocal("_hddid_probe_reason")); ///
            Macro.setLocal("_hddid_probe_reason", "helper_noncallable" if _cache_ok and _helper is not None and ((not callable(_helper)) or _helper_generator or _helper_async) else Macro.getLocal("_hddid_probe_reason")); ///
            exec("try:\n    _helper_positional = []\n    _helper_kwargs = {'perturb': True}\n    _helper_sig_target = _helper\n    _prefer_object_sig = isinstance(_helper, functools.partial)\n    if _prefer_object_sig:\n        _helper_partial_func = _helper.func\n        _helper_partial_call = getattr(_helper_partial_func, \"__call__\", None)\n        if _helper_partial_call is not None and _helper_partial_call is not _helper_partial_func and not inspect.isclass(_helper_partial_func) and not (inspect.isfunction(_helper_partial_func) or inspect.ismethod(_helper_partial_func) or inspect.isbuiltin(_helper_partial_func) or inspect.isroutine(_helper_partial_func)):\n            try:\n                _helper_sig_target = functools.partial(_helper_partial_call, *(_helper.args or ()), **(_helper.keywords or {}))\n                _prefer_object_sig = False\n            except TypeError:\n                _helper_sig_target = _helper\n                _prefer_object_sig = True\n    if not _prefer_object_sig and _helper_call is not None and _helper_call is not _helper and not (inspect.isfunction(_helper) or inspect.ismethod(_helper) or inspect.isbuiltin(_helper) or inspect.isroutine(_helper)):\n        _helper_sig_target = _helper_call\n    try:\n        _helper_sig = ((_module._resolve_bridge_signature(_helper)) or inspect.signature(_helper_sig_target, follow_wrapped=False)) if callable(getattr(_module, \"_resolve_bridge_signature\", None)) else inspect.signature(_helper_sig_target, follow_wrapped=False)\n    except Exception:\n        pass\n    else:\n        _helper_params = _helper_sig.parameters\n        _helper_has_var_pos = any(_p.kind == inspect.Parameter.VAR_POSITIONAL for _p in _helper_params.values())\n        _helper_has_var_kw = any(_p.kind == inspect.Parameter.VAR_KEYWORD for _p in _helper_params.values())\n        for _p in _helper_params.values():\n            if _p.kind == inspect.Parameter.POSITIONAL_ONLY and _p.name in _helper_kwargs:\n                _helper_positional.append(_helper_kwargs.pop(_p.name))\n        if _helper_has_var_pos and 'perturb' in _helper_kwargs:\n            _helper_positional.append(_helper_kwargs.pop('perturb'))\n        if 'perturb' in _helper_kwargs and not _helper_has_var_kw and 'perturb' not in _helper_params:\n            _helper_kwargs.pop('perturb')\n    _helper_result = _helper(\"`tildex'\", *_helper_positional, **_helper_kwargs)\n    _helper_result_generator = bool(inspect.isgenerator(_helper_result))\n    _helper_result_asyncgen = bool(inspect.isasyncgen(_helper_result)) if not _helper_result_generator else False\n    _helper_result_awaitable = bool(inspect.isawaitable(_helper_result)) if not _helper_result_generator and not _helper_result_asyncgen else False\n    _helper_result_close = getattr(_helper_result, \"close\", None) if _helper_result_generator else (getattr(_helper_result, \"aclose\", None) if _helper_result_asyncgen else (getattr(_helper_result, \"close\", None) if _helper_result_awaitable else None))\n    _helper_result_close_ret = _helper_result_close() if callable(_helper_result_close) else None\n    _helper_result_close_ret_close = getattr(_helper_result_close_ret, \"close\", None) if _helper_result_asyncgen else None\n    _helper_result_close_ret_close() if callable(_helper_result_close_ret_close) else None\n    (_ for _ in ()).throw(TypeError(f\"hddid_clime_requires_scipy() must return synchronously, got generator {type(_helper_result).__name__}\")) if _helper_result_generator else None\n    (_ for _ in ()).throw(TypeError(f\"hddid_clime_requires_scipy() must return synchronously, got async generator {type(_helper_result).__name__}\")) if _helper_result_asyncgen else None\n    (_ for _ in ()).throw(TypeError(f\"hddid_clime_requires_scipy() must return synchronously, got awaitable {type(_helper_result).__name__}\")) if _helper_result_awaitable else None\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_nonbool\") if not isinstance(_helper_result, (bool, _np.bool_)) else None\nexcept ImportError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_importerror\")\nexcept OSError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_oserror\")\nexcept AttributeError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_attributeerror\")\nexcept ValueError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_valueerror\")\nexcept TypeError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_typeerror\")\nexcept RuntimeError:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_runtimeerror\")\nexcept Exception:\n    Macro.setLocal(\"_hddid_probe_reason\", \"helper_exception\")\nelse:\n    Macro.setLocal(\"_hddid_probe_reason\", Macro.getLocal(\"_hddid_probe_reason\") or \"ok\")") if Macro.getLocal("_hddid_probe_reason") == "" else None
        if _rc == 0 & "`_hddid_probe_reason'" != "" {
            return local reason "`_hddid_probe_reason'"
            exit
        }
        return local reason "helper_exception"
        exit
    }
    return local reason "`_hddid_probe_reason'"
end

program define _hddid_cvlasso_pick_lambda, rclass
    version 16
    syntax , CONTEXT(string)

    return clear

    tempname _lambda_scalar _lambda_grid
    capture scalar `_lambda_scalar' = e(lopt)
    if _rc == 0 & `_lambda_scalar' < . {
        if `_lambda_scalar' <= 0 {
            di as error "{bf:hddid}: `context' produced a nonpositive e(lopt)"
            exit 498
        }
        return scalar lambda = `_lambda_scalar'
        return local source "lopt"
        exit
    }

    capture matrix `_lambda_grid' = e(lambdamat)
    if _rc != 0 {
        di as error "{bf:hddid}: `context' did not leave a usable lambda choice"
        di as error "  Neither e(lopt) nor e(lambdamat) is available after cvlasso"
        exit 498
    }

    local _lambda_last = rowsof(`_lambda_grid')
    if `_lambda_last' < 1 {
        di as error "{bf:hddid}: `context' returned an empty lambda grid"
        exit 498
    }

    scalar `_lambda_scalar' = el(`_lambda_grid', `_lambda_last', 1)
    if `_lambda_scalar' >= . {
        di as error "{bf:hddid}: `context' produced a non-finite fallback lambda"
        exit 498
    }
    if `_lambda_scalar' <= 0 {
        di as error "{bf:hddid}: `context' produced a nonpositive fallback lambda"
        exit 498
    }

    return scalar lambda = `_lambda_scalar'
    return local source "grid_last"
end

program define _hddid_run_rng_isolated
    version 16
    gettoken seed 0 : 0, parse(" ")
    capture confirm number `seed'
    if _rc != 0 {
        di as error "{bf:hddid}: internal RNG-isolation wrapper received a nonnumeric seed contract"
        exit 198
    }
    local _seed_num = real(`"`seed'"')
    if missing(`_seed_num') | `_seed_num' != floor(`_seed_num') | ///
        `_seed_num' < -1 | `_seed_num' > 2147483647 {
        di as error "{bf:hddid}: internal RNG-isolation wrapper requires seed() equal to -1 or an integer in [0, 2147483647]"
        di as error "  Received internal seed contract = {bf:`seed'}"
        exit 198
    }

    local _restore_rngstate = (`_seed_num' >= 0)
    local _use_active_stream 0
    local _resume_isolated_stream 0
    if `_seed_num' >= 0 & ///
        `"$HDDID_ACTIVE_INTERNAL_RNG_STREAM"' == "1" & ///
        `"$HDDID_ACTIVE_INTERNAL_SEED"' != "" {
        capture confirm number $HDDID_ACTIVE_INTERNAL_SEED
        if _rc == 0 {
            local _active_seed_num = real(`"$HDDID_ACTIVE_INTERNAL_SEED"')
            if !missing(`_active_seed_num') & ///
                `_active_seed_num' == floor(`_active_seed_num') & ///
                `_active_seed_num' == `_seed_num' {
                local _use_active_stream 1
                local _restore_rngstate 0
            }
        }
    }
    local _rngstate_before `c(rngstate)'
    if `_seed_num' >= 0 & !`_use_active_stream' & ///
        `"$HDDID_LASTISO_SEED"' != "" & ///
        `"$HDDID_LASTISO_CALLER_RNG"' != "" & ///
        `"$HDDID_LASTISO_INTERNAL_RNG"' != "" {
        capture confirm number $HDDID_LASTISO_SEED
        if _rc == 0 {
            local _isolated_seed_num = real(`"$HDDID_LASTISO_SEED"')
            if !missing(`_isolated_seed_num') & ///
                `_isolated_seed_num' == floor(`_isolated_seed_num') & ///
                `_isolated_seed_num' == `_seed_num' & ///
                `"`_rngstate_before'"' == `"$HDDID_LASTISO_CALLER_RNG"' {
                local _resume_isolated_stream 1
            }
        }
    }
    if `_seed_num' >= 0 & !`_use_active_stream' {
        if `_resume_isolated_stream' {
            quietly set rngstate $HDDID_LASTISO_INTERNAL_RNG
        }
        else {
            quietly set seed `_seed_num'
        }
    }

    capture `0'
    local _cmd_rc = _rc
    if `_cmd_rc' == 0 & `_seed_num' >= 0 & !`_use_active_stream' {
        global HDDID_LASTISO_SEED `_seed_num'
        global HDDID_LASTISO_CALLER_RNG `"`_rngstate_before'"'
        global HDDID_LASTISO_INTERNAL_RNG `"`c(rngstate)'"'
    }

    // Standalone seeded helper calls always restore the caller's ambient RNG.
    // Active-stream calls intentionally keep successful draws committed inside
    // the command-level seeded stream, but a failed substep is discarded and
    // must not perturb later retries/fallbacks.
    if `_restore_rngstate' | (`_cmd_rc' != 0 & `_use_active_stream') {
        quietly set rngstate `_rngstate_before'
    }

    exit `_cmd_rc'
end

program define _hddid_resolve_prop_cv, rclass
    version 16
    syntax, FOLD(integer) NTRAIN(integer) NTREAT(integer) NCONTROL(integer)

    return clear

    local _ps_lambda = e(lopt)
    local _ps_loptid = e(loptid)
    local _ps_lmax = e(lmax)
    local _ps_nlambda = e(lcount)
    local _ps_missing_lopt = missing(`_ps_lambda')

    if `_ps_missing_lopt' {
        if missing(`_ps_lmax') | `_ps_lmax' <= 0 | ///
            missing(`_ps_nlambda') | `_ps_nlambda' < 1 | ///
            `_ps_nlambda' != floor(`_ps_nlambda') {
            di as error "{bf:hddid}: cvlassologit returned an unusable propensity CV contract in fold `fold'"
            di as error "  training observations: total=`ntrain', treated=`ntreat', control=`ncontrol'"
            di as error "  Expected a finite {bf:e(lmax)} > 0 and integer {bf:e(lcount)} >= 1 when {bf:e(lopt)} is missing"
            di as error "  Returned contract: lopt=" %9.6f `_ps_lambda' ", loptid=`_ps_loptid', lcount=`_ps_nlambda', lmax=" %9.6f `_ps_lmax'
            exit 498
        }
        // Some seeded cvlassologit runs leave e(lopt) missing even though a
        // finite lambda path exists. Recover from the path's upper boundary
        // rather than passing a missing lambda onward.
        local _ps_lambda = `_ps_lmax'
        local _ps_loptid = 1
    }
    else {
        if `_ps_lambda' >= . | `_ps_lambda' <= 0 {
            di as error "{bf:hddid}: cvlassologit returned a nonpositive or non-finite {bf:e(lopt)} in fold `fold'"
            di as error "  training observations: total=`ntrain', treated=`ntreat', control=`ncontrol'"
            di as error "  Returned contract: lopt=" %9.6f `_ps_lambda' ", loptid=`_ps_loptid', lcount=`_ps_nlambda', lmax=" %9.6f `_ps_lmax'
            exit 498
        }
        if missing(`_ps_loptid') {
            di as error "{bf:hddid}: cvlassologit returned a usable lambda but a missing {bf:e(loptid)} in fold `fold'"
            di as error "  training observations: total=`ntrain', treated=`ntreat', control=`ncontrol'"
            di as error "  A nonmissing {bf:e(lopt)} requires integer boundary metadata {bf:e(loptid)} in [1, {bf:e(lcount)}]"
            di as error "  Returned contract: lopt=" %9.6f `_ps_lambda' ", loptid=`_ps_loptid', lcount=`_ps_nlambda', lmax=" %9.6f `_ps_lmax'
            exit 498
        }
        if missing(`_ps_nlambda') | `_ps_nlambda' < 1 | ///
            `_ps_nlambda' != floor(`_ps_nlambda') {
            di as error "{bf:hddid}: cvlassologit returned an unusable nonmissing-lopt propensity CV contract in fold `fold'"
            di as error "  training observations: total=`ntrain', treated=`ntreat', control=`ncontrol'"
            di as error "  A nonmissing {bf:e(lopt)} requires integer {bf:e(lcount)} >= 1"
            di as error "  Returned contract: lopt=" %9.6f `_ps_lambda' ", loptid=`_ps_loptid', lcount=`_ps_nlambda', lmax=" %9.6f `_ps_lmax'
            exit 498
        }
        if `_ps_loptid' != floor(`_ps_loptid') | ///
            `_ps_loptid' < 1 | `_ps_loptid' > `_ps_nlambda' {
            di as error "{bf:hddid}: cvlassologit returned an invalid {bf:e(loptid)} outside [1, lcount] in fold `fold'"
            di as error "  training observations: total=`ntrain', treated=`ntreat', control=`ncontrol'"
            di as error "  A nonmissing {bf:e(lopt)} requires integer boundary metadata {bf:e(loptid)} in [1, {bf:e(lcount)}]"
            di as error "  Returned contract: lopt=" %9.6f `_ps_lambda' ", loptid=`_ps_loptid', lcount=`_ps_nlambda', lmax=" %9.6f `_ps_lmax'
            exit 498
        }
    }

    return scalar lambda = `_ps_lambda'
    return scalar loptid = `_ps_loptid'
    return scalar lmax = `_ps_lmax'
    return scalar nlambda = `_ps_nlambda'
    return scalar missing_lopt = `_ps_missing_lopt'
end

program define _hddid_count_split_groups, rclass
    version 16
    args touse xvars zvar treatvar

    return clear

    local _hddid_xvars_sorted : list sort xvars
    local _hddid_keyvars `"`_hddid_xvars_sorted' `zvar'"'

    tempname __hddid_group_counts
    matrix `__hddid_group_counts' = J(1, 2, 0)
    // cvlasso/cvlassologit can clear ad-hoc Mata symbols created by a prior
    // successful hddid call. Re-load the Mata sidecar on demand before this
    // preprocessing guard asks for canonical split-key counts again.
    capture mata: _hddid_canonical_group_counts(J(1, 1, 0), J(1, 1, 0))
    if _rc != 0 {
        quietly _hddid_resolve_pkgdir ""
        local _hddid_splitcount_pkgdir `"`r(pkgdir)'"'
        if `"`_hddid_splitcount_pkgdir'"' == "" {
            di as error "{bf:hddid}: cannot reload split-key Mata helpers during preprocessing"
            di as error "  Reason: the current Stata session lost {_hddid_canonical_group_counts()} and no valid hddid package directory could be resolved"
            exit 198
        }
        capture quietly run "`_hddid_splitcount_pkgdir'/_hddid_mata.ado"
        if _rc != 0 {
            di as error "{bf:hddid}: failed to reload {bf:_hddid_mata.ado} before split-feasibility checks"
            di as error "  Expected sidecar location: `_hddid_splitcount_pkgdir'/_hddid_mata.ado"
            exit 198
        }
    }
    mata: st_matrix(st_local("__hddid_group_counts"), ///
        _hddid_canonical_group_counts( ///
            st_data(., tokens(st_local("_hddid_keyvars")), st_local("touse")), ///
            st_data(., st_local("treatvar"), st_local("touse"))))

    return scalar n0 = el(`__hddid_group_counts', 1, 1)
    return scalar n1 = el(`__hddid_group_counts', 1, 2)
end

program define _hddid_choose_outer_split_sample, rclass
    version 16
    syntax, TOUSE(name) FOLDTOUSE(name) [DEFAULTPROPTOUSE(name) NOFIRST]

    return clear

    // The paper/R split is anchored on the sample that actually carries the
    // held-out score. In the default internal path, D/W-complete rows missing
    // depvar() can still widen the propensity-training sample, but they must
    // not relabel the common-score outer fold map. nofirst keeps its own
    // broader pretrim fold-feasibility path.
    local _samplevar `touse'
    if "`nofirst'" != "" {
        local _samplevar `foldtouse'
    }

    return local samplevar `_samplevar'
end

program define _hddid_default_outer_fold_map
    version 16
    syntax , FOLDVAR(name) RANKVAR(name) SCORETOUSE(name) PROPTOUSE(name) ///
        XVARS(varlist numeric) ZVAR(varname numeric) TREATVAR(varname numeric) ///
        K(integer) SEED(integer)

    if `k' < 2 {
        di as error "{bf:hddid}: invalid default outer fold count {bf:k(`k')}"
        di as error "  Reason: outer cross-fitting requires an integer {bf:k >= 2} before any fold assignment arithmetic can run"
        exit 198
    }

    mata: _hddid_default_outer_fold_map_m( ///
        "`foldvar'", "`rankvar'", "`scoretouse'", "`proptouse'", ///
        `"`xvars'"', "`zvar'", "`treatvar'", `k', `seed')
end

program define _hddid_sort_default_innercv
    version 16
    syntax, STAge(string) FOLDRank(varname numeric) TREAT(varname numeric) ///
        XVARS(varlist numeric) ZVAR(varname numeric) DEPVAR(varname numeric)

    // [AUDIT FIX] The prior sort `treat foldrank xvars zvar` created
    // deterministic inner-CV splits for cvlasso/cvlassologit sorted by x.
    // For high-dimensional x, this makes inner validation folds
    // non-representative (inner fold 1 = smallest x, fold K = largest x),
    // biasing the CV lambda selection and causing systematic over-shrinkage
    // of the first-stage nuisance predictions.
    // Fix: sort only by treatment and fold rank. The fold rank already
    // provides a deterministic ordering that is not systematically aligned
    // with the x-covariate distribution, so inner CV folds remain
    // approximately representative random subsets.
    local _stage = lower(strtrim(`"`stage'"'))
    if "`_stage'" == "propensity" {
        sort `treat' `foldrank'
        exit
    }
    if "`_stage'" == "outcome" {
        sort `treat' `foldrank'
        exit
    }

    di as error "{bf:hddid}: invalid default inner-CV sort stage {bf:`stage'}"
    di as error "  Allowed stages are {bf:propensity} and {bf:outcome}"
    exit 198
end

program define _hddid_canonicalize_xvars, rclass
    version 16
    syntax namelist(min=1 max=1), XVARS(string asis)

    return clear

    local touse `namelist'
    local _hddid_xvars `"`xvars'"'
    local _hddid_p : word count `_hddid_xvars'
    if `_hddid_p' <= 1 {
        return local xvars `_hddid_xvars'
        exit
    }

    tempname __hddid_xord
    mata: st_matrix(st_local("__hddid_xord"), ///
        _hddid_canonical_x_order( ///
            st_data(., tokens(st_local("_hddid_xvars")), st_local("touse"))))

    local _hddid_xcanon
    forvalues _hddid_j = 1/`_hddid_p' {
        local _hddid_idx = `__hddid_xord'[1, `_hddid_j']
        local _hddid_xvar : word `_hddid_idx' of `_hddid_xvars'
        local _hddid_xcanon = trim(`"`_hddid_xcanon' `_hddid_xvar'"')
    }
    local _hddid_xcanon : list retokenize _hddid_xcanon
    return local xvars `_hddid_xcanon'
end

mata:
real matrix _hddid_canonical_x_standardize(real matrix key_data)
{
    real scalar j, n, max_abs_j, rms_j
    real rowvector key_mean, key_scale
    real colvector scaled_j
    real matrix centered, standardized

    n = rows(key_data)
    if (n == 0 | cols(key_data) == 0) {
        return(key_data)
    }
    if (hasmissing(key_data)) {
        errprintf("_hddid_canonical_x_standardize(): x() columns must be finite on the usable sample\n")
        _error(3498)
    }

    key_mean = mean(key_data)
    if (hasmissing(key_mean)) {
        errprintf("_hddid_canonical_x_standardize(): x() column means must remain finite; centering overflowed or became nonfinite\n")
        errprintf("_hddid_canonical_x_standardize(): rescale x() before canonical standardization\n")
        _error(3498)
    }
    centered = key_data :- key_mean
    if (hasmissing(centered)) {
        errprintf("_hddid_canonical_x_standardize(): centered x() coordinates must remain finite; centering overflowed or became nonfinite\n")
        errprintf("_hddid_canonical_x_standardize(): rescale x() before canonical standardization\n")
        _error(3498)
    }
    key_scale = J(1, cols(key_data), 0)
    standardized = centered

    for (j = 1; j <= cols(key_data); j++) {
        // Rescale before squaring so extreme but finite affine recodings do
        // not defeat canonical column ordering through RMS overflow.
        max_abs_j = max(abs(centered[., j]))
        if (max_abs_j > 0 & max_abs_j < .) {
            scaled_j = centered[., j] :/ max_abs_j
            rms_j = sqrt(mean(scaled_j :^ 2))
            if (rms_j > 0 & rms_j < .) {
                key_scale[1, j] = max_abs_j * rms_j
                standardized[., j] = scaled_j :/ rms_j
            }
        }
    }
    if (hasmissing(standardized)) {
        errprintf("_hddid_canonical_x_standardize(): standardized x() coordinates must remain finite; scaling overflowed or became nonfinite\n")
        errprintf("_hddid_canonical_x_standardize(): rescale x() before canonical standardization\n")
        _error(3498)
    }

    return(standardized)
}

real rowvector _hddid_canonical_x_order(real matrix key_data)
{
    real matrix key_sig, key_abs_sig, key_sig_input, key_sort_sig, key_canon, block
    real rowvector key_ord, block_ord, block_key_ord
    real scalar block_end, j

    if (cols(key_data) == 0) {
        return(J(1, 0, .))
    }
    if (cols(key_data) == 1) {
        return(1)
    }

    key_sig_input = _hddid_canonical_x_standardize(key_data)
    key_sig = J(rows(key_data), cols(key_data), .)
    key_abs_sig = J(rows(key_data), cols(key_data), .)
    for (j = 1; j <= cols(key_data); j++) {
        key_sig[., j] = sort(key_sig_input[., j], 1)
        key_abs_sig[., j] = sort(abs(key_sig_input[., j]), 1)
    }

    key_sort_sig = (key_sig \ key_abs_sig \ (1..cols(key_data)))
    key_ord = order(key_sort_sig', 1..rows(key_sort_sig))'
    key_sig = key_sig[, key_ord]
    key_canon = key_data[, key_ord]

    j = 1
    while (j <= cols(key_canon)) {
        block_end = j
        while (block_end < cols(key_canon)) {
            if (any(key_sig[., block_end + 1] :!= key_sig[., j])) {
                break
            }
            block_end = block_end + 1
        }
        if (block_end > j) {
            block = key_canon[., j..block_end]
            block_ord = order(block', 1..rows(block))'
            key_canon[., j..block_end] = block[., block_ord]
            block_key_ord = key_ord[j..block_end]
            key_ord[j..block_end] = block_key_ord[block_ord]
        }
        j = block_end + 1
    }

    return(key_ord)
}

real rowvector _hddid_canonical_group_counts(
    real matrix key_data, real matrix treat)
{
    real matrix counts, key_sig, key_canon, block
    real colvector idx, ord
    real rowvector key_ord, block_ord, prev_key
    real scalar block_end, g, j, key_rank

    counts = J(1, 2, 0)
    if (rows(key_data) != rows(treat)) {
        errprintf("_hddid_canonical_group_counts(): key_data and treat must have the same row count (%g vs %g)\n",
            rows(key_data), rows(treat))
        _error(3498)
    }
    if (cols(treat) != 1) {
        errprintf("_hddid_canonical_group_counts(): treat must be an n x 1 column vector; got %g x %g\n",
            rows(treat), cols(treat))
        _error(3498)
    }
    if (hasmissing(key_data)) {
        errprintf("_hddid_canonical_group_counts(): split-key data must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(treat) | min(treat) < 0 | max(treat) > 1 | any(treat :!= trunc(treat))) {
        errprintf("_hddid_canonical_group_counts(): treat must be a finite 0/1 indicator\n")
        _error(3498)
    }

    for (g = 0; g <= 1; g++) {
        idx = selectindex(treat :== g)
        if (rows(idx) == 0) {
            continue
        }

        key_canon = key_data[idx, .]
        if (cols(key_canon) == 0) {
            counts[1, g + 1] = 1
            continue
        }
        if (cols(key_canon) > 1) {
            key_sig = J(rows(key_canon), cols(key_canon), .)
            for (j = 1; j <= cols(key_canon); j++) {
                key_sig[., j] = sort(key_canon[., j], 1)
            }
            key_ord = order(key_sig', 1..cols(key_sig'))'
            key_sig = key_sig[, key_ord]
            key_canon = key_canon[, key_ord]

            j = 1
            while (j <= cols(key_canon)) {
                block_end = j
                while (block_end < cols(key_canon)) {
                    if (any(key_sig[., block_end + 1] :!= key_sig[., j])) {
                        break
                    }
                    block_end = block_end + 1
                }
                if (block_end > j) {
                    block = key_canon[., j..block_end]
                    block_ord = order(block', 1..rows(block))'
                    key_canon[., j..block_end] = block[., block_ord]
                }
                j = block_end + 1
            }
        }

        ord = order(key_canon, 1..cols(key_canon))
        key_rank = 0
        prev_key = J(1, cols(key_canon), .)
        for (j = 1; j <= rows(key_canon); j++) {
            if (j == 1 | any(key_canon[ord[j], .] :!= prev_key)) {
                key_rank = key_rank + 1
                prev_key = key_canon[ord[j], .]
            }
        }
        counts[1, g + 1] = key_rank
    }

    return(counts)
}
end

// Source-loading this file should only define programs. Resolve the package
// directory lazily inside hddid so `run hddid.ado' does not clobber caller r().

capture program drop _hddid_parse_estopt
capture program drop _hddid_parse_estopt_core
capture program drop _hddid_parse_methodopt
program define _hddid_parse_methodopt, rclass
    syntax , OPTSRAW(string asis)

    return clear
    local _hddid_opts_raw `optsraw'
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(92) + char(34), char(34), .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(92) + char(39), char(39), .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(9), " ", .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(10), " ", .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(13), " ", .)
    local _hddid_opts_raw_orig `"`_hddid_opts_raw'"'
    local _hddid_opts_raw_lc = lower(`"`_hddid_opts_raw_orig'"')
    local _hddid_method_scan_lc `"`_hddid_opts_raw_lc'"'
    local _hddid_method_first ""
    local _hddid_method_first_raw ""
    // Nested method(...) text inside an estimator-family payload (for example
    // estimator= method(ra)) is malformed estimator syntax, not a real basis
    // selector. Keep the method-domain precheck from stealing those cases
    // before estimator-style guidance classifies them.
    local _hddid_method_scan_lc = ///
        regexr(`"`_hddid_method_scan_lc'"', ///
        "(^|[ ,])estimator[ ]*=[ ]*[(]?[ ]*method[ ]*[(][^)]*[)][ ]*[)]?", ///
        " __hddid_estimator_payload__ ")
    local _hddid_method_scan_lc = ///
        regexr(`"`_hddid_method_scan_lc'"', ///
        "(^|[ ,])estimator[ ]*[(][ ]*method[ ]*[(][^)]*[)][ ]*[)]", ///
        " __hddid_estimator_payload__ ")
    local _hddid_method_scan_lc = ///
        regexr(`"`_hddid_method_scan_lc'"', ///
        "(^|[ ,])(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*method[ ]*[(][^)]*[)]", ///
        " __hddid_alias_payload__ ")
    local _hddid_method_scan_lc = ///
        regexr(`"`_hddid_method_scan_lc'"', ///
        "(^|[ ,])(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][^)]*[)][ ]*method[ ]*[(][^)]*[)]", ///
        " __hddid_alias_payload__ ")

    local _hddid_method_scan `"`_hddid_method_scan_lc'"'
    local _hddid_method_count 0
    // Nonempty spaced assignment-style method = ... tokens should fall
    // through to the concrete RHS branches below so public guidance preserves
    // the full malformed token instead of clipping it to method = alone.
    // Truly empty RHS cases are still caught by the dedicated empty-assignment
    // branch later in this parser.
    while regexm(`"`_hddid_method_scan'"', ///
        "(^|[ ,])(method[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)][^ ,]+)") {
        local _hddid_method_match = strtrim(regexs(2))
        local _hddid_method_raw `"`_hddid_method_match'"'
        local _hddid_method_pos = strpos(`"`_hddid_opts_raw_lc'"', `"`_hddid_method_match'"')
        if `_hddid_method_pos' > 0 {
            local _hddid_method_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_method_pos', length(`"`_hddid_method_match'"'))
        }
        local _hddid_method = strtrim(regexs(3))
        local _hddid_method = subinstr(`"`_hddid_method'"', char(34), "", .)
        local _hddid_method = subinstr(`"`_hddid_method'"', char(39), "", .)
        local _hddid_method = strproper(strtrim(`"`_hddid_method'"'))
        return local invalid "1"
        return local method `"`_hddid_method_raw'"'
        return local raw `"`_hddid_method_raw'"'
        exit
    }
    while regexm(`"`_hddid_method_scan'"', ///
        "(^|[ ,])method[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)]") {
        local _hddid_method_match = strtrim(regexs(0))
        local _hddid_method = strtrim(regexs(2))
        local _hddid_method = subinstr(`"`_hddid_method'"', char(34), "", .)
        local _hddid_method = subinstr(`"`_hddid_method'"', char(39), "", .)
        local _hddid_method = strproper(strtrim(`"`_hddid_method'"'))
        local _hddid_method_raw `"`_hddid_method_match'"'
        local _hddid_method_pos = strpos(`"`_hddid_opts_raw_lc'"', `"`_hddid_method_match'"')
        if `_hddid_method_pos' > 0 {
            local _hddid_method_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_method_pos', length(`"`_hddid_method_match'"'))
        }
        if !inlist(`"`_hddid_method'"', "Pol", "Tri") {
            return local invalid "1"
            return local method `"`_hddid_method_raw'"'
            return local raw `"`_hddid_method_raw'"'
            exit
        }
        // Assignment-style method=... text is malformed syntax on its own.
        // Even if a later real method(Tri)/method(Pol) follows, the bad
        // assignment token is not a first valid method() request and must not
        // be upgraded into duplicate-method guidance.
        return local invalid "1"
        return local method `"`_hddid_method_raw'"'
        return local raw `"`_hddid_method_raw'"'
        exit
    }
    while regexm(`"`_hddid_method_scan'"', ///
        "(^|[ ,])(method[ ]*=[ ]*)$") {
        local _hddid_method_match = strtrim(regexs(2))
        local _hddid_method_raw `"`_hddid_method_match'"'
        local _hddid_method_pos = strpos(`"`_hddid_opts_raw_lc'"', `"`_hddid_method_match'"')
        if `_hddid_method_pos' > 0 {
            local _hddid_method_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_method_pos', length(`"`_hddid_method_match'"'))
        }
        return local invalid "1"
        return local method `"`_hddid_method_raw'"'
        return local raw `"`_hddid_method_raw'"'
        exit
    }
    while regexm(`"`_hddid_method_scan'"', ///
        "(^|[ ,])method[ ]*=[ ]*([^ ,]+)") {
        local _hddid_method_match = strtrim(regexs(0))
        local _hddid_method = strtrim(regexs(2))
        local _hddid_method = subinstr(`"`_hddid_method'"', char(34), "", .)
        local _hddid_method = subinstr(`"`_hddid_method'"', char(39), "", .)
        local _hddid_method = strproper(strtrim(`"`_hddid_method'"'))
        local _hddid_method_raw `"`_hddid_method_match'"'
        local _hddid_method_pos = strpos(`"`_hddid_opts_raw_lc'"', `"`_hddid_method_match'"')
        if `_hddid_method_pos' > 0 {
            local _hddid_method_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_method_pos', length(`"`_hddid_method_match'"'))
        }
        if !inlist(`"`_hddid_method'"', "Pol", "Tri") {
            return local invalid "1"
            return local method `"`_hddid_method_raw'"'
            return local raw `"`_hddid_method_raw'"'
            exit
        }
        // Assignment-style method=... text is malformed syntax on its own.
        // Even if a later real method(Tri)/method(Pol) follows, the bad
        // assignment token is not a first valid method() request and must not
        // be upgraded into duplicate-method guidance.
        return local invalid "1"
        return local method `"`_hddid_method_raw'"'
        return local raw `"`_hddid_method_raw'"'
        exit
    }
    while regexm(`"`_hddid_method_scan'"', ///
        "(^|[ ,])(method[ ]*[(][ ]*([^)]*)[ ]*[)][^ ,]+)") {
        local _hddid_method_match = strtrim(regexs(2))
        local _hddid_method_raw `"`_hddid_method_match'"'
        local _hddid_method_pos = strpos(`"`_hddid_opts_raw_lc'"', `"`_hddid_method_match'"')
        if `_hddid_method_pos' > 0 {
            local _hddid_method_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_method_pos', length(`"`_hddid_method_match'"'))
        }
        local _hddid_method = strtrim(regexs(3))
        local _hddid_method = subinstr(`"`_hddid_method'"', char(34), "", .)
        local _hddid_method = subinstr(`"`_hddid_method'"', char(39), "", .)
        local _hddid_method = strproper(strtrim(`"`_hddid_method'"'))
        return local invalid "1"
        if inlist(`"`_hddid_method'"', "Pol", "Tri") {
            return local method `"`_hddid_method_raw'"'
        }
        else {
            return local method `"`_hddid_method'"'
        }
        return local raw `"`_hddid_method_raw'"'
        exit
    }
    while regexm(`"`_hddid_method_scan'"', ///
        "(^|[ ,])method[ ]*[(][ ]*([^)]*)[ ]*[)]([ ,]|$)") {
        local _hddid_method_match = strtrim(regexs(0))
        local _hddid_method_raw `"`_hddid_method_match'"'
        local _hddid_method_pos = strpos(`"`_hddid_opts_raw_lc'"', `"`_hddid_method_match'"')
        if `_hddid_method_pos' > 0 {
            local _hddid_method_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_method_pos', length(`"`_hddid_method_match'"'))
        }
        local _hddid_method = strtrim(regexs(2))
        local _hddid_method = subinstr(`"`_hddid_method'"', char(34), "", .)
        local _hddid_method = subinstr(`"`_hddid_method'"', char(39), "", .)
        local _hddid_method = strproper(strtrim(`"`_hddid_method'"'))
        if !inlist(`"`_hddid_method'"', "Pol", "Tri") {
            return local invalid "1"
            return local method `"`_hddid_method'"'
            return local raw `"`_hddid_method_raw'"'
            exit
        }
        if `"`_hddid_method_first'"' == "" {
            local _hddid_method_first `"`_hddid_method'"'
            local _hddid_method_first_raw `"`_hddid_method_raw'"'
        }
        local ++_hddid_method_count
        if `_hddid_method_count' > 1 {
            return local invalid "1"
            return local duplicate "1"
            return local method `"`_hddid_method_raw'"'
            exit
        }
        local _hddid_method_scan = regexr(`"`_hddid_method_scan'"', ///
            "(^|[ ,])method[ ]*[(][ ]*([^)]*)[ ]*[)]", "")
    }
    if `"`_hddid_method_first'"' != "" {
        return local method `"`_hddid_method_first'"'
        return local raw `"`_hddid_method_first_raw'"'
    }
end

program define _hddid_parse_estopt_core, rclass
    syntax , OPTSRAW(string asis)

    return clear
    local _hddid_opts_raw `optsraw'
    // Macro-expanded option text can retain Stata escape sequences like \"
    // or \'. Normalize those first so estimator-family guidance echoes a
    // human-readable token instead of macro-quoting artifacts.
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(92) + char(34), char(34), .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(92) + char(39), char(39), .)
    // Stata treats tabs/newlines as legal whitespace in command input.
    // Normalize them here so estimator-contract guidance does not depend on
    // whether the caller separated tokens with spaces or other whitespace.
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(9), " ", .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(10), " ", .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(13), " ", .)
    local _hddid_opts_raw_orig = ///
        strtrim(subinstr(`"`_hddid_opts_raw'"', ",", " ", .))
    local _hddid_opts_raw = lower(`"`_hddid_opts_raw_orig'"')
    // Mask x() payloads only for the final bare-token fallback branches. Legal
    // x variables may literally be named ra/ipw/aipw, but those names must not
    // be mistaken for unsupported estimator-family switches.
    local _hddid_opts_raw_bare = ///
        regexr(`"`_hddid_opts_raw'"', "(^|[ ,])x[ ]*[(][^)]*[)]", ///
        " x(__hddid_xpayload__)")
    // Preserve empty quoted estimator payloads before the generic quote
    // normalization below. Collapsing doubled quotes first would turn
    // estimator=('') / estimator=("") into estimator=(), which changes the
    // offending token shown in fixed-AIPW guidance.
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][ ]*["]["][ ]*[)])([ ]|$)"')
    if `_hddid_match' {
        return local invalid "1"
        return local raw `"`=strtrim(regexs(2))'"'
        return local form "assignment_parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*''[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        return local invalid "1"
        return local raw `"`=strtrim(regexs(2))'"'
        return local form "assignment_parenthesized"
        exit
    }
    // Empty quoted alias payloads are malformed estimator-family assignments
    // in their own right. Preserve the exact alias token before later
    // quote-normalization or generic alias parsing can rewrite ra="" to ra=
    // or swallow a separate trailing method()/q()/... option into the echo.
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*["]["])([ ]|$)"')
    if `_hddid_match' {
        return local invalid "1"
        return local raw `"`=strtrim(regexs(2))'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*'')([ ]|$)")
    if `_hddid_match' {
        return local invalid "1"
        return local raw `"`=strtrim(regexs(2))'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*["]["][ ]*[)])([ ]|$)"')
    if `_hddid_match' {
        return local invalid "1"
        return local raw `"`=strtrim(regexs(2))'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*''[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        return local invalid "1"
        return local raw `"`=strtrim(regexs(2))'"'
        return local form "assignment"
        exit
    }
    local _hddid_opts_raw_quoted_orig `"`_hddid_opts_raw_orig'"'
    local _hddid_opts_raw_quoted_orig = ///
        subinstr(`"`_hddid_opts_raw_quoted_orig'"', ///
        char(34) + char(34), char(34), .)
    local _hddid_opts_raw_quoted_orig = ///
        subinstr(`"`_hddid_opts_raw_quoted_orig'"', ///
        char(39) + char(39), char(39), .)
    local _hddid_opts_raw_quoted `"`_hddid_opts_raw'"'
    local _hddid_opts_raw_quoted = ///
        subinstr(`"`_hddid_opts_raw_quoted'"', ///
        char(34) + char(34), char(34), .)
    local _hddid_opts_raw_quoted = ///
        subinstr(`"`_hddid_opts_raw_quoted'"', ///
        char(39) + char(39), char(39), .)
    // A quoted parenthesized alias token remains the offending unsupported
    // estimator-family switch even when a later real method() option follows.
    // Canonical quoted RHS payloads should therefore reuse the same alias-head
    // guidance as the already-fixed noncanonical quoted path, with method()
    // kept outside the echoed offending token.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*["](r|ra|i|ip|ipw|a|ai|aip|aipw)["][ ]*[)])[ ]+(method[ ]*[(][^)]*[)])"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_alias_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_alias_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*'(r|ra|i|ip|ipw|a|ai|aip|aipw)'[ ]*[)])[ ]+(method[ ]*[(][^)]*[)])")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_alias_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_alias_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
    }
    // Define legal-follow patterns before the empty-assignment guard runs.
    // Otherwise an undefined local expands to an empty regex fragment and
    // every nonempty estimator=payload is misclassified as bare estimator=.
    local _hddid_estopt_lparen_follow ///
        "(c|cf|cfo|cfor|cform|cforma|cformat|ci|cit|city|cityp|citype|p|pf|pfo|pfor|pform|pforma|pformat|s|sf|sfo|sfor|sform|sforma|sformat|fvwr|fvwra|fvwrap|fvwrapo|fvwrapon|t|ti|tit|titl|title|tr|tre|trea|treat|x|z|z0|k|l|le|lev|leve|level|m|me|met|meth|metho|method|q|alp|alph|alpha|pi|pih|piha|pihat|phi1|phi1h|phi1ha|phi1hat|phi0|phi0h|phi0ha|phi0hat|seed|sep|sepa|separ|separa|separat|separato|separator|depn|depna|depnam|depname|nb|nbo|nboo|nboot)[ ]*[(]"
    local _hddid_estopt_bare_follow ///
        "(ab|abb|abbr|abbre|abbrev|allb|allba|allbas|allbase|allbasel|allbasele|allbaselev|allbaseleve|allbaselevel|allbaselevels|b|be|bet|beta|basel|basele|baselev|baseleve|baselevel|baselevels|cns|cnsr|cnsre|cnsrep|cnsrepo|cnsrepor|cnsreport|cod|codi|codin|coding|coefl|coefle|coefleg|coeflege|coeflegen|coeflegend|com|comp|compa|compar|compare|e|ef|efo|efor|eform|empty|emptyc|emptyce|emptycel|emptycell|emptycells|f|fi|fir|firs|first|fu|ful|full|fullc|fullcn|fullcns|fullcnsr|fullcnsre|fullcnsrep|fullcnsrepo|fullcnsrepor|fullcnsreport|fvl|fvla|fvlab|fvlabe|fvlabel|ls|lst|lstr|lstre|lstret|lstretch|ma|mar|mark|markd|markdo|markdow|markdown|noa|noab|noabb|noabbr|noabbre|noabbrev|not|nota|notab|notabl|notable|noempty|noemptyc|noemptyce|noemptycel|noemptycell|noemptycells|noo|noom|noomi|noomit|noomitt|noomitte|noomitted|nop|nopv|nopva|nopval|nopvalu|nopvalue|nopvalues|o|om|omi|omit|omitt|omitte|omitted|pl|plu|plus|se|sel|sele|seleg|selege|selegen|selegend|noci|nofv|nofvl|nofvla|nofvlab|nofvlabe|nofvlabel|noh|nohe|nohea|nohead|noheade|noheader|nols|nolst|nolstr|nolstre|nolstret|nolstretc|nolstretch|nof|nofi|nofir|nofirs|nofirst|ver|vers|versu|versus|verb|verbo|verbos|verbose|vsq|vsqu|vsqui|vsquis|vsquish)($|[ ])"
    local _hddid_estopt_syntax_follow ///
        "((if|in)($|[ ])|([[][^]]*[]]))"
    // Glued method() payloads are part of the malformed estimator token
    // itself. Catch them before the empty-assignment guards below, otherwise
    // estimator=method(...) collapses to estimator= and estimator=(...)method(...)
    // swallows later q()/seed() syntax into the public raw echo.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*method[ ]*[(][^)]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        if !regexm(`"`_hddid_raw'"', "=[ ]+method[ ]*[(]") {
            local _hddid_raw_pos = strpos( ///
                lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
            if `_hddid_raw_pos' > 0 {
                local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                    `_hddid_raw_pos', length(`"`_hddid_raw'"'))
            }
            return local invalid "1"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][^)]*[)][ ]*method[ ]*[(][^)]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_first `"`_hddid_raw'"'
        local _hddid_space = strpos(`"`_hddid_first'"', " ")
        if `_hddid_space' > 0 {
            local _hddid_first = substr(`"`_hddid_first'"', 1, `_hddid_space' - 1)
        }
        local _hddid_first_lc = lower(`"`_hddid_first'"')
        local _hddid_first_lc = subinstr(`"`_hddid_first_lc'"', char(34), "", .)
        local _hddid_first_lc = subinstr(`"`_hddid_first_lc'"', char(39), "", .)
        if regexm(`"`_hddid_first_lc'"', ///
            "^estimator[ ]*=[ ]*[(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)]$") {
            local _hddid_est_lc = lower(strtrim(regexs(1)))
            if strpos(`"`_hddid_first'"', char(34)) > 0 | ///
                strpos(`"`_hddid_first'"', char(39)) > 0 {
                return local invalid "1"
                return local raw `"`_hddid_first'"'
                return local form "assignment_parenthesized"
                exit
            }
            if inlist(`"`_hddid_est_lc'"', "r", "ra") {
                return local canonical "ra"
                return local raw `"`_hddid_first'"'
                return local form "assignment_parenthesized"
                exit
            }
            if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
                return local canonical "ipw"
                return local raw `"`_hddid_first'"'
                return local form "assignment_parenthesized"
                exit
            }
            if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
                return local canonical "aipw"
                return local raw `"`_hddid_first'"'
                return local form "assignment_parenthesized"
                exit
            }
        }
        if regexm(lower(`"`_hddid_first'"'), "^estimator[ ]*=[ ]*[(]") {
            return local invalid "1"
            return local raw `"`_hddid_first'"'
            return local form "assignment_parenthesized"
            exit
        }
        if !regexm(lower(`"`_hddid_raw'"'), "=[ ]+[(]") {
            return local invalid "1"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
    }
    // Preserve the full malformed assignment when estimator= is followed by
    // extra tokens. But if the first token after = is already a legal Stata
    // option (including legal abbreviations), then the estimator payload is
    // actually empty and the raw echo must stop at estimator=.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=)[ ]*((`_hddid_estopt_lparen_follow'))")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=)[ ]*((`_hddid_estopt_syntax_follow'))")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=)[ ]*((`_hddid_estopt_bare_follow'))")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    // A complete parenthesized estimator=(...) token should stand on its own
    // even when a real hddid option follows. Otherwise the generic
    // multi-token malformed-assignment branch swallows later method()/q()/...
    // text into the public estimator echo, even though those options are not
    // part of the estimator-family misuse.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)])[ ]+((`_hddid_estopt_lparen_follow')|(`_hddid_estopt_bare_follow'))")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = strtrim(regexs(3))
        local _hddid_est_lc = subinstr(`"`_hddid_est_lc'"', char(34), "", .)
        local _hddid_est_lc = subinstr(`"`_hddid_est_lc'"', char(39), "", .)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    // Later syntax fragments like if/in/[pw=...] are not part of the
    // malformed estimator=(...) token either, so keep the raw echo pinned to
    // estimator=(...) before the generic multi-token branch runs.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)])[ ]+(`_hddid_estopt_syntax_follow')")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = strtrim(regexs(3))
        local _hddid_est_lc = subinstr(`"`_hddid_est_lc'"', char(34), "", .)
        local _hddid_est_lc = subinstr(`"`_hddid_est_lc'"', char(39), "", .)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    // Quoted parenthesized estimator-family assignments should preserve the
    // quoted malformed token itself when a later real hddid option head like
    // method()/q()/seed()/... follows. Otherwise the generic multi-token
    // branch below swallows that later option into the public offending-token
    // echo instead of classifying the quoted token on its own.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][ ]*["][^"]*["][ ]*[)])[ ]+(method[ ]*[(][^)]*[)])"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*'[^']*'[ ]*[)])[ ]+(method[ ]*[(][^)]*[)])")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    // Quoted parenthesized alias assignments that are immediately followed by
    // method() belong to the same malformed estimator-style attempt. Keep the
    // full raw echo just like the existing unquoted parenthesized alias +
    // method() path; otherwise adding quotes changes the public contract by
    // clipping the later method() token away from the malformed input.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*["][^"]*["][ ]*[)][ ]+method[ ]*[(][^)]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*'[^']*'[ ]*[)][ ]+method[ ]*[(][^)]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    // Preserve exact raw echoes for quoted parenthesized alias assignments
    // before later quote-stripping. The unsupported switch is the alias head
    // itself (ra/ipw/aipw), not the quoted RHS payload, because HDDID exposes
    // one fixed AIPW estimator path and never publishes ra=/ipw=/aipw= as real
    // option domains. Therefore the parser should classify these malformed
    // inputs by the lhs alias head while preserving the exact raw token.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*["]([^"]*)["][ ]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_alias_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_alias_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*'([^']*)'[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_alias_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_alias_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    // Keep quoted parenthesized alias assignments with glued suffix text
    // intact before quote-stripping. Otherwise malformed alias tokens such as
    // ra=("ipw")foo or aipw=('ra')foo are rewritten to de-quoted echoes even
    // though the user supplied one quoted malformed estimator-family token.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*["][^"]*["][ ]*[)][^ ]+)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*'[^']*'[ ]*[)][^ ]+)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][ ]*["]([^"]*)["][ ]*[)])[ ]+(`_hddid_estopt_lparen_follow')"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*'([^']*)'[ ]*[)])[ ]+(`_hddid_estopt_lparen_follow')")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    // The simple quoted-alias branches above already preserve exact raw echoes
    // when a quoted alias token is followed by a space. Re-checking the same
    // shape against the full legal-follow bundles only adds redundant capture
    // groups and trips Stata's regex group limit on unrelated unquoted input.
    // But quoted parenthesized estimator=(...) tokens still need to preserve
    // canonical unsupported-switch guidance when the later token is really a
    // separate legal option head or syntax fragment.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*([^ ]+)[ ]+[^ ].*)$")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_first = lower(strtrim(regexs(3)))
        local _hddid_first = subinstr(`"`_hddid_first'"', char(34), "", .)
        local _hddid_first = subinstr(`"`_hddid_first'"', char(39), "", .)
        local _hddid_est_paren ""
        if regexm(`"`_hddid_first'"', ///
            "^[(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)]$") {
            local _hddid_est_paren = lower(strtrim(regexs(1)))
        }
        if !inlist(`"`_hddid_first'"', "r", "ra", "i", "ip", "ipw", ///
            "a", "ai", "aip", "aipw") {
            local _hddid_raw_pos = strpos( ///
                lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
            if `_hddid_raw_pos' > 0 {
                local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                    `_hddid_raw_pos', length(`"`_hddid_raw'"'))
            }
            if `"`_hddid_est_paren'"' != "" {
                local _hddid_space = strpos(`"`_hddid_raw'"', " ")
                if `_hddid_space' > 0 {
                    local _hddid_rest = ///
                        strtrim(substr(`"`_hddid_raw'"', `_hddid_space' + 1, .))
                    if regexm(lower(`"`_hddid_rest'"'), ///
                        "^(`_hddid_estopt_lparen_follow')") | ///
                        regexm(lower(`"`_hddid_rest'"'), ///
                        "^(`_hddid_estopt_bare_follow')") | ///
                        regexm(lower(`"`_hddid_rest'"'), ///
                        "^(`_hddid_estopt_syntax_follow')") {
                        local _hddid_raw = substr(`"`_hddid_raw'"', 1, ///
                            `_hddid_space' - 1)
                        if inlist(`"`_hddid_est_paren'"', "r", "ra") {
                            return local canonical "ra"
                            return local raw `"`_hddid_raw'"'
                            return local form "assignment_parenthesized"
                            exit
                        }
                        if inlist(`"`_hddid_est_paren'"', "i", "ip", "ipw") {
                            return local canonical "ipw"
                            return local raw `"`_hddid_raw'"'
                            return local form "assignment_parenthesized"
                            exit
                        }
                        if inlist(`"`_hddid_est_paren'"', "a", "ai", "aip", "aipw") {
                            return local canonical "aipw"
                            return local raw `"`_hddid_raw'"'
                            return local form "assignment_parenthesized"
                            exit
                        }
                    }
                }
            }
            return local invalid "1"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
    }
    // Preserve exact raw echoes for glued method() payloads nested inside a
    // malformed estimator-family token. These are not empty assignments
    // followed by a separate method() option: the user supplied one malformed
    // estimator token, so public guidance must preserve that exact token and
    // must not leak the internal method() masking sentinel below.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*method[ ]*[(][^)]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][^)]*[)][ ]*method[ ]*[(][^)]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][ ]*method[ ]*[(][^)]*[)][ ]*[)])([ ]|$)"')
    if `_hddid_match' {
        return local invalid "1"
        return local raw `"`=strtrim(regexs(2))'"'
        return local form "assignment_parenthesized"
        exit
    }
    // Bare parenthesized estimator(method(...)) tokens are malformed
    // estimator-family syntax in their own right. Preserve the exact token
    // before any later method() masking so nested method(...) text does not
    // leak sentinels or get reclassified as a real basis-family request.
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])(estimator[ ]*[(][ ]*method[ ]*[(][^)]*[)][ ]*[)])([ ]|$)"')
    if `_hddid_match' {
        return local invalid "1"
        return local raw `"`=strtrim(regexs(2))'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*method[ ]*[(][^)]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        if !regexm(`"`_hddid_raw'"', "=[ ]+method[ ]*[(]") {
            local _hddid_raw_pos = strpos( ///
                lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
            if `_hddid_raw_pos' > 0 {
                local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                    `_hddid_raw_pos', length(`"`_hddid_raw'"'))
            }
            return local invalid "1"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][^)]*[)][ ]*method[ ]*[(][^)]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_first `"`_hddid_raw'"'
        local _hddid_space = strpos(`"`_hddid_first'"', " ")
        if `_hddid_space' > 0 {
            local _hddid_first = substr(`"`_hddid_first'"', 1, `_hddid_space' - 1)
        }
        local _hddid_first_lc = lower(`"`_hddid_first'"')
        local _hddid_first_lc = subinstr(`"`_hddid_first_lc'"', char(34), "", .)
        local _hddid_first_lc = subinstr(`"`_hddid_first_lc'"', char(39), "", .)
        if regexm(`"`_hddid_first_lc'"', ///
            "^estimator[ ]*=[ ]*[(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)]$") {
            local _hddid_est_lc = lower(strtrim(regexs(1)))
            if strpos(`"`_hddid_first'"', char(34)) > 0 | ///
                strpos(`"`_hddid_first'"', char(39)) > 0 {
                return local invalid "1"
                return local raw `"`_hddid_first'"'
                return local form "assignment_parenthesized"
                exit
            }
            if inlist(`"`_hddid_est_lc'"', "r", "ra") {
                return local canonical "ra"
                return local raw `"`_hddid_first'"'
                return local form "assignment_parenthesized"
                exit
            }
            if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
                return local canonical "ipw"
                return local raw `"`_hddid_first'"'
                return local form "assignment_parenthesized"
                exit
            }
            if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
                return local canonical "aipw"
                return local raw `"`_hddid_first'"'
                return local form "assignment_parenthesized"
                exit
            }
        }
        if regexm(lower(`"`_hddid_first'"'), "^estimator[ ]*=[ ]*[(]") {
            return local invalid "1"
            return local raw `"`_hddid_first'"'
            return local form "assignment_parenthesized"
            exit
        }
        if !regexm(lower(`"`_hddid_raw'"'), "=[ ]+[(]") {
            return local invalid "1"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
    }
    // estimator-style token detection should not peek inside legitimate
    // option payloads like method(...), which the main syntax/method-domain
    // validation handles later using the option's own contract.
    local _hddid_opts_raw = ///
        regexr(`"`_hddid_opts_raw'"', ///
        "method[ ]*[(][^)]*[)]", "method(__hddid_method_payload__)")
    local _hddid_opts_raw_quoted = ///
        regexr(`"`_hddid_opts_raw_quoted'"', ///
        "method[ ]*[(][^)]*[)]", "method(__hddid_method_payload__)")
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        `"(^|[ ])estimator[ ]*=[ ]*["]([^"]*)["]([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(0))
        local _hddid_est_lc = lower(strtrim(regexs(2)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        "(^|[ ])estimator[ ]*=[ ]*'([^']*)'([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(0))
        local _hddid_est_lc = lower(strtrim(regexs(2)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    // Keep quoted nonparenthesized estimator assignments with glued suffix text
    // intact before quote-stripping. Otherwise estimator="ra"foo or
    // estimator='ipw'foo is rewritten to de-quoted estimator=rafoo /
    // estimator=ipwfoo in the public invalid-line echo.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*["][^"]*["][^ ]+)([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*'[^']*'[^ ]+)([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][ ]*["]([^"]*)["][ ]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(3)))
        // Preserve the user's exact token shape/case in the public error echo.
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*'([^']*)'[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][ ]*["][^"]*["][ ]*[)][^ ]+)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*'[^']*'[ ]*[)][^ ]+)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    // Preserve exact raw echoes for quoted parenthesized alias assignments
    // that carry glued suffix text. Otherwise tokens like ra=("ipw")foo or
    // ipw=('aipw')foo are rewritten to de-quoted alias text in public
    // guidance even though the caller supplied one malformed quoted token.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*["][^"]*["][ ]*[)][^ ]+)([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*'[^']*'[ ]*[)][^ ]+)([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    // Preserve exact raw echoes for quoted nonparenthesized alias assignments
    // before later quote-stripping. Otherwise ra='method(Pol)' or
    // ra="method(Pol)" is rewritten to de-quoted alias text, and the
    // internal method() masking sentinel can leak into public guidance even
    // though the caller supplied quoted malformed estimator-family input.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*["]([^"]*)["])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_alias_lc = lower(strtrim(regexs(3)))
        if inlist(`"`_hddid_alias_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*'([^']*)')([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_alias_lc = lower(strtrim(regexs(3)))
        if inlist(`"`_hddid_alias_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_alias_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    // Keep quoted nonparenthesized estimator assignments with glued suffix text
    // intact before quote-stripping. Otherwise estimator="ra"foo or
    // estimator='ipw'foo is rewritten to de-quoted estimator=rafoo /
    // estimator=ipwfoo in the public invalid-line echo.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*["][^"]*["][^ ]+)([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted_orig'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*'[^']*'[^ ]+)([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    // Keep quoted nonparenthesized estimator assignments with glued suffix
    // text intact before quote-stripping. Otherwise estimator="ra"foo or
    // estimator='ipw'foo is rewritten to de-quoted estimator=rafoo /
    // estimator=ipwfoo in the public invalid-line echo.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*["][^"]*["][^ ]+)([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*'[^']*'[^ ]+)([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(34), "", .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(39), "", .)
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*[(][ ]*[^)]*[)][^ ]+)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*[(][^)]*)$")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])estimator[ ]*[(][ ]*([^)]*)[ ]*[)]([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(0))
        local _hddid_est_lc = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "parenthesized"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*[^)]*[)][^ ]+)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = strtrim(regexs(3))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), `"`_hddid_raw'"')
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment_parenthesized"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment_parenthesized"
        exit
    }
    // An empty estimator= assignment must fail on the malformed estimator
    // token itself. The next legitimate command option (for example q() or
    // a bare switch like verbose) is not an estimator payload and must not
    // be swallowed into the raw echo. Respect Stata's legal option
    // abbreviations here too: estimator= alp(0.1) is still an empty
    // estimator assignment followed by alpha(), not a longer estimator token.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=)[ ]*((`_hddid_estopt_lparen_follow'))")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=)[ ]*((`_hddid_estopt_bare_follow'))")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*([^ ]+))")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_raw = strtrim(regexs(3))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), `"`_hddid_raw'"')
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if strpos(`"`_hddid_est_raw'"', "(") > 0 | ///
            strpos(`"`_hddid_est_raw'"', ")") > 0 {
            return local invalid "1"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        local _hddid_est_lc `"`_hddid_est_raw'"'
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=)[ ]*$")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator)[ ]*$")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "bare"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[(][ ]*)$")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[(][ ]*[^ )][^)]*)$")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[(][^)]*[)][^ ]+)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*([^ ]+))($|[ ])")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        local _hddid_payload ""
        local _hddid_eq = strpos(`"`_hddid_raw'"', "=")
        if `_hddid_eq' > 0 {
            local _hddid_payload = ///
                lower(strtrim(substr(`"`_hddid_raw'"', `_hddid_eq' + 1, .)))
        }
        // Alias-style estimator assignments (`ra=`, `ipw=`, `aipw=`) should
        // classify before any later bare parenthesized estimator token on the
        // RHS (for example `ra= a(0.1)`). Otherwise the parser rewrites the
        // user's malformed alias assignment into a different apparent token.
        // Still trim only when the RHS is truly the head of a separate legal
        // hddid option, bare switch, or Stata syntax fragment.
        local _hddid_alias_lparen_follow ///
            "^(c|cf|cfo|cfor|cform|cforma|cformat|ci|cit|city|cityp|citype|p|pf|pfo|pfor|pform|pforma|pformat|s|sf|sfo|sfor|sform|sforma|sformat|fvwr|fvwra|fvwrap|fvwrapo|fvwrapon|tr|tre|trea|treat|x|z|z0|k|l|le|lev|leve|level|m|me|met|meth|metho|method|q|alp|alph|alpha|pi|pih|piha|pihat|phi1|phi1h|phi1ha|phi1hat|phi0|phi0h|phi0ha|phi0hat|seed|sep|sepa|separ|separa|separat|separato|separator|depn|depna|depnam|depname|nb|nbo|nboo|nboot)[ ]*[(]"
        local _hddid_alias_bare_follow ///
            "^(ab|abb|abbr|abbre|abbrev|allb|allba|allbas|allbase|allbasel|allbasele|allbaselev|allbaseleve|allbaselevel|allbaselevels|b|be|bet|beta|basel|basele|baselev|baseleve|baselevel|baselevels|cns|cnsr|cnsre|cnsrep|cnsrepo|cnsrepor|cnsreport|cod|codi|codin|coding|coefl|coefle|coefleg|coeflege|coeflegen|coeflegend|com|comp|compa|compar|compare|e|ef|efo|efor|eform|empty|emptyc|emptyce|emptycel|emptycell|emptycells|f|fi|fir|firs|first|fu|ful|full|fullc|fullcn|fullcns|fullcnsr|fullcnsre|fullcnsrep|fullcnsrepo|fullcnsrepor|fullcnsreport|fvl|fvla|fvlab|fvlabe|fvlabel|ls|lst|lstr|lstre|lstret|lstretch|ma|mar|mark|markd|markdo|markdow|markdown|noa|noab|noabb|noabbr|noabbre|noabbrev|not|nota|notab|notabl|notable|noempty|noemptyc|noemptyce|noemptycel|noemptycell|noemptycells|noo|noom|noomi|noomit|noomitt|noomitte|noomitted|nop|nopv|nopva|nopval|nopvalu|nopvalue|nopvalues|o|om|omi|omit|omitt|omitte|omitted|pl|plu|plus|se|sel|sele|seleg|selege|selegen|selegend|noci|nofv|nofvl|nofvla|nofvlab|nofvlabe|nofvlabel|noh|nohe|nohea|nohead|noheade|noheader|nols|nolst|nolstr|nolstre|nolstret|nolstretc|nolstretch|nof|nofi|nofir|nofirs|nofirst|ver|vers|versu|versus|verb|verbo|verbos|verbose|vsq|vsqu|vsqui|vsquis|vsquish)($|[ ])"
        local _hddid_alias_syntax_follow ///
            "^((if|in)($|[ ])|([[][^]]*[]]))"
        if regexm(`"`_hddid_raw'"', "=[ ]+") & ( ///
            regexm(`"`_hddid_payload'"', `"`_hddid_alias_lparen_follow'"') | ///
            regexm(`"`_hddid_payload'"', `"`_hddid_alias_bare_follow'"') | ///
            regexm(`"`_hddid_payload'"', `"`_hddid_alias_syntax_follow'"')) {
            if `_hddid_eq' > 0 {
                local _hddid_raw = strtrim(substr(`"`_hddid_raw'"', 1, `_hddid_eq'))
            }
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    // Quoted parenthesized bare estimator-family tokens are the same
    // malformed replay/estimation switches as bare (ra)/(ipw)/(aipw). Classify
    // them before the generic syntax fallback so quotes do not downgrade a
    // fixed-AIPW contract violation into the generic "replay does not accept
    // options" message.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])(([(][ ]*["](r|ra|i|ip|ipw|a|ai|aip|aipw)["][ ]*[)]))([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(4)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "parenthesized"
            exit
        }
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])(([(][ ]*'(r|ra|i|ip|ipw|a|ai|aip|aipw)'[ ]*[)]))([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(4)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "parenthesized"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "parenthesized"
            exit
        }
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra)[ ]*[(][ ]*([^)]*)[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "ra"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((i|ip|ipw)[ ]*[(][ ]*([^)]*)[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "ipw"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((a|ai|aip|aipw)[ ]*[(][ ]*([^)]*)[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "aipw"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', "(^|[ ])((r|ra)[(][^ ]*[)]?)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        return local canonical "ra"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', "(^|[ ])((i|ip|ipw)[(][^ ]*[)]?)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        return local canonical "ipw"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', "(^|[ ])((a|ai|aip|aipw)[(][^ ]*[)]?)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        return local canonical "aipw"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', "(^|[ ])((r|ra)[ ]*=)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "ra"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', "(^|[ ])((i|ip|ipw)[ ]*=)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "ipw"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', "(^|[ ])((a|ai|aip|aipw)[ ]*=)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "aipw"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_bare'"', "(^|[ ])((r|ra))([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "ra"
        return local raw `"`_hddid_raw'"'
        return local form "bare"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_bare'"', "(^|[ ])((i|ip|ipw))([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "ipw"
        return local raw `"`_hddid_raw'"'
        return local form "bare"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_bare'"', "(^|[ ])((a|ai|aip|aipw))([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "aipw"
        return local raw `"`_hddid_raw'"'
        return local form "bare"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_bare'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[^ a-z0-9_(=][^ ]*)($|[ ])")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "bare"
        exit
    }
end

capture program drop _hddid_parse_estopt_sbridge
capture program drop _hddid_parse_estopt_rbridge
program define _hddid_parse_estopt_sbridge, sclass
    syntax , OPTSRAW(string asis)

    sreturn clear
    quietly _hddid_parse_estopt_core, optsraw(`optsraw')
    if `"`r(canonical)'"' != "" {
        sreturn local canonical `"`r(canonical)'"'
    }
    if `"`r(raw)'"' != "" {
        sreturn local raw `"`r(raw)'"'
    }
    if `"`r(form)'"' != "" {
        sreturn local form `"`r(form)'"'
    }
    if `"`r(invalid)'"' != "" {
        sreturn local invalid `"`r(invalid)'"'
    }
end

program define _hddid_parse_estopt_rbridge, rclass
    syntax , OPTSRAW(string asis)

    return clear
    quietly _hddid_parse_estopt_core, optsraw(`optsraw')
    if `"`r(canonical)'"' != "" {
        return local canonical `"`r(canonical)'"'
    }
    if `"`r(raw)'"' != "" {
        return local raw `"`r(raw)'"'
    }
    if `"`r(form)'"' != "" {
        return local form `"`r(form)'"'
    }
    if `"`r(invalid)'"' != "" {
        return local invalid `"`r(invalid)'"'
    }
end

program define _hddid_parse_estopt, sclass
    syntax , OPTSRAW(string asis)

    quietly _hddid_parse_estopt_rbridge, optsraw(`"`optsraw'"')
    quietly _hddid_parse_estopt_sbridge, optsraw(`"`optsraw'"')
end

capture program drop _hddid_parse_precomma_estexpr
program define _hddid_parse_precomma_estexpr, rclass
    syntax , RAW(string asis)

    return clear
    local _hddid_raw = strtrim(`"`raw'"')
    if `"`_hddid_raw'"' == "" {
        exit
    }

    quietly _hddid_parse_estopt_rbridge, optsraw(`"`_hddid_raw'"')
    if `"`r(invalid)'"' == "1" {
        return local invalid "1"
        return local raw `"`r(raw)'"'
        return local form `"`r(form)'"'
        exit
    }
    // A bare depvar named ra/ipw/aipw is legal before the comma. Only
    // precomma wrapper/assignment spellings should be reclassified here.
    if `"`r(canonical)'"' != "" & `"`r(form)'"' != "bare" {
        return local canonical `"`r(canonical)'"'
        return local raw `"`r(raw)'"'
        return local form `"`r(form)'"'
    }
end

capture program drop _hddid_show_estopt
capture program drop _hddid_show_estopt_safe
program define _hddid_show_estopt
    local _hddid_show_raw0 `"`0'"'
    local _hddid_show_trim0 = strtrim(`"`_hddid_show_raw0'"')
    if substr(`"`_hddid_show_trim0'"', 1, 1) == "," | ///
        strpos(`"`_hddid_show_trim0'"', "canonical(") > 0 | ///
        strpos(`"`_hddid_show_trim0'"', "form(") > 0 {
        syntax , CANONICAL(string) FORM(string) [RAW(string asis)]
    }
    else {
        local _hddid_positional `"`_hddid_show_trim0'"'
        local canonical ""
        local raw ""
        local form ""
        gettoken canonical _hddid_posrest : _hddid_positional
        local _hddid_posrest = strtrim(`"`_hddid_posrest'"')
        local _hddid_last_space = strrpos(`"`_hddid_posrest'"', " ")
        if `_hddid_last_space' > 0 {
            local raw = strtrim(substr(`"`_hddid_posrest'"', 1, `_hddid_last_space' - 1))
            local form = strtrim(substr(`"`_hddid_posrest'"', `_hddid_last_space' + 1, .))
        }
        foreach _hddid_posmac in canonical raw form {
            local _hddid_posval ``_hddid_posmac''
            if length(`"`_hddid_posval'"') >= 4 & ///
                substr(`"`_hddid_posval'"', 1, 2) == char(96) + char(34) & ///
                substr(`"`_hddid_posval'"', -2, 2) == char(34) + char(39) {
                local _hddid_posval = substr(`"`_hddid_posval'"', 3, length(`"`_hddid_posval'"') - 4)
            }
            if length(`"`_hddid_posval'"') >= 2 {
                local _hddid_posfirst = substr(`"`_hddid_posval'"', 1, 1)
                local _hddid_poslast = substr(`"`_hddid_posval'"', length(`"`_hddid_posval'"'), 1)
                if (`"`_hddid_posfirst'"' == char(34) & `"`_hddid_poslast'"' == char(34)) | ///
                    (`"`_hddid_posfirst'"' == char(39) & `"`_hddid_poslast'"' == char(39)) {
                    local _hddid_posval = substr(`"`_hddid_posval'"', 2, length(`"`_hddid_posval'"') - 2)
                }
            }
            local _hddid_posval = subinstr(`"`_hddid_posval'"', char(34) + char(34), char(34), .)
            local _hddid_posval = subinstr(`"`_hddid_posval'"', char(39) + char(39), char(39), .)
            local `_hddid_posmac' `"`_hddid_posval'"'
        }
    }

    local _hddid_disp `"`raw'"'
    if `"`_hddid_disp'"' == "" {
        local _hddid_disp `"`canonical'"'
    }
    local _hddid_disp = strtrim(`"`_hddid_disp'"')
    if `"`_hddid_disp'"' == "" {
        local _hddid_disp `"`canonical'"'
    }
    if length(`"`_hddid_disp'"') >= 2 {
        local _hddid_first = substr(`"`_hddid_disp'"', 1, 1)
        local _hddid_last = substr(`"`_hddid_disp'"', length(`"`_hddid_disp'"'), 1)
        if `"`_hddid_first'"' == char(34) & `"`_hddid_last'"' == char(34) {
            local _hddid_disp = substr(`"`_hddid_disp'"', 2, length(`"`_hddid_disp'"') - 2)
        }
    }
    local _hddid_disp = subinstr(`"`_hddid_disp'"', char(34) + char(34), char(34), .)
    local _hddid_rawshape `"`_hddid_disp'"'

    if `"`form'"' == "bare" {
        di as error "{bf:hddid}: estimator-style options are not supported as bare switches: " ///
            as text `"`_hddid_disp'"'
    }
    else if `"`form'"' == "assignment_parenthesized" {
        if strpos(`"`_hddid_rawshape'"', "=") > 0 {
            di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
                as text `"`_hddid_rawshape'"'
        }
        else {
            local _hddid_assign_disp `"estimator=(`_hddid_disp')"'
            di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
                as text `"`_hddid_assign_disp'"'
        }
    }
    else if `"`form'"' == "assignment" {
        if strpos(`"`_hddid_rawshape'"', "=") > 0 {
            di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
                as text `"`_hddid_rawshape'"'
        }
        else {
            local _hddid_assign_disp `"estimator=`_hddid_disp'"'
            di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
                as text `"`_hddid_assign_disp'"'
        }
    }
    else {
        di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
            as text `"`_hddid_disp'"'
    }
    di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
    di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
    di as error "  Use {bf:method(Pol)} or {bf:method(Tri)} to choose the sieve basis family"
end

program define _hddid_show_estopt_safe
    syntax , CANONICAL(string) FORM(string) [RAW(string asis)]

    local _hddid_disp `"`raw'"'
    if `"`_hddid_disp'"' == "" {
        local _hddid_disp `"`canonical'"'
    }
    local _hddid_disp = strtrim(`"`_hddid_disp'"')
    if `"`_hddid_disp'"' == "" {
        local _hddid_disp `"`canonical'"'
    }
    if length(`"`_hddid_disp'"') >= 2 {
        local _hddid_first = substr(`"`_hddid_disp'"', 1, 1)
        local _hddid_last = substr(`"`_hddid_disp'"', length(`"`_hddid_disp'"'), 1)
        if `"`_hddid_first'"' == char(34) & `"`_hddid_last'"' == char(34) {
            local _hddid_disp = substr(`"`_hddid_disp'"', 2, length(`"`_hddid_disp'"') - 2)
        }
    }
    local _hddid_disp = subinstr(`"`_hddid_disp'"', char(34) + char(34), char(34), .)
    local _hddid_rawshape `"`_hddid_disp'"'

    if `"`form'"' == "bare" {
        di as error "{bf:hddid}: estimator-style options are not supported as bare switches: " ///
            as text `"`_hddid_disp'"'
    }
    else if `"`form'"' == "assignment_parenthesized" {
        if strpos(`"`_hddid_rawshape'"', "=") > 0 {
            di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
                as text `"`_hddid_rawshape'"'
        }
        else {
            local _hddid_assign_disp `"estimator=(`_hddid_disp')"'
            di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
                as text `"`_hddid_assign_disp'"'
        }
    }
    else if `"`form'"' == "assignment" {
        if strpos(`"`_hddid_rawshape'"', "=") > 0 {
            di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
                as text `"`_hddid_rawshape'"'
        }
        else {
            local _hddid_assign_disp `"estimator=`_hddid_disp'"'
            di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
                as text `"`_hddid_assign_disp'"'
        }
    }
    else {
        di as error "{bf:hddid}: estimator-style options are not supported as bare switches or options: " ///
            as text `"`_hddid_disp'"'
    }
    di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
    di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
    di as error "  Use {bf:method(Pol)} or {bf:method(Tri)} to choose the sieve basis family"
end

capture program drop _hddid_show_invalid_estopt
program define _hddid_show_invalid_estopt
    syntax , RAW(string asis)

    local _hddid_disp `"`raw'"'
    if length(`"`_hddid_disp'"') >= 4 & ///
        substr(`"`_hddid_disp'"', 1, 2) == char(96) + char(34) & ///
        substr(`"`_hddid_disp'"', -2, 2) == char(34) + char(39) {
        local _hddid_disp = ///
            substr(`"`_hddid_disp'"', 3, length(`"`_hddid_disp'"') - 4)
    }
    local _hddid_disp = ///
        subinstr(`"`_hddid_disp'"', char(92) + char(34), char(34), .)
    local _hddid_disp = ///
        subinstr(`"`_hddid_disp'"', char(92) + char(39), char(39), .)
    local _hddid_disp = strtrim(`"`_hddid_disp'"')
    if `"`_hddid_disp'"' == "" {
        local _hddid_disp `"`raw'"'
    }

    di as error "{bf:hddid}: invalid estimator-style option value: " ///
        as text `"`_hddid_disp'"'
    di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
    di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
    di as error "  Use {bf:method(Pol)} or {bf:method(Tri)} to choose the sieve basis family"
end

capture program drop _hddid_show_esttoken
capture program drop _hddid_show_esttoken_safe
program define _hddid_show_esttoken
    local token `"`0'"'

    local _hddid_disp `"`token'"'
    if length(`"`_hddid_disp'"') >= 4 & ///
        substr(`"`_hddid_disp'"', 1, 2) == char(96) + char(34) & ///
        substr(`"`_hddid_disp'"', -2, 2) == char(34) + char(39) {
        local _hddid_disp = ///
            substr(`"`_hddid_disp'"', 3, length(`"`_hddid_disp'"') - 4)
    }
    local _hddid_disp = strtrim(`"`_hddid_disp'"')
    if `"`_hddid_disp'"' == "" {
        local _hddid_disp `"`token'"'
    }

    di as error "{bf:hddid}: estimator-style tokens are not supported as positional arguments: " ///
        as text `"`_hddid_disp'"'
    di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
    di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
    di as error "  Use syntax {bf:hddid depvar, treat(...) x(...) z(...)} with {bf:method(Pol)} or {bf:method(Tri)} only"
end

program define _hddid_show_esttoken_safe
    syntax , RAW(string asis)

    local _hddid_raw `"`raw'"'
    local _hddid_disp `"`_hddid_raw'"'
    if length(`"`_hddid_disp'"') >= 4 & ///
        substr(`"`_hddid_disp'"', 1, 2) == char(96) + char(34) & ///
        substr(`"`_hddid_disp'"', -2, 2) == char(34) + char(39) {
        local _hddid_disp = ///
            substr(`"`_hddid_disp'"', 3, length(`"`_hddid_disp'"') - 4)
    }
    local _hddid_disp = strtrim(`"`_hddid_disp'"')
    if `"`_hddid_disp'"' == "" {
        local _hddid_disp `"`_hddid_raw'"'
    }

    // Bare single-quoted tokens like 'ra' must be reported as data, not fed
    // back through a nested helper call that Stata reparses as command text.
    di as error "{bf:hddid}: estimator-style tokens are not supported as positional arguments: " ///
        as text `"`_hddid_disp'"'
    di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
    di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
    di as error "  Use syntax {bf:hddid depvar, treat(...) x(...) z(...)} with {bf:method(Pol)} or {bf:method(Tri)} only"
end

capture program drop _hddid_estbefore_method
program define _hddid_estbefore_method, rclass
    syntax , PRECOMMA(string asis) [METHODRAW(string asis)]

    return clear
    local _hddid_precomma_raw = strtrim(`precomma')
    if `"`_hddid_precomma_raw'"' == "" {
        exit
    }

    local _hddid_method_raw = strtrim(`methodraw')
    local _hddid_precomma_lc = lower(`"`_hddid_precomma_raw'"')
    local _hddid_method_pos = 0
    if `"`_hddid_method_raw'"' != "" {
        local _hddid_method_pos = strpos(`"`_hddid_precomma_lc'"', ///
            lower(`"`_hddid_method_raw'"'))
    }
    if `_hddid_method_pos' <= 0 {
        if regexm(`"`_hddid_precomma_raw'"', ///
            "([Mm][Ee][Tt][Hh][Oo][Dd][ ]*[(][^)]*[)])") {
            local _hddid_method_raw = regexs(1)
            local _hddid_method_pos = strpos(`"`_hddid_precomma_lc'"', ///
                lower(`"`_hddid_method_raw'"'))
        }
    }
    if `_hddid_method_pos' <= 1 {
        exit
    }

    local _hddid_before_method = ///
        strtrim(substr(`"`_hddid_precomma_raw'"', 1, `_hddid_method_pos' - 1))
    if `"`_hddid_before_method'"' == "" {
        exit
    }

    local _hddid_probe_raw ""
    local _hddid_probe_lc ""
    local _hddid_dq = char(34)
    local _hddid_last_char = substr(`"`_hddid_before_method'"', -1, 1)
    if `"`_hddid_last_char'"' == `"`_hddid_dq'"' {
        local _hddid_before_last = ///
            substr(`"`_hddid_before_method'"', 1, ///
            length(`"`_hddid_before_method'"') - 1)
        local _hddid_quote_pos = ///
            strrpos(`"`_hddid_before_last'"', `"`_hddid_last_char'"')
        if `_hddid_quote_pos' > 0 {
            local _hddid_prefix_raw = ///
                substr(`"`_hddid_before_method'"', 1, `_hddid_quote_pos' - 1)
            if strtrim(`"`_hddid_prefix_raw'"') == "" | ///
                substr(`"`_hddid_prefix_raw'"', -1, 1) == " " {
                local _hddid_probe_raw = ///
                    substr(`"`_hddid_before_method'"', `_hddid_quote_pos', .)
                local _hddid_probe_lc = lower(strtrim(substr( ///
                    `"`_hddid_probe_raw'"', 2, ///
                    length(`"`_hddid_probe_raw'"') - 2)))
            }
        }
    }
    if `"`_hddid_probe_raw'"' == "" {
        local _hddid_space = strrpos(`"`_hddid_before_method'"', " ")
        if `_hddid_space' > 0 {
            local _hddid_probe_raw = ///
                substr(`"`_hddid_before_method'"', `_hddid_space' + 1, .)
        }
        else {
            local _hddid_probe_raw `"`_hddid_before_method'"'
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
        local _hddid_probe_norm = ///
            strtrim(substr(`"`_hddid_probe_norm'"', 2, ///
            length(`"`_hddid_probe_norm'"') - 2))
        local _hddid_probe_norm = ///
            subinstr(`"`_hddid_probe_norm'"', char(34), "", .)
        local _hddid_probe_norm = ///
            subinstr(`"`_hddid_probe_norm'"', char(39), "", .)
        local _hddid_probe_norm = strtrim(`"`_hddid_probe_norm'"')
    }

    if inlist(`"`_hddid_probe_norm'"', "r", "ra") {
        return local canonical "ra"
        return local raw `"`_hddid_probe_raw'"'
        exit
    }
    if inlist(`"`_hddid_probe_norm'"', "i", "ip", "ipw") {
        return local canonical "ipw"
        return local raw `"`_hddid_probe_raw'"'
        exit
    }
    if inlist(`"`_hddid_probe_norm'"', "a", "ai", "aip", "aipw") {
        return local canonical "aipw"
        return local raw `"`_hddid_probe_raw'"'
        exit
    }
end

capture program drop _hddid_trailing_esttoken
program define _hddid_trailing_esttoken, rclass
    syntax , PRECOMMA(string asis)

    return clear
    local _hddid_last ""
    tokenize `precomma'
    local _hddid_i 1
    while `"``_hddid_i''"' != "" {
        local _hddid_last `"``_hddid_i''"'
        local ++_hddid_i
    }

    local _hddid_last_raw = strtrim(`"`_hddid_last'"')
    local _hddid_last_lc = lower(strtrim(`"`_hddid_last'"'))
    if inlist(`"`_hddid_last_lc'"', "r", "ra") {
        return local canonical "ra"
        return local raw `"`_hddid_last_raw'"'
    }
    else if inlist(`"`_hddid_last_lc'"', "i", "ip", "ipw") {
        return local canonical "ipw"
        return local raw `"`_hddid_last_raw'"'
    }
    else if inlist(`"`_hddid_last_lc'"', "a", "ai", "aip", "aipw") {
        return local canonical "aipw"
        return local raw `"`_hddid_last_raw'"'
    }
end

capture program drop hddid
capture program drop _hddid_estimate
capture program drop _hddid_display
program define _hddid_load_estimate_sidecar
    syntax , PATH(string)

    local _had_estimates 0
    tempname _hold_est

    if `"`e(cmd)'"' != "" {
        local _had_estimates 1
        quietly estimates store `_hold_est', copy
    }

    capture program drop _hddid_estimate
    capture noisily run "`path'"
    local _estimate_run_rc = _rc
    local _estimate_prog_rc = .
    if `_estimate_run_rc' == 0 {
        // Estimation must bind to the exact sibling sidecar just loaded above.
        // A bare _hddid_estimate call can otherwise autoload a different
        // adopath copy after source-run and mix bundles on the entry path.
        capture program list _hddid_estimate
        local _estimate_prog_rc = _rc
    }

    if `_estimate_run_rc' != 0 {
        if `_had_estimates' {
            quietly estimates restore `_hold_est'
        }
        else {
            quietly ereturn clear
        }
        di as error "{bf:hddid}: failed to load {bf:_hddid_estimate.ado}"
        di as error "  Expected sibling file: `path'"
        di as error "  Reason: command entry must source the exact estimation-sidecar contract from the active hddid bundle"
        exit 198
    }

    if `_estimate_prog_rc' != 0 {
        if `_had_estimates' {
            quietly estimates restore `_hold_est'
        }
        else {
            quietly ereturn clear
        }
        di as error "{bf:hddid}: sibling {bf:_hddid_estimate.ado} does not define a valid {bf:_hddid_estimate} estimation helper"
        di as error "  Expected sibling file: `path'"
        di as error "  Reason: source-loading the resolved sibling estimation file did not leave an in-memory {bf:_hddid_estimate} program, so command entry refuses to autoload a different adopath copy"
        di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
        exit 198
    }

    if `_had_estimates' {
        quietly estimates restore `_hold_est'
    }
    else {
        quietly ereturn clear
    }
end

program define _hddid_load_display_sidecar
    syntax , PATH(string)

    local _had_estimates 0
    tempname _hold_est

    if `"`e(cmd)'"' != "" {
        local _had_estimates 1
        quietly estimates store `_hold_est', copy
    }

    capture program drop _hddid_display
    capture noisily run "`path'"
    local _display_run_rc = _rc
    local _display_prog_rc = .
    if `_display_run_rc' == 0 {
        // Replay must bind to the exact sibling sidecar just loaded above.
        // A bare _hddid_display call can otherwise autoload a different
        // adopath copy after source-run and mask a malformed sibling file.
        capture program list _hddid_display
        local _display_prog_rc = _rc
    }

    if `_display_run_rc' != 0 {
        if `_had_estimates' {
            quietly estimates restore `_hold_est'
        }
        else {
            quietly ereturn clear
        }
        di as error "{bf:hddid}: failed to load {bf:_hddid_display.ado}"
        di as error "  Expected sibling file: `path'"
        di as error "  Reason: replay must source the exact display-sidecar contract from the active hddid bundle"
        exit 198
    }

    if `_display_prog_rc' != 0 {
        if `_had_estimates' {
            quietly estimates restore `_hold_est'
        }
        else {
            quietly ereturn clear
        }
        di as error "{bf:hddid}: sibling {bf:_hddid_display.ado} does not define a valid {bf:_hddid_display} replay helper"
        di as error "  Expected sibling file: `path'"
        di as error "  Reason: source-loading the resolved sibling display file did not leave an in-memory {bf:_hddid_display} program, so replay refuses to autoload a different adopath copy"
        di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
        exit 198
    }

    if `_had_estimates' {
        quietly estimates restore `_hold_est'
    }
end

program define _hddid_pfb
    version 16
    di as error "{bf:hddid}: predict is not supported."
    di as error "  Reason: hddid posts debiased estimates and confidence objects for beta and the omitted-intercept z-varying surface"
    di as error "  on the stored evaluation grid, but it does not define observation-level fitted values."
    di as error "  Inspect {bf:e(CIpoint)} for the published pointwise intervals and {bf:e(CIuniform)} for the published nonparametric interval object."
    exit 198
end

program define _hddid_validate_predict_stub, rclass
    return clear
    syntax , PATH(string)

    local _had_estimates 0
    tempname _hold_est

    if `"`e(cmd)'"' != "" {
        local _had_estimates 1
        quietly estimates store `_hold_est', copy
    }

    quietly ereturn clear
    capture program drop hddid_p

    capture noisily run "`path'"
    local _stub_run_rc = _rc
    local _stub_fallback_used 0
    local _stub_prog_name "hddid_p"
    local _stub_prog_rc = .
    local _stub_call_rc = .
    if `_stub_run_rc' == 1000 {
        local _stub_fallback_used 1
        local _stub_run_rc = 0
        local _stub_prog_name "_hddid_pfb"
        capture program list `_stub_prog_name'
        local _stub_prog_rc = _rc
        if `_stub_prog_rc' == 0 {
            capture `_stub_prog_name'
            local _stub_call_rc = _rc
        }
    }
    else if `_stub_run_rc' == 0 {
        // Validate the exact sibling file loaded above. A bare hddid_p call
        // can autoload a different adopath copy after source-run, which would
        // mask a malformed sibling file instead of fail-closing.
        capture program list `_stub_prog_name'
        local _stub_prog_rc = _rc
        if `_stub_prog_rc' == 0 {
            // Current unsupported-postestimation stubs fail closed with rc=198
            // plus guidance when no active hddid results are available.
            capture `_stub_prog_name'
            local _stub_call_rc = _rc
        }
        if `_stub_call_rc' != 198 {
            local _stub_fallback_used 1
            local _stub_prog_name "_hddid_pfb"
            capture program list `_stub_prog_name'
            local _stub_prog_rc = _rc
            if `_stub_prog_rc' == 0 {
                capture `_stub_prog_name'
                local _stub_call_rc = _rc
            }
        }
    }

    if `_had_estimates' {
        quietly estimates restore `_hold_est'
    }
    else {
        quietly ereturn clear
    }

    if `_stub_run_rc' != 0 {
        di as error "{bf:hddid}: failed to load {bf:hddid_p.ado}"
        di as error "  Expected sibling file: `path'"
        di as error "  Reason: the published predict() stub could not be compiled from the package directory"
        exit 198
    }

    if `_stub_prog_rc' != 0 {
        di as error "{bf:hddid}: sibling {bf:hddid_p.ado} does not define a valid {bf:hddid_p} postestimation stub"
        di as error "  Expected sibling file: `path'"
        if `_stub_fallback_used' {
            di as error "  Reason: the system-limit fallback did not leave an in-memory {bf:hddid_p} program"
        }
        else if `_stub_fallback_used' {
            di as error "  Reason: the source-loaded sibling stub did not satisfy the bare fail-close contract, and the fallback stub also failed validation"
        }
        else {
            di as error "  Reason: source-loading the resolved sibling file did not leave an in-memory {bf:hddid_p} program, so validation refuses to autoload a different adopath copy"
        }
        di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
        exit 198
    }

    if `_stub_call_rc' != 198 {
        di as error "{bf:hddid}: sibling {bf:hddid_p.ado} does not define a valid {bf:hddid_p} postestimation stub"
        di as error "  Expected sibling file: `path'"
        if `_stub_fallback_used' {
            di as error "  Reason: the system-limit fallback hddid_p must still reject validation without active hddid estimates under the current unsupported-postestimation contract (expected rc=198, got rc=`_stub_call_rc')"
        }
        else if `_stub_fallback_used' {
            di as error "  Reason: the source-loaded sibling stub did not satisfy the bare fail-close contract, and the fallback hddid_p stub also failed validation (expected rc=198, got rc=`_stub_call_rc')"
        }
        else {
            di as error "  Reason: a healthy hddid_p must be callable and reject validation without active hddid estimates under the current unsupported-postestimation contract (expected rc=198, got rc=`_stub_call_rc')"
        }
        di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
        exit 198
    }
    return local stubname "`_stub_prog_name'"
end

program define _hddid_validate_estat_stub
    syntax , PATH(string)

    local _had_estimates 0
    tempname _hold_est

    if `"`e(cmd)'"' != "" {
        local _had_estimates 1
        quietly estimates store `_hold_est', copy
    }

    quietly ereturn clear
    capture program drop hddid_estat

    capture noisily run "`path'"
    local _stub_run_rc = _rc
    local _stub_prog_rc = .
    local _stub_call_rc = .
    if `_stub_run_rc' == 0 {
        // Validate the exact sibling file loaded above. A bare hddid_estat
        // call can autoload a different adopath copy after source-run, which
        // would mask a malformed sibling file instead of fail-closing.
        capture program list hddid_estat
        local _stub_prog_rc = _rc
        if `_stub_prog_rc' == 0 {
            // Current unsupported-postestimation stubs fail closed with rc=198
            // plus guidance when no active hddid results are available.
            capture hddid_estat
            local _stub_call_rc = _rc
        }
    }

    if `_had_estimates' {
        quietly estimates restore `_hold_est'
    }
    else {
        quietly ereturn clear
    }

    if `_stub_run_rc' != 0 {
        di as error "{bf:hddid}: failed to load {bf:hddid_estat.ado}"
        di as error "  Expected sibling file: `path'"
        di as error "  Reason: the published estat stub could not be compiled from the package directory"
        exit 198
    }

    if `_stub_prog_rc' != 0 {
        di as error "{bf:hddid}: sibling {bf:hddid_estat.ado} does not define a valid {bf:hddid_estat} postestimation stub"
        di as error "  Expected sibling file: `path'"
        di as error "  Reason: source-loading the resolved sibling file did not leave an in-memory {bf:hddid_estat} program, so validation refuses to autoload a different adopath copy"
        di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
        exit 198
    }

    if `_stub_call_rc' != 198 {
        di as error "{bf:hddid}: sibling {bf:hddid_estat.ado} does not define a valid {bf:hddid_estat} postestimation stub"
        di as error "  Expected sibling file: `path'"
        di as error "  Reason: a healthy hddid_estat must be callable and reject validation without active hddid estimates under the current unsupported-postestimation contract (expected rc=198, got rc=`_stub_call_rc')"
        di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
        exit 198
    }
end

program define _hddid_publish_results, eclass
    syntax , B(name) V(name) XDEBIAS(name) GDEBIAS(name) STDX(name) ///
        STDG(name) TC(name) CIPOINT(name) CIUNIFORM(name) ///
        ESAMPLE(varname) NFINAL(integer) NPRETRIM(integer) ///
        NOUTER(integer) K(integer) P(integer) Q(integer) QQ(integer) ///
        ALPHA(real) NBOOT(string) NTRIMMED(integer) ///
        SECONDSTAGE(integer) MMATRIX(integer) CLIMEMAX(integer) ///
        XVARS(string asis) ZGRID(string asis) NPERFOLD(string asis) ///
        CLIMEEFF(string asis) METHOD(string) DEPVARROLE(string) ///
        TREATVAR(string) ZVAR(string) CMDLINE(string asis) ORIGORDER(varname) ///
        FIRSTSTAGE(string) ///
        PROPENSITY(integer) OUTCOME(integer) SEED(string) ///
        ZSUPPORTMIN(real) ZSUPPORTMAX(real) [PREDICTSTUB(string)]

    local firststage = lower(strtrim(`"`firststage'"'))
    // Internal producer calls sometimes pass string options with explicit
    // quote wrappers. Those wrappers do not change the realized role/fold
    // metadata and should not trigger spurious posting-time contract failures.
    local depvar_display = ///
        strtrim(subinstr(subinstr(`"`depvarrole'"', char(34), "", .), ///
        char(39), "", .))
    if `"`depvar_display'"' == "" {
        di as error "{bf:hddid}: internal result posting requires nonblank depvarrole()"
        di as error "  Reason: current hddid results publish {bf:e(depvar)} = {bf:beta} as the generic parametric block label, so posting must also preserve the original outcome-role mapping in {bf:e(depvar_role)} before replay/postestimation can interpret the saved surface"
        di as error "  Posting found blank depvarrole()"
        exit 498
    }
    local treatvar = ///
        strtrim(subinstr(subinstr(`"`treatvar'"', char(34), "", .), ///
        char(39), "", .))
    if `"`treatvar'"' == "" {
        di as error "{bf:hddid}: internal result posting requires nonblank treatvar()"
        di as error "  Reason: current hddid results publish the treatment-role mapping in {bf:e(treat)}, so posting must fail closed before replay/postestimation consume blank machine-readable role metadata"
        di as error "  Posting found blank treatvar()"
        exit 498
    }
    local zvar = ///
        strtrim(subinstr(subinstr(`"`zvar'"', char(34), "", .), ///
        char(39), "", .))
    if `"`zvar'"' == "" {
        di as error "{bf:hddid}: internal result posting requires nonblank zvar()"
        di as error "  Reason: current hddid results publish the running-variable role mapping in {bf:e(zvar)}, so posting must fail closed before replay/postestimation consume blank machine-readable role metadata"
        di as error "  Posting found blank zvar()"
        exit 498
    }
    local xvars = ///
        strtrim(subinstr(subinstr(`"`xvars'"', char(34), "", .), ///
        char(39), "", .))
    local predictstub = strtrim(`"`predictstub'"')
    if `"`predictstub'"' == "" {
        local predictstub "hddid_p"
    }
    if `"`xvars'"' == "" {
        di as error "{bf:hddid}: internal result posting requires nonblank xvars()"
        di as error "  Reason: current hddid results publish the parametric block labels in {bf:e(xvars)}, so posting must fail closed before replay/postestimation consume unlabeled beta coordinates"
        di as error "  Posting found blank xvars()"
        exit 498
    }
    local cmdline = strtrim(`"`cmdline'"')
    mata: st_local("__hddid_cmdline_norm", ///
        subinstr(subinstr(st_local("cmdline"), char(96) + char(34), char(34)), ///
        char(34) + char(39), char(34)))
    local cmdline `"`__hddid_cmdline_norm'"'
    macro drop __hddid_cmdline_norm
    if substr(`"`cmdline'"', 1, 1) == char(34) & ///
        substr(`"`cmdline'"', length(`"`cmdline'"'), 1) == char(34) & ///
        length(`"`cmdline'"') >= 2 {
        local cmdline = substr(`"`cmdline'"', 2, length(`"`cmdline'"') - 2)
    }
    local cmdline = strtrim(`"`cmdline'"')
    local nperfold = ///
        strtrim(subinstr(subinstr(`"`nperfold'"', char(34), "", .), ///
        char(39), "", .))
    local climeeff = ///
        strtrim(subinstr(subinstr(`"`climeeff'"', char(34), "", .), ///
        char(39), "", .))
    local _publish_xvars_count : word count `xvars'
    local _publish_xvars_distinct `"`xvars'"'
    local _publish_xvars_distinct : list uniq _publish_xvars_distinct
    local _publish_xvars_distinct_count : word count `_publish_xvars_distinct'
    if `_publish_xvars_count' != `p' | ///
        `_publish_xvars_distinct_count' != `p' {
        di as error "{bf:hddid}: internal result posting requires exactly p distinct xvars() labels"
        di as error "  Reason: the published beta/xdebias/V coordinates must map one-to-one onto the paper's p-dimensional X block before replay/postestimation can interpret the saved parametric surface"
        di as error "  Posting found p() = " %9.0g `p' ///
            ", xvars() supplied `_publish_xvars_count' label(s), and only `_publish_xvars_distinct_count' distinct label(s)"
        exit 498
    }
    if !inlist(`"`firststage'"', "internal", "nofirst") {
        di as error "{bf:hddid}: internal result posting requires firststage() = internal or nofirst"
        di as error "  Reason: current HDDID results publish a machine-readable nuisance-path provenance label with domain {bf:internal}/{bf:nofirst} only"
        di as error "  Posting found firststage() = {bf:`firststage'}"
        exit 498
    }
    local method = strtrim(`"`method'"')
    if !inlist(`"`method'"', "Pol", "Tri") {
        di as error "{bf:hddid}: internal result posting requires method() equal to Pol or Tri"
        di as error "  Reason: the published {bf:e(method)} metadata identifies the paper's sieve-basis family, so only {bf:Pol} and {bf:Tri} are interpretable posted result surfaces"
        di as error "  Posting found method() = {bf:`method'}"
        exit 498
    }
    if `"`cmdline'"' != "" {
        local _cmdline_parse_fstage_pub `"`cmdline'"'
        local _cmdline_parse_fstage_pub = ///
            subinstr(`"`_cmdline_parse_fstage_pub'"', char(9), " ", .)
        local _cmdline_parse_fstage_pub = ///
            subinstr(`"`_cmdline_parse_fstage_pub'"', char(10), " ", .)
        local _cmdline_parse_fstage_pub = ///
            subinstr(`"`_cmdline_parse_fstage_pub'"', char(13), " ", .)
        local _cmdline_lc_fstage_pub = ///
            lower(`"`_cmdline_parse_fstage_pub'"')
        local _cmdline_opts_fstage_pub ""
        local _cmdline_comma_fstage_pub = ///
            strpos(`"`_cmdline_lc_fstage_pub'"', ",")
        if `_cmdline_comma_fstage_pub' > 0 {
            local _cmdline_opts_fstage_pub = ///
                strtrim(substr(`"`_cmdline_lc_fstage_pub'"', ///
                `_cmdline_comma_fstage_pub' + 1, .))
        }
        local _cmdline_has_nofirst_fstage_pub = ///
            regexm(`"`_cmdline_opts_fstage_pub'"', ///
            "(^|[ ,])nof(i(r(s(t)?)?)?)?([ ,]|$)")
        local _mode_says_nofirst_fstage_pub = ///
            (`"`firststage'"' == "nofirst")
        if `_cmdline_has_nofirst_fstage_pub' != ///
            `_mode_says_nofirst_fstage_pub' {
            di as error "{bf:hddid}: stored firststage() must agree with whether cmdline() uses nofirst"
            di as error "  Posting found firststage() = {bf:`firststage'} but {bf:cmdline()} = {bf:`cmdline'}"
            di as error "  Reason: one current HDDID result surface corresponds to exactly one nuisance-path classification, so producer-side posting cannot publish contradictory machine-readable and successful-call first-stage provenance."
            exit 498
        }
    }
    if `"`propensity'"' == "" local propensity 0
    if `"`outcome'"' == "" local outcome 0
    local seed_input `"`seed'"'
    if `"`seed_input'"' == "" {
        local seed -1
    }
    else {
        capture confirm number `seed_input'
        if _rc != 0 {
            di as error "{bf:hddid}: internal result posting requires seed() equal to -1 or an integer in [0, 2147483647]"
            di as error "  Reason: the published RNG provenance contract only suppresses {bf:e(seed)} via seed(-1); any other posting-time seed value must already be valid before replay/postestimation consume it"
            di as error "  Posting found seed() = {bf:`seed_input'}"
            exit 498
        }
        local seed = real(`"`seed_input'"')
    }
    if `"`zsupportmin'"' == "" local zsupportmin .
    if `"`zsupportmax'"' == "" local zsupportmax .
    if missing(`seed') | `seed' < -1 | `seed' > 2147483647 | ///
        `seed' != floor(`seed') {
        di as error "{bf:hddid}: internal result posting requires seed() equal to -1 or an integer in [0, 2147483647]"
        di as error "  Reason: the published RNG provenance contract only suppresses {bf:e(seed)} via seed(-1); any other posting-time seed value must already be valid before replay/postestimation consume it"
        di as error "  Posting found seed() = " %12.8g `seed'
        exit 498
    }
    if `"`method'"' == "Tri" & ///
        (missing(`zsupportmin') | missing(`zsupportmax') | ///
        `zsupportmin' >= `zsupportmax') {
        di as error "{bf:hddid}: internal result posting requires finite Tri support endpoints"
        di as error "  Reason: method(Tri) stores the support-normalized basis, so current posted results must satisfy z_support_min < z_support_max before replay/postestimation can interpret the saved surface"
        di as error "  Posting found zsupportmin() = " %12.8g `zsupportmin' ///
            " and zsupportmax() = " %12.8g `zsupportmax'
        exit 498
    }
    if missing(`q') | `q' < 1 | `q' != floor(`q') {
        di as error "{bf:hddid}: internal result posting requires q() >= 1"
        di as error "  Reason: the published sieve basis order must be a positive integer before replay/postestimation can interpret the saved parametric/nonparametric surface"
        di as error "  Posting found q() = " %9.0g `q'
        exit 498
    }
    if `"`method'"' == "Tri" & (missing(`q') | mod(`q', 2) != 0) {
        di as error "{bf:hddid}: internal result posting requires even q() under method(Tri)"
        di as error "  Reason: the published trigonometric sieve basis is 1 plus cosine/sine pairs, so current posted Tri results need an even nonconstant basis count"
        di as error "  Posting found q() = " %9.0g `q'
        exit 498
    }
    if missing(`alpha') | `alpha' <= 0 | `alpha' >= 1 {
        di as error "{bf:hddid}: internal result posting requires alpha() in (0, 1)"
        di as error "  Reason: the published {bf:e(alpha)} scalar is the shared significance level behind {bf:e(CIpoint)}, and the same {bf:e(alpha)} scalar also calibrates the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object, so alpha must be a finite scalar strictly between 0 and 1"
        di as error "  Posting found alpha() = " %12.8g `alpha'
        exit 498
    }
    local nboot_input `"`nboot'"'
    capture confirm number `nboot_input'
    if _rc != 0 {
        di as error "{bf:hddid}: internal result posting requires nboot() >= 2"
        di as error "  Reason: the published {bf:e(tc)} object is the rowwise-envelope lower/upper critical-value pair behind {bf:e(CIuniform)}, so current result posting needs at least two Gaussian-bootstrap draws to identify both endpoints"
        di as error "  Posting found malformed nboot() = {bf:`nboot_input'}"
        exit 498
    }
    local nboot = real(`"`nboot_input'"')
    if missing(`nboot') | `nboot' < 2 | `nboot' != floor(`nboot') {
        di as error "{bf:hddid}: internal result posting requires nboot() >= 2"
        di as error "  Reason: the published {bf:e(tc)} object is the rowwise-envelope lower/upper critical-value pair behind {bf:e(CIuniform)}, so current result posting needs at least two Gaussian-bootstrap draws to identify both endpoints"
        di as error "  Posting found nboot() = " %9.0g `nboot'
        exit 498
    }
    if `"`cmdline'"' == "" & `seed' >= 0 {
        di as error "{bf:hddid}: stored cmdline omits seed() provenance, so posted seed() metadata must be absent"
        di as error "  Posting found blank {bf:cmdline()} but machine-readable {bf:seed()} = {bf:`seed'}"
        di as error "  Reason: omitting the successful-call record also omits {bf:seed()} provenance, so current saved results cannot simultaneously suppress and publish the realized bootstrap seed scalar."
        exit 498
    }
    if `"`cmdline'"' != "" {
        local _cmdline_has_seed_pub = ///
            regexm(`"`cmdline'"', "(^|[ ,])seed[(][ ]*[^)]*[)]")
        local _cmdline_seed_arg_pub ""
        local _cmdline_seed_value_pub = .
        local _cmdline_seed_ok_pub = 0
        local _cmdline_seed_is_sentinel_pub = 0
        local _cmdline_dup_seed_pub = 0
        local _cmdline_scalar_probe_pub `"`cmdline'"'
        if regexm(`"`_cmdline_scalar_probe_pub'"', "(^|[ ,])seed[(][^)]*[)]") {
            local _cmdline_scalar_probe_pub = ///
                regexr(`"`_cmdline_scalar_probe_pub'"', ///
                "(^|[ ,])seed[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_scalar_probe_pub'"', "(^|[ ,])seed[(]") {
                local _cmdline_dup_seed_pub = 1
            }
        }
        if regexm(`"`cmdline'"', "(^|[ ,])seed[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_seed_arg_pub = strtrim(regexs(2))
            capture confirm number `_cmdline_seed_arg_pub'
            if _rc == 0 {
                local _cmdline_seed_value_pub = real(`"`_cmdline_seed_arg_pub'"')
                if !missing(`_cmdline_seed_value_pub') & ///
                    `_cmdline_seed_value_pub' == floor(`_cmdline_seed_value_pub') {
                    if `_cmdline_seed_value_pub' == -1 {
                        local _cmdline_seed_ok_pub = 1
                        local _cmdline_seed_is_sentinel_pub = 1
                    }
                    else if `_cmdline_seed_value_pub' >= 0 & ///
                        `_cmdline_seed_value_pub' <= 2147483647 {
                        local _cmdline_seed_ok_pub = 1
                    }
                }
            }
        }
        if `_cmdline_has_seed_pub' & `_cmdline_dup_seed_pub' {
            di as error "{bf:hddid}: stored cmdline must encode seed() provenance at most once"
            di as error "  Posting found duplicated {bf:seed()} provenance in {bf:cmdline()} = {bf:`cmdline'}"
            di as error "  Reason: current saved results must publish one atomic RNG provenance record for the realized bootstrap path before replay/postestimation consume it"
            exit 498
        }
        if `_cmdline_has_seed_pub' & `_cmdline_seed_ok_pub' == 0 {
            di as error "{bf:hddid}: stored cmdline seed() provenance must be -1 or a finite integer in [0, 2147483647]"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} with malformed explicit {bf:seed()} provenance: {bf:`_cmdline_seed_arg_pub'}"
            di as error "  Reason: the successful-call provenance record and machine-readable bootstrap/RNG metadata must agree before replay/postestimation consume the current saved-results surface"
            exit 498
        }
        if `_cmdline_has_seed_pub' & `_cmdline_seed_is_sentinel_pub' & `seed' >= 0 {
            di as error "{bf:hddid}: seed(-1) provenance forbids posted seed() metadata"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} but machine-readable {bf:seed()} = {bf:`seed'}"
            di as error "  Reason: {bf:seed(-1)} is the no-reset sentinel, so current saved results cannot simultaneously suppress and publish the realized bootstrap seed provenance"
            exit 498
        }
        if `_cmdline_has_seed_pub' & `_cmdline_seed_is_sentinel_pub' == 0 & ///
            `_cmdline_seed_value_pub' < . & `_cmdline_seed_value_pub' != `seed' {
            di as error "{bf:hddid}: stored cmdline seed() provenance must match posted seed()"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} but machine-readable {bf:seed()} = {bf:`seed'}"
            di as error "  Reason: current saved results must publish one atomic RNG provenance record for the realized bootstrap path"
            exit 498
        }
        if `_cmdline_has_seed_pub' == 0 & `seed' >= 0 {
            di as error "{bf:hddid}: stored cmdline omits seed() provenance, so posted seed() metadata must be absent"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} but machine-readable {bf:seed()} = {bf:`seed'}"
            di as error "  Reason: omitting {bf:seed()} means the realized bootstrap path followed the ambient RNG stream rather than a single published seed scalar."
            exit 498
        }
        local _cmdline_has_nboot_pub = ///
            regexm(`"`cmdline'"', "(^|[ ,])nboot[(][ ]*[^)]*[)]")
        local _cmdline_nboot_arg_pub ""
        local _cmdline_nboot_value_pub = .
        local _cmdline_nboot_ok_pub = 0
        local _cmdline_dup_nboot_pub = 0
        local _cmdline_scalar_probe_pub `"`cmdline'"'
        if regexm(`"`_cmdline_scalar_probe_pub'"', "(^|[ ,])nboot[(][^)]*[)]") {
            local _cmdline_scalar_probe_pub = ///
                regexr(`"`_cmdline_scalar_probe_pub'"', ///
                "(^|[ ,])nboot[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_scalar_probe_pub'"', "(^|[ ,])nboot[(]") {
                local _cmdline_dup_nboot_pub = 1
            }
        }
        if regexm(`"`cmdline'"', "(^|[ ,])nboot[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_nboot_arg_pub = strtrim(regexs(2))
            if regexm(`"`_cmdline_nboot_arg_pub'"', "^[+]?[0-9]+$") {
                local _cmdline_nboot_value_pub = real(`"`_cmdline_nboot_arg_pub'"')
                if !missing(`_cmdline_nboot_value_pub') & ///
                    `_cmdline_nboot_value_pub' >= 2 {
                    local _cmdline_nboot_ok_pub = 1
                }
            }
        }
        if `_cmdline_has_nboot_pub' & `_cmdline_dup_nboot_pub' {
            di as error "{bf:hddid}: stored cmdline must encode nboot() provenance at most once"
            di as error "  Posting found duplicated {bf:nboot()} provenance in {bf:cmdline()} = {bf:`cmdline'}"
            di as error "  Reason: current saved results must publish one atomic Gaussian-bootstrap replication count behind {bf:e(tc)} and {bf:e(CIuniform)} before replay/postestimation consume it"
            exit 498
        }
        if `_cmdline_has_nboot_pub' & `_cmdline_nboot_ok_pub' == 0 {
            di as error "{bf:hddid}: stored cmdline nboot() provenance must be an integer >= 2"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} with malformed explicit {bf:nboot()} provenance: {bf:`_cmdline_nboot_arg_pub'}"
            di as error "  Reason: the successful-call provenance record and machine-readable bootstrap replication count must agree before replay/postestimation consume the current saved-results surface"
            exit 498
        }
        if `_cmdline_has_nboot_pub' & `_cmdline_nboot_value_pub' < . & ///
            `_cmdline_nboot_value_pub' != `nboot' {
            di as error "{bf:hddid}: stored cmdline nboot() provenance must match posted nboot()"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} but machine-readable {bf:nboot()} = {bf:`nboot'}"
            di as error "  Reason: current saved results must publish one atomic Gaussian-bootstrap replication count behind {bf:e(tc)} and {bf:e(CIuniform)}"
            exit 498
        }
        local _cmdline_has_alpha_pub = ///
            regexm(`"`cmdline'"', "(^|[ ,])alpha[(][ ]*[^)]*[)]")
        local _cmdline_alpha_arg_pub ""
        local _cmdline_alpha_value_pub = .
        local _cmdline_alpha_ok_pub = 0
        local _cmdline_dup_alpha_pub = 0
        local _cmdline_scalar_probe_pub `"`cmdline'"'
        if regexm(`"`_cmdline_scalar_probe_pub'"', "(^|[ ,])alpha[(][^)]*[)]") {
            local _cmdline_scalar_probe_pub = ///
                regexr(`"`_cmdline_scalar_probe_pub'"', ///
                "(^|[ ,])alpha[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_scalar_probe_pub'"', "(^|[ ,])alpha[(]") {
                local _cmdline_dup_alpha_pub = 1
            }
        }
        if regexm(`"`cmdline'"', "(^|[ ,])alpha[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_alpha_arg_pub = strtrim(regexs(2))
            if regexm(`"`_cmdline_alpha_arg_pub'"', ///
                "^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$") {
                local _cmdline_alpha_value_pub = real(`"`_cmdline_alpha_arg_pub'"')
                if !missing(`_cmdline_alpha_value_pub') & ///
                    `_cmdline_alpha_value_pub' > 0 & ///
                    `_cmdline_alpha_value_pub' < 1 {
                    local _cmdline_alpha_ok_pub = 1
                }
            }
        }
        if `_cmdline_has_alpha_pub' & `_cmdline_dup_alpha_pub' {
            di as error "{bf:hddid}: stored cmdline must encode alpha() provenance at most once"
            di as error "  Posting found duplicated {bf:alpha()} provenance in {bf:cmdline()} = {bf:`cmdline'}"
            di as error "  Reason: current saved results must publish one atomic shared significance level behind {bf:e(CIpoint)} and the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object before replay/postestimation consume them"
            exit 498
        }
        if `_cmdline_has_alpha_pub' & `_cmdline_alpha_ok_pub' == 0 {
            di as error "{bf:hddid}: stored cmdline alpha() provenance must be a finite scalar in (0, 1)"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} with malformed explicit {bf:alpha()} provenance: {bf:`_cmdline_alpha_arg_pub'}"
            di as error "  Reason: the successful-call provenance record and machine-readable shared significance level must agree before replay/postestimation consume the current saved-results surface for both {bf:e(CIpoint)} and the realized {bf:e(tc)}/{bf:e(CIuniform)} interval object"
            exit 498
        }
        if `_cmdline_has_alpha_pub' & `_cmdline_alpha_value_pub' < . & ///
            abs(`_cmdline_alpha_value_pub' - `alpha') > 1e-12 {
            di as error "{bf:hddid}: stored cmdline alpha() provenance must match posted alpha()"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} but machine-readable {bf:alpha()} = {bf:`alpha'}"
            di as error "  Reason: current saved results must publish one atomic shared significance level behind {bf:e(CIpoint)} and the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object"
            exit 498
        }
        local _cmdline_parse_pub `"`cmdline'"'
        local _cmdline_opts_pub ""
    if `"`_cmdline_parse_pub'"' != "" {
        local _cmdline_parse_pub = ///
            subinstr(`"`_cmdline_parse_pub'"', char(9), " ", .)
        local _cmdline_parse_pub = ///
            subinstr(`"`_cmdline_parse_pub'"', char(10), " ", .)
            local _cmdline_parse_pub = ///
                subinstr(`"`_cmdline_parse_pub'"', char(13), " ", .)
            local _cmdline_lc_pub = lower(`"`_cmdline_parse_pub'"')
            local _cmdline_comma_pub = strpos(`"`_cmdline_lc_pub'"', ",")
        if `_cmdline_comma_pub' > 0 {
            local _cmdline_opts_pub = ///
                strtrim(substr(`"`_cmdline_lc_pub'"', `_cmdline_comma_pub' + 1, .))
        }
    }
    local _cmdline_has_roles_pub = 0
    local _cmdline_dup_role_opts_pub = 0
    local _cmdline_depvar_pub ""
    local _cmdline_treat_pub ""
    local _cmdline_xvars_pub ""
    local _cmdline_zvar_pub ""
    if regexm(`"`_cmdline_lc_pub'"', "^[ ]*hddid[ ]+([^, ]+)") {
        local _cmdline_depvar_pub = strtrim(regexs(1))
    }
    if `"`_cmdline_opts_pub'"' != "" {
        local _cmdline_has_roles_pub = ///
            regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])tr(e(a(t)?)?)?[(]") & ///
            regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])x[(]") & ///
            regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])z[(]")
        local _cmdline_role_probe_pub `"`_cmdline_opts_pub'"'
        if regexm(`"`_cmdline_role_probe_pub'"', "(^|[ ,])tr(e(a(t)?)?)?[(][^)]*[)]") {
            local _cmdline_role_probe_pub = ///
                regexr(`"`_cmdline_role_probe_pub'"', ///
                "(^|[ ,])tr(e(a(t)?)?)?[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_role_probe_pub'"', "(^|[ ,])tr(e(a(t)?)?)?[(]") {
                local _cmdline_dup_role_opts_pub = 1
            }
        }
        local _cmdline_role_probe_pub `"`_cmdline_opts_pub'"'
        if regexm(`"`_cmdline_role_probe_pub'"', "(^|[ ,])x[(][^)]*[)]") {
            local _cmdline_role_probe_pub = ///
                regexr(`"`_cmdline_role_probe_pub'"', ///
                "(^|[ ,])x[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_role_probe_pub'"', "(^|[ ,])x[(]") {
                local _cmdline_dup_role_opts_pub = 1
            }
        }
        local _cmdline_role_probe_pub `"`_cmdline_opts_pub'"'
        if regexm(`"`_cmdline_role_probe_pub'"', "(^|[ ,])z[(][^)]*[)]") {
            local _cmdline_role_probe_pub = ///
                regexr(`"`_cmdline_role_probe_pub'"', ///
                "(^|[ ,])z[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_role_probe_pub'"', "(^|[ ,])z[(]") {
                local _cmdline_dup_role_opts_pub = 1
            }
        }
    }
    if regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])tr(e(a(t)?)?)?[(]([^)]*)[)]") {
        local _cmdline_treat_pub = strtrim(regexs(5))
    }
    if regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])x[(]([^)]*)[)]") {
        local _cmdline_xvars_pub = strtrim(regexs(2))
    }
    if regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])z[(]([^)]*)[)]") {
        local _cmdline_zvar_pub = strtrim(regexs(2))
    }
    if `_cmdline_dup_role_opts_pub' {
        di as error "{bf:hddid}: stored cmdline must encode depvar/treat()/x()/z() role provenance at most once"
        di as error "  Posting found duplicated role provenance in {bf:cmdline()} = {bf:`cmdline'}"
        di as error "  Reason: one current HDDID result surface corresponds to one depvar/treat/x/z mapping, so producer-side posting cannot publish ambiguous duplicated role provenance."
        exit 498
    }
    if `"`_cmdline_depvar_pub'"' == "" | `_cmdline_has_roles_pub' == 0 | ///
        `"`_cmdline_treat_pub'"' == "" | `"`_cmdline_xvars_pub'"' == "" | ///
        `"`_cmdline_zvar_pub'"' == "" {
        di as error "{bf:hddid}: stored cmdline must include depvar plus treat()/x()/z() role provenance"
        di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'}"
        di as error "  Reason: current saved results publish one realized depvar/treat/x/z mapping behind the posted beta and {bf:f(z0)} surface, so producer-side posting must fail closed before replay/postestimation consume incomplete role provenance."
        exit 498
    }
    local _depvar_cmd_expected_pub = lower(strtrim(`"`depvar_display'"'))
    local _treat_cmd_expected_pub = lower(strtrim(`"`treatvar'"'))
    local _xvars_cmd_expected_pub = lower(strtrim(`"`xvars'"'))
    local _xvars_cmd_expected_pub : list retokenize _xvars_cmd_expected_pub
    local _zvar_cmd_expected_pub = lower(strtrim(`"`zvar'"'))
    local _cmdline_depvar_cmp_pub = lower(strtrim(`"`_cmdline_depvar_pub'"'))
    local _cmdline_treat_cmp_pub = lower(strtrim(`"`_cmdline_treat_pub'"'))
    local _cmdline_xvars_cmp_pub = lower(strtrim(`"`_cmdline_xvars_pub'"'))
    local _cmdline_xvars_cmp_pub : list retokenize _cmdline_xvars_cmp_pub
    local _cmdline_zvar_cmp_pub = lower(strtrim(`"`_cmdline_zvar_pub'"'))
    capture unab _cmdline_depvar_canon_pub : `_cmdline_depvar_pub'
    if _rc == 0 {
        local _cmdline_depvar_cmp_pub = ///
            lower(strtrim(`"`_cmdline_depvar_canon_pub'"'))
    }
    capture unab _cmdline_treat_canon_pub : `_cmdline_treat_pub'
    if _rc == 0 {
        local _cmdline_treat_cmp_pub = ///
            lower(strtrim(`"`_cmdline_treat_canon_pub'"'))
    }
    capture unab _cmdline_xvars_canon_pub : `_cmdline_xvars_pub'
    if _rc == 0 {
        local _cmdline_xvars_cmp_pub = ///
            lower(strtrim(`"`_cmdline_xvars_canon_pub'"'))
        local _cmdline_xvars_cmp_pub : list retokenize _cmdline_xvars_cmp_pub
    }
    else {
        capture tsunab _cmdline_xvars_canon_pub : `_cmdline_xvars_pub'
        if _rc == 0 {
            local _cmdline_xvars_cmp_pub = ///
                lower(strtrim(`"`_cmdline_xvars_canon_pub'"'))
            local _cmdline_xvars_cmp_pub : list retokenize _cmdline_xvars_cmp_pub
        }
    }
    capture unab _cmdline_zvar_canon_pub : `_cmdline_zvar_pub'
    if _rc == 0 {
        local _cmdline_zvar_cmp_pub = ///
            lower(strtrim(`"`_cmdline_zvar_canon_pub'"'))
    }
    local _cmdline_xvars_sorted_pub : list sort _cmdline_xvars_cmp_pub
    local _xvars_cmd_sorted_pub : list sort _xvars_cmd_expected_pub
    local _pub_xvars_mismatch 0
    if strpos(`"`_cmdline_xvars_cmp_pub'"', "-") == 0 & ///
        `"`_cmdline_xvars_sorted_pub'"' != `"`_xvars_cmd_sorted_pub'"' {
        local _pub_xvars_mismatch 1
    }
    if `"`_cmdline_depvar_cmp_pub'"' != `"`_depvar_cmd_expected_pub'"' | ///
        `"`_cmdline_treat_cmp_pub'"' != `"`_treat_cmd_expected_pub'"' | ///
        `_pub_xvars_mismatch' | ///
        `"`_cmdline_zvar_cmp_pub'"' != `"`_zvar_cmd_expected_pub'"' {
        di as error "{bf:hddid}: stored cmdline role mapping must agree with posted depvar()/treatvar()/xvars()/zvar() metadata"
        di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'}"
        di as error "  Posting found machine-readable roles depvar={bf:`depvar_display'}, treat={bf:`treatvar'}, x={bf:`xvars'}, z={bf:`zvar'}"
        di as error "  Reason: one current HDDID result surface corresponds to one realized depvar/treat/x/z mapping, so producer-side posting cannot publish contradictory role provenance."
        exit 498
    }
    local _cmdline_has_method_pub = ///
        regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])method[(][ ]*[^)]*[)]")
        local _cmdline_has_q_pub = ///
            regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])q[(][ ]*[^)]*[)]")
        local _cmdline_has_method_assign_pub = ///
            regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])method[ ]*=")
        local _cmdline_has_q_assign_pub = ///
            regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])q[ ]*=")
        local _cmdline_dup_method_pub = 0
        local _cmdline_dup_q_pub = 0
        local _cmdline_method_arg_pub ""
        local _cmdline_method_value_pub ""
        local _cmdline_method_ok_pub = 0
        local _cmdline_q_arg_pub ""
        local _cmdline_q_value_pub = .
        local _cmdline_q_ok_pub = 0
        if `_cmdline_has_method_assign_pub' | `_cmdline_has_q_assign_pub' {
            local _cmdline_assign_parts_pub ""
            if `_cmdline_has_method_assign_pub' {
                local _cmdline_assign_parts_pub "{bf:method=}"
            }
            if `_cmdline_has_q_assign_pub' {
                if `"`_cmdline_assign_parts_pub'"' != "" {
                    local _cmdline_assign_parts_pub ///
                        `"`_cmdline_assign_parts_pub' and {bf:q=}"'
                }
                else {
                    local _cmdline_assign_parts_pub "{bf:q=}"
                }
            }
            di as error "{bf:hddid}: stored cmdline must encode method()/q() provenance with option syntax"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} with assignment-style `_cmdline_assign_parts_pub' provenance"
            di as error "  Reason: one successful hddid call can publish the realized sieve family/order only through {bf:method()} and {bf:q()}, so assignment-style saved provenance is malformed."
            exit 498
        }
        local _cmdline_method_probe_pub `"`_cmdline_opts_pub'"'
        if regexm(`"`_cmdline_method_probe_pub'"', "(^|[ ,])method[(][^)]*[)]") {
            local _cmdline_method_probe_pub = ///
                regexr(`"`_cmdline_method_probe_pub'"', ///
                "(^|[ ,])method[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_method_probe_pub'"', "(^|[ ,])method[(]") {
                local _cmdline_dup_method_pub = 1
            }
        }
        local _cmdline_q_probe_pub `"`_cmdline_opts_pub'"'
        if regexm(`"`_cmdline_q_probe_pub'"', "(^|[ ,])q[(][^)]*[)]") {
            local _cmdline_q_probe_pub = ///
                regexr(`"`_cmdline_q_probe_pub'"', "(^|[ ,])q[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_q_probe_pub'"', "(^|[ ,])q[(]") {
                local _cmdline_dup_q_pub = 1
            }
        }
        if `_cmdline_has_method_pub' & `_cmdline_dup_method_pub' {
            di as error "{bf:hddid}: stored cmdline must encode method() provenance at most once"
            di as error "  Posting found duplicated {bf:method()} provenance in {bf:cmdline()} = {bf:`cmdline'}"
            di as error "  Reason: one realized HDDID surface can only come from one sieve-basis family."
            exit 498
        }
        if `_cmdline_has_q_pub' & `_cmdline_dup_q_pub' {
            di as error "{bf:hddid}: stored cmdline must encode q() provenance at most once"
            di as error "  Posting found duplicated {bf:q()} provenance in {bf:cmdline()} = {bf:`cmdline'}"
            di as error "  Reason: one realized HDDID surface can only come from one sieve-order choice."
            exit 498
        }
        if regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])method[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_method_arg_pub = strtrim(regexs(2))
            if strlen(`"`_cmdline_method_arg_pub'"') >= 2 {
                local _cmdline_method_first_pub = ///
                    substr(`"`_cmdline_method_arg_pub'"', 1, 1)
                local _cmdline_method_last_pub = ///
                    substr(`"`_cmdline_method_arg_pub'"', -1, 1)
                if (`"`_cmdline_method_first_pub'"' == `"""' & ///
                    `"`_cmdline_method_last_pub'"' == `"""') | ///
                    (`"`_cmdline_method_first_pub'"' == "'" & ///
                    `"`_cmdline_method_last_pub'"' == "'") {
                    local _cmdline_method_arg_pub = ///
                        substr(`"`_cmdline_method_arg_pub'"', 2, ///
                        strlen(`"`_cmdline_method_arg_pub'"') - 2)
                }
            }
            local _cmdline_method_value_pub = ///
                strproper(strtrim(`"`_cmdline_method_arg_pub'"'))
            if inlist(`"`_cmdline_method_value_pub'"', "Pol", "Tri") {
                local _cmdline_method_ok_pub = 1
            }
        }
        if `_cmdline_has_method_pub' & `_cmdline_method_ok_pub' == 0 {
            di as error "{bf:hddid}: stored cmdline method() provenance must be {bf:Pol} or {bf:Tri}"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} with malformed explicit {bf:method()} provenance: {bf:`_cmdline_method_arg_pub'}"
            di as error "  Reason: the successful-call record may publish only the polynomial or trigonometric sieve family used by the realized HDDID surface."
            exit 498
        }
        if regexm(`"`_cmdline_opts_pub'"', "(^|[ ,])q[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_q_arg_pub = strtrim(regexs(2))
            if regexm(`"`_cmdline_q_arg_pub'"', "^[+]?[0-9]+$") {
                local _cmdline_q_value_pub = real(`"`_cmdline_q_arg_pub'"')
                if !missing(`_cmdline_q_value_pub') & `_cmdline_q_value_pub' >= 1 {
                    local _cmdline_q_ok_pub = 1
                }
            }
        }
        if `_cmdline_has_q_pub' & `_cmdline_q_ok_pub' == 0 {
            di as error "{bf:hddid}: stored cmdline q() provenance must be an integer >= 1"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} with malformed explicit {bf:q()} provenance: {bf:`_cmdline_q_arg_pub'}"
            di as error "  Reason: the successful-call record may publish only a valid positive sieve-order choice for the realized HDDID surface."
            exit 498
        }
        local _stored_method_cmdline_pub = strproper(strlower(strtrim(`"`method'"')))
        local _stored_q_cmdline_pub = `q'
        if `_cmdline_has_method_pub' == 0 & `_cmdline_has_q_pub' == 0 & ///
            (`"`_stored_method_cmdline_pub'"' != "Pol" | ///
            `_stored_q_cmdline_pub' != 8) {
            di as error "{bf:hddid}: stored cmdline omissions of method()/q() require posted method()/q() defaults"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} but machine-readable {bf:method()} = {bf:`_stored_method_cmdline_pub'} and {bf:q()} = {bf:`_stored_q_cmdline_pub'}"
            di as error "  Reason: omitting both basis options in the successful-call record still means official {bf:method(Pol)} and {bf:q(8)}, so producer-side posting must fail closed before malformed current results reach replay or postestimation."
            exit 498
        }
        else if `_cmdline_has_method_pub' == 0 & ///
            `"`_stored_method_cmdline_pub'"' != "Pol" {
            di as error "{bf:hddid}: stored cmdline that omits method() require posted method() = {bf:Pol}"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} but machine-readable {bf:method()} = {bf:`_stored_method_cmdline_pub'}."
            di as error "  Reason: omitting {bf:method()} in the successful-call record still means the official default basis family {bf:Pol}."
            exit 498
        }
        else if `_cmdline_has_q_pub' == 0 & ///
            `_stored_q_cmdline_pub' != 8 {
            di as error "{bf:hddid}: stored cmdline that omits q() require posted q() = 8"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} but machine-readable {bf:q()} = {bf:`_stored_q_cmdline_pub'}."
            di as error "  Reason: omitting {bf:q()} in the successful-call record still means the official default sieve order {bf:8}."
            exit 498
        }
        else if (`_cmdline_has_method_pub' | `_cmdline_has_q_pub') & ///
            (`_cmdline_has_method_pub' == 0 | ///
            `"`_cmdline_method_value_pub'"' == `"`_stored_method_cmdline_pub'"') & ///
            (`_cmdline_has_q_pub' == 0 | ///
            `_cmdline_q_value_pub' == `_stored_q_cmdline_pub') {
            // Explicit cmdline method()/q() provenance matches the posted
            // machine-readable metadata. Continue to matrix/public-surface checks.
        }
        else if `_cmdline_has_method_pub' | `_cmdline_has_q_pub' {
            di as error "{bf:hddid}: stored cmdline method()/q() provenance must match posted method()/q()"
            di as error "  Posting found {bf:cmdline()} = {bf:`cmdline'} but machine-readable {bf:method()} = {bf:`_stored_method_cmdline_pub'} and {bf:q()} = {bf:`_stored_q_cmdline_pub'}"
            di as error "  Reason: current saved results publish sieve-basis provenance through both the successful-call record and the machine-readable {bf:method()} / {bf:q()} metadata behind the realized beta and {bf:f(z0)} surface."
            exit 498
        }
    }
    if rowsof(`tc') != 1 | colsof(`tc') != 2 | ///
        missing(`tc'[1,1]) | missing(`tc'[1,2]) {
        di as error "{bf:hddid}: internal result posting requires finite tc() as a 1 x 2 lower/upper critical-value rowvector"
        di as error "  Reason: the published {bf:e(tc)} object records the Gaussian-bootstrap lower/upper critical-value provenance behind {bf:e(CIuniform)}"
        exit 498
    }
    if `tc'[1,1] > `tc'[1,2] {
        di as error "{bf:hddid}: internal result posting requires tc()[1,1] <= tc()[1,2]"
        di as error "  Reason: the published {bf:e(tc)} object is ordered as (lower, upper)"
        di as error "  Posting found tc() = (" %12.8g `tc'[1,1] ", " %12.8g `tc'[1,2] ")"
        exit 498
    }
    if rowsof(`gdebias') != 1 | colsof(`gdebias') != `qq' {
        di as error "{bf:hddid}: internal result posting requires gdebias() as a 1 x qq rowvector"
        di as error "  Reason: the published nonparametric point estimates must align one-to-one with the posted z0() grid"
        di as error "  Posting found gdebias() with shape " rowsof(`gdebias') " x " colsof(`gdebias') ///
            " but qq() = `qq'"
        exit 498
    }
    if rowsof(`stdg') != 1 | colsof(`stdg') != `qq' {
        di as error "{bf:hddid}: internal result posting requires stdg() as a 1 x qq rowvector"
        di as error "  Reason: the published nonparametric standard-error surface must align one-to-one with the posted z0() grid"
        di as error "  Posting found stdg() with shape " rowsof(`stdg') " x " colsof(`stdg') ///
            " but qq() = `qq'"
        exit 498
    }
    if rowsof(`ciuniform') != 2 | colsof(`ciuniform') != `qq' {
        di as error "{bf:hddid}: internal result posting requires CIuniform() as a 2 x qq matrix"
        di as error "  Reason: the published uniform interval object stores lower/upper rows over the posted z0() grid"
        di as error "  Posting found CIuniform() with shape " rowsof(`ciuniform') " x " colsof(`ciuniform') ///
            " but qq() = `qq'"
        exit 498
    }
    local _zgrid_count : word count `zgrid'
    if `_zgrid_count' != `qq' {
        di as error "{bf:hddid}: internal result posting requires zgrid() to contain exactly qq() evaluation points"
        di as error "  Reason: the published e(z0), e(gdebias), e(stdg), and interval objects must share one-to-one nonparametric coordinates"
        di as error "  Posting found `_zgrid_count' zgrid() value(s) but qq() = " %9.0g `qq'
        exit 498
    }
    local _zgrid_nonfinite_vals ""
    local _tri_zgrid_outside ""
    foreach _z0_val of local zgrid {
        capture confirm number `_z0_val'
        if _rc != 0 {
            local _zgrid_nonfinite_vals ///
                `"`_zgrid_nonfinite_vals' `"`_z0_val'"'"'
            continue
        }
        local _z0_num = real(`"`_z0_val'"')
        if missing(`_z0_num') {
            local _zgrid_nonfinite_vals ///
                `"`_zgrid_nonfinite_vals' `"`_z0_val'"'"'
            continue
        }
        if `"`method'"' == "Tri" & ///
            (`_z0_num' < `zsupportmin' | `_z0_num' > `zsupportmax') {
            local _z0_num_disp : display %21.15g `_z0_num'
            local _tri_zgrid_outside ///
                `"`_tri_zgrid_outside' `_z0_num_disp'"'
        }
    }
    local _zgrid_nonfinite_vals : list retokenize _zgrid_nonfinite_vals
    if `"`_zgrid_nonfinite_vals'"' != "" {
        di as error "{bf:hddid}: internal result posting requires finite zgrid() values"
        di as error "  Reason: the published e(z0) grid must contain finite evaluation points before replay/postestimation can align the saved f(z0) surface"
        di as error "  Posting found malformed zgrid() value(s): {bf:`_zgrid_nonfinite_vals'}"
        exit 498
    }
    local _tri_zgrid_outside : list retokenize _tri_zgrid_outside
    if `"`_tri_zgrid_outside'"' != "" {
        di as error "{bf:hddid}: internal result posting requires zgrid() points inside the stored Tri support"
        di as error "  Reason: method(Tri) stores the support-normalized basis, so the published e(z0) grid cannot leave [z_support_min, z_support_max]"
        di as error "  Posting found stored support = [" ///
            %12.8g `zsupportmin' ", " %12.8g `zsupportmax' ///
            "] and out-of-support zgrid() point(s):`_tri_zgrid_outside'"
        exit 498
    }
    mata: st_local("_hddid_bad_publish_gdebias", strofreal(hasmissing(st_matrix("`gdebias'"))))
    mata: st_local("_hddid_bad_publish_stdg", strofreal(hasmissing(st_matrix("`stdg'"))))
    mata: st_local("_hddid_bad_publish_ciuniform", strofreal(hasmissing(st_matrix("`ciuniform'"))))
    if real("`_hddid_bad_publish_gdebias'") == 1 {
        di as error "{bf:hddid}: internal result posting requires finite gdebias()"
        di as error "  Reason: the published nonparametric point-estimate surface cannot contain missing/nonfinite values"
        exit 498
    }
    if real("`_hddid_bad_publish_stdg'") == 1 {
        di as error "{bf:hddid}: internal result posting requires finite stdg()"
        di as error "  Reason: the published nonparametric standard-error surface cannot contain missing/nonfinite values"
        exit 498
    }
    tempname _publish_stdg_min
    mata: st_numscalar("`_publish_stdg_min'", min(st_matrix("`stdg'")))
    if scalar(`_publish_stdg_min') < 0 {
        di as error "{bf:hddid}: internal result posting requires nonnegative stdg()"
        di as error "  Reason: the published nonparametric standard-error surface is a square-root scale object and cannot contain negative entries"
        di as error "  Posting found min(stdg()) = " %12.8g scalar(`_publish_stdg_min')
        exit 498
    }
    tempname _publish_stdg_absmax _publish_stdg_scale _publish_zero_stdg_tol _publish_tc_scale _publish_tc_tol
    mata: st_numscalar("`_publish_stdg_absmax'", max(abs(st_matrix("`stdg'")))); ///
        st_numscalar("`_publish_stdg_scale'", max((1, max(abs(st_matrix("`stdg'")))))); ///
        st_numscalar("`_publish_tc_scale'", max((1, max(abs(st_matrix("`tc'"))))))
    scalar `_publish_zero_stdg_tol' = 1e-12 * scalar(`_publish_stdg_scale')
    scalar `_publish_tc_tol' = 1e-12 * scalar(`_publish_tc_scale')
    if scalar(`_publish_stdg_absmax') <= scalar(`_publish_zero_stdg_tol') & ///
        (abs(`tc'[1,1]) > scalar(`_publish_tc_tol') | ///
        abs(`tc'[1,2]) > scalar(`_publish_tc_tol')) {
        di as error "{bf:hddid}: internal result posting requires tc() = (0, 0) when stdg() is identically zero"
        di as error "  Reason: on the zero-SE shortcut, the published CIuniform() object already collapses exactly to gdebias(), so any nonzero tc() would be stale or impossible bootstrap critical-value provenance"
        di as error "  Posting found stdg() absmax = " %12.8g scalar(`_publish_stdg_absmax') ///
            ", tc() = (" %12.8g `tc'[1,1] ", " %12.8g `tc'[1,2] ")" ///
            ", zero-stdg tolerance = " %12.8g scalar(`_publish_zero_stdg_tol') ///
            ", tc tolerance = " %12.8g scalar(`_publish_tc_tol')
        exit 498
    }
    if scalar(`_publish_stdg_absmax') > scalar(`_publish_zero_stdg_tol') & ///
        abs(`tc'[1,1]) <= scalar(`_publish_tc_tol') & ///
        abs(`tc'[1,2]) <= scalar(`_publish_tc_tol') {
        di as error "{bf:hddid}: internal result posting requires nonzero tc() when stdg() is not identically zero"
        di as error "  Reason: with nonzero published stdg(), tc() = (0, 0) would collapse CIuniform() back to gdebias() instead of defining a distinct bootstrap envelope"
        di as error "  Posting found stdg() absmax = " %12.8g scalar(`_publish_stdg_absmax') ///
            ", tc() = (" %12.8g `tc'[1,1] ", " %12.8g `tc'[1,2] ")" ///
            ", zero-stdg tolerance = " %12.8g scalar(`_publish_zero_stdg_tol') ///
            ", tc tolerance = " %12.8g scalar(`_publish_tc_tol')
        exit 498
    }
    if real("`_hddid_bad_publish_ciuniform'") == 1 {
        di as error "{bf:hddid}: internal result posting requires finite CIuniform()"
        di as error "  Reason: the published uniform interval object cannot contain missing/nonfinite values"
        exit 498
    }
    tempname _publish_ciu_order_gap _publish_ciu_gap _publish_ciu_scale _publish_ciu_tol
    mata: st_numscalar("`_publish_ciu_order_gap'", max(st_matrix("`ciuniform'")[1,.] :- st_matrix("`ciuniform'")[2,.]))
    if scalar(`_publish_ciu_order_gap') > 0 {
        di as error "{bf:hddid}: internal result posting requires CIuniform() lower row <= upper row"
        di as error "  Reason: the published uniform interval object is ordered rowwise as (lower, upper)"
        di as error "  Posting found max(lower-upper) = " %12.8g scalar(`_publish_ciu_order_gap')
        exit 498
    }
    mata: _publish_ciu_oracle = ///
        (st_matrix("`gdebias'") :+ st_matrix("`tc'")[1,1] :* st_matrix("`stdg'")) \ ///
        (st_matrix("`gdebias'") :+ st_matrix("`tc'")[1,2] :* st_matrix("`stdg'")); ///
        st_numscalar("`_publish_ciu_gap'", ///
        max(abs(st_matrix("`ciuniform'") :- _publish_ciu_oracle))); ///
        st_numscalar("`_publish_ciu_scale'", ///
        max((1, max(abs(st_matrix("`ciuniform'"))), max(abs(_publish_ciu_oracle)))))
    scalar `_publish_ciu_tol' = 1e-12 * scalar(`_publish_ciu_scale')
    if scalar(`_publish_ciu_gap') > scalar(`_publish_ciu_tol') {
        di as error "{bf:hddid}: internal result posting requires CIuniform() equal to the rows implied by gdebias(), stdg(), and tc()"
        di as error "  Reason: bare replay and postestimation reuse the published interval object directly, so posting must fail closed on internally inconsistent CIuniform() metadata"
        di as error "  Posting found max |CIuniform - implied| = " %12.8g scalar(`_publish_ciu_gap') ///
            " with tolerance = " %12.8g scalar(`_publish_ciu_tol')
        exit 498
    }
    if missing(`secondstage') | ///
        `secondstage' < 2 | ///
        `secondstage' != floor(`secondstage') {
        di as error "{bf:hddid}: internal result posting requires secondstage() >= 2"
        di as error "  Reason: the published {bf:e(secondstage_nfolds)} metadata records the inner cross-validation design for the second-stage lasso, so it must be an integer fold count of at least 2"
        di as error "  Posting found secondstage() = " %9.0g `secondstage'
        exit 498
    }
    if missing(`mmatrix') | ///
        `mmatrix' < 2 | ///
        `mmatrix' != floor(`mmatrix') {
        di as error "{bf:hddid}: internal result posting requires mmatrix() >= 2"
        di as error "  Reason: the published {bf:e(mmatrix_nfolds)} metadata records the inner cross-validation design for the M-matrix auxiliary lasso, so it must be an integer fold count of at least 2"
        di as error "  Posting found mmatrix() = " %9.0g `mmatrix'
        exit 498
    }
    if missing(`k') | `k' < 2 | `k' != floor(`k') {
        di as error "{bf:hddid}: internal result posting requires k() >= 2"
        di as error "  Reason: the published {bf:e(k)} metadata describes the paper's outer cross-fitting partition, so posting cannot publish a non-cross-fit fold count"
        di as error "  Posting found k() = " %9.0g `k'
        exit 498
    }
    if missing(`p') | `p' < 1 | `p' != floor(`p') {
        di as error "{bf:hddid}: internal result posting requires p() >= 1"
        di as error "  Reason: the paper's partially linear block stores one beta coordinate per x() regressor, so the published parametric dimension must be a finite positive integer before replay/postestimation can index e(b), e(V), and e(xdebias)"
        di as error "  Posting found p() = " %9.0g `p'
        exit 498
    }
    if rowsof(`xdebias') != 1 | colsof(`xdebias') != `p' {
        di as error "{bf:hddid}: internal result posting requires xdebias() as a 1 x p rowvector"
        di as error "  Reason: the published parametric point-estimate surface must align one-to-one with the posted x() coordinates"
        di as error "  Posting found xdebias() with shape " rowsof(`xdebias') " x " colsof(`xdebias') ///
            " but p() = `p'"
        exit 498
    }
    if rowsof(`stdx') != 1 | colsof(`stdx') != `p' {
        di as error "{bf:hddid}: internal result posting requires stdx() as a 1 x p rowvector"
        di as error "  Reason: the published parametric standard-error surface must align one-to-one with the posted x() coordinates"
        di as error "  Posting found stdx() with shape " rowsof(`stdx') " x " colsof(`stdx') ///
            " but p() = `p'"
        exit 498
    }
    if rowsof(`cipoint') != 2 | colsof(`cipoint') != `p' + `qq' {
        di as error "{bf:hddid}: internal result posting requires CIpoint() as a 2 x (p + qq) matrix"
        di as error "  Reason: the published pointwise interval object stores lower/upper rows over the concatenated beta and f(z0) coordinates"
        di as error "  Posting found CIpoint() with shape " rowsof(`cipoint') " x " colsof(`cipoint') ///
            " but p() + qq() = `p' + `qq' = " `p' + `qq'
        exit 498
    }
    mata: st_local("_hddid_bad_publish_xdebias", strofreal(hasmissing(st_matrix("`xdebias'"))))
    mata: st_local("_hddid_bad_publish_stdx", strofreal(hasmissing(st_matrix("`stdx'"))))
    mata: st_local("_hddid_bad_publish_cipoint", strofreal(hasmissing(st_matrix("`cipoint'"))))
    if real("`_hddid_bad_publish_xdebias'") == 1 {
        di as error "{bf:hddid}: internal result posting requires finite xdebias()"
        di as error "  Reason: the published parametric point-estimate surface cannot contain missing/nonfinite values"
        exit 498
    }
    if real("`_hddid_bad_publish_stdx'") == 1 {
        di as error "{bf:hddid}: internal result posting requires finite stdx()"
        di as error "  Reason: the published parametric standard-error surface cannot contain missing/nonfinite values"
        exit 498
    }
    if rowsof(`b') != 1 | colsof(`b') != `p' {
        di as error "{bf:hddid}: internal result posting requires b() as a 1 x p rowvector"
        di as error "  Reason: the generic Stata e(b) surface must align one-to-one with the published debiased beta coordinates"
        di as error "  Posting found b() with shape " rowsof(`b') " x " colsof(`b') ///
            " but p() = `p'"
        exit 498
    }
    tempname _publish_bx_gap _publish_bx_scale _publish_bx_tol
    mata: st_numscalar("`_publish_bx_gap'", ///
        max(abs(st_matrix("`b'") :- st_matrix("`xdebias'")))); ///
        st_numscalar("`_publish_bx_scale'", ///
        max((1, max(abs(st_matrix("`b'"))), max(abs(st_matrix("`xdebias'"))))))
    scalar `_publish_bx_tol' = 1e-12 * scalar(`_publish_bx_scale')
    if scalar(`_publish_bx_gap') > scalar(`_publish_bx_tol') {
        di as error "{bf:hddid}: internal result posting requires b() equal to xdebias()"
        di as error "  Reason: the generic Stata e(b) vector and the published hddid xdebias() summary are the same debiased beta surface"
        di as error "  Posting found max |b - xdebias| = " %12.8g scalar(`_publish_bx_gap') ///
            " exceeded tolerance = " %12.8g scalar(`_publish_bx_tol')
        exit 498
    }
    tempname _publish_stdx_min
    mata: st_numscalar("`_publish_stdx_min'", min(st_matrix("`stdx'")))
    if scalar(`_publish_stdx_min') < 0 {
        di as error "{bf:hddid}: internal result posting requires nonnegative stdx()"
        di as error "  Reason: the published parametric standard-error surface is a square-root scale object and cannot contain negative entries"
        di as error "  Posting found min(stdx()) = " %12.8g scalar(`_publish_stdx_min')
        exit 498
    }
    if rowsof(`v') != `p' | colsof(`v') != `p' {
        di as error "{bf:hddid}: internal result posting requires V() as a p x p covariance matrix"
        di as error "  Reason: the published generic Stata covariance surface must align with the p-dimensional beta block before replay/postestimation can interpret e(V)"
        di as error "  Posting found V() with shape " rowsof(`v') " x " colsof(`v') ///
            " but p() = `p'"
        exit 498
    }
    tempname _publish_vdiag_gap _publish_vdiag_scale _publish_vdiag_tol
    mata: st_numscalar("`_publish_vdiag_gap'", ///
        max(abs(diagonal(st_matrix("`v'"))' :- ///
        (st_matrix("`stdx'") :^ 2)))); ///
        st_numscalar("`_publish_vdiag_scale'", ///
        max((1, max(abs(diagonal(st_matrix("`v'"))')), ///
        max(abs(st_matrix("`stdx'") :^ 2)))))
    scalar `_publish_vdiag_tol' = 1e-12 * scalar(`_publish_vdiag_scale')
    if scalar(`_publish_vdiag_gap') > scalar(`_publish_vdiag_tol') {
        di as error "{bf:hddid}: internal result posting requires diag(V) equal to stdx()^2"
        di as error "  Reason: the published generic covariance matrix and hddid-specific beta standard errors are the same parametric uncertainty surface"
        di as error "  Posting found max |diag(V) - stdx()^2| = " %12.8g scalar(`_publish_vdiag_gap') ///
            " exceeded tolerance = " %12.8g scalar(`_publish_vdiag_tol')
        exit 498
    }
    if real("`_hddid_bad_publish_cipoint'") == 1 {
        di as error "{bf:hddid}: internal result posting requires finite CIpoint()"
        di as error "  Reason: the published pointwise interval object cannot contain missing/nonfinite values"
        exit 498
    }
    tempname _publish_zcrit _publish_cipoint_gap _publish_cipoint_scale _publish_cipoint_tol
    scalar `_publish_zcrit' = invnormal(1 - `alpha' / 2)
    mata: st_numscalar("`_publish_cipoint_gap'", ///
        max(abs(st_matrix("`cipoint'") :- ( ///
        (st_matrix("`xdebias'") :- st_numscalar("`_publish_zcrit'") :* st_matrix("`stdx'"), ///
         st_matrix("`gdebias'") :- st_numscalar("`_publish_zcrit'") :* st_matrix("`stdg'")) \ ///
        (st_matrix("`xdebias'") :+ st_numscalar("`_publish_zcrit'") :* st_matrix("`stdx'"), ///
         st_matrix("`gdebias'") :+ st_numscalar("`_publish_zcrit'") :* st_matrix("`stdg'")) )))); ///
        st_numscalar("`_publish_cipoint_scale'", ///
        max((1, max(abs(st_matrix("`cipoint'"))), ///
        max(abs((st_matrix("`xdebias'") :- st_numscalar("`_publish_zcrit'") :* st_matrix("`stdx'"), ///
                 st_matrix("`gdebias'") :- st_numscalar("`_publish_zcrit'") :* st_matrix("`stdg'")) \ ///
                (st_matrix("`xdebias'") :+ st_numscalar("`_publish_zcrit'") :* st_matrix("`stdx'"), ///
                 st_matrix("`gdebias'") :+ st_numscalar("`_publish_zcrit'") :* st_matrix("`stdg'")))))))
    scalar `_publish_cipoint_tol' = 1e-12 * scalar(`_publish_cipoint_scale')
    if scalar(`_publish_cipoint_gap') > scalar(`_publish_cipoint_tol') {
        di as error "{bf:hddid}: internal result posting requires CIpoint() equal to the pointwise intervals implied by xdebias(), stdx(), gdebias(), stdg(), and alpha()"
        di as error "  Reason: the paper/R pointwise interval object is deterministic once the published estimates, standard errors, and alpha are fixed, so posting must fail closed on internally inconsistent CIpoint() metadata"
        di as error "  Posting found max |CIpoint - implied| = " %12.8g scalar(`_publish_cipoint_gap') ///
            " exceeded tolerance = " %12.8g scalar(`_publish_cipoint_tol')
        exit 498
    }
    local _nperfold_count : word count `nperfold'
    if `_nperfold_count' != `k' {
        di as error "{bf:hddid}: internal result posting requires exactly k retained fold counts"
        di as error "  Reason: the published {bf:e(N_per_fold)} contract is a 1 x k rowvector with one retained-sample fold count per outer fold"
        di as error "  Posting received k = `k' but nperfold() supplied `_nperfold_count' count(s)"
        exit 498
    }
    local _nperfold_sum = 0
    local _kk = 1
    foreach _n_eval of local nperfold {
        if missing(`_n_eval') | ///
            `_n_eval' < 1 | ///
            `_n_eval' != floor(`_n_eval') {
            di as error "{bf:hddid}: internal result posting requires strictly positive retained fold counts"
            di as error "  Reason: the published {bf:e(N_per_fold)} contract stores one finite integer >= 1 per outer fold"
            di as error "  Posting found nperfold()[`_kk'] = " %9.0f `_n_eval'
            exit 498
        }
        local _nperfold_sum = `_nperfold_sum' + `_n_eval'
        local ++_kk
    }
    if `_nperfold_sum' != `nfinal' {
        di as error "{bf:hddid}: internal result posting requires retained fold counts that sum to nfinal()"
        di as error "  Reason: the published {bf:e(N_per_fold)} contract must aggregate to the posted retained sample count {bf:e(N)}"
        di as error "  Posting found sum(nperfold()) = " %9.0f `_nperfold_sum' ///
            " but nfinal() = " %9.0f `nfinal'
        exit 498
    }
    if missing(`ntrimmed') | ///
        `ntrimmed' < 0 | ///
        `ntrimmed' != floor(`ntrimmed') | ///
        `ntrimmed' != (`npretrim' - `nfinal') {
        di as error "{bf:hddid}: internal result posting requires ntrimmed() = npretrim() - nfinal()"
        di as error "  Reason: current saved results publish retained-sample accounting through the identity {bf:e(N_trimmed) = e(N_pretrim) - e(N)}, so posting must fail closed before publishing impossible trim metadata"
        di as error "  Posting found ntrimmed() = " %9.0g `ntrimmed' ///
            ", npretrim() = " %9.0g `npretrim' ///
            ", and nfinal() = " %9.0g `nfinal'
        exit 498
    }
    if `"`firststage'"' == "internal" & ///
        (missing(`propensity') | ///
        `propensity' < 2 | ///
        `propensity' != floor(`propensity')) {
        di as error "{bf:hddid}: internal result posting requires propensity() >= 2"
        di as error "  Reason: current internal saved results publish {bf:e(propensity_nfolds)} as the propensity-stage inner-CV fold count, so posting must fail closed before publishing an impossible cross-validation provenance surface"
        di as error "  Posting found propensity() = " %9.0g `propensity'
        exit 498
    }
    if `"`firststage'"' == "internal" & ///
        (missing(`outcome') | ///
        `outcome' < 2 | ///
        `outcome' != floor(`outcome')) {
        di as error "{bf:hddid}: internal result posting requires outcome() >= 2"
        di as error "  Reason: current internal saved results publish {bf:e(outcome_nfolds)} as the treated/control outcome-stage inner-CV fold count, so posting must fail closed before publishing an impossible nuisance-path provenance surface"
        di as error "  Posting found outcome() = " %9.0g `outcome'
        exit 498
    }
    if `"`firststage'"' == "internal" & ///
        (missing(`nouter') | `nouter' != floor(`nouter') | `nouter' != `npretrim') {
        di as error "{bf:hddid}: internal result posting requires nouter() = npretrim()"
        di as error "  Reason: current internal saved results publish {bf:e(N_outer_split)} on the pretrim common score sample that pins the outer fold map, while auxiliary D/W-only rows can affect only the propensity training path"
        di as error "  Posting found nouter() = " %9.0g `nouter' ///
            " but npretrim() = " %9.0g `npretrim'
        exit 498
    }
    if `"`firststage'"' == "nofirst" & ///
        (missing(`nouter') | `nouter' != floor(`nouter') | `nouter' < `nfinal') {
        di as error "{bf:hddid}: nofirst result posting requires nouter() to be a finite integer >= nfinal()"
        di as error "  Reason: current {bf:nofirst} saved results publish {bf:e(N_outer_split)} on the retained-relevant subset of the broader strict-interior pretrim fold-feasibility sample that pins the outer fold map before later overlap trimming, so it cannot be smaller than the posted retained sample count {bf:e(N)}"
        di as error "  Posting found nouter() = " %9.0g `nouter' ///
            " but nfinal() = " %9.0g `nfinal'
        exit 498
    }
    quietly count if `esample' != 0 & !missing(`esample')
    local _esample_count = r(N)
    if `_esample_count' != `nfinal' {
        di as error "{bf:hddid}: internal result posting requires esample() to mark exactly nfinal() retained observations"
        di as error "  Reason: current saved results publish {bf:e(sample)} as the retained post-trim sample behind the posted {bf:e(N)}, {bf:e(b)}, and {bf:f(z0)} objects, so its live count cannot disagree with the posted retained-sample size"
        di as error "  Posting found count(if esample()) = " %9.0f `_esample_count' ///
            " but nfinal() = " %9.0f `nfinal'
        exit 498
    }
    if missing(`climemax') | `climemax' < 2 | `climemax' != floor(`climemax') {
        di as error "{bf:hddid}: internal result posting requires climemax() >= 2"
        di as error "  Reason: the published {bf:e(clime_nfolds_cv_max)} metadata records a requested inner-CV fold cap, so 0 is reserved for realized per-fold skips only and a valid request must be an integer >= 2"
        di as error "  Posting found climemax() = " %9.0g `climemax'
        exit 498
    }
    local _climeeff_count : word count `climeeff'
    if `_climeeff_count' != `k' {
        di as error "{bf:hddid}: internal result posting requires exactly k CLIME effective fold counts"
        di as error "  Reason: current multi-x saved results publish one realized CLIME CV count per outer fold"
        di as error "  Posting received k = `k' but climeeff() supplied `_climeeff_count' count(s)"
        exit 498
    }
    local _kk = 1
    foreach _clime_eff_fold of local climeeff {
        if missing(`_clime_eff_fold') | ///
            `_clime_eff_fold' != floor(`_clime_eff_fold') | ///
            (`_clime_eff_fold' != 0 & `_clime_eff_fold' < 2) {
            di as error "{bf:hddid}: internal result posting requires CLIME effective fold counts equal to 0 or integers >= 2"
            di as error "  Reason: the published realized CLIME CV metadata uses 0 only for skipped CV and otherwise records an integer fold count >= 2"
            di as error "  Posting found climeeff()[`_kk'] = " %9.0g `_clime_eff_fold'
            exit 498
        }
        if !missing(`climemax') & `_clime_eff_fold' > `climemax' {
            di as error "{bf:hddid}: internal result posting requires realized CLIME fold counts that do not exceed climemax()"
            di as error "  Reason: the published CLIME provenance cannot realize more inner CV folds than the requested cap"
            di as error "  Posting found climeeff()[`_kk'] = " %9.0g `_clime_eff_fold' ///
                " with climemax() = " %9.0g `climemax'
            exit 498
        }
        local ++_kk
    }
    // xvars() arrives from the estimation path already canonicalized on the
    // split-relevant sample that fixed the outer fold map. Recomputing that
    // order on the narrower retained esample would relabel beta coordinates
    // after trimming or score-sample narrowing without changing the model.
    local xvars : list retokenize xvars
    matrix colnames `b' = `xvars'
    matrix coleq `b' = beta
    matrix colnames `v' = `xvars'
    matrix rownames `v' = `xvars'
    matrix coleq `v' = beta
    matrix roweq `v' = beta

    ereturn post `b' `v', esample(`esample')
    tempname _e_rank
    mata: st_numscalar("`_e_rank'", rank(st_matrix("e(V)")))

    ereturn scalar N = `nfinal'
    ereturn scalar N_pretrim = `npretrim'
    ereturn scalar N_outer_split = `nouter'
    ereturn scalar rank = scalar(`_e_rank')
    ereturn scalar k = `k'
    ereturn scalar p = `p'
    ereturn scalar q = `q'
    ereturn scalar qq = `qq'
    ereturn scalar alpha = `alpha'
    ereturn scalar nboot = `nboot'
    ereturn scalar N_trimmed = `ntrimmed'
    if `"`firststage'"' == "internal" {
        ereturn scalar propensity_nfolds = `propensity'
        ereturn scalar outcome_nfolds = `outcome'
    }
    ereturn scalar secondstage_nfolds = `secondstage'
    ereturn scalar mmatrix_nfolds = `mmatrix'
    ereturn scalar clime_nfolds_cv_max = `climemax'
    if `"`method'"' == "Tri" {
        ereturn scalar z_support_min = `zsupportmin'
        ereturn scalar z_support_max = `zsupportmax'
    }
    if `seed' >= 0 {
        ereturn scalar seed = `seed'
    }

    matrix colnames `xdebias' = `xvars'
    matrix colnames `stdx' = `xvars'
    matrix colnames `tc' = tc_lower tc_upper

    // Reuse one z0 stripe across all nonparametric outputs so replay and
    // postestimation code align columns by the same evaluation labels.
    mata: _hddid_store_z0_colstripe("`zgrid'", "_z0_names")
    matrix colnames `gdebias' = `_z0_names'
    matrix colnames `stdg' = `_z0_names'
    matrix colnames `ciuniform' = `_z0_names'

    matrix rownames `cipoint' = lower upper
    matrix colnames `cipoint' = `xvars' `_z0_names'
    matrix rownames `ciuniform' = lower upper

    ereturn matrix xdebias = `xdebias'
    ereturn matrix gdebias = `gdebias'
    ereturn matrix stdx = `stdx'
    ereturn matrix stdg = `stdg'
    ereturn matrix tc = `tc'
    ereturn matrix CIpoint = `cipoint'
    ereturn matrix CIuniform = `ciuniform'

    tempname _N_per_fold
    matrix `_N_per_fold' = J(1, `k', 0)
    local _fold_names ""
    local _kk = 1
    foreach _n_eval of local nperfold {
        matrix `_N_per_fold'[1, `_kk'] = `_n_eval'
        local _fold_names "`_fold_names' fold_`_kk'"
        local ++_kk
    }
    matrix colnames `_N_per_fold' = `_fold_names'
    ereturn matrix N_per_fold = `_N_per_fold'

    tempname _clime_nfolds_cv_per_fold
    matrix `_clime_nfolds_cv_per_fold' = J(1, `k', 0)
    local _clime_nfolds_cv_effective_min = .
    local _clime_nfolds_cv_effective_max = .
    local _kk = 1
    foreach _clime_eff_fold of local climeeff {
        matrix `_clime_nfolds_cv_per_fold'[1, `_kk'] = `_clime_eff_fold'
        if missing(`_clime_nfolds_cv_effective_min') | ///
            `_clime_eff_fold' < `_clime_nfolds_cv_effective_min' {
            local _clime_nfolds_cv_effective_min = `_clime_eff_fold'
        }
        if missing(`_clime_nfolds_cv_effective_max') | ///
            `_clime_eff_fold' > `_clime_nfolds_cv_effective_max' {
            local _clime_nfolds_cv_effective_max = `_clime_eff_fold'
        }
        local ++_kk
    }
    matrix colnames `_clime_nfolds_cv_per_fold' = `_fold_names'
    ereturn scalar clime_nfolds_cv_effective_min = ///
        `_clime_nfolds_cv_effective_min'
    ereturn scalar clime_nfolds_cv_effective_max = ///
        `_clime_nfolds_cv_effective_max'
    ereturn matrix clime_nfolds_cv_per_fold = ///
        `_clime_nfolds_cv_per_fold'

    tempname _z0_mat
    matrix `_z0_mat' = J(1, `qq', 0)
    local _z0_idx = 1
    foreach _z0_val of local zgrid {
        matrix `_z0_mat'[1, `_z0_idx'] = `_z0_val'
        local _z0_idx = `_z0_idx' + 1
    }
    matrix colnames `_z0_mat' = `_z0_names'
    ereturn matrix z0 = `_z0_mat'

    capture confirm matrix __hddid_final_gammabar
    if _rc == 0 {
        tempname _gammabar
        matrix `_gammabar' = __hddid_final_gammabar
        ereturn matrix gammabar = `_gammabar'
    }
    capture confirm scalar __hddid_final_a0
    if _rc == 0 {
        ereturn scalar a0 = scalar(__hddid_final_a0)
    }

    ereturn local cmd "hddid"
    ereturn local cmdline `"`cmdline'"'
    ereturn local predict "`predictstub'"
    ereturn local estat_cmd "hddid_estat"
    ereturn local marginsnotok "_ALL"
    ereturn local firststage_mode "`firststage'"
    ereturn local method "`method'"
    ereturn local depvar "beta"
    ereturn local depvar_role "`depvarrole'"
    ereturn local treat "`treatvar'"
    ereturn local xvars "`xvars'"
    ereturn local zvar "`zvar'"
    ereturn local title ///
        "Doubly Robust Semiparametric DiD with High-Dimensional Data"
    ereturn local vce "robust"
    ereturn local vcetype "Robust"
    ereturn local properties "b V"

    _hddid_cleanup_state, khint(`k')

    sort `origorder'
end

program define _hddid_cleanup_state
    syntax [, KHINT(integer 0)]

    capture macro drop HDDID_ACTIVE_INTERNAL_SEED
    capture macro drop HDDID_ACTIVE_INTERNAL_RNG_STREAM
    capture macro drop HDDID_LASTISO_SEED
    capture macro drop HDDID_LASTISO_CALLER_RNG
    capture macro drop HDDID_LASTISO_INTERNAL_RNG

    // Drop transient matrices/scalars from prior runs so estimation failures
    // do not leak stale fold outputs into the next call.
    foreach _mat in ///
        __hddid_final_xdebias ///
        __hddid_final_gdebias ///
        __hddid_final_stdx ///
        __hddid_final_V ///
        __hddid_final_stdg ///
        __hddid_final_tc ///
        __hddid_final_CIpoint ///
        __hddid_final_alpha ///
        __hddid_final_CIuniform ///
        __hddid_xdebias_k ///
        __hddid_stdx_k ///
        __hddid_vcovx_k ///
        __hddid_gdebias_k ///
        __hddid_stdg_k ///
        __hddid_tc_k {
        capture matrix drop `_mat'
    }

    foreach _sca in __hddid_mata_selftest __hddid_nan_fallback_k ///
        __hddid_clime_effective_nfolds __hddid_clime_raw_feasible {
        capture scalar drop `_sca'
    }

    local _cleanup_kmax = max(1000, `khint')
    forvalues _i = 1/`_cleanup_kmax' {
        foreach _matpre in ///
            __hddid_fold_xdebias_ ///
            __hddid_fold_stdx_ ///
            __hddid_fold_vcovx_ ///
            __hddid_fold_gdebias_ ///
            __hddid_fold_stdg_ ///
            __hddid_fold_Vf_ ///
            __hddid_fold_tc_ {
            capture confirm matrix `_matpre'`_i'
            if _rc == 0 {
                capture matrix drop `_matpre'`_i'
            }
        }
        foreach _scapre in __hddid_fold_nanfb_ __hddid_fold_n_valid_ {
            capture confirm scalar `_scapre'`_i'
            if _rc == 0 {
                capture scalar drop `_scapre'`_i'
            }
        }
    }

    // Fold bridge state is created on the contiguous index block 1..K. When a
    // failed wrapper call does not know the prior K, keep sweeping upward
    // until the first empty index beyond the preflight bound so high-K stale
    // state cannot survive just because K exceeded 1000 in an earlier run.
    local _cleanup_i = `_cleanup_kmax' + 1
    local _cleanup_found = 1
    while `_cleanup_found' {
        local _cleanup_found = 0
        foreach _matpre in ///
            __hddid_fold_xdebias_ ///
            __hddid_fold_stdx_ ///
            __hddid_fold_vcovx_ ///
            __hddid_fold_gdebias_ ///
            __hddid_fold_stdg_ ///
            __hddid_fold_Vf_ ///
            __hddid_fold_tc_ {
            capture confirm matrix `_matpre'`_cleanup_i'
            if _rc == 0 {
                capture matrix drop `_matpre'`_cleanup_i'
                local _cleanup_found = 1
            }
        }
        foreach _scapre in __hddid_fold_nanfb_ __hddid_fold_n_valid_ {
            capture confirm scalar `_scapre'`_cleanup_i'
            if _rc == 0 {
                capture scalar drop `_scapre'`_cleanup_i'
                local _cleanup_found = 1
            }
        }
        local _cleanup_i = `_cleanup_i' + 1
    }
end


capture mata: mata drop _hddid_canonical_group_counts()
// When source-running via `run hddid.ado "<pkgdir>"`, preserve the explicit
// package root so the subsequent command call can resolve sibling sidecars
// even outside the project tree.
capture args _hddid_source_run_pkgdir
if `"`_hddid_source_run_pkgdir'"' != "" {
    global HDDID_SOURCE_RUN_PKGDIR_PREV `"$HDDID_SOURCE_RUN_PKGDIR"'
    global HDDID_SOURCE_RUN_PKGDIR `"`_hddid_source_run_pkgdir'"'
    global HDDID_SOURCE_RUN_PKGDIR_OWNED "1"
}
else {
    capture macro drop HDDID_SOURCE_RUN_PKGDIR_OWNED
    capture macro drop HDDID_SOURCE_RUN_PKGDIR_PREV
}
