capture program drop _hddid_wrap_drop_main
program define _hddid_wrap_drop_main
    version 16
    local _hddid_bundle_programs ///
        _hddid_main ///
        _hddid_probe_pkgdir_from_context ///
        _hddid_canonical_pkgdir ///
        _hddid_resolve_pkgdir ///
        _hddid_uncache_scipy ///
        _hddid_uncache_numpy ///
        _hddid_clime_scipy_probe ///
        _hddid_clime_feas_ok ///
        _hddid_probe_fail_classify ///
        _hddid_cvlasso_pick_lambda ///
        _hddid_run_rng_isolated ///
        _hddid_resolve_prop_cv ///
        _hddid_count_split_groups ///
        _hddid_choose_outer_split_sample ///
        _hddid_default_outer_fold_map ///
        _hddid_sort_default_innercv ///
        _hddid_canonicalize_xvars ///
        _hddid_parse_methodopt ///
        _hddid_parse_estopt_core ///
        _hddid_parse_estopt_sbridge ///
        _hddid_parse_estopt_rbridge ///
        _hddid_parse_estopt ///
        _hddid_parse_precomma_estexpr ///
        _hddid_show_estopt ///
        _hddid_show_invalid_estopt ///
        _hddid_show_esttoken ///
        _hddid_trailing_esttoken ///
        _hddid_load_estimate_sidecar ///
        _hddid_load_display_sidecar ///
        _hddid_pfb ///
        _hddid_validate_predict_stub ///
        _hddid_validate_estat_stub ///
        _hddid_publish_results ///
        _hddid_cleanup_state
    foreach _hddid_prog of local _hddid_bundle_programs {
        capture program drop `_hddid_prog'
    }
end

capture program drop _hddid_wrapper_try_load_main
program define _hddid_wrapper_try_load_main
    version 16
    args explicit_pkgdir
    local _hddid_wrapper_dir ""
    if `"`explicit_pkgdir'"' != "" {
        local _hddid_wrapper_dir `"`explicit_pkgdir'"'
        capture confirm file `"`_hddid_wrapper_dir'/_hddid_main.ado"'
        if _rc == 0 {
            quietly _hddid_wrap_drop_main
            global HDDID_WRAPPER_PKGDIR `"`_hddid_wrapper_dir'"'
            capture noisily run `"`_hddid_wrapper_dir'/_hddid_main.ado"'
            local _hddid_wrapper_run_rc = _rc
            if `_hddid_wrapper_run_rc' == 0 {
                capture program list _hddid_main
                local _hddid_wrapper_prog_rc = _rc
            }
            if `_hddid_wrapper_run_rc' == 0 & `_hddid_wrapper_prog_rc' == 0 {
                global HDDID_WRAPPER_PKGDIR `"`_hddid_wrapper_dir'"'
                exit
            }
        }
        capture macro drop HDDID_WRAPPER_PKGDIR
        di as error "{bf:hddid}: wrapper could not load the implementation program {bf:_hddid_main}"
        di as error "  Explicit package directory: `explicit_pkgdir'"
        di as error "  Reason: source-running {bf:hddid.ado} with an explicit package directory must bind to that exact bundle, so wrapper loading fails closed instead of falling back to a different adopath/context copy"
        exit 198
    }
    if `"`_hddid_wrapper_dir'"' == "" {
        capture findfile _hddid_main.ado
        if _rc == 0 {
            local _hddid_wrapper_main `"`r(fn)'"'
            local _hddid_wrapper_sep = strrpos(`"`_hddid_wrapper_main'"', "/")
            if `_hddid_wrapper_sep' == 0 {
                local _hddid_wrapper_sep = strrpos(`"`_hddid_wrapper_main'"', "\")
            }
            if `_hddid_wrapper_sep' > 0 {
                local _hddid_wrapper_dir = substr(`"`_hddid_wrapper_main'"', 1, `_hddid_wrapper_sep' - 1)
            }
        }
    }
    if `"`_hddid_wrapper_dir'"' != "" {
        capture confirm file `"`_hddid_wrapper_dir'/_hddid_main.ado"'
        if _rc == 0 {
            quietly _hddid_wrap_drop_main
            global HDDID_WRAPPER_PKGDIR `"`_hddid_wrapper_dir'"'
            capture noisily run `"`_hddid_wrapper_dir'/_hddid_main.ado"'
            local _hddid_wrapper_run_rc = _rc
            if `_hddid_wrapper_run_rc' == 0 {
                capture program list _hddid_main
                local _hddid_wrapper_prog_rc = _rc
            }
            if `_hddid_wrapper_run_rc' == 0 & `_hddid_wrapper_prog_rc' == 0 {
                global HDDID_WRAPPER_PKGDIR `"`_hddid_wrapper_dir'"'
                exit
            }
        }
    }
end

capture program drop _hddid_wrap_has_surface
program define _hddid_wrap_has_surface, rclass
    version 16
    local _hddid_active_surface = (`"`e(cmd)'"' == "hddid")
    if `_hddid_active_surface' == 0 {
        if `"`e(predict)'"' == "hddid_p" | `"`e(estat_cmd)'"' == "hddid_estat" {
            local _hddid_active_surface 1
        }
    }
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
            // Current replay/postestimation can still recover the original
            // outcome-role label from the successful-call depvar token when
            // both duplicate depvar locals are absent.
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
        if `_hddid_has_p' & `_hddid_has_k' & `_hddid_has_q' & ///
            `_hddid_has_N' & ///
            `_hddid_has_xdebias' & `_hddid_has_stdx' & ///
            `_hddid_has_gdebias' & `_hddid_has_z0' & ///
            (`_hddid_has_stdg' | `_hddid_has_CIpoint' | `_hddid_has_CIuniform') & ///
            `"`_hddid_treat_probe'"' != "" & `"`_hddid_xvars_probe'"' != "" & ///
            `"`_hddid_zvar_probe'"' != "" & `"`_hddid_method_probe'"' != "" & ///
            (`"`_hddid_depvar_probe'"' != "" | `"`_hddid_depvar_role_probe'"' != "") {
            // Match the broader current-surface classification already used by
            // replay/display fallback: current role provenance can remain
            // recoverable from e(cmdline) or the posted beta labels even when
            // one wrapper-local role label is absent, and wrapper fail-close
            // must also recognize the same current HDDID surface when e(stdg)
            // or e(alpha) is the malformed field but CIpoint/CIuniform still
            // advertise the surrounding nonparametric interval surface.
            local _hddid_active_surface 1
        }
    }
    return scalar active_surface = `_hddid_active_surface'
end

capture args _hddid_source_run_pkgdir
if `"`_hddid_source_run_pkgdir'"' == "" {
    capture macro drop HDDID_WRAPPER_PKGDIR
}
capture _return hold __hddid_wrapper_source_run_r
quietly _hddid_wrapper_try_load_main `"`_hddid_source_run_pkgdir'"'
capture _return restore __hddid_wrapper_source_run_r

capture program drop hddid
program define hddid, eclass
    local _hddid_source_run_pkgdir `"$HDDID_WRAPPER_PKGDIR"'
    if `"`_hddid_source_run_pkgdir'"' == "" {
        local _hddid_source_run_pkgdir `"$HDDID_SOURCE_RUN_PKGDIR"'
    }
    capture noisily _hddid_wrapper_try_load_main `"`_hddid_source_run_pkgdir'"'
    local _hddid_wrapper_load_rc = _rc
    capture program list _hddid_main
    if `_hddid_wrapper_load_rc' != 0 | _rc != 0 {
        // Fail closed on wrapper-load failure: leaving a stale HDDID e()
        // surface behind would make replay or the unsupported hddid_p /
        // hddid_estat stubs look like the failed current call succeeded.
        // Legacy/current replayable surfaces can survive with missing e(cmd),
        // blank e(predict)/e(estat_cmd), or other missing wrapper-only labels,
        // so detect the broader HDDID surface before deciding whether to clear.
        quietly _hddid_wrap_has_surface
        local _hddid_clear_surface = (r(active_surface) != 0)
        if `_hddid_clear_surface' {
            quietly ereturn clear
        }
        if `_hddid_wrapper_load_rc' == 0 | `"`_hddid_source_run_pkgdir'"' == "" {
            di as error "{bf:hddid}: wrapper could not load the implementation program {bf:_hddid_main}"
            di as error "  Source-run the wrapper with an explicit package directory or add the full hddid-stata bundle to adopath."
        }
        exit 198
    }
    _hddid_main `0'
end
