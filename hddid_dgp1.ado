capture program drop hddid_dgp1
program define hddid_dgp1
    version 16
    syntax, n(integer) p(integer) [seed(string) clear]

    if `n' < 1 {
        di as error "{bf:hddid_dgp1}: n() must be >= 1, got `n'"
        exit 198
    }

    if `p' < 1 {
        di as error "{bf:hddid_dgp1}: p() must be >= 1, got `p'"
        exit 198
    }

    local seed_input `"`seed'"'
    if `"`seed_input'"' == "" {
        local seed = -1
    }
    else {
        capture confirm number `seed_input'
        if _rc != 0 {
            di as error "{bf:hddid_dgp1}: seed() must be an integer in [0, 2147483647] or -1, got `seed_input'"
            exit 198
        }
        local seed = real(`"`seed_input'"')
        if missing(`seed') | `seed' != floor(`seed') | `seed' < -1 | `seed' > 2147483647 {
            di as error "{bf:hddid_dgp1}: seed() must be an integer in [0, 2147483647] or -1, got `seed_input'"
            exit 198
        }
    }

    if "`clear'" == "" & (c(k) > 0 | c(N) > 0) {
        di as error "no; data in memory would be lost"
        di as error "    Specify option {bf:clear} to replace the current dataset."
        exit 4
    }

    // Peak footprint is p x-variables plus 12 additional variables created
    // before the intermediate cleanup drop.
    local extra_vars = 12
    local maxvar_now = c(maxvar)
    local peak_vars = `p' + `extra_vars'
    if `peak_vars' > `maxvar_now' {
        local max_p = `maxvar_now' - `extra_vars'
        di as error "{bf:hddid_dgp1}: p(`p') exceeds the current maxvar budget"
        di as error "  c(maxvar) = `maxvar_now', requested peak variables = `peak_vars'"
        di as error "  x-variables = `p', additional DGP variables at peak = `extra_vars'"
        di as error "  Maximum feasible p() under the current maxvar is `max_p'"
        exit 198
    }

    local restore_rng = (`"`seed_input'"' != "" & `seed' != -1)
    local caller_rngstate = c(rngstate)

    // Build the replacement dataset transactionally so any runtime failure
    // leaves the caller's data untouched.
    preserve
    capture noisily {
        clear
        set obs `n'
        if `seed' != -1 {
            set seed `seed'
        }

        // --- X covariates: independent standard normal ---
        forvalues j = 1/`p' {
            gen double x`j' = rnormal()
        }

        // --- Z covariate: independent standard normal ---
        gen double z = rnormal()

        // --- Propensity score: P(T=1) = 1 - 1/(1+exp(X'theta0)) ---
        // theta0_i = 1/i (i<=10), 0 (i>10)
        gen double xtheta = 0
        local ptheta = min(`p', 10)
        forvalues i = 1/`ptheta' {
            replace xtheta = xtheta + x`i' * (1/`i')
        }
        gen double prop = invlogit(xtheta)
        gen byte treat = rbinomial(1, prop)

        // --- Base period outcome and error terms ---
        gen double y0_base = rnormal()
        gen double eps0 = rnormal()
        gen double eps1 = rnormal()

        // --- Linear parts: beta1_i=2/i, beta0_i=1/i (i<=15) ---
        gen double xbeta1 = 0
        gen double xbeta0 = 0
        local pbeta = min(`p', 15)
        forvalues i = 1/`pbeta' {
            replace xbeta1 = xbeta1 + x`i' * (2/`i')
            replace xbeta0 = xbeta0 + x`i' * (1/`i')
        }
        gen double fz = exp(z)

        // --- Post-period outcome ---
        gen double y1 = y0_base + (xbeta1 + fz + eps1)*treat ///
                                 + (xbeta0 + eps0)*(1-treat)
        gen double deltay = y1 - y0_base

        // --- Clean intermediate variables ---
        drop xtheta prop y0_base eps0 eps1 xbeta1 xbeta0 fz y1
    }

    local build_rc = _rc
    if `build_rc' {
        quietly set rngstate `caller_rngstate'
        restore
        exit `build_rc'
    }
    if `restore_rng' {
        quietly set rngstate `caller_rngstate'
    }

    restore, not
end
