*! Data-generating process 2 for Monte Carlo simulations
*! Generates panel data with AR(1) covariate structure

capture program drop hddid_dgp2

program define hddid_dgp2
    version 16
    syntax, n(integer) p(integer) [seed(string) rho(real 0.5) clear]

    if `n' < 1 {
        di as error "{bf:hddid_dgp2}: n() must be >= 1, got `n'"
        exit 198
    }

    if `p' < 1 {
        di as error "{bf:hddid_dgp2}: p() must be >= 1, got `p'"
        exit 198
    }

    local seed_input `"`seed'"'
    if `"`seed_input'"' == "" {
        local seed = -1
    }
    else {
        capture confirm number `seed_input'
        if _rc != 0 {
            di as error "{bf:hddid_dgp2}: seed() must be an integer in [0, 2147483647] or -1, got `seed_input'"
            exit 198
        }
        local seed = real(`"`seed_input'"')
        if missing(`seed') | `seed' != floor(`seed') | `seed' < -1 | `seed' > 2147483647 {
            di as error "{bf:hddid_dgp2}: seed() must be an integer in [0, 2147483647] or -1, got `seed_input'"
            exit 198
        }
    }

    if missing(`rho') {
        di as error "{bf:hddid_dgp2}: rho() must be finite, got `rho'"
        exit 198
    }

    if `p' > 1 & (`rho' <= -1 | `rho' >= 1) {
        di as error "{bf:hddid_dgp2}: rho() must satisfy -1 < rho < 1, got `rho'"
        exit 198
    }

    if "`clear'" == "" & (c(k) > 0 | c(N) > 0) {
        di as error "no; data in memory would be lost"
        di as error "    Specify option {bf:clear} to replace the current dataset."
        exit 4
    }

    // Memory requirement check: peak usage is p covariates plus 13 temporary variables
    local extra_vars = 13
    local maxvar_now = c(maxvar)
    local peak_vars = `p' + `extra_vars'
    if `peak_vars' > `maxvar_now' {
        local max_p = `maxvar_now' - `extra_vars'
        di as error "{bf:hddid_dgp2}: p(`p') exceeds the current maxvar budget"
        di as error "  c(maxvar) = `maxvar_now', requested peak variables = `peak_vars'"
        di as error "  x-variables = `p', additional DGP variables at peak = `extra_vars'"
        di as error "  Maximum feasible p() under the current maxvar is `max_p'"
        exit 198
    }

    local restore_rng = (`"`seed_input'"' != "" & `seed' != -1)
    local caller_rngstate = c(rngstate)

    // Data are generated via direct matrix operations to ensure reproducibility
    // without external dependencies

    // Preserve caller's data to enable restoration on error
    preserve
    capture noisily {
        clear
        set obs `n'
        if `seed' != -1 {
            set seed `seed'
        }

        // --- Covariates X: multivariate normal with AR(1) covariance structure ---
        // Sigma_{jk} = rho^|j-k|. When p=1, Sigma=[1] and rho is unidentified.
        tempname Sigma
        matrix `Sigma' = J(`p', `p', 0)
        forvalues j = 1/`p' {
            forvalues k = 1/`p' {
                // Parentheses ensure correct operator precedence for negative rho
                matrix `Sigma'[`j', `k'] = (`rho')^abs(`j' - `k')
            }
        }
        local xdraw_vars x1-x`p'
        if `p' == 1 {
            local xdraw_vars x1
        }
        // Generate covariates in double precision
        drawnorm `xdraw_vars', cov(`Sigma') double

        // --- Continuous covariate Z ---
        gen double z = rnormal()

        // --- Treatment assignment via propensity score ---
        gen double xtheta = 0
        local ptheta = min(`p', 10)
        forvalues i = 1/`ptheta' {
            replace xtheta = xtheta + x`i' * (1/`i')
        }
        gen double prop = invlogit(xtheta)
        gen byte treat = rbinomial(1, prop)

        // --- Baseline outcome with heteroscedastic error ---
        gen double eps_tilde = rnormal()
        gen double y0_base = eps_tilde * (1/sqrt(2)*z + 1/sqrt(2)*x1)

        // --- Error terms for post-treatment periods ---
        gen double eps0 = rnormal()
        gen double eps1 = rnormal()

        // --- Linear index components ---
        gen double xbeta1 = 0
        gen double xbeta0 = 0
        local pbeta = min(`p', 15)
        forvalues i = 1/`pbeta' {
            replace xbeta1 = xbeta1 + x`i' * (2/`i')
            replace xbeta0 = xbeta0 + x`i' * (1/`i')
        }
        gen double fz = exp(z)

        // --- Post-treatment outcome ---
        gen double y1 = y0_base + (xbeta1 + fz + eps1)*treat ///
                                 + (xbeta0 + eps0)*(1-treat)
        gen double deltay = y1 - y0_base

        // --- Remove temporary variables ---
        drop xtheta prop eps_tilde y0_base eps0 eps1 xbeta1 xbeta0 fz y1
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
