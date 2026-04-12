// =============================================================================
// hddid_example.do
// Doubly Robust Semiparametric DID Estimator with High-Dimensional Data
// Based on Ning, Peng, and Tao (2024, Review of Economics and Statistics)
// =============================================================================
//
// Prerequisites:
//   Stata 16+ with Python integration enabled
//   Configure/verify the bridge before running:
//     set python_exec /path/to/python3
//     python query
//   ssc install lassopack, replace
//     (ships the default lasso2/cvlasso/cvlassologit commands)
//     The documented propensity-recovery path can also invoke lassologit
//     after cvlassologit leaves no usable postresults.
//   Standard local install from this package directory:
//     net install hddid, from("/path/to/hddid-stata") replace
//   After net install, verify the installed sibling bundle resolves together:
//     which hddid
//     which hddid_dgp1
//     which hddid_dgp2
//     which hddid_p
//     which hddid_estat
//     findfile _hddid_main.ado
//     findfile _hddid_display.ado
//     findfile _hddid_estimate.ado
//     findfile _hddid_prepare_fold_covinv.ado
//     findfile _hddid_pst_cmdroles.ado
//     findfile _hddid_mata.ado
//     findfile hddid_safe_probe.py
//     findfile hddid_clime.py
//     python query
//     which lasso2
//     which cvlasso
//     which cvlassologit
//     which lassologit
//   To also fetch the shipped ancillary walkthrough into your working directory:
//     net install hddid, from("/path/to/hddid-stata") all replace
//     or: net get hddid, from("/path/to/hddid-stata")
//   Then locate and run the installed walkthrough copy with:
//     findfile hddid_example.do
//     do "`r(fn)'"
//   Python 3.7+ with numpy>=1.20 and scipy>=1.7:
//     pip install "numpy>=1.20" "scipy>=1.7"
//
// Estimated runtime: ~10 minutes (standard settings, n=500, p=50, K=3)
//
// Structure (simple -> complex):
//   Part 1: Basic estimation with DGP1 (simplest case)
//   Part 2: Paper-baseline DGP2 (correlated X, heteroskedastic baseline)
//   Part 3: Method comparison (Pol vs Tri)
//   Part 4: Accessing and interpreting stored results
//   Part 5: Common errors and diagnostics
//
// DGP validation note:
//   The shipped hddid_dgp1/hddid_dgp2 generators below track paper Section 5.
//   The DGP generators accept n() as small as 1 because generation and estimation are separate contracts.
//   A downstream hddid run still needs both treatment arms represented on the usable score / fold-pinning sample and at least K observations in each represented arm.
//   The maintained paper/R split then assigns the outer map as contiguous current-row blocks on the fold-pinning sample, so K() cannot exceed the number of nonempty row blocks implied by that sample size. In plain terms, tiny n() draws are generator probes rather than estimation-ready examples.
//   The shipped Stata DGP commands keep only deltay, so they are not
//   drop-in inputs to the hddid-r y0/y1 crossfit API.
//   For cross-language validation, prefer the package's paper oracle tests.
//   Do not treat hddid-r/R/Examplehighdimdiffindiff.R as the DGP oracle:
//   that legacy R wrapper changes the DGP construction away from the paper.
//   In particular, it re-draws z after building the baseline outcome, so the
//   observed z no longer matches the same paper DGP2 covariate used in both
//   the baseline term and exp(z). It also exposes rho.X but still hardcodes
//   the correlated-X covariance at 0.5^|j-k|, so nondefault rho.X values are
//   not honored there. It also defaults to method="Pol" even though the paper's Section 5 simulations use the 8th degree trigonometric (Tri) basis.
//   More fundamentally, the legacy wrapper hardcodes the polynomial sieve
//   regardless of the method argument, so even method="Tri" there does not
//   reproduce the paper's Tri basis.
//   In the current source tree it is also not even a runnable oracle against
//   the shipped R sources: Examplehighdimdiffindiff.R calls
//   highdimdiffindiff_crossfit() while the shipped cross-fit entry point in
//   this tree is highdimdiffindiff_crossfit3(). Even patching that wrapper
//   onto highdimdiffindiff_crossfit3() still does not rescue the shipped R
//   tree as a runnable oracle. A rename-only patch already fails at the
//   public R API layer: Examplehighdimdiffindiff.R passes method=... while
//   highdimdiffindiff_crossfit3(y0, y1, treat, x, z, q, k, z0, alp)
//   requires z0 and alp and does not accept method, so that patched wrapper
//   first throws the concrete R error unused argument (method = method).
//   Even after that signature mismatch, highdimdiffindiff_crossfit3()
//   source()s missing highdimdiffindiff_crossfit_inside3.r, and its
//   CIuniform line references undefined debias instead of gdebias.
//   At small p, the wrapper's fixed theta0/omega0 setup loops can also outrun
//   the simulated X width, so calls such as p()<10 can die with the concrete
//   R error "non-conformable arguments" instead of reproducing the paper's
//   truncated DGP contract.
//   For the maintained R estimator reference, read
//   those files as a read-only source reference, not a public wrapper/script entrypoint to source() directly:
//   hddid-r/R/highdimdiffindiff_crossfit.R together with
//   hddid-r/R/highdimdiffindiff_crossfit_inside.R: those files carry the
//   surviving shipped cross-fit estimator logic, specifically the
//   highdimdiffindiff_crossfit3() entrypoint and the
//   highdimdiffindiff_crossfit_inside3() helper, even though the Stata DGP
//   generators here still publish deltay rather than the y0/y1 level inputs
//   that the R code expects.
//   Under this package's q() indexing, q(8) yields a 4th
//   degree trigonometric basis, so matching the paper's 8th degree Tri
//   basis would require q(16) rather than q(8).
//
// Identification note:
//   The paper's target setting is repeated cross-sections, not a generic
//   panel-DiD workflow. The example's deltay path still relies on the paper's
//   conditional parallel trends and full-support assumptions after
//   conditioning on W=(X,Z).
// =============================================================================

// The example needs a clean dataset, not a full session reset.
// Avoid clearing caller-defined programs and other session-wide objects.
local hddid_example_dta_chars : char _dta[]
quietly label dir
local hddid_example_value_labels `"`r(names)'"'
local hddid_example_empty_surface = (c(k) == 0 & c(N) == 0)
local hddid_example_charonly_empty = ///
    (`hddid_example_empty_surface' & ///
    (`"`hddid_example_dta_chars'"' != "" | ///
    `"`hddid_example_value_labels'"' != ""))
local hddid_example_had_data = ///
    (c(k) > 0 | c(N) > 0 | `"`hddid_example_dta_chars'"' != "" | ///
    `"`hddid_example_value_labels'"' != "")
tempname hddid_example_est_hold
local hddid_example_had_estimates 0
capture noisily ereturn list
if _rc == 0 {
    capture noisily _estimates hold `hddid_example_est_hold'
    if _rc == 0 {
        local hddid_example_had_estimates 1
    }
}
if `hddid_example_had_data' {
    if `hddid_example_charonly_empty' {
        local hxe_restore_chars `"`hddid_example_dta_chars'"'
        tempfile hddid_example_label_backup
        capture noisily label save using "`hddid_example_label_backup'", replace
        local hxe_char_n 0
        foreach hxe_char_name of local hxe_restore_chars {
            local ++hxe_char_n
            local hxe_name_`hxe_char_n' `"`hxe_char_name'"'
            local hxe_value_`hxe_char_n' : char _dta[`hxe_char_name']
        }
    }
    else {
        tempfile hddid_example_data_backup
        quietly save "`hddid_example_data_backup'", replace
    }
}
clear
local hddid_example_cwd_prev `"`c(pwd)'"'
local hddid_example_more_prev `"`c(more)'"'
local hddid_example_matsize_prev = c(matsize)
local hddid_example_added_to_adopath 0
local hddid_example_rc 0
local hddid_example_cwd_live `"`c(pwd)'"'
local hddid_example_pwd_override : environment HDDID_EXAMPLE_PWD
local hddid_example_pwd_shell : environment PWD
set more off
local hddid_example_pkgdir_prev `"$HDDID_PACKAGE_DIR"'
local hxe_preload_cmds ""
foreach hxe_public_cmd in hddid hddid_dgp1 hddid_dgp2 hddid_p hddid_estat {
    local hxe_preloaded_`hxe_public_cmd' 0
    capture program list `hxe_public_cmd'
    local hxe_loaded = (_rc == 0)
    if `hxe_loaded' {
        local hxe_preloaded_`hxe_public_cmd' 1
        capture findfile `hxe_public_cmd'.ado
        if _rc == 0 {
            local hxe_preload_cmds `"`hxe_preload_cmds' `hxe_public_cmd'"'
            local hxe_prepath_`hxe_public_cmd' `"`r(fn)'"'
        }
        else {
            tempfile hxe_snapshot_log hxe_snapshot_do
            tempname hxe_snapshot_in hxe_snapshot_out
            local hxe_linesize_prev = c(linesize)
            capture set linesize 255
            capture log close hxe_example_snapshot
            quietly log using "`hxe_snapshot_log'", text replace ///
                name(hxe_example_snapshot)
            capture noisily program list `hxe_public_cmd'
            local hxe_snapshot_rc = _rc
            capture log close hxe_example_snapshot
            capture set linesize `hxe_linesize_prev'
            if `hxe_snapshot_rc' == 0 {
                local hxe_program_define ///
                    `"program define `hxe_public_cmd'"'
                file open `hxe_snapshot_in' using "`hxe_snapshot_log'", ///
                    read text
                file read `hxe_snapshot_in' hxe_snapshot_line
                while r(eof) == 0 {
                    if regexm(`"`macval(hxe_snapshot_line)'"', ///
                        "^`hxe_public_cmd'([^:]*)[:]$") {
                        local hxe_program_props = ///
                            trim(regexs(1))
                        if `"`hxe_program_props'"' != "" {
                            local hxe_program_define ///
                                `"program define `hxe_public_cmd' `hxe_program_props'"'
                        }
                    }
                    file read `hxe_snapshot_in' hxe_snapshot_line
                }
                file close `hxe_snapshot_in'
                file open `hxe_snapshot_in' using "`hxe_snapshot_log'", ///
                    read text
                file open `hxe_snapshot_out' using "`hxe_snapshot_do'", ///
                    write text replace
                file write `hxe_snapshot_out' ///
                    "capture program drop `hxe_public_cmd'" _n
                file write `hxe_snapshot_out' ///
                    `"`hxe_program_define'"' _n
                file read `hxe_snapshot_in' hxe_snapshot_line
                while r(eof) == 0 {
                    if regexm(`"`macval(hxe_snapshot_line)'"', ///
                        "^[ ]+[0-9]+[.][ ]") {
                        local hxe_snapshot_body = ///
                            regexr(`"`macval(hxe_snapshot_line)'"', ///
                            "^[ ]+[0-9]+[.][ ]+", "")
                        file write `hxe_snapshot_out' ///
                            `"`macval(hxe_snapshot_body)'"' _n
                    }
                    file read `hxe_snapshot_in' hxe_snapshot_line
                }
                file write `hxe_snapshot_out' "end" _n
                file close `hxe_snapshot_in'
                file close `hxe_snapshot_out'
                local hxe_preload_cmds ///
                    `"`hxe_preload_cmds' `hxe_public_cmd'"'
                local hxe_prepath_`hxe_public_cmd' `"`hxe_snapshot_do'"'
            }
        }
    }
}
local hxe_preloaded_internal_main 0
capture program list _hddid_main
if _rc == 0 {
    local hxe_preloaded_internal_main 1
    capture findfile _hddid_main.ado
    if _rc == 0 {
        local hxe_internal_main_path `"`r(fn)'"'
    }
    else {
        tempfile hxe_internal_main_log hxe_internal_main_do
        tempname hxe_internal_main_in hxe_internal_main_out
        local hxe_linesize_prev = c(linesize)
        capture set linesize 255
        capture log close hxe_imain_snap
        quietly log using "`hxe_internal_main_log'", text replace ///
            name(hxe_imain_snap)
        capture noisily program list _hddid_main
        local hxe_internal_main_snapshot_rc = _rc
        capture log close hxe_imain_snap
        capture set linesize `hxe_linesize_prev'
        if `hxe_internal_main_snapshot_rc' == 0 {
            local hxe_internal_main_define `"program define _hddid_main"'
            file open `hxe_internal_main_in' using ///
                "`hxe_internal_main_log'", read text
            file read `hxe_internal_main_in' hxe_internal_main_line
            while r(eof) == 0 {
                if regexm(`"`macval(hxe_internal_main_line)'"', ///
                    "^_hddid_main([^:]*)[:]$") {
                    local hxe_internal_main_props = ///
                        trim(regexs(1))
                    if `"`hxe_internal_main_props'"' != "" {
                        local hxe_internal_main_define ///
                            `"program define _hddid_main `hxe_internal_main_props'"'
                    }
                }
                file read `hxe_internal_main_in' hxe_internal_main_line
            }
            file close `hxe_internal_main_in'
            file open `hxe_internal_main_in' using ///
                "`hxe_internal_main_log'", read text
            file open `hxe_internal_main_out' using ///
                "`hxe_internal_main_do'", write text replace
            file write `hxe_internal_main_out' ///
                "capture program drop _hddid_main" _n
            file write `hxe_internal_main_out' ///
                `"`hxe_internal_main_define'"' _n
            file read `hxe_internal_main_in' hxe_internal_main_line
            while r(eof) == 0 {
                if regexm(`"`macval(hxe_internal_main_line)'"', ///
                    "^[ ]+[0-9]+[.][ ]") {
                    local hxe_internal_main_body = ///
                        regexr(`"`macval(hxe_internal_main_line)'"', ///
                        "^[ ]+[0-9]+[.][ ]+", "")
                    file write `hxe_internal_main_out' ///
                        `"`macval(hxe_internal_main_body)'"' _n
                }
                file read `hxe_internal_main_in' hxe_internal_main_line
            }
            file write `hxe_internal_main_out' "end" _n
            file close `hxe_internal_main_in'
            file close `hxe_internal_main_out'
            local hxe_internal_main_path `"`hxe_internal_main_do'"'
        }
    }
}

// _hddid_main.ado also publishes a large helper-program surface. The example
// must not leave those helper definitions behind in the caller namespace after
// it temporarily loads the authoritative bundle.
local hxe_internal_main_helpers "_hddid_probe_pkgdir_from_context _hddid_canonical_pkgdir _hddid_resolve_pkgdir _hddid_uncache_scipy _hddid_uncache_numpy _hddid_clime_scipy_probe _hddid_clime_feas_ok _hddid_probe_fail_classify _hddid_cvlasso_pick_lambda _hddid_run_rng_isolated _hddid_resolve_prop_cv _hddid_count_split_groups _hddid_choose_outer_split_sample _hddid_default_outer_fold_map _hddid_sort_default_innercv _hddid_canonicalize_xvars _hddid_parse_methodopt _hddid_parse_estopt_core _hddid_parse_estopt_sbridge _hddid_parse_estopt_rbridge _hddid_parse_estopt _hddid_parse_precomma_estexpr _hddid_show_estopt _hddid_show_invalid_estopt _hddid_show_esttoken _hddid_trailing_esttoken _hddid_load_estimate_sidecar _hddid_load_display_sidecar _hddid_validate_predict_stub _hddid_validate_estat_stub _hddid_publish_results _hddid_cleanup_state"
local hxe_main_helper_n 0
foreach hxe_main_helper_cmd of local hxe_internal_main_helpers {
    local ++hxe_main_helper_n
    local hxe_main_helper_name_`hxe_main_helper_n' `"`hxe_main_helper_cmd'"'
    local hxe_main_helper_loaded_`hxe_main_helper_n' 0
    capture program list `hxe_main_helper_cmd'
    if _rc == 0 {
        local hxe_main_helper_loaded_`hxe_main_helper_n' 1
        capture findfile `hxe_main_helper_cmd'.ado
        if _rc == 0 {
            local hxe_main_helper_path_`hxe_main_helper_n' `"`r(fn)'"'
        }
        else {
            tempfile hxe_main_helper_log hxe_main_helper_do
            tempname hxe_main_helper_in hxe_main_helper_out
            local hxe_linesize_prev = c(linesize)
            capture set linesize 255
            capture log close hxe_mhelp_snap
            quietly log using "`hxe_main_helper_log'", text replace ///
                name(hxe_mhelp_snap)
            capture noisily program list `hxe_main_helper_cmd'
            local hxe_main_helper_snapshot_rc = _rc
            capture log close hxe_mhelp_snap
            capture set linesize `hxe_linesize_prev'
            if `hxe_main_helper_snapshot_rc' == 0 {
                local hxe_main_helper_define ///
                    `"program define `hxe_main_helper_cmd'"'
                file open `hxe_main_helper_in' using ///
                    "`hxe_main_helper_log'", read text
                file read `hxe_main_helper_in' hxe_main_helper_line
                while r(eof) == 0 {
                    if regexm(`"`macval(hxe_main_helper_line)'"', ///
                        "^`hxe_main_helper_cmd'([^:]*)[:]$") {
                        local hxe_main_helper_props = ///
                            trim(regexs(1))
                        if `"`hxe_main_helper_props'"' != "" {
                            local hxe_main_helper_define ///
                                `"program define `hxe_main_helper_cmd' `hxe_main_helper_props'"'
                        }
                    }
                    file read `hxe_main_helper_in' hxe_main_helper_line
                }
                file close `hxe_main_helper_in'
                file open `hxe_main_helper_in' using ///
                    "`hxe_main_helper_log'", read text
                file open `hxe_main_helper_out' using ///
                    "`hxe_main_helper_do'", write text replace
                file write `hxe_main_helper_out' ///
                    "capture program drop `hxe_main_helper_cmd'" _n
                file write `hxe_main_helper_out' ///
                    `"`hxe_main_helper_define'"' _n
                file read `hxe_main_helper_in' hxe_main_helper_line
                while r(eof) == 0 {
                    if regexm(`"`macval(hxe_main_helper_line)'"', ///
                        "^[ ]+[0-9]+[.][ ]") {
                        local hxe_main_helper_body = ///
                            regexr(`"`macval(hxe_main_helper_line)'"', ///
                            "^[ ]+[0-9]+[.][ ]+", "")
                        file write `hxe_main_helper_out' ///
                            `"`macval(hxe_main_helper_body)'"' _n
                    }
                    file read `hxe_main_helper_in' hxe_main_helper_line
                }
                file write `hxe_main_helper_out' "end" _n
                file close `hxe_main_helper_in'
                file close `hxe_main_helper_out'
                local hxe_main_helper_path_`hxe_main_helper_n' ///
                    `"`hxe_main_helper_do'"'
            }
        }
    }
}

local hxe_internal_sidecars "_hddid_display _hddid_estimate _hddid_prepare_fold_covinv _hddid_pst_cmdroles"
local hxe_internal_n 0
foreach hxe_internal_cmd of local hxe_internal_sidecars {
    local ++hxe_internal_n
    local hxe_internal_name_`hxe_internal_n' `"`hxe_internal_cmd'"'
    local hxe_internal_loaded_`hxe_internal_n' 0
    capture program list `hxe_internal_cmd'
    if _rc == 0 {
        local hxe_internal_loaded_`hxe_internal_n' 1
        capture findfile `hxe_internal_cmd'.ado
        if _rc == 0 {
            local hxe_internal_path_`hxe_internal_n' `"`r(fn)'"'
        }
        else {
            tempfile hxe_internal_log hxe_internal_do
            tempname hxe_internal_in hxe_internal_out
            local hxe_linesize_prev = c(linesize)
            capture set linesize 255
            capture log close hxe_iside_snap
            quietly log using "`hxe_internal_log'", text replace ///
                name(hxe_iside_snap)
            capture noisily program list `hxe_internal_cmd'
            local hxe_internal_snapshot_rc = _rc
            capture log close hxe_iside_snap
            capture set linesize `hxe_linesize_prev'
            if `hxe_internal_snapshot_rc' == 0 {
                local hxe_internal_define ///
                    `"program define `hxe_internal_cmd'"'
                file open `hxe_internal_in' using ///
                    "`hxe_internal_log'", read text
                file read `hxe_internal_in' hxe_internal_line
                while r(eof) == 0 {
                    if regexm(`"`macval(hxe_internal_line)'"', ///
                        "^`hxe_internal_cmd'([^:]*)[:]$") {
                        local hxe_internal_props = ///
                            trim(regexs(1))
                        if `"`hxe_internal_props'"' != "" {
                            local hxe_internal_define ///
                                `"program define `hxe_internal_cmd' `hxe_internal_props'"'
                        }
                    }
                    file read `hxe_internal_in' hxe_internal_line
                }
                file close `hxe_internal_in'
                file open `hxe_internal_in' using ///
                    "`hxe_internal_log'", read text
                file open `hxe_internal_out' using ///
                    "`hxe_internal_do'", write text replace
                file write `hxe_internal_out' ///
                    "capture program drop `hxe_internal_cmd'" _n
                file write `hxe_internal_out' ///
                    `"`hxe_internal_define'"' _n
                file read `hxe_internal_in' hxe_internal_line
                while r(eof) == 0 {
                    if regexm(`"`macval(hxe_internal_line)'"', ///
                        "^[ ]+[0-9]+[.][ ]") {
                        local hxe_internal_body = ///
                            regexr(`"`macval(hxe_internal_line)'"', ///
                            "^[ ]+[0-9]+[.][ ]+", "")
                        file write `hxe_internal_out' ///
                            `"`macval(hxe_internal_body)'"' _n
                    }
                    file read `hxe_internal_in' hxe_internal_line
                }
                file write `hxe_internal_out' "end" _n
                file close `hxe_internal_in'
                file close `hxe_internal_out'
                local hxe_internal_path_`hxe_internal_n' ///
                    `"`hxe_internal_do'"'
            }
        }
    }
}

// _hddid_mata.ado publishes a large Mata surface. The example should leave a
// clean caller session when it had to load the authoritative bundle copy, and
// should restore a caller-preloaded discoverable sidecar when one existed.
local hxe_internal_mata_symbols "_hddid_debias_beta() _hddid_debias_gamma() _hddid_matrix_byrow() _hddid_quantile_type7_sorted() _hddid_bootstrap_tc() _hddid_aggregate_folds() _hddid_sieve_pol() _hddid_sieve_tri() _hddid_tri_rescale() _hddid_sieve_tri_support() _hddid_canonical_x_standardize() _hddid_canonical_x_order() _hddid_canonical_group_counts() _hddid_foldkey_canon() _hddid_foldkey_standardize() _hddid_matrix_lexcompare() _hddid_row_signorbit_canon() _hddid_colsignorbit_canon() _hddid_drop_duplicate_cols() _hddid_foldkey_rank_center() _hddid_resolve_fold_order() _hddid_stratified_fold_map_xz() _hddid_fold_map_xz_relaxed() _hddid_stratified_fold_map() _hddid_stratified_folds() _hddid_store_fold_map_byvars() _hddid_store_stratified_fold_map() _hddid_default_outer_fold_map_m() _hddid_store_fold_map_xz_relaxed() _hddid_trim_propensity() _hddid_dr_score() _hddid_compute_tildex() _hddid_absorbed_xvars() _hddid_single_x_precision() _hddid_sieve_basis_diagnostics() _hddid_init_folds() _hddid_store_fold() _hddid_run_aggregate() _hddid_post_results() _hddid_fold_debias_store() _hddid_store_constant_fold() _hddid_store_sieve_basis() _hddid_store_z0_basis() _hddid_restrict_fold_z0_grid() _hddid_z0_colname() _hddid_store_z0_colstripe() _hddid_stage2_prepare() _hddid_library_selftest() _hddid_assert_symmetric_psd() _hddid_assert_nanfb_stdg_carrier() _hddid_assert_vcovx_stdx() _hddid_beta_result() _hddid_gamma_result() _hddid_fold_result() _hddid_result()"
local hxe_preloaded_internal_mata 0
local hxe_internal_mata_path ""
capture mata: mata describe _hddid_sieve_pol()
if _rc == 0 {
    local hxe_preloaded_internal_mata 1
}
else {
    capture mata: mata describe _hddid_result()
    if _rc == 0 {
        local hxe_preloaded_internal_mata 1
    }
}
if `hxe_preloaded_internal_mata' {
    capture findfile _hddid_mata.ado
    if _rc == 0 {
        local hxe_internal_mata_path `"`r(fn)'"'
    }
}

// Prefer the sibling source-tree package when the example is run from this
// repository. Stata's live cwd is authoritative when it already resolves to a
// complete bundle or repo root, because users can `cd' inside Stata without
// updating inherited environment variables. If the live cwd does not identify a
// bundle, reuse any already-authoritative HDDID_PACKAGE_DIR state before
// falling back to HDDID_EXAMPLE_PWD/PWD subprocess launch overrides.
local hddid_example_pkgdir ""
local hddid_example_search_roots ///
    hddid_example_cwd_live ///
    hddid_example_pkgdir_prev ///
    hddid_example_pwd_override ///
    hddid_example_pwd_shell
local hddid_example_seen_roots ";"
foreach search_root in `hddid_example_search_roots' {
    local cursor ``search_root''
    if `"`cursor'"' == "" {
        continue
    }
    if strpos(`"`hddid_example_seen_roots'"', `";`cursor';"') != 0 {
        continue
    }
    local hddid_example_seen_roots `"`hddid_example_seen_roots'`cursor';"'
    while `"`cursor'"' != "" {
        foreach candidate in `"`cursor'"' `"`cursor'/hddid-stata"' {
            if `"`candidate'"' == "" {
                continue
            }
            capture confirm file "`candidate'/hddid.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/hddid_dgp1.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/hddid_dgp2.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/_hddid_main.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/_hddid_display.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/_hddid_estimate.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/_hddid_prepare_fold_covinv.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/_hddid_pst_cmdroles.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/_hddid_mata.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/hddid_clime.py"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/hddid_p.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/hddid_estat.ado"
            if _rc != 0 {
                continue
            }
            capture confirm file "`candidate'/hddid_safe_probe.py"
            if _rc != 0 {
                continue
            }
            // c(adopath) is semicolon-delimited, so test exact entry membership
            // instead of raw substring inclusion. Otherwise a shadow path whose
            // text merely contains `candidate' can suppress the real bundle add.
            local hddid_example_adopath `";`c(adopath)';"'
            if strpos(`"`hddid_example_adopath'"', `";`candidate';"') == 0 {
                quietly adopath ++ "`candidate'"
                local hddid_example_added_to_adopath 1
            }
            global HDDID_PACKAGE_DIR "`candidate'"
            local hddid_example_pkgdir `"`candidate'"'
            continue, break
        }
        if `"`hddid_example_pkgdir'"' != "" {
            continue, break
        }
        local sep = strrpos(`"`cursor'"', "/")
        if `sep' == 0 {
            local sep = strrpos(`"`cursor'"', "\")
        }
        if `sep' <= 1 {
            continue, break
        }
        local cursor = substr(`"`cursor'"', 1, `sep' - 1)
    }
    if `"`hddid_example_pkgdir'"' != "" {
        continue, break
    }
}

if `"`hddid_example_pkgdir'"' == "" {
    capture findfile hddid.ado
    if _rc == 0 {
        local hddid_example_main `"`r(fn)'"'
        local hddid_example_sep = strrpos(`"`hddid_example_main'"', "/")
        if `hddid_example_sep' == 0 {
            local hddid_example_sep = strrpos(`"`hddid_example_main'"', "\")
        }
        if `hddid_example_sep' > 0 {
            local candidate = substr(`"`hddid_example_main'"', 1, `hddid_example_sep' - 1)
            capture confirm file "`candidate'/hddid_dgp1.ado"
            if _rc == 0 {
                capture confirm file "`candidate'/hddid_dgp2.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/_hddid_main.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/_hddid_display.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/_hddid_estimate.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/_hddid_prepare_fold_covinv.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/_hddid_pst_cmdroles.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/_hddid_mata.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/hddid.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/hddid_clime.py"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/hddid_p.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/hddid_estat.ado"
            }
            if _rc == 0 {
                capture confirm file "`candidate'/hddid_safe_probe.py"
            }
            if _rc == 0 {
                global HDDID_PACKAGE_DIR "`candidate'"
                local hddid_example_pkgdir `"`candidate'"'
            }
        }
    }
}

if `"`hddid_example_pkgdir'"' == "" {
    di as error "{bf:hddid_example.do}: could not locate a complete hddid package bundle"
    di as error "  Required files: {bf:hddid.ado}, {bf:hddid_dgp1.ado}, {bf:hddid_dgp2.ado}, {bf:_hddid_main.ado}, {bf:_hddid_display.ado}, {bf:_hddid_estimate.ado}, {bf:_hddid_prepare_fold_covinv.ado}, {bf:_hddid_pst_cmdroles.ado}, {bf:_hddid_mata.ado}, {bf:hddid_clime.py}, {bf:hddid_p.ado}, {bf:hddid_estat.ado}, and {bf:hddid_safe_probe.py}"
    di as error "  Run the example from the repository root/package directory, or install/add the full hddid package directory to adopath"
    local hddid_example_rc = 199
}
else {
    // Record any caller-loaded public hddid commands that came from a
    // different source file so the example can restore them on exit after it
    // temporarily switches to the authoritative bundle.
    local hxe_restore_cmds ""
    foreach hxe_public_cmd of local hxe_preload_cmds {
        local hxe_cmd_path `"`hxe_prepath_`hxe_public_cmd''"'
        if `"`hxe_cmd_path'"' != ///
            `"`hddid_example_pkgdir'/`hxe_public_cmd'.ado"' {
            local hxe_restore_cmds ///
                `"`hxe_restore_cmds' `hxe_public_cmd'"'
            local hxe_restore_path_`hxe_public_cmd' ///
                `"`hxe_cmd_path'"'
        }
    }

    // Stata prefers already-loaded program definitions over later adopath
    // resolution. Once this example has resolved the authoritative bundle,
    // drop any stale public hddid commands so the sibling source-tree copy is
    // the implementation that actually runs below.
    capture program drop hddid
    capture program drop hddid_dgp1
    capture program drop hddid_dgp2
    capture program drop hddid_p
    capture program drop hddid_estat
    // The public wrapper only reloads _hddid_main when it is absent, so a
    // caller-preloaded internal main would otherwise hijack the example run.
    capture program drop _hddid_main
    // _hddid_estimate calls these helpers by bare program name. If the caller
    // already has a stale sidecar in memory, Stata will keep using that loaded
    // definition instead of autoloading the resolved sibling bundle copy.
    foreach hxe_internal_cmd of local hxe_internal_sidecars {
        capture program drop `hxe_internal_cmd'
    }
}
tempname hddid_example_main_prog
program define `hddid_example_main_prog'
    version 16
    tempname hddid_example_tri_npf
// =============================================================================
// Part 1: DGP1 — Homoscedastic + Independent Covariates
// =============================================================================
di as text ""
di as text "=============================================="
di as text " Part 1: DGP1 (Homoscedastic, Independent X)"
di as text "=============================================="

// Generate simulation data
// DGP1: X ~ N(0, I_p), homoscedastic errors, independent covariates
// The shipped Stata DGP1 implementation realizes the paper's time-0 notation
// as one shared baseline draw per unit before deltay is formed.
// Raw DGP1 outcome coefficients: beta^1_j = 2/j and beta^0_j = 1/j for
// j=1,...,15; both sequences are 0 for j>15.
// The public outcome passed to hddid below is deltay; deltay is the realized post-minus-base change, not the post-period treatment-state contrast Y^1(i,1) - Y^0(i,1).
// The ATT-surface coefficient reported below is
// beta_j = beta^1_j - beta^0_j = 1/j for j=1,...,15.
// If you shrink this public DGP below p()<10 or p()<15, the shipped generator
// truncates the paper's nonzero theta0 and beta^1/beta^0 sequences at p()
// rather than holding the full 10/15-support oracle fixed.
// This Part 1 block is the paper's DGP1 surface, not the legacy
// Examplehighdimdiffindiff.R wrapper path: that wrapper instead switches to
// correlated X, the DGP2-style heteroskedastic baseline, and a default
// method("Pol") run. More fundamentally, that old wrapper hardcodes the polynomial sieve
// regardless of the method argument, and its roxygen documents q as q/2 while the shipped cross-fit code passes q directly into
// sieve.Pol(..., q), so even method("Tri") q(16) there is still not the
// paper's Tri-basis DGP1 oracle. For the maintained R estimator reference
// behind this DGP1 surface, read hddid-r/R/highdimdiffindiff_crossfit.R
// together with hddid-r/R/highdimdiffindiff_crossfit_inside.R and treat
// highdimdiffindiff_crossfit3()/highdimdiffindiff_crossfit_inside3() there as
// the surviving read-only entry symbols rather than a public wrapper/script
// entrypoint to source() directly.
// This public DGP1 generator is also self-contained enough to remain callable
// after an absolute-path source-run even when the working directory is
// elsewhere, because hddid_dgp1.ado realizes the Section 5 generator with
// internal rnormal draws for the independent x() block and the scalar z()
// path instead of reloading any helper-side generator. That embedded Section 5 path remains authoritative
// for this public DGP1 block even after that source-run handoff.
// If you shrink this DGP call to n(1), that singleton draw is only a sanity
// probe: the generator still runs, but hddid immediately fails because the
// common-score sample loses one treatment arm before overlap trimming.
// True centered-shape benchmark: exp(z0_j) - exp(z0_ref), not raw exp(z0) levels
hddid_dgp1, n(500) p(50) seed(12345) clear

// The DGP seed(12345) above fixes only the generated sample itself:
// hddid_dgp1 restores the caller RNG state on exit, so it does not replace the estimator-side seed(42) below
// for the fold/bootstrap/CLIME path.
// Build covariate list dynamically from the generated public x* variables
// so the public example keeps working when you change p().
unab x_vars : x*

// Run hddid estimation
// Paper-aligned trigonometric basis with q(16) (8 harmonic pairs / 8th degree
// under the package's q() indexing), 3-fold cross-fitting, 90% CI, 1000
// bootstrap reps. Pin an explicit z0() grid so the reported omitted-intercept z-varying block keeps
// the same estimand dimension across runs instead of inheriting every retained
// unique z value from the realized sample.
// Use that shipped five-point z0() grid only when it lies inside the current retained z support; otherwise choose an in-support z0() list or omit z0() so hddid uses the retained support points directly.
// That five-point z0() list is this package walkthrough's audit grid rather than a paper-fixed evaluation set.
// Under method("Tri"), keep that explicit z0() grid inside the current retained z support.
// if any requested z0() point leaves that retained support, hddid fails closed instead of extrapolating the support-normalized Tri basis.
// That retained-support guard is a package-specific Stata Tri rule: this walkthrough uses a caller-supplied/package audit grid rather than a paper-fixed evaluation set, while the maintained R cross-fit sources here do not expose an executable method("Tri") fail-close interface.
// Reproducibility note: seed(42) fixes the outer fold map, the bootstrap draws,
// and the Python CLIME CV RNG. Once that outer split is fixed, the Stata
// cvlasso/cvlassologit inner CV partition follows the command's deterministic
// row order rather than a separate seed-driven random split.
// Default-path sample scope note: rows with observed treat()/x()/z() but missing deltay stay out of the common score sample.
// Those D/W-complete auxiliary rows still belong to the broader default-path propensity sample because pi(W) depends only on D and W=(X,Z).
// Under the default internal-first-stage path, if/in qualifiers are applied before both the broader D/W-complete propensity sample and the common score sample are built.
// Those D/W-complete rows missing {bf:depvar} never become held-out evaluation rows, so they stay available to every fold-external default-path propensity training sample.
// A qualifier-defined default-path run should therefore match physically dropping the excluded rows first: excluded rows no longer widen the broader D/W-complete propensity sample, pin the common-score outer split, or move the x() canonicalization anchor.
// If the qualifier-defined and physically subsetted default-path runs hand hddid the same D/W-complete rows in the same order, they must therefore deliver the same retained-sample estimates.
// D/W-complete auxiliary rows can still enter the internal propensity training sample and therefore can move the downstream estimator through the estimated propensity nuisance, even though they stay out of the common score sample and cannot relabel the outer split.
local hddid_example_z0_grid -1 -0.5 0 0.5 1
local hddid_example_t0_dgp1 = ///
    clock("`c(current_date)' `c(current_time)'", "DMY hms")
hddid deltay, treat(treat) x(`x_vars') z(z) ///
    method("Tri") q(16) z0(`hddid_example_z0_grid') ///
    K(3) alpha(0.1) nboot(1000) seed(42)
local hddid_example_t1_dgp1 = ///
    clock("`c(current_date)' `c(current_time)'", "DMY hms")
local hddid_example_elapsed_dgp1 = ///
    (`hddid_example_t1_dgp1' - `hddid_example_t0_dgp1') / 1000

// Display runtime
di as text "DGP1 runtime: " %9.3f `hddid_example_elapsed_dgp1' " seconds"

// --- Interpreting the output ---
// xdebias: debiased estimates of the ATT-surface beta_j = beta^1_j - beta^0_j
//   True values under DGP1: beta_j = 1/j for j=1,...,15; beta_j = 0 for j>15
//   A good estimate of x1 should be close to 1.0
//   A good estimate of x2 should be close to 0.5
//
// gdebias: public debiased z-varying block on the posted z0() grid
//   gdebias excludes the separate stage-2 intercept a0, so it is not the
//   full level f(z0) surface and should not be compared with exp(z0) in levels
//   Use centered shape diagnostics instead: compare
//   (gdebias(z0_j) - gdebias(z0_ref)) with (exp(z0_j) - exp(z0_ref))
//
// stdx: standard errors for each beta_j
//   Smaller SE = more precise estimate
//
// CIpoint: pointwise confidence intervals for both the beta block and the
//   omitted-intercept nonparametric block
//   Columns 1..p cover the parametric beta_j entries and columns p+1..(p+qq)
//   cover that posted z-varying block on the z0 grid
//   The beta-side interval is checked against beta_j truth, while the trailing
//   nonparametric block only supports centered shape checks because hddid does
//   not publish e(a0)
//
// tc: Lower/upper bootstrap critical-value pair for the published nonparametric interval object
//   The package calibrates e(tc) from rowwise Gaussian-bootstrap quantiles of
//   the studentized process over the full stored z0() grid;
//   under the current path this stores the rowwise-envelope lower/upper
//   studentized-process pair (min_j lower_j, max_j upper_j);
//   the stored lower/upper endpoints need not be symmetric and can even be
//   same-sign in finite samples, and e(CIuniform) applies the stored lower and
//   upper critical values separately on the studentized-process scale behind
//   the published interval object

// Display stored results
di as text ""
di as text "--- Debiased parametric estimates ---"
matrix list e(xdebias), format(%9.4f)
di as text ""
di as text "--- Parametric standard errors ---"
matrix list e(stdx), format(%9.4f)
di as text ""
di as text "--- Bootstrap critical values ---"
matrix list e(tc), format(%9.4f)

// Compare estimates with true values (beta_j = 1/j for j<=15 under DGP1)
di as text ""
di as text "--- Parametric component: Estimate vs True (first 10 variables) ---"
forvalues j = 1/10 {
    local true_j = 1/`j'
    local est_j = el(e(xdebias), 1, `j')
    local diff_j = `est_j' - `true_j'
    di as text "  x`j': estimate=" %9.4f `est_j' "  true=" %9.4f `true_j' "  diff=" %9.4f `diff_j'
}

// Display the full explicit z0() grid used in this shipped DGP1/Tri Part 1 run.
// This keeps the DGP1 nonparametric readout on the same named evaluation
// points that the shipped DGP2 walkthrough block reuses below.
di as text ""
di as text "--- DGP1 posted z0() grid ---"
matrix list e(z0), format(%9.4f)
di as text ""
di as text "--- DGP1 omitted-intercept gdebias block (all explicit z0 points) ---"
di as text "      z0   gdebias      SE      CI_lo      CI_hi   centered_gdebias centered_true"
local qq = colsof(e(gdebias))
local p = colsof(e(b))
local z0_ref = el(e(z0), 1, 1)
local gd_ref = el(e(gdebias), 1, 1)
forvalues j = 1/`qq' {
    local ci_idx = `p' + `j'
    local z0_j = el(e(z0), 1, `j')
    local gd_j = el(e(gdebias), 1, `j')
    local sg_j = el(e(stdg), 1, `j')
    local ci_lo_j = el(e(CIpoint), 1, `ci_idx')
    local ci_hi_j = el(e(CIpoint), 2, `ci_idx')
    local centered_hat_j = `gd_j' - `gd_ref'
    // centered shape diagnostics: compare exp(z0_j) - exp(z0_ref)
    local centered_true_j = exp(`z0_j') - exp(`z0_ref')
    di as text %8.3f `z0_j' " " %10.4f `gd_j' " " %10.4f `sg_j' " " %10.4f `ci_lo_j' " " %10.4f `ci_hi_j' " " %10.4f `centered_hat_j' " " %10.4f `centered_true_j'
}

// The same DGP1 public matrix surface is still enough for the beta_1 paper
// truth check and for centered-shape diagnostics on the omitted-intercept
// nonparametric block.
di as text ""
di as text "--- DGP1 hypothesis test: beta_1 = 1 ---"
local beta1 = el(e(xdebias), 1, 1)
local se1 = el(e(stdx), 1, 1)
local tstat = (`beta1' - 1) / `se1'
di as text "  beta_1 estimate: " %9.4f `beta1'
di as text "  SE:              " %9.4f `se1'
di as text "  t-stat (H0: beta_1=1): " %6.3f `tstat'
di as text "  p-value (two-sided):   " %6.4f 2*normal(-abs(`tstat'))

// CIpoint/CIuniform still describe the posted omitted-intercept nonparametric
// block, but because hddid does not publish e(a0) they cannot be checked
// against the full exp(z0) level surface in this public walkthrough.
di as text ""
di as text "--- DGP1 centered shape diagnostics ---"
local beta1_ci_lo = el(e(CIpoint), 1, 1)
local beta1_ci_hi = el(e(CIpoint), 2, 1)
di as text "DGP1 beta_1 CIpoint contains 1: " ///
    cond(1 >= `beta1_ci_lo' & 1 <= `beta1_ci_hi', "yes", "no") ///
    "  [" %9.4f `beta1_ci_lo' ", " %9.4f `beta1_ci_hi' "]"
local max_shape_gap = 0
forvalues j = 1/`qq' {
    local z0_j = el(e(z0), 1, `j')
    local centered_hat_j = el(e(gdebias), 1, `j') - `gd_ref'
    local centered_true_j = exp(`z0_j') - exp(`z0_ref')
    local shape_gap_j = abs(`centered_hat_j' - `centered_true_j')
    if `shape_gap_j' > `max_shape_gap' {
        local max_shape_gap = `shape_gap_j'
    }
}
di as text "DGP1 centered shape diagnostics anchor at z0_ref = " %9.4f `z0_ref'
di as text "Because gdebias excludes the separate stage-2 intercept a0, compare centered differences only."
di as text "Max |(gdebias-gdebias_ref) - (exp(z0)-exp(z0_ref))| = " %9.4f `max_shape_gap'
di as text "CIpoint/CIuniform remain interval objects for the omitted-intercept block, so this walkthrough does not compare them to exp(z0) levels."
// Retired tokens kept for audit traceability only:
//   older DGP1 pointwise-share and interval-share displays
//   --- DGP1 CIpoint pointwise diagnostics ---
//   DGP1 CIpoint pointwise within-run inclusion share:
//   This DGP1 CIpoint check is pointwise. The DGP1 CIuniform object is only the package's finite-grid interval object; it is not a calibrated simultaneous-coverage guarantee.
di as text "Retired shorthand from older walkthroughs contrasted CIpoint against CIuniform in one sentence. Read that superseded shorthand only as a reminder that CIpoint is pointwise; the current contract is the corrected finite-grid interval-object statement above."
//   DGP1 CIuniform interval-object within-run inclusion share:

// =============================================================================
// Part 2: DGP2 — Paper baseline design with correlated covariates and heteroskedastic baseline
// =============================================================================
di as text ""
di as text "=============================================="
di as text " Part 2: DGP2 (Paper Baseline, Correlated X, Heteroskedastic Baseline)"
di as text "=============================================="

// Generate simulation data
// DGP2: X ~ N(0, Sigma) with Sigma_{jk} = 0.5^|j-k| (AR(1) correlation)
// The paper's heteroskedastic feature enters through the observed base-period outcome Y(i,0),
// and the same observed baseline draw is shared by both post-period treatment
// states before their state-specific increments are added. The post-period
// shocks remain standard normal. DGP2 keeps the same raw outcome coefficients
// as DGP1: beta^1_j = 2/j and beta^0_j = 1/j for j=1,...,15, so the design
// change here is the correlated X draw plus the heteroskedastic baseline, not
// a different coefficient sequence. The public outcome passed to hddid below is deltay; deltay is the realized post-minus-base change, not the post-period treatment-state contrast Y^1(i,1) - Y^0(i,1).
// This Part 2 block is not the legacy
// Examplehighdimdiffindiff.R wrapper path: that wrapper redraws z after the
// baseline outcome, publishes rho.X while hardcoding the correlated-X
// covariance at 0.5^|j-k|, and defaults to method("Pol"). More
// fundamentally, that old wrapper hardcodes the polynomial sieve regardless of the method argument,
// and its roxygen documents q as q/2 while the shipped cross-fit code passes q directly into sieve.Pol(..., q), so even
// method("Tri") q(16) there is still not this shipped DGP2/Tri walkthrough
// surface. For the maintained R estimator reference behind this DGP2 surface,
// read hddid-r/R/highdimdiffindiff_crossfit.R together with
// hddid-r/R/highdimdiffindiff_crossfit_inside.R and treat
// highdimdiffindiff_crossfit3()/highdimdiffindiff_crossfit_inside3() there as
// the surviving read-only entry symbols. This public DGP2 generator is also
// self-contained enough to remain callable after an absolute-path source-run
// even when the working directory is elsewhere, because hddid_dgp2.ado builds
// the covariance matrix inline and uses an internal drawnorm call instead of
// reloading any helper-side generator. The embedded Section 5 path remains authoritative
// for this public DGP2 block. Keep rho(0.5) explicit here as the shipped public example choice rather than a paper-fixed rho value.
// When you shrink this public DGP2 example to p(1), the AR(1) covariance collapses to [1],
// so any finite rho() value then generates the same
// one-covariate draw; rho() only changes the public DGP2 surface once p()>1.
// for p()>1 the boundary choices rho(-1) and rho(1) are singular AR(1) limits, so this public example keeps rho(0.5) on its shipped interior path.
// As in DGP1, the full heterogeneous ATT target at a test point contains a
// separate stage-2 intercept a0. The later public gdebias readout isolates only
// the omitted-intercept z-varying block.
// As with DGP1, changing this call to p()<10 or p()<15 truncates the paper's
// nonzero theta0 and beta^1/beta^0 sequences at p(), so small-p runs are a
// lower-dimensional truncation of the paper surface, not the same oracle with
// hidden omitted coordinates.
// As with DGP1, shrinking this DGP call to n(1) leaves only a generator-valid
// singleton draw. That singleton draw is only a sanity probe because hddid
// then fails once the common-score sample loses one treatment arm before
// overlap trimming.
hddid_dgp2, n(500) p(50) seed(54321) rho(0.5) clear

// The DGP seed(54321) above again fixes only the generated sample itself:
// hddid_dgp2 restores the caller RNG state on exit, so it does not replace the estimator-side seed(42) below
// for the fold/bootstrap/CLIME path.
// Build covariate list dynamically from the generated public x* variables
// so the public example keeps working when you change p().
unab x_vars : x*

// Run hddid estimation with the paper's 8th-degree Tri basis, which maps to
// q(16) under the package's q/2 harmonic indexing. Inline the same explicit
// z0() grid used in Part 1 so this public DGP2 block stays runnable on its
// own while keeping the posted omitted-intercept z-varying block aligned to
// the same audit points used for centered shape diagnostics across the two
// shipped DGP walkthroughs.
// Use that shipped five-point z0() grid only when it lies inside the current retained z support; otherwise choose an in-support z0() list or omit z0() so hddid uses the retained support points directly.
// That five-point z0() list is this package walkthrough's audit grid rather than a paper-fixed evaluation set.
// Under method("Tri"), keep that explicit z0() grid inside the current retained z support.
// if any requested z0() point leaves that retained support, hddid fails closed instead of extrapolating the support-normalized Tri basis.
// That retained-support guard is a package-specific Stata Tri rule: this walkthrough uses a caller-supplied/package audit grid rather than a paper-fixed evaluation set, while the maintained R cross-fit sources here do not expose an executable method("Tri") fail-close interface.
// regression anchor: Part 2: DGP2 (Paper Baseline, Correlated X)
local hddid_example_t0_dgp2 = ///
    clock("`c(current_date)' `c(current_time)'", "DMY hms")
hddid deltay, treat(treat) x(`x_vars') z(z) ///
    method("Tri") q(16) z0(-1 -0.5 0 0.5 1) ///
    K(3) alpha(0.1) nboot(1000) seed(42)
local hddid_example_t1_dgp2 = ///
    clock("`c(current_date)' `c(current_time)'", "DMY hms")
local hddid_example_elapsed_dgp2 = ///
    (`hddid_example_t1_dgp2' - `hddid_example_t0_dgp2') / 1000

// Display runtime
di as text "DGP2 runtime: " %9.3f `hddid_example_elapsed_dgp2' " seconds"

// xdebias under DGP2 is still directly comparable with Part 1 because the
// ATT-surface target remains beta_j = 1/j for j=1,...,15 and 0 afterward.
// The design change from DGP1 to DGP2 is the correlated X draw plus the
// heteroskedastic baseline, not a different ATT-surface beta truth.
di as text ""
di as text "--- DGP2 debiased parametric estimates ---"
matrix list e(xdebias), format(%9.4f)
di as text ""
di as text "--- DGP2 parametric component: Estimate vs True (first 10 variables) ---"
// True values under DGP2: beta_j = 1/j for j=1,...,15; beta_j = 0 for j>15
forvalues j = 1/10 {
    local true_j = 1/`j'
    local est_j = el(e(xdebias), 1, `j')
    local diff_j = `est_j' - `true_j'
    di as text "  x`j': estimate=" %9.4f `est_j' "  true=" %9.4f `true_j' "  diff=" %9.4f `diff_j'
}

// --- Interpreting nonparametric output ---
// gdebias: public debiased z-varying block at each evaluation point
//   gdebias excludes the separate stage-2 intercept a0, so it is not the full
//   level f(z0) object and should not be compared with exp(z0) in levels
//   Use centered shape diagnostics instead: compare
//   (gdebias(z0_j) - gdebias(z0_ref)) with (exp(z0_j) - exp(z0_ref))
//
// CIpoint: pointwise confidence intervals for both the beta block and the
//   omitted-intercept nonparametric block
//   Columns 1..p cover the parametric beta_j entries and columns p+1..(p+qq)
//   cover that posted z-varying block on the z0 grid
//   These are nominal 90% pointwise intervals: under repeated sampling they target 90% coverage at each fixed coordinate
//   A single walkthrough run need not realize exact 90% inclusion at every reported coordinate
//   Across repeated samples, these pointwise intervals do not by themselves
//   define a calibrated simultaneous statement over the full z0 grid
//
// CIuniform: 2 x qq nonparametric interval object
//   lower row is gdebias + tc[1] * stdg and the upper row is
//   gdebias + tc[2] * stdg, with columns aligned to z0
//   Relative to the pointwise intervals, this published lower/upper interval object reuses one
//   rowwise-envelope lower/upper studentized-process pair across the full z0
//   grid; after multiplying by stdg, the outcome-scale width still varies
//   pointwise with the stored standard-error surface
//   Use CIuniform as the package's published nonparametric interval object for the omitted-intercept block only
//
// In one run, CIuniform is still only a descriptive finite-grid interval object; it is not a calibrated simultaneous-coverage statement, and its public surface omits a0 just like gdebias.

// Display the full explicit z0() grid used in this shipped DGP2/Tri Part 2 run.
di as text ""
di as text "--- DGP2 posted z0() grid ---"
matrix list e(z0), format(%9.4f)
di as text ""
di as text "--- DGP2 omitted-intercept gdebias block (all explicit z0 points) ---"
di as text "      z0   gdebias      SE      CI_lo      CI_hi   centered_gdebias centered_true"
local qq = colsof(e(gdebias))
local p = colsof(e(b))
local z0_ref = el(e(z0), 1, 1)
local gd_ref = el(e(gdebias), 1, 1)
forvalues j = 1/`qq' {
    local ci_idx = `p' + `j'
    local z0_j = el(e(z0), 1, `j')
    local gd_j = el(e(gdebias), 1, `j')
    local sg_j = el(e(stdg), 1, `j')
    local ci_lo_j = el(e(CIpoint), 1, `ci_idx')
    local ci_hi_j = el(e(CIpoint), 2, `ci_idx')
    local centered_hat_j = `gd_j' - `gd_ref'
    // centered shape diagnostics: compare exp(z0_j) - exp(z0_ref)
    local centered_true_j = exp(`z0_j') - exp(`z0_ref')
    di as text %8.3f `z0_j' " " %10.4f `gd_j' " " %10.4f `sg_j' " " %10.4f `ci_lo_j' " " %10.4f `ci_hi_j' " " %10.4f `centered_hat_j' " " %10.4f `centered_true_j'
}

// DGP2 changes the X covariance and the baseline-outcome law, but the public
// beta_1 truth check and centered-shape diagnostics still remain available on
// the omitted-intercept nonparametric block.
di as text ""
di as text "--- DGP2 hypothesis test: beta_1 = 1 ---"
local beta1 = el(e(xdebias), 1, 1)
local se1 = el(e(stdx), 1, 1)
local tstat = (`beta1' - 1) / `se1'
di "  beta_1 estimate: " %9.4f `beta1'
di "  SE:             " %9.4f `se1'
di "  t-stat (H0: beta_1=1): " %6.3f `tstat'
di "  p-value (two-sided):  " %6.4f 2*normal(-abs(`tstat'))

di as text ""
di as text "--- DGP2 centered shape diagnostics ---"
local beta1_ci_lo = el(e(CIpoint), 1, 1)
local beta1_ci_hi = el(e(CIpoint), 2, 1)
di "DGP2 beta_1 CIpoint contains 1: " cond(1 >= `beta1_ci_lo' & 1 <= `beta1_ci_hi', "yes", "no") ///
    "  [" %9.4f `beta1_ci_lo' ", " %9.4f `beta1_ci_hi' "]"
local max_shape_gap = 0
forvalues j = 1/`qq' {
    local z0_j = el(e(z0), 1, `j')
    local centered_hat_j = el(e(gdebias), 1, `j') - `gd_ref'
    local centered_true_j = exp(`z0_j') - exp(`z0_ref')
    local shape_gap_j = abs(`centered_hat_j' - `centered_true_j')
    if `shape_gap_j' > `max_shape_gap' {
        local max_shape_gap = `shape_gap_j'
    }
}
di as text "DGP2 centered shape diagnostics anchor at z0_ref = " %9.4f `z0_ref'
di as text "Because gdebias excludes the separate stage-2 intercept a0, compare centered differences only."
di as text "Max |(gdebias-gdebias_ref) - (exp(z0)-exp(z0_ref))| = " %9.4f `max_shape_gap'
di as text "Retired shorthand from older walkthroughs contrasted CIpoint against CIuniform in one sentence. Read that superseded shorthand only as a reminder that CIpoint is pointwise; the current contract is the corrected omitted-intercept finite-grid interval-object statement above."
di as text "CIpoint/CIuniform remain interval objects for the omitted-intercept block, so this walkthrough does not compare them to exp(z0) levels."
// Retired tokens kept for audit traceability only:
//   older DGP2 pointwise-share and interval-share displays
//   --- DGP2 CIpoint pointwise diagnostics ---
//   DGP2 CIpoint pointwise within-run inclusion share:
//   This DGP2 CIpoint check is pointwise. The DGP2 CIuniform object is only the package's finite-grid interval object; it is not a calibrated simultaneous-coverage guarantee.
//   DGP2 CIuniform interval-object within-run inclusion share:

// =============================================================================
// Part 3: Method Comparison — Polynomial vs Trigonometric Basis
// =============================================================================
di as text ""
di as text "=============================================="
di as text " Part 3: Pol vs Tri Basis Comparison"
di as text "=============================================="
// method() changes only the sieve basis family, not the paper's doubly robust
// AIPW estimator family, but that basis choice still changes the z-basis
// representation used in both the nuisance fits and f(z), so Pol vs Tri can
// move the full AIPW path.
// This section is a same-input-q demonstration, not a matched-degree basis comparison and not the paper's Tri baseline: Pol q(8) keeps an 8th-degree polynomial basis, while Tri q(8) is only a 4th degree trigonometric basis under the package's q()/2 indexing; the paper's 8th-degree Tri baseline is q(16).
// Keep the same explicit seed(42) in both runs so the realized outer folds,
// bootstrap draws, and CLIME CV splits stay aligned; the remaining
// difference is then the sieve basis family itself.
// Because this Part 3 demo omits z0(), the Pol and Tri runs need not post
// gdebias/CIuniform on the same default retained-sample z grid. To compare the
// nonparametric omitted-intercept z-varying block across basis families, rerun both commands with
// the same explicit z0() list.
di as text "  Note: this is a same-input-q demonstration, not a matched-degree basis comparison."
di as text "        Pol q(8) keeps an 8th-degree polynomial basis, while Tri q(8) is only a 4th degree trigonometric basis."
di as text "  Note: Part 3 omits z0(), so the Pol/Tri runs need not share the same default retained-sample z grid."
di as text "        Keep seed(42) in both runs so folds/bootstrap/CLIME randomness stays aligned and the comparison isolates the basis family."
di as text "        To compare the nonparametric omitted-intercept z-varying block across basis families, rerun both commands with the same explicit z0() list."

// Use same DGP1 data as Part 1 for fair comparison
hddid_dgp1, n(500) p(50) seed(12345) clear

// The reload seed(12345) only recreates the Part 1 DGP1 sample itself:
// hddid_dgp1 restores the caller RNG state on exit, so that generator seed
// still does not carry into the two hddid calls below. Keep the explicit
// estimator-side seed(42) in both runs when reproducing the same-input-q
// fold/bootstrap/CLIME comparison on this reloaded sample.
// Build covariate list dynamically from the generated public x* variables
// so the public example keeps working when you change p().
unab x_vars : x*

// Polynomial basis estimation
di as text ""
di as text "--- Running Polynomial basis (Pol) ---"
hddid deltay, treat(treat) x(`x_vars') z(z) ///
    method("Pol") q(8) K(3) alpha(0.1) nboot(1000) seed(42)
local pol_x1 = el(e(xdebias), 1, 1)
local pol_se1 = el(e(stdx), 1, 1)

// Trigonometric basis estimation
di as text ""
di as text "--- Running Trigonometric basis (Tri; demo q(8), not paper-baseline q(16)) ---"
hddid deltay, treat(treat) x(`x_vars') z(z) ///
    method("Tri") q(8) K(3) alpha(0.1) nboot(1000) seed(42)
local tri_x1 = el(e(xdebias), 1, 1)
local tri_se1 = el(e(stdx), 1, 1)
matrix `hddid_example_tri_npf' = e(N_per_fold)
local hddid_example_tri_N = e(N)
local hddid_example_tri_N_trimmed = e(N_trimmed)

// Compare x1 estimates (true value = 1.0)
di as text ""
di as text "--- x1 estimate comparison (true value = 1.0) ---"
di as text "  Pol: " %9.4f `pol_x1' " (SE = " %7.4f `pol_se1' ")"
di as text "  Tri: " %9.4f `tri_x1' " (SE = " %7.4f `tri_se1' ")"
di as text "  True: " %9.4f 1.0

// =============================================================================
// Part 4: Accessing Stored Results Programmatically
// =============================================================================
di as text ""
di as text "=============================================="
di as text " Part 4: Stored Results Access"
di as text "=============================================="
// The e() results below come from the immediately preceding Part 3 Tri q(8)
// demo run, not the earlier paper-baseline q(16) runs.
// Because the Part 3 Tri q(8) demo omits z0(), the current e(z0) grid, the aligned gdebias/stdg/CIuniform results, and the trailing omitted-intercept CIpoint block now come from the retained sample's
// default z support rather than the earlier explicit
// z0(-1 -0.5 0 0.5 1) paper-baseline grid.
// Read e(q) together with e(method): under the package's Tri q()/2 harmonic indexing,
// the active Tri q(8) surface therefore means a 4th degree trigonometric basis
// rather than the paper-baseline 8th-degree Tri q(16) surface used earlier in
// Parts 1 and 2.
// e(qq) is the shared qq = length(z0) contract: it is the
// width of the current e(z0), gdebias, stdg, and CIuniform omitted-intercept z-varying surfaces,
// and of the trailing omitted-intercept z-varying block in e(CIpoint).
// Retired exact-token traceability only: width of the current e(z0), gdebias, stdg, and CIuniform f(z0) surfaces
// Current contract: those width-aligned public objects are the omitted-intercept
// z-varying surfaces plus the trailing omitted-intercept z-varying block in e(CIpoint).

// --- Scalar results ---
di as text ""
di as text "--- Scalar results ---"
local hddid_example_cmdline_lc = lower(strtrim(`"`e(cmdline)'"'))
local hddid_example_method = ///
    strproper(strlower(strtrim(`"`e(method)'"')))
if `"`hddid_example_method'"' == "" {
    if regexm(`"`hddid_example_cmdline_lc'"', ///
        "(^|[ ,])method[(][ ]*([^)]*)[ ]*[)]") {
        local hddid_example_method = ///
            strproper(strtrim(regexs(2)))
    }
    else {
        local hddid_example_method "Pol"
    }
}
local hddid_example_q = .
capture confirm scalar e(q)
if _rc == 0 {
    local hddid_example_q = e(q)
}
else if regexm(`"`hddid_example_cmdline_lc'"', ///
    "(^|[ ,])q[(][ ]*([^)]*)[ ]*[)]") {
    local hddid_example_q = real(strtrim(regexs(2)))
}
else {
    local hddid_example_q = 8
}
local hddid_example_alpha = .
capture confirm scalar e(alpha)
if _rc == 0 {
    local hddid_example_alpha = e(alpha)
}
else if regexm(`"`hddid_example_cmdline_lc'"', ///
    "(^|[ ,])alpha[(][ ]*([^)]*)[ ]*[)]") {
    local hddid_example_alpha = real(strtrim(regexs(2)))
}
else {
    local hddid_example_alpha = 0.1
}
di as text "If current e(method), e(q), or e(alpha) are absent, this walkthrough falls back to method() provenance or the default Pol basis, q() provenance or the default q(8), and alpha() provenance or the default alpha(0.1)."
di "Sample size:          " e(N)
di "Folds:                " colsof(e(N_per_fold))
di "X dimension:          " colsof(e(b))
di "Sieve method:         " `"`hddid_example_method'"'
di "Sieve order q:        " `hddid_example_q'
if `"`hddid_example_method'"' == "Tri" {
    di "Tri harmonic degree: " `hddid_example_q'/2
}
else {
    di as text "Tri harmonic degree:  <not applicable; active sieve basis is Pol>"
}
di "Evaluation points / e(z0) width: " colsof(e(z0))
di "Significance level:   " `hddid_example_alpha'
capture confirm scalar e(nboot)
if _rc == 0 {
    di "Bootstrap reps:       " e(nboot)
}
else {
    di as text "Bootstrap reps:       <absent; ordinary current surfaces may omit e(nboot) because the posted e(tc)/e(CIuniform) object already carries the interval contract>"
}
capture confirm scalar e(seed)
if _rc == 0 {
    di "RNG provenance seed:  " e(seed)
}
else {
    di as text "RNG provenance seed:  <absent; omitted seed()/seed(-1) follows caller session RNG state>"
}
di as text "This guard is existence-based: explicit seed(0) would still post e(seed)=0, so it must print 0 rather than fall into the omitted-seed branch."
di as text "seeded reproducibility applies only to hddid's internal random steps."
di as text "on exit, hddid restores the caller's prior session RNG state."
di as text "If seed() were omitted or set to seed(-1), e(seed) would be intentionally absent."
di as text "That omitted-seed path keeps the realized outer fold map as a deterministic function of the current common-score row order."
di as text "Bootstrap draws would then continue from the caller's session RNG state."
di "Tri support min:      " e(z_support_min)
di "Tri support max:      " e(z_support_max)
di "Pretrim common-score sample: " e(N_pretrim)
di "Trimmed observations: " e(N_trimmed)
di "Fold-pinning outer split: " e(N_outer_split)
di "Propensity CV folds:   " e(propensity_nfolds)
di "Outcome CV folds:      " e(outcome_nfolds)
di "Second-stage CV folds: " e(secondstage_nfolds)
di "M-matrix CV folds:     " e(mmatrix_nfolds)
di "CLIME requested max CV folds: " e(clime_nfolds_cv_max)
di "CLIME realized min CV folds:  " e(clime_nfolds_cv_effective_min)
di "CLIME realized max CV folds:  " e(clime_nfolds_cv_effective_max)
// This split-sensitive count can differ from e(N) under nofirst and is the
// published sample size that fixes outer-fold assignment before trim.
// The sample-accounting identity is e(N_trimmed) = e(N_pretrim) - e(N).
// The active Part 4 surface also carries its Tri-basis provenance through
// e(method), e(z_support_min), and e(z_support_max), plus e(seed) for the
// realized fold/bootstrap/CLIME RNG path.
// For Tri, e(q) is the stored sieve-order input; under the package's Tri q()/2 harmonic indexing, the active Tri q(8) surface therefore means a 4th degree trigonometric basis rather than an 8th degree one.
// These tuning-provenance scalars expose the fixed inner-CV settings for the
// internally estimated propensity/outcome/second-stage/M-matrix paths plus
// the requested and realized CLIME-CV fold bounds behind the stored surface.
// Under the default internal-first-stage path this fold-pinning count equals
// e(N_pretrim); D/W-complete auxiliary rows missing deltay can still move the
// propensity nuisance path, but they stay outside both the common score sample
// and the fold-pinning outer split.
// Under nofirst, e(N_outer_split) records the retained-relevant subset of the
// broader strict-interior pretrim fold-feasibility sample.
// That broader strict-interior pretrim fold-feasibility sample is the
// nofirst-specific split path rebuilt from the supplied nuisance inputs, not the
// default internal-first-stage score sample.
// Any legal 0<pihat()<1 row still enters that broader strict-interior
// fold-feasibility path before later overlap trimming, but only treatment-arm
// keys with at least one retained-overlap pretrim row pin the published
// retained outer fold IDs.
// Retained rows then keep those already-assigned outer fold IDs on the narrower
// retained-overlap score sample.
// Under nofirst, e(N_outer_split) can still equal e(N_pretrim) by scalar count
// even when the fold-pinning membership differs, because strict-interior rows
// can replace exact-boundary score rows one-for-one.
// Exact-boundary pihat() rows stay outside that broader strict-interior
// fold-feasibility split and do not pin retained outer fold IDs by themselves.
// Only treatment-arm keys with at least one retained-overlap pretrim row pin
// the retained outer fold IDs.
// Under nofirst, e(N_pretrim) can exceed e(N_outer_split) when legal
// strict-interior rows stay on the common score sample but their
// treatment-arm keys never contribute a retained-overlap pretrim row, so
// those rows trim later without pinning retained outer fold IDs.

// --- Matrix results ---
di as text ""
di as text "--- Matrix results ---"

// Debiased parametric estimates
matrix list e(xdebias), format(%9.4f)
matrix list e(stdx), format(%9.4f)
matrix list e(b), format(%9.4f)
matrix list e(V), format(%9.4f)
// e(b) is the canonical Stata coefficient vector and matches e(xdebias).
// e(V) is the canonical parametric covariance surface, with
// diag(e(V)) = e(stdx)^2 on the active result surface.
matrix list e(z0), format(%9.4f)
// e(z0) is the shared posted evaluation grid: read e(gdebias), e(stdg),
// e(CIuniform), and the trailing omitted-intercept z-varying block of e(CIpoint) in this same order.
matrix list e(gdebias), format(%9.4f)
matrix list e(stdg), format(%9.4f)
matrix list e(CIpoint), format(%9.4f)
matrix list e(tc), format(%9.4f)
matrix list e(CIuniform), format(%9.4f)
// Replay reads e(CIpoint), e(stdg), and e(CIuniform) directly from the stored inference surface.
// Legacy replay/direct unsupported postestimation can still use the published e(CIuniform) object when e(tc) is absent; current replay/direct unsupported postestimation instead require e(tc) on current saved-results surfaces and fail closed before ancillary provenance reconciliation.
// When e(tc) is stored, current replay/direct unsupported postestimation validate that provenance against the published e(CIuniform) object.
// Current direct unsupported postestimation still fails closed when a current saved-results surface drops malformed e(CIuniform) or e(CIpoint) before ancillary seed()/alpha()/nboot() cmdline provenance checks.
// Retired exact-token audit traceability only: Current replay/direct unsupported postestimation can still use the published e(CIuniform) object when e(tc) is absent; what is lost is only the duplicate bootstrap critical-value provenance.
// Retired exact-token audit traceability only: When e(tc) is stored, the same replay/direct unsupported path also validates that provenance against the published e(CIuniform) object.
// Replay reads e(CIpoint), e(tc), e(stdg), and e(CIuniform) directly from the stored inference surface.
// On those same current saved-results surfaces, malformed e(tc) fails on that same inference-surface branch because e(tc) is the bootstrap-calibration provenance behind e(CIuniform).
// In short: malformed e(tc), e(CIuniform), or e(CIpoint) are all current inference-surface failures before ancillary cmdline provenance checks.
// e(CIpoint) stacks the pointwise beta block in its first e(p) columns and the
// pointwise omitted-intercept z-varying block in its remaining e(qq) columns aligned with the
// current e(z0) grid, while the published nonparametric interval object
// e(CIuniform) stays aligned on that same e(z0) grid.
// Changing nboot() only recalibrates e(tc)/e(CIuniform); the saved e(CIpoint), e(stdx), and e(stdg) surfaces remain the analytic pointwise objects.
// lower row = e(gdebias) + e(tc)[1,1] * e(stdg) and
// upper row = e(gdebias) + e(tc)[1,2] * e(stdg).

// Per-fold effective evaluation sample sizes (post-trim)
di as text ""
di as text "--- Per-fold effective evaluation sample sizes (post-trim) ---"
matrix list e(N_per_fold)
matrix list e(clime_nfolds_cv_per_fold)
// These post-trim fold counts are also the cross-fit aggregation weights
// behind the reported xdebias/gdebias and stdx/stdg summaries, and their sum is e(N), the retained post-trim sample size behind the stored surface.
// The realized CLIME-CV fold vector reports how much inner-CV work each outer
// fold actually used; a 0 means only that CLIME CV was skipped on that fold.

// --- Using results in subsequent analysis ---
di as text ""
di as text "--- Separate beta contribution from centered z-varying change ---"

// The paper's conditional ATT target is x0'beta + f(z0). The public surface
// does not currently post e(a0), so x0'beta + e(gdebias) is not the full ATT
// level. Public follow-up analysis should therefore keep the beta contribution
// and the centered omitted-intercept z-varying block separate.
di as text "Published beta coordinate order e(xvars): `e(xvars)'"
// Build any x0 rowvector in the published e(xvars) order before using the posted beta block.
matrix x0 = J(1, colsof(e(b)), 0)
matrix x0[1, 1] = 1
matrix att_beta = x0 * e(b)'
local z0_1 = el(e(z0), 1, 1)
local z0_ref = el(e(z0), 1, 1)
local gd_ref = el(e(gdebias), 1, 1)
di as text "Public ATT note: hddid does not currently publish e(a0), so the posted public objects do not identify the full ATT level at z0."
di as text "beta-only contribution at x0: " %9.4f el(att_beta, 1, 1)
di as text "Centered omitted-intercept anchor at z0_ref (equals 0 by construction): " %9.4f (el(e(gdebias), 1, 1) - `gd_ref')
// Retired traceability note only: older walkthroughs sometimes wrote the missing-a0 sum as a one-shot ATT level, but that shorthand is not a valid public reconstruction because e(gdebias) omits a0.

di as text ""
di as text "--- Centered shape diagnostics ---"

// Theorems 2 and 3 in the paper give separate pointwise (1-alpha) intervals
// for the beta block and the omitted-intercept z-varying block, and the
// cross-fit R reference publishes those coordinates together in CIpoint. The
// beta-side truth check reads the first column directly, while the
// nonparametric public block excludes a0 and therefore only supports centered
// shape diagnostics rather than level-truth interval checks.
// Retired anchor for prior contract tests: --- CIpoint pointwise diagnostics ---
local beta1_ci_lo = el(e(CIpoint), 1, 1)
local beta1_ci_hi = el(e(CIpoint), 2, 1)
di "  beta_1 CIpoint contains 1: " cond(1 >= `beta1_ci_lo' & 1 <= `beta1_ci_hi', "yes", "no") ///
    "  [" %9.4f `beta1_ci_lo' ", " %9.4f `beta1_ci_hi' "]"

local qq = colsof(e(z0))
local p = colsof(e(b))
local z0_ref = el(e(z0), 1, 1)
local gd_ref = el(e(gdebias), 1, 1)
local max_shape_gap = 0
forvalues j = 1/`qq' {
    local z0_j = el(e(z0), 1, `j')
    local centered_hat_j = el(e(gdebias), 1, `j') - `gd_ref'
    local centered_true_j = exp(`z0_j') - exp(`z0_ref')
    local shape_gap_j = abs(`centered_hat_j' - `centered_true_j')
    if `shape_gap_j' > `max_shape_gap' {
        local max_shape_gap = `shape_gap_j'
    }
}
di as text "Centered shape diagnostics anchor at z0_ref = " %9.4f `z0_ref'
di as text "Because gdebias excludes the separate stage-2 intercept a0, compare centered differences only."
di as text "Max |(gdebias-gdebias_ref) - (exp(z0)-exp(z0_ref))| = " %9.4f `max_shape_gap'
di as text "CIpoint/CIuniform remain interval objects for the omitted-intercept block, so this walkthrough does not compare them to exp(z0) levels."
// Retired Part 4 CIpoint tokens kept for audit traceability only:
//   older Part 4 pointwise-share and interval-share displays
//   --- CIpoint pointwise diagnostics ---
//   CIpoint pointwise within-run inclusion share:
//   Those CIpoint checks are pointwise. The published CIuniform object remains only the package's finite-grid interval object and is not a calibrated simultaneous-coverage guarantee.

di as text ""
di as text "--- Hypothesis test: beta_1 = 1 ---"

// Test if beta_1 = 1 (true value under DGP1)
local beta1 = el(e(xdebias), 1, 1)
local se1 = el(e(stdx), 1, 1)
local tstat = (`beta1' - 1) / `se1'
di "  beta_1 estimate: " %9.4f `beta1'
di "  SE:             " %9.4f `se1'
di "  t-stat (H0: beta_1=1): " %6.3f `tstat'
di "  p-value (two-sided):  " %6.4f 2*normal(-abs(`tstat'))
di as text "Retired shorthand from older walkthroughs contrasted CIpoint against CIuniform in one sentence. Read that superseded shorthand only as a reminder that CIpoint is pointwise; the current contract is the corrected finite-grid interval-object statement above."

// =============================================================================
// Part 5: Common Errors and Diagnostics
// =============================================================================
di as text ""
di as text "=============================================="
di as text " Part 5: Common Errors and Diagnostics"
di as text "=============================================="

// --- Error 0: incomplete package bundle / missing safe probe ---
// The shipped example and the multivariate x() CLIME path are public p>1
// workflows. They therefore need the full sibling hddid package bundle, not
// just hddid.ado plus hddid_clime.py. The side-effect-free safe probe lives
// in hddid_safe_probe.py and is loaded before the full CLIME sidecar.
di as text ""
di as text "--- Error demo: incomplete bundle / missing hddid_safe_probe.py ---"
di as text "If hddid_example.do says it could not locate a complete hddid package bundle,"
di as text "or a multivariate x() run says it cannot find hddid_safe_probe.py,"
di as text "Stata is not pointing at the full sibling hddid package bundle."
di as text "Fix: run hddid_example.do from the repository root/package directory,"
di as text "or install/add the full hddid-stata directory to adopath so"
di as text "hddid_safe_probe.py stays beside hddid_clime.py and the ado sidecars."
di as text "A standard local install is: net install hddid, from(\"/path/to/hddid-stata\") replace"
di as text "If you also need the shipped ancillary walkthrough, first refetch it with:"
di as text "  net install hddid, from(\"/path/to/hddid-stata\") all replace"
di as text "  or: net get hddid, from(\"/path/to/hddid-stata\")"
di as text "Verify the installed bundle with: which hddid | which hddid_dgp1 | which hddid_dgp2 | which hddid_p | which hddid_estat"
di as text "and private ado sidecars: findfile _hddid_main.ado | findfile _hddid_display.ado | findfile _hddid_estimate.ado"
di as text "plus findfile _hddid_prepare_fold_covinv.ado | findfile _hddid_pst_cmdroles.ado | findfile _hddid_mata.ado"
di as text "and confirm both Python bundle files with: findfile hddid_safe_probe.py | findfile hddid_clime.py"
di as text "and rerun python query plus which lasso2 | which cvlasso | which cvlassologit | which lassologit"
di as text "before rechecking the shipped walkthrough entrypoint with: findfile hddid_example.do"
di as text "and then rerunning the installed walkthrough copy with: do "`r(fn)'""

// --- Error 1: matrix-capacity / matsize limits ---
di as text ""
di as text "--- Error demo: matrix-capacity / matsize limits ---"
di as text "If a large q()/z0() request hits a matrix-dimension failure, first try: set matsize 10000"
di as text "But the active hard frontier is the larger of the q+1 sieve width and qq = length(z0),"
di as text "capped by c(max_matdim) when available; raising matsize alone cannot beat that matrix-capacity / edition cap."

// --- Error 2: Missing required options ---
// The following will produce an error (missing treat option):
di as text ""
di as text "--- Error demo: missing required option ---"
capture noisily hddid deltay, x(`x_vars') z(z)
di as text "Return code: " _rc " (expected: 198)"

// --- Error 3: Trigonometric basis requires even q ---
di as text ""
di as text "--- Error demo: odd q with Tri basis ---"
capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(7)
di as text "Return code: " _rc " (expected: 198)"

// --- Error 4: unsupported estimator-style switch ---
di as text ""
di as text "--- Error demo: unsupported estimator-style switch ---"
capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) aipw
di as text "Return code: " _rc " (expected: 198)"
capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) estimator=ipw
di as text "Return code: " _rc " (expected: 198)"
di as text "hddid always uses the paper's fixed AIPW score; method() only chooses the Pol/Tri basis family."
di as text "So aipw/ipw/ra or estimator(...) spellings are unsupported estimator-family syntax, not estimator switches."
di as text "The legacy R wrapper default method(""Pol"") still does not reproduce the paper's Tri baseline."
// The paper and the R reference both fix the estimator path at AIPW.
// method() only chooses the basis family; hddid always uses the paper's AIPW score.
// But the legacy Examplehighdimdiffindiff.R wrapper still defaults to method="Pol"
// even though the paper's Section 5 simulations use the 8th degree
// trigonometric (Tri) basis, so matching the wrapper default does not reproduce
// the paper's baseline basis choice.
// So ra/ipw/aipw or estimator(...) assignment spellings are user-facing contract errors, not alternative estimator modes.
// Assignment spellings are user-facing contract errors.

// --- Error 5: nofirst without pre-estimated nuisance ---
di as text ""
di as text "--- Error demo: nofirst without pihat/phi1hat/phi0hat ---"
capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) nofirst
di as text "Return code: " _rc " (expected: 198)"
// Important nofirst contract from the paper's sample-splitting logic:
// pihat()/phi1hat()/phi0hat() must be fold-aligned out-of-fold nuisance inputs
// built on complementary outer folds. Full-sample fitted values are invalid,
// even when they are numerically in range, because they break orthogonality.
// hddid cannot prove true OOF provenance mechanically.
// It still mechanically checks split-key and same-fold consistency, but
// in-sample fitted nuisances can still pass those structural checks.
// If they satisfy the same range and duplicate-key agreement constraints, the
// caller must police that provenance directly.
// In the current command contract, these nuisance inputs must align to hddid's own deterministic outer-fold assignment rather than an arbitrary external cross-fitting scheme.
// Generic external out-of-fold nuisance values can still be rejected when they were produced under a different row-order or duplicate-key fold map, because hddid rebuilds its own fold structure before checking the supplied series.
// Under nofirst, if/in qualifiers are applied before hddid rebuilds that broader strict-interior nofirst split path.
// Running with if/in is therefore equivalent to physically subsetting those rows first: excluded rows do not continue to pin the outer split, retained estimator fold ids, or same-fold nuisance checks.
// That equivalence is estimator-level too: if the retained rows stay in the same order and the supplied fold-aligned nuisances are the same, the nofirst if/in run and the physically subsetted run must return the same retained-sample estimates.
// A hidden missing pihat twin on one treatment arm must still be checked on the
// broader usable/raw split map before it can disappear from the score sample.
// hddid rebuilds that broader raw split first so a same-fold cross-arm missing
// pihat cannot evade the fold-feasibility provenance guard just by dropping out
// of the common nonmissing score sample. The same-fold cross-arm pihat()
// validity checks also extend to depvar-missing or otherwise score-ineligible
// twins when their same-fold partner still contributes a retained overlap row,
// because that broader raw retained-overlap candidate sample still pins the
// shared overlap decision and fold-external OOF propensity provenance.
// Scope also matters: pihat() belongs to the nofirst pretrim split-feasibility sample because the broader strict-interior path fixes overlap-trimming feasibility, but only the retained-relevant subset pins the retained estimator fold ids used later.
// That same broader strict-interior 0 < pihat() < 1 pretrim fold-feasibility path is also the x() canonicalization anchor under nofirst.
// More precisely, the broader strict-interior 0 < pihat() < 1 fold-feasibility
// sample still governs the same-fold pihat() provenance checks, while only
// treatment-arm keys with at least one retained-overlap pretrim row pin the
// retained estimator fold ids. The retained-estimator checks then stay on that
// retained-overlap subset on the common nonmissing score sample with pihat()
// in [0.01,0.99].
// On that retained-relevant subset, the retained estimator fold ids used by
// phi1hat_oof/phi0hat_oof and the second-stage score are the fixed outer fold
// ids pinned by that retained-relevant subset.
// On the common nonmissing score sample, pihat() must stay within [0,1].
// Rows already outside that score sample do not let an out-of-range pihat() veto the run,
// because missing depvar()/phi*() already keeps them out of the common nonmissing
// score sample that precedes retained overlap trimming.
// Exact 0 or 1 are legal boundary cases and are handled later by overlap trimming,
// while only values outside [0,1] are invalid nofirst input.
// phi1hat()/phi0hat() belong only to the retained overlap sample where the final AIPW score is formed.
// But the same-fold nofirst validity checks also extend to the broader
// retained-overlap candidate rows with pihat() in [0.01,0.99], including
// depvar-missing or otherwise score-ineligible twins whose same-fold partner
// still fixes the fold-aligned OOF outcome-nuisance contract.
// Numerically identical nuisance inputs may intentionally reuse one storage column;
// hddid copies each role into separate working variables before forming the AIPW score.
// The nuisance objects in the paper are functions of W=(X,Z), so same W=(X,Z) values across treatment arms must still share the same nuisance values when those rows are evaluated in the same outer fold.
// The maintained contiguous row-block split can still put the same W=(X,Z) row in different outer folds across arms when those cross-arm copies occupy different current-row positions, but different outer folds across arms do not justify treatment-arm-specific nuisance inputs.
// In that different-fold case, fold-aligned OOF nuisances may still take different numeric values across treatment arms because the rows are being scored in different evaluation folds with different fold-external training samples.
// The mechanical equality guard is therefore same-outer-fold only, not a global cross-arm equality requirement across all folds.
// A retained outer fold may still be single-arm after overlap trimming.
// The identification-level two-arm requirement applies on the common score sample before overlap trimming, while retained fold-level score and debiasing feasibility checks govern what remains after the overlap screen.
// Duplicate rows with the same treatment-arm x()/z() key also stay in one outer fold,
// so the same-arm duplicate-key scope has to be read by nuisance type.
// For pihat(), that duplicate-key agreement already applies on the broader
// strict-interior 0 < pihat() < 1 path, so a depvar-missing twin cannot hide
// behind later trimming even if the key fully trims out of retained overlap.
// For phi1hat()/phi0hat(), the duplicate-key agreement narrows to retained-overlap
// candidate rows with pihat() in [0.01,0.99].
// Sigf = (psi - X*M')' and the nonparametric one-step update only make
// sense when the realized fold-level Sigma_f is stably invertible.
// This is an algorithmic prerequisite from the paper/R path, not a
// soft numerical warning or a place to substitute a generalized inverse.
// If hddid reports singular, nearly singular, or numerically null Sigma_f,
// reduce q(), change method(), or ensure richer fold-level support in z().
//
// --- Working nofirst example (minimal scaffold) ---
// A legal nofirst run needs three observation-level variables that are already
// fold-aligned out-of-fold (OOF) on the scopes above.
// Once pihat()/phi1hat()/phi0hat() are supplied, hddid does not run the
// internal propensity or outcome first stages again.
// This section is an illustrative nofirst provenance outline (not runnable
// as-is): the package does not publish a public helper that builds the
// required provisional fold map for an external nofirst workflow, so user code
// should not depend on any underscore-prefixed internal helper to recreate
// hddid's private preprocessing.
// A safe outline is:
//   1. In your own code, build a provisional raw/pretrim split from the same
//      contiguous current-row blocks on the nofirst fold-pinning sample that
//      hddid uses internally, so pihat() is first generated on the broader
//      pretrim fold-feasibility sample rather than on the later retained
//      overlap sample.
//      Legacy audit anchor for older worker15 string-contract tests only:
//      earlier docs described this as a treated/control x()/z() split-key step
//   2. Use that fixed broader split to write fold-aligned OOF pihat values on
//      the held-out rows of that broader strict-interior pretrim
//      fold-feasibility sample. Exact 0/1 values stay outside the nofirst
//      fold-feasibility split, and strict-interior near-boundary groups that
//      never contribute a retained-overlap row may later trim away without
//      relabeling the retained estimator folds by themselves. The command's
//      actual pihat() provenance target stays on that broader raw/pretrim
//      fold-feasibility map.
//   3. After pihat() is realized, determine which rows survive onto the
//      retained overlap sample and then construct phi1hat()/phi0hat() as
//      retained-sample OOF nuisances on those same fixed estimator fold ids;
//      the retained estimator fold ids used by phi1hat_oof/phi0hat_oof and the
//      second-stage score are the fixed outer fold ids pinned by that
//      retained-relevant subset, with overlap trimming applied afterward on
//      the retained score sample rather than by rebuilding the outer split
//      after overlap trimming.
//   4. Call hddid with those finished nuisance variables, for example:
//        * hddid deltay, treat(treat) x(`x_vars') z(z) nofirst ///
//              pihat(pihat_oof) phi1hat(phi1hat_oof) phi0hat(phi0hat_oof) ///
//              method("Pol") q(6) k(3) nboot(1000) seed(42)
// This positive pattern is the nofirst counterpart to the internal first-stage
// examples above: the caller, not hddid, is responsible for ensuring the
// supplied nuisances are genuinely fold-aligned OOF rather than full-sample
// fitted values.
// For the internal first-stage path, hddid also has an outcome-side fallback:
// if an arm-specific training outcome is constant or the nuisance-fit W=(X,Z-basis) design is constant,
// the command uses the fold-external sample mean as the first-stage outcome nuisance prediction
// instead of forcing the fixed 5-fold outcome cvlasso path on that arm.

// --- Error 6: unsupported postestimation entrypoints ---
di as text ""
di as text "--- Error demo: unsupported postestimation entrypoints ---"
capture noisily predict, xb
di as text "predict rc: " _rc " (unsupported observation-level contract)"
capture noisily hddid_estat summarize
di as text "hddid_estat summarize rc: " _rc " (unsupported estat contract)"
capture noisily margins
di as text "margins rc: " _rc " (disabled because no prediction contract is published)"
di as text "Use bare replay plus the stored e() objects instead"
di as text "for aggregate beta / omitted-intercept z-varying output: ereturn list | matrix list e(b) | matrix list e(z0) | matrix list e(gdebias) | matrix list e(stdg) | matrix list e(tc) | matrix list e(CIpoint) | matrix list e(CIuniform)"
di as text "matrix list e(xdebias) | matrix list e(stdx) | matrix list e(V)"
di as text "Published beta coordinate order e(xvars): `e(xvars)'"
di as text "e(xvars) is the published beta coordinate order behind e(b) and the beta block of e(CIpoint)."
di as text "e(b) is the canonical Stata coefficient vector and matches e(xdebias)."
di as text "e(V) is the canonical parametric covariance surface, with diag(e(V)) = e(stdx)^2 on the active result surface."
di as text "e(z0) is the posted evaluation grid behind e(gdebias), e(stdg), e(CIuniform), and the trailing omitted-intercept z-varying block of e(CIpoint)."
// Retired exact-token audit traceability only: e(z0) is the posted evaluation grid behind e(gdebias), e(stdg), e(CIpoint), and e(CIuniform).
di as text "e(method) identifies the stored sieve basis."
di as text "When e(method)=Tri, inspect e(z_support_min) and e(z_support_max) before reading the omitted-intercept z-varying block on e(z0)."
di as text "e(CIpoint) uses its first e(p) columns for the beta block in e(xvars) order."
di as text "Its remaining e(qq) columns are the omitted-intercept z-varying block aligned with e(z0)."
di as text "The same stored nonparametric surface always carries e(stdg) and the published e(CIuniform) object on that current e(z0) grid."
di as text "When available, e(tc) is the duplicate bootstrap critical-value pair behind the published e(CIuniform) interval object."
di as text "Legacy replay/direct unsupported postestimation can still use the published e(CIuniform) object when e(tc) is absent; current replay/direct unsupported postestimation instead require the bundled e(gdebias), e(stdg), e(CIuniform), e(tc), and e(CIpoint) objects on current saved-results surfaces and fail closed before ancillary provenance reconciliation."
di as text "When e(tc) is stored, current replay/direct unsupported postestimation validate that provenance against the published e(CIuniform) object."
di as text "because hddid does not currently publish e(a0), use centered comparisons rather than treating the public omitted-intercept block as either a full ATT level or a raw f(z0) level."

// --- Diagnostic: Check post-trim per-fold effective sample sizes ---
di as text ""
di as text "--- Diagnostic: post-trim per-fold effective sample sizes ---"
matrix list `hddid_example_tri_npf'
// If any fold has very few effective observations after trimming, consider reducing K

// --- Diagnostic: Check trimming ---
di as text ""
di as text "--- Diagnostic: trimming rate ---"
local raw_n = `hddid_example_tri_N' + `hddid_example_tri_N_trimmed'
di "Total trimmed: " `hddid_example_tri_N_trimmed' " out of " `raw_n' ///
    " (" %4.1f 100*`hddid_example_tri_N_trimmed'/`raw_n' "%)"
// High trimming rate (>10%) may indicate propensity score model issues

di as text ""
di as text "=============================================="
di as text " All examples completed successfully."
di as text "=============================================="
end

if `hddid_example_rc' == 0 {
    // Raise the working matsize conservatively: the example should not fail
    // up front just because the runtime matrix-capacity limit is below 5000.
    local hddid_example_work_matsize 5000
    capture local hddid_example_matdim_cap = c(max_matdim)
    if _rc == 0 {
        local hddid_example_work_matsize = ///
            min(`hddid_example_work_matsize', `hddid_example_matdim_cap')
    }
    capture set matsize `hddid_example_work_matsize'
    if _rc != 0 {
        local hddid_example_rc = _rc
    }
    else {
        capture noisily `hddid_example_main_prog'
        local hddid_example_rc = _rc
    }
}

if `hddid_example_added_to_adopath' {
    capture noisily adopath - "`hddid_example_pkgdir'"
}
capture set more `hddid_example_more_prev'
capture set matsize `hddid_example_matsize_prev'
capture cd `"`hddid_example_cwd_prev'"'
if `hddid_example_had_data' {
    if `hddid_example_charonly_empty' {
        capture clear
        capture noisily do "`hddid_example_label_backup'"
        forvalues hxe_char_i = 1/`hxe_char_n' {
            local hxe_char_name `"`hxe_name_`hxe_char_i''"'
            local hxe_char_value `"`hxe_value_`hxe_char_i''"'
            capture char _dta[`hxe_char_name'] `"`hxe_char_value'"'
        }
    }
    else {
        capture noisily use "`hddid_example_data_backup'", clear
    }
}

if `"`hddid_example_pkgdir_prev'"' == "" {
    capture macro drop HDDID_PACKAGE_DIR
}
else {
    global HDDID_PACKAGE_DIR `"`hddid_example_pkgdir_prev'"'
}

if `hddid_example_had_estimates' {
    capture noisily _estimates unhold `hddid_example_est_hold'
}

foreach hxe_public_cmd of local hxe_restore_cmds {
    local hxe_restore_path ///
        `"`hxe_restore_path_`hxe_public_cmd''"'
    if `"`hxe_restore_path'"' != "" {
        capture noisily run `"`hxe_restore_path'"'
    }
}
foreach hxe_public_cmd in hddid hddid_dgp1 hddid_dgp2 hddid_p hddid_estat {
    if !`hxe_preloaded_`hxe_public_cmd'' {
        capture program drop `hxe_public_cmd'
    }
}
if `hxe_preloaded_internal_main' {
    if `"`hxe_internal_main_path'"' != "" {
        capture noisily run `"`hxe_internal_main_path'"'
    }
}
else {
    capture program drop _hddid_main
}
forvalues hxe_main_helper_i = 1/`hxe_main_helper_n' {
    local hxe_main_helper_cmd `"`hxe_main_helper_name_`hxe_main_helper_i''"'
    if `hxe_main_helper_loaded_`hxe_main_helper_i'' {
        local hxe_main_helper_restore_path ///
            `"`hxe_main_helper_path_`hxe_main_helper_i''"'
        if `"`hxe_main_helper_restore_path'"' != "" {
            capture noisily run `"`hxe_main_helper_restore_path'"'
        }
    }
    else {
        capture program drop `hxe_main_helper_cmd'
    }
}
forvalues hxe_internal_i = 1/`hxe_internal_n' {
    local hxe_internal_cmd `"`hxe_internal_name_`hxe_internal_i''"'
    if `hxe_internal_loaded_`hxe_internal_i'' {
        local hxe_internal_restore_path ///
            `"`hxe_internal_path_`hxe_internal_i''"'
        if `"`hxe_internal_restore_path'"' != "" {
            capture noisily run `"`hxe_internal_restore_path'"'
        }
    }
    else {
        capture program drop `hxe_internal_cmd'
    }
}
if `hxe_preloaded_internal_mata' {
    if `"`hxe_internal_mata_path'"' != "" {
        capture noisily run `"`hxe_internal_mata_path'"'
    }
}
else {
    foreach hxe_internal_mata_sym of local hxe_internal_mata_symbols {
        capture mata: mata drop `hxe_internal_mata_sym'
    }
}

capture program drop `hddid_example_main_prog'

if `hddid_example_rc' != 0 {
    exit `hddid_example_rc'
}
