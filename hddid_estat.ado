capture program drop _hddid_postest_parse_estopt
capture program drop _hddid_postest_show_invalid
capture program drop _hddid_postest_parse_methodopt
capture program drop _hddid_current_beta_coords
capture program drop _hddid_estat_preflight

program define _hddid_current_beta_coords, rclass
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

program define _hddid_estat_preflight
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
        di as error "  Reason: direct unsupported postestimation on current results delegates beta/interval consistency checks to a sibling helper"
        di as error "  Please reinstall the hddid package or remove shadow/old copies from adopath"
        exit 198
    }
end

program define _hddid_postest_parse_methodopt, rclass
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
    local _hddid_opts_trim = strtrim(`"`_hddid_opts_raw_orig'"')
    if regexm(lower(`"`_hddid_opts_trim'"'), ///
        "^'[ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*'([ ,]|$)") {
        exit
    }
    local _hddid_dq = char(34)
    local _hddid_sq = char(39)
    local _hddid_dq_est_pat = "^" + char(34) + ///
        "[ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*" + char(34) + "([ ,]|$)"
    if regexm(lower(`"`_hddid_opts_trim'"'), `"`_hddid_dq_est_pat'"') {
        exit
    }
    if regexm(`"`_hddid_opts_trim'"', ///
        `"^[(][ ]*'(r|ra|i|ip|ipw|a|ai|aip|aipw)'[ ]*[)]([ ,]|$)"') {
        exit
    }
    local _hddid_dq_paren_est_pat = "^[(][ ]*" + char(34) + ///
        "(r|ra|i|ip|ipw|a|ai|aip|aipw)" + char(34) + "[ ]*[)]([ ,]|$)"
    if regexm(lower(`"`_hddid_opts_trim'"'), `"`_hddid_dq_paren_est_pat'"') {
        exit
    }
    if strlen(`"`_hddid_opts_trim'"') >= 2 {
        local _hddid_trim_first = substr(`"`_hddid_opts_trim'"', 1, 1)
        local _hddid_trim_last = substr(`"`_hddid_opts_trim'"', -1, 1)
        if ((substr(`"`_hddid_opts_trim'"', 1, 1) == char(34) & ///
            substr(`"`_hddid_opts_trim'"', -1, 1) == char(34)) | ///
            (substr(`"`_hddid_opts_trim'"', 1, 1) == char(39) & ///
            substr(`"`_hddid_opts_trim'"', -1, 1) == char(39))) {
            local _hddid_inner_method = ///
                substr(`"`_hddid_opts_trim'"', 2, length(`"`_hddid_opts_trim'"') - 2)
            local _hddid_inner_method = strtrim(`"`_hddid_inner_method'"')
            local _hddid_inner_method_lc = lower(`"`_hddid_inner_method'"')
            if `"`_hddid_inner_method'"' != "" {
                if regexm(`"`_hddid_inner_method_lc'"', ///
                    "^method[ ]*=[ ]*[^ ,]*$") {
                    return local invalid "1"
                    return local method `"`_hddid_opts_trim'"'
                    exit
                }
                if regexm(`"`_hddid_inner_method_lc'"', ///
                    "^method[ ]*[(][ ]*([^)]*)[ ]*[)]$") {
                    local _hddid_method = strtrim(regexs(1))
                    local _hddid_method = ///
                        subinstr(`"`_hddid_method'"', char(34), "", .)
                    local _hddid_method = ///
                        subinstr(`"`_hddid_method'"', char(39), "", .)
                    local _hddid_method = strproper(strtrim(`"`_hddid_method'"'))
                    if !inlist(`"`_hddid_method'"', "Pol", "Tri") {
                        return local invalid "1"
                        return local method `"`_hddid_method'"'
                        exit
                    }
                    return local raw `"`_hddid_opts_trim'"'
                    exit
                }
                // A fully quoted bare token like 'ra' belongs to the
                // estimator-style postest parser, not the method() precheck.
                // Let that parser classify the fixed-AIPW misuse instead of
                // feeding the quoted token back into regexr(), which Stata can
                // misread as function syntax and abort with unknown function().
                exit
            }
        }
    }
    if regexm(`"`_hddid_opts_trim'"', ///
        `"^method[ ]*[(][ ]*'([^']*)'[ ]*[)]([ ,]|$)"') {
        local _hddid_method = strproper(strtrim(regexs(1)))
        if !inlist(`"`_hddid_method'"', "Pol", "Tri") {
            return local invalid "1"
            return local method `"`_hddid_method'"'
            exit
        }
        return local raw `"`_hddid_opts_trim'"'
        exit
    }
    if strpos(`"`_hddid_opts_raw_lc'"', "method") == 0 {
        exit
    }
    local _hddid_methodscan_lc `"`_hddid_opts_raw_lc'"'
    // Nested method(...) text inside an estimator-family payload (for example
    // estimator= method(ra)) is part of malformed estimator syntax, not a real
    // method() request. Keep the method-domain precheck from stealing those
    // cases before estimator-family guidance can classify them.
    local _hddid_methodscan_lc = ///
        regexr(`"`_hddid_methodscan_lc'"', ///
        "(^|[ ,])estimator[ ]*=[ ]*[(]?[ ]*method[ ]*[(][^)]*[)][ ]*[)]?", ///
        " __hddid_estimator_payload__ ")
    local _hddid_methodscan_lc = ///
        regexr(`"`_hddid_methodscan_lc'"', ///
        "(^|[ ,])estimator[ ]*=[ ]*[(][^)]*[)][ ]*method[ ]*[(][^)]*[)]", ///
        " __hddid_estimator_payload__ ")
    local _hddid_methodscan_lc = ///
        regexr(`"`_hddid_methodscan_lc'"', ///
        "(^|[ ,])estimator[ ]*=[ ]*[(]?[^ ,]+[)]?[ ]*method[ ]*=[ ]*[^ ,]*", ///
        " __hddid_estimator_payload__ ")
    local _hddid_methodscan_lc = ///
        regexr(`"`_hddid_methodscan_lc'"', ///
        "(^|[ ,])(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*method[ ]*[(][^)]*[)]", ///
        " __hddid_alias_payload__ ")
    local _hddid_methodscan_lc = ///
        regexr(`"`_hddid_methodscan_lc'"', ///
        "(^|[ ,])(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][^)]*[)][ ]*method[ ]*[(][^)]*[)]", ///
        " __hddid_alias_payload__ ")
    local _hddid_methodscan_lc = ///
        regexr(`"`_hddid_methodscan_lc'"', ///
        "(^|[ ,])(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(]?[^ ,]+[)]?[ ]*method[ ]*=[ ]*[^ ,]*", ///
        " __hddid_alias_payload__ ")

    local _hddid_match = regexm(`"`_hddid_methodscan_lc'"', ///
        "(^|[ ,])(method[ ]*=[ ]*[^ ,]*)([ ,]|$)")
    if `_hddid_match' {
        local _hddid_method = strtrim(regexs(2))
        local _hddid_method_pos = strpos(`"`_hddid_opts_raw_lc'"', ///
            `"`_hddid_method'"')
        if `_hddid_method_pos' > 0 {
            local _hddid_method = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_method_pos', length(`"`_hddid_method'"'))
        }
        return local invalid "1"
        return local method `"`_hddid_method'"'
        exit
    }

    local _hddid_match = regexm(`"`_hddid_methodscan_lc'"', ///
        "(^|[ ,])(method[ ]*[(][ ]*[^)]*[)][^ ,][^ ,]*)")
    if `_hddid_match' {
        local _hddid_method = strtrim(regexs(2))
        local _hddid_method_pos = strpos(`"`_hddid_opts_raw_lc'"', ///
            `"`_hddid_method'"')
        if `_hddid_method_pos' > 0 {
            local _hddid_method = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_method_pos', length(`"`_hddid_method'"'))
        }
        return local invalid "1"
        return local method `"`_hddid_method'"'
        exit
    }

    local _hddid_method_scan `"`_hddid_methodscan_lc'"'
    local _hddid_method_count 0
    local _hddid_method_raw ""
    while regexm(`"`_hddid_method_scan'"', ///
        "(^|[ ,])(method[ ]*[(][ ]*([^)]*)[ ]*[)])") {
        local _hddid_method_raw = strtrim(regexs(2))
        local _hddid_method_raw_pos = strpos(`"`_hddid_opts_raw_lc'"', ///
            lower(`"`_hddid_method_raw'"'))
        if `_hddid_method_raw_pos' > 0 {
            local _hddid_method_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_method_raw_pos', length(`"`_hddid_method_raw'"'))
        }
        local _hddid_method = strtrim(regexs(3))
        if strlen(`"`_hddid_method'"') >= 2 {
            if ((substr(`"`_hddid_method'"', 1, 1) == char(34) & ///
                substr(`"`_hddid_method'"', -1, 1) == char(34)) | ///
                (substr(`"`_hddid_method'"', 1, 1) == char(39) & ///
                substr(`"`_hddid_method'"', -1, 1) == char(39))) {
                local _hddid_method = substr(`"`_hddid_method'"', 2, ///
                    strlen(`"`_hddid_method'"') - 2)
            }
        }
        local _hddid_method = strproper(strtrim(`"`_hddid_method'"'))
        if !inlist(`"`_hddid_method'"', "Pol", "Tri") {
            return local invalid "1"
            return local method `"`_hddid_method'"'
            exit
        }
        local ++_hddid_method_count
        if `_hddid_method_count' > 1 {
            return local invalid "1"
            return local duplicate "1"
            return local method `"method(`_hddid_method')"'
            exit
        }
        local _hddid_method_scan = regexr(`"`_hddid_method_scan'"', ///
            "(^|[ ,])(method[ ]*[(][ ]*([^)]*)[ ]*[)])", "")
    }
    if `_hddid_method_count' == 1 & `"`_hddid_method_raw'"' != "" {
        return local raw `"`_hddid_method_raw'"'
    }
end

program define _hddid_postest_parse_estopt, rclass
    syntax , OPTSRAW(string asis)

    return clear
    local _hddid_opts_raw `optsraw'
    // Keep postestimation estimator-style guidance self-contained so these
    // stubs do not reload parser helpers from a shadow hddid.ado bundle.
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(92) + char(34), char(34), .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(92) + char(39), char(39), .)
    // Stata treats tabs/newlines as legal whitespace in command input.
    // Normalize them here so unsupported postestimation guidance classifies
    // estimator-family misuse independently of the caller's whitespace choice.
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(9), " ", .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(10), " ", .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(13), " ", .)
    local _hddid_opts_raw_orig = ///
        strtrim(subinstr(`"`_hddid_opts_raw'"', ",", " ", .))
    local _hddid_opts_raw = lower(`"`_hddid_opts_raw_orig'"')
    // Preserve leading bare single-quoted estimator-style tokens before the
    // alias-assignment regexes below. Those later regexm() calls are meant for
    // ra=/ipw=/aipw= spellings; letting a bare leading token like 'ra'
    // continue that far can leak parser-level unknown function() instead of
    // the public fixed-AIPW guidance.
    local _hddid_match = regexm(lower(`"`_hddid_opts_raw_orig'"'), ///
        "(^|[ ])(('(r|ra|i|ip|ipw|a|ai|aip|aipw)'))([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(4)))
        if inlist(`"`_hddid_est_lc'"', "r", "ra") {
            return local canonical "ra"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
    }
    // Preserve empty quoted estimator payloads before collapsing doubled
    // quotes; otherwise estimator=('') / estimator=("") is mis-echoed as the
    // different malformed token estimator=().
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
    // Empty quoted alias payloads are malformed alias assignments in their
    // own right. Preserve the exact raw token before quote-stripping or the
    // generic alias parser can collapse ra="" to ra= or swallow later
    // method()/q()/display options into the same echoed token.
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
    // method() text inside alias assignments is part of the malformed alias
    // token itself. Catch it before quote-stripping and later alias-follow
    // trimming, otherwise spaced or glued forms like ra = method(Pol),
    // ra=method(Pol), or quoted aipw=("ipw")method(Pol) lose the exact
    // public raw echo.
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*method[ ]*[(][^)]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_orig'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][^)]*[)][ ]*method[ ]*[(][^)]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_first `"`_hddid_raw'"'
        local _hddid_space = strpos(`"`_hddid_first'"', " ")
        if `_hddid_space' > 0 {
            local _hddid_first = substr(`"`_hddid_first'"', 1, `_hddid_space' - 1)
        }
        if strpos(`"`_hddid_first'"', char(34)) > 0 | ///
            strpos(`"`_hddid_first'"', char(39)) > 0 {
            return local invalid "1"
            return local raw `"`_hddid_first'"'
            return local form "assignment"
            exit
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_opts_raw_quoted `"`_hddid_opts_raw'"'
    local _hddid_opts_raw_quoted_orig `"`_hddid_opts_raw_orig'"'
    local _hddid_opts_raw_quoted = ///
        subinstr(`"`_hddid_opts_raw_quoted'"', ///
        char(34) + char(34), char(34), .)
    local _hddid_opts_raw_quoted = ///
        subinstr(`"`_hddid_opts_raw_quoted'"', ///
        char(39) + char(39), char(39), .)
    // Canonical quoted parenthesized alias payloads followed by a real
    // method() token should keep the same alias-head stub guidance as the
    // already-fixed noncanonical quoted path, with method() left outside the
    // offending estimator-style echo.
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
    // Preserve exact raw echoes for quoted parenthesized alias assignments
    // before later quote-stripping. Otherwise malformed alias switches such as
    // ra=("ipw") or aipw=('ipw') are rewritten to de-quoted alias tokens in
    // public guidance even though the user supplied quoted parenthesized text.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*["][^"]*["][ ]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        local _hddid_tail = ""
        if `_hddid_raw_pos' > 0 {
            local _hddid_tail = strtrim(substr( ///
                `"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos' + length(`"`_hddid_raw'"'), .))
        }
        if !regexm(lower(`"`_hddid_tail'"'), "^method[ ]*[(]") {
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
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    // A quoted parenthesized alias token is already malformed by itself.
    // If a real later method(Tri)/method(Pol) follows, keep that later option
    // outside the offending raw echo instead of swallowing it into the alias.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*["]([^"]*)["][ ]*[)])[ ]+(method[ ]*[(][^)]*[)])"')
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
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*'[^']*'[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        local _hddid_tail = ""
        if `_hddid_raw_pos' > 0 {
            local _hddid_tail = strtrim(substr( ///
                `"`_hddid_opts_raw_quoted_orig'"', ///
                `_hddid_raw_pos' + length(`"`_hddid_raw'"'), .))
        }
        if !regexm(lower(`"`_hddid_tail'"'), "^method[ ]*[(]") {
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
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*'([^']*)'[ ]*[)])[ ]+(method[ ]*[(][^)]*[)])")
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
    // Preserve exact raw echoes for quoted nonparenthesized alias assignments
    // before later quote-stripping. Otherwise ra='ipw' or aipw="ra" is
    // rewritten to de-quoted alias text in public postest guidance even
    // though the caller typed quoted malformed estimator-family input.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*["]([^"]*)["])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(4)))
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
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*'([^']*)')([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(4)))
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
        `"(^|[ ])estimator[ ]*=[ ]*["]([^"]*)["]([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(0))
        local _hddid_est_lc = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), `"`_hddid_raw'"')
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
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])estimator[ ]*=[ ]*'([^']*)'([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(0))
        local _hddid_est_lc = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), `"`_hddid_raw'"')
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
    // Keep exact raw echoes for quoted bare estimator-family tokens when the
    // next syntax fragment is a real qualifier boundary rather than part of
    // the estimator token itself. Otherwise `"ra" if 1' or `summarize "ipw"
    // if 1' is rewritten to de-quoted ra/ipw before postestimation guidance.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])(["](r|ra|i|ip|ipw|a|ai|aip|aipw)["])([ ]+(if|in)([ ]|$)|[ ]*$)"')
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
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])('((r|ra|i|ip|ipw|a|ai|aip|aipw))')([ ]+(if|in)([ ]|$)|[ ]*$)")
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
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
    }
    // A quoted parenthesized bare token like (`"ra"') is the same malformed
    // estimator-family switch as bare `ra'/`ipw'. One redundant outer
    // parenthesis layer, e.g. (("ra")) or ((ra)), does not change that
    // meaning. Classify these before later quote stripping so both bare and
    // if/in forms preserve the exact raw token and reach the same single
    // stub-guidance path.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])(([(][ ]*[(][ ]*["](r|ra|i|ip|ipw|a|ai|aip|aipw)["][ ]*[)][ ]*[)]))([ ]|$)"')
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
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])(([(][ ]*[(][ ]*'((r|ra|i|ip|ipw|a|ai|aip|aipw))'[ ]*[)][ ]*[)]))([ ]|$)")
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
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
    }
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
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])(([(][ ]*'((r|ra|i|ip|ipw|a|ai|aip|aipw))'[ ]*[)]))([ ]|$)")
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
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
    }
    // Keep quoted nonparenthesized estimator assignments with glued suffix text
    // intact before quote-stripping. Otherwise estimator="ra"foo or
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
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][ ]*["]([^"]*)["][ ]*[)])([ ]|$)"')
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = strtrim(regexs(3))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), `"`_hddid_raw'"')
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
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*'([^']*)'[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = strtrim(regexs(3))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_quoted_orig'"'), `"`_hddid_raw'"')
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
    // Keep quoted parenthesized estimator assignments with glued suffix text
    // intact before quote-stripping. Otherwise estimator=('ra')foo or
    // estimator=("ipw")foo is rewritten to de-quoted estimator=(ra)foo /
    // estimator=(ipw)foo in the public invalid-line echo.
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])(estimator[ ]*=[ ]*[(][ ]*["][^"]*["][ ]*[)][^ ]+)([ ]|$)"')
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
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*'[^']*'[ ]*[)][^ ]+)([ ]|$)")
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
    // Illegal short t()/tr() followers are not separate legal treat()
    // options. Preserve the whole malformed estimator token before the
    // canonical estimator=(ipw) branch below can clip it to estimator=(...).
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*[^)]*[)][ ]+(t|tr)[ ]*[(][^)]*[)])([ ]|$)")
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
        return local form "assignment_parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        "(^|[ ])estimator[ ]*=[ ]*[(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)]([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(0))
        local _hddid_est_lc = strtrim(regexs(2))
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
    }
    // Illegal short t()/tr() followers are not separate legal treat()
    // options. Keep the full malformed estimator token intact rather than
    // letting the bare estimator=(...) branch above clip the public raw echo.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*[^)]*[)][ ]+(t|tr)[ ]*[(][^)]*[)])([ ]|$)")
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
        return local form "assignment_parenthesized"
        exit
    }
    // Let quote-aware estimator branches classify estimator="ipw" q(2) or
    // estimator='ipw' method(Tri) first. But an empty estimator= followed by
    // legal postestimation syntax like if/in or a weight clause must still
    // fail on estimator= itself rather than swallowing that later syntax into
    // the public raw echo.
    local _hddid_estopt_syntax_follow ///
        "((if|in)($|[ ])|([[][^]]*[]]))"
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
    local _hddid_match = regexm(`"`_hddid_opts_raw_quoted'"', ///
        `"(^|[ ])((["](r|ra|i|ip|ipw|a|ai|aip|aipw)["]))([ ]|$)"')
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
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
    }
    local _hddid_match = regexm(lower(`"`_hddid_opts_raw_quoted'"'), ///
        "(^|[ ])(('(r|ra|i|ip|ipw|a|ai|aip|aipw)'))([ ]|$)")
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
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "i", "ip", "ipw") {
            return local canonical "ipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
        if inlist(`"`_hddid_est_lc'"', "a", "ai", "aip", "aipw") {
            return local canonical "aipw"
            return local raw `"`_hddid_raw'"'
            return local form "bare"
            exit
        }
    }
    // Bare postcomma parenthesized estimator-family tokens like `(ra)' are
    // still malformed attempts to switch away from the paper's fixed AIPW
    // path. One redundant outer parenthesis layer, e.g. `((ra))', does not
    // change that. Classify these before the generic parenthesized-invalid
    // branches below so postestimation can show one consistent stub guidance
    // path.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(([(][ ]*[(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)][ ]*[)]))([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(4)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical `"`_hddid_est_lc'"'
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])([(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical `"`_hddid_est_lc'"'
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
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
            lower(`"`_hddid_opts_raw_orig'"'), `"`_hddid_raw'"')
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
        "(^|[ ])estimator[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)]([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(0))
        local _hddid_est_lc = strtrim(regexs(2))
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
    // token itself. The next legitimate postestimation option, qualifier, or
    // weight clause, including legal abbreviations such as alp(), is not an
    // estimator payload and must not be swallowed into the raw echo.
    local _hddid_estopt_lparen_follow ///
        "(c|cf|cfo|cfor|cform|cforma|cformat|ci|cit|city|cityp|citype|p|pf|pfo|pfor|pform|pforma|pformat|s|sf|sfo|sfor|sform|sforma|sformat|fvwr|fvwra|fvwrap|fvwrapo|fvwrapon|tre|trea|treat|x|z|z0|k|l|le|lev|leve|level|m|me|met|meth|metho|method|q|alp|alph|alpha|pi|pih|piha|pihat|phi1|phi1h|phi1ha|phi1hat|phi0|phi0h|phi0ha|phi0hat|seed|sep|sepa|separ|separa|separat|separato|separator|depn|depna|depnam|depname|nb|nbo|nboo|nboot)[ ]*[(]"
    local _hddid_estopt_bare_follow ///
        "(ab|abb|abbr|abbre|abbrev|allb|allba|allbas|allbase|allbasel|allbasele|allbaselev|allbaseleve|allbaselevel|allbaselevels|b|be|bet|beta|basel|basele|baselev|baseleve|baselevel|baselevels|cns|cnsr|cnsre|cnsrep|cnsrepo|cnsrepor|cnsreport|cod|codi|codin|coding|coefl|coefle|coefleg|coeflege|coeflegen|coeflegend|com|comp|compa|compar|compare|e|ef|efo|efor|eform|empty|emptyc|emptyce|emptycel|emptycell|emptycells|f|fi|fir|firs|first|fu|ful|full|fullc|fullcn|fullcns|fullcnsr|fullcnsre|fullcnsrep|fullcnsrepo|fullcnsrepor|fullcnsreport|fvl|fvla|fvlab|fvlabe|fvlabel|ls|lst|lstr|lstre|lstret|lstretch|ma|mar|mark|markd|markdo|markdow|markdown|noa|noab|noabb|noabbr|noabbre|noabbrev|not|nota|notab|notabl|notable|noempty|noemptyc|noemptyce|noemptycel|noemptycell|noemptycells|noo|noom|noomi|noomit|noomitt|noomitte|noomitted|nop|nopv|nopva|nopval|nopvalu|nopvalue|nopvalues|o|om|omi|omit|omitt|omitte|omitted|pl|plu|plus|se|sel|sele|seleg|selege|selegen|selegend|noci|nofv|nofvl|nofvla|nofvlab|nofvlabe|nofvlabel|noh|nohe|nohea|nohead|noheade|noheader|nols|nolst|nolstr|nolstre|nolstret|nolstretc|nolstretch|nof|nofi|nofir|nofirs|nofirst|ver|vers|versu|versus|verb|verbo|verbos|verbose|vsq|vsqu|vsqui|vsquis|vsquish)($|[ ])"
    local _hddid_estopt_syntax_follow ///
        "((if|in)($|[ ])|([[][^]]*[]]))"
    // An empty estimator= assignment must fail on the malformed estimator
    // token itself. The next legitimate option-looking token, qualifier, or
    // weight clause, including Stata's legal abbreviations such as alp(), is
    // not an estimator payload and must not be swallowed into the raw echo.
    // But estimator= method(<bad>) is different: the nested method() text is
    // itself malformed estimator RHS content once the payload leaves the
    // Pol/Tri sieve-basis domain, so the public estimator echo should keep
    // that whole RHS token.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*method[ ]*[(][ ]*([^)]*)[ ]*[)])([ ]|$)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_est_rhs_method = strproper(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if !inlist(`"`_hddid_est_rhs_method'"', "Pol", "Tri") {
            return local invalid "1"
            return local raw `"`_hddid_raw'"'
            return local form "assignment"
            exit
        }
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=)[ ]*((`_hddid_estopt_lparen_follow'))")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_payload = lower(strtrim(regexs(4)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if regexm(`"`_hddid_raw'"', "=[ ]+") & ///
            regexm(`"`_hddid_payload'"', "^[a-z_][a-z0-9_]*[ ]*[(]") {
            local _hddid_eq = strpos(`"`_hddid_raw'"', "=")
            if `_hddid_eq' > 0 {
                local _hddid_raw = strtrim(substr(`"`_hddid_raw'"', 1, `_hddid_eq'))
            }
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
    // even when a real postestimation option follows. Otherwise the generic
    // multi-token assignment branch swallows later method()/alpha()/... tokens
    // into the public estimator echo, even though they are separate options.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)])[ ]+((`_hddid_estopt_lparen_follow')|(`_hddid_estopt_bare_follow'))")
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
        return local form "assignment_parenthesized"
        exit
    }
    // Illegal short t()/tr() followers are not separate legal treat()
    // options. Keep the full malformed estimator token intact rather than
    // clipping the public raw echo back to estimator=(...) alone.
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])(estimator[ ]*=[ ]*[(][ ]*[^)]*[)][ ]+(t|tr)[ ]*[(][^)]*[)])([ ]|$)")
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
        return local form "assignment_parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])estimator[ ]*=[ ]*([^ ]+)")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(0))
        local _hddid_est_raw = strtrim(regexs(2))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), `"`_hddid_raw'"')
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        if strpos(`"`_hddid_est_raw'"', "(") > 0 | ///
            strpos(`"`_hddid_est_raw'"', ")") > 0 {
            if regexm(`"`_hddid_raw'"', "=[ ]+") & ///
                regexm(lower(`"`_hddid_est_raw'"'), "^[a-z_][a-z0-9_]*[ ]*[(]") {
                local _hddid_eq = strpos(`"`_hddid_raw'"', "=")
                if `_hddid_eq' > 0 {
                    local _hddid_raw = strtrim(substr(`"`_hddid_raw'"', 1, `_hddid_eq'))
                }
            }
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
        local _hddid_raw = subinstr(strtrim(regexs(2)), " ", "", .)
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[(][ ]*[^ )][^)]*)$")
    if `_hddid_match' {
        local _hddid_raw = subinstr(strtrim(regexs(2)), " ", "", .)
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
        "(^|[ ])((r|ra)[ ]*[(][^)]*[)]?)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), `"`_hddid_raw'"')
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
        "(^|[ ])((i|ip|ipw)[ ]*[(][^)]*[)]?)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), `"`_hddid_raw'"')
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
        "(^|[ ])((a|ai|aip|aipw)[ ]*[(][^)]*[)]?)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), `"`_hddid_raw'"')
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        return local canonical "aipw"
        return local raw `"`_hddid_raw'"'
        return local form "parenthesized"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*([^ ]+))($|[ ])")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        local _hddid_alias_lc = lower(strtrim(regexs(3)))
        local _hddid_raw_pos = strpos( ///
            lower(`"`_hddid_opts_raw_orig'"'), lower(`"`_hddid_raw'"'))
        if `_hddid_raw_pos' > 0 {
            local _hddid_raw = substr(`"`_hddid_opts_raw_orig'"', ///
                `_hddid_raw_pos', length(`"`_hddid_raw'"'))
        }
        local _hddid_payload = lower(strtrim(regexs(4)))
        if regexm(`"`_hddid_payload'"', "^[(][ ]*([^)]*)[ ]*[)]$") {
            local _hddid_inner_payload = lower(strtrim(regexs(1)))
            if !inlist(`"`_hddid_inner_payload'"', ///
                "r", "ra", "i", "ip", "ipw", "a", "ai", "aip", "aipw") {
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
        }
        // Postestimation alias assignments should stop at ra=/ipw=/aipw=
        // when the next token is really a separate legal option head,
        // abbreviation, or Stata syntax fragment.
        local _hddid_alias_lparen_follow ///
            "^(c|cf|cfo|cfor|cform|cforma|cformat|ci|cit|city|cityp|citype|p|pf|pfo|pfor|pform|pforma|pformat|s|sf|sfo|sfor|sform|sforma|sformat|fvwr|fvwra|fvwrap|fvwrapo|fvwrapon|tre|trea|treat|x|z|z0|k|l|le|lev|leve|level|m|me|met|meth|metho|method|q|alp|alph|alpha|pi|pih|piha|pihat|phi1|phi1h|phi1ha|phi1hat|phi0|phi0h|phi0ha|phi0hat|seed|sep|sepa|separ|separa|separat|separato|separator|depn|depna|depnam|depname|nb|nbo|nboo|nboot)[ ]*[(]"
        local _hddid_alias_bare_follow ///
            "^(ab|abb|abbr|abbre|abbrev|allb|allba|allbas|allbase|allbasel|allbasele|allbaselev|allbaseleve|allbaselevel|allbaselevels|b|be|bet|beta|basel|basele|baselev|baseleve|baselevel|baselevels|cns|cnsr|cnsre|cnsrep|cnsrepo|cnsrepor|cnsreport|cod|codi|codin|coding|coefl|coefle|coefleg|coeflege|coeflegen|coeflegend|com|comp|compa|compar|compare|e|ef|efo|efor|eform|empty|emptyc|emptyce|emptycel|emptycell|emptycells|f|fi|fir|firs|first|fu|ful|full|fullc|fullcn|fullcns|fullcnsr|fullcnsre|fullcnsrep|fullcnsrepo|fullcnsrepor|fullcnsreport|fvl|fvla|fvlab|fvlabe|fvlabel|ls|lst|lstr|lstre|lstret|lstretch|ma|mar|mark|markd|markdo|markdow|markdown|noa|noab|noabb|noabbr|noabbre|noabbrev|not|nota|notab|notabl|notable|noempty|noemptyc|noemptyce|noemptycel|noemptycell|noemptycells|noo|noom|noomi|noomit|noomitt|noomitte|noomitted|nop|nopv|nopva|nopval|nopvalu|nopvalue|nopvalues|o|om|omi|omit|omitt|omitte|omitted|pl|plu|plus|se|sel|sele|seleg|selege|selegen|selegend|noci|nofv|nofvl|nofvla|nofvlab|nofvlabe|nofvlabel|noh|nohe|nohea|nohead|noheade|noheader|nols|nolst|nolstr|nolstre|nolstret|nolstretc|nolstretch|nof|nofi|nofir|nofirs|nofirst|ver|vers|versu|versus|verb|verbo|verbos|verbose|vsq|vsqu|vsqui|vsquis|vsquish)($|[ ])"
        local _hddid_alias_syntax_follow ///
            "^((if|in)($|[ ])|([[][^]]*[]]))"
        if regexm(`"`_hddid_raw'"', "=[ ]+") & ( ///
            regexm(`"`_hddid_payload'"', ///
            `"`_hddid_alias_lparen_follow'"') | ///
            regexm(`"`_hddid_payload'"', `"`_hddid_alias_bare_follow'"') | ///
            regexm(`"`_hddid_payload'"', "^[a-z_][a-z0-9_]*[ ]*[(]") | ///
            regexm(`"`_hddid_payload'"', `"`_hddid_alias_syntax_follow'"')) {
            local _hddid_eq = strpos(`"`_hddid_raw'"', "=")
            if `_hddid_eq' > 0 {
                local _hddid_raw = strtrim(substr(`"`_hddid_raw'"', 1, `_hddid_eq'))
            }
        }
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "assignment"
        exit
    }
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra)[ ]*=)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
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
        "(^|[ ])((i|ip|ipw)[ ]*=)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
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
        "(^|[ ])((a|ai|aip|aipw)[ ]*=)")
    if `_hddid_match' {
        local _hddid_raw = regexs(2)
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
        "(^|[ ])((r|ra))([ ]|$)")
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
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((i|ip|ipw))([ ]|$)")
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
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((a|ai|aip|aipw))([ ]|$)")
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
    local _hddid_match = regexm(`"`_hddid_opts_raw'"', ///
        "(^|[ ])((r|ra|i|ip|ipw|a|ai|aip|aipw)[^ a-z0-9_(=][^ ]*)($|[ ])")
    if `_hddid_match' {
        local _hddid_raw = strtrim(regexs(2))
        return local invalid "1"
        return local raw `"`_hddid_raw'"'
        return local form "bare"
        exit
    }
end

program define _hddid_postest_show_invalid
    syntax , RAW(string asis)

    di as error "{bf:hddid}: invalid estimator-style option value: " ///
        as text `"`raw'"'
    di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
    di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
    di as error "  Use {bf:method(Pol)} or {bf:method(Tri)} to choose the sieve basis family"
end

capture program drop _hddid_postest_parse
program define _hddid_postest_parse, rclass
    syntax , RAW(string asis)

    return clear

    local _hddid_raw = strtrim(`"`raw'"')
    if `"`_hddid_raw'"' == "" {
        exit
    }

    quietly _hddid_postest_parse_estopt, optsraw(`"`_hddid_raw'"')
    if `"`r(invalid)'"' == "1" | `"`r(canonical)'"' != "" {
        return local invalid `"`r(invalid)'"'
        return local canonical `"`r(canonical)'"'
        return local raw `"`r(raw)'"'
        return local form `"`r(form)'"'
    }
end

capture program drop _hddid_trailing_esttoken
program define _hddid_trailing_esttoken, rclass
    syntax , PRECOMMA(string asis)

    return clear
    local _hddid_last ""
    local _hddid_precomma_raw = strtrim(`"`precomma'"')
    local _hddid_dq = char(34)
    if `"`_hddid_precomma_raw'"' != "" {
        local _hddid_lastchar = substr(`"`_hddid_precomma_raw'"', -1, 1)
        if `"`_hddid_lastchar'"' == `"`_hddid_dq'"' {
            local _hddid_before_last = ///
                substr(`"`_hddid_precomma_raw'"', 1, ///
                length(`"`_hddid_precomma_raw'"') - 1)
            local _hddid_quote_pos = ///
                strrpos(`"`_hddid_before_last'"', `"`_hddid_lastchar'"')
            if `_hddid_quote_pos' > 0 {
                local _hddid_prefix_raw = ///
                    substr(`"`_hddid_precomma_raw'"', 1, `_hddid_quote_pos' - 1)
                if strtrim(`"`_hddid_prefix_raw'"') == "" | ///
                    substr(`"`_hddid_prefix_raw'"', -1, 1) == " " {
                    local _hddid_last = ///
                        substr(`"`_hddid_precomma_raw'"', `_hddid_quote_pos', .)
                }
            }
        }
    }
    if `"`_hddid_last'"' == "" {
        tokenize `precomma'
        local _hddid_i 1
        while `"``_hddid_i''"' != "" {
            local _hddid_last `"``_hddid_i''"'
            local ++_hddid_i
        }
    }

    local _hddid_probe_raw = strtrim(`"`_hddid_last'"')
    local _hddid_probe_lc = lower(strtrim(`"`_hddid_probe_raw'"'))
    local _hddid_probe_key `"`_hddid_probe_lc'"'
    if regexm(`"`_hddid_probe_key'"', "^[(].*[)]$") {
        local _hddid_probe_key = strtrim(substr( ///
            `"`_hddid_probe_key'"', 2, length(`"`_hddid_probe_key'"') - 2))
    }
    local _hddid_probe_key = ///
        subinstr(`"`_hddid_probe_key'"', char(34), "", .)
    local _hddid_probe_key = ///
        subinstr(`"`_hddid_probe_key'"', char(39), "", .)
    local _hddid_probe_key = strtrim(`"`_hddid_probe_key'"')
    if inlist(`"`_hddid_probe_key'"', "r", "ra") {
        return local canonical "ra"
        return local raw `"`_hddid_probe_raw'"'
    }
    else if inlist(`"`_hddid_probe_key'"', "i", "ip", "ipw") {
        return local canonical "ipw"
        return local raw `"`_hddid_probe_raw'"'
    }
    else if inlist(`"`_hddid_probe_key'"', "a", "ai", "aip", "aipw") {
        return local canonical "aipw"
        return local raw `"`_hddid_probe_raw'"'
    }
end

capture program drop _hddid_estat_stub_prescan
program define _hddid_estat_stub_prescan, rclass
    syntax , CMDLINE(string asis)

    return clear
    local 0 `cmdline'

    local _hddid_estopt_invalid ""
    local _hddid_estopt_canonical ""
    local _hddid_estopt_raw ""
    local _hddid_skip_method_prescan 0
    quietly _hddid_postest_parse_estopt, optsraw(`"`0'"')
    if `"`r(canonical)'"' != "" {
        local _hddid_estopt_invalid `"`r(invalid)'"'
        local _hddid_estopt_canonical `"`r(canonical)'"'
        local _hddid_estopt_raw `"`r(raw)'"'
        local _hddid_skip_method_prescan 1
    }

    if !`_hddid_skip_method_prescan' {
        quietly _hddid_postest_parse_methodopt, optsraw(`"`0'"')
    }
    if !`_hddid_skip_method_prescan' & `"`r(invalid)'"' == "1" {
        local _hddid_bad_method `"`r(method)'"'
        local _hddid_bad_method_raw `"`r(method)'"'
        local _hddid_bad_method_probe `"`_hddid_bad_method_raw'"'
        local _hddid_pst_method_note 0
        local _hddid_bad_method_probe = ///
            subinstr(`"`_hddid_bad_method_probe'"', char(34), "", .)
        local _hddid_bad_method_probe = ///
            subinstr(`"`_hddid_bad_method_probe'"', char(39), "", .)
        local _hddid_bad_method_assignok 0
        if `"`r(duplicate)'"' == "1" {
            di as error "{bf:hddid}: method() may be specified at most once, got {bf:`r(method)'}"
            di as error "  Reason: {bf:method()} selects one sieve basis family for the stored HDDID surface, so duplicate {bf:method()} tokens are malformed"
        }
        else {
            if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                "^method[ ]*=[ ]*[(][ ]*([^)]*)[ ]*[)]$") {
                local _hddid_bad_method_disp = ///
                    strproper(strtrim(regexs(1)))
                local _hddid_bad_method_assignok 1
            }
            else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                "^method[ ]*=[ ]*$") {
                local _hddid_bad_method_assignok 1
            }
            else if regexm(lower(`"`_hddid_bad_method_probe'"'), ///
                "^method[ ]*=[ ]*([^ ,]+)$") {
                local _hddid_bad_method_disp = ///
                    strproper(strtrim(regexs(1)))
                local _hddid_bad_method_assignok 1
            }
            if `_hddid_bad_method_assignok' {
                di as error "{bf:hddid}: invalid method() syntax"
                if `"`_hddid_bad_method_raw'"' != "" {
                    di as error "  Offending method() input: " as text `"`_hddid_bad_method_raw'"'
                }
                di as error "  Reason: {bf:method()} uses option syntax; write {bf:method(Pol)} or {bf:method(Tri)}, not assignment-style {bf:method=(...)}"
            }
            else {
                di as error "{bf:hddid}: method() must be {bf:Pol} or {bf:Tri}, got {bf:`r(method)'}"
                di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
                local _hddid_pst_method_note 1
            }
        }
        di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
        if `_hddid_pst_method_note' {
            di as error "  Reason: {bf:method()} is an estimation option that only picks the {bf:Pol}/{bf:Tri} sieve basis; it is not a supported postestimation token."
        }
        di as error "  Use bare {bf:hddid_estat}; the stored sieve basis is already published in {bf:e(method)}."
        exit 198
    }
    if !`_hddid_skip_method_prescan' & `"`r(raw)'"' != "" {
        di as error "{bf:hddid}: estat is not supported."
        di as error "  Reason: hddid publishes parametric and nonparametric inference objects, but no unified estat contract is defined."
        di as error "  Offending method() input: " as text `"`r(raw)'"'
        di as error "  Reason: {bf:method()} is an estimation option that only picks the {bf:Pol}/{bf:Tri} sieve basis; it is not a supported postestimation token."
        di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
        di as error "  Use bare {bf:hddid_estat}; the stored sieve basis is already published in {bf:e(method)}."
        exit 198
    }

    local _hddid_leading_ifin 0
    local _hddid_subcmd_ifin 0
    local _hddid_esttoken_canonical ""
    local _hddid_esttoken_raw ""
    local _hddid_raw0 `"`0'"'
    local _hddid_raw0_comma = strpos(`"`_hddid_raw0'"', ",")
    local _hddid_raw0_postcomma ""
    if `_hddid_raw0_comma' > 0 {
        local _hddid_raw0_postcomma = ///
            substr(`"`_hddid_raw0'"', `_hddid_raw0_comma' + 1, .)
        if strtrim(`"`_hddid_raw0_postcomma'"') == "" {
            di as error "{bf:hddid}: estat does not accept a trailing comma"
            di as error "  Reason: the unsupported {bf:hddid_estat} stub publishes no options contract, so a lone comma is malformed call syntax"
            di as error "  Use bare {bf:hddid_estat} or supply a nonempty estimator-style token only when you want that misuse echoed back"
            exit 198
        }
    }
    local _hddid_raw0_postcomma_probe = strtrim(`"`_hddid_raw0_postcomma'"')
    if `"`_hddid_raw0_postcomma_probe'"' != "" & ///
        strpos(`"`_hddid_raw0_postcomma_probe'"', " ") == 0 {
        local _hddid_postcomma_quote = substr(`"`_hddid_raw0_postcomma_probe'"', 1, 1)
        if (`"`_hddid_postcomma_quote'"' == `"""' | ///
            `"`_hddid_postcomma_quote'"' == "'" ) & ///
            substr(`"`_hddid_raw0_postcomma_probe'"', -1, 1) == ///
            `"`_hddid_postcomma_quote'"' & ///
            length(`"`_hddid_raw0_postcomma_probe'"') >= 2 {
            local _hddid_postcomma_inner = lower(strtrim(substr( ///
                `"`_hddid_raw0_postcomma_probe'"', 2, ///
                length(`"`_hddid_raw0_postcomma_probe'"') - 2)))
            if inlist(`"`_hddid_postcomma_inner'"', "r", "ra") {
                local _hddid_estopt_canonical "ra"
                local _hddid_estopt_raw `"`_hddid_raw0_postcomma_probe'"'
            }
            else if inlist(`"`_hddid_postcomma_inner'"', "i", "ip", "ipw") {
                local _hddid_estopt_canonical "ipw"
                local _hddid_estopt_raw `"`_hddid_raw0_postcomma_probe'"'
            }
            else if inlist(`"`_hddid_postcomma_inner'"', "a", "ai", "aip", "aipw") {
                local _hddid_estopt_canonical "aipw"
                local _hddid_estopt_raw `"`_hddid_raw0_postcomma_probe'"'
            }
        }
    }
    local _hddid_raw0_probe `"`_hddid_raw0'"'
    if `_hddid_raw0_comma' > 0 {
        local _hddid_raw0_probe = ///
            substr(`"`_hddid_raw0'"', 1, `_hddid_raw0_comma' - 1)
    }
    local _hddid_raw0_probe = ///
        subinstr(`"`_hddid_raw0_probe'"', char(9), " ", .)
    local _hddid_raw0_probe = ///
        subinstr(`"`_hddid_raw0_probe'"', char(10), " ", .)
    local _hddid_raw0_probe = ///
        subinstr(`"`_hddid_raw0_probe'"', char(13), " ", .)
    local _hddid_raw0_probe = strtrim(`"`_hddid_raw0_probe'"')
    if `"`_hddid_raw0_probe'"' != "" & `"`_hddid_estopt_raw'"' == "" {
        local _hddid_probe_raw ""
        local _hddid_probe_lc ""
        local _hddid_dq = char(34)
        local _hddid_sq = char(39)
        local _hddid_lastchar = substr(`"`_hddid_raw0_probe'"', -1, 1)
        if `"`_hddid_lastchar'"' == `"`_hddid_dq'"' | ///
            `"`_hddid_lastchar'"' == `"`_hddid_sq'"' {
            local _hddid_before_last = ///
                substr(`"`_hddid_raw0_probe'"', 1, ///
                length(`"`_hddid_raw0_probe'"') - 1)
            local _hddid_quote_pos = ///
                strrpos(`"`_hddid_before_last'"', `"`_hddid_lastchar'"')
            if `_hddid_quote_pos' > 0 {
                local _hddid_prefix_raw = ///
                    substr(`"`_hddid_raw0_probe'"', 1, ///
                    `_hddid_quote_pos' - 1)
                if strtrim(`"`_hddid_prefix_raw'"') == "" | ///
                    substr(`"`_hddid_prefix_raw'"', -1, 1) == " " {
                    local _hddid_probe_raw = ///
                        substr(`"`_hddid_raw0_probe'"', `_hddid_quote_pos', .)
                    local _hddid_probe_lc = lower(strtrim(substr( ///
                        `"`_hddid_probe_raw'"', 2, ///
                        length(`"`_hddid_probe_raw'"') - 2)))
                }
            }
        }
        if inlist(`"`_hddid_probe_lc'"', "r", "ra") {
            local _hddid_estopt_canonical "ra"
            local _hddid_estopt_raw `"`_hddid_probe_raw'"'
        }
        else if inlist(`"`_hddid_probe_lc'"', "i", "ip", "ipw") {
            local _hddid_estopt_canonical "ipw"
            local _hddid_estopt_raw `"`_hddid_probe_raw'"'
        }
        else if inlist(`"`_hddid_probe_lc'"', "a", "ai", "aip", "aipw") {
            local _hddid_estopt_canonical "aipw"
            local _hddid_estopt_raw `"`_hddid_probe_raw'"'
        }
    }
    if regexm(lower(`"`_hddid_raw0_probe'"'), "^(summarize)([ ]+(if|in)([ ]|$))") {
        local _hddid_subcmd_ifin 1
    }
    if `"`_hddid_raw0_probe'"' != "" & strpos(`"`_hddid_raw0_probe'"', " ") == 0 {
        local _hddid_bare_quote = substr(`"`_hddid_raw0_probe'"', 1, 1)
        if (`"`_hddid_bare_quote'"' == `"""' | ///
            `"`_hddid_bare_quote'"' == "'" ) & ///
            substr(`"`_hddid_raw0_probe'"', -1, 1) == `"`_hddid_bare_quote'"' & ///
            length(`"`_hddid_raw0_probe'"') >= 2 {
            local _hddid_bare_inner = lower(strtrim(substr( ///
                `"`_hddid_raw0_probe'"', 2, length(`"`_hddid_raw0_probe'"') - 2)))
            if inlist(`"`_hddid_bare_inner'"', "r", "ra") {
                local _hddid_estopt_canonical "ra"
                local _hddid_estopt_raw `"`_hddid_raw0_probe'"'
            }
            else if inlist(`"`_hddid_bare_inner'"', "i", "ip", "ipw") {
                local _hddid_estopt_canonical "ipw"
                local _hddid_estopt_raw `"`_hddid_raw0_probe'"'
            }
            else if inlist(`"`_hddid_bare_inner'"', "a", "ai", "aip", "aipw") {
                local _hddid_estopt_canonical "aipw"
                local _hddid_estopt_raw `"`_hddid_raw0_probe'"'
            }
        }
    }
    if `"`_hddid_raw0_probe'"' != "" {
        if `"`_hddid_estopt_raw'"' == "" & ///
            regexm(lower(`"`_hddid_raw0_probe'"'), "^(if|in)([ ]|$)") {
            local _hddid_leading_ifin 1
            quietly _hddid_trailing_esttoken, precomma(`"`_hddid_raw0_probe'"')
            local _hddid_ifin_token_raw `"`r(raw)'"'
            local _hddid_ifin_token_canonical `"`r(canonical)'"'
            if `"`_hddid_ifin_token_raw'"' != "" {
                // Once if/in has already consumed the command head, any
                // trailing RA/IPW/AIPW-family token is estimator-style misuse,
                // even when it is bare rather than quoted/parenthesized.
                // Surface package guidance instead of generic invalid-token
                // parser fallout on qualifier-tail spellings.
                local _hddid_estopt_canonical `"`_hddid_ifin_token_canonical'"'
                local _hddid_estopt_raw `"`_hddid_ifin_token_raw'"'
            }
        }
        local _hddid_if_pos = strpos(lower(`"`_hddid_raw0_probe'"'), " if ")
        local _hddid_in_pos = strpos(lower(`"`_hddid_raw0_probe'"'), " in ")
        local _hddid_qual_pos = 0
        if `_hddid_if_pos' > 0 & (`_hddid_in_pos' == 0 | `_hddid_if_pos' < `_hddid_in_pos') {
            local _hddid_qual_pos = `_hddid_if_pos'
        }
        else if `_hddid_in_pos' > 0 {
            local _hddid_qual_pos = `_hddid_in_pos'
        }
        if `_hddid_qual_pos' > 0 {
            local _hddid_prequal = ///
                strtrim(substr(`"`_hddid_raw0_probe'"', 1, `_hddid_qual_pos' - 1))
            if `"`_hddid_prequal'"' != "" {
                local _hddid_probe_raw ""
                local _hddid_probe_lc ""
                local _hddid_dq = char(34)
                local _hddid_sq = char(39)
                local _hddid_lastchar = substr(`"`_hddid_prequal'"', -1, 1)
                if `"`_hddid_lastchar'"' == `"`_hddid_dq'"' | ///
                    `"`_hddid_lastchar'"' == `"`_hddid_sq'"' {
                    local _hddid_before_last = ///
                        substr(`"`_hddid_prequal'"', 1, length(`"`_hddid_prequal'"') - 1)
                    local _hddid_quote_pos = ///
                        strrpos(`"`_hddid_before_last'"', `"`_hddid_lastchar'"')
                    if `_hddid_quote_pos' > 0 {
                        local _hddid_prefix_raw = ///
                            substr(`"`_hddid_prequal'"', 1, `_hddid_quote_pos' - 1)
                        if strtrim(`"`_hddid_prefix_raw'"') == "" | ///
                            substr(`"`_hddid_prefix_raw'"', -1, 1) == " " {
                            local _hddid_probe_raw = ///
                                substr(`"`_hddid_prequal'"', `_hddid_quote_pos', .)
                            local _hddid_probe_lc = lower(strtrim(substr( ///
                                `"`_hddid_probe_raw'"', 2, ///
                                length(`"`_hddid_probe_raw'"') - 2)))
                        }
                    }
                }
                if `"`_hddid_probe_raw'"' == "" {
                    local _hddid_space = strrpos(`"`_hddid_prequal'"', " ")
                    if `_hddid_space' > 0 {
                        local _hddid_esttoken_raw = ///
                            strtrim(substr(`"`_hddid_prequal'"', `_hddid_space' + 1, .))
                    }
                    else {
                        local _hddid_esttoken_raw `"`_hddid_prequal'"'
                    }
                    local _hddid_esttoken_canonical = ///
                        lower(strtrim(`"`_hddid_esttoken_raw'"'))
                }
                else {
                    local _hddid_esttoken_raw `"`_hddid_probe_raw'"'
                    local _hddid_esttoken_canonical `"`_hddid_probe_lc'"'
                }
                if regexm(`"`_hddid_esttoken_canonical'"', "^[(].*[)]$") {
                    local _hddid_esttoken_canonical = ///
                        strtrim(substr(`"`_hddid_esttoken_canonical'"', 2, ///
                        length(`"`_hddid_esttoken_canonical'"') - 2))
                    local _hddid_esttoken_canonical = ///
                        subinstr(`"`_hddid_esttoken_canonical'"', char(34), "", .)
                    local _hddid_esttoken_canonical = ///
                        subinstr(`"`_hddid_esttoken_canonical'"', char(39), "", .)
                    local _hddid_esttoken_canonical = ///
                        strtrim(`"`_hddid_esttoken_canonical'"')
                }
                if inlist(`"`_hddid_esttoken_canonical'"', "r", "ra") {
                    local _hddid_esttoken_canonical "ra"
                }
                else if inlist(`"`_hddid_esttoken_canonical'"', "i", "ip", "ipw") {
                    local _hddid_esttoken_canonical "ipw"
                }
                else if inlist(`"`_hddid_esttoken_canonical'"', "a", "ai", "aip", "aipw") {
                    local _hddid_esttoken_canonical "aipw"
                }
                else {
                    local _hddid_esttoken_canonical ""
                    local _hddid_esttoken_raw ""
                }
                if `"`_hddid_esttoken_canonical'"' != "" {
                    local _hddid_estopt_canonical `"`_hddid_esttoken_canonical'"'
                    local _hddid_estopt_raw `"`_hddid_esttoken_raw'"'
                }
            }
            if `"`_hddid_estopt_raw'"' == "" {
                local _hddid_tail_raw ""
                local _hddid_tail_key ""
                local _hddid_tail_space = strrpos(`"`_hddid_raw0_probe'"', " ")
                if `_hddid_tail_space' > 0 {
                    local _hddid_tail_raw = ///
                        strtrim(substr(`"`_hddid_raw0_probe'"', ///
                        `_hddid_tail_space' + 1, .))
                }
                else {
                    local _hddid_tail_raw = strtrim(`"`_hddid_raw0_probe'"')
                }
                local _hddid_tail_key = lower(strtrim(`"`_hddid_tail_raw'"'))
                if regexm(`"`_hddid_tail_key'"', "^[(].*[)]$") {
                    local _hddid_tail_key = ///
                        strtrim(substr(`"`_hddid_tail_key'"', 2, ///
                        length(`"`_hddid_tail_key'"') - 2))
                }
                local _hddid_tail_key = ///
                    subinstr(`"`_hddid_tail_key'"', char(34), "", .)
                local _hddid_tail_key = ///
                    subinstr(`"`_hddid_tail_key'"', char(39), "", .)
                local _hddid_tail_key = strtrim(`"`_hddid_tail_key'"')
                if inlist(`"`_hddid_tail_key'"', "r", "ra") {
                    local _hddid_estopt_canonical "ra"
                    local _hddid_estopt_raw `"`_hddid_tail_raw'"'
                }
                else if inlist(`"`_hddid_tail_key'"', "i", "ip", "ipw") {
                    local _hddid_estopt_canonical "ipw"
                    local _hddid_estopt_raw `"`_hddid_tail_raw'"'
                }
                else if inlist(`"`_hddid_tail_key'"', "a", "ai", "aip", "aipw") {
                    local _hddid_estopt_canonical "aipw"
                    local _hddid_estopt_raw `"`_hddid_tail_raw'"'
                }
            }
        }
    }
    if `"`_hddid_estopt_raw'"' == "" & !`_hddid_leading_ifin' {
        capture program list _hddid_trailing_esttoken
        if _rc == 0 {
            quietly _hddid_trailing_esttoken, precomma(`"`_hddid_raw0_probe'"')
            if `"`r(canonical)'"' != "" & `"`r(raw)'"' != "" {
                local _hddid_estopt_canonical `"`r(canonical)'"'
                local _hddid_estopt_raw `"`r(raw)'"'
            }
        }
    }
    local _hddid_prescan_skip_syntax 0
    if `"`_hddid_estopt_raw'"' != "" {
        local _hddid_prescan_skip_syntax 1
    }
    local _hddid_prescan_no_comma_assign 0
    if `_hddid_raw0_comma' == 0 & `"`_hddid_estopt_raw'"' == "" & ///
        !`_hddid_leading_ifin' & !`_hddid_subcmd_ifin' {
        quietly _hddid_postest_parse_estopt, ///
            optsraw(`"`_hddid_raw0'"')
        if `"`r(raw)'"' != "" {
            local _hddid_estopt_invalid `"`r(invalid)'"'
            local _hddid_estopt_canonical `"`r(canonical)'"'
            local _hddid_estopt_raw `"`r(raw)'"'
            local _hddid_prescan_no_comma_assign 1
            local _hddid_prescan_skip_syntax 1
        }
    }
    if !`_hddid_prescan_no_comma_assign' & ///
        `_hddid_raw0_comma' > 0 & `"`_hddid_estopt_raw'"' == "" {
        quietly _hddid_postest_parse_estopt, ///
            optsraw(`"`_hddid_raw0_postcomma'"')
        if `"`r(raw)'"' != "" {
            local _hddid_estopt_invalid `"`r(invalid)'"'
            local _hddid_estopt_canonical `"`r(canonical)'"'
            local _hddid_estopt_raw `"`r(raw)'"'
            local _hddid_prescan_skip_syntax 1
        }
    }

    // Accept generic estat call shapes, including weighted ones, then reject
    // them with package-specific guidance instead of parser-level errors.
    if !`_hddid_prescan_no_comma_assign' & !`_hddid_prescan_skip_syntax' {
        syntax [anything] [fw aw pw iw] [if] [in] [, *]
    }
    if !`_hddid_prescan_no_comma_assign' & !`_hddid_prescan_skip_syntax' & ///
        `"`_hddid_estopt_raw'"' == "" & `"`anything'"' != "" {
        quietly _hddid_postest_parse_estopt, ///
            optsraw(`"`anything'"')
        local _hddid_estopt_invalid `"`r(invalid)'"'
        local _hddid_estopt_canonical `"`r(canonical)'"'
        local _hddid_estopt_raw `"`r(raw)'"'
        if `"`_hddid_estopt_raw'"' == "" {
            local _hddid_anything_lc = lower(strtrim(`"`anything'"'))
            local _hddid_allow_syntax_trailing 1
            if inlist(`"`_hddid_anything_lc'"', ///
                "su", "sum", "summ", "summa", "summar", ///
                "summari", "summariz", "summarize") & ///
                (`"`if'"' != "" | `"`in'"' != "") {
                local _hddid_allow_syntax_trailing 0
            }
            if `_hddid_allow_syntax_trailing' {
                capture program list _hddid_trailing_esttoken
                if _rc == 0 {
                    quietly _hddid_trailing_esttoken, precomma(`"`_hddid_raw0'"')
                    local _hddid_esttoken_canonical `"`r(canonical)'"'
                    local _hddid_esttoken_raw `"`r(raw)'"'
                    if `"`_hddid_esttoken_canonical'"' != "" {
                        local _hddid_estopt_raw `"`_hddid_esttoken_raw'"'
                    }
                }
            }
        }
    }
    if !`_hddid_prescan_no_comma_assign' & !`_hddid_prescan_skip_syntax' & ///
        `"`_hddid_estopt_raw'"' == "" & `"`options'"' != "" {
        local _hddid_options_raw `"`options'"'
        if `"`_hddid_raw0_postcomma'"' != "" {
            local _hddid_options_raw `"`_hddid_raw0_postcomma'"'
        }
        quietly _hddid_postest_parse_estopt, ///
            optsraw(`"`_hddid_options_raw'"')
        local _hddid_option_estopt_invalid `"`r(invalid)'"'
        local _hddid_option_estopt_canonical `"`r(canonical)'"'
        if `"`_hddid_option_estopt_invalid'"' != "" {
            local _hddid_estopt_invalid `"`_hddid_option_estopt_invalid'"'
        }
        if `"`_hddid_option_estopt_canonical'"' != "" {
            local _hddid_estopt_canonical `"`_hddid_option_estopt_canonical'"'
        }
        local _hddid_estopt_raw `"`r(raw)'"'
    }

    if `"`_hddid_estopt_invalid'"' == "1" & ///
        `"`_hddid_estopt_canonical'"' == "" & ///
        `"`_hddid_estopt_raw'"' != "" {
        local _hddid_cmdline_lc = lower(`"`0'"')
        local _hddid_alias_rhs_lc ""
        local _hddid_alias_head_lc ""
        if regexm(`"`_hddid_estopt_raw'"', ///
            "^[ ]*[(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)][ ]*$") {
            local _hddid_alias_head_lc = lower(strtrim(regexs(1)))
        }
        else if regexm(`"`_hddid_estopt_raw'"', ///
            `"^(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*["]([^"]*)["][ ]*[)]$"') {
            local _hddid_alias_head_lc = lower(strtrim(regexs(1)))
            local _hddid_alias_rhs_lc = lower(strtrim(regexs(2)))
        }
        else if regexm(`"`_hddid_estopt_raw'"', ///
            "^(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*[(][ ]*'([^']*)'[ ]*[)]$") {
            local _hddid_alias_head_lc = lower(strtrim(regexs(1)))
            local _hddid_alias_rhs_lc = lower(strtrim(regexs(2)))
        }
        else if regexm(`"`_hddid_estopt_raw'"', ///
            `"^(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*["]([^"]*)["]$"') {
            local _hddid_alias_head_lc = lower(strtrim(regexs(1)))
            local _hddid_alias_rhs_lc = lower(strtrim(regexs(2)))
        }
        else if regexm(`"`_hddid_estopt_raw'"', ///
            "^(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*=[ ]*'([^']*)'$") {
            local _hddid_alias_head_lc = lower(strtrim(regexs(1)))
            local _hddid_alias_rhs_lc = lower(strtrim(regexs(2)))
        }
        if `"`_hddid_alias_head_lc'"' != "" & ///
            regexm(`"`_hddid_cmdline_lc'"', "(^|[ ,])method[ ]*[(]") {
            local _hddid_estopt_invalid ""
            if inlist(`"`_hddid_alias_head_lc'"', "r", "ra") {
                local _hddid_estopt_canonical "ra"
            }
            else if inlist(`"`_hddid_alias_head_lc'"', "i", "ip", "ipw") {
                local _hddid_estopt_canonical "ipw"
            }
            else if inlist(`"`_hddid_alias_head_lc'"', "a", "ai", "aip", "aipw") {
                local _hddid_estopt_canonical "aipw"
            }
        }
    }

    if `"`_hddid_estopt_invalid'"' == "1" & `"`_hddid_estopt_raw'"' != "" {
        _hddid_postest_show_invalid, raw(`"`_hddid_estopt_raw'"')
        exit 198
    }

    return local estopt_invalid `"`_hddid_estopt_invalid'"'
    return local estopt_canonical `"`_hddid_estopt_canonical'"'
    return local estopt_raw `"`_hddid_estopt_raw'"'
end

capture program drop hddid_estat
program define hddid_estat
    version 16
    capture program list _hddid_pst_cmdroles
    if _rc != 0 {
        local _hddid_pst_pkgdir `"$HDDID_SOURCE_RUN_PKGDIR"'
        if `"`_hddid_pst_pkgdir'"' == "" {
            local _hddid_pst_pkgdir `"$HDDID_WRAPPER_PKGDIR"'
        }
        if `"`_hddid_pst_pkgdir'"' == "" {
            local _hddid_pst_pkgdir `"$HDDID_PACKAGE_DIR"'
        }
        if `"`_hddid_pst_pkgdir'"' != "" {
            quietly capture run `"`_hddid_pst_pkgdir'/_hddid_pst_cmdroles.ado"'
            capture program list _hddid_pst_cmdroles
        }
        if _rc != 0 {
            capture findfile _hddid_pst_cmdroles.ado
            if _rc == 0 {
                quietly capture run `"`r(fn)'"'
            }
        }
    }

    _hddid_estat_stub_prescan, cmdline(`"`0'"')
    local _hddid_estopt_invalid `"`r(estopt_invalid)'"'
    local _hddid_estopt_canonical `"`r(estopt_canonical)'"'
    local _hddid_estopt_raw `"`r(estopt_raw)'"'
    local _hddid_active_surface = (`"`e(cmd)'"' == "hddid")
    if `_hddid_active_surface' == 0 {
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
        if `_hddid_has_p' & `_hddid_has_k' & `_hddid_has_q' & ///
            `_hddid_has_N' & ///
            `_hddid_has_xdebias' & `_hddid_has_stdx' & ///
            `_hddid_has_gdebias' & `_hddid_has_z0' & ///
            (`_hddid_has_stdg' | `_hddid_has_CIpoint' | `_hddid_has_CIuniform') & ///
            `"`_hddid_treat_probe'"' != "" & `"`_hddid_xvars_probe'"' != "" & ///
            `"`_hddid_zvar_probe'"' != "" & `"`_hddid_method_probe'"' != "" & ///
            (`"`_hddid_depvar_probe'"' != "" | `"`_hddid_depvar_role_probe'"' != "") {
            // Recognize the surrounding current HDDID surface from its core
            // posted role/grid/debiased objects even when one published
            // nonparametric inference object is the malformed field. Missing
            // e(stdg) or e(alpha) should still be classified as the same
            // current HDDID surface whenever the posted interval objects are
            // present, so the later guards can surface that exact saved-results
            // corruption instead of degrading the same result set to a generic
            // no-active-HDDID classification.
            local _hddid_active_surface 1
        }
    }
    if !`_hddid_active_surface' {
        di as error "{bf:hddid}: estat is not supported."
        di as error "  Reason: no active {bf:hddid} result set is available for postestimation."
        if `"`_hddid_estopt_raw'"' != "" {
            di as error "  Offending estimator-style input: " ///
                as text `"`_hddid_estopt_raw'"'
            di as error "  Reason: {bf:method()} only picks the {bf:Pol}/{bf:Tri} sieve basis; it is not an estimator-family switch."
            di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
            if `"`_hddid_estopt_canonical'"' == "" {
                if !regexm(`"`_hddid_estopt_raw'"', ///
                    "^[ ]*[(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)][ ]*$") {
                    _hddid_postest_show_invalid, raw(`"`_hddid_estopt_raw'"')
                }
            }
        }
        di as error "  Run {bf:hddid} first, then inspect the stored {bf:e()} result surface."
        exit 198
    }
    // Estimator-family misuse is parser-level input, not a property of the
    // current saved-results surface. If the user typed aipw/ra/ipw syntax
    // into estat, surface that misuse immediately instead of letting
    // malformed e() metadata mask it with an unrelated current-surface error.
    if `"`_hddid_estopt_raw'"' != "" {
        di as error "{bf:hddid}: estat is not supported."
        di as error "  Reason: hddid publishes parametric and nonparametric inference objects, but no unified estat contract is defined."
        di as error "  Offending estimator-style input: " ///
            as text `"`_hddid_estopt_raw'"'
        di as error "  Reason: {bf:method()} only picks the {bf:Pol}/{bf:Tri} sieve basis; it is not an estimator-family switch."
        di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
        if `"`_hddid_estopt_canonical'"' == "" {
            if !regexm(`"`_hddid_estopt_raw'"', ///
                "^[ ]*[(][ ]*(r|ra|i|ip|ipw|a|ai|aip|aipw)[ ]*[)][ ]*$") {
                _hddid_postest_show_invalid, raw(`"`_hddid_estopt_raw'"')
            }
        }
        di as error "  Use {bf:e(sample)} only when the original estimation data are still in memory."
        di as error "  After {bf:estimates use}, rely on the stored {bf:e()} result surface."
        di as error "  A live retained-sample count may no longer be available there."
        exit 198
    }

    local _depvar_eq = strtrim(`"`e(depvar)'"')
    local _depvar_eq_missing = (`"`_depvar_eq'"' == "")
    local _depvar_role = strtrim(`"`e(depvar_role)'"')
    local _firststage_mode = lower(strtrim(`"`e(firststage_mode)'"'))
    local _cmdline = `"`e(cmdline)'"'
    local _cmdline_probe = strtrim(`"`_cmdline'"')
    local _cmdline_parse_pre = `"`_cmdline'"'
    local _cmdline_lc_pre ""
    local _cmdline_depvar_pre ""
    if `"`_cmdline_probe'"' != "" {
        local _cmdline_parse_pre = ///
            subinstr(`"`_cmdline_parse_pre'"', char(9), " ", .)
        local _cmdline_parse_pre = ///
            subinstr(`"`_cmdline_parse_pre'"', char(10), " ", .)
        local _cmdline_parse_pre = ///
            subinstr(`"`_cmdline_parse_pre'"', char(13), " ", .)
        local _cmdline_lc_pre = lower(`"`_cmdline_parse_pre'"')
        if regexm(`"`_cmdline_lc_pre'"', "^[ ]*hddid[ ]+([^, ]+)") {
            local _cmdline_depvar_pre = strtrim(regexs(1))
        }
    }
    capture confirm scalar e(N_pretrim)
    local _has_n_pretrim_marker = (_rc == 0)
    capture confirm scalar e(clime_nfolds_cv_max)
    local _has_clime_max_marker = (_rc == 0)
    capture confirm scalar e(clime_nfolds_cv_effective_min)
    local _has_clime_effmin_marker = (_rc == 0)
    capture confirm scalar e(clime_nfolds_cv_effective_max)
    local _has_clime_effmax_marker = (_rc == 0)
    capture confirm matrix e(clime_nfolds_cv_per_fold)
    local _has_clime_perfold_marker = (_rc == 0)
    capture confirm scalar e(nboot)
    local _has_nboot = (_rc == 0)
    local _current_result_surface = (`"`_depvar_role'"' != "")
    if `_current_result_surface' == 0 & ///
        (`"`_firststage_mode'"' != "" | `_has_n_pretrim_marker' | ///
         `_has_clime_max_marker' | `_has_clime_effmin_marker' | ///
         `_has_clime_effmax_marker' | `_has_clime_perfold_marker') {
        local _current_result_surface 1
    }
    if `_depvar_eq_missing' & `_current_result_surface' {
        local _depvar_eq "beta"
    }
    if `_current_result_surface' & `"`_depvar_role'"' == "" & ///
        `"`_depvar_eq'"' != "" & `"`_depvar_eq'"' != "beta" {
        di as error "{bf:hddid}: stored e(depvar) must be {bf:beta} on current results"
        di as error "  Reason: current hddid results are already identified by current-only machine-readable metadata such as {bf:e(firststage_mode)}, {bf:e(N_pretrim)}, or the published CLIME fold-provenance block, so {bf:e(depvar)} must remain the generic beta-block label rather than a legacy outcome-role name."
        exit 498
    }
    local _depvar_role_from_cmdline 0
    local _cmd_has_roles 0
    local _cmdline_has_nofirst 0
    local _firststage_mode_from_cmdline 0
    local _fstage_from_folds 0
    local _cmdroles_checked 0
    local _cmdline_treat ""
    local _cmdline_xvars ""
    local _cmdline_zvar ""
    if `_current_result_surface' & `"`_depvar_role'"' == "" & ///
        `"`_depvar_eq'"' == "beta" {
        if `"`_cmdline_depvar_pre'"' != "" {
            local _depvar_role `"`_cmdline_depvar_pre'"'
            local _depvar_role_from_cmdline 1
        }
        else {
            di as error "{bf:hddid}: current results require stored e(depvar_role) or current e(cmdline) depvar provenance"
            di as error "  Reason: once current-only metadata such as {bf:e(firststage_mode)}, {bf:e(N_pretrim)}, or the published CLIME fold-provenance block is present, {bf:e(depvar)=beta} is only the generic beta-block label, so direct unsupported postestimation must recover the original outcome-role label from {bf:e(depvar_role)} or the successful-call record in {bf:e(cmdline)}."
            exit 498
        }
    }
    if `_current_result_surface' {
        local _estat_stub = strtrim(`"`e(estat_cmd)'"')
        if `"`_estat_stub'"' != "hddid_estat" {
            local _estat_stub "hddid_estat"
        }
        local _predict_stub = strtrim(`"`e(predict)'"')
        if `"`_predict_stub'"' != "hddid_p" {
            local _predict_stub "hddid_p"
        }
        local _vce = strtrim(`"`e(vce)'"')
        // e(vce) is only the machine-readable variance tag paired with the
        // already-posted covariance surface e(V); direct unsupported
        // postestimation can therefore fall back to the canonical HDDID tag
        // when it is absent or malformed.
        if `"`_vce'"' != "robust" {
            local _vce "robust"
        }
        local _vcetype = strtrim(`"`e(vcetype)'"')
        if `"`_vcetype'"' != "Robust" {
            local _vcetype "Robust"
        }
        local _marginsnotok = strtrim(`"`e(marginsnotok)'"')
        if `"`_marginsnotok'"' != "_ALL" {
            local _marginsnotok "_ALL"
        }
        if `"`_cmdline_probe'"' != "" {
            local _cmdline_parse = `"`_cmdline'"'
            local _cmdline_parse = ///
                subinstr(`"`_cmdline_parse'"', char(9), " ", .)
            local _cmdline_parse = ///
                subinstr(`"`_cmdline_parse'"', char(10), " ", .)
            local _cmdline_parse = ///
                subinstr(`"`_cmdline_parse'"', char(13), " ", .)
            local _cmdline_lc = lower(`"`_cmdline_parse'"')
            local _cmdline_opts = ""
            local _cmdline_comma = strpos(`"`_cmdline_lc'"', ",")
            if `_cmdline_comma' > 0 {
                local _cmdline_opts = ///
                    strtrim(substr(`"`_cmdline_lc'"', `_cmdline_comma' + 1, .))
            }
            local _cmdline_depvar = ""
            if regexm(`"`_cmdline_lc'"', "^[ ]*hddid[ ]+([^, ]+)") {
                local _cmdline_depvar = strtrim(regexs(1))
            }
            local _cmdline_treat_head ///
                "(^tr(e(a(t)?)?)?[(])|([ ,]tr(e(a(t)?)?)?[(])"
            local _cmdline_treat_token ///
                "(^tr(e(a(t)?)?)?[(][^)]*[)])|([ ,]tr(e(a(t)?)?)?[(][^)]*[)])"
            local _cmd_has_roles = ///
                regexm(`"`_cmdline_opts'"', `"`_cmdline_treat_head'"') & ///
                regexm(`"`_cmdline_opts'"', "(^|[ ,])x[(]") & ///
                regexm(`"`_cmdline_opts'"', "(^|[ ,])z[(]")
            local _cmdline_has_nofirst = ///
                regexm(`"`_cmdline_opts'"', "(^|[ ,])nof(i(r(s(t)?)?)?)?([ ,]|$)")
            local _cmdline_has_seed = ///
                regexm(`"`_cmdline_opts'"', "(^|[ ,])seed[(][ ]*[^)]*[)]")
            local _cmdline_dup_role_opts = 0
            local _cmdline_role_probe `"`_cmdline_opts'"'
            if regexm(`"`_cmdline_role_probe'"', `"`_cmdline_treat_token'"') {
                local _cmdline_role_probe = ///
                    regexr(`"`_cmdline_role_probe'"', ///
                    `"`_cmdline_treat_token'"', " ")
                if regexm(`"`_cmdline_role_probe'"', `"`_cmdline_treat_head'"') {
                    local _cmdline_dup_role_opts = 1
                }
            }
            local _cmdline_role_probe `"`_cmdline_opts'"'
            if regexm(`"`_cmdline_role_probe'"', "(^|[ ,])x[(][^)]*[)]") {
                local _cmdline_role_probe = ///
                    regexr(`"`_cmdline_role_probe'"', ///
                    "(^|[ ,])x[(][^)]*[)]", " ")
                if regexm(`"`_cmdline_role_probe'"', "(^|[ ,])x[(]") {
                    local _cmdline_dup_role_opts = 1
                }
            }
            local _cmdline_role_probe `"`_cmdline_opts'"'
            if regexm(`"`_cmdline_role_probe'"', "(^|[ ,])z[(][^)]*[)]") {
                local _cmdline_role_probe = ///
                    regexr(`"`_cmdline_role_probe'"', ///
                    "(^|[ ,])z[(][^)]*[)]", " ")
                if regexm(`"`_cmdline_role_probe'"', "(^|[ ,])z[(]") {
                    local _cmdline_dup_role_opts = 1
                }
            }
            if `_cmdline_dup_role_opts' {
                di as error "{bf:hddid}: stored e(cmdline) must encode each treat()/x()/z() role option at most once"
                di as error "  Current postestimation guidance found duplicated role provenance in {bf:e(cmdline)} = {bf:`_cmdline'}"
                exit 498
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
            if `"`_cmdline_depvar'"' == "" | `_cmd_has_roles' == 0 {
                local _published_xcoords_ok 0
                quietly _hddid_current_beta_coords
                local _published_xcoords `"`r(coords)'"'
                if `"`_published_xcoords'"' != "" {
                    local _published_xcoords_ok 1
                }
                local _stored_role_bundle_ok = ///
                    (`"`_depvar_role'"' != "" & ///
                    strtrim(`"`e(treat)'"') != "" & ///
                    (strtrim(`"`e(xvars)'"') != "" | `_published_xcoords_ok') & ///
                    strtrim(`"`e(zvar)'"') != "")
                if `_stored_role_bundle_ok' == 0 {
                    di as error "{bf:hddid}: stored e(cmdline) must include depvar plus treat()/x()/z() role provenance"
                    di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'}"
                    di as error "  Reason: the successful-call record can omit role text only when the published role metadata already remain complete in {bf:e(depvar_role)}, {bf:e(treat)}, and {bf:e(zvar)}, and when the beta-coordinate order still remains recoverable from machine-readable {bf:e(xvars)} or the published beta-surface labels."
                    exit 498
                }
            }
            capture confirm matrix e(tc)
            if _rc == 0 {
                tempname _tc_pre_disp
                matrix `_tc_pre_disp' = e(tc)
            local _tc_pre_names_actual : colnames `_tc_pre_disp'
            local _tc_pre_names_actual : list retokenize _tc_pre_names_actual
            if rowsof(`_tc_pre_disp') != 1 | colsof(`_tc_pre_disp') != 2 | ///
                missing(`_tc_pre_disp'[1,1]) | missing(`_tc_pre_disp'[1,2]) {
                di as error "{bf:hddid}: stored e(tc) must be a finite 1 x 2 rowvector"
                di as error "  Current postestimation guidance must validate the published CIuniform bootstrap provenance before ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
            if `"`_tc_pre_names_actual'"' != "tc_lower tc_upper" {
                di as error "{bf:hddid}: stored e(tc) must use colnames {bf:tc_lower tc_upper}"
                di as error "  Current postestimation guidance must validate unambiguous CIuniform bootstrap provenance before ancillary seed()/alpha()/nboot() cmdline checks: {bf:`_tc_pre_names_actual'}"
                exit 498
            }
            if `_tc_pre_disp'[1,1] > `_tc_pre_disp'[1,2] {
                di as error "{bf:hddid}: stored e(tc) must satisfy lower <= upper"
                di as error "  Current postestimation guidance must validate ordered CIuniform bootstrap provenance before ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
            capture confirm matrix e(CIuniform)
            local _has_ciuniform_pre = (_rc == 0)
            capture confirm matrix e(CIpoint)
            local _has_cipoint_pre = (_rc == 0)
            capture confirm matrix e(xdebias)
            local _has_xdebias_pre = (_rc == 0)
            capture confirm matrix e(stdx)
            local _has_stdx_pre = (_rc == 0)
            capture confirm matrix e(gdebias)
            local _has_gdebias_pre = (_rc == 0)
            capture confirm matrix e(stdg)
            local _has_stdg_pre = (_rc == 0)
            _hddid_estat_preflight
            _hddid_preflight_current_vectors, mode(postest)
            if `_has_ciuniform_pre' & `_has_gdebias_pre' & `_has_stdg_pre' {
                tempname _ciuniform_gap_pre _ciuniform_scale_pre _ciuniform_tol_pre
                mata: _hddid_ciuniform_actual_pre = st_matrix("e(CIuniform)"); _hddid_gdebias_pre = st_matrix("e(gdebias)"); _hddid_stdg_pre = st_matrix("e(stdg)"); _hddid_tc_pre = st_matrix("e(tc)"); _hddid_ciuniform_oracle_pre = (_hddid_gdebias_pre :+ _hddid_tc_pre[1, 1] * _hddid_stdg_pre) \ (_hddid_gdebias_pre :+ _hddid_tc_pre[1, 2] * _hddid_stdg_pre); st_numscalar("`_ciuniform_gap_pre'", max(abs(_hddid_ciuniform_actual_pre :- _hddid_ciuniform_oracle_pre))); st_numscalar("`_ciuniform_scale_pre'", max((1, max(abs(_hddid_ciuniform_actual_pre)), max(abs(_hddid_ciuniform_oracle_pre)))))
                scalar `_ciuniform_tol_pre' = 1e-12 * scalar(`_ciuniform_scale_pre')
                if scalar(`_ciuniform_gap_pre') > scalar(`_ciuniform_tol_pre') {
                    di as error "{bf:hddid}: stored e(CIuniform) must equal the lower/upper rows implied by e(gdebias), e(stdg), and e(tc)"
                    di as error "  Current postestimation guidance must reject malformed current interval-object metadata before ancillary seed()/alpha()/nboot() cmdline checks."
                    exit 498
                }
                tempname _stdg0es _ciug0es _cius0es
                mata: st_numscalar("`_stdg0es'", max(abs(st_matrix("e(stdg)")))); ///
                    _hddid_ciu0es = st_matrix("e(gdebias)") \ st_matrix("e(gdebias)"); ///
                    st_numscalar("`_ciug0es'", max(abs(st_matrix("e(CIuniform)") :- _hddid_ciu0es))); ///
                    st_numscalar("`_cius0es'", max((1, max(abs(st_matrix("e(CIuniform)"))), max(abs(_hddid_ciu0es)))))
                if scalar(`_stdg0es') <= scalar(`_ciuniform_tol_pre') & ///
                    scalar(`_ciug0es') <= scalar(`_ciuniform_tol_pre') & ///
                    (abs(`_tc_pre_disp'[1,1]) > scalar(`_ciuniform_tol_pre') | ///
                    abs(`_tc_pre_disp'[1,2]) > scalar(`_ciuniform_tol_pre')) {
                    di as error "{bf:hddid}: stored e(tc) must equal (0, 0) when stored e(stdg) is identically zero"
                    di as error "  Current postestimation guidance must reject impossible zero-SE bootstrap provenance before ancillary seed()/alpha()/nboot() cmdline checks."
                    exit 498
                }
            }
            local _ciuniform_zero_shortcut_pre = 0
            if `_has_ciuniform_pre' & `_has_gdebias_pre' & `_has_stdg_pre' {
                tempname _stdg_absmax_pre _ciuniform_shortcut_gap_pre _ciuniform_shortcut_scale_pre
                mata: st_numscalar("`_stdg_absmax_pre'", max(abs(st_matrix("e(stdg)")))); ///
                    _hddid_ciuniform_shortcut_pre = st_matrix("e(gdebias)") \ st_matrix("e(gdebias)"); ///
                    st_numscalar("`_ciuniform_shortcut_gap_pre'", max(abs(st_matrix("e(CIuniform)") :- _hddid_ciuniform_shortcut_pre))); ///
                    st_numscalar("`_ciuniform_shortcut_scale_pre'", max((1, max(abs(st_matrix("e(CIuniform)"))), max(abs(_hddid_ciuniform_shortcut_pre)))))
                if abs(`_tc_pre_disp'[1,1]) <= scalar(`_ciuniform_tol_pre') & ///
                    abs(`_tc_pre_disp'[1,2]) <= scalar(`_ciuniform_tol_pre') & ///
                    scalar(`_stdg_absmax_pre') <= scalar(`_ciuniform_tol_pre') & ///
                    scalar(`_ciuniform_shortcut_gap_pre') <= scalar(`_ciuniform_tol_pre') {
                    local _ciuniform_zero_shortcut_pre = 1
                }
            }
            local _cmdline_alpha_value_pre = .
            local _cmdline_alpha_ok_pre = 0
            if regexm(`"`_cmdline_opts'"', "(^|[ ,])alpha[(][ ]*([^)]*)[ ]*[)]") {
                local _cmdline_alpha_arg_pre = strtrim(regexs(2))
                if regexm(`"`_cmdline_alpha_arg_pre'"', ///
                    "^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$") {
                    local _cmdline_alpha_value_pre = real(`"`_cmdline_alpha_arg_pre'"')
                    if !missing(`_cmdline_alpha_value_pre') & ///
                        `_cmdline_alpha_value_pre' > 0 & ///
                        `_cmdline_alpha_value_pre' < 1 {
                        local _cmdline_alpha_ok_pre = 1
                    }
                }
            }
            capture confirm scalar e(alpha)
            local _has_alpha_pre = (_rc == 0)
            local _alpha_pre = .
            if `_has_alpha_pre' {
                local _alpha_pre = e(alpha)
            }
            else if `_cmdline_alpha_ok_pre' {
                local _alpha_pre = `_cmdline_alpha_value_pre'
            }
            if `_has_cipoint_pre' & `_has_xdebias_pre' & `_has_stdx_pre' & ///
                `_has_gdebias_pre' & `_has_stdg_pre' & !missing(`_alpha_pre') {
                tempname _cipoint_gap_pre _cipoint_scale_pre _cipoint_tol_pre _zcrit_pre
                scalar `_zcrit_pre' = invnormal(1 - `_alpha_pre' / 2)
                mata: st_numscalar("`_cipoint_gap_pre'", ///
                    max(abs(st_matrix("e(CIpoint)") :- ( ///
                    (st_matrix("e(xdebias)") :- st_numscalar("`_zcrit_pre'") :* st_matrix("e(stdx)"), ///
                     st_matrix("e(gdebias)") :- st_numscalar("`_zcrit_pre'") :* st_matrix("e(stdg)")) \ ///
                    (st_matrix("e(xdebias)") :+ st_numscalar("`_zcrit_pre'") :* st_matrix("e(stdx)"), ///
                     st_matrix("e(gdebias)") :+ st_numscalar("`_zcrit_pre'") :* st_matrix("e(stdg)")) )))); ///
                    st_numscalar("`_cipoint_scale_pre'", ///
                    max((1, max(abs(st_matrix("e(CIpoint)"))), ///
                    max(abs((st_matrix("e(xdebias)") :- st_numscalar("`_zcrit_pre'") :* st_matrix("e(stdx)"), ///
                             st_matrix("e(gdebias)") :- st_numscalar("`_zcrit_pre'") :* st_matrix("e(stdg)")) \ ///
                            (st_matrix("e(xdebias)") :+ st_numscalar("`_zcrit_pre'") :* st_matrix("e(stdx)"), ///
                             st_matrix("e(gdebias)") :+ st_numscalar("`_zcrit_pre'") :* st_matrix("e(stdg)")))))))
                scalar `_cipoint_tol_pre' = 1e-12 * scalar(`_cipoint_scale_pre')
                if scalar(`_cipoint_gap_pre') > scalar(`_cipoint_tol_pre') {
                    di as error "{bf:hddid}: stored e(CIpoint) must equal the pointwise intervals implied by e(xdebias), e(stdx), e(gdebias), e(stdg), and e(alpha)"
                    di as error "  Current postestimation guidance must reject malformed current pointwise interval metadata before ancillary seed()/alpha()/nboot() cmdline checks."
                    exit 498
                }
            }
            local _cmdline_seed_suppressed_pre = 0
            if regexm(`"`_cmdline_opts'"', "(^|[ ,])seed[(][ ]*-1[ ]*[)]") {
                local _cmdline_seed_suppressed_pre = 1
            }
            capture confirm scalar e(seed)
            local _cmdline_seed_has_estored = (_rc == 0)
            if `_cmdline_has_seed' & !`_cmdline_seed_suppressed_pre' & ///
                `_cmdline_seed_has_estored' == 0 {
                di as error "{bf:hddid}: current results with stored e(cmdline) seed() provenance require stored e(seed)"
                di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but no machine-readable {bf:e(seed)}."
                if `_ciuniform_zero_shortcut_pre' {
                    di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar for the realized outer fold assignment and Python CLIME CV splitting."
                    di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
                }
                else {
                    di as error "  Reason: current hddid results publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar behind the realized bootstrap path."
                }
                exit 498
            }
            local _treat = strtrim(`"`e(treat)'"')
            local _xvars = strtrim(`"`e(xvars)'"')
            local _zvar = strtrim(`"`e(zvar)'"')
            if `"`_xvars'"' == "" {
                quietly _hddid_current_beta_coords
                local _xvars `"`r(coords)'"'
            }
            if `"`_depvar_role'"' != "" & `"`_treat'"' != "" & `"`_xvars'"' != "" & `"`_zvar'"' != "" {
                _hddid_pst_cmdroles, ///
                    cmdline("`_cmdline'") ///
                    depvar("`_depvar_role'") ///
                    treat("`_treat'") ///
                    xvars("`_xvars'") ///
                    zvar("`_zvar'")
                local _cmdroles_checked 1
            }
        }
    }
}

    capture confirm scalar e(N_pretrim)
    local _has_n_pretrim = (_rc == 0)
    capture confirm scalar e(N_trimmed)
    local _has_n_trimmed = (_rc == 0)
    capture confirm scalar e(N_outer_split)
    local _has_n_outer_split = (_rc == 0)
    if `_has_n_pretrim' == 0 {
        if `_has_n_trimmed' {
            di as error "  Inspect {bf:e(N_trimmed)} and {bf:e(N)} for the stored retained-sample accounting."
        }
        else {
            di as error "  Stored retained-sample accounting is incomplete because {bf:e(N_trimmed)} is not available."
            di as error "  Inspect {bf:e(N)} for the retained-sample count that remains stored."
        }
        if `_current_result_surface' {
            di as error "  When available, inspect {bf:e(N_pretrim)} for the full pretrim-to-retained accounting identity."
        }
    }
    di as error "  HDDID always uses the paper's fixed {bf:AIPW (doubly robust)} estimator path."
    capture confirm scalar e(propensity_nfolds)
    local _has_prop_nf_fst = (_rc == 0)
    capture confirm scalar e(outcome_nfolds)
    local _has_out_nf_fst = (_rc == 0)
    if `"`_firststage_mode'"' == "" & `_current_result_surface' {
        if `"`_cmdline_probe'"' == "" & ///
            (`_has_prop_nf_fst' + `_has_out_nf_fst') == 1 {
            di as error "{bf:hddid}: current direct unsupported postestimation requires stored {bf:e(propensity_nfolds)} and {bf:e(outcome_nfolds)} when first-stage provenance is recovered from fold metadata"
            di as error "  Reason: direct unsupported postestimation must disclose the published paired internal-only fold block {bf:e(propensity_nfolds)}/{bf:e(outcome_nfolds)} before it can reuse the current saved-results surface as an internal first-stage fit."
            exit 498
        }
        if `"`_cmdline_probe'"' != "" & `_cmd_has_roles' {
            if `_cmdline_has_nofirst' {
                local _firststage_mode "nofirst"
            }
            else {
                local _firststage_mode "internal"
            }
            local _firststage_mode_from_cmdline 1
        }
        else if `_has_prop_nf_fst' & `_has_out_nf_fst' {
            local _firststage_mode "internal"
            local _fstage_from_folds 1
        }
    }
    if `"`_firststage_mode'"' == "" {
        if `_current_result_surface' {
            di as error "{bf:hddid}: current results require stored e(firststage_mode)"
            di as error "  Reason: current hddid direct unsupported postestimation can recover first-stage provenance from stored {bf:e(firststage_mode)}, from the published paired internal-only fold block {bf:e(propensity_nfolds)}/{bf:e(outcome_nfolds)}, or, when the successful-call record remains available, from {bf:e(cmdline)}; it only fails closed when all three are unavailable on a malformed current saved-results surface."
            exit 498
        }
    }
    if `"`_firststage_mode'"' != "" & ///
        !inlist(`"`_firststage_mode'"', "internal", "nofirst") {
        di as error "  stored {bf:e(firststage_mode)} must be {bf:internal} or {bf:nofirst}."
        di as error "  Current postestimation guidance refuses to reinterpret malformed first-stage provenance as a legacy {bf:e(cmdline)}-only result."
        exit 498
    }
    if inlist(`"`_firststage_mode'"', "internal", "nofirst") {
        if `_firststage_mode_from_cmdline' {
            di as error "  Recover the stored first-stage provenance from {bf:e(cmdline)}."
        }
        else if `_fstage_from_folds' {
            di as error "  Recover the stored internal first-stage provenance from the published paired {bf:e(propensity_nfolds)} and {bf:e(outcome_nfolds)} block."
        }
        else {
            di as error "  Use {bf:e(firststage_mode)} for the stored first-stage provenance."
        }
    }
    else {
        local _cmdline_legacy_probe = strtrim(`"`e(cmdline)'"')
        if `"`_cmdline_legacy_probe'"' == "" {
            di as error "{bf:hddid}: legacy results without stored e(firststage_mode) require stored e(cmdline)"
            di as error "  Reason: direct unsupported postestimation cannot classify the published first-stage path as {bf:internal} or {bf:nofirst} without either machine-readable {bf:e(firststage_mode)} or the successful-call provenance record."
            exit 498
        }
        di as error "  Legacy results without {bf:e(firststage_mode)} should recover that first-stage provenance from {bf:e(cmdline)}."
    }
    if `_current_result_surface' & inlist(`"`_firststage_mode'"', "internal", "nofirst") {
        capture confirm scalar e(N_outer_split)
        local _has_n_outer_split_fast = (_rc == 0)
        if `_has_n_outer_split_fast' {
            local _n_outer_split_fast = e(N_outer_split)
            if `"`_firststage_mode'"' == "internal" {
                capture confirm scalar e(N_pretrim)
                local _has_n_pretrim_fast = (_rc == 0)
                if `_has_n_pretrim_fast' {
                    local _n_pretrim_fast = e(N_pretrim)
                    if missing(`_n_pretrim_fast') | ///
                        missing(`_n_outer_split_fast') | ///
                        `_n_pretrim_fast' != floor(`_n_pretrim_fast') | ///
                        `_n_outer_split_fast' != floor(`_n_outer_split_fast') | ///
                        `_n_outer_split_fast' != `_n_pretrim_fast' {
                        di as error "{bf:hddid}: stored e(N_outer_split) must equal stored e(N_pretrim) for current internal results"
                        di as error "  Current postestimation guidance refuses to advertise malformed outer-split provenance metadata."
                        exit 498
                    }
                }
            }
            else if missing(`_n_outer_split_fast') | ///
                `_n_outer_split_fast' < e(N) | ///
                `_n_outer_split_fast' != floor(`_n_outer_split_fast') {
                di as error "{bf:hddid}: stored e(N_outer_split) must be a finite integer >= stored e(N) for current nofirst results"
                di as error "  Current postestimation guidance refuses to advertise malformed nofirst outer-split provenance before ancillary seed()/alpha()/nboot() checks."
                exit 498
            }
        }
        capture confirm matrix e(N_per_fold)
        local _has_n_per_fold_fast = (_rc == 0)
        if `_has_n_per_fold_fast' {
            capture confirm scalar e(k)
            local _has_k_fast = (_rc == 0)
            capture confirm scalar e(N)
            local _has_n_retained_fast = (_rc == 0)
            if `_has_k_fast' {
                local _k_fast = e(k)
                tempname _N_per_fold_fast
                matrix `_N_per_fold_fast' = e(N_per_fold)
                if rowsof(`_N_per_fold_fast') != 1 | ///
                    colsof(`_N_per_fold_fast') != `_k_fast' {
                    di as error "{bf:hddid}: stored e(N_per_fold) must be a 1 x k rowvector"
                    di as error "  Current postestimation guidance refuses to advertise malformed retained fold-count metadata before ancillary seed()/alpha()/nboot() checks."
                    exit 498
                }
                local _N_per_fold_sum_fast = 0
                forvalues _kk = 1/`_k_fast' {
                    local _N_per_fold_val_fast = ///
                        `_N_per_fold_fast'[1, `_kk']
                    if missing(`_N_per_fold_val_fast') | ///
                        `_N_per_fold_val_fast' < 1 | ///
                        `_N_per_fold_val_fast' != ///
                        floor(`_N_per_fold_val_fast') {
                        di as error "{bf:hddid}: stored e(N_per_fold) entries must be finite integers >= 1"
                        di as error "  Current postestimation guidance refuses to advertise malformed retained fold-count metadata before ancillary seed()/alpha()/nboot() checks."
                        exit 498
                    }
                    local _N_per_fold_sum_fast = ///
                        `_N_per_fold_sum_fast' + ///
                        `_N_per_fold_val_fast'
                }
                if `_has_n_retained_fast' {
                    local _n_retained_fast = e(N)
                    if !missing(`_n_retained_fast') & ///
                        `_N_per_fold_sum_fast' != `_n_retained_fast' {
                        di as error "{bf:hddid}: stored e(N_per_fold) must sum to stored e(N)"
                        di as error "  Current postestimation guidance refuses to advertise malformed retained fold-count metadata before ancillary seed()/alpha()/nboot() checks."
                        exit 498
                    }
                }
            }
        }
    }
    local _cmdline = `"`e(cmdline)'"'
    local _cmdline_probe = strtrim(`"`_cmdline'"')
    local _cmdline_has_seed 0
    local _cmdline_has_alpha 0
    local _cmdline_has_nboot 0
    local _cmdline_has_method 0
    local _cmdline_method ""
    local _cmdline_has_q 0
    local _cmdline_q_value .
    local _cmdline_seed_value .
    local _cmdline_alpha_value .
    local _cmdline_nboot_value .
    local _ciuniform_zero_shortcut 0
    capture confirm matrix e(tc)
    local _hddid_has_tc_shortcut = (_rc == 0)
    capture confirm matrix e(gdebias)
    local _hddid_has_gdebias_shortcut = (_rc == 0)
    capture confirm matrix e(stdg)
    local _hddid_has_stdg_shortcut = (_rc == 0)
    capture confirm matrix e(CIuniform)
    local _hddid_has_ciuniform_shortcut = (_rc == 0)
    if `_hddid_has_tc_shortcut' & `_hddid_has_gdebias_shortcut' & ///
        `_hddid_has_stdg_shortcut' & `_hddid_has_ciuniform_shortcut' {
        tempname _hddid_shortcut_tc _hddid_shortcut_stdgmax _hddid_shortcut_gap _hddid_shortcut_scale _hddid_shortcut_tol
        matrix `_hddid_shortcut_tc' = e(tc)
        mata: st_numscalar("`_hddid_shortcut_stdgmax'", max(abs(st_matrix("e(stdg)")))); ///
            _hddid_shortcut_ciu = st_matrix("e(gdebias)") \ st_matrix("e(gdebias)"); ///
            st_numscalar("`_hddid_shortcut_gap'", max(abs(st_matrix("e(CIuniform)") :- _hddid_shortcut_ciu))); ///
            st_numscalar("`_hddid_shortcut_scale'", max((1, max(abs(st_matrix("e(CIuniform)"))), max(abs(_hddid_shortcut_ciu)))))
        scalar `_hddid_shortcut_tol' = 1e-12 * scalar(`_hddid_shortcut_scale')
        if rowsof(`_hddid_shortcut_tc') == 1 & colsof(`_hddid_shortcut_tc') == 2 & ///
            abs(`_hddid_shortcut_tc'[1,1]) <= scalar(`_hddid_shortcut_tol') & ///
            abs(`_hddid_shortcut_tc'[1,2]) <= scalar(`_hddid_shortcut_tol') & ///
            scalar(`_hddid_shortcut_stdgmax') <= scalar(`_hddid_shortcut_tol') & ///
            scalar(`_hddid_shortcut_gap') <= scalar(`_hddid_shortcut_tol') {
            local _ciuniform_zero_shortcut 1
        }
    }
    local _tc_zero_shortcut = `_ciuniform_zero_shortcut'
    if `_current_result_surface' & `"`_firststage_mode'"' != "" & ///
        `"`_cmdline_probe'"' != "" {
        local _cmdline_parse = `"`_cmdline'"'
        local _cmdline_parse = ///
            subinstr(`"`_cmdline_parse'"', char(9), " ", .)
        local _cmdline_parse = ///
            subinstr(`"`_cmdline_parse'"', char(10), " ", .)
        local _cmdline_parse = ///
            subinstr(`"`_cmdline_parse'"', char(13), " ", .)
        local _cmdline_opts = ""
        local _cmdline_lc = lower(`"`_cmdline_parse'"')
        local _cmdline_comma = strpos(`"`_cmdline_lc'"', ",")
        if `_cmdline_comma' > 0 {
            local _cmdline_opts = ///
                strtrim(substr(`"`_cmdline_lc'"', `_cmdline_comma' + 1, .))
        }
        local _cmdline_depvar = ""
        if regexm(`"`_cmdline_lc'"', "^[ ]*hddid[ ]+([^, ]+)") {
            local _cmdline_depvar = strtrim(regexs(1))
        }
        local _cmdline_treat_head ///
            "(^tr(e(a(t)?)?)?[(])|([ ,]tr(e(a(t)?)?)?[(])"
        local _cmdline_treat_token ///
            "(^tr(e(a(t)?)?)?[(][^)]*[)])|([ ,]tr(e(a(t)?)?)?[(][^)]*[)])"
        local _cmd_has_roles = ///
            regexm(`"`_cmdline_opts'"', `"`_cmdline_treat_head'"') & ///
            regexm(`"`_cmdline_opts'"', "(^|[ ,])x[(]") & ///
            regexm(`"`_cmdline_opts'"', "(^|[ ,])z[(]")
        local _cmdline_dup_role_opts = 0
        local _cmdline_role_probe `"`_cmdline_opts'"'
        if regexm(`"`_cmdline_role_probe'"', `"`_cmdline_treat_token'"') {
            local _cmdline_role_probe = ///
                regexr(`"`_cmdline_role_probe'"', ///
                `"`_cmdline_treat_token'"', " ")
            if regexm(`"`_cmdline_role_probe'"', `"`_cmdline_treat_head'"') {
                local _cmdline_dup_role_opts = 1
            }
        }
        local _cmdline_role_probe `"`_cmdline_opts'"'
        if regexm(`"`_cmdline_role_probe'"', "(^|[ ,])x[(][^)]*[)]") {
            local _cmdline_role_probe = ///
                regexr(`"`_cmdline_role_probe'"', ///
                "(^|[ ,])x[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_role_probe'"', "(^|[ ,])x[(]") {
                local _cmdline_dup_role_opts = 1
            }
        }
        local _cmdline_role_probe `"`_cmdline_opts'"'
        if regexm(`"`_cmdline_role_probe'"', "(^|[ ,])z[(][^)]*[)]") {
            local _cmdline_role_probe = ///
                regexr(`"`_cmdline_role_probe'"', ///
                "(^|[ ,])z[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_role_probe'"', "(^|[ ,])z[(]") {
                local _cmdline_dup_role_opts = 1
            }
        }
        if `_cmdline_dup_role_opts' {
            di as error "{bf:hddid}: stored e(cmdline) must encode each treat()/x()/z() role option at most once"
            di as error "  Current postestimation guidance found duplicated role provenance in {bf:e(cmdline)} = {bf:`_cmdline'}"
            exit 498
        }
        if `"`_cmdline_depvar'"' == "" | `_cmd_has_roles' == 0 {
            local _published_xcoords_ok 0
            quietly _hddid_current_beta_coords
            local _published_xcoords `"`r(coords)'"'
            if `"`_published_xcoords'"' != "" {
                local _published_xcoords_ok 1
            }
            local _stored_role_bundle_ok = ///
                (`"`_depvar_role'"' != "" & ///
                strtrim(`"`e(treat)'"') != "" & ///
                (strtrim(`"`e(xvars)'"') != "" | `_published_xcoords_ok') & ///
                strtrim(`"`e(zvar)'"') != "")
            if `_stored_role_bundle_ok' == 0 {
                di as error "{bf:hddid}: stored e(cmdline) must include depvar plus treat()/x()/z() role provenance"
                di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'}"
                di as error "  Reason: the successful-call record can omit role text only when the published role metadata already remain complete in {bf:e(depvar_role)}, {bf:e(treat)}, and {bf:e(zvar)}, and when the beta-coordinate order still remains recoverable from machine-readable {bf:e(xvars)} or the published beta-surface labels."
                exit 498
            }
        }
        local _cmdline_has_nofirst = ///
            regexm(`"`_cmdline_opts'"', "(^|[ ,])nof(i(r(s(t)?)?)?)?([ ,]|$)")
        local _cmdline_has_seed = ///
            regexm(`"`_cmdline_opts'"', "(^|[ ,])seed[(][ ]*[^)]*[)]")
        local _cmdline_has_alpha = ///
            regexm(`"`_cmdline_opts'"', "(^|[ ,])alpha[(][ ]*[^)]*[)]")
        local _cmdline_has_nboot = ///
            regexm(`"`_cmdline_opts'"', "(^|[ ,])nboot[(][ ]*[^)]*[)]")
        if regexm(`"`_cmdline_opts'"', "(^|[ ,])method[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_has_method = 1
            local _cmdline_method = strtrim(regexs(2))
            if strlen(`"`_cmdline_method'"') >= 2 {
                local _cmdline_method_first = substr(`"`_cmdline_method'"', 1, 1)
                local _cmdline_method_last = substr(`"`_cmdline_method'"', -1, 1)
                if (`"`_cmdline_method_first'"' == `"""' & ///
                    `"`_cmdline_method_last'"' == `"""') | ///
                    (`"`_cmdline_method_first'"' == "'" & ///
                    `"`_cmdline_method_last'"' == "'") {
                    local _cmdline_method = substr(`"`_cmdline_method'"', 2, ///
                        strlen(`"`_cmdline_method'"') - 2)
                }
            }
            local _cmdline_method = strproper(strtrim(`"`_cmdline_method'"'))
        }
        if regexm(`"`_cmdline_opts'"', "(^|[ ,])q[(][ ]*([0-9]+)[ ]*[)]") {
            local _cmdline_has_q = 1
            local _cmdline_q_value = real(regexs(2))
        }
        local _cmdline_dup_seed = 0
        local _cmdline_dup_alpha = 0
        local _cmdline_dup_nboot = 0
        local _cmdline_scalar_probe `"`_cmdline_opts'"'
        if regexm(`"`_cmdline_scalar_probe'"', "(^|[ ,])seed[(][^)]*[)]") {
            local _cmdline_scalar_probe = ///
                regexr(`"`_cmdline_scalar_probe'"', ///
                "(^|[ ,])seed[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_scalar_probe'"', "(^|[ ,])seed[(]") {
                local _cmdline_dup_seed = 1
            }
        }
        local _cmdline_scalar_probe `"`_cmdline_opts'"'
        if regexm(`"`_cmdline_scalar_probe'"', "(^|[ ,])alpha[(][^)]*[)]") {
            local _cmdline_scalar_probe = ///
                regexr(`"`_cmdline_scalar_probe'"', ///
                "(^|[ ,])alpha[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_scalar_probe'"', "(^|[ ,])alpha[(]") {
                local _cmdline_dup_alpha = 1
            }
        }
        local _cmdline_scalar_probe `"`_cmdline_opts'"'
        if regexm(`"`_cmdline_scalar_probe'"', "(^|[ ,])nboot[(][^)]*[)]") {
            local _cmdline_scalar_probe = ///
                regexr(`"`_cmdline_scalar_probe'"', ///
                "(^|[ ,])nboot[(][^)]*[)]", " ")
            if regexm(`"`_cmdline_scalar_probe'"', "(^|[ ,])nboot[(]") {
                local _cmdline_dup_nboot = 1
            }
        }
        local _cmdline_seed_arg ""
        local _cmdline_seed_ok = 0
        local _cmdline_seed_suppressed = 0
        if regexm(`"`_cmdline_opts'"', "(^|[ ,])seed[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_seed_arg = strtrim(regexs(2))
            capture confirm number `_cmdline_seed_arg'
            if _rc == 0 {
                local _cmdline_seed_value = real(`"`_cmdline_seed_arg'"')
                if !missing(`_cmdline_seed_value') & ///
                    `_cmdline_seed_value' == floor(`_cmdline_seed_value') & ///
                    `_cmdline_seed_value' == -1 {
                    local _cmdline_seed_ok = 1
                    local _cmdline_seed_suppressed = 1
                }
                else if !missing(`_cmdline_seed_value') & ///
                    `_cmdline_seed_value' == floor(`_cmdline_seed_value') & ///
                    `_cmdline_seed_value' >= 0 & ///
                    `_cmdline_seed_value' <= 2147483647 {
                    local _cmdline_seed_ok = 1
                }
            }
        }
        local _cmdline_alpha_arg ""
        local _cmdline_alpha_value = .
        local _cmdline_alpha_ok = 0
        if regexm(`"`_cmdline_opts'"', "(^|[ ,])alpha[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_alpha_arg = strtrim(regexs(2))
            if regexm(`"`_cmdline_alpha_arg'"', ///
                "^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$") {
                local _cmdline_alpha_value = real(`"`_cmdline_alpha_arg'"')
                if !missing(`_cmdline_alpha_value') & ///
                    `_cmdline_alpha_value' > 0 & ///
                    `_cmdline_alpha_value' < 1 {
                    local _cmdline_alpha_ok = 1
                }
            }
        }
        local _cmdline_nboot_arg ""
        local _cmdline_nboot_ok = 0
        if regexm(`"`_cmdline_opts'"', "(^|[ ,])nboot[(][ ]*([^)]*)[ ]*[)]") {
            local _cmdline_nboot_arg = strtrim(regexs(2))
            if regexm(`"`_cmdline_nboot_arg'"', "^[+]?[0-9]+$") {
                local _cmdline_nboot_value = real(`"`_cmdline_nboot_arg'"')
                if !missing(`_cmdline_nboot_value') & ///
                    `_cmdline_nboot_value' >= 2 {
                    local _cmdline_nboot_ok = 1
                }
            }
        }
        local _mode_says_nofirst = (`"`_firststage_mode'"' == "nofirst")
        if `_cmdline_has_nofirst' != `_mode_says_nofirst' {
            di as error "{bf:hddid}: stored e(firststage_mode) must agree with whether e(cmdline) uses nofirst"
            di as error "  Postestimation found e(firststage_mode) = {bf:`_firststage_mode'} but e(cmdline) = {bf:`_cmdline'}"
            exit 498
        }
        if `_cmdline_has_seed' & `_cmdline_dup_seed' {
            di as error "{bf:hddid}: stored e(cmdline) must encode seed() provenance at most once"
            di as error "  Current postestimation guidance found duplicated {bf:seed()} provenance in {bf:e(cmdline)} = {bf:`_cmdline'}."
            if `_ciuniform_zero_shortcut' {
                di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still publish one atomic RNG provenance record for the realized outer fold assignment and Python CLIME CV splitting."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Reason: current hddid results publish one atomic RNG provenance record for the realized bootstrap path."
            }
            exit 498
        }
        if `_cmdline_has_seed' & `_cmdline_seed_ok' == 0 {
            di as error "{bf:hddid}: stored e(cmdline) seed() provenance must be a finite integer in [0, 2147483647]"
            di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} with malformed explicit {bf:seed()} provenance: {bf:`_cmdline_seed_arg'}."
            if `_ciuniform_zero_shortcut' {
                di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still reconcile explicit {bf:seed()} across the successful-call record and machine-readable {bf:e(seed)} for the realized outer fold assignment and Python CLIME CV splitting."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Reason: current hddid results publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar behind the realized bootstrap path."
            }
            exit 498
        }
        capture confirm scalar e(seed)
        if _rc == 0 {
            local _stored_seed = e(seed)
            if missing(`_stored_seed') | `_stored_seed' < 0 | ///
                `_stored_seed' > 2147483647 | ///
                `_stored_seed' != floor(`_stored_seed') {
                di as error "{bf:hddid}: stored e(seed) must be a finite integer in [0, 2147483647]"
                if `_ciuniform_zero_shortcut' {
                    di as error "  Reason: on the degenerate zero-SE shortcut, current hddid postestimation guidance still requires finite stored {bf:e(seed)} as machine-readable current-surface RNG metadata."
                    di as error "          That metadata still pins the realized outer fold assignment and Python CLIME CV splitting."
                    di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
                }
                else {
                    di as error "  Current postestimation guidance refuses to advertise malformed RNG provenance metadata."
                }
                exit 498
            }
        }
        if `_cmdline_has_seed' & !`_cmdline_seed_suppressed' & _rc != 0 {
            di as error "{bf:hddid}: current results with stored e(cmdline) seed() provenance require stored e(seed)"
            if `_ciuniform_zero_shortcut' {
                di as error "  Reason: on the degenerate zero-SE shortcut, current hddid postestimation guidance treats an explicit seed() as part of the machine-readable provenance for the realized outer fold assignment and Python CLIME CV splitting."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Reason: current hddid postestimation guidance treats an explicit seed() as part of the machine-readable bootstrap/RNG provenance behind the posted e(tc) and e(CIuniform) objects."
            }
            exit 498
        }
        if `_cmdline_has_seed' & `_cmdline_seed_suppressed' & _rc == 0 {
            local _stored_seed = e(seed)
            di as error "{bf:hddid}: stored e(cmdline) seed(-1) provenance forbids stored e(seed)"
            di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(seed)} = {bf:`_stored_seed'}."
            if `_ciuniform_zero_shortcut' {
                di as error "  Reason: on the degenerate zero-SE shortcut, {bf:seed(-1)} is still the published no-reset sentinel, so current postestimation refuses a saved-results surface that simultaneously posts suppressed provenance and machine-readable metadata for the realized outer fold assignment and Python CLIME CV splitting."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Reason: {bf:seed(-1)} is the published no-reset sentinel, so current postestimation refuses a saved-results surface that simultaneously posts suppressed and realized RNG provenance."
            }
            exit 498
        }
        if `_cmdline_has_seed' & !`_cmdline_seed_suppressed' & _rc == 0 & !missing(`_cmdline_seed_value') {
            local _stored_seed = e(seed)
            if `_stored_seed' != `_cmdline_seed_value' {
                di as error "{bf:hddid}: current results with stored e(cmdline) seed() provenance require stored e(seed) to match"
                di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(seed)} = {bf:`_stored_seed'}."
                if `_ciuniform_zero_shortcut' {
                    di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar for the realized outer fold assignment and Python CLIME CV splitting."
                    di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
                }
                else {
                    di as error "  Reason: current hddid results publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar behind the realized bootstrap path."
                }
                exit 498
            }
        }
        if `_cmdline_has_alpha' & `_cmdline_dup_alpha' {
            di as error "{bf:hddid}: stored e(cmdline) must encode alpha() provenance at most once"
            di as error "  Current postestimation guidance found duplicated {bf:alpha()} provenance in {bf:e(cmdline)} = {bf:`_cmdline'}."
            if `_ciuniform_zero_shortcut' {
                di as error "  Reason: on this degenerate zero-SE shortcut, current hddid results still publish one atomic shared {bf:e(alpha)} scalar that calibrates the analytic {bf:e(CIpoint)} pointwise intervals."
                di as error "          It does not recalibrate the collapsed {bf:e(CIuniform)} object because that published nonparametric interval object already equals {bf:e(gdebias)}."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Reason: current hddid results publish one atomic shared significance level behind the realized {bf:e(CIpoint)} object, and the same significance level also calibrates the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object."
            }
            exit 498
        }
        if `_cmdline_has_alpha' & `_cmdline_alpha_ok' == 0 {
            di as error "{bf:hddid}: stored e(cmdline) alpha() provenance must be a finite scalar in (0, 1)"
            di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} with malformed shared significance-level provenance in explicit {bf:alpha()}: {bf:`_cmdline_alpha_arg'}."
            if `_ciuniform_zero_shortcut' {
                di as error "  Reason: on this degenerate zero-SE shortcut, current hddid results still require the shared {bf:e(alpha)} scalar that calibrates the analytic {bf:e(CIpoint)} pointwise intervals."
                di as error "          It does not recalibrate the collapsed {bf:e(CIuniform)} object because that published nonparametric interval object already equals {bf:e(gdebias)}."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Reason: current hddid results publish the shared significance level through both the successful-call record and the machine-readable {bf:e(alpha)} scalar behind the realized {bf:e(CIpoint)} object, and the same {bf:e(alpha)} scalar also calibrates the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object."
            }
            exit 498
        }
        if `_cmdline_has_nboot' & `_cmdline_dup_nboot' {
            di as error "{bf:hddid}: stored e(cmdline) must encode nboot() provenance at most once"
            di as error "  Current postestimation guidance found duplicated {bf:nboot()} provenance in {bf:e(cmdline)} = {bf:`_cmdline'}."
            if `_ciuniform_zero_shortcut' {
                di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still publish one atomic {bf:nboot()} configuration record for the current saved-results surface."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Reason: current hddid results publish one atomic Gaussian-bootstrap replication count behind the realized {bf:e(tc)} / {bf:e(CIuniform)} path."
            }
            exit 498
        }
        if `_cmdline_has_nboot' & `_cmdline_nboot_ok' == 0 {
            di as error "{bf:hddid}: stored e(cmdline) nboot() provenance must be an integer >= 2"
            di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} with malformed explicit {bf:nboot()} provenance: {bf:`_cmdline_nboot_arg'}."
            if `_ciuniform_zero_shortcut' {
                di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still reconcile {bf:nboot()} across the successful-call record and machine-readable {bf:e(nboot)} as configuration metadata."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Reason: current hddid results publish bootstrap replication-count provenance through both the successful-call record and the machine-readable {bf:e(nboot)} scalar behind the realized {bf:e(tc)} / {bf:e(CIuniform)} path."
            }
            exit 498
        }
        capture confirm scalar e(nboot)
        if `_cmdline_has_nboot' & _rc != 0 & !missing(`_cmdline_nboot_value') {
            di as error "{bf:hddid}: current results with stored e(cmdline) nboot() provenance require stored e(nboot)"
            di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but no machine-readable {bf:e(nboot)}."
            if `_ciuniform_zero_shortcut' {
                di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still reconcile {bf:nboot()} across the successful-call record and machine-readable {bf:e(nboot)} as configuration metadata."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Reason: current hddid results publish bootstrap replication-count provenance through both the successful-call record and the machine-readable {bf:e(nboot)} scalar behind the realized {bf:e(tc)} / {bf:e(CIuniform)} path."
            }
            exit 498
        }
        if `_cmdline_has_nboot' & _rc == 0 & !missing(`_cmdline_nboot_value') {
            local _stored_nboot = e(nboot)
            if `_stored_nboot' != `_cmdline_nboot_value' {
                di as error "{bf:hddid}: current results with stored e(cmdline) nboot() provenance require stored e(nboot) to match"
                di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(nboot)} = {bf:`_stored_nboot'}."
                if `_ciuniform_zero_shortcut' {
                    di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still reconcile {bf:nboot()} across the successful-call record and machine-readable {bf:e(nboot)} as configuration metadata."
                    di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
                }
                else {
                    di as error "  Reason: current hddid results publish bootstrap replication-count provenance through both the successful-call record and the machine-readable {bf:e(nboot)} scalar behind the realized {bf:e(tc)} / {bf:e(CIuniform)} path."
                }
                exit 498
            }
        }
    }
    local _treat = strtrim(`"`e(treat)'"')
    local _xvars = strtrim(`"`e(xvars)'"')
    local _zvar = strtrim(`"`e(zvar)'"')
    if `_current_result_surface' {
        if `"`_treat'"' == "" & `"`_cmdline_treat'"' != "" {
            local _treat `"`_cmdline_treat'"'
        }
        if `"`_zvar'"' == "" & `"`_cmdline_zvar'"' != "" {
            local _zvar `"`_cmdline_zvar'"'
        }
        if `"`_xvars'"' == "" {
            quietly _hddid_current_beta_coords
            local _xvars `"`r(coords)'"'
        }
        if `"`_cmdline_probe'"' != "" & `_cmdroles_checked' == 0 & ///
            `"`_depvar_role'"' != "" & `"`_treat'"' != "" & ///
            `"`_xvars'"' != "" & `"`_zvar'"' != "" {
            _hddid_pst_cmdroles, ///
                cmdline("`_cmdline'") ///
                depvar("`_depvar_role'") ///
                treat("`_treat'") ///
                xvars("`_xvars'") ///
                zvar("`_zvar'")
            local _cmdroles_checked 1
        }
    }
    if `_current_result_surface' & `"`_treat'"' == "" {
        di as error "{bf:hddid}: current results require stored e(treat)"
        di as error "  Reason: direct unsupported postestimation can recover the treatment-role label from current e(cmdline) when that successful-call record is still available; otherwise the current saved-results surface is malformed."
        exit 498
    }
    if `_current_result_surface' & `"`_xvars'"' == "" {
        di as error "{bf:hddid}: current results require stored e(xvars)"
        di as error "  Reason: direct unsupported postestimation can recover the beta-coordinate order from machine-readable {bf:e(xvars)} or the published beta-surface labels when they are still available; otherwise it cannot advertise the stored beta surface."
        exit 498
    }
    if `_current_result_surface' & `"`_zvar'"' == "" {
        di as error "{bf:hddid}: current results require stored e(zvar)"
        di as error "  Reason: direct unsupported postestimation can recover the running-variable role label from current e(cmdline) when that successful-call record is still available; otherwise the current saved-results surface is malformed."
        exit 498
    }
    local _has_role_metadata = 0
    if `"`_treat'"' != "" & `"`_xvars'"' != "" & `"`_zvar'"' != "" {
        if (`_current_result_surface' & `"`_depvar_role'"' != "") | ///
            (`_current_result_surface' == 0 & `"`_depvar_eq'"' != "") {
            local _has_role_metadata = 1
        }
    }
    if `"`_firststage_mode'"' == "nofirst" {
        if `_firststage_mode_from_cmdline' {
            di as error "  Current {bf:nofirst} results recover that first-stage provenance from {bf:e(cmdline)} when {bf:e(firststage_mode)} is unavailable."
        }
        else {
            di as error "  Current {bf:nofirst} results can still support bare replay and direct unsupported postestimation guidance from {bf:e(firststage_mode)} plus stored role metadata when {bf:e(cmdline)} is unavailable."
        }
        if `_has_role_metadata' == 0 {
            di as error "  Replay and direct unsupported postestimation guidance also require stored role metadata:"
            di as error "  {bf:e(depvar_role)} or legacy {bf:e(depvar)}, plus {bf:e(treat)}, {bf:e(xvars)}, and {bf:e(zvar)}."
        }
        di as error "  When available, use {bf:e(cmdline)} for the successful call's published provenance" ///
            as error " record."
    }
    else if `"`_firststage_mode'"' == "internal" {
        if `_firststage_mode_from_cmdline' {
            di as error "  Current internally estimated results recover that first-stage provenance from {bf:e(cmdline)} when {bf:e(firststage_mode)} is unavailable."
        }
        else if `_fstage_from_folds' {
            di as error "  Current internally estimated results recover that first-stage provenance from the published paired {bf:e(propensity_nfolds)} / {bf:e(outcome_nfolds)} block when {bf:e(firststage_mode)} and {bf:e(cmdline)} are unavailable."
        }
        else {
            di as error "  Current internally estimated results publish {bf:e(firststage_mode)=internal}."
            di as error "  Current internally estimated results can still support bare replay and direct unsupported postestimation guidance from {bf:e(firststage_mode)} plus stored role metadata when {bf:e(cmdline)} is unavailable."
        }
        if `_has_role_metadata' == 0 {
            di as error "  Replay and direct unsupported postestimation guidance also require stored role metadata:"
            di as error "  {bf:e(depvar_role)} or legacy {bf:e(depvar)}, plus {bf:e(treat)}, {bf:e(xvars)}, and {bf:e(zvar)}."
        }
        di as error "  When available, use {bf:e(cmdline)} for the successful call's published provenance record."
    }
    else {
        di as error "  Use {bf:e(cmdline)} for the successful call's published provenance record."
    }
    local _seed .
    capture confirm scalar e(seed)
    local _has_seed = (_rc == 0)
    if _rc == 0 {
        local _seed = e(seed)
        if missing(`_seed') | `_seed' < 0 | `_seed' > 2147483647 | ///
            `_seed' != floor(`_seed') {
            di as error "{bf:hddid}: stored e(seed) must be a finite integer in [0, 2147483647]"
            if `_tc_zero_shortcut' {
                di as error "  Reason: on this degenerate zero-SE shortcut, current hddid postestimation guidance still requires finite stored {bf:e(seed)} as machine-readable current-surface RNG metadata."
                di as error "          That metadata still pins the realized outer fold assignment and Python CLIME CV splitting."
                di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Current postestimation guidance refuses to advertise malformed RNG provenance metadata."
            }
            exit 498
        }
    }
    if `_current_result_surface' & `_cmdline_has_seed' & ///
        !missing(`_cmdline_seed_value') & `_cmdline_seed_value' == -1 & `_has_seed' {
        di as error "{bf:hddid}: stored e(cmdline) seed(-1) provenance forbids stored e(seed)"
        di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(seed)} = {bf:`_seed'}."
        if `_ciuniform_zero_shortcut' {
            di as error "  Reason: on the degenerate zero-SE shortcut, {bf:seed(-1)} is still the published no-reset sentinel, so current postestimation refuses a saved-results surface that simultaneously posts suppressed provenance and machine-readable metadata for the realized outer fold assignment and Python CLIME CV splitting."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: {bf:seed(-1)} is the published no-reset sentinel, so current postestimation refuses a saved-results surface that simultaneously posts suppressed and realized RNG provenance."
        }
        exit 498
    }
    if `_current_result_surface' & `_cmdline_has_seed' & `_has_seed' & ///
        !missing(`_cmdline_seed_value') & `_cmdline_seed_value' != -1 & ///
        `_seed' != `_cmdline_seed_value' {
        di as error "{bf:hddid}: current results with stored e(cmdline) seed() provenance require stored e(seed) to match"
        di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(seed)} = {bf:`_seed'}."
        di as error "  Reason: current hddid results publish RNG provenance through both the successful-call record and the machine-readable {bf:e(seed)} scalar behind the realized bootstrap path."
        exit 498
    }
    if `_current_result_surface' & ///
        `_cmdline_has_seed' == 0 & `_has_seed' {
        di as error "{bf:hddid}: current results whose stored e(cmdline) omits seed() require stored e(seed) to be absent"
        di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(seed)} = {bf:`_seed'}."
        if `_ciuniform_zero_shortcut' {
            di as error "  Reason: on the degenerate zero-SE shortcut, omitting {bf:seed()} means the realized outer fold assignment remains deterministic from the data rather than being indexed by one published seed scalar."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: omitting {bf:seed()} means the realized bootstrap path followed the ambient RNG stream rather than a single published seed scalar."
        }
        exit 498
    }
    capture confirm scalar e(alpha)
    local _has_alpha = (_rc == 0)
    local _alpha = .
    if `_has_alpha' {
        local _alpha = e(alpha)
        if missing(`_alpha') | `_alpha' <= 0 | `_alpha' >= 1 {
            di as error "{bf:hddid}: stored e(alpha) must be a finite scalar in (0, 1)"
            di as error "  Unsupported postestimation guidance refuses to advertise malformed shared significance-level provenance or contradictory shared bootstrap-interval significance-level provenance."
            exit 498
        }
    }
    else if `_current_result_surface' & `_cmdline_has_alpha' & ///
        `_cmdline_dup_alpha' == 0 & `_cmdline_alpha_ok' {
        local _alpha = `_cmdline_alpha_value'
    }
    else if `_current_result_surface' {
        di as error "{bf:hddid}: current results require stored e(alpha) or valid current e(cmdline) alpha() provenance"
        if `_tc_zero_shortcut' {
            di as error "  Reason: on this degenerate zero-SE shortcut, current hddid results still require shared pointwise-significance provenance for the analytic {bf:e(CIpoint)} pointwise intervals."
            di as error "          It does not recalibrate the collapsed {bf:e(CIuniform)} object because that published nonparametric interval object already equals {bf:e(gdebias)}."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish the significance level behind the posted {bf:e(CIpoint)} object and the realized {bf:e(tc)}/{bf:e(CIuniform)} interval object for the beta and omitted-intercept z-varying coordinates."
        }
        exit 498
    }
    if `_current_result_surface' & `_cmdline_has_alpha' & ///
        `_has_alpha' & ///
        !missing(`_cmdline_alpha_value') & ///
        abs(`_alpha' - `_cmdline_alpha_value') > 1e-12 {
        di as error "{bf:hddid}: current results with stored e(cmdline) alpha() provenance require stored e(alpha) to match"
        di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(alpha)} = {bf:`_alpha'}."
        if `_tc_zero_shortcut' {
            di as error "  Reason: on this degenerate zero-SE shortcut, current hddid results still reconcile the shared {bf:e(alpha)} scalar that calibrates the analytic {bf:e(CIpoint)} pointwise intervals."
            di as error "          It does not recalibrate the collapsed {bf:e(CIuniform)} object because that published nonparametric interval object already equals {bf:e(gdebias)}."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish the shared significance level through both the successful-call record and the machine-readable {bf:e(alpha)} scalar behind the realized {bf:e(CIpoint)} object, and the same {bf:e(alpha)} scalar also calibrates the realized {bf:e(tc)}/{bf:e(CIuniform)} bootstrap interval object."
        }
        exit 498
    }
    local _nboot .
    capture confirm matrix e(tc)
    local _has_tc_bundle = (_rc == 0)
    capture confirm matrix e(CIuniform)
    local _has_ciuniform_bundle = (_rc == 0)
    if `_has_nboot' == 0 & `_current_result_surface' & ///
        `_has_tc_bundle' & `_has_ciuniform_bundle' {
        di as error "{bf:hddid}: current CIuniform/tc surfaces require stored e(nboot)"
        if `_ciuniform_zero_shortcut' {
            di as error "  Reason: on this degenerate zero-SE shortcut, current hddid results still require stored {bf:e(nboot)} as machine-readable current-surface configuration metadata."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish the bootstrap replication count as machine-readable provenance behind the realized {bf:e(tc)}/{bf:e(CIuniform)} interval object."
        }
        exit 498
    }
    if `_has_nboot' {
        local _nboot = e(nboot)
        if missing(`_nboot') | `_nboot' < 2 | ///
            `_nboot' != floor(`_nboot') {
            di as error "{bf:hddid}: stored e(nboot) must be an integer >= 2"
            if `_ciuniform_zero_shortcut' {
                di as error "  Unsupported postestimation guidance refuses to advertise malformed current-surface {bf:e(nboot)} configuration metadata on the degenerate zero-SE shortcut."
                di as error "  No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
            }
            else {
                di as error "  Unsupported postestimation guidance refuses to advertise malformed bootstrap replication-count provenance."
            }
            exit 498
        }
    }
    if `_current_result_surface' & `_cmdline_has_nboot' & `_has_nboot' & ///
        !missing(`_cmdline_nboot_value') & `_nboot' != `_cmdline_nboot_value' {
        di as error "{bf:hddid}: current results with stored e(cmdline) nboot() provenance require stored e(nboot) to match"
        di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(nboot)} = {bf:`_nboot'}."
        if `_ciuniform_zero_shortcut' {
            di as error "  Reason: on the degenerate zero-SE shortcut, current hddid results still reconcile {bf:nboot()} across the successful-call record and machine-readable {bf:e(nboot)} as configuration metadata."
            di as error "          No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Reason: current hddid results publish bootstrap replication-count provenance through both the successful-call record and the machine-readable {bf:e(nboot)} scalar behind the realized {bf:e(tc)} / {bf:e(CIuniform)} path."
        }
        exit 498
    }
    local _cmdline_has_method = ///
        regexm(`"`_cmdline_opts'"', "(^|[ ,])method[(][ ]*[^)]*[)]")
    local _cmdline_has_q = ///
        regexm(`"`_cmdline_opts'"', "(^|[ ,])q[(][ ]*[^)]*[)]")
    local _cmdline_has_method_assign = ///
        regexm(`"`_cmdline_opts'"', "(^|[ ,])method[ ]*=")
    local _cmdline_has_q_assign = ///
        regexm(`"`_cmdline_opts'"', "(^|[ ,])q[ ]*=")
    local _cmdline_dup_method = 0
    local _cmdline_dup_q = 0
    local _cmdline_method_arg ""
    local _cmdline_method ""
    local _cmdline_method_ok = 0
    local _cmdline_q_arg ""
    local _cmdline_q_value = .
    local _cmdline_q_ok = 0
    if `_cmdline_has_method_assign' | `_cmdline_has_q_assign' {
        local _cmdline_assign_parts ""
        if `_cmdline_has_method_assign' {
            local _cmdline_assign_parts "{bf:method=}"
        }
        if `_cmdline_has_q_assign' {
            if `"`_cmdline_assign_parts'"' != "" {
                local _cmdline_assign_parts ///
                    `"`_cmdline_assign_parts' and {bf:q=}"'
            }
            else {
                local _cmdline_assign_parts "{bf:q=}"
            }
        }
        di as error "{bf:hddid}: stored e(cmdline) must encode method()/q() provenance with option syntax, not assignment syntax"
        di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} with assignment-style `_cmdline_assign_parts' provenance."
        di as error "  Reason: one successful hddid call can publish the realized sieve family/order only through {bf:method()} and {bf:q()}, so assignment-style saved provenance is malformed."
        exit 498
    }
    local _cmdline_method_probe `"`_cmdline_opts'"'
    if regexm(`"`_cmdline_method_probe'"', "(^|[ ,])method[(][^)]*[)]") {
        local _cmdline_method_probe = ///
            regexr(`"`_cmdline_method_probe'"', ///
            "(^|[ ,])method[(][^)]*[)]", " ")
        if regexm(`"`_cmdline_method_probe'"', "(^|[ ,])method[(]") {
            local _cmdline_dup_method = 1
        }
    }
    local _cmdline_q_probe `"`_cmdline_opts'"'
    if regexm(`"`_cmdline_q_probe'"', "(^|[ ,])q[(][^)]*[)]") {
        local _cmdline_q_probe = ///
            regexr(`"`_cmdline_q_probe'"', "(^|[ ,])q[(][^)]*[)]", " ")
        if regexm(`"`_cmdline_q_probe'"', "(^|[ ,])q[(]") {
            local _cmdline_dup_q = 1
        }
    }
    if `_cmdline_has_method' & `_cmdline_dup_method' {
        di as error "{bf:hddid}: stored e(cmdline) must encode method() provenance at most once"
        di as error "  Current postestimation guidance found duplicated {bf:method()} provenance in {bf:e(cmdline)} = {bf:`_cmdline'}."
        di as error "  Reason: one realized HDDID surface can only come from one sieve-basis family."
        exit 498
    }
    if `_cmdline_has_q' & `_cmdline_dup_q' {
        di as error "{bf:hddid}: stored e(cmdline) must encode q() provenance at most once"
        di as error "  Current postestimation guidance found duplicated {bf:q()} provenance in {bf:e(cmdline)} = {bf:`_cmdline'}."
        di as error "  Reason: one realized HDDID surface can only come from one sieve-order choice."
        exit 498
    }
    if regexm(`"`_cmdline_opts'"', "(^|[ ,])method[(][ ]*([^)]*)[ ]*[)]") {
        local _cmdline_method_arg = strtrim(regexs(2))
        if strlen(`"`_cmdline_method_arg'"') >= 2 {
            local _cmdline_method_first = substr(`"`_cmdline_method_arg'"', 1, 1)
            local _cmdline_method_last = substr(`"`_cmdline_method_arg'"', -1, 1)
            if (`"`_cmdline_method_first'"' == `"""' & `"`_cmdline_method_last'"' == `"""') | ///
                (`"`_cmdline_method_first'"' == "'" & `"`_cmdline_method_last'"' == "'") {
                local _cmdline_method_arg = substr(`"`_cmdline_method_arg'"', 2, ///
                    strlen(`"`_cmdline_method_arg'"') - 2)
            }
        }
        local _cmdline_method = strproper(strtrim(`"`_cmdline_method_arg'"'))
        if inlist(`"`_cmdline_method'"', "Pol", "Tri") {
            local _cmdline_method_ok = 1
        }
    }
    if `_cmdline_has_method' & `_cmdline_method_ok' == 0 {
        di as error "{bf:hddid}: stored e(cmdline) method() provenance must be {bf:Pol} or {bf:Tri}"
        di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} with malformed explicit {bf:method()} provenance: {bf:`_cmdline_method_arg'}."
        di as error "  Reason: the successful-call record may publish only the polynomial or trigonometric sieve family used by the realized HDDID surface."
        exit 498
    }
    if regexm(`"`_cmdline_opts'"', "(^|[ ,])q[(][ ]*([^)]*)[ ]*[)]") {
        local _cmdline_q_arg = strtrim(regexs(2))
        if regexm(`"`_cmdline_q_arg'"', "^[+]?[0-9]+$") {
            local _cmdline_q_value = real(`"`_cmdline_q_arg'"')
            if !missing(`_cmdline_q_value') & `_cmdline_q_value' >= 1 {
                local _cmdline_q_ok = 1
            }
        }
    }
    if `_cmdline_has_q' & `_cmdline_q_ok' == 0 {
        di as error "{bf:hddid}: stored e(cmdline) q() provenance must be an integer >= 1"
        di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} with malformed explicit {bf:q()} provenance: {bf:`_cmdline_q_arg'}."
        di as error "  Reason: the successful-call record may publish only a valid positive sieve-order choice for the realized HDDID surface."
        exit 498
        }
        local _stored_method_cmdline = strproper(strlower(strtrim(`"`e(method)'"')))
        local _stored_method_ok = inlist(`"`_stored_method_cmdline'"', "Pol", "Tri")
        if `_stored_method_ok' == 0 & `"`_method'"' != "" {
            local _stored_method_cmdline `"`_method'"'
            local _stored_method_ok = inlist(`"`_stored_method_cmdline'"', "Pol", "Tri")
        }
        capture confirm scalar e(q)
        local _stored_q_cmdline = .
        local _stored_q_ok = 0
        if _rc == 0 {
            local _stored_q_cmdline = e(q)
            if !missing(`_stored_q_cmdline') & `_stored_q_cmdline' >= 1 & ///
                `_stored_q_cmdline' == floor(`_stored_q_cmdline') {
                local _stored_q_ok = 1
            }
        }
        else if !missing(`_q') {
            local _stored_q_cmdline = `_q'
            local _stored_q_ok = 1
        }
    if (`_cmdline_has_method' | `_cmdline_has_q') & ///
        `_stored_method_ok' & `_stored_q_ok' {
        local _cmdline_method_mismatch = 0
        local _cmdline_q_mismatch = 0
        if `_cmdline_has_method' & `_cmdline_method_ok' & ///
            `"`_cmdline_method'"' != `"`_stored_method_cmdline'"' {
            local _cmdline_method_mismatch = 1
        }
        if `_cmdline_has_q' & `_cmdline_q_ok' & ///
            `_cmdline_q_value' != `_stored_q_cmdline' {
            local _cmdline_q_mismatch = 1
        }
        if `_cmdline_method_mismatch' | `_cmdline_q_mismatch' {
            di as error "{bf:hddid}: current results with stored e(cmdline) method()/q() provenance require stored e(method) and e(q) to match"
            di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(method)} = {bf:`_stored_method_cmdline'} and {bf:e(q)} = {bf:`_stored_q_cmdline'}."
            di as error "  Reason: current hddid results publish sieve-basis provenance through both the successful-call record and the machine-readable {bf:e(method)} / {bf:e(q)} metadata behind the realized beta and omitted-intercept z-varying surface."
            exit 498
        }
    }
    local _method_raw = strtrim(`"`e(method)'"')
    di as error "  When available, use {bf:e(seed)} for the published RNG provenance of that realized estimation path."
    if `_ciuniform_zero_shortcut' {
        di as error "  explicit seed() fixes the realized outer fold assignment and Python CLIME CV splitting."
        di as error "  On this degenerate zero-SE shortcut, no studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
    }
    else {
        di as error "  explicit seed() fixes the realized outer fold assignment, Gaussian bootstrap draws, and Python CLIME CV splitting."
    }
    di as error "  explicit seed(0) is a legal seeded run, not an alias for the omitted seed()/seed(-1) path."
    di as error "  seeded reproducibility applies only to hddid's internal random steps."
    di as error "  on exit, hddid restores the caller's prior session RNG state."
    if `_ciuniform_zero_shortcut' {
        di as error "  omitted seed()/seed(-1) keeps the outer fold assignment deterministic from the data."
        di as error "  On this degenerate zero-SE shortcut, no studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
    }
    else {
        di as error "  omitted seed()/seed(-1) keeps the outer fold assignment deterministic from the data, and bootstrap draws continue from the caller's session RNG state."
    }
    if `"`_firststage_mode'"' == "internal" {
        di as error "  Under omitted seed()/seed(-1), current internal results keep the realized fold map as a deterministic function of the current common-score row order."
    }
    else if `"`_firststage_mode'"' == "nofirst" {
        di as error "  Under omitted seed()/seed(-1), current nofirst results keep the realized fold map as a deterministic function of the current nofirst fold-pinning row order."
    }
    else {
        di as error "  Under omitted seed()/seed(-1), the realized fold map is a deterministic function of the current nofirst fold-pinning row order."
    }
    di as error "  Python CLIME CV uses a deterministic per-fold integer seed derived from the current Stata RNG state."
    if `"`_method_raw'"' == "" {
        if `_current_result_surface' {
            if strtrim(`"`_cmdline'"') != "" {
                if `_cmdline_has_method' & `_cmdline_method_ok' {
                    local _method_raw `"`_cmdline_method'"'
                }
                else if `_cmdline_has_method' == 0 {
                    local _method_raw "Pol"
                }
                else {
                    di as error "{bf:hddid}: current results require stored e(method) or valid current e(cmdline) method() provenance"
                    di as error "  Reason: current hddid results publish the stored sieve basis family as {bf:Pol} or {bf:Tri}, so unsupported postestimation guidance will not guess that basis from a malformed saved-results surface."
                    exit 498
                }
            }
            else {
                di as error "{bf:hddid}: current results require stored e(method)"
                di as error "  Reason: current hddid results publish the stored sieve basis family as {bf:Pol} or {bf:Tri}, so unsupported postestimation guidance will not guess that basis from a malformed saved-results surface."
                exit 498
            }
        }
        di as error "  Legacy hddid results should still store {bf:e(method)} to identify the stored sieve basis."
    }
    else {
        local _method = strproper(strlower(`"`_method_raw'"'))
        if !inlist(`"`_method'"', "Pol", "Tri") {
            di as error "{bf:hddid}: stored e(method) must be Pol or Tri"
            di as error "  Current postestimation guidance refuses to reinterpret an out-of-domain stored sieve label: {bf:`_method_raw'}"
            exit 498
        }
        capture confirm scalar e(q)
        if _rc {
            if `_current_result_surface' & strtrim(`"`_cmdline'"') != "" {
                if `_cmdline_has_q' & `_cmdline_q_ok' {
                    local _q = `_cmdline_q_value'
                }
                else if `_cmdline_has_q' == 0 {
                    local _q = 8
                }
                else {
                    di as error "{bf:hddid}: current results require stored e(q) or valid current e(cmdline) q() provenance"
                    di as error "  Reason: current hddid results publish the stored sieve-basis order, so unsupported postestimation guidance will not advertise a malformed current surface without that basis-order metadata."
                    exit 498
                }
            }
            else {
                di as error "{bf:hddid}: current results require stored e(q)"
                di as error "  Reason: current hddid results publish the stored sieve-basis order, so unsupported postestimation guidance will not advertise a malformed current surface without that basis-order metadata."
                exit 498
            }
        }
        else local _q = e(q)
        if missing(`_q') | `_q' < 1 | `_q' != floor(`_q') {
            di as error "{bf:hddid}: stored e(q) must be a finite integer >= 1"
            di as error "  Current postestimation guidance refuses to advertise malformed sieve-order metadata."
            exit 498
        }
        if `_current_result_surface' & strtrim(`"`_cmdline'"') != "" {
            if `_cmdline_has_method' {
                if `"`_cmdline_method'"' != `"`_method'"' {
                    di as error "{bf:hddid}: current results with stored e(cmdline) method() provenance require stored e(method) to match"
                    di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(method)} = {bf:`_method'}."
                    di as error "  Reason: current hddid results publish the sieve-basis family through both the successful-call record and the machine-readable {bf:e(method)} label behind the realized beta/omitted-intercept z-varying surface."
                    exit 498
                }
            }
            else if `"`_method'"' != "Pol" {
                di as error "{bf:hddid}: current results whose stored e(cmdline) omits method() require stored e(method) = {bf:Pol}"
                di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(method)} = {bf:`_method'}."
                di as error "  Reason: the successful-call record still identifies the official default sieve basis, and {bf:hddid} syntax defaults to {bf:method(Pol)}."
                exit 498
            }
            if `_cmdline_has_q' {
                if `_q' != `_cmdline_q_value' {
                    di as error "{bf:hddid}: current results with stored e(cmdline) q() provenance require stored e(q) to match"
                    di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(q)} = {bf:`_q'}."
                    di as error "  Reason: current hddid results publish the sieve-order provenance through both the successful-call record and the machine-readable {bf:e(q)} scalar behind the realized beta/omitted-intercept z-varying surface."
                    exit 498
                }
            }
            else if `_q' != 8 {
                di as error "{bf:hddid}: current results whose stored e(cmdline) omits q() require stored e(q) = 8"
                di as error "  Current postestimation guidance found {bf:e(cmdline)} = {bf:`_cmdline'} but stored {bf:e(q)} = {bf:`_q'}."
                di as error "  Reason: the successful-call record still identifies the official default sieve order, and {bf:hddid} syntax defaults to {bf:q(8)}."
                exit 498
            }
        }
        di as error "  Use {bf:e(method)} to identify the stored sieve basis only; whether it is {bf:Pol} or {bf:Tri},"
        di as error "  it is not an {bf:RA}/{bf:IPW}/{bf:AIPW} estimator switch."
        if `"`_method'"' == "Tri" {
            capture confirm scalar e(z_support_min)
            local _has_z_support_min = (_rc == 0)
            capture confirm scalar e(z_support_max)
            local _has_z_support_max = (_rc == 0)
            if `_has_z_support_min' == 0 | `_has_z_support_max' == 0 {
                di as error "{bf:hddid}: current results require stored e(z_support_min) and e(z_support_max)"
                di as error "  Reason: current method(Tri) results publish the retained support normalization used by the trigonometric basis, so unsupported postestimation guidance will not advertise a malformed current surface without those endpoints."
                exit 498
            }
            local _z_support_min = e(z_support_min)
            local _z_support_max = e(z_support_max)
            if missing(`_z_support_min') | missing(`_z_support_max') | ///
                `_z_support_min' >= `_z_support_max' {
                di as error "{bf:hddid}: stored Tri support endpoints must satisfy finite z_support_min < z_support_max"
                di as error "  Current postestimation guidance refuses to advertise malformed trigonometric-support metadata."
                exit 498
            }
            if mod(`_q', 2) != 0 {
                di as error "{bf:hddid}: stored e(q) must be even when e(method) = {bf:Tri}"
                di as error "  Current postestimation guidance refuses to advertise malformed trigonometric sieve-order metadata."
                exit 498
            }
            di as error "  For {bf:method(Tri)} results, inspect {bf:e(z_support_min)} and {bf:e(z_support_max)}"
            di as error "  for the retained-support normalization used by the trigonometric basis."
        }
    }
    if `_current_result_surface' {
        di as error "  Current results use {bf:e(depvar)}={bf:beta} as the generic beta-block label in Stata postestimation."
        if `_depvar_eq_missing' {
            di as error "  When that duplicate local label is absent, the posted {bf:e(b)}/{bf:e(V)} equation stripes still recover the same generic {bf:beta} label."
        }
        if `"`_depvar_eq'"' != "beta" {
            di as error "{bf:hddid}: stored {bf:e(depvar)} must be {bf:beta} when {bf:e(depvar_role)} is present"
            di as error "  Reason: current hddid results separate the generic beta-block label from the original outcome-role label."
            exit 498
        }
        di as error "  Use {bf:e(depvar_role)} for the original outcome-role label when available; otherwise current {bf:e(cmdline)} or legacy {bf:e(depvar)},"
        di as error "  plus {bf:e(treat)}, {bf:e(xvars)}, and {bf:e(zvar)} for the role mapping."
    }
    else {
        di as error "  Use {bf:e(depvar_role)} for the original outcome-role label when available; otherwise current {bf:e(cmdline)} or legacy {bf:e(depvar)},"
        di as error "  plus {bf:e(treat)}, {bf:e(xvars)}, and {bf:e(zvar)} for the role mapping."
    }
    local _properties = strtrim(`"`e(properties)'"')
    local _properties : list retokenize _properties
    // e(properties) is only Stata wrapper capability metadata.  Unsupported
    // estat guidance already points users to the actual posted HDDID objects in
    // e(b), e(V), and the debiased interval matrices, so coherent current saved
    // results must not be vetoed solely because this capability label is absent
    // or malformed.
    capture confirm matrix e(N_per_fold)
    if _rc != 0 {
        if `_current_result_surface' {
            di as error "{bf:hddid}: current results require stored e(N_per_fold)"
            di as error "  Reason: current hddid results publish the retained cross-fit fold counts behind the debiased aggregation, so unsupported postestimation guidance will not advertise fold accounting from a malformed saved-results surface."
            exit 498
        }
        di as error "  When available, inspect {bf:e(N_per_fold)} for the stored post-trim fold accounting only; legacy results may omit that implementation-specific weight summary."
    }
    else {
        capture confirm scalar e(N)
        local _has_n_retained = (_rc == 0)
        if `_has_n_retained' {
            local _n_retained = e(N)
            if `_current_result_surface' & ///
                (missing(`_n_retained') | ///
                `_n_retained' < 1 | ///
                `_n_retained' != floor(`_n_retained')) {
                di as error "{bf:hddid}: stored e(N) must be a finite integer >= 1"
                di as error "  Current postestimation guidance refuses to advertise malformed retained-sample metadata."
                exit 498
            }
        }
        else if `_current_result_surface' {
            di as error "{bf:hddid}: current results require stored e(N)"
            di as error "  Reason: current hddid results publish the retained post-trim sample count that anchors the stored beta/omitted-intercept z-varying surface and fold accounting."
            exit 498
        }
        if `_has_n_trimmed' {
            local _n_trimmed = e(N_trimmed)
            if missing(`_n_trimmed') | ///
                `_n_trimmed' < 0 | ///
                `_n_trimmed' != floor(`_n_trimmed') {
                di as error "{bf:hddid}: stored e(N_trimmed) must be a finite integer >= 0"
                di as error "  Current postestimation guidance refuses to advertise malformed retained-sample accounting metadata."
                exit 498
            }
            if `_has_n_pretrim' & `_has_n_retained' & ///
                `_n_trimmed' != (e(N_pretrim) - `_n_retained') {
                di as error "{bf:hddid}: stored e(N_trimmed) must equal stored e(N_pretrim) - e(N)"
                di as error "  Current postestimation guidance refuses to advertise inconsistent retained-sample accounting metadata."
                exit 498
            }
        }
        local _k_disp = .
        capture confirm scalar e(k)
        local _has_k = (_rc == 0)
        if `_has_k' {
            local _k_disp = e(k)
        }
        else if `_current_result_surface' {
            tempname _hddid_npf_k_probe
            matrix `_hddid_npf_k_probe' = e(N_per_fold)
            if rowsof(`_hddid_npf_k_probe') != 1 | ///
                colsof(`_hddid_npf_k_probe') < 2 {
                di as error "{bf:hddid}: current results require stored e(k) or a valid 1 x k e(N_per_fold)"
                di as error "  Reason: current hddid results can recover the duplicate outer-fold count from the published fold-accounting rowvector, but only when that object still has coherent 1 x k shape."
                exit 498
            }
            local _has_k 1
            local _k_disp = colsof(`_hddid_npf_k_probe')
        }
        if `_has_k' {
            if `_current_result_surface' & ///
                (missing(`_k_disp') | `_k_disp' < 2 | ///
                `_k_disp' != floor(`_k_disp')) {
                di as error "{bf:hddid}: stored e(k) must be a finite integer >= 2"
                di as error "  Current postestimation guidance refuses to advertise malformed cross-fitting metadata."
                exit 498
            }
        }
        if `_has_n_pretrim' {
            if `_current_result_surface' & `_has_n_outer_split' == 0 {
                di as error "{bf:hddid}: current results require stored e(N_outer_split)"
                di as error "  Reason: current hddid results publish the outer-split sample count that pins the stored fold assignment before retained-sample accounting."
                exit 498
            }
            di as error "  Inspect {bf:e(N_pretrim)}, {bf:e(N_trimmed)}, and {bf:e(N)} for the"
            di as error "  published pretrim, trimmed, and retained-sample accounting behind the stored result surface."
        }
        else {
            if `_has_n_trimmed' {
                di as error "  Inspect {bf:e(N_trimmed)} and {bf:e(N)} for the stored retained-sample accounting."
            }
            else {
                di as error "  Stored retained-sample accounting is incomplete because {bf:e(N_trimmed)} is not available."
                di as error "  Inspect {bf:e(N)} for the retained-sample count that remains stored."
            }
            if `_current_result_surface' {
                di as error "  When available, inspect {bf:e(N_pretrim)} for the full pretrim-to-retained accounting identity."
            }
        }
        if `_has_n_outer_split' {
            local _n_outer_split = e(N_outer_split)
            local _n_outer_split_floor_label "e(N)"
            local _n_outer_split_floor = .
            if `_has_n_retained' {
                local _n_outer_split_floor = `_n_retained'
            }
            if `_current_result_surface' {
                if `"`_firststage_mode'"' == "internal" & `_has_n_pretrim' {
                    if missing(`_n_outer_split') | ///
                        `_n_outer_split' != e(N_pretrim) | ///
                        `_n_outer_split' != floor(`_n_outer_split') {
                        di as error "{bf:hddid}: stored e(N_outer_split) must equal stored e(N_pretrim) for current internal results"
                        di as error "  Current postestimation guidance refuses to advertise malformed outer-split provenance metadata."
                        exit 498
                    }
                }
                else if `"`_firststage_mode'"' == "nofirst" {
                    local _n_outer_split_floor = `_n_retained'
                    local _n_outer_split_floor_label "e(N)"
                }
                if `"`_firststage_mode'"' != "internal" & ///
                    (missing(`_n_outer_split') | ///
                    `_n_outer_split' < `_n_outer_split_floor' | ///
                    `_n_outer_split' != floor(`_n_outer_split')) {
                    if `"`_firststage_mode'"' == "nofirst" {
                        di as error "{bf:hddid}: stored e(N_outer_split) must be a finite integer >= stored e(N) for current nofirst results"
                        di as error "  Current postestimation guidance refuses to advertise malformed nofirst outer-split provenance before ancillary seed()/alpha()/nboot() checks."
                    }
                    else {
                        di as error "{bf:hddid}: stored e(N_outer_split) must be a finite integer >= stored `_n_outer_split_floor_label'"
                        di as error "  Current postestimation guidance refuses to advertise malformed outer-split provenance metadata."
                    }
                    exit 498
                }
            }
            else if `_has_n_retained' & ///
                (missing(`_n_outer_split') | ///
                `_n_outer_split' < `_n_outer_split_floor' | ///
                `_n_outer_split' != floor(`_n_outer_split')) {
                di as error "{bf:hddid}: stored e(N_outer_split) must be a finite integer >= stored {bf:e(N)}"
                di as error "  Legacy postestimation guidance refuses to advertise malformed outer-split provenance metadata."
                exit 498
            }
            di as error "  Inspect {bf:e(N_outer_split)} for the stored outer-split sample count that pins the published outer fold assignment."
            if `_current_result_surface' & `"`_firststage_mode'"' == "internal" {
                di as error "  Under the default internal-first-stage path, if/in qualifiers are applied before both the broader D/W-complete propensity sample and the common-score sample are built."
                di as error "  D/W-complete rows missing {bf:depvar} never become held-out evaluation rows, so they stay available to every fold-external default-path propensity training sample."
                di as error "  If the qualifier-defined and physically subsetted default-path runs hand hddid the same D/W-complete rows in the same order, they must therefore deliver the same retained-sample estimates."
                di as error "  Excluded rows do not continue to widen the internal propensity path, pin the common-score outer split, or move the x() canonicalization anchor."
            }
            else if `_current_result_surface' & `"`_firststage_mode'"' == "nofirst" {
                di as error "  Under {bf:nofirst}, supplied {bf:pihat()} must already be fold-aligned out-of-fold on the broader strict-interior pretrim fold-feasibility sample."
                di as error "  That broader strict-interior pretrim fold-feasibility sample is the nofirst-specific split path rebuilt from the supplied nuisance inputs, not the default internal-first-stage score sample."
                di as error "  Under {bf:nofirst}, if/in qualifiers are applied before hddid rebuilds that broader strict-interior nofirst split path."
                di as error "  Running with if/in is therefore equivalent to physically subsetting those rows first: excluded rows do not continue to pin the outer split, retained estimator fold ids, or same-fold nuisance checks."
                di as error "  If the retained rows stay in the same order and the supplied fold-aligned nuisances are the same, the corresponding nofirst if/in run and physically subsetted run must return the same retained-sample estimates."
                di as error "  Exact-boundary pihat() rows stay outside that broader strict-interior fold-feasibility split and do not pin retained outer fold IDs by themselves."
                di as error "  Any legal strict-interior 0<pihat()<1 row still enters that broader strict-interior fold-feasibility path before later overlap trimming, but only treatment-arm keys with at least one retained-overlap pretrim row pin the published retained outer fold IDs."
                di as error "  Only treatment-arm keys with at least one retained-overlap pretrim row pin the retained outer fold IDs."
                di as error "  Retained rows then keep those already-assigned outer fold IDs on the narrower retained-overlap score sample."
                di as error "  Retained-overlap membership only narrows the later retained estimator sample and same-arm phi duplicate-key checks; it does not erase those already-assigned outer fold IDs."
                di as error "  Same-fold cross-arm phi candidate checks also extend to depvar-missing or otherwise score-ineligible twins with pihat() still in [0.01,0.99] when shared W=(X,Z) rows stay on the same retained estimator fold IDs."
                di as error "  Same-arm phi duplicate-key checks also extend to depvar-missing twins with pihat() still in [0.01,0.99] when that treatment-arm key still contributes a retained overlap row."
            }
            if `_current_result_surface' & `"`_firststage_mode'"' == "nofirst" & ///
                `_has_n_pretrim' & `_n_outer_split' > e(N_pretrim) {
                di as error "  Legal strict-interior pihat() rows excluded from the score by missing depvar(), phi1hat(), or phi0hat() can still keep e(N_outer_split) above e(N_pretrim), because the outer fold map is fixed before those later score-sample eligibility checks."
            }
            if `_current_result_surface' & `"`_firststage_mode'"' == "nofirst" & ///
                `_has_n_pretrim' & `_n_outer_split' < e(N_pretrim) {
                di as error "  Legal strict-interior pihat() rows on treatment-arm keys that never contribute a retained-overlap pretrim row do not pin retained outer fold IDs, so e(N_pretrim) can exceed e(N_outer_split)."
            }
            if `_current_result_surface' & `"`_firststage_mode'"' == "nofirst" & ///
                `_has_n_pretrim' & `_n_outer_split' == e(N_pretrim) {
                di as error "  Under {bf:nofirst}, {bf:e(N_outer_split)=e(N_pretrim)} can still hide different fold-pinning membership because strict-interior rows can replace exact-boundary score rows one-for-one."
            }
        }
        if `_has_k' {
            tempname _N_per_fold_disp
            matrix `_N_per_fold_disp' = e(N_per_fold)
            if rowsof(`_N_per_fold_disp') != 1 | ///
                colsof(`_N_per_fold_disp') != `_k_disp' {
                di as error "{bf:hddid}: stored e(N_per_fold) must be a 1 x k rowvector"
                di as error "  Current postestimation guidance found " ///
                    rowsof(`_N_per_fold_disp') " x " ///
                    colsof(`_N_per_fold_disp') ///
                    " but stored e(k) = " %9.0f `_k_disp'
                exit 498
            }
            local _N_per_fold_sum = 0
            forvalues _kk = 1/`_k_disp' {
                local _N_per_fold_val = `_N_per_fold_disp'[1, `_kk']
                if missing(`_N_per_fold_val') | ///
                    `_N_per_fold_val' < 1 | ///
                    `_N_per_fold_val' != floor(`_N_per_fold_val') {
                    di as error "{bf:hddid}: stored e(N_per_fold) entries must be finite integers >= 1"
                    di as error "  Current postestimation guidance found e(N_per_fold)[1,`_kk'] = " ///
                        %9.0f `_N_per_fold_val'
                    exit 498
                }
                local _N_per_fold_sum = `_N_per_fold_sum' + `_N_per_fold_val'
            }
            if `_has_n_retained' & `_N_per_fold_sum' != `_n_retained' {
                di as error "{bf:hddid}: stored e(N_per_fold) must sum to stored e(N)"
                di as error "  Current postestimation guidance found sum(e(N_per_fold)) = " ///
                    %9.0f `_N_per_fold_sum' " but e(N) = " ///
                    %9.0f `_n_retained'
                exit 498
            }
        }
        di as error "  Inspect {bf:e(N_per_fold)} for the published post-trim retained-sample counts by outer evaluation fold."
    }
    local _xvars_lc = lower(strtrim(`"`_xvars'"'))
    local _xvars_lc : list retokenize _xvars_lc
    local _xcount = 0
    if `"`_xvars_lc'"' != "" {
        local _xcount : word count `_xvars_lc'
    }
    local _xvars_unique : list uniq _xvars_lc
    local _xvars_unique : list retokenize _xvars_unique
    local _xvars_unique_count : word count `_xvars_unique'
    capture confirm scalar e(p)
    local _has_p = (_rc == 0)
    local _p_disp = .
    if `_has_p' {
        local _p_disp = e(p)
        if `_current_result_surface' & ///
            (missing(`_p_disp') | `_p_disp' < 1 | ///
            `_p_disp' != floor(`_p_disp')) {
            di as error "{bf:hddid}: stored e(p) must be a finite integer >= 1"
            di as error "  Current postestimation guidance refuses to advertise malformed beta-dimension metadata."
            exit 498
        }
    }
    else if `_current_result_surface' {
        if `_xcount' >= 1 {
            local _p_disp = `_xcount'
        }
        if missing(`_p_disp') {
            capture confirm matrix e(b)
            if _rc == 0 {
                tempname _hddid_estat_bdim_probe
                matrix `_hddid_estat_bdim_probe' = e(b)
                if colsof(`_hddid_estat_bdim_probe') >= 1 {
                    local _p_disp = colsof(`_hddid_estat_bdim_probe')
                }
            }
        }
        if missing(`_p_disp') | `_p_disp' < 1 | ///
            `_p_disp' != floor(`_p_disp') {
            di as error "{bf:hddid}: current results require stored e(p) or a published beta surface width"
            di as error "  Reason: current hddid postestimation guidance validates the posted beta covariance surface against the parametric dimension encoded in stored e(p), e(xvars), or the published beta objects."
            exit 498
        }
    }
    if !missing(`_p_disp') & `_p_disp' == floor(`_p_disp') & ///
        `_p_disp' >= 1 & `_p_disp' > `_xcount' {
        local _xcount = `_p_disp'
    }
    if `_current_result_surface' & ///
        `_xvars_unique_count' != `_xcount' {
        di as error "{bf:hddid}: stored e(xvars) must list one distinct covariate name per published beta coordinate"
        di as error "  Current postestimation guidance refuses to advertise beta objects from malformed coordinate metadata."
        exit 498
    }
    capture confirm matrix e(V)
    local _has_v = (_rc == 0)
    if `_current_result_surface' & `_has_v' == 0 {
        di as error "{bf:hddid}: current results require stored e(V)"
        di as error "  Reason: current hddid postestimation guidance points users to the posted beta covariance surface, so it must first validate that covariance matrix before checking published covariance-rank metadata."
        exit 498
    }
    capture confirm scalar e(clime_nfolds_cv_max)
    local _has_clime_req = (_rc == 0)
    capture confirm scalar e(clime_nfolds_cv_effective_min)
    local _has_clime_eff_min = (_rc == 0)
    capture confirm scalar e(clime_nfolds_cv_effective_max)
    local _has_clime_eff_max = (_rc == 0)
    capture confirm matrix e(clime_nfolds_cv_per_fold)
    local _has_clime_pf = (_rc == 0)
    if `_current_result_surface' {
        local _clime_block_parts = ///
            `_has_clime_req' + `_has_clime_eff_min' + ///
            `_has_clime_eff_max' + `_has_clime_pf'
        if `_p_disp' > 1 & `_clime_block_parts' != 4 {
            di as error "{bf:hddid}: current multi-x results require the stored CLIME metadata block"
            di as error "  Reason: current multi-x hddid results publish the requested and realized CLIME fold metadata as part of the retained-sample precision-step provenance behind beta debiasing. Current scalar-x results instead use the analytic inverse, so direct unsupported postestimation may suppress that optional CLIME summary when e(p)=1."
            exit 498
        }
        if `_clime_block_parts' {
            if missing(`_k_disp') | `_k_disp' < 1 | ///
                `_k_disp' != floor(`_k_disp') {
                di as error "{bf:hddid}: stored e(k) must be a finite integer >= 1"
                di as error "  Current postestimation guidance refuses to advertise malformed outer-fold metadata."
                exit 498
            }
            local _clime_nfolds_cv_max = e(clime_nfolds_cv_max)
        if missing(`_clime_nfolds_cv_max') | ///
            `_clime_nfolds_cv_max' < 2 | ///
            `_clime_nfolds_cv_max' != floor(`_clime_nfolds_cv_max') {
            di as error "{bf:hddid}: stored e(clime_nfolds_cv_max) must be an integer >= 2"
            di as error "  Current postestimation guidance refuses to advertise malformed CLIME requested-fold metadata."
            exit 498
        }
        local _clime_eff_min = e(clime_nfolds_cv_effective_min)
        if missing(`_clime_eff_min') | ///
            `_clime_eff_min' != floor(`_clime_eff_min') | ///
            (`_clime_eff_min' != 0 & `_clime_eff_min' < 2) {
            di as error "{bf:hddid}: stored realized CLIME CV fold counts must be 0 or integers >= 2"
            di as error "  Current postestimation guidance refuses to advertise malformed CLIME realized-fold metadata."
            exit 498
        }
        local _clime_eff_max = e(clime_nfolds_cv_effective_max)
        if missing(`_clime_eff_max') | ///
            `_clime_eff_max' != floor(`_clime_eff_max') | ///
            (`_clime_eff_max' != 0 & `_clime_eff_max' < 2) {
            di as error "{bf:hddid}: stored realized CLIME CV fold counts must be 0 or integers >= 2"
            di as error "  Current postestimation guidance refuses to advertise malformed CLIME realized-fold metadata."
            exit 498
        }
        if `_clime_eff_min' > `_clime_eff_max' {
            di as error "{bf:hddid}: stored e(clime_nfolds_cv_effective_min) must not exceed e(clime_nfolds_cv_effective_max)"
            di as error "  Current postestimation guidance refuses to advertise inconsistent CLIME realized-fold metadata."
            exit 498
        }
        tempname _clime_cv_per_fold
        matrix `_clime_cv_per_fold' = e(clime_nfolds_cv_per_fold)
        if rowsof(`_clime_cv_per_fold') != 1 | ///
            colsof(`_clime_cv_per_fold') != `_k_disp' {
            di as error "{bf:hddid}: stored e(clime_nfolds_cv_per_fold) must be a 1 x k rowvector"
            di as error "  Got " rowsof(`_clime_cv_per_fold') " x " ///
                colsof(`_clime_cv_per_fold') "; current results expect k = `_k_disp'"
            exit 498
        }
        local _clime_pf_min = .
        local _clime_pf_max = .
        forvalues _kk = 1/`_k_disp' {
            local _clime_pf_val = `_clime_cv_per_fold'[1, `_kk']
            if missing(`_clime_pf_val') | ///
                `_clime_pf_val' != floor(`_clime_pf_val') | ///
                (`_clime_pf_val' != 0 & `_clime_pf_val' < 2) {
                di as error "{bf:hddid}: stored realized CLIME CV fold counts must be 0 or integers >= 2"
                di as error "  Current postestimation guidance found e(clime_nfolds_cv_per_fold)[1,`_kk'] = " ///
                    %9.0f `_clime_pf_val'
                exit 498
            }
            if `_clime_pf_val' > `_clime_nfolds_cv_max' {
                di as error "{bf:hddid}: stored realized CLIME CV fold counts must not exceed e(clime_nfolds_cv_max)"
                di as error "  Current postestimation guidance found fold `_kk' effective count = " ///
                    %9.0f `_clime_pf_val' " but requested max = " ///
                    %9.0f `_clime_nfolds_cv_max'
                exit 498
            }
            if missing(`_clime_pf_min') | `_clime_pf_val' < `_clime_pf_min' {
                local _clime_pf_min = `_clime_pf_val'
            }
            if missing(`_clime_pf_max') | `_clime_pf_val' > `_clime_pf_max' {
                local _clime_pf_max = `_clime_pf_val'
            }
        }
        if `_clime_pf_min' != `_clime_eff_min' {
            di as error "{bf:hddid}: stored e(clime_nfolds_cv_effective_min) must match e(clime_nfolds_cv_per_fold)"
            di as error "  Current postestimation guidance found min(per-fold) = " ///
                %9.0f `_clime_pf_min' " but e(clime_nfolds_cv_effective_min) = " ///
                %9.0f `_clime_eff_min'
            exit 498
        }
        if `_clime_pf_max' != `_clime_eff_max' {
            di as error "{bf:hddid}: stored e(clime_nfolds_cv_effective_max) must match e(clime_nfolds_cv_per_fold)"
            di as error "  Current postestimation guidance found max(per-fold) = " ///
                %9.0f `_clime_pf_max' " but e(clime_nfolds_cv_effective_max) = " ///
                %9.0f `_clime_eff_max'
            exit 498
        }
            di as error "  Inspect {bf:e(clime_nfolds_cv_max)}, {bf:e(clime_nfolds_cv_effective_min)},"
            di as error "  {bf:e(clime_nfolds_cv_effective_max)}, and {bf:e(clime_nfolds_cv_per_fold)}"
            di as error "  for the published retained-sample CLIME/precision-step provenance."
        }
    }
    capture confirm scalar e(rank)
    local _has_rank = (_rc == 0)
    if `_has_rank' {
        local _rank_disp = e(rank)
        if missing(`_rank_disp') | ///
            `_rank_disp' < 0 | ///
            `_rank_disp' > `_xcount' | ///
            `_rank_disp' != floor(`_rank_disp') {
            di as error "{bf:hddid}: stored e(rank) must be a finite integer between 0 and the beta dimension"
            if `_current_result_surface' {
                di as error "  Current postestimation guidance refuses to advertise malformed covariance-rank metadata."
            }
            else {
                di as error "  Legacy direct unsupported postestimation refuses to advertise malformed covariance-rank metadata."
            }
            exit 498
        }
        tempname _V_rank
        mata: st_numscalar("`_V_rank'", rank(st_matrix("e(V)")))
        if `_rank_disp' != scalar(`_V_rank') {
            di as error "{bf:hddid}: stored e(rank) must equal rank(e(V))"
            if `_current_result_surface' {
                di as error "  Current postestimation guidance refuses to advertise an internally inconsistent beta covariance surface."
            }
            else {
                di as error "  Legacy direct unsupported postestimation refuses to advertise an internally inconsistent beta covariance surface."
            }
            exit 498
        }
    }
    capture confirm matrix e(tc)
    local _has_tc = (_rc == 0)
    local _tc_same_sign = 0
    local _tc_zero_shortcut = `_ciuniform_zero_shortcut'

    if `_current_result_surface' & !`_has_tc' {
        capture confirm matrix e(z0)
        local _has_z0_bundle = (_rc == 0)
        if `_has_z0_bundle' {
            local _curr_np_missing ""
            capture confirm matrix e(gdebias)
            if _rc {
                local _curr_np_missing `"`_curr_np_missing' e(gdebias)"'
            }
            capture confirm matrix e(stdg)
            if _rc {
                local _curr_np_missing `"`_curr_np_missing' e(stdg)"'
            }
            capture confirm matrix e(CIuniform)
            if _rc {
                local _curr_np_missing `"`_curr_np_missing' e(CIuniform)"'
            }
            local _curr_np_missing `"`_curr_np_missing' e(tc)"'
            capture confirm matrix e(CIpoint)
            if _rc {
                local _curr_np_missing `"`_curr_np_missing' e(CIpoint)"'
            }
            if `"`_curr_np_missing'"' != "" {
                di as error "{bf:hddid}: current saved-results surfaces with stored e(z0) require bundled e(gdebias), e(stdg), e(CIuniform), e(tc), and e(CIpoint)"
                di as error "  Current postestimation guidance must reject incomplete published z0 surfaces before ancillary seed()/alpha()/nboot() cmdline checks."
                exit 498
            }
        }
        di as error "{bf:hddid}: current results require stored e(tc)"
        di as error "  Current direct unsupported postestimation must validate the bootstrap critical-value provenance behind the published {bf:e(CIuniform)} interval object before continuing."
        exit 498
    }

    if `_has_tc' {
        tempname _tc_disp
        matrix `_tc_disp' = e(tc)
        local _tc_names_actual : colnames `_tc_disp'
        local _tc_names_actual : list retokenize _tc_names_actual
        if rowsof(`_tc_disp') != 1 | colsof(`_tc_disp') != 2 | ///
            missing(`_tc_disp'[1,1]) | missing(`_tc_disp'[1,2]) {
            di as error "{bf:hddid}: stored e(tc) must be a finite 1 x 2 rowvector"
            di as error "  Current postestimation guidance refuses to advertise malformed bootstrap provenance metadata."
            exit 498
        }
        if `"`_tc_names_actual'"' != "tc_lower tc_upper" {
            di as error "{bf:hddid}: stored e(tc) must use colnames {bf:tc_lower tc_upper}"
            di as error "  Current postestimation guidance refuses to advertise ambiguous bootstrap provenance metadata: {bf:`_tc_names_actual'}"
            exit 498
        }
        if `_tc_disp'[1,1] > `_tc_disp'[1,2] {
            di as error "{bf:hddid}: stored e(tc) must satisfy lower <= upper"
            di as error "  Current postestimation guidance refuses to advertise descending bootstrap-provenance endpoints."
            exit 498
        }
        local _tc_same_sign = (`_tc_disp'[1,1] > 0 | `_tc_disp'[1,2] < 0)
    }
    capture confirm scalar e(qq)
    local _has_qq = (_rc == 0)
    if `_current_result_surface' & `_has_qq' == 0 {
        local _qq_disp = .
        capture confirm matrix e(z0)
        if _rc == 0 {
            tempname _hddid_estat_z0width_probe
            matrix `_hddid_estat_z0width_probe' = e(z0)
            if rowsof(`_hddid_estat_z0width_probe') == 1 & ///
                colsof(`_hddid_estat_z0width_probe') >= 1 {
                local _qq_disp = colsof(`_hddid_estat_z0width_probe')
            }
        }
        if missing(`_qq_disp') {
            di as error "{bf:hddid}: current results require stored e(qq) or a published z0-grid width"
            di as error "  Reason: current hddid postestimation guidance validates the published pointwise intervals and the published nonparametric lower/upper interval object against the nonparametric grid width encoded in stored e(qq) or e(z0)."
            exit 498
        }
    }
    if `_has_qq' {
        local _qq_disp = e(qq)
        if `_current_result_surface' & ///
            (missing(`_qq_disp') | `_qq_disp' < 1 | ///
            `_qq_disp' != floor(`_qq_disp')) {
            di as error "{bf:hddid}: stored e(qq) must be a finite integer >= 1"
            di as error "  Current postestimation guidance refuses to advertise malformed nonparametric-grid metadata."
            exit 498
        }
    }
    if `_current_result_surface' {
        capture confirm matrix e(CIpoint)
        if _rc != 0 {
            di as error "{bf:hddid}: current results require stored e(CIpoint)"
            di as error "  Reason: current hddid postestimation guidance points users to the published pointwise intervals and the published nonparametric lower/upper interval object, so it will not advertise a malformed current surface that omits the pointwise confidence matrix."
            exit 498
        }
        tempname _CIpoint_disp
        matrix `_CIpoint_disp' = e(CIpoint)
        if rowsof(`_CIpoint_disp') != 2 | ///
            colsof(`_CIpoint_disp') != `_p_disp' + `_qq_disp' {
            di as error "{bf:hddid}: stored e(CIpoint) must be 2 x (p + qq)"
            di as error "  Got " rowsof(`_CIpoint_disp') " x " ///
                colsof(`_CIpoint_disp') "; current results expect p + qq = " ///
                `_p_disp' + `_qq_disp'
            exit 498
        }
        local _cipoint_rownames_actual : rownames `_CIpoint_disp'
        local _cipoint_rownames_actual : list retokenize _cipoint_rownames_actual
        if `"`_cipoint_rownames_actual'"' != "lower upper" {
            di as error "{bf:hddid}: stored e(CIpoint) must use rownames {bf:lower upper}"
            di as error "  Current postestimation guidance refuses to advertise ambiguous pointwise interval endpoints: {bf:`_cipoint_rownames_actual'}"
            exit 498
        }
        capture confirm matrix e(xdebias)
        if _rc != 0 {
            di as error "{bf:hddid}: current results require stored e(xdebias)"
            di as error "  Reason: current hddid postestimation guidance points users to the published beta surface, so it will not advertise malformed current pointwise intervals without the posted debiased beta vector."
            exit 498
        }
        capture confirm matrix e(stdx)
        if _rc != 0 {
            di as error "{bf:hddid}: current results require stored e(stdx)"
            di as error "  Reason: current hddid postestimation guidance points users to the published beta surface, so it will not advertise malformed current pointwise intervals without the posted beta standard-error vector."
            exit 498
        }
        tempname _xdebias_disp _stdx_disp
        matrix `_xdebias_disp' = e(xdebias)
        matrix `_stdx_disp' = e(stdx)
        if rowsof(`_xdebias_disp') != 1 | colsof(`_xdebias_disp') != `_p_disp' {
            di as error "{bf:hddid}: stored e(xdebias) must be a 1 x p rowvector"
            di as error "  Current postestimation guidance refuses to advertise malformed beta point-estimate metadata."
            exit 498
        }
        if rowsof(`_stdx_disp') != 1 | colsof(`_stdx_disp') != `_p_disp' {
            di as error "{bf:hddid}: stored e(stdx) must be a 1 x p rowvector"
            di as error "  Current postestimation guidance refuses to advertise malformed beta standard-error metadata."
            exit 498
        }
        mata: st_local("_hddid_bad_xdebias", strofreal(hasmissing(st_matrix("`_xdebias_disp'"))))
        if real(`"`_hddid_bad_xdebias'"') == 1 {
            di as error "{bf:hddid}: stored e(xdebias) must be finite"
            di as error "  Current postestimation guidance refuses to advertise malformed beta point-estimate metadata with missing/nonfinite entries."
            exit 498
        }
        mata: st_local("_hddid_bad_stdx", strofreal(hasmissing(st_matrix("`_stdx_disp'"))))
        if real(`"`_hddid_bad_stdx'"') == 1 {
            di as error "{bf:hddid}: stored e(stdx) must be finite"
            di as error "  Current postestimation guidance refuses to advertise malformed beta standard-error metadata with missing/nonfinite entries."
            exit 498
        }
        tempname _min_stdx_disp
        mata: st_numscalar("`_min_stdx_disp'", min(st_matrix("`_stdx_disp'")))
        if scalar(`_min_stdx_disp') < 0 {
            di as error "{bf:hddid}: stored e(stdx) must be nonnegative"
            di as error "  Current postestimation guidance refuses to advertise a malformed current parametric standard-error surface; min entry = " ///
                %12.8g scalar(`_min_stdx_disp')
            exit 498
        }
        tempname _vstdx_gap _vstdx_scale _vstdx_tol
        mata: st_numscalar("`_vstdx_gap'", ///
            max(abs(diagonal(st_matrix("e(V)"))' :- ///
            (st_matrix("`_stdx_disp'") :* st_matrix("`_stdx_disp'"))))); ///
            st_numscalar("`_vstdx_scale'", ///
            max((1, max(abs(diagonal(st_matrix("e(V)"))')), ///
            max(abs(st_matrix("`_stdx_disp'") :* st_matrix("`_stdx_disp'"))))))
        scalar `_vstdx_tol' = 1e-12 * scalar(`_vstdx_scale')
        if scalar(`_vstdx_gap') > scalar(`_vstdx_tol') {
            di as error "{bf:hddid}: stored diag(e(V)) must equal e(stdx)^2"
            di as error "  Current postestimation guidance refuses to advertise an internally inconsistent parametric covariance diagonal; max gap = " ///
                %12.8g scalar(`_vstdx_gap') " exceeded tolerance = " ///
                %12.8g scalar(`_vstdx_tol')
            exit 498
        }
        mata: st_local("_hddid_bad_cipoint", strofreal(hasmissing(st_matrix("`_CIpoint_disp'"))))
        if real(`"`_hddid_bad_cipoint'"') == 1 {
            di as error "{bf:hddid}: stored e(CIpoint) must be finite"
            di as error "  Current postestimation guidance refuses to advertise malformed current pointwise interval metadata with missing/nonfinite entries."
            exit 498
        }
        capture confirm matrix e(CIuniform)
        if _rc != 0 {
            di as error "{bf:hddid}: current results require stored e(CIuniform)"
            di as error "  Reason: current hddid postestimation guidance points users to the published pointwise intervals and the published nonparametric lower/upper interval object, so it will not advertise a malformed current surface that omits the published nonparametric interval object."
            exit 498
        }
        tempname _CIuniform_disp
        matrix `_CIuniform_disp' = e(CIuniform)
        if rowsof(`_CIuniform_disp') != 2 | ///
            colsof(`_CIuniform_disp') != `_qq_disp' {
            di as error "{bf:hddid}: stored e(CIuniform) must be 2 x qq"
            di as error "  Got " rowsof(`_CIuniform_disp') " x " ///
                colsof(`_CIuniform_disp') "; current results expect qq = " ///
                `_qq_disp'
            exit 498
        }
        local _ciuniform_rownames_actual : rownames `_CIuniform_disp'
        local _ciuniform_rownames_actual : list retokenize _ciuniform_rownames_actual
        if `"`_ciuniform_rownames_actual'"' != "lower upper" {
            di as error "{bf:hddid}: stored e(CIuniform) must use rownames {bf:lower upper}"
            di as error "  Current postestimation guidance refuses to advertise ambiguous nonparametric interval endpoints: {bf:`_ciuniform_rownames_actual'}"
            exit 498
        }
        mata: st_local("_hddid_bad_ciuniform", strofreal(hasmissing(st_matrix("`_CIuniform_disp'"))))
        if real(`"`_hddid_bad_ciuniform'"') == 1 {
            di as error "{bf:hddid}: stored e(CIuniform) must be finite"
            di as error "  Current postestimation guidance refuses to advertise a malformed current nonparametric interval object with missing/nonfinite entries."
            exit 498
        }
        tempname _ciuniform_order_gap
        mata: st_numscalar("`_ciuniform_order_gap'", ///
            max(st_matrix("`_CIuniform_disp'")[1,.] :- ///
            st_matrix("`_CIuniform_disp'")[2,.]))
        if scalar(`_ciuniform_order_gap') > 0 {
            di as error "{bf:hddid}: stored e(CIuniform) lower row must not exceed upper row"
            di as error "  Current postestimation guidance refuses to advertise a malformed current nonparametric interval object; max(lower-upper) = " ///
                %12.8g scalar(`_ciuniform_order_gap')
            exit 498
        }
        capture confirm matrix e(gdebias)
        if _rc != 0 {
            di as error "{bf:hddid}: current results require stored e(gdebias)"
            di as error "  Reason: current hddid postestimation guidance points users to the published nonparametric surface, so it will not advertise a malformed current surface that omits the debiased omitted-intercept z-varying values."
            exit 498
        }
        capture confirm matrix e(stdg)
        if _rc != 0 {
            di as error "{bf:hddid}: current results require stored e(stdg)"
            di as error "  Reason: current hddid postestimation guidance points users to the published nonparametric surface, so it will not advertise a malformed current surface that omits the posted omitted-intercept z-varying standard errors."
            exit 498
        }
        capture confirm matrix e(z0)
        if _rc != 0 {
            di as error "{bf:hddid}: current results require stored e(z0)"
            di as error "  Reason: current hddid postestimation guidance points users to the published nonparametric surface on the stored evaluation grid, so it will not advertise a malformed current surface that omits that grid."
            exit 498
        }
        tempname _gdebias_disp _z0_disp
        matrix `_gdebias_disp' = e(gdebias)
        if rowsof(`_gdebias_disp') != 1 | colsof(`_gdebias_disp') != `_qq_disp' {
            di as error "{bf:hddid}: stored e(gdebias) must be a 1 x qq rowvector"
            di as error "  Got " rowsof(`_gdebias_disp') " x " ///
                colsof(`_gdebias_disp') "; current results expect qq = " ///
                `_qq_disp'
            exit 498
        }
        mata: st_local("_hddid_bad_gdebias_disp", strofreal(hasmissing(st_matrix("`_gdebias_disp'"))))
        if real(`"`_hddid_bad_gdebias_disp'"') == 1 {
            di as error "{bf:hddid}: stored e(gdebias) must be finite"
            di as error "  Current postestimation guidance refuses to advertise a malformed current nonparametric point-estimate surface with missing/nonfinite entries."
            exit 498
        }
        tempname _z0_disp
        matrix `_z0_disp' = e(z0)
        if rowsof(`_z0_disp') != 1 | colsof(`_z0_disp') != `_qq_disp' {
            di as error "{bf:hddid}: stored e(z0) must be a 1 x qq rowvector"
            di as error "  Got " rowsof(`_z0_disp') " x " ///
                colsof(`_z0_disp') "; current results expect qq = " ///
                `_qq_disp'
            exit 498
        }
        mata: st_local("_hddid_bad_z0_disp", strofreal(hasmissing(st_matrix("`_z0_disp'"))))
        if real(`"`_hddid_bad_z0_disp'"') == 1 {
            di as error "{bf:hddid}: stored e(z0) must be finite"
            di as error "  Current postestimation guidance refuses to advertise a malformed current evaluation grid with missing/nonfinite entries."
            exit 498
        }
        tempname _stdg_disp
        matrix `_stdg_disp' = e(stdg)
        if rowsof(`_stdg_disp') != 1 | colsof(`_stdg_disp') != `_qq_disp' {
            di as error "{bf:hddid}: stored e(stdg) must be a 1 x qq rowvector"
            di as error "  Got " rowsof(`_stdg_disp') " x " ///
                colsof(`_stdg_disp') "; current results expect qq = " ///
                `_qq_disp'
            exit 498
        }
        mata: st_local("_hddid_bad_stdg_disp", strofreal(hasmissing(st_matrix("`_stdg_disp'"))))
        if real(`"`_hddid_bad_stdg_disp'"') == 1 {
            di as error "{bf:hddid}: stored e(stdg) must be finite"
            di as error "  Current postestimation guidance refuses to advertise a malformed current nonparametric standard-error surface with missing/nonfinite entries."
            exit 498
        }
        tempname _min_stdg_disp
        mata: st_numscalar("`_min_stdg_disp'", min(st_matrix("e(stdg)")))
        if scalar(`_min_stdg_disp') < 0 {
            di as error "{bf:hddid}: stored e(stdg) must be nonnegative"
            di as error "  Current postestimation guidance refuses to advertise a malformed current nonparametric standard-error surface; min entry = " ///
                %12.8g scalar(`_min_stdg_disp')
            exit 498
        }
        local _z0_names_actual : colnames `_z0_disp'
        local _z0_names_actual : list retokenize _z0_names_actual
        // The numeric e(z0) rowvector plus aligned nonparametric column order
        // define the advertised grid. Unsupported postestimation guidance does
        // not require the e(z0) labels to numerically encode that same grid.
        if `"`_method'"' == "Tri" {
            local _tri_z0_outside_disp ""
            forvalues _j = 1/`_qq_disp' {
                local _tri_z0_j = `_z0_disp'[1, `_j']
                if `_tri_z0_j' < `_z_support_min' | `_tri_z0_j' > `_z_support_max' {
                    local _tri_z0_j_disp : display %21.15g `_tri_z0_j'
                    local _tri_z0_outside_disp ///
                        `"`_tri_z0_outside_disp' `_tri_z0_j_disp'"'
                }
            }
            local _tri_z0_outside_disp : list retokenize _tri_z0_outside_disp
            if `"`_tri_z0_outside_disp'"' != "" {
                di as error "{bf:hddid}: stored e(z0) must lie within stored Tri support"
                di as error "  Current postestimation found stored support = [" ///
                    %12.8g `_z_support_min' ", " %12.8g `_z_support_max' ///
                    "] and out-of-support e(z0) point(s):`_tri_z0_outside_disp'"
                di as error "  Reason: the published trigonometric basis is defined on the support-normalized coordinate, so current postestimation guidance cannot advertise the omitted-intercept z-varying surface off that stored domain."
                exit 498
            }
        }
        local _cipoint_all_names : colnames `_CIpoint_disp'
        local _cipoint_x_names_actual ""
        forvalues _j = 1/`_p_disp' {
            local _cipoint_x_name_j : word `_j' of `_cipoint_all_names'
            local _cipoint_x_names_actual ///
                `"`_cipoint_x_names_actual' `_cipoint_x_name_j'"'
        }
        local _cipoint_x_names_actual = lower(strtrim(`"`_cipoint_x_names_actual'"'))
        local _cipoint_x_names_actual : list retokenize _cipoint_x_names_actual
        local _cipoint_z_names_actual ""
        forvalues _j = 1/`_qq_disp' {
            local _cipoint_name_idx = `_p_disp' + `_j'
            local _cipoint_name_j : word `_cipoint_name_idx' of `_cipoint_all_names'
            local _cipoint_z_names_actual ///
                `"`_cipoint_z_names_actual' `_cipoint_name_j'"'
        }
        local _cipoint_z_names_actual : list retokenize _cipoint_z_names_actual
        local _gdebias_names_actual : colnames e(gdebias)
        local _gdebias_names_actual : list retokenize _gdebias_names_actual
        local _stdg_names_actual : colnames e(stdg)
        local _stdg_names_actual : list retokenize _stdg_names_actual
        local _ciuniform_names_actual : colnames `_CIuniform_disp'
        local _ciuniform_names_actual : list retokenize _ciuniform_names_actual
        if `"`_cipoint_x_names_actual'"' != `"`_xvars_lc'"' {
            di as error "{bf:hddid}: stored e(CIpoint) beta column labels must match e(xvars)"
            di as error "  Current postestimation guidance refuses to advertise pointwise beta intervals on an ambiguous beta coordinate map: CIpoint(beta)={bf:`_cipoint_x_names_actual'}, xvars={bf:`_xvars_lc'}"
            exit 498
        }
        if `"`_gdebias_names_actual'"' != `"`_z0_names_actual'"' {
            di as error "{bf:hddid}: stored e(gdebias) colnames must match e(z0)"
            di as error "  Current postestimation guidance refuses to advertise nonparametric point estimates on an ambiguous grid: gdebias={bf:`_gdebias_names_actual'}, z0={bf:`_z0_names_actual'}"
            exit 498
        }
        if `"`_stdg_names_actual'"' != `"`_z0_names_actual'"' {
            di as error "{bf:hddid}: stored e(stdg) colnames must match e(z0)"
            di as error "  Current postestimation guidance refuses to advertise nonparametric standard errors on an ambiguous grid: stdg={bf:`_stdg_names_actual'}, z0={bf:`_z0_names_actual'}"
            exit 498
        }
        if `"`_cipoint_z_names_actual'"' != `"`_z0_names_actual'"' {
            di as error "{bf:hddid}: stored e(CIpoint) nonparametric column labels must match e(z0)"
            di as error "  Current postestimation guidance refuses to advertise pointwise intervals on an ambiguous grid: CIpoint(z)={bf:`_cipoint_z_names_actual'}, z0={bf:`_z0_names_actual'}"
            exit 498
        }
        if `"`_ciuniform_names_actual'"' != `"`_z0_names_actual'"' {
            di as error "{bf:hddid}: stored e(CIuniform) colnames must match e(z0)"
            di as error "  Current postestimation guidance refuses to advertise a nonparametric interval object on an ambiguous grid: CIuniform={bf:`_ciuniform_names_actual'}, z0={bf:`_z0_names_actual'}"
            exit 498
        }
        if `_has_tc' {
            tempname _ciuniform_gap _ciuniform_scale
            mata: _hddid_ciuniform_actual = st_matrix("e(CIuniform)"); _hddid_gdebias = st_matrix("e(gdebias)"); _hddid_stdg = st_matrix("e(stdg)"); _hddid_tc = st_matrix("e(tc)"); _hddid_ciuniform_oracle = (_hddid_gdebias :+ _hddid_tc[1, 1] * _hddid_stdg) \ (_hddid_gdebias :+ _hddid_tc[1, 2] * _hddid_stdg); st_numscalar("`_ciuniform_gap'", max(abs(_hddid_ciuniform_actual :- _hddid_ciuniform_oracle))); st_numscalar("`_ciuniform_scale'", max((1, max(abs(_hddid_ciuniform_actual)), max(abs(_hddid_ciuniform_oracle)))))
            if scalar(`_ciuniform_gap') > 1e-12 * scalar(`_ciuniform_scale') {
                di as error "{bf:hddid}: stored e(CIuniform) must equal the lower/upper rows implied by e(gdebias), e(stdg), and e(tc)"
                di as error "  Current postestimation guidance refuses to advertise malformed nonparametric interval-object metadata on a current saved-results surface."
                exit 498
            }
        }
        tempname _cipoint_gap _cipoint_scale _cipoint_tol _zcrit_disp
        scalar `_zcrit_disp' = invnormal(1 - `_alpha' / 2)
        mata: st_numscalar("`_cipoint_gap'", ///
            max(abs(st_matrix("`_CIpoint_disp'") :- ( ///
            (st_matrix("`_xdebias_disp'") :- st_numscalar("`_zcrit_disp'") :* st_matrix("`_stdx_disp'"), ///
             st_matrix("e(gdebias)") :- st_numscalar("`_zcrit_disp'") :* st_matrix("e(stdg)")) \ ///
            (st_matrix("`_xdebias_disp'") :+ st_numscalar("`_zcrit_disp'") :* st_matrix("`_stdx_disp'"), ///
             st_matrix("e(gdebias)") :+ st_numscalar("`_zcrit_disp'") :* st_matrix("e(stdg)")) )))); ///
            st_numscalar("`_cipoint_scale'", ///
            max((1, max(abs(st_matrix("`_CIpoint_disp'"))), ///
            max(abs((st_matrix("`_xdebias_disp'") :- st_numscalar("`_zcrit_disp'") :* st_matrix("`_stdx_disp'"), ///
                     st_matrix("e(gdebias)") :- st_numscalar("`_zcrit_disp'") :* st_matrix("e(stdg)")) \ ///
                    (st_matrix("`_xdebias_disp'") :+ st_numscalar("`_zcrit_disp'") :* st_matrix("`_stdx_disp'"), ///
                     st_matrix("e(gdebias)") :+ st_numscalar("`_zcrit_disp'") :* st_matrix("e(stdg)")))))))
        scalar `_cipoint_tol' = 1e-12 * scalar(`_cipoint_scale')
        if scalar(`_cipoint_gap') > scalar(`_cipoint_tol') {
            di as error "{bf:hddid}: stored e(CIpoint) must equal the pointwise intervals implied by e(xdebias), e(stdx), e(gdebias), e(stdg), and e(alpha)"
            di as error "  Current postestimation guidance refuses to advertise malformed pointwise interval metadata on a current saved-results surface."
            exit 498
        }
    }
    di as error "{bf:hddid}: estat is not supported."
    di as error "  Reason: hddid publishes parametric and nonparametric inference objects, but no unified estat contract is defined."
    if `"`_hddid_estopt_raw'"' != "" {
        di as error "  Offending estimator-style input: " ///
            as text `"`_hddid_estopt_raw'"'
        di as error "  Reason: {bf:method()} only picks the {bf:Pol}/{bf:Tri} sieve basis; it is not an estimator-family switch."
        di as error "  {bf:hddid} implements the paper's doubly robust AIPW estimator throughout"
        if `"`_hddid_estopt_canonical'"' == "" {
            _hddid_postest_show_invalid, raw(`"`_hddid_estopt_raw'"')
        }
    }
    di as error "  Use {bf:e(sample)} only when the original estimation data are still in memory."
    di as error "  After {bf:estimates use}, rely on the stored {bf:e()} result surface."
    di as error "  A live retained-sample count may no longer be available there."
    di as error "  Inspect {bf:e(b)}, {bf:e(V)}, {bf:e(xdebias)}, and {bf:e(stdx)} for the beta block."
    di as error "  Inspect {bf:e(gdebias)}, {bf:e(stdg)}, and {bf:e(z0)} for the stored omitted-intercept z-varying surface."
    di as error "  Inspect {bf:e(CIpoint)} for the published pointwise intervals: its first {bf:e(p)} columns are the beta block in {bf:e(xvars)} order."
    di as error "  Its remaining {bf:e(qq)} columns are the omitted-intercept z-varying block aligned with {bf:e(z0)}."
    if !`_has_tc' {
        di as error "  Inspect {bf:e(CIuniform)} for the published nonparametric interval object."
        di as error "  When available, inspect {bf:e(tc)} for bootstrap critical-value provenance only."
    }
    else {
        di as error "  Inspect {bf:e(CIuniform)} for the published nonparametric interval object."
        if `_tc_zero_shortcut' {
            di as error "  Inspect {bf:e(tc)} only as the deterministic zero-SE shortcut sentinel showing {bf:e(CIuniform)} collapsed to {bf:e(gdebias)}."
        }
        else {
            di as error "  Inspect {bf:e(tc)} for the bootstrap critical-value provenance behind {bf:e(CIuniform)}."
        }
    }
    if !`_has_nboot' {
        di as error "  When available, inspect {bf:e(nboot)} for bootstrap replication-count provenance only."
    }
    else {
        if `_tc_zero_shortcut' {
            di as error "  Inspect {bf:e(nboot)} only as preserved command provenance; no studentized Gaussian-bootstrap draws were used for this degenerate zero-SE shortcut."
        }
        else {
            di as error "  Inspect {bf:e(nboot)} for the bootstrap replication count behind {bf:e(CIuniform)}."
        }
    }
    if !`_has_alpha' {
        if `_tc_zero_shortcut' {
            di as error "  When available, inspect {bf:e(alpha)} as the shared scalar that still calibrates the analytic {bf:e(CIpoint)} pointwise intervals."
            di as error "  On this degenerate zero-SE shortcut, it does not recalibrate the collapsed {bf:e(CIuniform)} object because that published nonparametric interval object already equals {bf:e(gdebias)}."
            di as error "  No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  When available, inspect {bf:e(alpha)} for the shared significance level behind {bf:e(CIpoint)} and the realized {bf:e(tc)}/{bf:e(CIuniform)} interval object."
        }
    }
    else {
        if `_tc_zero_shortcut' {
            di as error "  Inspect {bf:e(alpha)} as the shared scalar that still calibrates the analytic {bf:e(CIpoint)} pointwise intervals."
            di as error "  On this degenerate zero-SE shortcut, it does not recalibrate the collapsed {bf:e(CIuniform)} object because that published nonparametric interval object already equals {bf:e(gdebias)}."
            di as error "  No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Inspect {bf:e(alpha)} for the shared significance level behind {bf:e(CIpoint)} and the realized {bf:e(tc)}/{bf:e(CIuniform)} interval object."
        }
    }
    di as error "  The paper target is {bf:x0'beta + f(z0)}, but the current public nonparametric surface omits the separate intercept {bf:a0}."
    di as error "  Form the full linear combination of {bf:x0} with the beta block in {bf:e(b)} or {bf:e(xdebias)} only in the published {bf:e(xvars)} order."
    di as error "  Use {bf:e(gdebias)} only for centered comparisons on the stored {bf:e(z0)} grid."
    di as error "  because {bf:hddid} does not currently publish {bf:e(a0)}, {bf:e(gdebias)} alone does not recover a full ATT/{bf:f(z0)} level."
    if !`_has_tc' {
        di as error "  Treat {bf:e(CIuniform)} as the published nonparametric interval object, i.e. the published lower/upper interval object on the stored omitted-intercept z-varying surface."
        di as error "  Legacy saved results without {bf:e(tc)} keep that posted object but do not expose the duplicate bootstrap critical-value provenance behind it."
    }
    else {
        if `_tc_zero_shortcut' {
            di as error "  Treat {bf:e(CIuniform)} as the published nonparametric interval object, and on this degenerate zero-SE shortcut it collapses exactly to {bf:e(gdebias)}."
            di as error "  The current {bf:e(tc)} = {bf:(0, 0)} pair is the deterministic zero-SE shortcut sentinel, not bootstrap critical-value provenance."
            di as error "  No studentized Gaussian-bootstrap draws were used for the published nonparametric interval object."
        }
        else {
            di as error "  Treat {bf:e(CIuniform)} as the published nonparametric interval object implied by {bf:e(gdebias)}, {bf:e(stdg)}, and {bf:e(tc)}."
            di as error "  The current {bf:e(tc)} object records the ordered lower/upper bootstrap critical-value provenance behind that posted interval object."
            di as error "  Under the current path, those stored endpoints are the rowwise-envelope lower/upper studentized-process pair {bf:(min_j lower_j, max_j upper_j)}."
            di as error "  Saved results that also store e(tc) carry the same ordered lower/upper bootstrap provenance through that posted interval object."
            di as error "  Interpret this as ordered lower/upper bootstrap critical-value provenance, not a symmetric cutoff pair."
            if `_tc_same_sign' {
                di as error "  Caveat: same-sign e(tc) can place the published CIuniform object entirely above or below the omitted-intercept z-varying surface."
                // Retired tc traceability token kept for legacy regression coverage only:
                // same-sign e(tc) can place the published CIuniform object entirely above or below f(z0)
            }
        }
    }
    di as error "  It is not a paper-proven simultaneous-confidence band."
    exit 198
end
