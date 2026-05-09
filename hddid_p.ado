capture program drop _hddid_p_postest_parse_estopt
capture program drop _hddid_p_postest_show_invalid
capture program drop _hddid_p_postest_parse_methodopt
program define _hddid_p_postest_parse_methodopt, rclass
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
                // Quoted bare estimator-family tokens are handled
                // downstream by the estimator-style parser.
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
    local _hddid_methodscan_lc `"`_hddid_opts_raw_lc'"'
    // Remove nested method() text inside estimator-family payloads
    // so that the method-domain precheck does not intercept them.
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
        "(^|[ ,])(method[ ]*=[ ]*[^ ,]*)")
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

program define _hddid_p_postest_parse_estopt, rclass
    syntax , OPTSRAW(string asis)

    return clear
    local _hddid_opts_raw `optsraw'
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(92) + char(34), char(34), .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(92) + char(39), char(39), .)
    // Normalize whitespace for consistent parsing.
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(9), " ", .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(10), " ", .)
    local _hddid_opts_raw = ///
        subinstr(`"`_hddid_opts_raw'"', char(13), " ", .)
    local _hddid_opts_raw_orig = ///
        strtrim(subinstr(`"`_hddid_opts_raw'"', ",", " ", .))
    local _hddid_opts_raw = lower(`"`_hddid_opts_raw_orig'"')
    // Match leading bare single-quoted estimator tokens before
    // alias-assignment patterns.
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
    // Match empty quoted estimator payloads before doubled-quote collapsing.
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
    // Match empty quoted alias payloads before quote-stripping.
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
    // Match method() text within alias assignments before quote-stripping.
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
    // Quoted parenthesized alias payloads followed by method()
    // exclude method() from the alias echo.
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
    // Match quoted parenthesized alias assignments before quote-stripping.
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
    // Quoted parenthesized alias tokens followed by method()
    // exclude method() from the alias echo.
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
    // Match quoted parenthesized alias assignments with trailing
    // text before quote-stripping.
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
    // Match quoted nonparenthesized alias assignments before
    // quote-stripping.
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
    // Match quoted bare estimator-family tokens before if/in qualifiers.
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
    // Quoted parenthesized and doubly parenthesized estimator-family
    // tokens are classified before quote-stripping.
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
    // Match quoted estimator assignments with trailing text before
    // quote-stripping.
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
    // Match quoted parenthesized estimator assignments with trailing
    // text before quote-stripping.
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
    // Parenthesized and doubly parenthesized estimator-family tokens
    // are classified before generic parenthesized-invalid branches.
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
    // Trailing t()/tr() after estimator=(...) is retained in the
    // full malformed token.
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
    // An empty estimator= assignment fails on the token itself;
    // subsequent options are excluded.  estimator=method() with an
    // invalid sieve-basis name retains the full right-hand side.
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
    local _hddid_estopt_lparen_follow_1 ///
        "(c|cf|cfo|cfor|cform|cforma|cformat|ci|cit|city|cityp|citype|"
    local _hddid_estopt_lparen_follow_2 ///
        "p|pf|pfo|pfor|pform|pforma|pformat|s|sf|sfo|sfor|sform|sforma|sformat|"
    local _hddid_estopt_lparen_follow_3 ///
        "fvwr|fvwra|fvwrap|fvwrapo|fvwrapon|tre|trea|treat|x|z|z0|k|l|le|lev|leve|level|"
    local _hddid_estopt_lparen_follow_4 ///
        "m|me|met|meth|metho|method|q|alp|alph|alpha|pi|pih|piha|pihat|"
    local _hddid_estopt_lparen_follow_5 ///
        "phi1|phi1h|phi1ha|phi1hat|phi0|phi0h|phi0ha|phi0hat|seed|sep|sepa|separ|"
    local _hddid_estopt_lparen_follow_6 ///
        "separa|separat|separato|separator|depn|depna|depnam|depname|nb|nbo|nboo|nboot)[ ]*[(]"
    local _hddid_estopt_lparen_follow ///
        `"`_hddid_estopt_lparen_follow_1'`_hddid_estopt_lparen_follow_2'`_hddid_estopt_lparen_follow_3'`_hddid_estopt_lparen_follow_4'`_hddid_estopt_lparen_follow_5'`_hddid_estopt_lparen_follow_6'"'
    local _hddid_estopt_bare_follow_1 ///
        "(ab|abb|abbr|abbre|abbrev|allb|allba|allbas|allbase|allbasel|allbasele|"
    local _hddid_estopt_bare_follow_2 ///
        "allbaselev|allbaseleve|allbaselevel|allbaselevels|b|be|bet|beta|basel|basele|"
    local _hddid_estopt_bare_follow_3 ///
        "baselev|baseleve|baselevel|baselevels|cns|cnsr|cnsre|cnsrep|cnsrepo|cnsrepor|"
    local _hddid_estopt_bare_follow_4 ///
        "cnsreport|cod|codi|codin|coding|coefl|coefle|coefleg|coeflege|coeflegen|coeflegend|"
    local _hddid_estopt_bare_follow_5 ///
        "com|comp|compa|compar|compare|e|ef|efo|efor|eform|empty|emptyc|emptyce|emptycel|"
    local _hddid_estopt_bare_follow_6 ///
        "emptycell|emptycells|f|fi|fir|firs|first|fu|ful|full|fullc|fullcn|fullcns|fullcnsr|"
    local _hddid_estopt_bare_follow_7 ///
        "fullcnsre|fullcnsrep|fullcnsrepo|fullcnsrepor|fullcnsreport|fvl|fvla|fvlab|fvlabe|"
    local _hddid_estopt_bare_follow_8 ///
        "fvlabel|ls|lst|lstr|lstre|lstret|lstretch|ma|mar|mark|markd|markdo|markdow|markdown|"
    local _hddid_estopt_bare_follow_9 ///
        "noa|noab|noabb|noabbr|noabbre|noabbrev|not|nota|notab|notabl|notable|noempty|"
    local _hddid_estopt_bare_follow_10 ///
        "noemptyc|noemptyce|noemptycel|noemptycell|noemptycells|noo|noom|noomi|noomit|"
    local _hddid_estopt_bare_follow_11 ///
        "noomitt|noomitte|noomitted|nop|nopv|nopva|nopval|nopvalu|nopvalue|nopvalues|"
    local _hddid_estopt_bare_follow_12 ///
        "o|om|omi|omit|omitt|omitte|omitted|pl|plu|plus|se|sel|sele|seleg|selege|selegen|"
    local _hddid_estopt_bare_follow_13 ///
        "selegend|noci|nofv|nofvl|nofvla|nofvlab|nofvlabe|nofvlabel|noh|nohe|nohea|nohead|"
    local _hddid_estopt_bare_follow_14 ///
        "noheade|noheader|nols|nolst|nolstr|nolstre|nolstret|nolstretc|nolstretch|"
    local _hddid_estopt_bare_follow_15 ///
        "nof|nofi|nofir|nofirs|nofirst|ver|vers|versu|versus|verb|verbo|verbos|verbose|"
    local _hddid_estopt_bare_follow_16 ///
        "vsq|vsqu|vsqui|vsquis|vsquish)($|[ ])"
    local _hddid_estopt_bare_follow_a ///
        `"`_hddid_estopt_bare_follow_1'`_hddid_estopt_bare_follow_2'`_hddid_estopt_bare_follow_3'`_hddid_estopt_bare_follow_4'`_hddid_estopt_bare_follow_5'`_hddid_estopt_bare_follow_6'`_hddid_estopt_bare_follow_7'`_hddid_estopt_bare_follow_8'"'
    local _hddid_estopt_bare_follow_b ///
        `"`_hddid_estopt_bare_follow_9'`_hddid_estopt_bare_follow_10'`_hddid_estopt_bare_follow_11'`_hddid_estopt_bare_follow_12'`_hddid_estopt_bare_follow_13'`_hddid_estopt_bare_follow_14'`_hddid_estopt_bare_follow_15'`_hddid_estopt_bare_follow_16'"'
    local _hddid_estopt_bare_follow ///
        `"`_hddid_estopt_bare_follow_a'`_hddid_estopt_bare_follow_b'"'
    local _hddid_estopt_syntax_follow ///
        "((if|in)($|[ ])|([[][^]]*[]]))"
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
    // A complete estimator=(...) token is bounded before subsequent
    // options.
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
    // Trailing t()/tr() after estimator=(...) is retained in the
    // full malformed token.
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
        // Alias assignments are bounded at the equals sign when
        // followed by a separate option or syntax fragment.
        local _hddid_alias_lparen_follow_1 ///
            "^(c|cf|cfo|cfor|cform|cforma|cformat|ci|cit|city|cityp|citype|"
        local _hddid_alias_lparen_follow_2 ///
            "p|pf|pfo|pfor|pform|pforma|pformat|s|sf|sfo|sfor|sform|sforma|sformat|"
        local _hddid_alias_lparen_follow_3 ///
            "fvwr|fvwra|fvwrap|fvwrapo|fvwrapon|tre|trea|treat|x|z|z0|k|l|le|lev|leve|level|"
        local _hddid_alias_lparen_follow_4 ///
            "m|me|met|meth|metho|method|q|alp|alph|alpha|pi|pih|piha|pihat|"
        local _hddid_alias_lparen_follow_5 ///
            "phi1|phi1h|phi1ha|phi1hat|phi0|phi0h|phi0ha|phi0hat|seed|sep|sepa|separ|"
        local _hddid_alias_lparen_follow_6 ///
            "separa|separat|separato|separator|depn|depna|depnam|depname|nb|nbo|nboo|nboot)[ ]*[(]"
        local _hddid_alias_lparen_follow ///
            `"`_hddid_alias_lparen_follow_1'`_hddid_alias_lparen_follow_2'`_hddid_alias_lparen_follow_3'`_hddid_alias_lparen_follow_4'`_hddid_alias_lparen_follow_5'`_hddid_alias_lparen_follow_6'"'
        local _hddid_alias_bare_follow_1 ///
            "^(ab|abb|abbr|abbre|abbrev|allb|allba|allbas|allbase|allbasel|allbasele|"
        local _hddid_alias_bare_follow_2 ///
            "allbaselev|allbaseleve|allbaselevel|allbaselevels|b|be|bet|beta|basel|basele|"
        local _hddid_alias_bare_follow_3 ///
            "baselev|baseleve|baselevel|baselevels|cns|cnsr|cnsre|cnsrep|cnsrepo|cnsrepor|"
        local _hddid_alias_bare_follow_4 ///
            "cnsreport|cod|codi|codin|coding|coefl|coefle|coefleg|coeflege|coeflegen|coeflegend|"
        local _hddid_alias_bare_follow_5 ///
            "com|comp|compa|compar|compare|e|ef|efo|efor|eform|empty|emptyc|emptyce|emptycel|"
        local _hddid_alias_bare_follow_6 ///
            "emptycell|emptycells|f|fi|fir|firs|first|fu|ful|full|fullc|fullcn|fullcns|fullcnsr|"
        local _hddid_alias_bare_follow_7 ///
            "fullcnsre|fullcnsrep|fullcnsrepo|fullcnsrepor|fullcnsreport|fvl|fvla|fvlab|fvlabe|"
        local _hddid_alias_bare_follow_8 ///
            "fvlabel|ls|lst|lstr|lstre|lstret|lstretch|ma|mar|mark|markd|markdo|markdow|markdown|"
        local _hddid_alias_bare_follow_9 ///
            "noa|noab|noabb|noabbr|noabbre|noabbrev|not|nota|notab|notabl|notable|noempty|"
        local _hddid_alias_bare_follow_10 ///
            "noemptyc|noemptyce|noemptycel|noemptycell|noemptycells|noo|noom|noomi|noomit|"
        local _hddid_alias_bare_follow_11 ///
            "noomitt|noomitte|noomitted|nop|nopv|nopva|nopval|nopvalu|nopvalue|nopvalues|"
        local _hddid_alias_bare_follow_12 ///
            "o|om|omi|omit|omitt|omitte|omitted|pl|plu|plus|se|sel|sele|seleg|selege|selegen|"
        local _hddid_alias_bare_follow_13 ///
            "selegend|noci|nofv|nofvl|nofvla|nofvlab|nofvlabe|nofvlabel|noh|nohe|nohea|nohead|"
        local _hddid_alias_bare_follow_14 ///
            "noheade|noheader|nols|nolst|nolstr|nolstre|nolstret|nolstretc|nolstretch|"
        local _hddid_alias_bare_follow_15 ///
            "nof|nofi|nofir|nofirs|nofirst|ver|vers|versu|versus|verb|verbo|verbos|verbose|"
        local _hddid_alias_bare_follow_16 ///
            "vsq|vsqu|vsqui|vsquis|vsquish)($|[ ])"
        local _hddid_alias_bare_follow_a ///
            `"`_hddid_alias_bare_follow_1'`_hddid_alias_bare_follow_2'`_hddid_alias_bare_follow_3'`_hddid_alias_bare_follow_4'`_hddid_alias_bare_follow_5'`_hddid_alias_bare_follow_6'`_hddid_alias_bare_follow_7'`_hddid_alias_bare_follow_8'"'
        local _hddid_alias_bare_follow_b ///
            `"`_hddid_alias_bare_follow_9'`_hddid_alias_bare_follow_10'`_hddid_alias_bare_follow_11'`_hddid_alias_bare_follow_12'`_hddid_alias_bare_follow_13'`_hddid_alias_bare_follow_14'`_hddid_alias_bare_follow_15'`_hddid_alias_bare_follow_16'"'
        local _hddid_alias_bare_follow ///
            `"`_hddid_alias_bare_follow_a'`_hddid_alias_bare_follow_b'"'
        local _hddid_alias_syntax_follow ///
            "^((if|in)($|[ ])|([[][^]]*[]]))"
        local _hddid_alias_payload_has_lparen = ///
            regexm(`"`_hddid_payload'"', `"`_hddid_alias_lparen_follow'"')
        local _hddid_alias_payload_has_bare = ///
            regexm(`"`_hddid_payload'"', `"`_hddid_alias_bare_follow'"')
        local _hddid_alias_payload_has_func = ///
            regexm(`"`_hddid_payload'"', "^[a-z_][a-z0-9_]*[ ]*[(]")
        local _hddid_alias_payload_has_syntax = ///
            regexm(`"`_hddid_payload'"', `"`_hddid_alias_syntax_follow'"')
        if regexm(`"`_hddid_raw'"', "=[ ]+") & ///
            (`_hddid_alias_payload_has_lparen' | ///
            `_hddid_alias_payload_has_bare' | ///
            `_hddid_alias_payload_has_func' | ///
            `_hddid_alias_payload_has_syntax') {
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

program define _hddid_p_postest_show_invalid
    syntax , RAW(string asis)

    di as error "{bf:hddid}: invalid estimator-style option value: " ///
        as text `"`raw'"'
    di as error "  Reason: {bf:method()} selects only the sieve basis family; it is not an AIPW, IPW, or RA estimator switch"
    di as error "  {bf:hddid} implements the doubly robust AIPW estimator throughout"
    di as error "  Use {bf:method(Pol)} or {bf:method(Tri)} to choose the sieve basis family"
end

capture program drop _hddid_p_postest_parse
program define _hddid_p_postest_parse, rclass
    syntax , RAW(string asis)

    return clear

    local _hddid_raw = strtrim(`"`raw'"')
    if `"`_hddid_raw'"' == "" {
        exit
    }

    quietly _hddid_p_postest_parse_estopt, optsraw(`"`_hddid_raw'"')
    if `"`r(invalid)'"' == "1" | `"`r(canonical)'"' != "" {
        return local invalid `"`r(invalid)'"'
        return local canonical `"`r(canonical)'"'
        return local raw `"`r(raw)'"'
        return local form `"`r(form)'"'
    }
end

capture program drop _hddid_p_trailing_esttoken
program define _hddid_p_trailing_esttoken, rclass
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

capture program drop _hddid_p_stub_prescan
program define _hddid_p_stub_prescan, rclass
    syntax , CMDLINE(string asis)

    return clear
    local 0 `cmdline'
    if `"`0'"' == "" {
        return local estopt_invalid ""
        return local estopt_canonical ""
        return local estopt_raw ""
        exit 0
    }

    local _hddid_estopt_invalid ""
    local _hddid_estopt_canonical ""
    local _hddid_estopt_raw ""
    local _hddid_skip_method_prescan 0
    quietly _hddid_p_postest_parse_estopt, optsraw(`"`0'"')
    if `"`r(canonical)'"' != "" & ///
        (regexm(strtrim(`"`r(raw)'"'), "^[ ]*[(][ ]*[(]") | ///
        regexm(strtrim(`"`0'"'), "^[ ]*,")) {
        local _hddid_estopt_invalid `"`r(invalid)'"'
        local _hddid_estopt_canonical `"`r(canonical)'"'
        local _hddid_estopt_raw `"`r(raw)'"'
        local _hddid_skip_method_prescan 1
    }

    if `"`0'"' != "" & !`_hddid_skip_method_prescan' {
        quietly _hddid_p_postest_parse_methodopt, optsraw(`"`0'"')
        if `"`r(invalid)'"' == "1" {
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
            di as error "  {bf:hddid} implements the doubly robust AIPW estimator throughout"
            if `_hddid_pst_method_note' {
                di as error "  Reason: {bf:method()} is an estimation option that only picks the {bf:Pol}/{bf:Tri} sieve basis; it is not a supported postestimation token."
            }
            di as error "  Use bare {bf:hddid_p}; the stored sieve basis is already published in {bf:e(method)}."
            exit 198
        }
        if `"`r(raw)'"' != "" {
            di as error "{bf:hddid}: bare predict (or predict with an estimator-style option) is not supported."
            di as error "  Reason: observation-level fitted values are produced by {bf:predict} {it:newvar} {bf:[, xb|fz|tau]}."
            di as error "  Aggregate inference objects for the parametric beta block and the nonparametric {bf:f(z)} surface live on the stored evaluation grid."
            di as error "  Offending method() input: " as text `"`r(raw)'"'
            di as error "  Reason: {bf:method()} is an estimation option that only picks the {bf:Pol}/{bf:Tri} sieve basis; it is not a supported postestimation token."
            di as error "  {bf:hddid} implements the doubly robust AIPW estimator throughout"
            di as error "  Use bare {bf:hddid_p}; the stored sieve basis is already published in {bf:e(method)}."
            exit 198
        }
    }

    local _hddid_leading_ifin 0
    local _hddid_esttoken_canonical ""
    local _hddid_esttoken_raw ""
    local _hddid_raw0 `"`0'"'
    local _hddid_raw0_comma = strpos(`"`_hddid_raw0'"', ",")
    local _hddid_raw0_postcomma ""
    if `_hddid_raw0_comma' > 0 {
        local _hddid_raw0_postcomma = ///
            substr(`"`_hddid_raw0'"', `_hddid_raw0_comma' + 1, .)
        if strtrim(`"`_hddid_raw0_postcomma'"') == "" {
            di as error "{bf:hddid}: predict does not accept a trailing comma"
            di as error "  Reason: {bf:hddid_p} does not accept options; a lone comma is malformed syntax"
            di as error "  Use bare {bf:hddid_p} or supply a nonempty estimator-style token only when you want that misuse echoed back"
            exit 198
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
            quietly _hddid_p_trailing_esttoken, precomma(`"`_hddid_raw0_probe'"')
            local _hddid_ifin_token_raw `"`r(raw)'"'
            local _hddid_ifin_token_canonical `"`r(canonical)'"'
            if `"`_hddid_ifin_token_raw'"' != "" {
                // Trailing estimator-family tokens after if/in qualifiers
                // are classified for package-level guidance.
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
                local _hddid_quote_char = substr(`"`_hddid_prequal'"', -1, 1)
                if `"`_hddid_quote_char'"' == `"`_hddid_dq'"' | ///
                    `"`_hddid_quote_char'"' == `"`_hddid_sq'"' {
                    local _hddid_before_last = ///
                        substr(`"`_hddid_prequal'"', 1, length(`"`_hddid_prequal'"') - 1)
                    local _hddid_quote_pos = ///
                        strrpos(`"`_hddid_before_last'"', `"`_hddid_quote_char'"')
                    if `_hddid_quote_pos' > 0 {
                        local _hddid_prefix_raw = ///
                            substr(`"`_hddid_prequal'"', 1, `_hddid_quote_pos' - 1)
                        if strtrim(`"`_hddid_prefix_raw'"') == "" | ///
                            substr(`"`_hddid_prefix_raw'"', -1, 1) == " " {
                            local _hddid_probe_raw = ///
                                substr(`"`_hddid_prequal'"', `_hddid_quote_pos', .)
                            local _hddid_probe_lc = lower(strtrim(substr( ///
                                `"`_hddid_probe_raw'"', 2, length(`"`_hddid_probe_raw'"') - 2)))
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
        }
    }
    if `"`_hddid_estopt_raw'"' == "" & !`_hddid_leading_ifin' {
        capture program list _hddid_p_trailing_esttoken
        if _rc == 0 {
            quietly _hddid_p_trailing_esttoken, precomma(`"`_hddid_raw0_probe'"')
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
        !`_hddid_leading_ifin' {
        quietly _hddid_p_postest_parse_estopt, ///
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
        quietly _hddid_p_postest_parse_estopt, ///
            optsraw(`"`_hddid_raw0_postcomma'"')
        if `"`r(raw)'"' != "" {
            local _hddid_estopt_invalid `"`r(invalid)'"'
            local _hddid_estopt_canonical `"`r(canonical)'"'
            local _hddid_estopt_raw `"`r(raw)'"'
            local _hddid_prescan_skip_syntax 1
        }
    }

    // Unsupported postestimation input is routed to package guidance.
    if !`_hddid_prescan_no_comma_assign' & !`_hddid_prescan_skip_syntax' {
        syntax [anything] [fw aw pw iw] [if] [in] [, *]
    }
    if !`_hddid_prescan_no_comma_assign' & !`_hddid_prescan_skip_syntax' & ///
        `"`_hddid_estopt_raw'"' == "" & `"`anything'"' != "" {
        quietly _hddid_p_postest_parse_estopt, ///
            optsraw(`"`anything'"')
        local _hddid_estopt_invalid `"`r(invalid)'"'
        local _hddid_estopt_canonical `"`r(canonical)'"'
        local _hddid_estopt_raw `"`r(raw)'"'
        if `"`_hddid_estopt_raw'"' == "" {
            capture program list _hddid_p_trailing_esttoken
            if _rc == 0 {
                quietly _hddid_p_trailing_esttoken, precomma(`"`_hddid_raw0'"')
                local _hddid_esttoken_canonical `"`r(canonical)'"'
                local _hddid_esttoken_raw `"`r(raw)'"'
                if `"`_hddid_esttoken_canonical'"' != "" {
                    local _hddid_estopt_raw `"`_hddid_esttoken_raw'"'
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
        quietly _hddid_p_postest_parse_estopt, ///
            optsraw(`"`_hddid_options_raw'"')
        local _hddid_option_estopt_invalid `"`r(invalid)'"'
        local _hddid_option_estopt_canonical `"`r(canonical)'"'
        local _hddid_option_estopt_raw `"`r(raw)'"'
        if `"`_hddid_option_estopt_invalid'"' != "" {
            local _hddid_estopt_invalid `"`_hddid_option_estopt_invalid'"'
        }
        if `"`_hddid_option_estopt_canonical'"' != "" {
            local _hddid_estopt_canonical `"`_hddid_option_estopt_canonical'"'
        }
        if `"`_hddid_option_estopt_raw'"' != "" {
            local _hddid_estopt_raw `"`_hddid_option_estopt_raw'"'
        }
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
        _hddid_p_postest_show_invalid, raw(`"`_hddid_estopt_raw'"')
        exit 198
    }

    return local estopt_invalid `"`_hddid_estopt_invalid'"'
    return local estopt_canonical `"`_hddid_estopt_canonical'"'
    return local estopt_raw `"`_hddid_estopt_raw'"'
end

capture program drop hddid_p
program define hddid_p
    version 16

    // Supported predict options: xb, fz, tau
    if `"`e(cmd)'"' == "hddid" {
        capture confirm matrix e(gammabar)
        local _hddid_has_gammabar = (_rc == 0)

        // Syntax: predict newvar [if] [in] [, xb fz tau]
        local 0_saved `"`0'"'
        capture syntax newvarname [if] [in] [, XB FZ TAU]
        if _rc == 0 {
            local _n_opts = ("`xb'" != "") + ("`fz'" != "") + ("`tau'" != "")
            if `_n_opts' > 1 {
                di as error "{bf:hddid predict}: specify at most one of {bf:xb}, {bf:fz}, or {bf:tau}"
                exit 198
            }
            if `_n_opts' == 0 {
                local tau "tau"
            }

            // xb: linear prediction X'beta_debiased
            if "`xb'" != "" {
                tempname _hddid_p_b
                matrix `_hddid_p_b' = e(b)
                quietly matrix score `typlist' `varlist' = `_hddid_p_b' `if' `in'
                label variable `varlist' "Linear prediction (X'beta_debias)"
                exit
            }

            // fz and tau require e(gammabar) and e(a0)
            if !`_hddid_has_gammabar' {
                di as error "{bf:hddid predict}: e(gammabar) not found in stored results"
                di as error "  Reason: stored results lack {bf:e(gammabar)}; re-estimate to enable predict"
                di as error "  Re-run {bf:hddid} to produce results compatible with predict"
                exit 198
            }

            marksample touse, novarlist

            tempname _hddid_p_gammabar _hddid_p_a0
            matrix `_hddid_p_gammabar' = e(gammabar)
            scalar `_hddid_p_a0' = e(a0)
            local _hddid_p_method `"`e(method)'"'
            local _hddid_p_q = e(q)
            local _hddid_p_zvar `"`e(zvar)'"'

            // Construct sieve basis at each observation's Z value
            tempvar _hddid_p_fz_val
            quietly gen double `_hddid_p_fz_val' = . if `touse'

            // Compute f(z) = psi(z)'gammabar via Mata.
            tempname _hddid_p_fz_mata
            if `"`_hddid_p_method'"' == "Pol" {
                mata: st_matrix("`_hddid_p_fz_mata'", ///
                    _hddid_sieve_pol( ///
                        st_data(., "`_hddid_p_zvar'", "`touse'"), ///
                        strtoreal("`_hddid_p_q'")) ///
                    * st_matrix("`_hddid_p_gammabar'")')
            }
            else {
                mata: st_matrix("`_hddid_p_fz_mata'", ///
                    _hddid_sieve_tri_support( ///
                        st_data(., "`_hddid_p_zvar'", "`touse'"), ///
                        strtoreal("`_hddid_p_q'"), ///
                        st_numscalar("e(z_support_min)"), ///
                        st_numscalar("e(z_support_max)")) ///
                    * st_matrix("`_hddid_p_gammabar'")')
            }
            mata: st_store(., "`_hddid_p_fz_val'", "`touse'", ///
                st_matrix("`_hddid_p_fz_mata'"))

            if "`fz'" != "" {
                quietly gen `typlist' `varlist' = `_hddid_p_fz_val' `if' `in'
                label variable `varlist' "Nonparametric prediction (a0 + psi(z)'gammabar)"
                exit
            }

            // tau: heterogeneous ATT prediction X'beta + f(z)
            tempname _hddid_p_b
            matrix `_hddid_p_b' = e(b)
            tempvar _hddid_p_xb_val
            quietly matrix score double `_hddid_p_xb_val' = `_hddid_p_b'
            quietly gen `typlist' `varlist' = `_hddid_p_xb_val' + `_hddid_p_fz_val' `if' `in'
            label variable `varlist' "Heterogeneous ATT prediction (X'beta + f(z))"
            exit
        }
        local 0 `"`0_saved'"'
    }

    // Unsupported-predict guidance
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

    _hddid_p_stub_prescan, cmdline(`"`0'"')
    local _hddid_estopt_invalid `"`r(estopt_invalid)'"'
    local _hddid_estopt_canonical `"`r(estopt_canonical)'"'
    local _hddid_estopt_raw `"`r(estopt_raw)'"'
    local _hddid_cmdline_predict_raw = subinstr(`"`0'"', char(9), " ", .)
    local _hddid_cmdline_predict_raw = ///
        subinstr(`"`_hddid_cmdline_predict_raw'"', char(10), " ", .)
    local _hddid_cmdline_predict_raw = ///
        subinstr(`"`_hddid_cmdline_predict_raw'"', char(13), " ", .)
    local _hddid_cmdline_predict_raw = strtrim(`"`_hddid_cmdline_predict_raw'"')
    local _hddid_predict_head_bare_alias ""
    local _hddid_cmdline_predict_raw_lc = ///
        lower(`"`_hddid_cmdline_predict_raw'"')
    if regexm(`"`_hddid_cmdline_predict_raw_lc'"', ///
        "^(r|ra|i|ip|ipw|a|ai|aip|aipw)([ ]*(,|if([ ]|$)|in([ ]|$))|$)") {
        local _hddid_predict_head_bare_alias = lower(strtrim(regexs(1)))
    }
    // Storage-type-prefixed estimator-family tokens are classified
    // alongside untyped forms.
    if `"`_hddid_predict_head_bare_alias'"' == "" & ///
        regexm(`"`_hddid_cmdline_predict_raw_lc'"', ///
        "^(byte|int|long|float|double)[ ]+(r|ra|i|ip|ipw|a|ai|aip|aipw)([ ]|$)") {
        local _hddid_predict_head_bare_alias = lower(strtrim(regexs(2)))
    }
    // Bare estimator-family tokens in the newvar slot are treated as
    // variable names; quoted, parenthesized, and assignment forms
    // remain on the estimator-style guidance path.
    if `"`_hddid_estopt_raw'"' != "" & `"`_hddid_predict_head_bare_alias'"' != "" & ///
        lower(`"`_hddid_estopt_raw'"') == `"`_hddid_predict_head_bare_alias'"' {
        local _hddid_estopt_invalid ""
        local _hddid_estopt_canonical ""
        local _hddid_estopt_raw ""
    }
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
        local _hddid_surface_core_ok = ///
            (`_hddid_has_p' & `_hddid_has_k' & `_hddid_has_q' & ///
            `_hddid_has_N' & `_hddid_has_xdebias' & `_hddid_has_stdx' & ///
            `_hddid_has_gdebias' & `_hddid_has_z0')
        local _hddid_surface_interval_ok = ///
            (`_hddid_has_stdg' | `_hddid_has_CIpoint' | `_hddid_has_CIuniform')
        local _hddid_surface_role_ok = ///
            (`"`_hddid_treat_probe'"' != "" & `"`_hddid_xvars_probe'"' != "" & ///
            `"`_hddid_zvar_probe'"' != "" & `"`_hddid_method_probe'"' != "" & ///
            (`"`_hddid_depvar_probe'"' != "" | `"`_hddid_depvar_role_probe'"' != ""))
        if `_hddid_surface_core_ok' & `_hddid_surface_interval_ok' & ///
            `_hddid_surface_role_ok' {
            // An HDDID surface is recognized by its core stored results
            // even when individual inference objects are incomplete.
            local _hddid_active_surface 1
        }
    }
    if !`_hddid_active_surface' {
        di as error "{bf:hddid}: predict requires an active hddid result surface."
        di as error "  Reason: no active {bf:hddid} result set is available for postestimation."
        if `"`_hddid_estopt_raw'"' != "" {
            di as error `"  Offending estimator-style input: {bf:`_hddid_estopt_raw'}"'
            di as error "  Reason: {bf:method()} only picks the {bf:Pol}/{bf:Tri} sieve basis; it is not an estimator-family switch."
            di as error "  {bf:hddid} implements the doubly robust AIPW estimator throughout"
            if `"`_hddid_estopt_canonical'"' == "" {
                _hddid_p_postest_show_invalid, raw(`"`_hddid_estopt_raw'"')
            }
        }
        di as error "  Run {bf:hddid} first, then inspect the stored {bf:e()} result surface."
        exit 198
    }
    // Estimator-family misuse in predict input is reported before
    // saved-results metadata errors.
    if `"`_hddid_estopt_raw'"' != "" {
        di as error "{bf:hddid}: bare predict (or predict with an estimator-style option) is not supported."
        di as error "  Reason: observation-level fitted values are produced by {bf:predict} {it:newvar} {bf:[, xb|fz|tau]}."
        di as error "  Aggregate inference objects for the parametric beta block and the nonparametric {bf:f(z)} surface live on the stored evaluation grid."
        di as error `"  Offending estimator-style input: {bf:`_hddid_estopt_raw'}"'
        di as error "  Reason: {bf:method()} only picks the {bf:Pol}/{bf:Tri} sieve basis; it is not an estimator-family switch."
        di as error "  {bf:hddid} implements the doubly robust AIPW estimator throughout"
        if `"`_hddid_estopt_canonical'"' == "" {
            _hddid_p_postest_show_invalid, raw(`"`_hddid_estopt_raw'"')
        }
        di as error "  Use {bf:e(sample)} only when the original estimation data are still in memory."
        di as error "  After {bf:estimates use}, rely on the stored {bf:e()} result surface."
        di as error "  A live retained-sample count may no longer be available there."
        exit 198
    }

    capture program list _hddid_p_current_surface
    if _rc != 0 {
        local _hddid_pst_pkgdir `"$HDDID_SOURCE_RUN_PKGDIR"'
        if `"`_hddid_pst_pkgdir'"' == "" {
            local _hddid_pst_pkgdir `"$HDDID_WRAPPER_PKGDIR"'
        }
        if `"`_hddid_pst_pkgdir'"' == "" {
            local _hddid_pst_pkgdir `"$HDDID_PACKAGE_DIR"'
        }
        if `"`_hddid_pst_pkgdir'"' != "" {
            quietly capture run `"`_hddid_pst_pkgdir'/_hddid_p_current_surface.ado"'
            capture program list _hddid_p_current_surface
        }
        if _rc != 0 {
            capture findfile _hddid_p_current_surface.ado
            if _rc == 0 {
                quietly capture run `"`r(fn)'"'
            }
        }
        capture program list _hddid_p_current_surface
        if _rc != 0 {
            di as error "{bf:hddid}: failed to load {bf:_hddid_p_current_surface.ado}"
            di as error "  Reason: current-surface validation requires {bf:_hddid_p_current_surface.ado}"
            di as error "  Please reinstall the {bf:hddid} package or remove outdated copies from adopath"
            exit 198
        }
    }

    local _hddid_current_surface_opts ""
    if `"`_hddid_estopt_raw'"' != "" {
        local _hddid_current_surface_opts ///
            `"`_hddid_current_surface_opts' estoptraw(`"`_hddid_estopt_raw'"')"' 
    }
    if `"`_hddid_estopt_canonical'"' != "" {
        local _hddid_current_surface_opts ///
            `"`_hddid_current_surface_opts' estoptcanonical(`"`_hddid_estopt_canonical'"')"' 
    }
    _hddid_p_current_surface, `_hddid_current_surface_opts'
end
