/*! version 1.0.0 */
capture program drop _hddid_disp_beta_coords
capture program drop _hddid_disp_preflight
capture program drop _hddid_display

program define _hddid_disp_beta_coords, rclass
    version 16
    return clear

    local _coords = strtrim(`"`e(xvars)'"')
    local _coords : list retokenize _coords

    if `"`_coords'"' == "" {
        capture confirm matrix e(xdebias)
        if _rc == 0 {
            tempname _xdebias_coords
            matrix `_xdebias_coords' = e(xdebias)
            local _coords : colnames `_xdebias_coords'
            local _coords : list retokenize _coords
        }
    }

    if `"`_coords'"' == "" {
        capture confirm matrix e(stdx)
        if _rc == 0 {
            tempname _stdx_coords
            matrix `_stdx_coords' = e(stdx)
            local _coords : colnames `_stdx_coords'
            local _coords : list retokenize _coords
        }
    }

    if `"`_coords'"' == "" {
        capture confirm matrix e(b)
        if _rc == 0 {
            tempname _b_coords
            matrix `_b_coords' = e(b)
            local _coords : colnames `_b_coords'
            local _coords : list retokenize _coords
        }
    }

    return local coords `"`_coords'"'
end

program define _hddid_disp_preflight
    capture program list _hddid_preflight_current_vectors
    if _rc == 0 {
        exit
    }

    local _hddid_pst_pkgdir `"$HDDID_SOURCE_RUN_PKGDIR"'
    if `"`_hddid_pst_pkgdir'"' == "" {
        local _hddid_pst_pkgdir `"$HDDID_WRAPPER_PKGDIR"'
    }
    if `"`_hddid_pst_pkgdir'"' == "" {
        local _hddid_pst_pkgdir `"$HDDID_PACKAGE_DIR"'
    }

    if `"`_hddid_pst_pkgdir'"' != "" {
        quietly capture run `"`_hddid_pst_pkgdir'/_hddid_preflight_current_vectors.ado"'
        capture program list _hddid_preflight_current_vectors
    }
    if _rc != 0 {
        capture findfile _hddid_preflight_current_vectors.ado
        if _rc == 0 {
            quietly capture run `"`r(fn)'"'
        }
    }

    capture program list _hddid_preflight_current_vectors
    if _rc != 0 {
        di as error "{bf:hddid}: failed to load {bf:_hddid_preflight_current_vectors.ado}"
        di as error "  Reason: replay on current results delegates beta/interval consistency checks to a sibling helper"
        di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
        exit 198
    }
end

program define _hddid_display
    // Replay reads only posted e() objects and assumes their column stripes
    // already match the z0 grid stored at estimation time.
    quietly _hddid_disp_beta_coords
    local xvars `"`r(coords)'"'
    capture confirm scalar e(p)
    local p = .
    if _rc {
        if `"`xvars'"' != "" {
            local _hddid_xvars_lc = lower(strtrim(`"`xvars'"'))
            local _hddid_xvars_lc : list retokenize _hddid_xvars_lc
            local _hddid_xcount : word count `_hddid_xvars_lc'
            if `_hddid_xcount' >= 1 {
                local p = `_hddid_xcount'
            }
        }
        if missing(`p') {
            capture confirm matrix e(b)
            if _rc == 0 {
                tempname _hddid_replay_b_width
                matrix `_hddid_replay_b_width' = e(b)
                if colsof(`_hddid_replay_b_width') >= 1 {
                    local p = colsof(`_hddid_replay_b_width')
                }
            }
        }
        if missing(`p') {
            di as error "{bf:hddid}: replay requires stored e(p) or a published beta surface width"
            di as error "  Reason: replay needs the parametric dimension from stored e(p), e(xvars), or the posted beta objects to validate the published beta surfaces"
            exit 498
        }
    }
    else {
        local p = e(p)
    }
    if missing(`p') | `p' < 1 | `p' != floor(`p') {
        di as error "{bf:hddid}: stored e(p) must be a finite integer >= 1"
        di as error "  Replay cannot validate beta object dimensions with an invalid x-dimension anchor"
        exit 498
    }
    local _depvar_eq_disp `"`e(depvar)'"'
    local _depvar_eq_disp = strtrim(`"`_depvar_eq_disp'"')
    local _depvar_eq_missing_disp = (`"`_depvar_eq_disp'"' == "")
    local _depvar_role_disp `"`e(depvar_role)'"'
    local _depvar_role_disp = strtrim(`"`_depvar_role_disp'"')
    local _cmdline_disp `"`e(cmdline)'"'
    local _cmdline_probe = strtrim(`"`_cmdline_disp'"')
    local _cmdline_parse_pre_disp `"`_cmdline_disp'"'
    local _cmdline_lc_pre_disp ""
    local _cmdline_depvar_pre_disp ""
    if `"`_cmdline_probe'"' != "" {
        local _cmdline_parse_pre_disp = ///
            subinstr(`"`_cmdline_parse_pre_disp'"', char(9), " ", .)
        local _cmdline_parse_pre_disp = ///
            subinstr(`"`_cmdline_parse_pre_disp'"', char(10), " ", .)
        local _cmdline_parse_pre_disp = ///
            subinstr(`"`_cmdline_parse_pre_disp'"', char(13), " ", .)
        local _cmdline_lc_pre_disp = lower(`"`_cmdline_parse_pre_disp'"')
        if regexm(`"`_cmdline_lc_pre_disp'"', "^[ ]*hddid[ ]+([^, ]+)") {
            local _cmdline_depvar_pre_disp = strtrim(regexs(1))
        }
    }
    local _cmdline_opts_pre_disp ""
    local _cmdline_has_method_pre_disp = 0
    local _cmdline_method_pre_disp ""
    local _cmdline_method_ok_pre_disp = 0
    local _cmdline_has_q_pre_disp = 0
    local _cmdline_q_value_pre_disp = .
    local _cmdline_q_ok_pre_disp = 0
    if `"`_cmdline_probe'"' != "" {
        if regexm(`"`_cmdline_lc_pre_disp'"', "^[ ]*hddid[^,]*,[ ]*(.*)$") {
            local _cmdline_opts_pre_disp = strtrim(regexs(1))
        }
        if regexm(`"`_cmdline_opts_pre_disp'"', "(^|[ ,])method[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_has_method_pre_disp = 1
            local _cmdline_method_pre_disp = strtrim(regexs(2))
            if strlen(`"`_cmdline_method_pre_disp'"') >= 2 {
                local _cmdline_method_first_pre_disp = substr(`"`_cmdline_method_pre_disp'"', 1, 1)
                local _cmdline_method_last_pre_disp = substr(`"`_cmdline_method_pre_disp'"', -1, 1)
                if (`"`_cmdline_method_first_pre_disp'"' == `"""' & ///
                    `"`_cmdline_method_last_pre_disp'"' == `"""') | ///
                    (`"`_cmdline_method_first_pre_disp'"' == "'" & ///
                    `"`_cmdline_method_last_pre_disp'"' == "'") {
                    local _cmdline_method_pre_disp = ///
                        substr(`"`_cmdline_method_pre_disp'"', 2, ///
                        strlen(`"`_cmdline_method_pre_disp'"') - 2)
                }
            }
            local _cmdline_method_pre_disp = ///
                strproper(strtrim(`"`_cmdline_method_pre_disp'"'))
            if inlist(`"`_cmdline_method_pre_disp'"', "Pol", "Tri") {
                local _cmdline_method_ok_pre_disp = 1
            }
        }
        if regexm(`"`_cmdline_opts_pre_disp'"', "(^|[ ,])q[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_has_q_pre_disp = 1
            local _cmdline_q_arg_pre_disp = strtrim(regexs(2))
            if regexm(`"`_cmdline_q_arg_pre_disp'"', "^[+]?[0-9]+$") {
                local _cmdline_q_value_pre_disp = real(`"`_cmdline_q_arg_pre_disp'"')
                if !missing(`_cmdline_q_value_pre_disp') & ///
                    `_cmdline_q_value_pre_disp' >= 1 {
                    local _cmdline_q_ok_pre_disp = 1
                }
            }
        }
    }
    local _fstage_mode_disp_raw `"`e(firststage_mode)'"'
    local _fstage_probe_disp = ///
        lower(strtrim(`"`_fstage_mode_disp_raw'"'))
    capture confirm scalar e(N_pretrim)
    local _has_n_pretrim_marker_disp = (_rc == 0)
    capture confirm scalar e(clime_nfolds_cv_max)
    local _has_clime_max_marker_disp = (_rc == 0)
    capture confirm scalar e(clime_nfolds_cv_effective_min)
    local _has_clime_effmin_marker_disp = (_rc == 0)
    capture confirm scalar e(clime_nfolds_cv_effective_max)
    local _has_clime_effmax_marker_disp = (_rc == 0)
    capture confirm matrix e(clime_nfolds_cv_per_fold)
    local _has_clime_perfold_marker_disp = (_rc == 0)
    local _nboot_disp .
    capture confirm scalar e(nboot)
    local _has_nboot_surface_disp = (_rc == 0)
    local _has_current_markers_disp = ///
        (`"`_fstage_probe_disp'"' != "" | ///
         `_has_n_pretrim_marker_disp' | ///
         `_has_clime_max_marker_disp' | ///
         `_has_clime_effmin_marker_disp' | ///
         `_has_clime_effmax_marker_disp' | ///
         `_has_clime_perfold_marker_disp')
    local _current_result_surface_disp = (`"`_depvar_role_disp'"' != "")
    if `_current_result_surface_disp' == 0 & ///
        `_depvar_eq_missing_disp' & ///
        `_has_current_markers_disp' & ///
        `"`_cmdline_depvar_pre_disp'"' != "" {
        local _current_result_surface_disp 1
        local _depvar_eq_disp "beta"
    }
    if `_depvar_eq_missing_disp' & `_current_result_surface_disp' {
        local _depvar_eq_disp "beta"
    }
    if `"`_depvar_eq_disp'"' == "" {
        di as error "{bf:hddid}: replay requires stored e(depvar)"
        di as error "  Reason: replay must keep the published beta-block equation label attached to the stored Stata eclass coefficients"
        exit 498
    }
    if `_current_result_surface_disp' == 0 & ///
        `"`_depvar_eq_disp'"' != "" & `"`_depvar_eq_disp'"' != "beta" & ///
        `_has_current_markers_disp' {
        di as error "{bf:hddid}: stored e(depvar) must be {bf:beta} on current results"
        di as error "  Reason: current hddid results are already identified by current-only machine-readable metadata such as {bf:e(firststage_mode)}, {bf:e(N_pretrim)}, or the published CLIME fold-provenance block, so {bf:e(depvar)} must remain the generic beta-block label rather than a legacy outcome-role name."
        exit 498
    }
    if `_current_result_surface_disp' == 0 & ///
        `"`_depvar_eq_disp'"' == "beta" & ///
        `_has_current_markers_disp' {
        local _current_result_surface_disp 1
        if `_depvar_eq_missing_disp' {
            local _depvar_eq_disp "beta"
        }
    }
    local _depvar_role_from_cmdline_disp 0
    if `"`_depvar_role_disp'"' == "" & ///
        `"`_depvar_eq_disp'"' == "beta" & `_current_result_surface_disp' {
        if `"`_cmdline_depvar_pre_disp'"' != "" {
            local _depvar_role_disp `"`_cmdline_depvar_pre_disp'"'
            local _depvar_role_from_cmdline_disp 1
        }
        else {
            di as error "{bf:hddid}: replay requires stored e(depvar_role) or current e(cmdline) depvar provenance"
            di as error "  Reason: once current-only metadata such as {bf:e(firststage_mode)}, {bf:e(N_pretrim)}, or the published CLIME fold-provenance block is present, {bf:e(depvar)=beta} is only the generic beta-block label, so replay must recover the original outcome-role label from {bf:e(depvar_role)} or the successful-call record in {bf:e(cmdline)}."
            exit 498
        }
    }
    if `"`_depvar_role_disp'"' != "" {
        if `"`_depvar_eq_disp'"' != "beta" {
            di as error "{bf:hddid}: stored e(depvar) must be {bf:beta} when e(depvar_role) is present"
            di as error "  Reason: current hddid results separate the generic beta-block label from the original outcome-role label"
            exit 498
        }
        local _depvar_disp `"`_depvar_role_disp'"'
    }
    else {
        local _depvar_disp `"`_depvar_eq_disp'"'
    }
    if `_current_result_surface_disp' {
        _hddid_disp_preflight
    }
    local _tc0_alpha_pre_disp 0
    if `_current_result_surface_disp' {
        _hddid_preflight_current_vectors, mode(replay)
        capture confirm matrix e(tc)
        local _has_tc_alpha_pre_disp = (_rc == 0)
        capture confirm matrix e(CIuniform)
        local _has_ciuniform_alpha_pre_disp = (_rc == 0)
        capture confirm matrix e(gdebias)
        local _has_gdebias_alpha_pre_disp = (_rc == 0)
        capture confirm matrix e(stdg)
        local _has_stdg_alpha_pre_disp = (_rc == 0)
        if `_has_tc_alpha_pre_disp' & `_has_ciuniform_alpha_pre_disp' & ///
            `_has_gdebias_alpha_pre_disp' & `_has_stdg_alpha_pre_disp' {
            tempname _tc_alpha_pre_disp _tc_alpha_tol_pre_disp _stdg_abs_alpha_pre_disp _ciu_gap_alpha_pre_disp _ciu_scale_alpha_pre_disp
            matrix `_tc_alpha_pre_disp' = e(tc)
            mata: st_numscalar("`_stdg_abs_alpha_pre_disp'", max(abs(st_matrix("e(stdg)")))); ///
                _hddid_ciu_alpha_pre = st_matrix("e(gdebias)") \ st_matrix("e(gdebias)"); ///
                st_numscalar("`_ciu_gap_alpha_pre_disp'", max(abs(st_matrix("e(CIuniform)") :- _hddid_ciu_alpha_pre))); ///
                st_numscalar("`_ciu_scale_alpha_pre_disp'", max((1, max(abs(st_matrix("e(CIuniform)"))), max(abs(_hddid_ciu_alpha_pre)))))
            scalar `_tc_alpha_tol_pre_disp' = 1e-12 * scalar(`_ciu_scale_alpha_pre_disp')
            if rowsof(`_tc_alpha_pre_disp') == 1 & ///
                colsof(`_tc_alpha_pre_disp') == 2 & ///
                abs(`_tc_alpha_pre_disp'[1,1]) <= scalar(`_tc_alpha_tol_pre_disp') & ///
                abs(`_tc_alpha_pre_disp'[1,2]) <= scalar(`_tc_alpha_tol_pre_disp') & ///
                scalar(`_stdg_abs_alpha_pre_disp') <= scalar(`_tc_alpha_tol_pre_disp') & ///
                scalar(`_ciu_gap_alpha_pre_disp') <= scalar(`_tc_alpha_tol_pre_disp') {
                local _tc0_alpha_pre_disp 1
            }
        }
    }
    local _cmdline_has_alpha_pre_disp = 0
    local _cmdline_alpha_value_pre_disp = .
    local _cmdline_alpha_ok_pre_disp = 0
    local _cmdline_has_nboot_pre_disp = 0
    if regexm(`"`_cmdline_opts_pre_disp'"', "(^|[ ,])alpha[(][ ]*([^)]*)[ ]*[)]") {
        local _cmdline_has_alpha_pre_disp = 1
        local _cmdline_alpha_arg_pre_disp = strtrim(regexs(2))
        if regexm(`"`_cmdline_alpha_arg_pre_disp'"', ///
            "^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$") {
            local _cmdline_alpha_value_pre_disp = real(`"`_cmdline_alpha_arg_pre_disp'"')
            if !missing(`_cmdline_alpha_value_pre_disp') & ///
                `_cmdline_alpha_value_pre_disp' > 0 & ///
                `_cmdline_alpha_value_pre_disp' < 1 {
                local _cmdline_alpha_ok_pre_disp = 1
            }
        }
    }
    if regexm(`"`_cmdline_opts_pre_disp'"', "(^|[ ,])nboot[(][ ]*[^)]*[)]") {
        local _cmdline_has_nboot_pre_disp = 1
    }
    capture confirm scalar e(alpha)
    local _has_alpha_disp = (_rc == 0)
    local _alpha_disp = .
    if `_has_alpha_disp' {
        local _alpha_disp = e(alpha)
        if missing(`_alpha_disp') | `_alpha_disp' <= 0 | `_alpha_disp' >= 1 {
            di as error "{bf:hddid}: stored e(alpha) must be a finite scalar in (0, 1)"
            di as error "  Replay cannot report the published pointwise or bootstrap interval objects with an invalid significance level"
            exit 498
        }
    }
    else if `_current_result_surface_disp' & `_cmdline_has_alpha_pre_disp' & ///
        `_cmdline_alpha_ok_pre_disp' {
        local _alpha_disp = `_cmdline_alpha_value_pre_disp'
    }
    else if `_has_alpha_disp' == 0 & ///
        (`_current_result_surface_disp' == 0 | `_cmdline_has_alpha_pre_disp' == 0) {
        if `_current_result_surface_disp' {
            di as error "{bf:hddid}: replay requires stored e(alpha) or valid current e(cmdline) alpha() provenance"
        }
        else {
            di as error "{bf:hddid}: replay requires stored e(alpha)"
        }
        if `_tc0_alpha_pre_disp' {
            di as error "  Reason: on this degenerate zero-SE shortcut, replay still requires shared pointwise-significance provenance for the analytic {bf:e(CIpoint)} intervals."
            di as error "          It does not recalibrate the collapsed {bf:e(CIuniform)} object because that published nonparametric interval object already equals {bf:e(gdebias)}."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: replay reports the shared significance level behind the realized {bf:e(CIpoint)} object, and the same significance level also calibrates the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object."
        }
        exit 498
    }
    capture confirm scalar e(nboot)
    local _has_nboot_disp = (_rc == 0)
    capture confirm matrix e(tc)
    local _has_tc_bundle_disp = (_rc == 0)
    capture confirm matrix e(CIuniform)
    local _has_ciuniform_bundle_disp = (_rc == 0)
    if `_has_nboot_disp' {
        local _nboot_disp = e(nboot)
        if missing(`_nboot_disp') | `_nboot_disp' < 2 | ///
            `_nboot_disp' != floor(`_nboot_disp') {
            di as error "{bf:hddid}: stored e(nboot) must be an integer >= 2"
            if `_tc0_alpha_pre_disp' {
                di as error "  Reason: on this degenerate zero-SE shortcut, replay still requires stored {bf:e(nboot)} as machine-readable current-surface configuration metadata."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Replay cannot report the published CIuniform interval object with an invalid bootstrap replication count"
            }
            exit 498
        }
    }
    else if `_current_result_surface_disp' & ///
        `_has_tc_bundle_disp' & `_has_ciuniform_bundle_disp' & ///
        `_cmdline_has_nboot_pre_disp' == 0 {
        di as error "{bf:hddid}: replay requires stored e(nboot)"
        if `_tc0_alpha_pre_disp' {
            di as error "  Reason: on this degenerate zero-SE shortcut, replay still requires stored {bf:e(nboot)} as machine-readable current-surface configuration metadata."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: replay reports the bootstrap replication count behind the realized {bf:e(tc)}/{bf:e(CIuniform)} interval object."
        }
        exit 498
    }
    local _seed_disp .
    capture confirm scalar e(seed)
    local _has_seed_disp = (_rc == 0)
    if `_has_seed_disp' {
        local _seed_disp = e(seed)
        if missing(`_seed_disp') | `_seed_disp' < 0 | ///
            `_seed_disp' > 2147483647 | ///
            `_seed_disp' != floor(`_seed_disp') {
            di as error "{bf:hddid}: stored e(seed) must be a finite integer in [0, 2147483647]"
            if `_tc0_alpha_pre_disp' {
                di as error "  Reason: on this degenerate zero-SE shortcut, replay still requires finite stored {bf:e(seed)} as machine-readable current-surface RNG metadata."
                di as error "          That metadata still pins the realized outer fold assignment and Python CLIME CV splitting."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Replay cannot report published seed provenance with invalid seed metadata"
            }
            exit 498
        }
    }
    local _method_disp_raw = strtrim(`"`e(method)'"')
    if `"`_method_disp_raw'"' == "" {
        if `_current_result_surface_disp' & `"`_cmdline_probe'"' != "" {
            if `_cmdline_has_method_pre_disp' & `_cmdline_method_ok_pre_disp' {
                local _method_disp_raw `"`_cmdline_method_pre_disp'"'
            }
            else if `_cmdline_has_method_pre_disp' == 0 {
                local _method_disp_raw "Pol"
            }
            else {
                di as error "{bf:hddid}: replay requires stored e(method) or valid current e(cmdline) method() provenance"
                di as error "  Reason: replay must identify whether the published sieve fit used the polynomial or trigonometric basis"
                exit 498
            }
        }
        else {
            di as error "{bf:hddid}: replay requires stored e(method)"
            di as error "  Reason: replay must identify whether the published sieve fit used the polynomial or trigonometric basis"
            exit 498
        }
    }
    local _method_disp = strproper(strlower(`"`_method_disp_raw'"'))
    if !inlist(`"`_method_disp'"', "Pol", "Tri") {
        di as error "{bf:hddid}: stored e(method) must be Pol or Tri"
        di as error "  Replay cannot describe the published sieve basis with an out-of-domain method label: {bf:`_method_disp_raw'}"
        exit 498
    }
    if `"`_method_disp'"' == "Tri" {
        capture confirm scalar e(z_support_min)
        local _has_z_support_min_disp = (_rc == 0)
        capture confirm scalar e(z_support_max)
        local _has_z_support_max_disp = (_rc == 0)
        if `_has_z_support_min_disp' == 0 | `_has_z_support_max_disp' == 0 {
            di as error "{bf:hddid}: replay requires stored e(z_support_min) and e(z_support_max)"
            di as error "  Reason: method(Tri) is defined on the support-normalized coordinate u=(z-z_min)/(z_max-z_min), so replay must know the published retained support endpoints"
            exit 498
        }
        local _z_support_min_disp = e(z_support_min)
        local _z_support_max_disp = e(z_support_max)
        if missing(`_z_support_min_disp') | missing(`_z_support_max_disp') | ///
            `_z_support_min_disp' >= `_z_support_max_disp' {
            di as error "{bf:hddid}: stored Tri support endpoints must satisfy finite z_support_min < z_support_max"
            di as error "  Replay found z_support_min = " %12.8g `_z_support_min_disp' ///
                " and z_support_max = " %12.8g `_z_support_max_disp'
            exit 498
        }
    }
    capture confirm scalar e(N)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(N)"
        di as error "  Reason: replay reports the final post-trim estimation-sample count"
        exit 498
    }
    local _N_disp = e(N)
    if missing(`_N_disp') | `_N_disp' < 1 | `_N_disp' != floor(`_N_disp') {
        di as error "{bf:hddid}: stored e(N) must be a finite integer >= 1"
        di as error "  Replay cannot report final estimation-sample size with invalid sample-count metadata"
        exit 498
    }
    capture confirm scalar e(k)
    if _rc {
        capture confirm matrix e(N_per_fold)
        if _rc {
            di as error "{bf:hddid}: replay requires stored e(k) or a valid stored e(N_per_fold)"
            di as error "  Reason: replay reports the number of outer cross-fitting folds from the duplicate scalar {bf:e(k)} or, when that scalar is absent, from the published fold-count rowvector {bf:e(N_per_fold)}"
            exit 498
        }
        tempname _N_per_fold_k_probe_disp
        matrix `_N_per_fold_k_probe_disp' = e(N_per_fold)
        if rowsof(`_N_per_fold_k_probe_disp') != 1 | ///
            colsof(`_N_per_fold_k_probe_disp') < 2 {
            di as error "{bf:hddid}: stored e(N_per_fold) must be a 1 x k rowvector with k >= 2 when stored e(k) is absent"
            di as error "  Replay cannot recover the outer cross-fitting dimension from malformed fold-count metadata"
            exit 498
        }
        local _k_disp = colsof(`_N_per_fold_k_probe_disp')
    }
    else local _k_disp = e(k)
    if missing(`_k_disp') | `_k_disp' < 2 | `_k_disp' != floor(`_k_disp') {
        di as error "{bf:hddid}: stored e(k) must be a finite integer >= 2"
        di as error "  Replay cannot report cross-fitting metadata with fewer than two folds"
        exit 498
    }
    capture confirm scalar e(q)
    if _rc {
        if `_current_result_surface_disp' & `"`_cmdline_probe'"' != "" {
            if `_cmdline_has_q_pre_disp' & `_cmdline_q_ok_pre_disp' {
                local _q_disp = `_cmdline_q_value_pre_disp'
            }
            else if `_cmdline_has_q_pre_disp' == 0 {
                local _q_disp = 8
            }
            else {
                di as error "{bf:hddid}: replay requires stored e(q) or valid current e(cmdline) q() provenance"
                di as error "  Reason: replay reports the stored sieve-basis order"
                exit 498
            }
        }
        else {
            di as error "{bf:hddid}: replay requires stored e(q)"
            di as error "  Reason: replay reports the stored sieve-basis order"
            exit 498
        }
    }
    else local _q_disp = e(q)
    if missing(`_q_disp') | `_q_disp' < 1 | `_q_disp' != floor(`_q_disp') {
        di as error "{bf:hddid}: stored e(q) must be a finite integer >= 1"
        di as error "  Replay cannot describe the published sieve basis with an invalid order"
        exit 498
    }
    if `"`_method_disp'"' == "Tri" & mod(`_q_disp', 2) != 0 {
        di as error "{bf:hddid}: stored e(q) must be even when e(method) = {bf:Tri}"
        di as error "  Reason: the published trigonometric basis is indexed by cosine/sine pairs, so replay cannot describe a valid current-result Tri sieve from an odd q"
        exit 498
    }
    local _has_N_trimmed_disp = 0
    local _N_trimmed_disp = .
    capture confirm scalar e(N_trimmed)
    if _rc == 0 {
        local _has_N_trimmed_disp 1
        local _N_trimmed_disp = e(N_trimmed)
        if missing(`_N_trimmed_disp') | `_N_trimmed_disp' < 0 | ///
            `_N_trimmed_disp' != floor(`_N_trimmed_disp') {
            di as error "{bf:hddid}: stored e(N_trimmed) must be a finite integer >= 0"
            di as error "  Replay cannot report overlap-trimming metadata with an invalid count"
            exit 498
        }
    }
    capture confirm scalar e(N_pretrim)
    local _has_N_pretrim_disp = (_rc == 0)
    local _N_pretrim_disp = .
    if `_has_N_pretrim_disp' {
        local _N_pretrim_disp = e(N_pretrim)
        if missing(`_N_pretrim_disp') | ///
            `_N_pretrim_disp' < `_N_disp' | ///
            `_N_pretrim_disp' != floor(`_N_pretrim_disp') {
            di as error "{bf:hddid}: stored e(N_pretrim) must be a finite integer >= stored e(N)"
            di as error "  Replay found e(N_pretrim) = " %9.0f `_N_pretrim_disp' ///
                " and e(N) = " %9.0f `_N_disp'
            exit 498
        }
        if `_has_N_trimmed_disp' & ///
            `_N_trimmed_disp' != (`_N_pretrim_disp' - `_N_disp') {
            di as error "{bf:hddid}: stored e(N_trimmed) must equal stored e(N_pretrim) - e(N)"
            di as error "  Replay found e(N_trimmed) = " %9.0f `_N_trimmed_disp' ///
                ", e(N_pretrim) = " %9.0f `_N_pretrim_disp' ///
                ", and e(N) = " %9.0f `_N_disp'
            exit 498
        }
    }
    // Current and legacy replay are defined by the posted beta/f(z0) objects.
    // Stata wrapper labels such as e(predict), e(estat_cmd),
    // e(marginsnotok), e(vce), or e(vcetype) are useful for routing and
    // display, but replay can still show a coherent stored estimator surface
    // when only those wrapper labels are absent or malformed.
    if `_current_result_surface_disp' {
        local _predict_disp `"`e(predict)'"'
        local _predict_disp = strtrim(`"`_predict_disp'"')
        if `"`_predict_disp'"' != "hddid_p" {
            local _predict_disp "hddid_p"
        }
        local _estat_cmd_disp = strtrim(`"`e(estat_cmd)'"')
        if `"`_estat_cmd_disp'"' != "hddid_estat" {
            local _estat_cmd_disp "hddid_estat"
        }
        local _marginsnotok_disp = strtrim(`"`e(marginsnotok)'"')
        if `"`_marginsnotok_disp'"' != "_ALL" {
            local _marginsnotok_disp "_ALL"
        }
        local _vce_disp `"`e(vce)'"'
        local _vce_disp = strtrim(`"`_vce_disp'"')
        // e(vce) is only the machine-readable variance tag paired with the
        // already-posted covariance surface e(V); replay can therefore fall
        // back to the canonical HDDID tag when it is absent or malformed.
        if `"`_vce_disp'"' != "robust" {
            local _vce_disp "robust"
        }
        local _vcetype_disp `"`e(vcetype)'"'
        local _vcetype_disp = strtrim(`"`_vcetype_disp'"')
        // e(vcetype) is only the human-readable display label paired with the
        // already-posted covariance surface e(V); replay can therefore fall
        // back to the canonical HDDID label when it is absent or malformed.
        if `"`_vcetype_disp'"' != "Robust" {
            local _vcetype_disp "Robust"
        }
    }
    local _properties_disp `"`e(properties)'"'
    local _properties_disp : list retokenize _properties_disp
    // e(properties) is only Stata wrapper capability metadata.  The paper and
    // hddid-r define the replayed HDDID surface through the posted numeric
    // objects e(b), e(V), e(xdebias), e(gdebias), e(CIpoint), and e(CIuniform),
    // so coherent saved results may still replay even when the capability label
    // is absent or malformed.
    // The stored outer-split count pins fold assignment before retained-sample
    // aggregation. Legacy surfaces and current nofirst surfaces only need that
    // broader split to cover the retained sample e(N), but current internal
    // surfaces pin the split on the pretrim score sample e(N_pretrim).
    local _N_outer_split_floor_disp = `_N_disp'
    local _N_outer_split_floor_label "e(N)"
    local _has_N_outer_split_disp 0
    capture confirm scalar e(N_outer_split)
    if _rc {
        if `"`_depvar_role_disp'"' != "" {
            di as error "{bf:hddid}: replay requires stored e(N_outer_split)"
            di as error "  Reason: current hddid results publish the outer-split sample count that pins the stored fold assignment before retained-sample accounting"
            exit 498
        }
    }
    else {
        local _N_outer_split_disp = e(N_outer_split)
        local _has_N_outer_split_disp 1
    }
    if `_current_result_surface_disp' & `"`_depvar_role_disp'"' != "" & ///
        `_has_N_outer_split_disp' {
        if `"`_fstage_probe_disp'"' == "internal" & `_has_N_pretrim_disp' {
            if missing(`_N_outer_split_disp') | ///
                `_N_outer_split_disp' != floor(`_N_outer_split_disp') | ///
                `_N_outer_split_disp' != `_N_pretrim_disp' {
                di as error "{bf:hddid}: stored e(N_outer_split) must equal stored e(N_pretrim) for current internal results"
                di as error "  Replay found e(N_outer_split) = " %9.0f `_N_outer_split_disp' ///
                    ", stored e(N_pretrim) = " %9.0f `_N_pretrim_disp'
                di as error "  Reason: current internal results publish fold-pinning split metadata before ancillary seed()/alpha()/nboot() provenance, so replay fails on malformed outer-split counts first."
                exit 498
            }
        }
        else if `"`_fstage_probe_disp'"' == "nofirst" {
            if missing(`_N_outer_split_disp') | ///
                `_N_outer_split_disp' < `_N_disp' | ///
                `_N_outer_split_disp' != floor(`_N_outer_split_disp') {
                di as error "{bf:hddid}: stored e(N_outer_split) must be a finite integer >= stored e(N) for current nofirst results"
                di as error "  Replay found e(N_outer_split) = " %9.0f `_N_outer_split_disp' ///
                    ", stored e(N) = " %9.0f `_N_disp'
                di as error "  Reason: current nofirst results publish fold-pinning split metadata before ancillary seed()/alpha()/nboot() provenance, so replay fails on malformed outer-split counts first."
                exit 498
            }
        }
    }
    local _N_per_fold_summary "unavailable on legacy saved results"
    capture confirm matrix e(N_per_fold)
    if _rc {
        if `_current_result_surface_disp' {
            di as error "{bf:hddid}: replay requires stored e(N_per_fold)"
            di as error "  Reason: replay must validate the published retained-sample fold accounting before display"
            exit 498
        }
    }
    tempname _N_per_fold_disp
    if _rc == 0 {
        matrix `_N_per_fold_disp' = e(N_per_fold)
        if rowsof(`_N_per_fold_disp') != 1 | ///
            colsof(`_N_per_fold_disp') != `_k_disp' {
            di as error "{bf:hddid}: stored e(N_per_fold) must be a 1 x k rowvector"
            di as error "  Got " rowsof(`_N_per_fold_disp') " x " ///
                colsof(`_N_per_fold_disp') "; replay expects k = `_k_disp'"
            exit 498
        }
        local _N_per_fold_sum = 0
        local _N_per_fold_summary ""
        local _N_per_fold_sep ""
        forvalues _kk = 1/`_k_disp' {
            local _N_per_fold_val = `_N_per_fold_disp'[1, `_kk']
            if missing(`_N_per_fold_val') | ///
                `_N_per_fold_val' < 1 | ///
                `_N_per_fold_val' != floor(`_N_per_fold_val') {
                di as error "{bf:hddid}: stored e(N_per_fold) entries must be finite integers >= 1"
                di as error "  Replay found e(N_per_fold)[1,`_kk'] = " ///
                    %9.0f `_N_per_fold_val'
                exit 498
            }
            local _N_per_fold_sum = `_N_per_fold_sum' + `_N_per_fold_val'
            local _N_per_fold_summary ///
                `"`_N_per_fold_summary'`_N_per_fold_sep'fold_`_kk'=`_N_per_fold_val'"'
            local _N_per_fold_sep ", "
        }
        if `_N_per_fold_sum' != `_N_disp' {
            di as error "{bf:hddid}: stored e(N_per_fold) must sum to stored e(N)"
            di as error "  Replay found sum(e(N_per_fold)) = " ///
                %9.0f `_N_per_fold_sum' " but e(N) = " %9.0f `_N_disp'
            exit 498
        }
    }
    local _N_esample_disp = .
    capture quietly count if e(sample)
    if _rc == 0 {
        local _N_esample_disp = r(N)
    }
    local _replay_role_data_present 1
    capture confirm variable `_depvar_disp'
    if _rc {
        local _replay_role_data_present 0
    }
    capture confirm variable `_treat_disp'
    if _rc {
        local _replay_role_data_present 0
    }
    capture confirm variable `_zvar_disp'
    if _rc {
        local _replay_role_data_present 0
    }
    foreach _xvar_disp of local xvars {
        capture confirm variable `_xvar_disp'
        if _rc {
            local _replay_role_data_present 0
        }
    }
    // Replay is display-only over the posted e() surface. A live e(sample)
    // count is therefore at most informational: the current data may have
    // been subsetted or otherwise changed since estimation while the stored
    // result surface remains internally coherent.
    local _replay_linesize = c(linesize)
    local _cmdline_disp `"`e(cmdline)'"'
    local _cmdline_probe = strtrim(`"`_cmdline_disp'"')
    local _cmdline_parse_disp `"`_cmdline_disp'"'
    local _firststage_mode_disp `"`_fstage_mode_disp_raw'"'
    local _firststage_mode_probe = lower(strtrim(`"`_firststage_mode_disp'"'))
    capture confirm scalar e(propensity_nfolds)
    local _has_prop_nf_m_disp = (_rc == 0)
    capture confirm scalar e(outcome_nfolds)
    local _has_out_nf_m_disp = (_rc == 0)
    if `"`_cmdline_probe'"' == "" & `"`_firststage_mode_probe'"' == "" {
        if `_current_result_surface_disp' {
            if (`_has_prop_nf_m_disp' + `_has_out_nf_m_disp') == 1 {
                di as error "{bf:hddid}: current results require stored e(propensity_nfolds) and e(outcome_nfolds) when first-stage provenance is recovered from fold metadata"
                di as error "  Reason: replay must disclose the published paired internal-only fold block {bf:e(propensity_nfolds)}/{bf:e(outcome_nfolds)} before a current saved-results surface can be classified as an internal first-stage fit."
                exit 498
            }
            else if `_has_prop_nf_m_disp' & `_has_out_nf_m_disp' {
                local _firststage_mode_disp "internal"
                local _firststage_mode_probe "internal"
            }
        }
    }
    if `"`_cmdline_probe'"' == "" & `"`_firststage_mode_probe'"' == "" {
        if `_current_result_surface_disp' {
            di as error "{bf:hddid}: current results require stored e(firststage_mode)"
            di as error "  Reason: current hddid replay interprets first-stage provenance from machine-readable {bf:e(firststage_mode)}={bf:internal}/{bf:nofirst}, from the published paired internal-only fold block {bf:e(propensity_nfolds)}/{bf:e(outcome_nfolds)}, or from the successful-call record in {bf:e(cmdline)}; it only fails closed when all three are unavailable on a malformed current saved-results surface."
            exit 498
        }
        di as error "{bf:hddid}: replay requires stored e(cmdline)"
        di as error "  Reason: legacy results without e(firststage_mode) need the successful-call provenance record to classify the first-stage path"
        exit 498
    }
    local _cmdline_has_nofirst_disp = 0
    local _cmd_has_roles_disp = 0
    local _cmdline_depvar_disp ""
    local _cmdline_treat_disp ""
    local _cmdline_xvars_disp ""
    local _cmdline_zvar_disp ""
    local _cmdline_lc_disp ""
    local _cmdline_opts_disp ""
    local _cmdline_comma_disp = 0
    local _cmdline_dup_role_opts = 0
    if `"`_cmdline_probe'"' != "" {
        // Stata command syntax accepts tabs/newlines as whitespace. Normalize
        // those before parsing replay provenance so legal whitespace spelling
        // choices do not corrupt the stored role mapping contract.
        local _cmdline_parse_disp = ///
            subinstr(`"`_cmdline_parse_disp'"', char(9), " ", .)
        local _cmdline_parse_disp = ///
            subinstr(`"`_cmdline_parse_disp'"', char(10), " ", .)
        local _cmdline_parse_disp = ///
            subinstr(`"`_cmdline_parse_disp'"', char(13), " ", .)
        local _cmdline_lc_disp = lower(`"`_cmdline_parse_disp'"')
        local _cmdline_comma_disp = strpos(`"`_cmdline_lc_disp'"', ",")
        if `_cmdline_comma_disp' > 0 {
            local _cmdline_opts_disp = ///
                strtrim(substr(`"`_cmdline_lc_disp'"', `_cmdline_comma_disp' + 1, .))
        }
    }
    if regexm(`"`_cmdline_lc_disp'"', "^[ ]*hddid[ ]+([^, ]+)") {
        local _cmdline_depvar_disp = strtrim(regexs(1))
    }
    // Legacy cmdline fallback must inspect only the option list after the
    // comma. Positional text such as a depvar literally named nofirst does not
    // encode the first-stage path. Accept the same legal TREat()
    // abbreviations as formal syntax (tr()/tre()/trea()/treat()) while avoiding
    // escaped-parenthesis regex syntax that Stata's parser rejects.
    if `"`_cmdline_probe'"' != "" {
        local _cmdline_has_nofirst_disp = ///
            regexm(`"`_cmdline_opts_disp'"', ///
                "(^|[ ,])nof(i(r(s(t)?)?)?)?([ ,]|$)")
        local _cmd_has_roles_disp = ///
            regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])tr(e(a(t)?)?)?[(]") & ///
            regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])x[(]") & ///
            regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])z[(]")
        local _cmdline_role_probe_disp `"`_cmdline_opts_disp'"'
        if regexm(`"`_cmdline_role_probe_disp'"', "(^|[ ,])tr(e(a(t)?)?)?[(][^)]*[)]") {
            local _cmdline_role_probe_disp = ///
                regexr(`"`_cmdline_role_probe_disp'"', ///
                "(^|[ ,])tr(e(a(t)?)?)?[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_role_probe_disp'"', "(^|[ ,])tr(e(a(t)?)?)?[(]") {
                local _cmdline_dup_role_opts = 1
            }
        }
        local _cmdline_role_probe_disp `"`_cmdline_opts_disp'"'
        if regexm(`"`_cmdline_role_probe_disp'"', "(^|[ ,])x[(][^)]*[)]") {
            local _cmdline_role_probe_disp = ///
                regexr(`"`_cmdline_role_probe_disp'"', ///
                "(^|[ ,])x[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_role_probe_disp'"', "(^|[ ,])x[(]") {
                local _cmdline_dup_role_opts = 1
            }
        }
        local _cmdline_role_probe_disp `"`_cmdline_opts_disp'"'
        if regexm(`"`_cmdline_role_probe_disp'"', "(^|[ ,])z[(][^)]*[)]") {
            local _cmdline_role_probe_disp = ///
                regexr(`"`_cmdline_role_probe_disp'"', ///
                "(^|[ ,])z[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_role_probe_disp'"', "(^|[ ,])z[(]") {
                local _cmdline_dup_role_opts = 1
            }
        }
    }
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])tr(e(a(t)?)?)?[(]([^)]*)[)]") {
        local _cmdline_treat_disp = strtrim(regexs(5))
    }
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])x[(]([^)]*)[)]") {
        local _cmdline_xvars_disp = strtrim(regexs(2))
    }
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])z[(]([^)]*)[)]") {
        local _cmdline_zvar_disp = strtrim(regexs(2))
    }
    local _treat_disp = strtrim(`"`e(treat)'"')
    if `"`_treat_disp'"' == "" & `"`_cmdline_treat_disp'"' != "" & ///
        `_current_result_surface_disp' {
        local _treat_disp `"`_cmdline_treat_disp'"'
    }
    local _zvar_disp = strtrim(`"`e(zvar)'"')
    if `"`_zvar_disp'"' == "" & `"`_cmdline_zvar_disp'"' != "" & ///
        `_current_result_surface_disp' {
        local _zvar_disp `"`_cmdline_zvar_disp'"'
    }
    if `"`_treat_disp'"' == "" {
        di as error "{bf:hddid}: replay requires stored e(treat)"
        di as error "  Reason: replay must keep the published treatment-role label attached to the stored HDDID result unless current e(cmdline) still preserves that role provenance."
        exit 498
    }
    if `"`_zvar_disp'"' == "" {
        di as error "{bf:hddid}: replay requires stored e(zvar)"
        di as error "  Reason: replay must keep the published z-role label attached to the stored HDDID result unless current e(cmdline) still preserves that role provenance."
        exit 498
    }
    if `"`xvars'"' == "" & `_current_result_surface_disp' {
        quietly _hddid_disp_beta_coords
        local xvars `"`r(coords)'"'
    }
    if `"`xvars'"' == "" {
        di as error "{bf:hddid}: replay requires stored e(xvars)"
        di as error "  Reason: replay needs one published covariate label per beta entry; current results can only recover that coordinate order from the published beta-surface labels when they are still available."
        exit 498
    }
    local _xvars_retokenized = lower(strtrim(`"`xvars'"'))
    local _xvars_retokenized : list retokenize _xvars_retokenized
    local _xvars_count : word count `_xvars_retokenized'
    if `_xvars_count' != `p' {
        di as error "{bf:hddid}: stored e(xvars) must list exactly p covariate names"
        di as error "  Got `_xvars_count' names; replay expects p = `p'"
        exit 498
    }
    local _xvars_unique : list uniq _xvars_retokenized
    local _xvars_unique_count : word count `_xvars_unique'
    if `_xvars_unique_count' != `p' {
        di as error "{bf:hddid}: stored e(xvars) must list exactly p distinct covariate names"
        di as error "  Reason: replay indexes the published beta surface by one unique covariate label per coordinate"
        exit 498
    }
    if `_current_result_surface_disp' {
        capture confirm matrix e(tc)
        if _rc == 0 {
            tempname _tc_pre_disp
            matrix `_tc_pre_disp' = e(tc)
        local _tc_pre_names_disp : colnames `_tc_pre_disp'
        local _tc_pre_names_disp : list retokenize _tc_pre_names_disp
        if rowsof(`_tc_pre_disp') != 1 | colsof(`_tc_pre_disp') != 2 | ///
            missing(`_tc_pre_disp'[1,1]) | missing(`_tc_pre_disp'[1,2]) {
            di as error "{bf:hddid}: stored e(tc) must be a finite 1 x 2 rowvector"
            di as error "  Replay must validate the published CIuniform bootstrap provenance before ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if `"`_tc_pre_names_disp'"' != "tc_lower tc_upper" {
            di as error "{bf:hddid}: stored e(tc) must use colnames {bf:tc_lower tc_upper}"
            di as error "  Replay must validate unambiguous CIuniform bootstrap provenance before ancillary seed()/alpha()/nboot() cmdline checks: {bf:`_tc_pre_names_disp'}"
            exit 498
        }
        if `_tc_pre_disp'[1,1] > `_tc_pre_disp'[1,2] {
            di as error "{bf:hddid}: stored e(tc) must satisfy lower <= upper"
            di as error "  Replay must validate ordered CIuniform bootstrap provenance before ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        capture confirm matrix e(CIuniform)
        local _has_ciuniform_pre_disp = (_rc == 0)
        capture confirm matrix e(CIpoint)
        local _has_cipoint_pre_disp = (_rc == 0)
        capture confirm matrix e(xdebias)
        local _has_xdebias_pre_disp = (_rc == 0)
        capture confirm matrix e(stdx)
        local _has_stdx_pre_disp = (_rc == 0)
        capture confirm matrix e(gdebias)
        local _has_gdebias_pre_disp = (_rc == 0)
        capture confirm matrix e(stdg)
        local _has_stdg_pre_disp = (_rc == 0)
        _hddid_preflight_current_vectors, mode(replay)
        if `_has_ciuniform_pre_disp' & `_has_gdebias_pre_disp' & `_has_stdg_pre_disp' {
            tempname _ciuniform_gap_pre_disp _ciuniform_scale_pre_disp _ciuniform_tol_pre_disp
            mata: _hddid_ciuniform_actual_pre_disp = st_matrix("e(CIuniform)"); _hddid_gdebias_pre_disp = st_matrix("e(gdebias)"); _hddid_stdg_pre_disp = st_matrix("e(stdg)"); _hddid_tc_pre_disp = st_matrix("e(tc)"); _hddid_ciuniform_oracle_pre_disp = (_hddid_gdebias_pre_disp :+ _hddid_tc_pre_disp[1, 1] * _hddid_stdg_pre_disp) \ (_hddid_gdebias_pre_disp :+ _hddid_tc_pre_disp[1, 2] * _hddid_stdg_pre_disp); st_numscalar("`_ciuniform_gap_pre_disp'", max(abs(_hddid_ciuniform_actual_pre_disp :- _hddid_ciuniform_oracle_pre_disp))); st_numscalar("`_ciuniform_scale_pre_disp'", max((1, max(abs(_hddid_ciuniform_actual_pre_disp)), max(abs(_hddid_ciuniform_oracle_pre_disp)))))
            scalar `_ciuniform_tol_pre_disp' = 1e-12 * scalar(`_ciuniform_scale_pre_disp')
            if scalar(`_ciuniform_gap_pre_disp') > scalar(`_ciuniform_tol_pre_disp') {
                di as error "{bf:hddid}: stored e(CIuniform) must equal the lower/upper rows implied by e(gdebias), e(stdg), and e(tc)"
                di as error "  Replay must reject malformed current interval-object metadata before ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
            tempname _stdg0pd _ciug0pd _cius0pd
            mata: st_numscalar("`_stdg0pd'", max(abs(st_matrix("e(stdg)"))))
            mata: _hddid_ciu0pd = st_matrix("e(gdebias)") \ st_matrix("e(gdebias)")
            mata: st_numscalar("`_ciug0pd'", max(abs(st_matrix("e(CIuniform)") :- _hddid_ciu0pd)))
            mata: st_numscalar("`_cius0pd'", max((1, max(abs(st_matrix("e(CIuniform)"))), max(abs(_hddid_ciu0pd)))))
            if scalar(`_stdg0pd') <= scalar(`_ciuniform_tol_pre_disp') & ///
                scalar(`_ciug0pd') <= scalar(`_ciuniform_tol_pre_disp') & ///
                (abs(`_tc_pre_disp'[1,1]) > scalar(`_ciuniform_tol_pre_disp') | ///
                abs(`_tc_pre_disp'[1,2]) > scalar(`_ciuniform_tol_pre_disp')) {
                di as error "{bf:hddid}: stored e(tc) must equal (0, 0) when stored e(stdg) is identically zero"
                di as error "  Replay must reject impossible zero-SE bootstrap provenance before ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
        }
        if `_has_cipoint_pre_disp' & `_has_xdebias_pre_disp' & `_has_stdx_pre_disp' & ///
            `_has_gdebias_pre_disp' & `_has_stdg_pre_disp' {
            tempname _cipoint_gap_pre_disp _cipoint_scale_pre_disp _cipoint_tol_pre_disp _zcrit_pre_disp
            scalar `_zcrit_pre_disp' = invnormal(1 - `_alpha_disp' / 2)
            mata: st_numscalar("`_cipoint_gap_pre_disp'", ///
                max(abs(st_matrix("e(CIpoint)") :- ( ///
                (st_matrix("e(xdebias)") :- st_numscalar("`_zcrit_pre_disp'") :* st_matrix("e(stdx)"), ///
                 st_matrix("e(gdebias)") :- st_numscalar("`_zcrit_pre_disp'") :* st_matrix("e(stdg)")) \ ///
                (st_matrix("e(xdebias)") :+ st_numscalar("`_zcrit_pre_disp'") :* st_matrix("e(stdx)"), ///
                 st_matrix("e(gdebias)") :+ st_numscalar("`_zcrit_pre_disp'") :* st_matrix("e(stdg)")) )))); ///
                st_numscalar("`_cipoint_scale_pre_disp'", ///
                max((1, max(abs(st_matrix("e(CIpoint)"))), ///
                max(abs((st_matrix("e(xdebias)") :- st_numscalar("`_zcrit_pre_disp'") :* st_matrix("e(stdx)"), ///
                         st_matrix("e(gdebias)") :- st_numscalar("`_zcrit_pre_disp'") :* st_matrix("e(stdg)")) \ ///
                        (st_matrix("e(xdebias)") :+ st_numscalar("`_zcrit_pre_disp'") :* st_matrix("e(stdx)"), ///
                         st_matrix("e(gdebias)") :+ st_numscalar("`_zcrit_pre_disp'") :* st_matrix("e(stdg)")))))))
            scalar `_cipoint_tol_pre_disp' = 1e-12 * scalar(`_cipoint_scale_pre_disp')
            if scalar(`_cipoint_gap_pre_disp') > scalar(`_cipoint_tol_pre_disp') {
                di as error "{bf:hddid}: stored e(CIpoint) must equal the pointwise intervals implied by e(xdebias), e(stdx), e(gdebias), e(stdg), and e(alpha)"
                di as error "  Replay must reject malformed current pointwise interval metadata before ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
        }
    }
    }
    local _cmdline_has_seed_disp = ///
        regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])seed[(][ ]*[^)]*[)]")
    local _cmdline_has_alpha_disp = ///
        regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])alpha[(][ ]*[^)]*[)]")
    local _cmdline_has_nboot_disp = ///
        regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])nboot[(][ ]*[^)]*[)]")
    local _cmdline_has_method_disp = 0
    local _cmdline_method_disp ""
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])method[(][ ]*([^)]*)[ ]*[)]") {
        local _cmdline_has_method_disp = 1
        local _cmdline_method_disp = strtrim(regexs(2))
        if strlen(`"`_cmdline_method_disp'"') >= 2 {
            local _cmdline_method_first_disp = substr(`"`_cmdline_method_disp'"', 1, 1)
            local _cmdline_method_last_disp = substr(`"`_cmdline_method_disp'"', -1, 1)
            if (`"`_cmdline_method_first_disp'"' == `"""' & ///
                `"`_cmdline_method_last_disp'"' == `"""') | ///
                (`"`_cmdline_method_first_disp'"' == "'" & ///
                `"`_cmdline_method_last_disp'"' == "'") {
                local _cmdline_method_disp = substr(`"`_cmdline_method_disp'"', 2, ///
                    strlen(`"`_cmdline_method_disp'"') - 2)
            }
        }
        local _cmdline_method_disp = strproper(strtrim(`"`_cmdline_method_disp'"'))
    }
    local _cmdline_has_q_disp = 0
    local _cmdline_q_value_disp = .
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])q[(][ ]*([0-9]+)[ ]*[)]") {
        local _cmdline_has_q_disp = 1
        local _cmdline_q_value_disp = real(regexs(2))
    }
    local _cmdline_dup_seed_disp = 0
    local _cmdline_dup_alpha_disp = 0
    local _cmdline_dup_nboot_disp = 0
    local _cmdline_scalar_probe_disp `"`_cmdline_opts_disp'"'
    if regexm(`"`_cmdline_scalar_probe_disp'"', "(^|[ ,])seed[(][^)]*[)]") {
        local _cmdline_scalar_probe_disp = ///
            regexr(`"`_cmdline_scalar_probe_disp'"', ///
            "(^|[ ,])seed[(][^)]*[)]", " ")
        if regexm(`"`_cmdline_scalar_probe_disp'"', "(^|[ ,])seed[(]") {
            local _cmdline_dup_seed_disp = 1
        }
    }
    local _cmdline_scalar_probe_disp `"`_cmdline_opts_disp'"'
    if regexm(`"`_cmdline_scalar_probe_disp'"', "(^|[ ,])alpha[(][^)]*[)]") {
        local _cmdline_scalar_probe_disp = ///
            regexr(`"`_cmdline_scalar_probe_disp'"', ///
            "(^|[ ,])alpha[(][^)]*[)]", " ")
        if regexm(`"`_cmdline_scalar_probe_disp'"', "(^|[ ,])alpha[(]") {
            local _cmdline_dup_alpha_disp = 1
        }
    }
    local _cmdline_scalar_probe_disp `"`_cmdline_opts_disp'"'
    if regexm(`"`_cmdline_scalar_probe_disp'"', "(^|[ ,])nboot[(][^)]*[)]") {
        local _cmdline_scalar_probe_disp = ///
            regexr(`"`_cmdline_scalar_probe_disp'"', ///
            "(^|[ ,])nboot[(][^)]*[)]", " ")
        if regexm(`"`_cmdline_scalar_probe_disp'"', "(^|[ ,])nboot[(]") {
            local _cmdline_dup_nboot_disp = 1
        }
    }
    local _cmdline_seed_arg_disp ""
    local _cmdline_seed_value_disp = .
    local _cmdline_seed_ok_disp = 0
    local _cmdline_seed_suppressed_disp = 0
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])seed[(][ ]*([^)]*)[ ]*[)]") {
        local _cmdline_seed_arg_disp = strtrim(regexs(2))
        capture confirm number `_cmdline_seed_arg_disp'
        if _rc == 0 {
            local _cmdline_seed_value_disp = real(`"`_cmdline_seed_arg_disp'"')
            if !missing(`_cmdline_seed_value_disp') & ///
                `_cmdline_seed_value_disp' == floor(`_cmdline_seed_value_disp') & ///
                `_cmdline_seed_value_disp' == -1 {
                local _cmdline_seed_ok_disp = 1
                local _cmdline_seed_suppressed_disp = 1
            }
            else if !missing(`_cmdline_seed_value_disp') & ///
                `_cmdline_seed_value_disp' == floor(`_cmdline_seed_value_disp') & ///
                `_cmdline_seed_value_disp' >= 0 & ///
                `_cmdline_seed_value_disp' <= 2147483647 {
                local _cmdline_seed_ok_disp = 1
            }
        }
    }
    local _cmdline_alpha_arg_disp ""
    local _cmdline_alpha_value_disp = .
    local _cmdline_alpha_ok_disp = 0
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])alpha[(][ ]*([^)]*)[ ]*[)]") {
        local _cmdline_alpha_arg_disp = strtrim(regexs(2))
        if regexm(`"`_cmdline_alpha_arg_disp'"', ///
            "^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$") {
            local _cmdline_alpha_value_disp = real(`"`_cmdline_alpha_arg_disp'"')
            if !missing(`_cmdline_alpha_value_disp') & ///
                `_cmdline_alpha_value_disp' > 0 & ///
                `_cmdline_alpha_value_disp' < 1 {
                local _cmdline_alpha_ok_disp = 1
            }
        }
    }
    local _cmdline_nboot_arg_disp ""
    local _cmdline_nboot_value_disp = .
    local _cmdline_nboot_ok_disp = 0
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])nboot[(][ ]*([^)]*)[ ]*[)]") {
        local _cmdline_nboot_arg_disp = strtrim(regexs(2))
        if regexm(`"`_cmdline_nboot_arg_disp'"', "^[+]?[0-9]+$") {
            local _cmdline_nboot_value_disp = real(`"`_cmdline_nboot_arg_disp'"')
            if !missing(`_cmdline_nboot_value_disp') & ///
                `_cmdline_nboot_value_disp' >= 2 {
                local _cmdline_nboot_ok_disp = 1
            }
        }
    }
    local _tc_zero_shortcut_seed_disp = 0
    if `_current_result_surface_disp' {
        capture confirm matrix e(tc)
        local _has_tc_seed_disp = (_rc == 0)
        capture confirm matrix e(CIuniform)
        local _has_ciuniform_seed_disp = (_rc == 0)
        capture confirm matrix e(gdebias)
        local _has_gdebias_seed_disp = (_rc == 0)
        capture confirm matrix e(stdg)
        local _has_stdg_seed_disp = (_rc == 0)
        if `_has_tc_seed_disp' & `_has_ciuniform_seed_disp' & ///
            `_has_gdebias_seed_disp' & `_has_stdg_seed_disp' {
            tempname _tc_zero_seed_disp _tc_zero_tol_seed_disp _stdg_absmax_seed_disp _ciu_shortcut_gap_seed_disp _ciu_shortcut_scale_seed_disp
            matrix `_tc_zero_seed_disp' = e(tc)
            mata: st_numscalar("`_stdg_absmax_seed_disp'", max(abs(st_matrix("e(stdg)")))); ///
                _hddid_ciu_shortcut_seed_disp = st_matrix("e(gdebias)") \ st_matrix("e(gdebias)"); ///
                st_numscalar("`_ciu_shortcut_gap_seed_disp'", max(abs(st_matrix("e(CIuniform)") :- _hddid_ciu_shortcut_seed_disp))); ///
                st_numscalar("`_ciu_shortcut_scale_seed_disp'", max((1, max(abs(st_matrix("e(CIuniform)"))), max(abs(_hddid_ciu_shortcut_seed_disp)))))
            scalar `_tc_zero_tol_seed_disp' = 1e-12 * scalar(`_ciu_shortcut_scale_seed_disp')
            if rowsof(`_tc_zero_seed_disp') == 1 & colsof(`_tc_zero_seed_disp') == 2 & ///
                abs(`_tc_zero_seed_disp'[1,1]) <= scalar(`_tc_zero_tol_seed_disp') & ///
                abs(`_tc_zero_seed_disp'[1,2]) <= scalar(`_tc_zero_tol_seed_disp') & ///
                scalar(`_stdg_absmax_seed_disp') <= scalar(`_tc_zero_tol_seed_disp') & ///
                scalar(`_ciu_shortcut_gap_seed_disp') <= scalar(`_tc_zero_tol_seed_disp') {
                local _tc_zero_shortcut_seed_disp 1
            }
        }
    }
    if `_current_result_surface_disp' & `_cmdline_has_seed_disp' & ///
        `_cmdline_dup_seed_disp' {
        di as error "{bf:hddid}: stored e(cmdline) must encode seed() provenance at most once"
        di as error "  Replay found duplicated {bf:seed()} provenance in {bf:e(cmdline)} = {bf:`_cmdline_disp'}"
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still publish one atomic RNG provenance record for the realized outer fold assignment and Python CLIME CV splitting, so replay must fail closed on duplicated singleton seed metadata."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish one atomic RNG provenance record for the realized bootstrap path, so replay must fail closed on duplicated singleton seed metadata."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_seed_disp' & ///
        `_cmdline_seed_ok_disp' == 0 {
        di as error "{bf:hddid}: stored e(cmdline) seed() provenance must be a finite integer in [0, 2147483647]"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} with malformed explicit {bf:seed()} provenance: {bf:`_cmdline_seed_arg_disp'}"
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still reconcile explicit {bf:seed()} across the successful-call record and machine-readable {bf:e(seed)} for the realized outer fold assignment and Python CLIME CV splitting."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar behind the realized bootstrap path."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_seed_disp' & ///
        `_cmdline_seed_suppressed_disp' & `_has_seed_disp' {
        di as error "{bf:hddid}: stored e(cmdline) seed(-1) provenance forbids stored e(seed)"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but stored {bf:e(seed)} = {bf:`_seed_disp'}."
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, {bf:seed(-1)} is still the published no-reset sentinel, so current replay refuses a saved-results surface that simultaneously posts suppressed provenance and machine-readable metadata for the realized outer fold assignment and Python CLIME CV splitting."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: {bf:seed(-1)} is the published no-reset sentinel, so current replay refuses a saved-results surface that simultaneously posts suppressed and realized RNG provenance."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_seed_disp' & ///
        !`_cmdline_seed_suppressed_disp' & ///
        `_has_seed_disp' == 0 {
        di as error "{bf:hddid}: current results with stored e(cmdline) seed() provenance require stored e(seed)"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but no machine-readable {bf:e(seed)}."
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar for the realized outer fold assignment and Python CLIME CV splitting."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar behind the realized bootstrap path."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_seed_disp' & ///
        !`_cmdline_seed_suppressed_disp' & ///
        `_has_seed_disp' & !missing(`_cmdline_seed_value_disp') & ///
        `_seed_disp' != `_cmdline_seed_value_disp' {
        di as error "{bf:hddid}: current results with stored e(cmdline) seed() provenance require stored e(seed) to match"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but stored {bf:e(seed)} = {bf:`_seed_disp'}."
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar for the realized outer fold assignment and Python CLIME CV splitting."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar behind the realized bootstrap path."
        }
        exit 498
    }
    if `_current_result_surface_disp' & ///
        `_cmdline_has_seed_disp' == 0 & `_has_seed_disp' {
        di as error "{bf:hddid}: current results whose stored e(cmdline) omits seed() require stored e(seed) to be absent"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but stored {bf:e(seed)} = {bf:`_seed_disp'}."
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, omitting {bf:seed()} means the realized outer fold assignment remains deterministic from the data rather than being indexed by one published seed scalar."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: omitting {bf:seed()} means the realized bootstrap path followed the ambient RNG stream rather than a single published seed scalar."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_alpha_disp' & ///
        `_cmdline_dup_alpha_disp' {
        di as error "{bf:hddid}: stored e(cmdline) must encode alpha() provenance at most once"
        di as error "  Replay found duplicated {bf:alpha()} provenance in {bf:e(cmdline)} = {bf:`_cmdline_disp'}"
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on this degenerate zero-SE shortcut, current hddid results still publish one atomic shared {bf:e(alpha)} scalar that calibrates the analytic {bf:e(CIpoint)} pointwise intervals, so replay must fail closed on duplicated singleton alpha metadata."
            di as error "          That shared scalar does not recalibrate the collapsed {bf:e(CIuniform)} object because it already equals {bf:e(gdebias)}."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish one atomic shared significance level behind the realized {bf:e(CIpoint)} object, and the same significance level also calibrates the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object, so replay must fail closed on duplicated singleton alpha metadata."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_alpha_disp' & ///
        `_cmdline_alpha_ok_disp' == 0 {
        di as error "{bf:hddid}: stored e(cmdline) alpha() provenance must be a finite scalar in (0, 1)"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} with malformed explicit {bf:alpha()} provenance: {bf:`_cmdline_alpha_arg_disp'}"
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on this degenerate zero-SE shortcut, current hddid results still require the shared {bf:e(alpha)} scalar that calibrates the analytic {bf:e(CIpoint)} pointwise intervals."
            di as error "          It does not recalibrate the collapsed {bf:e(CIuniform)} object because that published nonparametric interval object already equals {bf:e(gdebias)}."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish the shared significance level through both the successful-call record and the machine-readable {bf:e(alpha)} scalar behind the realized {bf:e(CIpoint)} object, and the same {bf:e(alpha)} scalar also calibrates the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_alpha_disp' & ///
        !missing(`_cmdline_alpha_value_disp') & ///
        abs(`_alpha_disp' - `_cmdline_alpha_value_disp') > 1e-12 {
        di as error "{bf:hddid}: current results with stored e(cmdline) alpha() provenance require stored e(alpha) to match"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but stored {bf:e(alpha)} = {bf:`_alpha_disp'}."
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on this degenerate zero-SE shortcut, current hddid results still reconcile the shared {bf:e(alpha)} scalar that calibrates the analytic {bf:e(CIpoint)} pointwise intervals."
            di as error "          It does not recalibrate the collapsed {bf:e(CIuniform)} object because that published nonparametric interval object already equals {bf:e(gdebias)}."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish the shared significance level through both the successful-call record and the machine-readable {bf:e(alpha)} scalar behind the realized {bf:e(CIpoint)} object, and the same {bf:e(alpha)} scalar also calibrates the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_nboot_disp' & ///
        `_cmdline_dup_nboot_disp' {
        di as error "{bf:hddid}: stored e(cmdline) must encode nboot() provenance at most once"
        di as error "  Replay found duplicated {bf:nboot()} provenance in {bf:e(cmdline)} = {bf:`_cmdline_disp'}"
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still publish one atomic configuration record for this saved-results surface."
            di as error "          one atomic {c -(}bf:nboot(){c )-} configuration record for the current saved-results surface."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish one atomic Gaussian-bootstrap replication count behind {bf:e(tc)} and {bf:e(CIuniform)}, so replay must fail closed on duplicated singleton nboot metadata."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_nboot_disp' & ///
        `_cmdline_nboot_ok_disp' == 0 {
        di as error "{bf:hddid}: stored e(cmdline) nboot() provenance must be an integer >= 2"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} with malformed explicit {bf:nboot()} provenance: {bf:`_cmdline_nboot_arg_disp'}"
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still reconcile {bf:nboot()} across the successful-call record."
            di as error "          machine-readable {c -(}bf:e(nboot){c )-} as configuration metadata."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish bootstrap replication-count provenance through both the successful-call record and the machine-readable {bf:e(nboot)} scalar behind the realized {bf:e(tc)} / {bf:e(CIuniform)} path."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_nboot_disp' & ///
        `_has_nboot_disp' == 0 & !missing(`_cmdline_nboot_value_disp') {
        di as error "{bf:hddid}: current results with stored e(cmdline) nboot() provenance require stored e(nboot)"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but no machine-readable {bf:e(nboot)}."
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still reconcile {bf:nboot()} across the successful-call record."
            di as error "          machine-readable {c -(}bf:e(nboot){c )-} as configuration metadata."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish bootstrap replication-count provenance through both the successful-call record and the machine-readable {bf:e(nboot)} scalar behind the realized {bf:e(tc)} / {bf:e(CIuniform)} path."
        }
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_nboot_disp' & ///
        `_has_nboot_disp' & !missing(`_cmdline_nboot_value_disp') & ///
        `_nboot_disp' != `_cmdline_nboot_value_disp' {
        di as error "{bf:hddid}: current results with stored e(cmdline) nboot() provenance require stored e(nboot) to match"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but stored {bf:e(nboot)} = {bf:`_nboot_disp'}."
        if `_tc_zero_shortcut_seed_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still reconcile {bf:nboot()} across the successful-call record."
            di as error "          machine-readable {c -(}bf:e(nboot){c )-} as configuration metadata."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish bootstrap replication-count provenance through both the successful-call record and the machine-readable {bf:e(nboot)} scalar behind the realized {bf:e(tc)} / {bf:e(CIuniform)} path."
        }
        exit 498
    }
    local _cmdline_has_method_disp = ///
        regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])method[(][ ]*[^)]*[)]")
    local _cmdline_has_q_disp = ///
        regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])q[(][ ]*[^)]*[)]")
    local _cmdline_has_method_assign_disp = ///
        regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])method[ ]*=")
    local _cmdline_has_q_assign_disp = ///
        regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])q[ ]*=")
    local _cmdline_dup_method_disp = 0
    local _cmdline_dup_q_disp = 0
    local _cmdline_method_arg_disp ""
    local _cmdline_method_disp ""
    local _cmdline_method_ok_disp = 0
    local _cmdline_q_arg_disp ""
    local _cmdline_q_value_disp = .
    local _cmdline_q_ok_disp = 0
    if `_current_result_surface_disp' & ///
        (`_cmdline_has_method_assign_disp' | `_cmdline_has_q_assign_disp') {
        local _cmdline_assign_parts_disp ""
        if `_cmdline_has_method_assign_disp' {
            local _cmdline_assign_parts_disp "{bf:method=}"
        }
        if `_cmdline_has_q_assign_disp' {
            if `"`_cmdline_assign_parts_disp'"' != "" {
                local _cmdline_assign_parts_disp ///
                    `"`_cmdline_assign_parts_disp' and {bf:q=}"'
            }
            else {
                local _cmdline_assign_parts_disp "{bf:q=}"
            }
        }
        di as error "{bf:hddid}: stored e(cmdline) must encode method()/q() provenance with option syntax, not assignment syntax"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} with assignment-style `_cmdline_assign_parts_disp' provenance"
        di as error "  Reason: one successful hddid call can publish the realized sieve family/order only through {bf:method()} and {bf:q()}, so assignment-style saved provenance is malformed."
        exit 498
    }
    local _cmdline_method_probe_disp `"`_cmdline_opts_disp'"'
    if regexm(`"`_cmdline_method_probe_disp'"', "(^|[ ,])method[(][^)]*[)]") {
        local _cmdline_method_probe_disp = ///
            regexr(`"`_cmdline_method_probe_disp'"', ///
            "(^|[ ,])method[(][^)]*[)]", " ")
        if regexm(`"`_cmdline_method_probe_disp'"', "(^|[ ,])method[(]") {
            local _cmdline_dup_method_disp = 1
        }
    }
    local _cmdline_q_probe_disp `"`_cmdline_opts_disp'"'
    if regexm(`"`_cmdline_q_probe_disp'"', "(^|[ ,])q[(][^)]*[)]") {
        local _cmdline_q_probe_disp = ///
            regexr(`"`_cmdline_q_probe_disp'"', "(^|[ ,])q[(][^)]*[)]", " ")
        if regexm(`"`_cmdline_q_probe_disp'"', "(^|[ ,])q[(]") {
            local _cmdline_dup_q_disp = 1
        }
    }
    if `_current_result_surface_disp' & `_cmdline_has_method_disp' & ///
        `_cmdline_dup_method_disp' {
        di as error "{bf:hddid}: stored e(cmdline) must encode method() provenance at most once"
        di as error "  Replay found duplicated {bf:method()} provenance in {bf:e(cmdline)} = {bf:`_cmdline_disp'}"
        di as error "  Reason: one realized HDDID surface can only come from one sieve-basis family."
        exit 498
    }
    if `_current_result_surface_disp' & `_cmdline_has_q_disp' & ///
        `_cmdline_dup_q_disp' {
        di as error "{bf:hddid}: stored e(cmdline) must encode q() provenance at most once"
        di as error "  Replay found duplicated {bf:q()} provenance in {bf:e(cmdline)} = {bf:`_cmdline_disp'}"
        di as error "  Reason: one realized HDDID surface can only come from one sieve-order choice."
        exit 498
    }
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])method[(][ ]*([^)]*)[ ]*[)]") {
        local _cmdline_method_arg_disp = strtrim(regexs(2))
        if strlen(`"`_cmdline_method_arg_disp'"') >= 2 {
            local _cmdline_method_first_disp = substr(`"`_cmdline_method_arg_disp'"', 1, 1)
            local _cmdline_method_last_disp = substr(`"`_cmdline_method_arg_disp'"', -1, 1)
            if (`"`_cmdline_method_first_disp'"' == `"""' & `"`_cmdline_method_last_disp'"' == `"""') | ///
                (`"`_cmdline_method_first_disp'"' == "'" & `"`_cmdline_method_last_disp'"' == "'") {
                local _cmdline_method_arg_disp = substr(`"`_cmdline_method_arg_disp'"', 2, ///
                    strlen(`"`_cmdline_method_arg_disp'"') - 2)
            }
        }
        local _cmdline_method_disp = strproper(strtrim(`"`_cmdline_method_arg_disp'"'))
        if inlist(`"`_cmdline_method_disp'"', "Pol", "Tri") {
            local _cmdline_method_ok_disp = 1
        }
    }
    if `_current_result_surface_disp' & `_cmdline_has_method_disp' & ///
        `_cmdline_method_ok_disp' == 0 {
        di as error "{bf:hddid}: stored e(cmdline) method() provenance must be {bf:Pol} or {bf:Tri}"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} with malformed explicit {bf:method()} provenance: {bf:`_cmdline_method_arg_disp'}"
        di as error "  Reason: the successful-call record may publish only the polynomial or trigonometric sieve family used by the realized HDDID surface."
        exit 498
    }
    if regexm(`"`_cmdline_opts_disp'"', "(^|[ ,])q[(][ ]*([^)]*)[ ]*[)]") {
        local _cmdline_q_arg_disp = strtrim(regexs(2))
        if regexm(`"`_cmdline_q_arg_disp'"', "^[+]?[0-9]+$") {
            local _cmdline_q_value_disp = real(`"`_cmdline_q_arg_disp'"')
            if !missing(`_cmdline_q_value_disp') & ///
                `_cmdline_q_value_disp' >= 1 {
                local _cmdline_q_ok_disp = 1
            }
        }
    }
    if `_current_result_surface_disp' & `_cmdline_has_q_disp' & ///
        `_cmdline_q_ok_disp' == 0 {
        di as error "{bf:hddid}: stored e(cmdline) q() provenance must be an integer >= 1"
        di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} with malformed explicit {bf:q()} provenance: {bf:`_cmdline_q_arg_disp'}"
        di as error "  Reason: the successful-call record may publish only a valid positive sieve-order choice for the realized HDDID surface."
        exit 498
    }
    local _stored_method_cmdline_disp = strproper(strlower(strtrim(`"`e(method)'"')))
    local _stored_method_ok_disp = ///
        inlist(`"`_stored_method_cmdline_disp'"', "Pol", "Tri")
    if `_stored_method_ok_disp' == 0 & `"`_method_disp'"' != "" {
        local _stored_method_cmdline_disp `"`_method_disp'"'
        local _stored_method_ok_disp = ///
            inlist(`"`_stored_method_cmdline_disp'"', "Pol", "Tri")
    }
    local _stored_q_ok_disp = 0
    local _stored_q_cmdline_disp = .
    if !missing(`_q_disp') & `_q_disp' >= 1 & `_q_disp' == floor(`_q_disp') {
        local _stored_q_cmdline_disp = `_q_disp'
        local _stored_q_ok_disp = 1
    }
    if `_current_result_surface_disp' & ///
        (`_cmdline_has_method_disp' | `_cmdline_has_q_disp') & ///
        `_stored_method_ok_disp' & `_stored_q_ok_disp' {
        local _cmdline_method_mismatch_disp = 0
        local _cmdline_q_mismatch_disp = 0
        if `_cmdline_has_method_disp' & `_cmdline_method_ok_disp' & ///
            `"`_cmdline_method_disp'"' != `"`_stored_method_cmdline_disp'"' {
            local _cmdline_method_mismatch_disp = 1
        }
        if `_cmdline_has_q_disp' & `_cmdline_q_ok_disp' & ///
            `_cmdline_q_value_disp' != `_stored_q_cmdline_disp' {
            local _cmdline_q_mismatch_disp = 1
        }
        if `_cmdline_method_mismatch_disp' | `_cmdline_q_mismatch_disp' {
            di as error "{bf:hddid}: current results with stored e(cmdline) method()/q() provenance require stored e(method) and e(q) to match"
            di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but stored {bf:e(method)} = {bf:`_stored_method_cmdline_disp'} and {bf:e(q)} = {bf:`_stored_q_cmdline_disp'}."
            di as error "  Reason: current hddid results publish sieve-basis provenance through both the successful-call record and the machine-readable {bf:e(method)} / {bf:e(q)} metadata behind the realized beta and omitted-intercept z-varying surface."
            exit 498
        }
    }
    // Replay must also honor official defaults when the current successful
    // call record omits method()/q(). The earlier pre-parse summary block
    // cannot enforce these omission defaults because cmdline method/q locals
    // are not populated until this replay-side parser runs.
    if `_current_result_surface_disp' & strtrim(`"`_cmdline_disp'"') != "" & ///
        `"`_cmdline_depvar_disp'"' != "" & `_cmd_has_roles_disp' {
        if `_cmdline_has_method_disp' == 0 & ///
            `"`_stored_method_cmdline_disp'"' != "Pol" {
            di as error "{bf:hddid}: current results whose stored e(cmdline) omits method() require stored e(method) = {bf:Pol}"
            di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but stored {bf:e(method)} = {bf:`_stored_method_cmdline_disp'}."
            di as error "  Reason: the successful-call record still identifies the official default sieve basis, and {bf:hddid} syntax defaults to {bf:method(Pol)}."
            exit 498
        }
        if `_cmdline_has_q_disp' == 0 & `_stored_q_cmdline_disp' != 8 {
            di as error "{bf:hddid}: current results whose stored e(cmdline) omits q() require stored e(q) = 8"
            di as error "  Replay found {bf:e(cmdline)} = {bf:`_cmdline_disp'} but stored {bf:e(q)} = {bf:`_stored_q_cmdline_disp'}."
            di as error "  Reason: the successful-call record still identifies the official default sieve order, and {bf:hddid} syntax defaults to {bf:q(8)}."
            exit 498
        }
    }
    if `"`_firststage_mode_probe'"' != "" {
        local _firststage_mode_disp `"`_firststage_mode_probe'"'
        if !inlist(`"`_firststage_mode_disp'"', "internal", "nofirst") {
            di as error "{bf:hddid}: stored e(firststage_mode) must be {bf:internal} or {bf:nofirst}"
            di as error "  Replay found an unknown published first-stage mode: {bf:`_firststage_mode_disp'}"
            exit 498
        }
        if `"`_cmdline_probe'"' != "" {
            // When cmdline is present, validate that its nuisance-path and role
            // provenance agree with the machine-readable replay metadata.
            if `_cmdline_dup_role_opts' {
                di as error "{bf:hddid}: stored e(cmdline) must encode each treat()/x()/z() role option at most once"
                di as error "  Replay found duplicated role provenance in e(cmdline) = {bf:`_cmdline_disp'}"
                exit 498
            }
            if `"`_cmdline_depvar_disp'"' == "" | `_cmd_has_roles_disp' == 0 {
                local _stored_role_bundle_ok_disp = ///
                    (`"`_depvar_role_disp'"' != "" & ///
                    `"`_treat_disp'"' != "" & ///
                    `"`xvars'"' != "" & ///
                    `"`_zvar_disp'"' != "")
                if `_stored_role_bundle_ok_disp' == 0 {
                    di as error "{bf:hddid}: stored e(cmdline) must include depvar plus treat()/x()/z() role provenance"
                    di as error "  Replay found e(cmdline) = {bf:`_cmdline_disp'}"
                    di as error "  Reason: replay can lose redundant role text only when the published machine-readable role metadata already remain complete in {bf:e(depvar_role)}, {bf:e(treat)}, {bf:e(xvars)}, and {bf:e(zvar)}."
                    exit 498
                }
            }
            local _mode_says_nofirst = (`"`_firststage_mode_disp'"' == "nofirst")
            if `_cmdline_has_nofirst_disp' != `_mode_says_nofirst' {
                di as error "{bf:hddid}: stored e(firststage_mode) must agree with whether e(cmdline) uses nofirst"
                di as error "  Replay found e(firststage_mode) = {bf:`_firststage_mode_disp'} but e(cmdline) = {bf:`_cmdline_disp'}"
                exit 498
            }
        }
    }
    else {
        if `_cmdline_dup_role_opts' {
            di as error "{bf:hddid}: stored e(cmdline) must encode each treat()/x()/z() role option at most once"
            di as error "  Replay found duplicated role provenance in e(cmdline) = {bf:`_cmdline_disp'}"
            exit 498
        }
        if `_cmdline_has_nofirst_disp' {
            local _firststage_mode_disp "nofirst"
        }
        else if `_cmd_has_roles_disp' {
            local _firststage_mode_disp "internal"
        }
        else {
            di as error "{bf:hddid}: stored e(cmdline) must identify whether first stage was internal or nofirst"
            di as error "  Replay found an unclassifiable legacy cmdline: {bf:`_cmdline_disp'}"
            exit 498
        }
    }
    if `_has_N_outer_split_disp' {
        if `"`_depvar_role_disp'"' != "" & `"`_firststage_mode_disp'"' == "internal" & ///
            `_has_N_pretrim_disp' {
            local _N_outer_split_floor_disp = `_N_pretrim_disp'
            local _N_outer_split_floor_label "e(N_pretrim)"
            if missing(`_N_outer_split_disp') | ///
                `_N_outer_split_disp' != `_N_pretrim_disp' | ///
                `_N_outer_split_disp' != floor(`_N_outer_split_disp') {
                di as error "{bf:hddid}: stored e(N_outer_split) must equal stored e(N_pretrim) for current internal results"
                di as error "  Replay found e(N_outer_split) = " %9.0f `_N_outer_split_disp' ///
                    ", stored e(N_pretrim) = " %9.0f `_N_pretrim_disp'
                di as error "  Reason: current internal results publish fold-pinning split metadata before ancillary seed()/alpha()/nboot() provenance, so replay fails on malformed outer-split counts first."
                exit 498
            }
        }
        else {
            local _N_outer_split_floor_disp = `_N_disp'
            local _N_outer_split_floor_label "e(N)"
            if missing(`_N_outer_split_disp') | ///
                `_N_outer_split_disp' < `_N_outer_split_floor_disp' | ///
                `_N_outer_split_disp' != floor(`_N_outer_split_disp') {
                if `_current_result_surface_disp' & ///
                    `"`_firststage_mode_disp'"' == "nofirst" {
                    di as error "{bf:hddid}: stored e(N_outer_split) must be a finite integer >= stored e(N) for current nofirst results"
                    di as error "  Replay found e(N_outer_split) = " %9.0f `_N_outer_split_disp' ///
                        ", stored e(N) = " %9.0f `_N_outer_split_floor_disp'
                    di as error "  Reason: current nofirst results publish fold-pinning split metadata before ancillary seed()/alpha()/nboot() provenance, so replay fails on malformed outer-split counts first."
                }
                else {
                    di as error "{bf:hddid}: stored e(N_outer_split) must be a finite integer >= stored `_N_outer_split_floor_label'"
                    di as error "  Replay found e(N_outer_split) = " %9.0f `_N_outer_split_disp' ///
                        ", stored `_N_outer_split_floor_label' = " %9.0f `_N_outer_split_floor_disp'
                }
                exit 498
            }
        }
    }
    if `_current_result_surface_disp' & `"`_cmdline_probe'"' != "" & ///
        `_cmdline_has_seed_disp' & !`_cmdline_seed_suppressed_disp' & ///
        `_has_seed_disp' == 0 {
        di as error "{bf:hddid}: current results with stored e(cmdline) seed() provenance require stored e(seed)"
        if `_tc_zero_shortcut_disp' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid replay treats an explicit seed() as part of the machine-readable provenance for the realized outer fold assignment and Python CLIME CV splitting."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid replay treats an explicit seed() as part of the machine-readable bootstrap/RNG provenance behind the posted e(tc) and e(CIuniform) objects."
        }
        exit 498
    }
    if `_cmd_has_roles_disp' {
        local _cmdline_role_mismatch = 0
        local _cmdline_xvars_mismatch = 0
        local _depvar_cmd_expected = lower(strtrim(`"`_depvar_disp'"'))
        local _treat_cmd_expected = lower(strtrim(`"`_treat_disp'"'))
        local _xvars_cmd_expected = lower(strtrim(`"`xvars'"'))
        local _xvars_cmd_expected : list retokenize _xvars_cmd_expected
        local _xvars_cmd_expected_sorted_pre : list sort _xvars_cmd_expected
        local _zvar_cmd_expected = lower(strtrim(`"`_zvar_disp'"'))
        local _published_vars_cmd_expected ///
            `"`_depvar_cmd_expected' `_treat_cmd_expected' `_xvars_cmd_expected' `_zvar_cmd_expected'"'
        local _published_vars_cmd_expected : list retokenize _published_vars_cmd_expected
        local _cmdline_depvar_cmp_disp = lower(strtrim(`"`_cmdline_depvar_disp'"'))
        local _cmdline_treat_cmp_disp = lower(strtrim(`"`_cmdline_treat_disp'"'))
        local _cmdline_xvars_cmp_disp = lower(strtrim(`"`_cmdline_xvars_disp'"'))
        local _cmdline_xvars_cmp_disp : list retokenize _cmdline_xvars_cmp_disp
        local _cmdline_xvars_raw_lc `"`_cmdline_xvars_cmp_disp'"'
        local _cmdline_zvar_cmp_disp = lower(strtrim(`"`_cmdline_zvar_disp'"'))
        // When the current data still contain the referenced variables,
        // resolve legal Stata abbreviations before comparing provenance names
        // with the published role metadata; preserve x() order as typed.
        // If those variables are no longer in memory (for example after
        // estimates use), fall back to the published full role metadata and
        // accept legal prefix abbreviations as pure cmdline spelling choices.
        if `_replay_role_data_present' & `"`_cmdline_depvar_disp'"' != "" {
            capture unab _cmdline_depvar_canon_disp : `_cmdline_depvar_disp'
            if _rc == 0 {
                local _cmdline_depvar_cmp_disp = ///
                    lower(strtrim(`"`_cmdline_depvar_canon_disp'"'))
            }
        }
        if `"`_cmdline_depvar_cmp_disp'"' != "" & ///
            `"`_cmdline_depvar_cmp_disp'"' != `"`_depvar_cmd_expected'"' & ///
            strpos(`"`_depvar_cmd_expected'"', `"`_cmdline_depvar_cmp_disp'"') == 1 {
            local _cmdline_depvar_match_count 0
            foreach _published_var of local _published_vars_cmd_expected {
                if strpos(`"`_published_var'"', `"`_cmdline_depvar_cmp_disp'"') == 1 {
                    local _cmdline_depvar_match_count = ///
                        `_cmdline_depvar_match_count' + 1
                }
            }
            if `_cmdline_depvar_match_count' == 1 {
                local _cmdline_depvar_cmp_disp `"`_depvar_cmd_expected'"'
            }
        }
        if `_replay_role_data_present' & `"`_cmdline_treat_disp'"' != "" {
            capture unab _cmdline_treat_canon_disp : `_cmdline_treat_disp'
            if _rc == 0 {
                local _cmdline_treat_cmp_disp = ///
                    lower(strtrim(`"`_cmdline_treat_canon_disp'"'))
            }
        }
        if `"`_cmdline_treat_cmp_disp'"' != "" & ///
            `"`_cmdline_treat_cmp_disp'"' != `"`_treat_cmd_expected'"' & ///
            strpos(`"`_treat_cmd_expected'"', `"`_cmdline_treat_cmp_disp'"') == 1 {
            local _cmdline_treat_match_count 0
            foreach _published_var of local _published_vars_cmd_expected {
                if strpos(`"`_published_var'"', `"`_cmdline_treat_cmp_disp'"') == 1 {
                    local _cmdline_treat_match_count = ///
                        `_cmdline_treat_match_count' + 1
                }
            }
            if `_cmdline_treat_match_count' == 1 {
                local _cmdline_treat_cmp_disp `"`_treat_cmd_expected'"'
            }
        }
        local _cmdline_xvars_has_wild_disp = ///
            (strpos(`"`_cmdline_xvars_disp'"', "*") > 0 | ///
             strpos(`"`_cmdline_xvars_disp'"', "?") > 0)
        if `_replay_role_data_present' & `"`_cmdline_xvars_disp'"' != "" & ///
            `_cmdline_xvars_has_wild_disp' == 0 {
            capture unab _cmdline_xvars_canon_disp : `_cmdline_xvars_disp'
            if _rc == 0 {
                local _cmdline_xvars_try = ///
                    lower(strtrim(`"`_cmdline_xvars_canon_disp'"'))
                local _cmdline_xvars_try : list retokenize _cmdline_xvars_try
                local _cmdline_xvars_try_sorted : list sort _cmdline_xvars_try
                if `"`_cmdline_xvars_try_sorted'"' == `"`_xvars_cmd_expected_sorted_pre'"' {
                    local _cmdline_xvars_cmp_disp `"`_cmdline_xvars_try'"'
                }
            }
            if `"`_cmdline_xvars_cmp_disp'"' == `"`_cmdline_xvars_raw_lc'"' {
                capture tsunab _cmdline_xvars_canon_disp : `_cmdline_xvars_disp'
                if _rc == 0 {
                    local _cmdline_xvars_try = ///
                        lower(strtrim(`"`_cmdline_xvars_canon_disp'"'))
                    local _cmdline_xvars_try : list retokenize _cmdline_xvars_try
                    local _cmdline_xvars_try_sorted : list sort _cmdline_xvars_try
                    if `"`_cmdline_xvars_try_sorted'"' == `"`_xvars_cmd_expected_sorted_pre'"' {
                        local _cmdline_xvars_cmp_disp `"`_cmdline_xvars_try'"'
                    }
                }
            }
        }
        if `"`_cmdline_xvars_disp'"' != "" & ///
            (`"`_cmdline_xvars_cmp_disp'"' == "" | ///
             strpos(`"`_cmdline_xvars_cmp_disp'"', "-") > 0 | ///
             `_cmdline_xvars_has_wild_disp') {
            local _xrange_exp ""
            local _xrange_fail 0
            local _xrange_needs_data_order_disp 0
            local _xraw = lower(strtrim(`"`_cmdline_xvars_disp'"'))
            local _xraw : list retokenize _xraw
            // estimates use can replay posted results without the original
            // data in memory, so recreate legal x() wildcard syntax from the
            // published xvars metadata when unab cannot expand cmdline
            // provenance such as x(rep*). Stata varlist ranges instead depend
            // on the original dataset order. Without the live dataset, replay
            // cannot prove that a range token still denotes exactly the
            // published x() block, so current results fail closed on that
            // ambiguous provenance instead of widening the saved-results
            // identity from the posted e(xvars) coordinates. Even when live
            // data are present, wildcard tokens remain provenance-only: a
            // wider current varlist (for example adding rep3 after estimation)
            // must not widen or invalidate the stored beta-coordinate surface
            // already pinned by e(xvars).
            foreach _xraw_tok of local _xraw {
                if strpos(`"`_xraw_tok'"', "-") > 0 & ///
                    regexm(`"`_xraw_tok'"', "^([^ -]+)-([^ -]+)$") {
                    local _xlo = regexs(1)
                    local _xhi = regexs(2)
                    local _xlo_n 0
                    local _xhi_n 0
                    local _xlo_hit ""
                    local _xhi_hit ""
                    foreach _expected_xvar of local _xvars_cmd_expected {
                        if strpos(`"`_expected_xvar'"', `"`_xlo'"') == 1 {
                            local _xlo_n = `_xlo_n' + 1
                            local _xlo_hit `"`_expected_xvar'"'
                        }
                        if strpos(`"`_expected_xvar'"', `"`_xhi'"') == 1 {
                            local _xhi_n = `_xhi_n' + 1
                            local _xhi_hit `"`_expected_xvar'"'
                        }
                    }
                    if `_xlo_n' != 1 | `_xhi_n' != 1 {
                        local _xrange_fail 1
                    }
                    else if `_replay_role_data_present' {
                        local _xlo_pos : list posof `"`_xlo_hit'"' in _xvars_cmd_expected
                        local _xhi_pos : list posof `"`_xhi_hit'"' in _xvars_cmd_expected
                        if `_xlo_pos' == 0 | `_xhi_pos' == 0 | ///
                            `_xlo_pos' > `_xhi_pos' {
                            local _xrange_fail 1
                        }
                        else {
                            forvalues _xj = `_xlo_pos'/`_xhi_pos' {
                                local _xpiece : word `_xj' of `_xvars_cmd_expected'
                                local _xrange_exp `"`_xrange_exp' `_xpiece'"'
                            }
                        }
                    }
                    else {
                        // After estimates use drops the live dataset, keep a
                        // historical range only when the published xvars block
                        // still proves the full numeric sequence implied by
                        // the endpoints (for example x1-x3 -> x1 x2 x3).
                        // Bare nonnumeric ranges remain ambiguous about the
                        // original dataset order once the data are gone, so
                        // replay must still fail closed on those cases.
                        local _xrange_sequence_checked 0
                        local _xrange_sequence_fail 0
                        if regexm(`"`_xlo_hit'"', "^(.*[^0-9]|)([0-9]+)([^0-9]*)$") {
                            local _xlo_prefix = regexs(1)
                            local _xlo_numstr = regexs(2)
                            local _xlo_suffix = regexs(3)
                            local _xlo_num = real(`"`_xlo_numstr'"')
                            local _xlo_width = length(`"`_xlo_numstr'"')
                            if regexm(`"`_xhi_hit'"', "^(.*[^0-9]|)([0-9]+)([^0-9]*)$") {
                                local _xhi_prefix = regexs(1)
                                local _xhi_numstr = regexs(2)
                                local _xhi_suffix = regexs(3)
                                local _xhi_num = real(`"`_xhi_numstr'"')
                                local _xhi_width = length(`"`_xhi_numstr'"')
                                if !missing(`_xlo_num') & !missing(`_xhi_num') & ///
                                    `"`_xlo_prefix'"' == `"`_xhi_prefix'"' & ///
                                    `"`_xlo_suffix'"' == `"`_xhi_suffix'"' & ///
                                    `_xlo_width' == `_xhi_width' {
                                    local _xrange_sequence_checked 1
                                    local _xseq_from = min(`_xlo_num', `_xhi_num')
                                    local _xseq_to = max(`_xlo_num', `_xhi_num')
                                    forvalues _xseq = `_xseq_from'/`_xseq_to' {
                                        local _xseq_expected : display %0`_xlo_width'.0f `_xseq'
                                        local _xseq_name `"`_xlo_prefix'`_xseq_expected'`_xlo_suffix'"'
                                        local _xseq_pos : list posof `"`_xseq_name'"' in _xvars_cmd_expected
                                        if `_xseq_pos' == 0 {
                                            local _xrange_sequence_fail 1
                                        }
                                    }
                                }
                            }
                        }
                        if `_xrange_sequence_checked' == 0 {
                            local _xrange_fail 1
                        }
                        else if `_xrange_sequence_fail' {
                            local _xrange_fail 1
                        }
                        else {
                            local _xlo_pos : list posof `"`_xlo_hit'"' in _xvars_cmd_expected
                            local _xhi_pos : list posof `"`_xhi_hit'"' in _xvars_cmd_expected
                            if `_xlo_pos' == 0 | `_xhi_pos' == 0 | ///
                                `_xlo_pos' > `_xhi_pos' {
                                local _xrange_fail 1
                            }
                            else {
                                forvalues _xj = `_xlo_pos'/`_xhi_pos' {
                                    local _xpiece : word `_xj' of `_xvars_cmd_expected'
                                    local _xrange_exp `"`_xrange_exp' `_xpiece'"'
                                }
                            }
                        }
                    }
                }
                else if strpos(`"`_xraw_tok'"', "*") > 0 | ///
                    strpos(`"`_xraw_tok'"', "?") > 0 {
                    local _xwild_hits ""
                    foreach _expected_xvar of local _xvars_cmd_expected {
                        if strmatch(`"`_expected_xvar'"', `"`_xraw_tok'"') {
                            local _xwild_hits `"`_xwild_hits' `_expected_xvar'"'
                        }
                    }
                    local _xwild_hits : list retokenize _xwild_hits
                    if `"`_xwild_hits'"' == "" {
                        local _xrange_fail 1
                    }
                    else {
                        local _xrange_exp `"`_xrange_exp' `_xwild_hits'"'
                    }
                }
                else {
                    local _xrange_exp `"`_xrange_exp' `_xraw_tok'"'
                }
            }
            if `_xrange_fail' == 0 & `_xrange_needs_data_order_disp' == 0 & ///
                `"`_xrange_exp'"' != "" {
                local _cmdline_xvars_cmp_disp = ///
                    lower(strtrim(`"`_xrange_exp'"'))
                local _cmdline_xvars_cmp_disp : list retokenize _cmdline_xvars_cmp_disp
            }
            if `_xrange_fail' == 0 & `_xrange_needs_data_order_disp' {
                local _xsubset_fail 0
                local _xsubset_matched ""
                local _xsubset_tokens `"`_xrange_exp'"'
                local _xsubset_tokens : list retokenize _xsubset_tokens
                foreach _cmdline_xvar of local _xsubset_tokens {
                    local _cmdline_xvar_match_count 0
                    local _cmdline_xvar_match ""
                    foreach _published_var of local _published_vars_cmd_expected {
                        if strpos(`"`_published_var'"', `"`_cmdline_xvar'"') == 1 {
                            local _cmdline_xvar_match_count = ///
                                `_cmdline_xvar_match_count' + 1
                            local _cmdline_xvar_match `"`_published_var'"'
                        }
                    }
                    local _cmdline_xvar_expected_pos : list posof ///
                        `"`_cmdline_xvar_match'"' in _xvars_cmd_expected
                    if `_cmdline_xvar_match_count' != 1 | ///
                        `_cmdline_xvar_expected_pos' == 0 {
                        local _xsubset_fail 1
                    }
                    else {
                        local _cmdline_xvar_match_pos : list posof ///
                            `"`_cmdline_xvar_match'"' in _xsubset_matched
                        if `_cmdline_xvar_match_pos' > 0 {
                            local _xsubset_fail 1
                        }
                        else {
                            local _xsubset_matched ///
                                `"`_xsubset_matched' `_cmdline_xvar_match'"'
                        }
                    }
                }
                if `_xsubset_fail' == 0 {
                    local _cmdline_xvars_cmp_disp `"`_xvars_cmd_expected'"'
                }
            }
        }
        if `"`_cmdline_xvars_cmp_disp'"' != "" & ///
            `"`_cmdline_xvars_cmp_disp'"' != `"`_xvars_cmd_expected'"' {
            local _cmdline_xvars_count_disp : word count `_cmdline_xvars_cmp_disp'
            local _xvars_expected_count_disp : word count `_xvars_cmd_expected'
            if `_cmdline_xvars_count_disp' == `_xvars_expected_count_disp' {
                // x() order is canonicalized before posting e(xvars), so replay
                // should match cmdline tokens to the published xvars by unique
                // prefix membership rather than by their original typing order.
                local _cmdline_xvars_match_fail 0
                local _cmdline_xvars_matched ""
                foreach _cmdline_xvar of local _cmdline_xvars_cmp_disp {
                    local _cmdline_xvar_match_count 0
                    local _cmdline_xvar_match ""
                    foreach _published_var of local _published_vars_cmd_expected {
                        if strpos(`"`_published_var'"', `"`_cmdline_xvar'"') == 1 {
                            local _cmdline_xvar_match_count = ///
                                `_cmdline_xvar_match_count' + 1
                            local _cmdline_xvar_match `"`_published_var'"'
                        }
                    }
                    local _cmdline_xvar_expected_pos : list posof ///
                        `"`_cmdline_xvar_match'"' in _xvars_cmd_expected
                    if `_cmdline_xvar_match_count' != 1 | ///
                        `_cmdline_xvar_expected_pos' == 0 {
                        local _cmdline_xvars_match_fail 1
                    }
                    else {
                        local _cmdline_xvar_match_pos : list posof ///
                            `"`_cmdline_xvar_match'"' in _cmdline_xvars_matched
                        if `_cmdline_xvar_match_pos' > 0 {
                            local _cmdline_xvars_match_fail 1
                        }
                        else {
                            local _cmdline_xvars_matched ///
                                `"`_cmdline_xvars_matched' `_cmdline_xvar_match'"'
                        }
                    }
                }
                if `_cmdline_xvars_match_fail' == 0 {
                    // Replay should normalize pure cmdline x() spelling changes
                    // back onto the published beta-coordinate order in e(xvars),
                    // not onto lexical varname order.
                    local _cmdline_xvars_cmp_disp `"`_xvars_cmd_expected'"'
                }
            }
        }
        if `_replay_role_data_present' & `"`_cmdline_zvar_disp'"' != "" {
            capture unab _cmdline_zvar_canon_disp : `_cmdline_zvar_disp'
            if _rc == 0 {
                local _cmdline_zvar_cmp_disp = ///
                    lower(strtrim(`"`_cmdline_zvar_canon_disp'"'))
            }
        }
        if `"`_cmdline_zvar_cmp_disp'"' != "" & ///
            `"`_cmdline_zvar_cmp_disp'"' != `"`_zvar_cmd_expected'"' & ///
            strpos(`"`_zvar_cmd_expected'"', `"`_cmdline_zvar_cmp_disp'"') == 1 {
            local _cmdline_zvar_match_count 0
            foreach _published_var of local _published_vars_cmd_expected {
                if strpos(`"`_published_var'"', `"`_cmdline_zvar_cmp_disp'"') == 1 {
                    local _cmdline_zvar_match_count = ///
                        `_cmdline_zvar_match_count' + 1
                }
            }
            if `_cmdline_zvar_match_count' == 1 {
                local _cmdline_zvar_cmp_disp `"`_zvar_cmd_expected'"'
            }
        }
        if `"`_cmdline_depvar_cmp_disp'"' != "" & ///
            `"`_cmdline_depvar_cmp_disp'"' != `"`_depvar_cmd_expected'"' {
            local _cmdline_role_mismatch = 1
        }
        if `"`_cmdline_treat_cmp_disp'"' != "" & ///
            `"`_cmdline_treat_cmp_disp'"' != `"`_treat_cmd_expected'"' {
            local _cmdline_role_mismatch = 1
        }
        // When unab/tsunab cannot expand a cmdline range token (e.g. x1-x10
        // after lasso2 reorders dataset variables), _cmdline_xvars_cmp_disp
        // remains the raw range string. Skip the mismatch check in that case
        // since the earlier range-expansion block already tried all resolution
        // paths. A raw range that survived all expansion attempts is not a
        // contradictory role mapping—it is an unresolvable display-time token.
        if `"`_cmdline_xvars_cmp_disp'"' != "" & ///
            strpos(`"`_cmdline_xvars_cmp_disp'"', "-") == 0 & ///
            !`_cmdline_xvars_has_wild_disp' {
            local _cmdline_xvars_sorted_disp : list sort _cmdline_xvars_cmp_disp
            local _xvars_cmd_expected_sorted : list sort _xvars_cmd_expected
            if `"`_cmdline_xvars_sorted_disp'"' != `"`_xvars_cmd_expected_sorted'"' {
                local _cmdline_xvars_mismatch = 1
                local _cmdline_role_mismatch = 1
            }
        }
        if `"`_cmdline_zvar_cmp_disp'"' != "" & ///
            `"`_cmdline_zvar_cmp_disp'"' != `"`_zvar_cmd_expected'"' {
            local _cmdline_role_mismatch = 1
        }
        if `_cmdline_role_mismatch' {
            if `_cmdline_xvars_mismatch' {
                di as error "{bf:hddid}: stored e(cmdline) x() mapping must agree with the published e(xvars) metadata"
                di as error "  Replay found e(cmdline) = {bf:`_cmdline_disp'}"
                di as error "  Replay found published e(xvars) = {bf:`xvars'}"
                exit 498
            }
            di as error "{bf:hddid}: stored e(cmdline) role mapping must agree with the published depvar/treat/z metadata"
            di as error "  Replay found e(cmdline) = {bf:`_cmdline_disp'}"
            di as error "  Replay found published roles depvar={bf:`_depvar_disp'}, treat={bf:`_treat_disp'}, x={bf:`xvars'}, z={bf:`_zvar_disp'}"
            exit 498
        }
    }

    capture confirm scalar e(propensity_nfolds)
    local _has_propensity_nfolds_disp = (_rc == 0)
    capture confirm scalar e(outcome_nfolds)
    local _has_outcome_nfolds_disp = (_rc == 0)
    if `"`_firststage_mode_disp'"' == "internal" {
        if `_has_propensity_nfolds_disp' == 0 | ///
            `_has_outcome_nfolds_disp' == 0 {
            if `_replay_linesize' < 200 {
                quietly set linesize 200
            }
            di as error "{bf:hddid}: replay requires stored e(propensity_nfolds) and e(outcome_nfolds) when first stage was estimated internally"
            di as error "  Reason: replay must disclose the published inner-CV design for the estimated propensity and outcome nuisance stages"
            if c(linesize) != `_replay_linesize' {
                quietly set linesize `_replay_linesize'
            }
            exit 498
        }
    }
    else if `"`_firststage_mode_disp'"' == "nofirst" {
        if `_has_propensity_nfolds_disp' | `_has_outcome_nfolds_disp' {
            if `_replay_linesize' < 200 {
                quietly set linesize 200
            }
            di as error "{bf:hddid}: stored e(propensity_nfolds) and e(outcome_nfolds) must be omitted when nofirst was used"
            di as error "  Reason: replay must not report estimated first-stage folds for user-supplied nuisance inputs"
            if c(linesize) != `_replay_linesize' {
                quietly set linesize `_replay_linesize'
            }
            exit 498
        }
    }
    if `_has_propensity_nfolds_disp' {
        local _propensity_nfolds_disp = e(propensity_nfolds)
        if missing(`_propensity_nfolds_disp') | ///
            `_propensity_nfolds_disp' < 2 | ///
            `_propensity_nfolds_disp' != floor(`_propensity_nfolds_disp') {
            di as error "{bf:hddid}: stored e(propensity_nfolds) must be an integer >= 2"
            di as error "  Replay cannot report propensity-stage inner CV metadata with an invalid fold count"
            exit 498
        }
    }
    if `_has_outcome_nfolds_disp' {
        local _outcome_nfolds_disp = e(outcome_nfolds)
        if missing(`_outcome_nfolds_disp') | ///
            `_outcome_nfolds_disp' < 2 | ///
            `_outcome_nfolds_disp' != floor(`_outcome_nfolds_disp') {
            di as error "{bf:hddid}: stored e(outcome_nfolds) must be an integer >= 2"
            di as error "  Replay cannot report outcome-stage inner CV metadata with an invalid fold count"
            exit 498
        }
    }
    capture confirm scalar e(secondstage_nfolds)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(secondstage_nfolds)"
        di as error "  Reason: second-stage lasso tuning is part of the published estimator-path metadata for the posted beta and omitted-intercept z-varying objects"
        exit 498
    }
    local _secondstage_nfolds_disp = e(secondstage_nfolds)
    if missing(`_secondstage_nfolds_disp') | ///
        `_secondstage_nfolds_disp' < 2 | ///
        `_secondstage_nfolds_disp' != floor(`_secondstage_nfolds_disp') {
        di as error "{bf:hddid}: stored e(secondstage_nfolds) must be an integer >= 2"
        di as error "  Replay cannot report second-stage inner CV metadata with an invalid fold count"
        exit 498
    }
    capture confirm scalar e(mmatrix_nfolds)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(mmatrix_nfolds)"
        di as error "  Reason: M-matrix tuning is part of the published debiasing-path metadata for the posted beta and omitted-intercept z-varying objects"
        exit 498
    }
    local _mmatrix_nfolds_disp = e(mmatrix_nfolds)
    if missing(`_mmatrix_nfolds_disp') | ///
        `_mmatrix_nfolds_disp' < 2 | ///
        `_mmatrix_nfolds_disp' != floor(`_mmatrix_nfolds_disp') {
        di as error "{bf:hddid}: stored e(mmatrix_nfolds) must be an integer >= 2"
        di as error "  Replay cannot report M-matrix inner CV metadata with an invalid fold count"
        exit 498
    }
    local _clime_nfolds_cv_max_disp = .
    capture confirm scalar e(clime_nfolds_cv_max)
    local _has_clime_req_disp = (_rc == 0)
    if `_has_clime_req_disp' {
        local _clime_nfolds_cv_max_disp = e(clime_nfolds_cv_max)
        if missing(`_clime_nfolds_cv_max_disp') | ///
            `_clime_nfolds_cv_max_disp' < 2 | ///
            `_clime_nfolds_cv_max_disp' != floor(`_clime_nfolds_cv_max_disp') {
            di as error "{bf:hddid}: stored e(clime_nfolds_cv_max) must be an integer >= 2"
            di as error "  Replay cannot report CLIME requested-fold metadata with an invalid fold cap"
            exit 498
        }
    }
    capture confirm scalar e(clime_nfolds_cv_effective_min)
    local _has_clime_eff_min_disp = (_rc == 0)
    if `_has_clime_eff_min_disp' {
        local _clime_eff_min_disp = e(clime_nfolds_cv_effective_min)
        if missing(`_clime_eff_min_disp') | ///
            `_clime_eff_min_disp' != floor(`_clime_eff_min_disp') | ///
            (`_clime_eff_min_disp' != 0 & `_clime_eff_min_disp' < 2) {
            di as error "{bf:hddid}: stored realized CLIME CV fold counts must be 0 or integers >= 2"
            di as error "  Replay found e(clime_nfolds_cv_effective_min) = " ///
                %9.0f `_clime_eff_min_disp'
            exit 498
        }
    }
    capture confirm scalar e(clime_nfolds_cv_effective_max)
    local _has_clime_eff_max_disp = (_rc == 0)
    capture confirm matrix e(clime_nfolds_cv_per_fold)
    local _has_clime_pf_disp = (_rc == 0)
    // Current multi-x postings publish the requested/realized CLIME
    // metadata block as part of the precision-step provenance. Under p=1 the
    // scalar precision step uses the analytic inverse, so replay may suppress
    // the CLIME summary entirely when that optional block is absent.
    local _current_clime_block_disp = (`_current_result_surface_disp' & `p' > 1)
    local _clime_block_parts_disp = ///
        `_has_clime_req_disp' + `_has_clime_eff_min_disp' + ///
        `_has_clime_eff_max_disp' + `_has_clime_pf_disp'
    if `_current_clime_block_disp' & ///
        `_clime_block_parts_disp' != 4 {
        di as error "{bf:hddid}: replay requires the stored CLIME metadata block for current results"
        di as error "  Reason: current hddid posting always publishes the requested and realized CLIME fold metadata as part of the posted precision-step provenance, even when p=1 uses the analytic scalar shortcut and records zeros"
        exit 498
    }
    if `_has_clime_eff_max_disp' {
        local _clime_eff_max_disp = e(clime_nfolds_cv_effective_max)
        if missing(`_clime_eff_max_disp') | ///
            `_clime_eff_max_disp' != floor(`_clime_eff_max_disp') | ///
            (`_clime_eff_max_disp' != 0 & `_clime_eff_max_disp' < 2) {
            di as error "{bf:hddid}: stored realized CLIME CV fold counts must be 0 or integers >= 2"
            di as error "  Replay found e(clime_nfolds_cv_effective_max) = " ///
                %9.0f `_clime_eff_max_disp'
            exit 498
        }
    }
    if `_has_clime_eff_min_disp' & `_has_clime_eff_max_disp' {
        if `e(clime_nfolds_cv_effective_min)' > `e(clime_nfolds_cv_effective_max)' {
            di as error "{bf:hddid}: stored CLIME effective-fold bounds must satisfy min <= max"
            di as error "  Replay found min = " %9.0f `e(clime_nfolds_cv_effective_min)' ///
                " and max = " %9.0f `e(clime_nfolds_cv_effective_max)'
            exit 498
        }
        if !missing(`_clime_nfolds_cv_max_disp') & ///
            `e(clime_nfolds_cv_effective_max)' > `_clime_nfolds_cv_max_disp' {
            di as error "{bf:hddid}: stored realized CLIME CV fold counts must not exceed e(clime_nfolds_cv_max)"
            di as error "  Replay found effective max = " ///
                %9.0f `e(clime_nfolds_cv_effective_max)' ///
                " but requested max = " %9.0f `_clime_nfolds_cv_max_disp'
            exit 498
        }
    }
    // The realized CLIME min/max summary is derived from the per-fold counts.
    // Without the rowvector, replay cannot validate the published diagnostic.
    if `_has_clime_pf_disp' == 0 & ///
        (`_has_clime_req_disp' | `_has_clime_eff_min_disp' | `_has_clime_eff_max_disp') {
        di as error "{bf:hddid}: replay requires stored e(clime_nfolds_cv_per_fold)"
        di as error "  Reason: replay must validate the published realized CLIME fold-count summary against the per-fold counts"
        exit 498
    }
    if `_has_clime_pf_disp' {
        tempname _clime_cv_per_fold_disp
        matrix `_clime_cv_per_fold_disp' = e(clime_nfolds_cv_per_fold)
        if rowsof(`_clime_cv_per_fold_disp') != 1 | ///
            colsof(`_clime_cv_per_fold_disp') != `_k_disp' {
            di as error "{bf:hddid}: stored e(clime_nfolds_cv_per_fold) must be a 1 x k rowvector"
            di as error "  Got " rowsof(`_clime_cv_per_fold_disp') " x " ///
                colsof(`_clime_cv_per_fold_disp') "; replay expects k = `_k_disp'"
            exit 498
        }
        local _clime_pf_min = .
        local _clime_pf_max = .
        forvalues _kk = 1/`_k_disp' {
            local _clime_pf_val = `_clime_cv_per_fold_disp'[1, `_kk']
            if missing(`_clime_pf_val') | ///
                `_clime_pf_val' != floor(`_clime_pf_val') | ///
                (`_clime_pf_val' != 0 & `_clime_pf_val' < 2) {
                di as error "{bf:hddid}: stored realized CLIME CV fold counts must be 0 or integers >= 2"
                di as error "  Replay found e(clime_nfolds_cv_per_fold)[1,`_kk'] = " ///
                    %9.0f `_clime_pf_val'
                exit 498
            }
            if !missing(`_clime_nfolds_cv_max_disp') & ///
                `_clime_pf_val' > `_clime_nfolds_cv_max_disp' {
                di as error "{bf:hddid}: stored realized CLIME CV fold counts must not exceed e(clime_nfolds_cv_max)"
                di as error "  Replay found fold `_kk' effective count = " ///
                    %9.0f `_clime_pf_val' " but requested max = " ///
                    %9.0f `_clime_nfolds_cv_max_disp'
                exit 498
            }
            if missing(`_clime_pf_min') | `_clime_pf_val' < `_clime_pf_min' {
                local _clime_pf_min = `_clime_pf_val'
            }
            if missing(`_clime_pf_max') | `_clime_pf_val' > `_clime_pf_max' {
                local _clime_pf_max = `_clime_pf_val'
            }
        }
        if `_has_clime_eff_min_disp' {
            if `_clime_pf_min' != `e(clime_nfolds_cv_effective_min)' {
                di as error "{bf:hddid}: stored e(clime_nfolds_cv_effective_min) must match e(clime_nfolds_cv_per_fold)"
                di as error "  Replay found min(per-fold) = " %9.0f `_clime_pf_min' ///
                    " but e(clime_nfolds_cv_effective_min) = " ///
                    %9.0f `e(clime_nfolds_cv_effective_min)'
                exit 498
            }
        }
        if `_has_clime_eff_max_disp' {
            if `_clime_pf_max' != `e(clime_nfolds_cv_effective_max)' {
                di as error "{bf:hddid}: stored e(clime_nfolds_cv_effective_max) must match e(clime_nfolds_cv_per_fold)"
                di as error "  Replay found max(per-fold) = " %9.0f `_clime_pf_max' ///
                    " but e(clime_nfolds_cv_effective_max) = " ///
                    %9.0f `e(clime_nfolds_cv_effective_max)'
                exit 498
            }
        }
    }
    tempname xdebias stdx CIpoint
    capture matrix `xdebias' = e(xdebias)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(xdebias)"
        di as error "  Reason: the published parametric summary is defined by the debiased beta estimates"
        exit 498
    }
    capture matrix `stdx' = e(stdx)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(stdx)"
        di as error "  Reason: the published parametric summary includes standard errors for beta"
        exit 498
    }
    capture matrix `CIpoint' = e(CIpoint)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(CIpoint)"
        di as error "  Reason: the published pointwise confidence intervals are part of the replay contract"
        exit 498
    }

    if rowsof(`xdebias') != 1 | colsof(`xdebias') != `p' {
        di as error "{bf:hddid}: stored e(xdebias) must be a 1 x p rowvector"
        di as error "  Got " rowsof(`xdebias') " x " colsof(`xdebias') "; replay expects p = `p'"
        exit 498
    }
    if rowsof(`stdx') != 1 | colsof(`stdx') != `p' {
        di as error "{bf:hddid}: stored e(stdx) must be a 1 x p rowvector"
        di as error "  Got " rowsof(`stdx') " x " colsof(`stdx') "; replay expects p = `p'"
        exit 498
    }
    local _xvars_expected : list retokenize xvars
    local _xdebias_names_actual : colnames `xdebias'
    local _xdebias_names_actual : list retokenize _xdebias_names_actual
    local _stdx_names_actual : colnames `stdx'
    local _stdx_names_actual : list retokenize _stdx_names_actual
    local _current_beta_summary_labels_ok 0
    tempname V_disp
    capture matrix `V_disp' = e(V)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(V)"
        di as error "  Reason: the published parametric covariance matrix is part of the saved-results contract"
        exit 498
    }
    if rowsof(`V_disp') != `p' | colsof(`V_disp') != `p' {
        di as error "{bf:hddid}: stored e(V) must be a p x p matrix"
        di as error "  Got " rowsof(`V_disp') " x " colsof(`V_disp') "; replay expects p = `p'"
        exit 498
    }
    local _V_colnames_actual : colnames `V_disp'
    local _V_colnames_actual : list retokenize _V_colnames_actual
    local _V_rownames_actual : rownames `V_disp'
    local _V_rownames_actual : list retokenize _V_rownames_actual
    capture matrix `CIpoint' = e(CIpoint)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(CIpoint)"
        di as error "  Reason: the published pointwise confidence intervals are part of the replay contract"
        exit 498
    }
    local _cipoint_all_names : colnames `CIpoint'
    local _cipoint_x_names_actual ""
    forvalues j = 1/`p' {
        local _cipoint_name_j : word `j' of `_cipoint_all_names'
        local _cipoint_x_names_actual "`_cipoint_x_names_actual' `_cipoint_name_j'"
    }
    local _cipoint_x_names_actual : list retokenize _cipoint_x_names_actual
    if `"`_xdebias_names_actual'"' == `"`_xvars_expected'"' & ///
        `"`_stdx_names_actual'"' == `"`_xvars_expected'"' & ///
        `"`_cipoint_x_names_actual'"' == `"`_xvars_expected'"' {
        local _current_beta_summary_labels_ok 1
    }
    if (`"`_V_colnames_actual'"' != `"`_xvars_expected'"' | ///
        `"`_V_rownames_actual'"' != `"`_xvars_expected'"') & ///
        !(`_current_result_surface_disp' & `_current_beta_summary_labels_ok') {
        di as error "{bf:hddid}: stored e(V) row/column labels must match e(xvars)"
        di as error "  Replay found a mismatch between the posted covariance labels and the published beta labels"
        exit 498
    }
    mata: st_local("_hddid_bad_V", strofreal(hasmissing(st_matrix("`V_disp'"))))
    if real(`"`_hddid_bad_V'"') == 1 {
        di as error "{bf:hddid}: stored e(V) must be finite"
        di as error "  Replay cannot trust the published parametric covariance matrix with missing/nonfinite entries"
        exit 498
    }
    tempname _V_sym_gap _V_rank
    mata: st_numscalar("`_V_sym_gap'", max(abs(st_matrix("`V_disp'") :- st_matrix("`V_disp'")')))
    if scalar(`_V_sym_gap') > 1e-12 {
        di as error "{bf:hddid}: stored e(V) must be symmetric"
        di as error "  Replay found an asymmetric published parametric covariance matrix; max gap = " ///
            %12.8g scalar(`_V_sym_gap')
        exit 498
    }
    mata: st_numscalar("`_V_rank'", rank(st_matrix("`V_disp'")))
    capture confirm scalar e(rank)
    if _rc {
        // The covariance rank is recoverable from the posted e(V) matrix itself.
        // Missing e(rank) therefore does not invalidate an otherwise coherent
        // current replay surface.
    }
    else if `_current_result_surface_disp' {
        local _rank_disp = e(rank)
        if missing(`_rank_disp') | `_rank_disp' < 0 | `_rank_disp' > `p' | ///
            `_rank_disp' != floor(`_rank_disp') {
            di as error "{bf:hddid}: stored e(rank) must be a finite integer between 0 and p"
            di as error "  Replay cannot validate the published covariance-rank metadata with an invalid rank anchor"
            exit 498
        }
        if `_rank_disp' != scalar(`_V_rank') {
            di as error "{bf:hddid}: stored e(rank) must equal rank(e(V))"
            di as error "  Replay found inconsistent published covariance-rank metadata; stored e(rank) = " ///
                %9.0f `_rank_disp' " but rank(e(V)) = " %9.0f scalar(`_V_rank')
            exit 498
        }
    }
    if `"`_xdebias_names_actual'"' != `"`_xvars_expected'"' | ///
        `"`_stdx_names_actual'"' != `"`_xvars_expected'"' {
        di as error "{bf:hddid}: stored beta labels must match e(xvars)"
        di as error "  Replay found a mismatch between e(xvars) and the published beta point-estimate / standard-error column labels"
        exit 498
    }
    if `"`_cipoint_x_names_actual'"' != `"`_xvars_expected'"' {
        di as error "{bf:hddid}: stored e(CIpoint) beta column labels must match e(xvars)"
        di as error "  Replay found a mismatch between e(xvars) and the beta block of the published pointwise interval object"
        exit 498
    }
    tempname b_disp
    capture matrix `b_disp' = e(b)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(b)"
        di as error "  Reason: the posted Stata eclass coefficient vector must agree with the published beta summary"
        exit 498
    }
    if rowsof(`b_disp') != 1 | colsof(`b_disp') != `p' {
        di as error "{bf:hddid}: stored e(b) must be a 1 x p rowvector"
        di as error "  Got " rowsof(`b_disp') " x " colsof(`b_disp') "; replay expects p = `p'"
        exit 498
    }
    local _b_names_actual : colnames `b_disp'
    local _b_names_actual : list retokenize _b_names_actual
    if `"`_b_names_actual'"' != `"`_xvars_expected'"' & ///
        !(`_current_result_surface_disp' & `_current_beta_summary_labels_ok') {
        di as error "{bf:hddid}: stored e(b) labels must match e(xvars)"
        di as error "  Replay found a mismatch between the posted Stata eclass coefficient labels and the published beta labels"
        exit 498
    }
    local _b_eqnames_actual : coleq `b_disp'
    local _b_eqnames_actual : list retokenize _b_eqnames_actual
    local _V_col_eqnames_actual : coleq `V_disp'
    local _V_col_eqnames_actual : list retokenize _V_col_eqnames_actual
    local _V_row_eqnames_actual : roweq `V_disp'
    local _V_row_eqnames_actual : list retokenize _V_row_eqnames_actual
    local _eqnames_expected ""
    forvalues j = 1/`p' {
        local _eqnames_expected `"`_eqnames_expected' `_depvar_eq_disp'"'
    }
    local _eqnames_expected : list retokenize _eqnames_expected
    local _eqnames_legacy_blank ""
    forvalues j = 1/`p' {
        local _eqnames_legacy_blank `"`_eqnames_legacy_blank' _"'
    }
    local _eqnames_legacy_blank : list retokenize _eqnames_legacy_blank
    local _allow_blank_eqstripe = 0
    if `"`_b_eqnames_actual'"' == `"`_eqnames_legacy_blank'"' & ///
        `"`_V_col_eqnames_actual'"' == `"`_eqnames_legacy_blank'"' & ///
        `"`_V_row_eqnames_actual'"' == `"`_eqnames_legacy_blank'"' {
        if `"`_depvar_role_disp'"' == "" & `"`_depvar_eq_disp'"' != "beta" {
            local _allow_blank_eqstripe 1
        }
        else if `"`_depvar_eq_disp'"' == "beta" {
            local _allow_blank_eqstripe 1
        }
    }
    if (`"`_b_eqnames_actual'"' != `"`_eqnames_expected'"' | ///
        `"`_V_col_eqnames_actual'"' != `"`_eqnames_expected'"' | ///
        `"`_V_row_eqnames_actual'"' != `"`_eqnames_expected'"') & ///
        `_allow_blank_eqstripe' == 0 {
        di as error "{bf:hddid}: stored e(b) and e(V) equation stripes must match e(depvar)"
        di as error "  Replay found e(depvar) = {bf:`_depvar_eq_disp'}"
        di as error "  Replay found coleq(e(b)) = {bf:`_b_eqnames_actual'}"
        di as error "  Replay found coleq(e(V)) = {bf:`_V_col_eqnames_actual'}"
        di as error "  Replay found roweq(e(V)) = {bf:`_V_row_eqnames_actual'}"
        exit 498
    }
    mata: st_local("_hddid_bad_b", strofreal(hasmissing(st_matrix("`b_disp'"))))
    if real(`"`_hddid_bad_b'"') == 1 {
        di as error "{bf:hddid}: stored e(b) must be finite"
        di as error "  Replay cannot trust the posted Stata eclass coefficient vector with missing/nonfinite entries"
        exit 498
    }
    tempname _b_gap
    mata: st_numscalar("`_b_gap'", max(abs(st_matrix("`b_disp'") :- st_matrix("`xdebias'"))))
    if scalar(`_b_gap') > 1e-12 {
        di as error "{bf:hddid}: stored e(b) must equal stored e(xdebias)"
        di as error "  Replay found that the posted Stata eclass coefficient vector differs from the published beta summary; max gap = " ///
            %12.8g scalar(`_b_gap')
        exit 498
    }

    tempname gdebias stdg CIuniform z0_mat
    capture confirm scalar e(qq)
    if _rc {
        local qq = .
        capture matrix `z0_mat' = e(z0)
        if _rc == 0 {
            if rowsof(`z0_mat') == 1 & colsof(`z0_mat') >= 1 {
                local qq = colsof(`z0_mat')
            }
        }
        if missing(`qq') {
            di as error "{bf:hddid}: replay requires stored e(qq) or a published z0-grid width"
            di as error "  Reason: replay needs the posted z0-grid size from stored e(qq) or e(z0) to validate the published omitted-intercept z-varying objects"
            exit 498
        }
    }
    else {
        local qq = e(qq)
    }
    if missing(`qq') | `qq' < 1 | `qq' != floor(`qq') {
        di as error "{bf:hddid}: stored e(qq) must be a finite integer >= 1"
        di as error "  Replay cannot validate nonparametric object dimensions with an invalid z0-grid anchor"
        exit 498
    }
    capture matrix `gdebias' = e(gdebias)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(gdebias)"
        di as error "  Reason: the published nonparametric summary is defined by the debiased omitted-intercept z-varying estimates"
        exit 498
    }
    capture confirm matrix e(stdg)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(stdg)"
        di as error "  Reason: the published nonparametric summary includes pointwise standard errors"
        exit 498
    }
    matrix `stdg' = e(stdg)
    capture matrix `CIuniform' = e(CIuniform)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(CIuniform)"
        di as error "  Reason: the published CIuniform interval object is part of the replay contract"
        exit 498
    }
    capture matrix `z0_mat' = e(z0)
    if _rc {
        di as error "{bf:hddid}: replay requires stored e(z0)"
        di as error "  Reason: replay must align nonparametric results with the published evaluation grid"
        exit 498
    }

    if rowsof(`gdebias') != 1 | colsof(`gdebias') != `qq' {
        di as error "{bf:hddid}: stored e(gdebias) must be a 1 x qq rowvector"
        di as error "  Got " rowsof(`gdebias') " x " colsof(`gdebias') "; replay expects qq = `qq'"
        exit 498
    }
    if rowsof(`stdg') != 1 | colsof(`stdg') != `qq' {
        di as error "{bf:hddid}: stored e(stdg) must be a 1 x qq rowvector"
        di as error "  Got " rowsof(`stdg') " x " colsof(`stdg') "; replay expects qq = `qq'"
        exit 498
    }
    if rowsof(`CIpoint') != 2 | colsof(`CIpoint') != `p' + `qq' {
        local _cipoint_expected = `p' + `qq'
        di as error "{bf:hddid}: stored e(CIpoint) must be 2 x (p + qq)"
        di as error "  Got " rowsof(`CIpoint') " x " colsof(`CIpoint') "; replay expects p + qq = `p' + `qq' = `_cipoint_expected'"
        exit 498
    }
    if rowsof(`CIuniform') != 2 | colsof(`CIuniform') != `qq' {
        di as error "{bf:hddid}: stored e(CIuniform) must be 2 x qq"
        di as error "  Got " rowsof(`CIuniform') " x " colsof(`CIuniform') "; replay expects qq = `qq'"
        exit 498
    }
    local _cipoint_rownames_actual : rownames `CIpoint'
    local _cipoint_rownames_actual : list retokenize _cipoint_rownames_actual
    local _ciuniform_rownames_actual : rownames `CIuniform'
    local _ciuniform_rownames_actual : list retokenize _ciuniform_rownames_actual
    if `"`_cipoint_rownames_actual'"' != "lower upper" | ///
        `"`_ciuniform_rownames_actual'"' != "lower upper" {
        di as error "{bf:hddid}: stored interval matrices must use rownames {bf:lower upper}"
        di as error "  Replay found rownames(CIpoint) = {bf:`_cipoint_rownames_actual'}"
        di as error "  Replay found rownames(CIuniform) = {bf:`_ciuniform_rownames_actual'}"
        exit 498
    }
    if rowsof(`z0_mat') != 1 | colsof(`z0_mat') != `qq' {
        di as error "{bf:hddid}: stored e(z0) must be a 1 x qq rowvector"
        di as error "  Got " rowsof(`z0_mat') " x " colsof(`z0_mat') "; replay expects qq = `qq'"
        exit 498
    }
    local _z0_names_actual : colnames `z0_mat'
    local _z0_names_actual : list retokenize _z0_names_actual
    local _gdebias_names_actual : colnames `gdebias'
    local _gdebias_names_actual : list retokenize _gdebias_names_actual
    local _stdg_names_actual : colnames `stdg'
    local _stdg_names_actual : list retokenize _stdg_names_actual
    local _ciuniform_names_actual : colnames `CIuniform'
    local _ciuniform_names_actual : list retokenize _ciuniform_names_actual
    local _cipoint_all_names : colnames `CIpoint'
    local _cipoint_z_names_actual ""
    // The paper and hddid-r define the nonparametric block through the numeric
    // evaluation grid e(z0) plus aligned column order across the published
    // omitted-intercept objects. Replay therefore does not require the Stata
    // wrapper's e(z0) labels to numerically re-encode that same grid.
    forvalues j = 1/`qq' {
        local _cipoint_name_idx = `p' + `j'
        local _cipoint_name_j : word `_cipoint_name_idx' of `_cipoint_all_names'
        local _cipoint_z_names_actual "`_cipoint_z_names_actual' `_cipoint_name_j'"
    }
    local _cipoint_z_names_actual : list retokenize _cipoint_z_names_actual
    if `"`_gdebias_names_actual'"' != `"`_z0_names_actual'"' | ///
        `"`_stdg_names_actual'"' != `"`_z0_names_actual'"' | ///
        `"`_ciuniform_names_actual'"' != `"`_z0_names_actual'"' | ///
        `"`_cipoint_z_names_actual'"' != `"`_z0_names_actual'"' {
        di as error "{bf:hddid}: stored nonparametric column stripes must match e(z0)"
        di as error "  Replay found a mismatch among the published nonparametric column labels"
        exit 498
    }

    tempname tc_disp
    capture confirm matrix e(tc)
    local _has_tc_disp = (_rc == 0)
    local _tc_same_sign_disp = 0
    local _tc_zero_shortcut_disp = 0

    if !`_has_tc_disp' & `_current_result_surface_disp' {
        di as error "{bf:hddid}: current results require stored e(tc)"
        di as error "  Replay must validate the current-surface bootstrap critical-value provenance behind the published CIuniform interval object before display."
        exit 498
    }

    if `_has_tc_disp' {
        matrix `tc_disp' = e(tc)
        local _tc_rows = rowsof(`tc_disp')
        local _tc_cols = colsof(`tc_disp')
        local _tc_names_actual : colnames `tc_disp'
        local _tc_names_actual : list retokenize _tc_names_actual
        if `_tc_rows' != 1 | `_tc_cols' != 2 {
            di as error "{bf:hddid}: stored e(tc) must be a finite 1 x 2 rowvector"
            di as error "  Got `_tc_rows' x `_tc_cols'; replay needs the bootstrap critical-value pair (lower, upper)"
            exit 498
        }
        if `"`_tc_names_actual'"' != "tc_lower tc_upper" {
            di as error "{bf:hddid}: stored e(tc) must use colnames {bf:tc_lower tc_upper}"
            di as error "  Replay found colnames(e(tc)) = {bf:`_tc_names_actual'}"
            exit 498
        }
        if missing(`tc_disp'[1,1]) | missing(`tc_disp'[1,2]) {
            di as error "{bf:hddid}: stored e(tc) must be a finite 1 x 2 rowvector"
            di as error "  Replay cannot display a bootstrap critical-value pair with missing entries"
            exit 498
        }
        if `tc_disp'[1,1] > `tc_disp'[1,2] {
            di as error "{bf:hddid}: stored e(tc) must satisfy lower <= upper"
            di as error "  Replay received endpoints in descending order"
            exit 498
        }
        local _tc_same_sign_disp = ///
            (`tc_disp'[1,1] > 0 | `tc_disp'[1,2] < 0)
    }
    mata: st_local("_hddid_bad_xdebias", strofreal(hasmissing(st_matrix("`xdebias'"))))
    mata: st_local("_hddid_bad_stdx", strofreal(hasmissing(st_matrix("`stdx'"))))
    mata: st_local("_hddid_bad_cipoint", strofreal(hasmissing(st_matrix("`CIpoint'"))))
    mata: st_local("_hddid_bad_gdebias", strofreal(hasmissing(st_matrix("`gdebias'"))))
    mata: st_local("_hddid_bad_stdg", strofreal(hasmissing(st_matrix("`stdg'"))))
    mata: st_local("_hddid_bad_ciuniform", strofreal(hasmissing(st_matrix("`CIuniform'"))))
    mata: st_local("_hddid_bad_z0", strofreal(hasmissing(st_matrix("`z0_mat'"))))

    if real(`"`_hddid_bad_xdebias'"') == 1 {
        di as error "{bf:hddid}: stored e(xdebias) must be finite"
        di as error "  Replay cannot print parametric estimates with missing/nonfinite entries"
        exit 498
    }
    if real(`"`_hddid_bad_stdx'"') == 1 {
        di as error "{bf:hddid}: stored e(stdx) must be finite"
        di as error "  Replay cannot print parametric standard errors with missing/nonfinite entries"
        exit 498
    }
    mata: st_numscalar("__hddid_min_stdx_disp", min(st_matrix("`stdx'")))
    if scalar(__hddid_min_stdx_disp) < 0 {
        di as error "{bf:hddid}: stored e(stdx) must be nonnegative"
        di as error "  Replay found a negative parametric standard error; min entry = " ///
            %12.8g scalar(__hddid_min_stdx_disp)
        exit 498
    }
    tempname _vstdx_gap _vstdx_scale _vstdx_tol
    mata: st_numscalar("`_vstdx_gap'", ///
        max(abs(diagonal(st_matrix("`V_disp'"))' :- ///
        (st_matrix("`stdx'") :* st_matrix("`stdx'"))))); ///
        st_numscalar("`_vstdx_scale'", ///
        max((1, max(abs(diagonal(st_matrix("`V_disp'"))')), ///
        max(abs(st_matrix("`stdx'") :* st_matrix("`stdx'"))))))
    scalar `_vstdx_tol' = 1e-12 * scalar(`_vstdx_scale')
    if scalar(`_vstdx_gap') > scalar(`_vstdx_tol') {
        di as error "{bf:hddid}: stored diag(e(V)) must equal e(stdx)^2"
        di as error "  Replay found an internally inconsistent parametric covariance diagonal; max gap = " ///
            %12.8g scalar(`_vstdx_gap') " exceeded tolerance = " ///
            %12.8g scalar(`_vstdx_tol')
        exit 498
    }
    if real(`"`_hddid_bad_cipoint'"') == 1 {
        di as error "{bf:hddid}: stored e(CIpoint) must be finite"
        di as error "  Replay cannot print pointwise confidence intervals with missing/nonfinite entries"
        exit 498
    }
    if real(`"`_hddid_bad_gdebias'"') == 1 {
        di as error "{bf:hddid}: stored e(gdebias) must be finite"
        di as error "  Replay cannot print nonparametric estimates with missing/nonfinite entries"
        exit 498
    }
    if real(`"`_hddid_bad_stdg'"') == 1 {
        di as error "{bf:hddid}: stored e(stdg) must be finite"
        di as error "  Replay cannot print nonparametric standard errors with missing/nonfinite entries"
        exit 498
    }
    mata: st_numscalar("__hddid_min_stdg_disp", min(st_matrix("`stdg'")))
    if scalar(__hddid_min_stdg_disp) < 0 {
        di as error "{bf:hddid}: stored e(stdg) must be nonnegative"
        di as error "  Replay found a negative nonparametric standard error; min entry = " ///
            %12.8g scalar(__hddid_min_stdg_disp)
        exit 498
    }
    if real(`"`_hddid_bad_ciuniform'"') == 1 {
        di as error "{bf:hddid}: stored e(CIuniform) must be finite"
        di as error "  Replay cannot print the published CIuniform interval object with missing/nonfinite entries"
        exit 498
    }
    tempname _ciuniform_order_gap
    mata: st_numscalar("`_ciuniform_order_gap'", ///
        max(st_matrix("`CIuniform'")[1,.] :- st_matrix("`CIuniform'")[2,.]))
    if scalar(`_ciuniform_order_gap') > 0 {
        di as error "{bf:hddid}: stored e(CIuniform) lower row must not exceed upper row"
        di as error "  Replay found a malformed published CIuniform interval object; max(lower-upper) = " ///
            %12.8g scalar(`_ciuniform_order_gap')
        exit 498
    }
    if real(`"`_hddid_bad_z0'"') == 1 {
        di as error "{bf:hddid}: stored e(z0) must be finite"
        di as error "  Replay cannot align nonparametric results to a malformed evaluation grid"
        exit 498
    }
    if `"`_method_disp'"' == "Tri" {
        local _tri_z0_outside_disp ""
        forvalues j = 1/`qq' {
            local _tri_z0_j = `z0_mat'[1, `j']
            if `_tri_z0_j' < `_z_support_min_disp' | ///
                `_tri_z0_j' > `_z_support_max_disp' {
                local _tri_z0_j_disp : display %21.15g `_tri_z0_j'
                local _tri_z0_outside_disp ///
                    `"`_tri_z0_outside_disp' `_tri_z0_j_disp'"'
            }
        }
        local _tri_z0_outside_disp : list retokenize _tri_z0_outside_disp
        if `"`_tri_z0_outside_disp'"' != "" {
            di as error "{bf:hddid}: stored e(z0) must lie within stored Tri support"
            di as error "  Replay found stored support = [" ///
                %12.8g `_z_support_min_disp' ", " %12.8g `_z_support_max_disp' ///
                "] and out-of-support e(z0) point(s):`_tri_z0_outside_disp'"
            di as error "  Reason: the published trigonometric basis is defined on the support-normalized coordinate, so replay cannot display the omitted-intercept z-varying surface off that stored domain"
            exit 498
        }
    }

    _hddid_preflight_current_vectors, mode(replay)
    if `_has_tc_disp' {
        tempname _ciu_gap _ciu_scale _ciu_tol
        mata: _ciu_oracle = ///
            (st_matrix("`gdebias'") :+ st_matrix("`tc_disp'")[1,1] :* st_matrix("`stdg'")) \ ///
            (st_matrix("`gdebias'") :+ st_matrix("`tc_disp'")[1,2] :* st_matrix("`stdg'")); ///
            st_numscalar("`_ciu_gap'", ///
            max(abs(st_matrix("`CIuniform'") :- _ciu_oracle))); ///
            st_numscalar("`_ciu_scale'", ///
            max((1, max(abs(st_matrix("`CIuniform'"))), max(abs(_ciu_oracle)))))
        scalar `_ciu_tol' = 1e-12 * scalar(`_ciu_scale')
        if scalar(`_ciu_gap') > scalar(`_ciu_tol') {
            di as error "{bf:hddid}: stored e(CIuniform) must equal the lower/upper rows implied by e(gdebias), e(stdg), and e(tc)"
            di as error "  Replay found an internally inconsistent published CIuniform interval object; max gap = " ///
                %12.8g scalar(`_ciu_gap') " exceeded tolerance = " ///
                %12.8g scalar(`_ciu_tol')
            exit 498
        }
        tempname _stdg_absmax_disp _ciu_shortcut_gap_disp _ciu_shortcut_scale_disp _ciu_shortcut_tol_disp
        mata: st_numscalar("`_stdg_absmax_disp'", max(abs(st_matrix("`stdg'")))); ///
            _hddid_ciu_shortcut_disp = st_matrix("`gdebias'") \ st_matrix("`gdebias'"); ///
            st_numscalar("`_ciu_shortcut_gap_disp'", ///
            max(abs(st_matrix("`CIuniform'") :- _hddid_ciu_shortcut_disp))); ///
            st_numscalar("`_ciu_shortcut_scale_disp'", ///
            max((1, max(abs(st_matrix("`CIuniform'"))), max(abs(_hddid_ciu_shortcut_disp)))))
        scalar `_ciu_shortcut_tol_disp' = 1e-12 * scalar(`_ciu_shortcut_scale_disp')
        if abs(`tc_disp'[1,1]) <= scalar(`_ciu_shortcut_tol_disp') & ///
            abs(`tc_disp'[1,2]) <= scalar(`_ciu_shortcut_tol_disp') & ///
            scalar(`_stdg_absmax_disp') <= scalar(`_ciu_shortcut_tol_disp') & ///
            scalar(`_ciu_shortcut_gap_disp') <= scalar(`_ciu_shortcut_tol_disp') {
            local _tc_zero_shortcut_disp 1
        }
    }

    tempname _cipoint_gap _cipoint_scale _cipoint_tol _zcrit_disp
    scalar `_zcrit_disp' = invnormal(1 - `_alpha_disp' / 2)
    mata: st_numscalar("`_cipoint_gap'", ///
        max(abs(st_matrix("`CIpoint'") :- ( ///
        (st_matrix("`xdebias'") :- st_numscalar("`_zcrit_disp'") :* st_matrix("`stdx'"), ///
         st_matrix("`gdebias'") :- st_numscalar("`_zcrit_disp'") :* st_matrix("`stdg'")) \ ///
        (st_matrix("`xdebias'") :+ st_numscalar("`_zcrit_disp'") :* st_matrix("`stdx'"), ///
         st_matrix("`gdebias'") :+ st_numscalar("`_zcrit_disp'") :* st_matrix("`stdg'")) )))); ///
        st_numscalar("`_cipoint_scale'", ///
        max((1, max(abs(st_matrix("`CIpoint'"))), ///
        max(abs((st_matrix("`xdebias'") :- st_numscalar("`_zcrit_disp'") :* st_matrix("`stdx'"), ///
                 st_matrix("`gdebias'") :- st_numscalar("`_zcrit_disp'") :* st_matrix("`stdg'")) \ ///
                (st_matrix("`xdebias'") :+ st_numscalar("`_zcrit_disp'") :* st_matrix("`stdx'"), ///
                 st_matrix("`gdebias'") :+ st_numscalar("`_zcrit_disp'") :* st_matrix("`stdg'")))))))
    scalar `_cipoint_tol' = 1e-12 * scalar(`_cipoint_scale')
    if scalar(`_cipoint_gap') > scalar(`_cipoint_tol') {
        di as error "{bf:hddid}: stored e(CIpoint) must equal the pointwise intervals implied by e(xdebias), e(stdx), e(gdebias), e(stdg), and e(alpha)"
        di as error "  Replay found internally inconsistent pointwise intervals; max gap = " ///
            %12.8g scalar(`_cipoint_gap') " exceeded tolerance = " ///
            %12.8g scalar(`_cipoint_tol')
        exit 498
    }

    local _title = strtrim(`"`e(title)'"')
    if `"`_title'"' == "" {
        // The title is human-readable display metadata, not part of the
        // estimator-defining beta/f(z0) surface.
        local _title "Doubly Robust Semiparametric DiD with High-Dimensional Data"
    }
    di as text ""
    // --- Header block (Stata-native two-column layout) ---
    di as text "{hline 78}"
    di as text "DR Semiparametric DiD" ///
        _col(49) as text "Number of obs" _col(67) "=" ///
        _col(69) as result %9.0fc `_N_disp'
    di as text "High-Dimensional Data" ///
        _col(49) as text "Cross-fit folds" _col(67) "=" ///
        _col(69) as result %9.0f `_k_disp'
    di as text "" ///
        _col(49) as text "Alpha" _col(67) "=" ///
        _col(69) as result %9.4f `_alpha_disp'
    di as text "{hline 78}"
    di as text "Outcome (delta Y)  = " as result "`_depvar_disp'" ///
        _col(49) as text "Method" _col(67) "=" ///
        _col(69) as result %9s "`_method_disp' (q=`_q_disp')"
    di as text "Treatment          = " as result "`_treat_disp'" ///
        _col(49) as text "Covariates (p)" _col(67) "=" ///
        _col(69) as result %9.0f `p'
    di as text "Sieve variable (z) = " as result "`_zvar_disp'"

    // --- Parametric table (Stata-native coefficient table) ---
    local _ci_level = round((1 - `_alpha_disp') * 100, 1)
    di as text ""
    di as text "Debiased parametric estimates (beta)"
    di as text "{hline 78}"
    di as text %13s " " "{c |}" ///
        %11s "Coef." %11s "Std. Err." %9s "z" %8s "P>|z|" ///
        "     [`_ci_level'% Conf. Interval]"
    di as text "{hline 13}{c +}{hline 64}"

    forvalues j = 1/`p' {
        local vname : word `j' of `xvars'
        local _bval = `xdebias'[1, `j']
        local _sval = `stdx'[1, `j']
        local _zstat = .
        local _pval = .
        if `_sval' > 0 & !missing(`_sval') {
            local _zstat = `_bval' / `_sval'
            local _pval = 2 * normal(-abs(`_zstat'))
        }
        di as text %13s abbrev("`vname'",12) " {c |}" as result ///
            %11.7g `_bval' ///
            %11.7g `_sval' ///
            %9.2f `_zstat' ///
            %8.3f `_pval' ///
            "    " %10.7g `CIpoint'[1, `j'] ///
            %11.7g `CIpoint'[2, `j']
    }
    di as text "{hline 13}{c BT}{hline 64}"

    // --- Nonparametric table (merged pointwise + uniform CI) ---
    di as text ""
    di as text "Debiased nonparametric function f(z)"
    di as text "{hline 78}"
    di as text %10s "z0" " {c |}" ///
        %11s "f(z0)" %10s "Std. Err." ///
        "    [`_ci_level'% Ptwise CI]" ///
        "    [`_ci_level'% Unif. CI]"
    di as text "{hline 10}{c +}{hline 67}"

    forvalues j = 1/`qq' {
        local _zval = `z0_mat'[1, `j']
        di as text %10.4g `_zval' " {c |}" as result ///
            %11.6f `gdebias'[1, `j'] ///
            %10.6f `stdg'[1, `j'] ///
            "   " %10.6f `CIpoint'[1, `p' + `j'] ///
            %10.6f `CIpoint'[2, `p' + `j'] ///
            "   " %10.6f `CIuniform'[1, `j'] ///
            %10.6f `CIuniform'[2, `j']
    }
    di as text "{hline 10}{c BT}{hline 67}"

    // --- Compact footer ---
    di as text ""
    di as text "N = " as result `_N_disp' as text ///
        "    Folds = " as result `_k_disp' as text ///
        "    p = " as result `p' as text ///
        "    q = " as result `_q_disp'
    di as text "Estimator: " as result "AIPW (doubly robust)" as text ///
        "    Estimand: conditional ATT"
    local _footer_seed_str ""
    if `_has_seed_disp' {
        local _footer_seed_str "    seed = `_seed_disp'"
    }
    local _footer_nboot_str ""
    if `_has_nboot_disp' {
        local _footer_nboot_str "    nboot = `_nboot_disp'"
    }
    di as text "Bootstrap:`_footer_nboot_str'" as text "`_footer_seed_str'"
    // Compact diagnostics
    if `_has_N_trimmed_disp' & `_N_trimmed_disp' > 0 {
        di as text "Trimmed obs: " as result `_N_trimmed_disp'
    }
    if `"`_method_disp'"' == "Tri" {
        di as text "Tri support: [" as result %12.8g `_z_support_min_disp' ///
            as text ", " as result %12.8g `_z_support_max_disp' as text "]"
    }
    di as text "Fold counts: " as result "`_N_per_fold_summary'"
    if `"`_firststage_mode_disp'"' == "nofirst" {
        di as text "First stage: " as result "user-supplied (nofirst)"
    }
    // Skip the extremely verbose N_outer_split and inner CV diagnostic blocks.
    // These details are available via e(N_outer_split), e(N_pretrim),
    // e(propensity_nfolds), e(outcome_nfolds), etc.
    local _show_N_outer_split_disp 0
    if 0 {
        if `_current_result_surface_disp' & ///
            `"`_firststage_mode_disp'"' == "internal" {
            di as text "  Under the default internal-first-stage path, if/in qualifiers are applied before both the broader D/W-complete propensity sample and the common-score sample are built."
            di as text "  D/W-complete rows missing {bf:depvar} never become held-out evaluation rows, so they stay available to every fold-external default-path propensity training sample."
            di as text "  If the qualifier-defined and physically subsetted default-path runs hand hddid the same D/W-complete rows in the same order, they must therefore deliver the same retained-sample estimates."
            di as text "  Excluded rows do not continue to widen the internal propensity path, pin the common-score outer split, or move the x() canonicalization anchor."
        }
        else if `_current_result_surface_disp' & ///
            `"`_firststage_mode_disp'"' == "nofirst" {
            di as text "  Under {bf:nofirst}, supplied {bf:pihat()} must already be fold-aligned out-of-fold on the broader strict-interior pretrim fold-feasibility sample."
            di as text "  That broader strict-interior pretrim fold-feasibility sample is the nofirst-specific split path rebuilt from the supplied nuisance inputs, not the default internal-first-stage score sample."
            di as text "  Under {bf:nofirst}, if/in qualifiers are applied before hddid rebuilds that broader strict-interior nofirst split path."
            di as text "  Running with if/in is therefore equivalent to physically subsetting those rows first: excluded rows do not continue to pin the outer split, retained estimator fold ids, or same-fold nuisance checks."
            di as text "  If the retained rows stay in the same order and the supplied fold-aligned nuisances are the same, the corresponding nofirst if/in run and physically subsetted run must return the same retained-sample estimates."
            di as text "  Exact-boundary pihat() rows stay outside that broader strict-interior fold-feasibility split and do not pin retained outer fold IDs by themselves."
            di as text "  Any legal strict-interior 0<pihat()<1 row still enters that broader strict-interior fold-feasibility path before later overlap trimming, but only treatment-arm keys with at least one retained-overlap pretrim row pin the published retained outer fold IDs."
            di as text "  Only treatment-arm keys with at least one retained-overlap pretrim row pin the retained outer fold IDs."
            di as text "  Retained rows then keep those already-assigned outer fold IDs on the narrower retained-overlap score sample."
            di as text "  Retained-overlap membership only narrows the later retained estimator sample and same-arm phi duplicate-key checks; it does not erase those already-assigned outer fold IDs."
            di as text "  Same-fold cross-arm phi candidate checks also extend to depvar-missing or otherwise score-ineligible twins with pihat() still in [0.01,0.99] when shared W=(X,Z) rows stay on the same retained estimator fold IDs."
            di as text "  Same-arm phi duplicate-key checks also extend to depvar-missing twins with pihat() still in [0.01,0.99] when that treatment-arm key still contributes a retained overlap row."
            if `_has_N_pretrim_disp' & ///
                `_N_outer_split_disp' > `_N_pretrim_disp' {
                di as text "  Legal strict-interior pihat() rows excluded from the score by missing depvar(), phi1hat(), or phi0hat() can still keep e(N_outer_split) above e(N_pretrim), because the outer fold map is fixed before those later score-sample eligibility checks."
            }
            if `_has_N_pretrim_disp' & ///
                `_N_outer_split_disp' < `_N_pretrim_disp' {
                di as text "  Legal strict-interior pihat() rows on treatment-arm keys that never contribute a retained-overlap pretrim row do not pin retained outer fold IDs, so e(N_pretrim) can exceed e(N_outer_split)."
            }
            if `_has_N_pretrim_disp' & ///
                `_N_outer_split_disp' == `_N_pretrim_disp' {
                di as text "  Under {bf:nofirst}, {bf:e(N_outer_split)=e(N_pretrim)} can still hide different fold-pinning membership because strict-interior rows can replace exact-boundary score rows one-for-one."
            }
        }
    }
    if `_replay_role_data_present' & `_N_esample_disp' > 0 {
        if `_N_esample_disp' == `_N_disp' {
            di as text "Live e(sample) match:"
            di as text "  count-only sanity check; replay still uses the stored e() surface."
        }
        else {
            di as text "Live e(sample) differs from stored e(N):"
            di as text "  current count = " as result `_N_esample_disp' ///
                as text ", stored e(N) = " as result `_N_disp'
            di as text "  informational only; replay still uses the stored e() surface."
        }
    }
    if `"`_firststage_mode_disp'"' == "nofirst" {
        di as text "First stage: " as result ///
            "user-supplied nuisance inputs (nofirst)"
    }
    else {
        di as text "First stage: " as result ///
            "internal nuisance estimation"
    }
    local _inner_parts ""
    local _inner_sep ""
    capture confirm scalar e(propensity_nfolds)
    if _rc == 0 {
        local _inner_prop = e(propensity_nfolds)
        if !missing(`_inner_prop') {
            local _inner_parts `"`_inner_parts'`_inner_sep'propensity=`_inner_prop'"'
            local _inner_sep ", "
        }
    }
    capture confirm scalar e(outcome_nfolds)
    if _rc == 0 {
        local _inner_outcome = e(outcome_nfolds)
        if !missing(`_inner_outcome') {
            local _inner_parts `"`_inner_parts'`_inner_sep'outcome=`_inner_outcome'"'
            local _inner_sep ", "
        }
    }
    capture confirm scalar e(secondstage_nfolds)
    if _rc == 0 {
        local _inner_stage2 = e(secondstage_nfolds)
        if !missing(`_inner_stage2') {
            local _inner_parts `"`_inner_parts'`_inner_sep'second-stage=`_inner_stage2'"'
            local _inner_sep ", "
        }
    }
    capture confirm scalar e(mmatrix_nfolds)
    if _rc == 0 {
        local _inner_mm = e(mmatrix_nfolds)
        if !missing(`_inner_mm') {
            local _inner_parts `"`_inner_parts'`_inner_sep'M-matrix=`_inner_mm'"'
            local _inner_sep ", "
        }
    }
    local _inner_clime ""
    local _inner_clime_note1 ""
    local _inner_clime_note2 ""
    capture confirm scalar e(clime_nfolds_cv_max)
    local _has_clime_req = (_rc == 0)
    if `_has_clime_req' {
        local _inner_clime_req = e(clime_nfolds_cv_max)
        if !missing(`_inner_clime_req') {
            local _inner_clime "requested<=`_inner_clime_req'"
        }
    }
    capture confirm scalar e(clime_nfolds_cv_effective_min)
    local _has_clime_eff_min = (_rc == 0)
    capture confirm scalar e(clime_nfolds_cv_effective_max)
    local _has_clime_eff_max = (_rc == 0)
    if `"`_inner_clime'"' != "" & `_has_clime_eff_min' & `_has_clime_eff_max' {
        local _inner_clime_eff_min = e(clime_nfolds_cv_effective_min)
        local _inner_clime_eff_max = e(clime_nfolds_cv_effective_max)
        if !missing(`_inner_clime_eff_min') & !missing(`_inner_clime_eff_max') {
            if `_inner_clime_eff_min' == 0 & `_inner_clime_eff_max' == 0 {
                if `p' == 1 {
                    local _inner_clime "`_inner_clime', effective=0"
                    local _inner_clime_note1 "CLIME note: analytic scalar inverse; CV skipped"
                }
                else {
                    local _inner_clime "`_inner_clime', effective=0"
                    local _inner_clime_note1 "CLIME note: skipped on all folds"
                    local _inner_clime_note2 "            diagonal-covariance shortcut or constant-score fallback"
                }
            }
            else if `_inner_clime_eff_min' == 0 {
                local _inner_clime "`_inner_clime', effective=0..`_inner_clime_eff_max'"
                if `p' == 1 {
                    local _inner_clime_note1 "CLIME note: 0 means CV skipped on at least one fold via a scalar analytic inverse or retained constant-score fallback"
                }
                else {
                    local _inner_clime_note1 "CLIME note: 0 means CV skipped on at least one fold via a"
                    local _inner_clime_note2 "            diagonal-covariance shortcut or constant-score fallback"
                }
            }
            else if `_inner_clime_eff_min' == `_inner_clime_eff_max' {
                local _inner_clime "`_inner_clime', effective=`_inner_clime_eff_min'"
            }
            else {
                local _inner_clime "`_inner_clime', effective=`_inner_clime_eff_min'..`_inner_clime_eff_max'"
            }
        }
    }
    if `"`_inner_clime'"' != "" {
        if `"`_inner_parts'"' != "" {
            di as text "Inner CV folds: `_inner_parts'"
        }
        di as text "CLIME CV folds: `_inner_clime'"
        if `"`_inner_clime_note1'"' != "" {
            di as text "`_inner_clime_note1'"
        }
        if `"`_inner_clime_note2'"' != "" {
            di as text "`_inner_clime_note2'"
        }
    }
    else if `"`_inner_parts'"' != "" {
        di as text "Inner CV folds: `_inner_parts'"
    }

    if `_has_tc_disp' {
        if `_tc_zero_shortcut_disp' {
            di as text "Degenerate zero-SE shortcut sentinel: tc = (" ///
                as result %21.15g `tc_disp'[1,1] as text ", " ///
                as result %21.15g `tc_disp'[1,2] as text ")"
            di as text "  No studentized Gaussian-bootstrap draws were used for this published nonparametric interval object."
            di as text "  Interpret e(tc)=(0,0) as the deterministic shortcut proving CIuniform collapsed to gdebias on the stored z0 grid."
        }
        else {
            di as text "Bootstrap tc provenance (ordered lower/upper critical-value provenance behind CIuniform): tc = (" ///
                as result %21.15g `tc_disp'[1,1] as text ", " ///
                as result %21.15g `tc_disp'[1,2] as text ")"
            di as text "  Current path: rowwise-envelope lower/upper studentized-process pair (min_j lower_j, max_j upper_j)."
            di as text "  Interpret this as ordered lower/upper bootstrap critical-value provenance, not a symmetric cutoff pair."
        }
    }
end
