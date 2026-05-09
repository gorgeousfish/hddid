capture program drop _hddid_pst_cmdroles
program define _hddid_pst_cmdroles
    version 16
    syntax , CMDLINE(string asis) DEPVAR(string asis) TREAT(string asis) XVARS(string asis) ZVAR(string asis)

    local _depvar `"`depvar'"'
    if strlen(`"`_depvar'"') >= 2 & substr(`"`_depvar'"', 1, 1) == char(34) & ///
        substr(`"`_depvar'"', strlen(`"`_depvar'"'), 1) == char(34) {
        local _depvar = substr(`"`_depvar'"', 2, strlen(`"`_depvar'"') - 2)
    }
    local _depvar = strtrim(`"`_depvar'"')
    local _treat `"`treat'"'
    if strlen(`"`_treat'"') >= 2 & substr(`"`_treat'"', 1, 1) == char(34) & ///
        substr(`"`_treat'"', strlen(`"`_treat'"'), 1) == char(34) {
        local _treat = substr(`"`_treat'"', 2, strlen(`"`_treat'"') - 2)
    }
    local _treat = strtrim(`"`_treat'"')
    local _xvars `"`xvars'"'
    if strlen(`"`_xvars'"') >= 2 & substr(`"`_xvars'"', 1, 1) == char(34) & ///
        substr(`"`_xvars'"', strlen(`"`_xvars'"'), 1) == char(34) {
        local _xvars = substr(`"`_xvars'"', 2, strlen(`"`_xvars'"') - 2)
    }
    local _xvars = strtrim(`"`_xvars'"')
    local _zvar `"`zvar'"'
    if strlen(`"`_zvar'"') >= 2 & substr(`"`_zvar'"', 1, 1) == char(34) & ///
        substr(`"`_zvar'"', strlen(`"`_zvar'"'), 1) == char(34) {
        local _zvar = substr(`"`_zvar'"', 2, strlen(`"`_zvar'"') - 2)
    }
    local _zvar = strtrim(`"`_zvar'"')
    local _cmdline_display `"`cmdline'"'
    if strlen(`"`_cmdline_display'"') >= 2 & substr(`"`_cmdline_display'"', 1, 1) == char(34) & ///
        substr(`"`_cmdline_display'"', strlen(`"`_cmdline_display'"'), 1) == char(34) {
        local _cmdline_display = substr(`"`_cmdline_display'"', 2, strlen(`"`_cmdline_display'"') - 2)
    }

    local _post_role_data_present 1
    capture confirm variable `_depvar'
    if _rc {
        local _post_role_data_present 0
    }
    capture confirm variable `_treat'
    if _rc {
        local _post_role_data_present 0
    }
    capture confirm variable `_zvar'
    if _rc {
        local _post_role_data_present 0
    }
    foreach _xvar of local _xvars {
        capture confirm variable `_xvar'
        if _rc {
            local _post_role_data_present 0
        }
    }

    local _cmdline_parse `"`_cmdline_display'"'
    local _cmdline_parse = subinstr(`"`_cmdline_parse'"', char(9), " ", .)
    local _cmdline_parse = subinstr(`"`_cmdline_parse'"', char(10), " ", .)
    local _cmdline_parse = subinstr(`"`_cmdline_parse'"', char(13), " ", .)
    local _cmdline_lc = lower(`"`_cmdline_parse'"')
    local _cmdline_opts ""
    local _cmdline_comma = strpos(`"`_cmdline_lc'"', ",")
    if `_cmdline_comma' > 0 {
        local _cmdline_opts = strtrim(substr(`"`_cmdline_lc'"', `_cmdline_comma' + 1, .))
    }

    local _cmdline_depvar ""
    local _cmdline_treat ""
    local _cmdline_xvars ""
    local _cmdline_zvar ""
    if regexm(`"`_cmdline_lc'"', "^[ ]*hddid[ ]+([^, ]+)") {
        local _cmdline_depvar = strtrim(regexs(1))
    }
    if regexm(`"`_cmdline_opts'"', "(^|[ ,])tr(e(a(t)?)?)[(]([^)]*)[)]") {
        local _cmdline_treat = strtrim(regexs(5))
    }
    if regexm(`"`_cmdline_opts'"', "(^|[ ,])x[(]([^)]*)[)]") {
        local _cmdline_xvars = strtrim(regexs(2))
    }
    if regexm(`"`_cmdline_opts'"', "(^|[ ,])z[(]([^)]*)[)]") {
        local _cmdline_zvar = strtrim(regexs(2))
    }

    local _cmdline_role_mismatch 0
    local _cmdline_xvars_mismatch 0
    local _depvar_cmd_expected = lower(strtrim(`"`_depvar'"'))
    local _treat_cmd_expected = lower(strtrim(`"`_treat'"'))
    local _xvars_cmd_expected = lower(strtrim(`"`_xvars'"'))
    local _xvars_cmd_expected : list retokenize _xvars_cmd_expected
    local _zvar_cmd_expected = lower(strtrim(`"`_zvar'"'))
    local _published_vars_cmd_expected `"`_depvar_cmd_expected' `_treat_cmd_expected' `_xvars_cmd_expected' `_zvar_cmd_expected'"'
    local _published_vars_cmd_expected : list retokenize _published_vars_cmd_expected

    local _cmdline_depvar_cmp = lower(strtrim(`"`_cmdline_depvar'"'))
    local _cmdline_treat_cmp = lower(strtrim(`"`_cmdline_treat'"'))
    local _cmdline_xvars_cmp = lower(strtrim(`"`_cmdline_xvars'"'))
    local _cmdline_xvars_cmp : list retokenize _cmdline_xvars_cmp
    local _cmdline_zvar_cmp = lower(strtrim(`"`_cmdline_zvar'"'))

    if `_post_role_data_present' & `"`_cmdline_depvar'"' != "" {
        capture unab _cmdline_depvar_canon : `_cmdline_depvar'
        if _rc == 0 {
            local _cmdline_depvar_cmp = lower(strtrim(`"`_cmdline_depvar_canon'"'))
        }
    }
    if `"`_cmdline_depvar_cmp'"' != "" & ///
        `"`_cmdline_depvar_cmp'"' != `"`_depvar_cmd_expected'"' & ///
        strpos(`"`_depvar_cmd_expected'"', `"`_cmdline_depvar_cmp'"') == 1 {
        local _cmdline_depvar_match_count 0
        foreach _published_var of local _published_vars_cmd_expected {
            if strpos(`"`_published_var'"', `"`_cmdline_depvar_cmp'"') == 1 {
                local _cmdline_depvar_match_count = `_cmdline_depvar_match_count' + 1
            }
        }
        if `_cmdline_depvar_match_count' == 1 {
            local _cmdline_depvar_cmp `"`_depvar_cmd_expected'"'
        }
    }

    if `_post_role_data_present' & `"`_cmdline_treat'"' != "" {
        capture unab _cmdline_treat_canon : `_cmdline_treat'
        if _rc == 0 {
            local _cmdline_treat_cmp = lower(strtrim(`"`_cmdline_treat_canon'"'))
        }
    }
    if `"`_cmdline_treat_cmp'"' != "" & ///
        `"`_cmdline_treat_cmp'"' != `"`_treat_cmd_expected'"' & ///
        strpos(`"`_treat_cmd_expected'"', `"`_cmdline_treat_cmp'"') == 1 {
        local _cmdline_treat_match_count 0
        foreach _published_var of local _published_vars_cmd_expected {
            if strpos(`"`_published_var'"', `"`_cmdline_treat_cmp'"') == 1 {
                local _cmdline_treat_match_count = `_cmdline_treat_match_count' + 1
            }
        }
        if `_cmdline_treat_match_count' == 1 {
            local _cmdline_treat_cmp `"`_treat_cmd_expected'"'
        }
    }

    local _cmdline_xvars_has_wild = ///
        (strpos(`"`_cmdline_xvars'"', "*") > 0 | ///
         strpos(`"`_cmdline_xvars'"', "?") > 0)
    if `_post_role_data_present' & `"`_cmdline_xvars'"' != "" & ///
        `_cmdline_xvars_has_wild' == 0 {
        capture unab _cmdline_xvars_canon : `_cmdline_xvars'
        if _rc == 0 {
            local _cmdline_xvars_cmp = lower(strtrim(`"`_cmdline_xvars_canon'"'))
            local _cmdline_xvars_cmp : list retokenize _cmdline_xvars_cmp
        }
        else {
            capture tsunab _cmdline_xvars_canon : `_cmdline_xvars'
            if _rc == 0 {
                local _cmdline_xvars_cmp = lower(strtrim(`"`_cmdline_xvars_canon'"'))
                local _cmdline_xvars_cmp : list retokenize _cmdline_xvars_cmp
            }
        }
    }
    if `"`_cmdline_xvars'"' != "" & ///
        (`"`_cmdline_xvars_cmp'"' == "" | ///
         strpos(`"`_cmdline_xvars_cmp'"', "-") > 0 | ///
         strpos(`"`_cmdline_xvars_cmp'"', "*") > 0 | ///
         strpos(`"`_cmdline_xvars_cmp'"', "?") > 0) {
        local _xrange_exp ""
        local _xrange_fail 0
        local _xraw = lower(strtrim(`"`_cmdline_xvars'"'))
        local _xraw : list retokenize _xraw
        // Wildcard specifications in e(cmdline) x() are historical records
        // once e(xvars) has published the canonical variable list. A broader
        // wildcard expansion must not override the stored canonical names;
        // variable-range expansions remain dependent on the dataset in memory.
        foreach _xraw_tok of local _xraw {
            if strpos(`"`_xraw_tok'"', "-") > 0 & regexm(`"`_xraw_tok'"', "^([^ -]+)-([^ -]+)$") {
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
                else if `_post_role_data_present' {
                    // When data are in memory, unab has already resolved
                    // any variable range against dataset order. Reuse the
                    // published e(xvars) slice between the uniquely matched
                    // endpoints.
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
                    // When data are no longer in memory, retain the stored
                    // range only if the endpoint names encode an explicit
                    // numeric sequence coherent with e(xvars). Numeric
                    // sequences are verified element-wise against the stored
                    // metadata; nonnumeric ranges are ambiguous without live
                    // data and are not reinterpreted from the stored endpoints
                    // alone.
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
            else if strpos(`"`_xraw_tok'"', "*") > 0 | strpos(`"`_xraw_tok'"', "?") > 0 {
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
        if `_xrange_fail' == 0 & `"`_xrange_exp'"' != "" {
            local _cmdline_xvars_cmp = lower(strtrim(`"`_xrange_exp'"'))
            local _cmdline_xvars_cmp : list retokenize _cmdline_xvars_cmp
        }
    }
    if `"`_cmdline_xvars_cmp'"' != "" & `"`_cmdline_xvars_cmp'"' != `"`_xvars_cmd_expected'"' {
        local _cmdline_xvars_count : word count `_cmdline_xvars_cmp'
        local _xvars_expected_count : word count `_xvars_cmd_expected'
        if `_cmdline_xvars_count' == `_xvars_expected_count' {
            local _cmdline_xvars_match_fail 0
            local _cmdline_xvars_matched ""
            foreach _cmdline_xvar of local _cmdline_xvars_cmp {
                local _cmdline_xvar_match_count 0
                local _cmdline_xvar_match ""
                foreach _published_var of local _published_vars_cmd_expected {
                    if strpos(`"`_published_var'"', `"`_cmdline_xvar'"') == 1 {
                        local _cmdline_xvar_match_count = `_cmdline_xvar_match_count' + 1
                        local _cmdline_xvar_match `"`_published_var'"'
                    }
                }
                local _cmdline_xvar_expected_pos : list posof `"`_cmdline_xvar_match'"' in _xvars_cmd_expected
                if `_cmdline_xvar_match_count' != 1 | `_cmdline_xvar_expected_pos' == 0 {
                    local _cmdline_xvars_match_fail 1
                }
                else {
                    local _cmdline_xvar_match_pos : list posof `"`_cmdline_xvar_match'"' in _cmdline_xvars_matched
                    if `_cmdline_xvar_match_pos' > 0 {
                        local _cmdline_xvars_match_fail 1
                    }
                    else {
                        local _cmdline_xvars_matched `"`_cmdline_xvars_matched' `_cmdline_xvar_match'"'
                    }
                }
            }
            if `_cmdline_xvars_match_fail' == 0 {
                local _cmdline_xvars_cmp `"`_xvars_cmd_expected'"'
            }
        }
    }

    if `_post_role_data_present' & `"`_cmdline_zvar'"' != "" {
        capture unab _cmdline_zvar_canon : `_cmdline_zvar'
        if _rc == 0 {
            local _cmdline_zvar_cmp = lower(strtrim(`"`_cmdline_zvar_canon'"'))
        }
    }
    if `"`_cmdline_zvar_cmp'"' != "" & ///
        `"`_cmdline_zvar_cmp'"' != `"`_zvar_cmd_expected'"' & ///
        strpos(`"`_zvar_cmd_expected'"', `"`_cmdline_zvar_cmp'"') == 1 {
        local _cmdline_zvar_match_count 0
        foreach _published_var of local _published_vars_cmd_expected {
            if strpos(`"`_published_var'"', `"`_cmdline_zvar_cmp'"') == 1 {
                local _cmdline_zvar_match_count = `_cmdline_zvar_match_count' + 1
            }
        }
        if `_cmdline_zvar_match_count' == 1 {
            local _cmdline_zvar_cmp `"`_zvar_cmd_expected'"'
        }
    }

    if `"`_cmdline_depvar_cmp'"' != "" & `"`_cmdline_depvar_cmp'"' != `"`_depvar_cmd_expected'"' {
        local _cmdline_role_mismatch 1
    }
    if `"`_cmdline_treat_cmp'"' != "" & `"`_cmdline_treat_cmp'"' != `"`_treat_cmd_expected'"' {
        local _cmdline_role_mismatch 1
    }
    // e(cmdline) provides a textual record of the original call. When
    // e(depvar), e(treat), e(xvars), and e(zvar) are already stored,
    // omission of x() from the textual record is acceptable; role
    // mismatches are detected whenever a concrete x() specification
    // contradicts the stored metadata.
    local _cmdline_xvars_sorted : list sort _cmdline_xvars_cmp
    local _xvars_cmd_expected_sorted : list sort _xvars_cmd_expected
    if `"`_cmdline_xvars_cmp'"' != "" & `"`_cmdline_xvars_sorted'"' != `"`_xvars_cmd_expected_sorted'"' {
        local _cmdline_xvars_mismatch 1
        local _cmdline_role_mismatch 1
    }
    if `"`_cmdline_zvar_cmp'"' != "" & `"`_cmdline_zvar_cmp'"' != `"`_zvar_cmd_expected'"' {
        local _cmdline_role_mismatch 1
    }

    if `_cmdline_role_mismatch' {
        if `_cmdline_xvars_mismatch' {
            di as error "{bf:hddid}: stored e(cmdline) x() mapping must agree with the published e(xvars) metadata"
            di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline_display'}"
            di as error "  Current postestimation guidance found published {bf:e(xvars)} = {bf:`_xvars'}"
            exit 498
        }
        di as error "{bf:hddid}: stored e(cmdline) role mapping must agree with the published depvar/treat/z metadata"
        di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline_display'}"
        di as error "  Current postestimation guidance found published roles depvar={bf:`_depvar'}, treat={bf:`_treat'}, x={bf:`_xvars'}, z={bf:`_zvar'}"
        exit 498
    }
end
