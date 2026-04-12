program define _hddid_preflight_current_vectors
    version 16
    syntax, MODE(string)

    local _mode = lower(trim("`mode'"))
    local _prefix "Current postestimation guidance"
    if "`_mode'" == "replay" {
        local _prefix "Replay"
    }

    capture confirm scalar e(p)
    local _has_p = (_rc == 0)
    local _p = .
    if `_has_p' {
        local _p = e(p)
    }

    capture confirm scalar e(qq)
    local _has_qq = (_rc == 0)
    local _qq = .
    if `_has_qq' {
        local _qq = e(qq)
    }

    local _has_xvars = (`"`e(xvars)'"' != "")
    local _xvars_lc ""
    if `_has_xvars' {
        local _xvars_lc = lower(strtrim(`"`e(xvars)'"'))
        local _xvars_lc : list retokenize _xvars_lc
    }
    local _beta_names_expected ""
    local _beta_names_expected_source ""

    capture confirm matrix e(z0)
    local _has_z0 = (_rc == 0)
    local _z0_names_actual ""
    if `_has_z0' {
        tempname _z0
        matrix `_z0' = e(z0)
        if rowsof(`_z0') != 1 | (`_has_qq' & colsof(`_z0') != `_qq') {
            di as error "{bf:hddid}: stored e(z0) must be a 1 x qq rowvector"
            di as error "  `_prefix' must validate the published nonparametric evaluation grid before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        tempname _z0_bad
        mata: st_numscalar("`_z0_bad'", hasmissing(st_matrix("`_z0'")))
        if scalar(`_z0_bad') != 0 {
            di as error "{bf:hddid}: stored e(z0) must be finite"
            di as error "  `_prefix' must validate the published nonparametric evaluation grid before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        local _z0_names_actual : colnames `_z0'
        local _z0_names_actual : list retokenize _z0_names_actual
    }

    if `_has_p' == 0 {
        if `"`_xvars_lc'"' != "" {
            local _p : word count `_xvars_lc'
            local _has_p = !missing(`_p') & `_p' >= 1
        }
        if `_has_p' == 0 {
            capture confirm matrix e(xdebias)
            if _rc == 0 {
                tempname _xdebias_p_probe
                matrix `_xdebias_p_probe' = e(xdebias)
                if rowsof(`_xdebias_p_probe') == 1 & ///
                    colsof(`_xdebias_p_probe') >= 1 {
                    local _p = colsof(`_xdebias_p_probe')
                    local _has_p = 1
                }
            }
        }
        if `_has_p' == 0 {
            capture confirm matrix e(stdx)
            if _rc == 0 {
                tempname _stdx_p_probe
                matrix `_stdx_p_probe' = e(stdx)
                if rowsof(`_stdx_p_probe') == 1 & ///
                    colsof(`_stdx_p_probe') >= 1 {
                    local _p = colsof(`_stdx_p_probe')
                    local _has_p = 1
                }
            }
        }
        if `_has_p' == 0 {
            capture confirm matrix e(b)
            if _rc == 0 {
                tempname _b
                matrix `_b' = e(b)
                if colsof(`_b') >= 1 {
                    local _p = colsof(`_b')
                    local _has_p = 1
                }
            }
        }
    }

    if `_has_qq' == 0 & `_has_z0' {
        if rowsof(`_z0') == 1 & colsof(`_z0') >= 1 {
            local _qq = colsof(`_z0')
            local _has_qq = 1
        }
    }

    if `_has_qq' == 0 & `_has_p' {
        capture confirm matrix e(CIpoint)
        if _rc == 0 {
            tempname _cipoint_width_probe
            matrix `_cipoint_width_probe' = e(CIpoint)
            if rowsof(`_cipoint_width_probe') == 2 {
                if colsof(`_cipoint_width_probe') < `_p' {
                    di as error "{bf:hddid}: stored e(CIpoint) must be 2 x (p + qq)"
                    di as error "  `_prefix' must validate pointwise interval-matrix shape metadata before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                    exit 498
                }
                local _qq_from_cipoint = colsof(`_cipoint_width_probe') - `_p'
                if `_qq_from_cipoint' > 0 {
                    local _qq = `_qq_from_cipoint'
                    local _has_qq = 1
                }
            }
        }
    }

    if `_has_xvars' {
        local _beta_names_expected `"`_xvars_lc'"'
        local _beta_names_expected_source "e(xvars)"
    }
    else if `_has_p' {
        capture confirm matrix e(xdebias)
        if _rc == 0 {
            tempname _xdebias_beta_probe
            matrix `_xdebias_beta_probe' = e(xdebias)
            if rowsof(`_xdebias_beta_probe') == 1 & colsof(`_xdebias_beta_probe') == `_p' {
                local _beta_names_expected : colnames `_xdebias_beta_probe'
                local _beta_names_expected = lower(strtrim(`"`_beta_names_expected'"'))
                local _beta_names_expected : list retokenize _beta_names_expected
                local _beta_names_expected_source "e(xdebias)"
            }
        }
        if `"`_beta_names_expected'"' == "" {
            capture confirm matrix e(stdx)
            if _rc == 0 {
                tempname _stdx_beta_probe
                matrix `_stdx_beta_probe' = e(stdx)
                if rowsof(`_stdx_beta_probe') == 1 & colsof(`_stdx_beta_probe') == `_p' {
                    local _beta_names_expected : colnames `_stdx_beta_probe'
                    local _beta_names_expected = lower(strtrim(`"`_beta_names_expected'"'))
                    local _beta_names_expected : list retokenize _beta_names_expected
                    local _beta_names_expected_source "e(stdx)"
                }
            }
        }
        if `"`_beta_names_expected'"' == "" {
            capture confirm matrix e(CIpoint)
            if _rc == 0 {
                tempname _cipoint_beta_probe
                matrix `_cipoint_beta_probe' = e(CIpoint)
                if rowsof(`_cipoint_beta_probe') == 2 & colsof(`_cipoint_beta_probe') >= `_p' {
                    local _cipoint_beta_names_probe : colnames `_cipoint_beta_probe'
                    local _cipoint_beta_names_probe = lower(strtrim(`"`_cipoint_beta_names_probe'"'))
                    local _cipoint_beta_names_probe : list retokenize _cipoint_beta_names_probe
                    local _beta_names_expected ""
                    forvalues _j = 1/`_p' {
                        local _beta_names_expected `"`_beta_names_expected' `: word `_j' of `_cipoint_beta_names_probe''"'
                    }
                    local _beta_names_expected : list retokenize _beta_names_expected
                    local _beta_names_expected_source "e(CIpoint) beta block"
                }
            }
        }
        if `"`_beta_names_expected'"' == "" {
            capture confirm matrix e(b)
            if _rc == 0 {
                tempname _b_beta_probe
                matrix `_b_beta_probe' = e(b)
                if rowsof(`_b_beta_probe') == 1 & colsof(`_b_beta_probe') == `_p' {
                    local _beta_names_expected : colnames `_b_beta_probe'
                    local _beta_names_expected = lower(strtrim(`"`_beta_names_expected'"'))
                    local _beta_names_expected : list retokenize _beta_names_expected
                    local _beta_names_expected_source "e(b)"
                }
            }
        }
    }

    local _has_xdebias_matrix 0
    capture confirm matrix e(xdebias)
    if _rc == 0 {
        local _has_xdebias_matrix 1
        tempname _xdebias
        matrix `_xdebias' = e(xdebias)
        if rowsof(`_xdebias') != 1 | (`_has_p' & colsof(`_xdebias') != `_p') {
            di as error "{bf:hddid}: stored e(xdebias) must be a 1 x p rowvector"
            di as error "  `_prefix' must validate beta point-estimate rowvector metadata before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        tempname _xdebias_bad
        mata: st_numscalar("`_xdebias_bad'", hasmissing(st_matrix("`_xdebias'")))
        if scalar(`_xdebias_bad') != 0 {
            di as error "{bf:hddid}: stored e(xdebias) must be finite"
            di as error "  `_prefix' must validate beta point-estimate finiteness before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        local _xdebias_names_actual : colnames `_xdebias'
        local _xdebias_names_actual = lower(strtrim(`"`_xdebias_names_actual'"'))
        local _xdebias_names_actual : list retokenize _xdebias_names_actual
        if `"`_beta_names_expected'"' != "" {
            if `"`_xdebias_names_actual'"' != `"`_beta_names_expected'"' {
                di as error "{bf:hddid}: stored e(xdebias) colnames must match e(xvars)"
                if `_has_xvars' {
                    di as error "  `_prefix' must validate beta coordinate labels before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                }
                else {
                    di as error "  `_prefix' must recover one coherent beta coordinate map from the published current-result beta objects when stored e(xvars) is blank."
                    di as error "  Found e(xdebias)={bf:`_xdebias_names_actual'} but `_beta_names_expected_source'={bf:`_beta_names_expected'}."
                }
                exit 498
            }
        }
    }

    local _has_b_matrix 0
    capture confirm matrix e(b)
    if _rc == 0 {
        local _has_b_matrix 1
        tempname _b_current
        matrix `_b_current' = e(b)
        local _b_names_actual : colnames `_b_current'
        local _b_names_actual = lower(strtrim(`"`_b_names_actual'"'))
        local _b_names_actual : list retokenize _b_names_actual
        if `"`_beta_names_expected'"' != "" {
            if `"`_b_names_actual'"' != `"`_beta_names_expected'"' {
                di as error "{bf:hddid}: stored e(b) labels must match e(xvars)"
                if `_has_xvars' {
                    di as error "  `_prefix' must validate posted beta-vector coordinate labels before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                }
                else {
                    di as error "  `_prefix' must recover one coherent beta coordinate map from the published current-result beta objects when stored e(xvars) is blank."
                    di as error "  Found e(b)={bf:`_b_names_actual'} but `_beta_names_expected_source'={bf:`_beta_names_expected'}."
                }
                exit 498
            }
        }
    }

    if `_has_b_matrix' & `_has_xdebias_matrix' {
        tempname _bx_gap _bx_scale _bx_tol
        mata: st_numscalar("`_bx_gap'", ///
            max(abs(st_matrix("`_b_current'") :- st_matrix("`_xdebias'")))); ///
            st_numscalar("`_bx_scale'", ///
            max((1, max(abs(st_matrix("`_b_current'"))), ///
            max(abs(st_matrix("`_xdebias'"))))))
        scalar `_bx_tol' = 1e-12 * scalar(`_bx_scale')
        if scalar(`_bx_gap') > scalar(`_bx_tol') {
            di as error "{bf:hddid}: stored e(b) must equal e(xdebias)"
            di as error "  `_prefix' must keep the generic Stata beta vector and the published debiased beta surface numerically identical before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            di as error "  Found max |e(b) - e(xdebias)| = " %12.8g scalar(`_bx_gap') ///
                " exceeded tolerance = " %12.8g scalar(`_bx_tol')
            exit 498
        }
    }

    capture confirm matrix e(stdx)
    if _rc == 0 {
        tempname _stdx
        matrix `_stdx' = e(stdx)
        if rowsof(`_stdx') != 1 | (`_has_p' & colsof(`_stdx') != `_p') {
            di as error "{bf:hddid}: stored e(stdx) must be a 1 x p rowvector"
            di as error "  `_prefix' must validate beta standard-error rowvector metadata before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        tempname _stdx_bad _stdx_min
        mata: st_numscalar("`_stdx_bad'", hasmissing(st_matrix("`_stdx'"))); ///
            st_numscalar("`_stdx_min'", min(st_matrix("`_stdx'")))
        if scalar(`_stdx_bad') != 0 {
            di as error "{bf:hddid}: stored e(stdx) must be finite"
            di as error "  `_prefix' must validate beta standard-error finiteness before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if scalar(`_stdx_min') < 0 {
            di as error "{bf:hddid}: stored e(stdx) must be nonnegative"
            di as error "  `_prefix' must validate beta standard-error scale metadata before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        local _stdx_names_actual : colnames `_stdx'
        local _stdx_names_actual = lower(strtrim(`"`_stdx_names_actual'"'))
        local _stdx_names_actual : list retokenize _stdx_names_actual
        if `"`_beta_names_expected'"' != "" {
            if `"`_stdx_names_actual'"' != `"`_beta_names_expected'"' {
                di as error "{bf:hddid}: stored e(stdx) colnames must match e(xvars)"
                if `_has_xvars' {
                    di as error "  `_prefix' must validate beta standard-error coordinate labels before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                }
                else {
                    di as error "  `_prefix' must recover one coherent beta coordinate map from the published current-result beta objects when stored e(xvars) is blank."
                    di as error "  Found e(stdx)={bf:`_stdx_names_actual'} but `_beta_names_expected_source'={bf:`_beta_names_expected'}."
                }
                exit 498
            }
        }
    }

    capture confirm matrix e(CIpoint)
    if _rc == 0 {
        tempname _cipoint _cipoint_bad
        matrix `_cipoint' = e(CIpoint)
        if rowsof(`_cipoint') != 2 | ///
            (`_has_p' & `_has_qq' & colsof(`_cipoint') != `_p' + `_qq') {
            di as error "{bf:hddid}: stored e(CIpoint) must be 2 x (p + qq)"
            di as error "  `_prefix' must validate pointwise interval-matrix shape metadata before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        local _cipoint_rownames_actual : rownames `_cipoint'
        local _cipoint_rownames_actual : list retokenize _cipoint_rownames_actual
        if `"`_cipoint_rownames_actual'"' != "lower upper" {
            di as error "{bf:hddid}: stored e(CIpoint) must use rownames {bf:lower upper}"
            di as error "  `_prefix' must validate pointwise interval endpoint semantics before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        mata: st_numscalar("`_cipoint_bad'", hasmissing(st_matrix("`_cipoint'")))
        if scalar(`_cipoint_bad') != 0 {
            di as error "{bf:hddid}: stored e(CIpoint) must be finite"
            di as error "  `_prefix' must validate pointwise interval-object finiteness before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if `_has_p' & `_has_qq' & `"`_beta_names_expected'"' != "" {
            local _cipoint_names_actual : colnames `_cipoint'
            local _cipoint_names_actual = lower(strtrim(`"`_cipoint_names_actual'"'))
            local _cipoint_names_actual : list retokenize _cipoint_names_actual
            local _cipoint_x_names_actual ""
            forvalues _j = 1/`_p' {
                local _cipoint_x_names_actual `"`_cipoint_x_names_actual' `: word `_j' of `_cipoint_names_actual''"'
            }
            local _cipoint_x_names_actual : list retokenize _cipoint_x_names_actual
            if `"`_cipoint_x_names_actual'"' != `"`_beta_names_expected'"' {
                di as error "{bf:hddid}: stored e(CIpoint) beta column labels must match e(xvars)"
                if `_has_xvars' {
                    di as error "  `_prefix' must validate pointwise beta interval coordinate labels before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                }
                else {
                    di as error "  `_prefix' must recover one coherent beta coordinate map from the published current-result beta objects when stored e(xvars) is blank."
                    di as error "  Found CIpoint(beta)={bf:`_cipoint_x_names_actual'} but `_beta_names_expected_source'={bf:`_beta_names_expected'}."
                }
                exit 498
            }
        }
        if `_has_p' & `_has_qq' & `_has_z0' {
            local _cipoint_names_actual : colnames `_cipoint'
            local _cipoint_names_actual : list retokenize _cipoint_names_actual
            local _cipoint_z_names_actual ""
            local _cipoint_z_start = `_p' + 1
            forvalues _j = `_cipoint_z_start'/`=`_p' + `_qq'' {
                local _cipoint_z_names_actual `"`_cipoint_z_names_actual' `: word `_j' of `_cipoint_names_actual''"'
            }
            local _cipoint_z_names_actual : list retokenize _cipoint_z_names_actual
            if `"`_cipoint_z_names_actual'"' != `"`_z0_names_actual'"' {
                di as error "{bf:hddid}: stored e(CIpoint) nonparametric column labels must match e(z0)"
                di as error "  `_prefix' must validate pointwise nonparametric grid labels before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
        }
    }

    capture confirm matrix e(gdebias)
    if _rc == 0 {
        tempname _gdebias
        matrix `_gdebias' = e(gdebias)
        if rowsof(`_gdebias') != 1 | (`_has_qq' & colsof(`_gdebias') != `_qq') {
            di as error "{bf:hddid}: stored e(gdebias) must be a 1 x qq rowvector"
            di as error "  `_prefix' must validate nonparametric point-estimate rowvector metadata before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        tempname _gdebias_bad
        mata: st_numscalar("`_gdebias_bad'", hasmissing(st_matrix("`_gdebias'")))
        if scalar(`_gdebias_bad') != 0 {
            di as error "{bf:hddid}: stored e(gdebias) must be finite"
            di as error "  `_prefix' must validate nonparametric point-estimate finiteness before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if `_has_z0' {
            local _gdebias_names_actual : colnames `_gdebias'
            local _gdebias_names_actual : list retokenize _gdebias_names_actual
            if `"`_gdebias_names_actual'"' != `"`_z0_names_actual'"' {
                di as error "{bf:hddid}: stored e(gdebias) colnames must match e(z0)"
                di as error "  `_prefix' must validate nonparametric point-estimate grid labels before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
        }
    }

    capture confirm matrix e(CIuniform)
    if _rc == 0 {
        tempname _ciuniform
        matrix `_ciuniform' = e(CIuniform)
        if rowsof(`_ciuniform') != 2 | ///
            (`_has_qq' & colsof(`_ciuniform') != `_qq') {
            di as error "{bf:hddid}: stored e(CIuniform) must be 2 x qq"
            di as error "  `_prefix' must validate nonparametric interval-matrix shape metadata before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        local _ciuniform_rownames_actual : rownames `_ciuniform'
        local _ciuniform_rownames_actual : list retokenize _ciuniform_rownames_actual
        if `"`_ciuniform_rownames_actual'"' != "lower upper" {
            di as error "{bf:hddid}: stored e(CIuniform) must use rownames {bf:lower upper}"
            di as error "  `_prefix' must validate nonparametric interval endpoint semantics before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if `_has_z0' {
            local _ciuniform_names_actual : colnames `_ciuniform'
            local _ciuniform_names_actual : list retokenize _ciuniform_names_actual
            if `"`_ciuniform_names_actual'"' != `"`_z0_names_actual'"' {
                di as error "{bf:hddid}: stored e(CIuniform) colnames must match e(z0)"
                di as error "  `_prefix' must validate nonparametric interval-object grid labels before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
        }
    }

    capture confirm matrix e(stdg)
    if _rc == 0 {
        tempname _stdg
        matrix `_stdg' = e(stdg)
        if rowsof(`_stdg') != 1 | (`_has_qq' & colsof(`_stdg') != `_qq') {
            di as error "{bf:hddid}: stored e(stdg) must be a 1 x qq rowvector"
            di as error "  `_prefix' must validate nonparametric standard-error rowvector metadata before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        tempname _stdg_bad _stdg_min
        mata: st_numscalar("`_stdg_bad'", hasmissing(st_matrix("`_stdg'"))); ///
            st_numscalar("`_stdg_min'", min(st_matrix("`_stdg'")))
        if scalar(`_stdg_bad') != 0 {
            di as error "{bf:hddid}: stored e(stdg) must be finite"
            di as error "  `_prefix' must validate nonparametric standard-error finiteness before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if scalar(`_stdg_min') < 0 {
            di as error "{bf:hddid}: stored e(stdg) must be nonnegative"
            di as error "  `_prefix' must validate nonparametric standard-error scale metadata before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if `_has_z0' {
            local _stdg_names_actual : colnames `_stdg'
            local _stdg_names_actual : list retokenize _stdg_names_actual
            if `"`_stdg_names_actual'"' != `"`_z0_names_actual'"' {
                di as error "{bf:hddid}: stored e(stdg) colnames must match e(z0)"
                di as error "  `_prefix' must validate nonparametric standard-error grid labels before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
        }
    }

    capture confirm matrix e(CIpoint)
    if _rc == 0 {
        tempname _cipoint_order_gap
        mata: st_numscalar("`_cipoint_order_gap'", ///
            max(st_matrix("e(CIpoint)")[1,.] :- ///
            st_matrix("e(CIpoint)")[2,.]))
        if scalar(`_cipoint_order_gap') > 0 {
            di as error "{bf:hddid}: stored e(CIpoint) lower row must not exceed upper row"
            di as error "  `_prefix' must validate ordered pointwise interval endpoints before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
    }

    capture confirm matrix e(CIuniform)
    local _has_ciuniform = (_rc == 0)
    if `_has_ciuniform' {
        tempname _ciuniform_bad _ciuniform_order_gap
        mata: st_numscalar("`_ciuniform_bad'", hasmissing(st_matrix("e(CIuniform)"))); ///
            st_numscalar("`_ciuniform_order_gap'", ///
            max(st_matrix("e(CIuniform)")[1,.] :- ///
            st_matrix("e(CIuniform)")[2,.]))
        if scalar(`_ciuniform_bad') != 0 {
            di as error "{bf:hddid}: stored e(CIuniform) must be finite"
            di as error "  `_prefix' must validate nonparametric interval-object finiteness before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if scalar(`_ciuniform_order_gap') > 0 {
            di as error "{bf:hddid}: stored e(CIuniform) lower row must not exceed upper row"
            di as error "  `_prefix' must validate ordered nonparametric interval endpoints before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
    }

    capture confirm matrix e(gdebias)
    local _has_gdebias = (_rc == 0)
    capture confirm matrix e(stdg)
    local _has_stdg = (_rc == 0)
    capture confirm matrix e(CIpoint)
    local _has_cipoint = (_rc == 0)
    if `_has_z0' == 0 {
        local _nonparam_bundle_missing_z0 ""
        if `_has_gdebias' {
            local _nonparam_bundle_missing_z0 `"`_nonparam_bundle_missing_z0' e(gdebias)"'
        }
        if `_has_stdg' {
            local _nonparam_bundle_missing_z0 `"`_nonparam_bundle_missing_z0' e(stdg)"'
        }
        if `_has_ciuniform' {
            local _nonparam_bundle_missing_z0 `"`_nonparam_bundle_missing_z0' e(CIuniform)"'
        }
        if `_has_cipoint' & `_has_p' & `_has_qq' & !missing(`_qq') & `_qq' > 0 {
            local _nonparam_bundle_missing_z0 `"`_nonparam_bundle_missing_z0' e(CIpoint) nonparametric block"' 
        }
        local _nonparam_bundle_missing_z0 : list retokenize _nonparam_bundle_missing_z0
        if `"`_nonparam_bundle_missing_z0'"' != "" {
            di as error "{bf:hddid}: stored nonparametric current-surface objects require bundled e(z0)"
            di as error "  `_prefix' must reject unlabeled nonparametric evaluation surfaces before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            di as error "  Published object(s) missing their shared evaluation grid: {bf:`_nonparam_bundle_missing_z0'}"
            exit 498
        }
    }

    capture confirm matrix e(tc)
    local _has_tc = (_rc == 0)
    if "`_mode'" == "current" & `_has_z0' & ///
        (`_has_gdebias' | `_has_stdg' | `_has_ciuniform' | `_has_tc' | ///
        `_has_cipoint') {
        local _curr_np_missing ""
        if `_has_gdebias' == 0 {
            local _curr_np_missing `"`_curr_np_missing' e(gdebias)"'
        }
        if `_has_stdg' == 0 {
            local _curr_np_missing `"`_curr_np_missing' e(stdg)"'
        }
        if `_has_ciuniform' == 0 {
            local _curr_np_missing `"`_curr_np_missing' e(CIuniform)"'
        }
        if `_has_tc' == 0 {
            local _curr_np_missing `"`_curr_np_missing' e(tc)"'
        }
        if `_has_cipoint' == 0 {
            local _curr_np_missing `"`_curr_np_missing' e(CIpoint)"'
        }
        local _curr_np_missing : list retokenize _curr_np_missing
        if `"`_curr_np_missing'"' != "" {
            di as error "{bf:hddid}: current saved-results surfaces with stored e(z0) require bundled e(gdebias), e(stdg), e(CIuniform), e(tc), and e(CIpoint)"
            di as error "  `_prefix' must reject incomplete current inference-surface metadata before replay or direct unsupported postestimation can consume the stored surface."
            di as error "  Missing companion object(s): {bf:`_curr_np_missing'}"
            exit 498
        }
    }
    if `_has_ciuniform' {
        local _ciuniform_bundle_missing ""
        if `_has_gdebias' == 0 {
            local _ciuniform_bundle_missing `"`_ciuniform_bundle_missing' e(gdebias)"'
        }
        if `_has_stdg' == 0 {
            local _ciuniform_bundle_missing `"`_ciuniform_bundle_missing' e(stdg)"'
        }
        if `_has_tc' == 0 {
            local _ciuniform_bundle_missing `"`_ciuniform_bundle_missing' e(tc)"'
        }
        local _ciuniform_bundle_missing : list retokenize _ciuniform_bundle_missing
        if `"`_ciuniform_bundle_missing'"' != "" {
            di as error "{bf:hddid}: stored e(CIuniform) requires bundled e(gdebias), e(stdg), and e(tc)"
            di as error "  `_prefix' must reject incomplete nonparametric bootstrap-band metadata before interval algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            di as error "  Missing companion object(s): {bf:`_ciuniform_bundle_missing'}"
            exit 498
        }
    }
    if `_has_tc' & `_has_ciuniform' == 0 {
        di as error "{bf:hddid}: stored e(tc) requires bundled e(CIuniform)"
        di as error "  `_prefix' must reject orphaned bootstrap critical-value provenance before interval algebra or ancillary seed()/alpha()/nboot() cmdline checks."
        exit 498
    }
    if `_has_tc' {
        tempname _tc _tc_bad
        matrix `_tc' = e(tc)
        local _tc_names_actual : colnames `_tc'
        local _tc_names_actual : list retokenize _tc_names_actual
        mata: st_numscalar("`_tc_bad'", hasmissing(st_matrix("`_tc'")))
        if rowsof(`_tc') != 1 | colsof(`_tc') != 2 | ///
            scalar(`_tc_bad') != 0 {
            di as error "{bf:hddid}: stored e(tc) must be a finite 1 x 2 rowvector"
            di as error "  `_prefix' must validate CIuniform bootstrap provenance before interval algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if `"`_tc_names_actual'"' != "tc_lower tc_upper" {
            di as error "{bf:hddid}: stored e(tc) must use colnames {bf:tc_lower tc_upper}"
            di as error "  `_prefix' must validate unambiguous CIuniform bootstrap provenance before interval algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
        if `_tc'[1,1] > `_tc'[1,2] {
            di as error "{bf:hddid}: stored e(tc) must satisfy lower <= upper"
            di as error "  `_prefix' must validate ordered CIuniform bootstrap provenance before interval algebra or ancillary seed()/alpha()/nboot() cmdline checks."
            exit 498
        }
    }
    if `_has_ciuniform' & `_has_gdebias' & `_has_stdg' & `_has_tc' {
        tempname _ciuniform_gap _ciuniform_scale _stdg_absmax _stdg_scale _zero_stdg_tol _tc_scale _tc_tol
        mata: st_numscalar("`_stdg_absmax'", max(abs(st_matrix("e(stdg)")))); ///
            st_numscalar("`_stdg_scale'", max((1, max(abs(st_matrix("e(stdg)")))))); ///
            st_numscalar("`_tc_scale'", max((1, max(abs(st_matrix("`_tc'"))))))
        scalar `_zero_stdg_tol' = 1e-12 * scalar(`_stdg_scale')
        scalar `_tc_tol' = 1e-12 * scalar(`_tc_scale')
        if scalar(`_stdg_absmax') <= scalar(`_zero_stdg_tol') {
            tempname _ciu_zero_shortcut _ciu_zero_gap _ciu_zero_scale
            mata: _hddid_ciu_zero_shortcut = st_matrix("e(gdebias)") \ st_matrix("e(gdebias)"); ///
                st_numscalar("`_ciu_zero_gap'", max(abs(st_matrix("e(CIuniform)") :- _hddid_ciu_zero_shortcut))); ///
                st_numscalar("`_ciu_zero_scale'", max((1, max(abs(st_matrix("e(CIuniform)"))), max(abs(_hddid_ciu_zero_shortcut)))))
            scalar `_tc_tol' = max(scalar(`_tc_tol'), 1e-12 * scalar(`_ciu_zero_scale'))
            if scalar(`_ciu_zero_gap') > scalar(`_tc_tol') {
                di as error "{bf:hddid}: stored e(CIuniform) must collapse exactly to e(gdebias) when stored e(stdg) is identically zero"
                di as error "  `_prefix' must reject displaced zero-SE nonparametric interval rows before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
            if abs(`_tc'[1,1]) > scalar(`_tc_tol') | ///
                abs(`_tc'[1,2]) > scalar(`_tc_tol') {
                di as error "{bf:hddid}: stored e(tc) must equal (0, 0) when stored e(stdg) is identically zero"
                di as error "  `_prefix' must reject nonzero bootstrap critical-value metadata on the degenerate zero-SE shortcut before CI algebra or ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
        }
        else {
            mata: ciu_pf = st_matrix("e(CIuniform)")
            mata: gd_pf = st_matrix("e(gdebias)")
            mata: sg_pf = st_matrix("e(stdg)")
            mata: tc_pf = st_matrix("`_tc'")
            mata: ciu_lo_pf = gd_pf :+ tc_pf[1, 1] * sg_pf
            mata: ciu_hi_pf = gd_pf :+ tc_pf[1, 2] * sg_pf
            mata: ciu_oracle_pf = ciu_lo_pf \ ciu_hi_pf
            mata: st_numscalar("`_ciuniform_gap'", max(abs(ciu_pf :- ciu_oracle_pf)))
            mata: st_numscalar("`_ciuniform_scale'", max((1, max(abs(ciu_pf)), max(abs(ciu_oracle_pf)))))
            if scalar(`_ciuniform_gap') > 1e-12 * scalar(`_ciuniform_scale') {
                di as error "{bf:hddid}: stored e(CIuniform) must equal the lower/upper rows implied by e(gdebias), e(stdg), and e(tc)"
                di as error "  `_prefix' must reject malformed current interval-object metadata before ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
            if abs(`_tc'[1,1]) <= scalar(`_tc_tol') & ///
                abs(`_tc'[1,2]) <= scalar(`_tc_tol') {
                di as error "{bf:hddid}: stored e(tc) must not equal (0, 0) when stored e(stdg) is not identically zero"
                di as error "  `_prefix' must reject degenerate current CIuniform bootstrap provenance before ancillary seed()/alpha()/nboot() cmdline checks."
                di as error "  Reason: with nonzero published e(stdg), e(tc) = (0, 0) would collapse stored e(CIuniform) back to e(gdebias) instead of defining a distinct two-sided bootstrap envelope."
                exit 498
            }
        }
    }
    capture confirm scalar e(alpha)
    local _has_alpha = (_rc == 0)
    if `_has_cipoint' & `_has_xdebias_matrix' & `_has_gdebias' & ///
        `_has_stdg' & `_has_alpha' {
        capture confirm matrix e(stdx)
        local _has_stdx = (_rc == 0)
        if `_has_stdx' {
            tempname _cipoint_gap _cipoint_scale _cipoint_tol _zcrit
            scalar `_zcrit' = invnormal(1 - e(alpha) / 2)
            mata: st_numscalar("`_cipoint_gap'", ///
                max(abs(st_matrix("e(CIpoint)") :- ( ///
                (st_matrix("e(xdebias)") :- st_numscalar("`_zcrit'") :* st_matrix("e(stdx)"), ///
                 st_matrix("e(gdebias)") :- st_numscalar("`_zcrit'") :* st_matrix("e(stdg)")) \ ///
                (st_matrix("e(xdebias)") :+ st_numscalar("`_zcrit'") :* st_matrix("e(stdx)"), ///
                 st_matrix("e(gdebias)") :+ st_numscalar("`_zcrit'") :* st_matrix("e(stdg)")) )))); ///
                st_numscalar("`_cipoint_scale'", ///
                max((1, max(abs(st_matrix("e(CIpoint)"))), ///
                max(abs((st_matrix("e(xdebias)") :- st_numscalar("`_zcrit'") :* st_matrix("e(stdx)"), ///
                         st_matrix("e(gdebias)") :- st_numscalar("`_zcrit'") :* st_matrix("e(stdg)")) \ ///
                        (st_matrix("e(xdebias)") :+ st_numscalar("`_zcrit'") :* st_matrix("e(stdx)"), ///
                         st_matrix("e(gdebias)") :+ st_numscalar("`_zcrit'") :* st_matrix("e(stdg)")))))))
            scalar `_cipoint_tol' = 1e-12 * scalar(`_cipoint_scale')
            if scalar(`_cipoint_gap') > scalar(`_cipoint_tol') {
                di as error "{bf:hddid}: stored e(CIpoint) must equal the pointwise intervals implied by e(xdebias), e(stdx), e(gdebias), e(stdg), and e(alpha)"
                di as error "  `_prefix' must reject malformed current pointwise interval metadata before ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
        }
    }

end
