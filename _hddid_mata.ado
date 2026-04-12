*! version 1.0.0
*! _hddid_mata: Mata numerics for hddid

version 16

// Defensive reload: drop prior symbols so the file can be re-run in-session.
// Mata does not allow redefining structs/functions in place.
capture mata: mata drop _hddid_debias_beta()
capture mata: mata drop _hddid_debias_gamma()
capture mata: mata drop _hddid_matrix_byrow()
capture mata: mata drop _hddid_quantile_type7_sorted()
capture mata: mata drop _hddid_bootstrap_tc()
capture mata: mata drop _hddid_aggregate_folds()
capture mata: mata drop _hddid_sieve_pol()
capture mata: mata drop _hddid_sieve_tri()
capture mata: mata drop _hddid_tri_rescale()
capture mata: mata drop _hddid_sieve_tri_support()
capture mata: mata drop _hddid_canonical_x_standardize()
capture mata: mata drop _hddid_canonical_x_order()
capture mata: mata drop _hddid_canonical_group_counts()
capture mata: mata drop _hddid_foldkey_canon()
capture mata: mata drop _hddid_foldkey_standardize()
capture mata: mata drop _hddid_matrix_lexcompare()
capture mata: mata drop _hddid_row_signorbit_canon()
capture mata: mata drop _hddid_colsignorbit_canon()
capture mata: mata drop _hddid_drop_duplicate_cols()
capture mata: mata drop _hddid_foldkey_rank_center()
capture mata: mata drop _hddid_resolve_fold_order()
capture mata: mata drop _hddid_stratified_fold_map_xz()
capture mata: mata drop _hddid_fold_map_xz_relaxed()
capture mata: mata drop _hddid_stratified_fold_map()
capture mata: mata drop _hddid_stratified_folds()
capture mata: mata drop _hddid_store_fold_map_byvars()
capture mata: mata drop _hddid_store_stratified_fold_map()
capture mata: mata drop _hddid_default_outer_fold_map_m()
capture mata: mata drop _hddid_store_fold_map_xz_relaxed()
capture mata: mata drop _hddid_trim_propensity()
capture mata: mata drop _hddid_dr_score()
capture mata: mata drop _hddid_compute_tildex()
capture mata: mata drop _hddid_absorbed_xvars()
capture mata: mata drop _hddid_single_x_precision()
capture mata: mata drop _hddid_beta_influence_entry()
capture mata: mata drop _hddid_stable_beta_row()
capture mata: mata drop _hddid_sieve_basis_diagnostics()
capture mata: mata drop _hddid_init_folds()
capture mata: mata drop _hddid_store_fold()
capture mata: mata drop _hddid_run_aggregate()
capture mata: mata drop _hddid_post_results()
capture mata: mata drop _hddid_fold_debias_store()
capture mata: mata drop _hddid_store_constant_fold()
capture mata: mata drop _hddid_store_sieve_basis()
capture mata: mata drop _hddid_store_z0_basis()
capture mata: mata drop _hddid_restrict_fold_z0_grid()
capture mata: mata drop _hddid_z0_colname()
capture mata: mata drop _hddid_store_z0_colstripe()
capture mata: mata drop _hddid_stage2_prepare()
capture mata: mata drop _hddid_aggregate_gammabar()
capture mata: mata drop _hddid_library_selftest()
capture mata: mata drop _hddid_assert_symmetric_psd()
capture mata: mata drop _hddid_assert_symmetric_finite()
capture mata: mata drop _hddid_assert_nanfb_stdg_carrier()
capture mata: mata drop _hddid_assert_vcovx_stdx()
// Structs
capture mata: mata drop _hddid_beta_result()
capture mata: mata drop _hddid_gamma_result()
capture mata: mata drop _hddid_fold_result()
capture mata: mata drop _hddid_result()

mata:

// Shared result containers used across folds and aggregation.

struct _hddid_beta_result {
    real rowvector xdebias
    real rowvector stdx
    real matrix    vcovx
}

struct _hddid_gamma_result {
    real rowvector gdebias
    real matrix    stdg
    real matrix    Vf
    real scalar    nan_fallback
    real colvector gammabar
}

struct _hddid_fold_result {
    real rowvector xdebias
    real rowvector stdx
    real matrix    vcovx
    real rowvector gdebias
    real matrix    stdg
    real matrix    Vf
    real scalar    n_valid
    real scalar    nan_fallback
    real rowvector tc
    real colvector gammabar
    real scalar    a0
}

struct _hddid_result {
    real rowvector xdebias
    real rowvector gdebias
    real rowvector stdx
    real matrix    V
    real rowvector stdg
    real rowvector tc
    real matrix    CIpoint
    real matrix    CIuniform
    real colvector gammabar
    real scalar    a0
}

real scalar _hddid_library_selftest(
    string scalar b_name, string scalar V_name,
    string scalar xdebias_name, string scalar gdebias_name,
    string scalar stdx_name, string scalar stdg_name,
    string scalar tc_name, string scalar CIpoint_name,
    string scalar CIuniform_name)
{
    struct _hddid_beta_result scalar beta_res
    struct _hddid_gamma_result scalar gamma_res
    struct _hddid_fold_result scalar fold_res
    struct _hddid_result scalar final_res
    real colvector zprobe
    real matrix basis_pol, basis_tri
    real scalar zcrit

    beta_res = _hddid_beta_result()
    gamma_res = _hddid_gamma_result()
    fold_res = _hddid_fold_result()
    final_res = _hddid_result()

    zprobe = (0 \ 0.5 \ 1)
    basis_pol = _hddid_sieve_pol(zprobe, 1)
    basis_tri = _hddid_sieve_tri(zprobe, 2)

    if (rows(basis_pol) != 3 | cols(basis_pol) != 2) {
        return(0)
    }
    if (rows(basis_tri) != 3 | cols(basis_tri) != 3) {
        return(0)
    }

    zcrit = invnormal(1 - 0.1 / 2)
    st_matrix("__hddid_final_xdebias", (0, 0))
    st_matrix("__hddid_final_gdebias", (0, 0, 0))
    st_matrix("__hddid_final_stdx", (1, sqrt(2)))
    st_matrix("__hddid_final_V", (1, 0.1 \ 0.1, 2))
    st_matrix("__hddid_final_stdg", (1, 1, 1))
    st_matrix("__hddid_final_tc", (-zcrit, zcrit))
    st_matrix("__hddid_final_CIpoint", ///
        (-zcrit, -zcrit * sqrt(2), -zcrit, -zcrit, -zcrit) \ ///
        ( zcrit,  zcrit * sqrt(2),  zcrit,  zcrit,  zcrit))
    st_matrix("__hddid_final_CIuniform", ///
        (-zcrit, -zcrit, -zcrit) \ ///
        ( zcrit,  zcrit,  zcrit))
    st_matrix("__hddid_final_alpha", (0.1))

    _hddid_post_results(
        b_name, V_name, xdebias_name, gdebias_name,
        stdx_name, stdg_name, tc_name, CIpoint_name, CIuniform_name, 3)

    if (rows(st_matrix(V_name)) != 2 | cols(st_matrix(V_name)) != 2) {
        return(0)
    }
    if (cols(st_matrix(b_name)) != 2) {
        return(0)
    }
    if (cols(st_matrix(xdebias_name)) != 2) {
        return(0)
    }
    if (cols(st_matrix(gdebias_name)) != 3) {
        return(0)
    }
    if (cols(st_matrix(stdg_name)) != 3) {
        return(0)
    }
    if (cols(st_matrix(CIpoint_name)) != 5) {
        return(0)
    }
    if (cols(st_matrix(CIuniform_name)) != 3) {
        return(0)
    }

    // Compile-time reference to the fold wrapper guards against partial sidecars.
    if (0) {
        _hddid_fold_debias_store(
            "", "", "", "", "", "", "", "", "", "",
            1, 1, 1, 1, 1, 0.1, 1, -1)
    }

    return(1)
}

void _hddid_assert_symmetric_psd(string scalar label, real matrix V)
{
    real scalar v_scale, v_tol, v_sym_gap
    real colvector v_eval

    if (rows(V) != cols(V)) {
        errprintf("%s must be square; got %g x %g\n", label, rows(V), cols(V))
        _error(3498)
    }
    if (rows(V) < 1) {
        errprintf("%s must be a nonempty square matrix; got %g x %g\n",
            label, rows(V), cols(V))
        _error(3498)
    }
    if (hasmissing(V)) {
        errprintf("%s must be finite; found missing/nonfinite values\n", label)
        _error(3498)
    }

    // Symmetry/PSD are properties of this covariance object itself. Use the
    // matrix's own scale so tiny but nonzero objects do not get a unit-scale
    // tolerance floor that can hide same-order asymmetry or negativity.
    v_scale = max(abs(V))
    if (v_scale <= 0 | v_scale >= .) {
        v_scale = 1
    }
    v_tol = 1e-10 * v_scale
    v_sym_gap = max(abs(V :- V'))
    if (v_sym_gap > v_tol) {
        errprintf("%s must be symmetric within tolerance %g; max |V-V'| = %g\n",
            label, v_tol, v_sym_gap)
        _error(3498)
    }

    v_eval = symeigenvalues(V)
    if (min(v_eval) < -v_tol) {
        errprintf("%s must be positive semidefinite within tolerance %g; min eigenvalue = %g\n",
            label, v_tol, min(v_eval))
        _error(3498)
    }
}

void _hddid_assert_symmetric_finite(string scalar label, real matrix V)
{
    real scalar v_scale, v_tol, v_sym_gap

    if (rows(V) != cols(V)) {
        errprintf("%s must be square; got %g x %g\n", label, rows(V), cols(V))
        _error(3498)
    }
    if (rows(V) < 1) {
        errprintf("%s must be a nonempty square matrix; got %g x %g\n",
            label, rows(V), cols(V))
        _error(3498)
    }
    if (hasmissing(V)) {
        errprintf("%s must be finite; found missing/nonfinite values\n", label)
        _error(3498)
    }

    v_scale = max(abs(V))
    if (v_scale <= 0 | v_scale >= .) {
        v_scale = 1
    }
    v_tol = 1e-10 * v_scale
    v_sym_gap = max(abs(V :- V'))
    if (v_sym_gap > v_tol) {
        errprintf("%s must be symmetric within tolerance %g; max |V-V'| = %g\n",
            label, v_tol, v_sym_gap)
        _error(3498)
    }
}

void _hddid_assert_nanfb_stdg_carrier(string scalar label, real matrix stdg)
{
    real scalar i, j, qq

    qq = rows(stdg)
    if (qq != cols(stdg)) {
        errprintf("%s must be square when nan_fallback=1; got %g x %g\n",
            label, rows(stdg), cols(stdg))
        _error(3498)
    }
    for (i = 1; i <= qq; i++) {
        for (j = 1; j <= qq; j++) {
            if (i != j & stdg[i, j] < .) {
                errprintf("%s must leave off-diagonal entries missing when nan_fallback=1; found finite value %g at (%g,%g)\n",
                    label, stdg[i, j], i, j)
                _error(3498)
            }
        }
    }
}

void _hddid_assert_vcovx_stdx(
    string scalar label, real matrix vcovx, real matrix stdx)
{
    real rowvector vcov_diag, stdx_sq
    real scalar j, gap, scale, tol

    vcov_diag = diagonal(vcovx)'
    stdx_sq = stdx:^2
    for (j = 1; j <= cols(stdx_sq); j++) {
        gap = abs(vcov_diag[j] - stdx_sq[j])
        // vcovx_jj and stdx_j^2 encode the same beta_j variance object. Check
        // each coordinate on its own scale so a large-variance beta cannot
        // mask a same-order mismatch in a tiny-variance beta.
        scale = max((abs(vcov_diag[j]), stdx_sq[j]))
        tol = 1e-12 * scale
        if (gap > tol) {
            errprintf("%s are inconsistent at beta coordinate %g; |diag(vcovx)[%g]-stdx[%g]^2| = %g exceeded tolerance=%g\n",
                label, j, j, j, gap, tol)
            _error(3498)
        }
    }
}

// Core numerical routines.

// _hddid_sieve_pol(z, q) returns an n x (q+1) polynomial basis with an
// intercept in column 1. q must be a finite non-negative integer.

real matrix _hddid_sieve_pol(real colvector z, real scalar q)
{
    real matrix basis
    real scalar j, n
    
    // q is validated defensively because Mata treats missing (.) as +infinity.
    if (q < 0 | q != trunc(q) | q >= .) {
        errprintf("_hddid_sieve_pol(): q must be a non-negative integer, got %g\n", q)
        _error(3498)
    }
    if (hasmissing(z)) {
        errprintf("_hddid_sieve_pol(): z must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    
    n = rows(z)
    basis = J(n, q + 1, .)
    basis[., 1] = J(n, 1, 1)
    for (j = 2; j <= q + 1; j++) {
        basis[., j] = basis[., j - 1] :* z
    }
    if (hasmissing(basis)) {
        errprintf("_hddid_sieve_pol(): generated sieve basis contains missing/nonfinite values\n")
        errprintf("_hddid_sieve_pol(): finite z with large q or |z| can overflow polynomial powers; rescale z or reduce q\n")
        _error(3498)
    }
    
    return(basis)
}

// _hddid_sieve_tri(z, q) returns an n x (q+1) trigonometric basis with an
// intercept in column 1: [1, cos(2*pi*z), sin(2*pi*z), ...]. q must be a
// finite positive even integer.

real matrix _hddid_sieve_tri(real colvector z, real scalar q)
{
    real matrix basis
    real scalar j, J, n, col
    
    // mod(., 2) is missing in Mata, so "!= 0" also rejects missing q.
    if (mod(q, 2) != 0 | q < 2) {
        errprintf("_hddid_sieve_tri(): q must be a positive even integer, got %g\n", q)
        _error(3498)
    }
    if (hasmissing(z)) {
        errprintf("_hddid_sieve_tri(): z must be finite; found missing/nonfinite values\n")
        _error(3351)
    }
    
    J = q / 2
    n = rows(z)
    basis = J(n, q + 1, .)
    basis[., 1] = J(n, 1, 1)
    
    col = 2
    for (j = 1; j <= J; j++) {
        basis[., col]     = cos(2 * j * pi() * z)
        basis[., col + 1] = sin(2 * j * pi() * z)
        col = col + 2
    }
    
    return(basis)
}

real colvector _hddid_tri_rescale(
    real colvector z, real scalar z_min, real scalar z_max)
{
    real scalar z_span
    real colvector z_centered, z_scaled

    if (missing(z_min) | missing(z_max) | z_max <= z_min) {
        errprintf("_hddid_tri_rescale(): invalid support [%g, %g]\n", z_min, z_max)
        _error(3498)
    }
    if (hasmissing(z)) {
        errprintf("_hddid_tri_rescale(): z must be finite; found missing/nonfinite values\n")
        _error(3351)
    }

    z_span = z_max - z_min
    if (missing(z_span) | z_span <= 0) {
        errprintf("_hddid_tri_rescale(): support width must remain finite and positive after subtraction; got z_max-z_min = %g\n",
            z_span)
        errprintf("_hddid_tri_rescale(): rescale z() before Tri support normalization\n")
        _error(3498)
    }

    z_centered = z :- z_min
    if (hasmissing(z_centered)) {
        errprintf("_hddid_tri_rescale(): centered z must remain finite; support normalization overflowed during z-z_min\n")
        errprintf("_hddid_tri_rescale(): rescale z() before Tri support normalization\n")
        _error(3498)
    }

    z_scaled = z_centered :/ z_span
    if (hasmissing(z_scaled)) {
        errprintf("_hddid_tri_rescale(): support-normalized z must remain finite; division by the retained support width overflowed\n")
        errprintf("_hddid_tri_rescale(): rescale z() before Tri support normalization\n")
        _error(3498)
    }

    return(z_scaled)
}

real matrix _hddid_sieve_tri_support(
    real colvector z, real scalar q,
    real scalar z_min, real scalar z_max)
{
    return(_hddid_sieve_tri(_hddid_tri_rescale(z, z_min, z_max), q))
}

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

// _hddid_stratified_fold_map(xz, treat, K, seed) returns an n x 2 matrix:
// column 1 is the fold id, and column 2 is a within-treatment key-group rank.
// The seed-dependent score pair drives the main ordering after columnwise
// centering/scaling. Those scores use only the magnitudes of the standardized
// coordinates so one-to-one sign recodings such as w -> -w do not perturb the
// split. The full xz row is appended as a deterministic tie-breaker so
// distinct rows do not collapse onto the same fold key. Exact duplicate keys
// stay in the same fold so row order inside a duplicate-key group cannot leak
// into the outer sample split.

real matrix _hddid_foldkey_canon(real matrix key_data)
{
    real scalar j
    real rowvector key_ord, block_ord
    real matrix key_sig, key_abs_sig, key_sort_sig, key_canon, key_sig_input
    real matrix block, block_sort_input
    real scalar block_end
    real colvector key_sig_j, key_sig_flip_j

    if ((rows(key_data) > 0 | cols(key_data) > 0) & hasmissing(key_data)) {
        errprintf("_hddid_foldkey_canon(): split-key columns must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (cols(key_data) <= 1) {
        return(_hddid_colsignorbit_canon(key_data))
    }

    // Canonicalize by each column's sorted standardized-value multiset, not by
    // the raw observation order. This keeps pure renaming/varlist reordering
    // from altering the split while also preventing unrelated row reordering
    // or pure positive affine recodings from changing the canonical column
    // order itself.
    key_sig_input = _hddid_foldkey_standardize(key_data)
    key_sig = J(rows(key_data), cols(key_data), .)
    key_abs_sig = J(rows(key_data), cols(key_data), .)
    for (j = 1; j <= cols(key_data); j++) {
        key_sig_j = sort(key_sig_input[., j], 1)
        key_sig_flip_j = -key_sig_j[rows(key_sig_j)..1]
        if (_hddid_matrix_lexcompare(key_sig_flip_j, key_sig_j) < 0) {
            key_sig_j = key_sig_flip_j
        }
        key_sig[., j] = key_sig_j
        key_abs_sig[., j] = abs(key_sig_j)
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
            // When multiple x() columns share the same canonical signature,
            // break ties on a coordinatewise sign-orbit representative so a
            // one-to-one sign recoding of one column cannot relabel folds.
            block_sort_input = _hddid_colsignorbit_canon(block)
            block_ord = order(block_sort_input', 1..rows(block_sort_input))'
            key_canon[., j..block_end] = block[., block_ord]
        }
        j = block_end + 1
    }

    // The split-key information set is unchanged by a pure columnwise sign
    // recoding, so fix a deterministic sign-orbit representative after the
    // canonical column order is chosen as well. This keeps w -> -w from
    // relabeling fold keys while preserving exact-duplicate detection because
    // sign flips are applied columnwise to the whole key matrix.
    key_canon = _hddid_colsignorbit_canon(key_canon)

    return(key_canon)
}

real matrix _hddid_foldkey_standardize(real matrix key_data)
{
    real scalar j, n, max_abs_j, rms_j
    real rowvector key_mean
    real colvector scaled_j
    real matrix centered, standardized

    n = rows(key_data)
    if (n == 0 | cols(key_data) == 0) {
        return(key_data)
    }
    if (hasmissing(key_data)) {
        errprintf("_hddid_foldkey_standardize(): split-key columns must be finite; found missing/nonfinite values\n")
        _error(3498)
    }

    key_mean = mean(key_data)
    if (hasmissing(key_mean)) {
        errprintf("_hddid_foldkey_standardize(): split-key column means must remain finite; centering overflowed or became nonfinite\n")
        errprintf("_hddid_foldkey_standardize(): rescale split-key columns before fold assignment\n")
        _error(3498)
    }
    centered = key_data :- key_mean
    if (hasmissing(centered)) {
        errprintf("_hddid_foldkey_standardize(): centered split-key coordinates must remain finite; centering overflowed or became nonfinite\n")
        errprintf("_hddid_foldkey_standardize(): rescale split-key columns before fold assignment\n")
        _error(3498)
    }
    standardized = centered

    for (j = 1; j <= cols(key_data); j++) {
        // Rescale before squaring so extreme but finite affine recodings do
        // not perturb the split through overflow in the RMS calculation.
        max_abs_j = max(abs(centered[., j]))
        if (max_abs_j > 0 & max_abs_j < .) {
            scaled_j = centered[., j] :/ max_abs_j
            rms_j = sqrt(mean(scaled_j :^ 2))
            if (rms_j > 0 & rms_j < .) {
                standardized[., j] = scaled_j :/ rms_j
            }
        }
    }
    if (hasmissing(standardized)) {
        errprintf("_hddid_foldkey_standardize(): standardized split-key coordinates must remain finite; scaling overflowed or became nonfinite\n")
        errprintf("_hddid_foldkey_standardize(): rescale split-key columns before fold assignment\n")
        _error(3498)
    }

    return(standardized)
}

real scalar _hddid_matrix_lexcompare(real matrix A, real matrix B)
{
    real scalar i, j

    if (rows(A) != rows(B) | cols(A) != cols(B)) {
        errprintf("_hddid_matrix_lexcompare(): matrix shape mismatch (%g x %g vs %g x %g)\n",
            rows(A), cols(A), rows(B), cols(B))
        _error(3498)
    }
    if (hasmissing(A) | hasmissing(B)) {
        errprintf("_hddid_matrix_lexcompare(): matrices must be finite; found missing/nonfinite entry\n")
        _error(3498)
    }

    for (i = 1; i <= rows(A); i++) {
        for (j = 1; j <= cols(A); j++) {
            if (A[i, j] < B[i, j]) {
                return(-1)
            }
            if (A[i, j] > B[i, j]) {
                return(1)
            }
        }
    }

    return(0)
}

real matrix _hddid_row_signorbit_canon(real matrix A)
{
    real scalar i
    real matrix out

    out = A
    for (i = 1; i <= rows(A); i++) {
        if (_hddid_matrix_lexcompare(-A[i, .], A[i, .]) < 0) {
            out[i, .] = -A[i, .]
        }
    }

    return(out)
}

real matrix _hddid_colsignorbit_canon(real matrix A)
{
    real scalar j
    real matrix out
    real colvector col_sorted, col_flip_sorted

    out = A
    for (j = 1; j <= cols(A); j++) {
        // Compare sorted column multisets, not the current row order. This
        // keeps a pure row reordering from flipping the chosen sign orbit for
        // an otherwise identical column.
        col_sorted = sort(A[., j], 1)
        col_flip_sorted = sort(-A[., j], 1)
        if (_hddid_matrix_lexcompare(col_flip_sorted, col_sorted) < 0) {
            out[., j] = -A[., j]
        }
    }

    // Some centered-rank columns have perfectly sign-symmetric multisets, so
    // the columnwise comparison above ties under A versus -A and would leave a
    // pure global sign flip unresolved. Canonicalize each row against its own
    // sign orbit as a row-order-invariant second pass so pure sign recodings
    // cannot relabel the fold-map tie-breaker matrix.
    out = _hddid_row_signorbit_canon(out)

    return(out)
}

real matrix _hddid_drop_duplicate_cols(real matrix A)
{
    real scalar j, k, keep_j
    real rowvector keep_idx

    if (cols(A) <= 1) {
        return(A)
    }

    keep_idx = J(1, 0, .)
    for (j = 1; j <= cols(A); j++) {
        keep_j = 1
        for (k = 1; k <= cols(keep_idx); k++) {
            if (all(A[., j] :== A[., keep_idx[k]])) {
                keep_j = 0
                break
            }
        }
        if (keep_j) {
            keep_idx = keep_idx, j
        }
    }

    return(A[., keep_idx])
}

real matrix _hddid_foldkey_rank_center(real matrix key_data)
{
    real scalar n, p, j, start, stop, avg_rank, center
    real colvector ord
    real matrix ranks

    n = rows(key_data)
    p = cols(key_data)
    if (n == 0 | p == 0) {
        return(key_data)
    }
    if (hasmissing(key_data)) {
        errprintf("_hddid_foldkey_rank_center(): split-key columns must be finite; found missing/nonfinite values\n")
        _error(3498)
    }

    ranks = J(n, p, .)
    center = (n + 1) / 2
    for (j = 1; j <= p; j++) {
        ord = order(key_data[., j], 1)
        start = 1
        while (start <= n) {
            stop = start
            while (stop < n) {
                if (key_data[ord[stop + 1], j] != key_data[ord[start], j]) {
                    break
                }
                stop = stop + 1
            }
            avg_rank = (start + stop) / 2
            ranks[ord[|start \ stop|], j] = J(stop - start + 1, 1, avg_rank - center)
            start = stop + 1
        }
    }

    return(ranks)
}

real colvector _hddid_resolve_fold_order(real matrix primary_keys, real matrix raw_keys, real matrix exact_keys)
{
    real scalar n, j, block_end
    real colvector ord_primary, ord_final, block_idx, block_ord
    real matrix block_raw, block_exact, block_sort_input

    n = rows(primary_keys)
    if (rows(raw_keys) != n | rows(exact_keys) != n) {
        errprintf("_hddid_resolve_fold_order(): primary/raw/exact row mismatch (%g, %g, %g)\n",
            n, rows(raw_keys), rows(exact_keys))
        _error(3498)
    }
    if (n == 0) {
        return(J(0, 1, .))
    }

    ord_primary = order(primary_keys, 1..cols(primary_keys))
    ord_final = ord_primary

    j = 1
    while (j <= n) {
        block_end = j
        while (block_end < n) {
            if (any(primary_keys[ord_primary[block_end + 1], .] :!= ///
                primary_keys[ord_primary[j], .])) {
                break
            }
            block_end = block_end + 1
        }

        if (block_end > j) {
            block_idx = ord_primary[j..block_end]
            block_raw = raw_keys[block_idx, .]
            block_exact = exact_keys[block_idx, .]
            // raw_keys already arrive in a sign/affine-invariant canonical
            // representation, but they can still tie exactly for mirror-image
            // extremes. Break those residual ties on the corresponding exact
            // sign-canonical split keys so pure sign recodings do not let
            // caller row order leak into fold assignment.
            block_sort_input = (block_raw, block_exact)
            block_ord = order(block_sort_input, 1..cols(block_sort_input))
            ord_final[j..block_end] = block_idx[block_ord]
        }

        j = block_end + 1
    }

    return(ord_final)
}

real matrix _hddid_stratified_fold_map_xz(
    real matrix x_data, real colvector z_data,
    real matrix treat, real scalar K, real scalar seed)
{
    real scalar n, pz_g, phase1, phase2, phase_seed, g, j, key_rank
    real colvector coeff1, coeff2, score1_g, score2_g, idx, ord
    real matrix order_keys, fold_map, x_canon_g, xz_canon_g, xz_score_input_g
    real matrix xz_rank_input_g, xz_rank_canon_g
    real rowvector prev_key

    n = rows(z_data)

    if (cols(treat) != 1) {
        errprintf("_hddid_stratified_fold_map_xz(): treat must be an n x 1 column vector; got %g x %g\n",
            rows(treat), cols(treat))
        _error(3498)
    }
    if (rows(treat) != n | rows(x_data) != n) {
        errprintf("_hddid_stratified_folds_xz(): x, z, and treat row mismatch (%g, %g, %g)\n",
            rows(x_data), n, rows(treat))
        _error(3498)
    }
    if (n == 0) {
        errprintf("_hddid_stratified_folds_xz(): empty input\n")
        _error(3498)
    }
    if (hasmissing(x_data) | hasmissing(z_data)) {
        errprintf("_hddid_stratified_folds_xz(): x and z must be finite with no missing values\n")
        _error(3498)
    }
    if (K < 2 | K != trunc(K)) {
        errprintf("_hddid_stratified_folds_xz(): K must be an integer >= 2, got %g\n", K)
        _error(3498)
    }
    if (seed >= . | seed != trunc(seed) | seed < -1 | seed > 2147483647) {
        errprintf("_hddid_stratified_folds_xz(): seed must be an integer in [0, 2147483647] or -1, got %g\n",
            seed)
        _error(3498)
    }
    if (min(treat) < 0 | max(treat) > 1 | any(treat :!= trunc(treat))) {
        errprintf("_hddid_stratified_folds_xz(): treat must be binary 0/1\n")
        _error(3498)
    }

    // Keep the omitted-seed path deterministic, but do not let the public
    // no-seed sentinel numerically alias the explicit seed(0) fold map.
    phase_seed = (seed >= 0 ? seed : -997)
    phase1 = phase_seed / 997 + pi() / 10
    phase2 = phase_seed / 991 + pi() / 7

    fold_map = J(n, 2, .)

    for (g = 0; g <= 1; g++) {
        idx = selectindex(treat :== g)
        if (rows(idx) == 0) {
            continue
        }
        // Canonicalize only x() columns. z() is a structural role, so rows
        // that swap x and z values must stay distinct split keys.
        x_canon_g = _hddid_drop_duplicate_cols(x_data[idx, .])
        x_canon_g = _hddid_foldkey_canon(x_canon_g)
        xz_canon_g = (x_canon_g, z_data[idx])
        pz_g = cols(xz_canon_g)
        coeff1 = 1 :/ (1..pz_g)'
        coeff2 = 1 :/ ((1..pz_g)' :+ 17)
        // Quantize the O(1) score input so sub-ULP drift from extreme but
        // finite affine recodings cannot relabel otherwise identical keys.
        xz_score_input_g = round(_hddid_foldkey_standardize(xz_canon_g), 1e-10)
        xz_rank_input_g = _hddid_foldkey_rank_center(xz_canon_g)
        xz_rank_canon_g = _hddid_colsignorbit_canon(xz_rank_input_g)
        // Quantize the compressed scores themselves so row-order-dependent
        // summation drift in centering/scaling cannot outrank the
        // sign/affine-invariant rank keys that follow as the final
        // deterministic tie-breaker.
        score1_g = round(abs(sin(abs(xz_score_input_g) * coeff1 :+ phase1)), 1e-10)
        score2_g = round(abs(cos(abs(xz_score_input_g) * coeff2 :+ phase2)), 1e-10)
        // Deterministic tie-breakers must inherit the same affine invariance as
        // the main score. Centered column ranks stay fixed under positive
        // affine recodings and negate under coordinatewise sign flips, so use
        // only those reduced keys when breaking residual score collisions.
        order_keys = (score1_g, score2_g, abs(xz_rank_input_g), ///
            xz_rank_canon_g)
        ord = _hddid_resolve_fold_order(order_keys, xz_rank_canon_g, xz_canon_g)
        key_rank = 0
        prev_key = J(1, cols(xz_canon_g), .)
        for (j = 1; j <= rows(idx); j++) {
            if (j == 1 | any(xz_canon_g[ord[j], .] :!= prev_key)) {
                key_rank = key_rank + 1
                prev_key = xz_canon_g[ord[j], .]
            }
            fold_map[idx[ord[j]], 1] = mod(key_rank - 1, K) + 1
            fold_map[idx[ord[j]], 2] = key_rank
        }
        if (key_rank < K) {
            errprintf("_hddid_stratified_folds_xz(): treatment arm %g has only %g distinct split-key groups; requested K=%g would leave at least one outer fold empty because exact duplicate keys stay together\n",
                g, key_rank, K)
            _error(3498)
        }
    }

    return(fold_map)
}

real matrix _hddid_fold_map_xz_relaxed(
    real matrix x_data, real colvector z_data,
    real matrix treat, real scalar K, real scalar seed)
{
    real scalar n, pz_g, phase1, phase2, phase_seed, g, j, key_rank
    real colvector coeff1, coeff2, score1_g, score2_g, idx, ord
    real matrix order_keys, fold_map, x_canon_g, xz_canon_g, xz_score_input_g
    real matrix xz_rank_input_g, xz_rank_canon_g
    real rowvector prev_key

    n = rows(z_data)

    if (cols(treat) != 1) {
        errprintf("_hddid_fold_map_xz_relaxed(): treat must be an n x 1 column vector; got %g x %g\n",
            rows(treat), cols(treat))
        _error(3498)
    }
    if (rows(treat) != n | rows(x_data) != n) {
        errprintf("_hddid_fold_map_xz_relaxed(): x, z, and treat row mismatch (%g, %g, %g)\n",
            rows(x_data), n, rows(treat))
        _error(3498)
    }
    if (n == 0) {
        errprintf("_hddid_fold_map_xz_relaxed(): empty input\n")
        _error(3498)
    }
    if (hasmissing(x_data) | hasmissing(z_data)) {
        errprintf("_hddid_fold_map_xz_relaxed(): x and z must be finite with no missing values\n")
        _error(3498)
    }
    if (K < 2 | K != trunc(K)) {
        errprintf("_hddid_fold_map_xz_relaxed(): K must be an integer >= 2, got %g\n", K)
        _error(3498)
    }
    if (seed >= . | seed != trunc(seed) | seed < -1 | seed > 2147483647) {
        errprintf("_hddid_fold_map_xz_relaxed(): seed must be an integer in [0, 2147483647] or -1, got %g\n",
            seed)
        _error(3498)
    }
    if (min(treat) < 0 | max(treat) > 1 | any(treat :!= trunc(treat))) {
        errprintf("_hddid_fold_map_xz_relaxed(): treat must be binary 0/1\n")
        _error(3498)
    }

    phase_seed = (seed >= 0 ? seed : -997)
    phase1 = phase_seed / 997 + pi() / 10
    phase2 = phase_seed / 991 + pi() / 7

    fold_map = J(n, 2, .)

    for (g = 0; g <= 1; g++) {
        idx = selectindex(treat :== g)
        if (rows(idx) == 0) {
            continue
        }
        x_canon_g = _hddid_drop_duplicate_cols(x_data[idx, .])
        x_canon_g = _hddid_foldkey_canon(x_canon_g)
        xz_canon_g = (x_canon_g, z_data[idx])
        pz_g = cols(xz_canon_g)
        coeff1 = 1 :/ (1..pz_g)'
        coeff2 = 1 :/ ((1..pz_g)' :+ 17)
        xz_score_input_g = round(_hddid_foldkey_standardize(xz_canon_g), 1e-10)
        xz_rank_input_g = _hddid_foldkey_rank_center(xz_canon_g)
        xz_rank_canon_g = _hddid_colsignorbit_canon(xz_rank_input_g)
        score1_g = round(abs(sin(abs(xz_score_input_g) * coeff1 :+ phase1)), 1e-10)
        score2_g = round(abs(cos(abs(xz_score_input_g) * coeff2 :+ phase2)), 1e-10)
        order_keys = (score1_g, score2_g, abs(xz_rank_input_g), ///
            xz_rank_canon_g)
        ord = _hddid_resolve_fold_order(order_keys, xz_rank_canon_g, xz_canon_g)
        key_rank = 0
        prev_key = J(1, cols(xz_canon_g), .)
        for (j = 1; j <= rows(idx); j++) {
            if (j == 1 | any(xz_canon_g[ord[j], .] :!= prev_key)) {
                key_rank = key_rank + 1
                prev_key = xz_canon_g[ord[j], .]
            }
            fold_map[idx[ord[j]], 1] = mod(key_rank - 1, K) + 1
            fold_map[idx[ord[j]], 2] = key_rank
        }
        if (key_rank < K) {
            errprintf("_hddid_fold_map_xz_relaxed(): treatment arm %g has only %g distinct split-key groups on the retained sample; requested K=%g would leave at least one retained evaluation fold empty because exact duplicate keys stay together\n",
                g, key_rank, K)
            _error(3498)
        }
    }

    return(fold_map)
}

real matrix _hddid_stratified_fold_map(
    real matrix xz, real colvector treat, real scalar K, real scalar seed)
{
    real scalar n, pz_g, phase1, phase2, phase_seed, g, j, key_rank
    real colvector coeff1, coeff2, score1_g, score2_g, idx, ord
    real matrix order_keys, fold_map, xz_canon_g, xz_score_input_g
    real matrix xz_rank_input_g, xz_rank_canon_g
    real rowvector prev_key

    n = rows(xz)

    if (rows(treat) != n) {
        errprintf("_hddid_stratified_folds(): xz and treat row mismatch (%g vs %g)\n",
            n, rows(treat))
        _error(3498)
    }
    if (n == 0) {
        errprintf("_hddid_stratified_folds(): empty input\n")
        _error(3498)
    }
    if (hasmissing(xz)) {
        errprintf("_hddid_stratified_folds(): xz must be finite with no missing values\n")
        _error(3498)
    }
    if (K < 2 | K != trunc(K)) {
        errprintf("_hddid_stratified_folds(): K must be an integer >= 2, got %g\n", K)
        _error(3498)
    }
    if (seed >= . | seed != trunc(seed) | seed < -1 | seed > 2147483647) {
        errprintf("_hddid_stratified_folds(): seed must be an integer in [0, 2147483647] or -1, got %g\n",
            seed)
        _error(3498)
    }
    if (min(treat) < 0 | max(treat) > 1 | any(treat :!= trunc(treat))) {
        errprintf("_hddid_stratified_folds(): treat must be binary 0/1\n")
        _error(3498)
    }

    // Keep the omitted-seed path deterministic, but do not let the public
    // no-seed sentinel numerically alias the explicit seed(0) fold map.
    phase_seed = (seed >= 0 ? seed : -997)
    phase1 = phase_seed / 997 + pi() / 10
    phase2 = phase_seed / 991 + pi() / 7

    fold_map = J(n, 2, .)

    for (g = 0; g <= 1; g++) {
        idx = selectindex(treat :== g)
        if (rows(idx) == 0) {
            continue
        }
        // Canonicalize the key columns within arm so one treatment arm's
        // marginal key distribution cannot relabel the other arm's split key.
        xz_canon_g = _hddid_drop_duplicate_cols(xz[idx, .])
        xz_canon_g = _hddid_foldkey_canon(xz_canon_g)
        pz_g = cols(xz_canon_g)
        coeff1 = 1 :/ (1..pz_g)'
        coeff2 = 1 :/ ((1..pz_g)' :+ 17)
        // The split is stratified by treatment arm, so the within-arm ordering
        // signal must also be arm-local. Otherwise changing the opposite arm's
        // covariate scale perturbs this arm's fold map through the shared
        // centering/scaling step even though the arm-specific keys are fixed.
        // Quantize the O(1) score input so sub-ULP drift from extreme but
        // finite affine recodings cannot relabel otherwise identical keys.
        xz_score_input_g = round(_hddid_foldkey_standardize(xz_canon_g), 1e-10)
        xz_rank_input_g = _hddid_foldkey_rank_center(xz_canon_g)
        xz_rank_canon_g = _hddid_colsignorbit_canon(xz_rank_input_g)
        // Quantize the compressed scores themselves so row-order-dependent
        // summation drift in centering/scaling cannot outrank the
        // sign/affine-invariant rank keys that follow as the final
        // deterministic tie-breaker.
        score1_g = round(abs(sin(abs(xz_score_input_g) * coeff1 :+ phase1)), 1e-10)
        score2_g = round(abs(cos(abs(xz_score_input_g) * coeff2 :+ phase2)), 1e-10)
        // Deterministic tie-breakers must inherit the same affine invariance as
        // the main score. Centered column ranks stay fixed under positive
        // affine recodings and negate under coordinatewise sign flips, so use
        // only those reduced keys when breaking residual score collisions.
        order_keys = (score1_g, score2_g, abs(xz_rank_input_g), ///
            xz_rank_canon_g)
        ord = _hddid_resolve_fold_order(order_keys, xz_rank_canon_g, xz_canon_g)
        key_rank = 0
        prev_key = J(1, cols(xz_canon_g), .)
        for (j = 1; j <= rows(idx); j++) {
            if (j == 1 | any(xz_canon_g[ord[j], .] :!= prev_key)) {
                key_rank = key_rank + 1
                prev_key = xz_canon_g[ord[j], .]
            }
            fold_map[idx[ord[j]], 1] = mod(key_rank - 1, K) + 1
            fold_map[idx[ord[j]], 2] = key_rank
        }
        if (key_rank < K) {
            errprintf("_hddid_stratified_folds(): treatment arm %g has only %g distinct split-key groups; requested K=%g would leave at least one outer fold empty because exact duplicate keys stay together\n",
                g, key_rank, K)
            _error(3498)
        }
    }

    return(fold_map)
}

real colvector _hddid_stratified_folds(
    real matrix xz, real colvector treat, real scalar K, real scalar seed)
{
    return(_hddid_stratified_fold_map(xz, treat, K, seed)[., 1])
}

void _hddid_store_fold_map_byvars(
    string scalar fold_var, string scalar rank_var,
    string scalar touse_var, string scalar keyvars,
    string scalar treat_var, real scalar K, real scalar seed)
{
    real matrix key_data
    real matrix fold_map
    string rowvector key_tokens

    key_tokens = tokens(keyvars)
    if (cols(key_tokens) == 0) {
        errprintf("_hddid_store_fold_map_byvars(): keyvars must name at least one variable\n")
        _error(3498)
    }

    fold_map = _hddid_stratified_fold_map(
        st_data(., key_tokens, touse_var),
        st_data(., treat_var, touse_var),
        K, seed)

    st_store(., st_varindex(fold_var), touse_var, fold_map[., 1])
    st_store(., st_varindex(rank_var), touse_var, fold_map[., 2])
}

void _hddid_store_stratified_fold_map(
    string scalar fold_var, string scalar rank_var,
    string scalar touse_var, string scalar xvars,
    string scalar zvar, string scalar treat_var,
    real scalar K, real scalar seed)
{
    real matrix fold_map, x_data
    real colvector z_data, treat_data
    real rowvector x_ord
    string rowvector x_tokens

    x_tokens = tokens(xvars)
    if (cols(x_tokens) == 0) {
        errprintf("_hddid_store_stratified_fold_map(): xvars must name at least one variable\n")
        _error(3498)
    }
    if (cols(x_tokens) > 1) {
        x_ord = order(x_tokens', 1)'
        x_tokens = x_tokens[x_ord]
    }
    x_data = st_data(., x_tokens, touse_var)
    z_data = st_data(., zvar, touse_var)
    treat_data = st_data(., treat_var, touse_var)

    fold_map = _hddid_stratified_fold_map_xz(
        x_data, z_data, treat_data, K, seed)

    st_store(., st_varindex(fold_var), touse_var, fold_map[., 1])
    st_store(., st_varindex(rank_var), touse_var, fold_map[., 2])
}

void _hddid_default_outer_fold_map_m(
    string scalar fold_var, string scalar rank_var,
    string scalar score_touse_var, string scalar prop_touse_var,
    string scalar xvars, string scalar zvar, string scalar treat_var,
    real scalar K, real scalar seed)
{
    real scalar n_all, p, g, i, j, n_score, score_block_size, score_max_rank_g, group_count, new_count
    real scalar pz_g, phase_seed, phase1, phase2, key_rank_new, gid, new_id
    real colvector prop_touse, score_touse, treat_data, z_data
    real colvector prop_idx, score_idx, score_arm_idx, aux_arm_idx
    real colvector fold_all, rank_all, ord_score, ord_aux, ord_new
    real colvector aux_group_id, aux_group_fold, aux_group_rank
    real colvector score_unique_fold, score_unique_rank, aux_group_new_id
    real colvector coeff1, coeff2, score1_g, score2_g
    real matrix x_data, score_keys, aux_keys, new_keys
    real matrix x_new, x_canon_new, xz_canon_new, xz_score_input_g
    real matrix xz_rank_input_g, xz_rank_canon_g, order_keys
    real rowvector x_ord, prev_key
    string rowvector x_tokens

    x_tokens = tokens(xvars)
    if (cols(x_tokens) == 0) {
        errprintf("_hddid_default_outer_fold_map_m(): xvars must name at least one variable\n")
        _error(3498)
    }
    if (cols(x_tokens) > 1) {
        x_ord = order(x_tokens', 1)'
        x_tokens = x_tokens[x_ord]
    }

    prop_touse = st_data(., prop_touse_var)
    score_touse = st_data(., score_touse_var)
    treat_data = st_data(., treat_var)
    z_data = st_data(., zvar)
    x_data = st_data(., x_tokens)
    n_all = rows(prop_touse)
    p = cols(x_data)

    if (rows(score_touse) != n_all | rows(treat_data) != n_all | rows(z_data) != n_all) {
        errprintf("_hddid_default_outer_fold_map_m(): input row mismatch\n")
        _error(3498)
    }
    if (hasmissing(prop_touse) | min(prop_touse) < 0 | max(prop_touse) > 1 | any(prop_touse :!= trunc(prop_touse))) {
        errprintf("_hddid_default_outer_fold_map_m(): prop_touse must be a finite 0/1 indicator\n")
        _error(3498)
    }
    if (K < 2 | K != trunc(K)) {
        errprintf("_hddid_default_outer_fold_map_m(): K must be an integer >= 2, got %g\n", K)
        _error(3498)
    }
    if (hasmissing(score_touse) | min(score_touse) < 0 | max(score_touse) > 1 | any(score_touse :!= trunc(score_touse))) {
        errprintf("_hddid_default_outer_fold_map_m(): score_touse must be a finite 0/1 indicator\n")
        _error(3498)
    }
    prop_idx = selectindex(prop_touse :== 1)
    score_idx = selectindex((prop_touse :== 1) :& (score_touse :== 1))
    if (hasmissing(x_data[prop_idx, .]) | hasmissing(z_data[prop_idx])) {
        errprintf("_hddid_default_outer_fold_map_m(): x and z must be finite on the wider default propensity sample\n")
        _error(3498)
    }
    if (hasmissing(treat_data[prop_idx]) | min(treat_data[prop_idx]) < 0 | max(treat_data[prop_idx]) > 1 | any(treat_data[prop_idx] :!= trunc(treat_data[prop_idx]))) {
        errprintf("_hddid_default_outer_fold_map_m(): treat must be a finite 0/1 indicator\n")
        _error(3498)
    }
    if (any((score_touse :== 1) :& (prop_touse :== 0))) {
        errprintf("_hddid_default_outer_fold_map_m(): score_touse must be a subset of prop_touse\n")
        _error(3498)
    }

    if (rows(prop_idx) == 0 | rows(score_idx) == 0) {
        errprintf("_hddid_default_outer_fold_map_m(): wider propensity sample and score sample must both be nonempty\n")
        _error(3498)
    }
    if (sum(treat_data[score_idx] :== 1) == 0 | sum(treat_data[score_idx] :== 0) == 0) {
        errprintf("_hddid_default_outer_fold_map_m(): score_touse must contain both treatment arms on the common score sample\n")
        _error(3498)
    }

    fold_all = J(n_all, 1, .)
    rank_all = J(n_all, 1, .)
    // The paper only needs held-out sample splitting, and the R reference
    // realizes that split as contiguous blocks in the current score-sample
    // row order before any later trimming. Keep the default fold-pinning
    // map on that same row-order path instead of rebuilding a stratified/keyed
    // fold hash on W=(X,Z).
    n_score = rows(score_idx)
    score_block_size = ceil(n_score / K)
    for (i = 1; i <= n_score; i++) {
        fold_all[score_idx[i]] = (ceil(i / score_block_size) <= K ? ceil(i / score_block_size) : K)
        rank_all[score_idx[i]] = i
    }

    for (g = 0; g <= 1; g++) {
        score_arm_idx = selectindex((prop_touse :== 1) :& (score_touse :== 1) :& (treat_data :== g))
        aux_arm_idx = selectindex((prop_touse :== 1) :& (score_touse :== 0) :& (treat_data :== g))
        if (rows(aux_arm_idx) == 0) {
            continue
        }

        score_max_rank_g = (rows(score_arm_idx) > 0 ? max(rank_all[score_arm_idx]) : 0)
        score_keys = J(0, p + 1, .)
        score_unique_fold = J(0, 1, .)
        score_unique_rank = J(0, 1, .)
        if (rows(score_arm_idx) > 0) {
            score_keys = (x_data[score_arm_idx, .], z_data[score_arm_idx])
            ord_score = order(score_keys, 1..cols(score_keys))
            score_keys = J(0, p + 1, .)
            prev_key = J(1, p + 1, .)
            for (i = 1; i <= rows(score_arm_idx); i++) {
                if (i == 1 | any((x_data[score_arm_idx[ord_score[i]], .], z_data[score_arm_idx[ord_score[i]]]) :!= prev_key)) {
                    prev_key = (x_data[score_arm_idx[ord_score[i]], .], z_data[score_arm_idx[ord_score[i]]])
                    score_keys = score_keys \ prev_key
                    score_unique_fold = score_unique_fold \ fold_all[score_arm_idx[ord_score[i]]]
                    score_unique_rank = score_unique_rank \ rank_all[score_arm_idx[ord_score[i]]]
                }
            }
        }

        aux_keys = (x_data[aux_arm_idx, .], z_data[aux_arm_idx])
        ord_aux = order(aux_keys, 1..cols(aux_keys))
        aux_group_id = J(rows(aux_arm_idx), 1, .)
        aux_group_fold = J(0, 1, .)
        aux_group_rank = J(0, 1, .)
        aux_group_new_id = J(0, 1, .)
        new_keys = J(0, p + 1, .)
        prev_key = J(1, p + 1, .)
        group_count = 0
        new_count = 0

        for (i = 1; i <= rows(aux_arm_idx); i++) {
            if (i == 1 | any(aux_keys[ord_aux[i], .] :!= prev_key)) {
                group_count = group_count + 1
                prev_key = aux_keys[ord_aux[i], .]
                gid = 0
                for (j = 1; j <= rows(score_keys); j++) {
                    if (_hddid_matrix_lexcompare(prev_key, score_keys[j, .]) == 0) {
                        gid = j
                        break
                    }
                }
                if (gid > 0) {
                    aux_group_fold = aux_group_fold \ score_unique_fold[gid]
                    aux_group_rank = aux_group_rank \ score_unique_rank[gid]
                    aux_group_new_id = aux_group_new_id \ 0
                }
                else {
                    new_count = new_count + 1
                    new_keys = new_keys \ prev_key
                    aux_group_fold = aux_group_fold \ .
                    aux_group_rank = aux_group_rank \ .
                    aux_group_new_id = aux_group_new_id \ new_count
                }
            }
            aux_group_id[ord_aux[i]] = group_count
        }

        if (new_count > 0) {
            x_new = new_keys[., 1..p]
            x_canon_new = _hddid_drop_duplicate_cols(x_new)
            x_canon_new = _hddid_foldkey_canon(x_canon_new)
            xz_canon_new = (x_canon_new, new_keys[., p + 1])
            pz_g = cols(xz_canon_new)
            coeff1 = 1 :/ (1..pz_g)'
            coeff2 = 1 :/ ((1..pz_g)' :+ 17)
            phase_seed = (seed >= 0 ? seed : -997)
            phase1 = phase_seed / 997 + pi() / 10
            phase2 = phase_seed / 991 + pi() / 7
            xz_score_input_g = round(_hddid_foldkey_standardize(xz_canon_new), 1e-10)
            xz_rank_input_g = _hddid_foldkey_rank_center(xz_canon_new)
            xz_rank_canon_g = _hddid_colsignorbit_canon(xz_rank_input_g)
            score1_g = round(abs(sin(abs(xz_score_input_g) * coeff1 :+ phase1)), 1e-10)
            score2_g = round(abs(cos(abs(xz_score_input_g) * coeff2 :+ phase2)), 1e-10)
            order_keys = (score1_g, score2_g, abs(xz_rank_input_g), xz_rank_canon_g)
            ord_new = _hddid_resolve_fold_order(order_keys, xz_rank_canon_g, xz_canon_new)
            prev_key = J(1, cols(xz_canon_new), .)
            key_rank_new = 0
            for (i = 1; i <= rows(ord_new); i++) {
                if (i == 1 | any(xz_canon_new[ord_new[i], .] :!= prev_key)) {
                    key_rank_new = key_rank_new + 1
                    prev_key = xz_canon_new[ord_new[i], .]
                }
                aux_group_rank[selectindex(aux_group_new_id :== ord_new[i])] = score_max_rank_g + key_rank_new
                aux_group_fold[selectindex(aux_group_new_id :== ord_new[i])] = mod(score_max_rank_g + key_rank_new - 1, K) + 1
            }
        }

        for (i = 1; i <= rows(aux_arm_idx); i++) {
            gid = aux_group_id[i]
            fold_all[aux_arm_idx[i]] = aux_group_fold[gid]
            rank_all[aux_arm_idx[i]] = aux_group_rank[gid]
        }
    }

    // Default outer folds are defined only on the wider propensity sample.
    // Leave rows outside prop_touse unchanged, matching the other fold-map
    // storage helpers that only write within their declared sample mask.
    st_store(., st_varindex(fold_var), prop_touse_var, fold_all[prop_idx])
    st_store(., st_varindex(rank_var), prop_touse_var, rank_all[prop_idx])
}

void _hddid_store_fold_map_xz_relaxed(
    string scalar fold_var, string scalar rank_var,
    string scalar touse_var, string scalar xvars,
    string scalar zvar, string scalar treat_var,
    real scalar K, real scalar seed)
{
    real matrix fold_map, x_data
    real colvector z_data, treat_data
    real rowvector x_ord
    string rowvector x_tokens

    x_tokens = tokens(xvars)
    if (cols(x_tokens) == 0) {
        errprintf("_hddid_store_fold_map_xz_relaxed(): xvars must name at least one variable\n")
        _error(3498)
    }
    if (cols(x_tokens) > 1) {
        x_ord = order(x_tokens', 1)'
        x_tokens = x_tokens[x_ord]
    }
    x_data = st_data(., x_tokens, touse_var)
    z_data = st_data(., zvar, touse_var)
    treat_data = st_data(., treat_var, touse_var)

    fold_map = _hddid_fold_map_xz_relaxed(
        x_data, z_data, treat_data, K, seed)

    st_store(., st_varindex(fold_var), touse_var, fold_map[., 1])
    st_store(., st_varindex(rank_var), touse_var, fold_map[., 2])
}

void _hddid_store_sieve_basis(
    string scalar z_var, string scalar touse_var,
    string scalar method, real scalar q,
    string scalar zb_varlist, string scalar zbf_varlist,
    real scalar z_min, real scalar z_max)
{
    real colvector z_data
    real matrix zbasis
    string rowvector zb_tokens, zbf_tokens
    real scalar j

    z_data = st_data(., z_var, touse_var)
    if (strlower(method) == "pol") {
        zbasis = _hddid_sieve_pol(z_data, q)
    }
    else if (strlower(method) == "tri") {
        zbasis = _hddid_sieve_tri_support(z_data, q, z_min, z_max)
    }
    else {
        errprintf("_hddid_store_sieve_basis(): unknown method %s\n", method)
        _error(3498)
    }

    if (hasmissing(zbasis)) {
        errprintf("_hddid_store_sieve_basis(): generated sieve basis contains missing/nonfinite values\n")
        errprintf("  Reason: polynomial/trigonometric basis evaluation overflowed or encountered invalid support values\n")
        _error(3498)
    }

    zb_tokens = tokens(zb_varlist)
    zbf_tokens = tokens(zbf_varlist)

    if (cols(zb_tokens) != q) {
        errprintf("_hddid_store_sieve_basis(): expected %g non-intercept sieve vars, got %g\n",
            q, cols(zb_tokens))
        _error(3498)
    }
    if (cols(zbf_tokens) != q + 1) {
        errprintf("_hddid_store_sieve_basis(): expected %g full sieve vars, got %g\n",
            q + 1, cols(zbf_tokens))
        _error(3498)
    }

    st_store(., st_varindex(zbf_tokens[1]), touse_var, zbasis[., 1])
    for (j = 1; j <= q; j++) {
        st_store(., st_varindex(zb_tokens[j]), touse_var, zbasis[., j + 1])
        st_store(., st_varindex(zbf_tokens[j + 1]), touse_var, zbasis[., j + 1])
    }
}

void _hddid_store_z0_basis(
    string scalar z0_numlist, string scalar method,
    real scalar q, string scalar zbpred_name,
    real scalar z_min, real scalar z_max)
{
    real colvector z0_vec
    real matrix zbpred_full

    z0_vec = strtoreal(tokens(z0_numlist))'
    if (rows(z0_vec) == 0) {
        errprintf("_hddid_store_z0_basis(): z0 grid must contain at least one finite evaluation point\n")
        _error(3498)
    }
    if (strlower(method) == "pol") {
        if (hasmissing(z0_vec)) {
            errprintf("_hddid_store_z0_basis(): z0 grid must be finite; found missing/nonfinite value(s)\n")
            _error(3498)
        }
        zbpred_full = _hddid_sieve_pol(z0_vec, q)
    }
    else if (strlower(method) == "tri") {
        if (hasmissing(z0_vec)) {
            errprintf("_hddid_store_z0_basis(): Tri z0() values must be finite\n")
            _error(3498)
        }
        if (min(z0_vec) < z_min | max(z0_vec) > z_max) {
            errprintf("_hddid_store_z0_basis(): Tri z0() values must lie within the retained support [%g, %g]\n",
                z_min, z_max)
            _error(3498)
        }
        zbpred_full = _hddid_sieve_tri_support(z0_vec, q, z_min, z_max)
    }
    else {
        errprintf("_hddid_store_z0_basis(): unknown method %s\n", method)
        _error(3498)
    }

    if (hasmissing(zbpred_full)) {
        errprintf("_hddid_store_z0_basis(): generated z0 basis contains missing/nonfinite values\n")
        errprintf("  Reason: polynomial/trigonometric evaluation at z0() overflowed or encountered invalid support values\n")
        _error(3498)
    }

    st_matrix(zbpred_name, zbpred_full)
}

void _hddid_restrict_fold_z0_grid(
    real scalar K,
    string scalar full_z0_list,
    string scalar keep_z0_list,
    string scalar zbpred_name)
{
    real colvector full_z0, keep_z0, keep_idx
    real colvector full_z0_canon, keep_z0_canon
    real matrix gdebias_k, stdg_k, zbpred, Vf_k
    real scalar i, j, k, m, qq_full, qq_keep, nan_fallback, q_zb
    real scalar match_scale, match_tol, later_scale, later_tol
    string scalar k_str

    if (K < 2 | K != trunc(K) | K >= .) {
        errprintf("_hddid_restrict_fold_z0_grid(): K must be an integer >= 2, got %g\n", K)
        _error(3498)
    }

    full_z0 = strtoreal(tokens(full_z0_list))'
    keep_z0 = strtoreal(tokens(keep_z0_list))'
    qq_full = rows(full_z0)
    qq_keep = rows(keep_z0)

    if (hasmissing(full_z0)) {
        errprintf("_hddid_restrict_fold_z0_grid(): full_z0_list must contain only finite evaluation points\n")
        _error(3498)
    }
    if (hasmissing(keep_z0)) {
        errprintf("_hddid_restrict_fold_z0_grid(): keep_z0_list must contain only finite evaluation points\n")
        _error(3498)
    }
    if (qq_full < 1 | qq_keep < 1 | qq_keep > qq_full) {
        errprintf("_hddid_restrict_fold_z0_grid(): invalid z0-grid widths full=%g keep=%g\n",
            qq_full, qq_keep)
        _error(3498)
    }

    // Restrict the retained grid by numeric support points. levelsof can round
    // large doubles by one ULP when it converts them to decimal text, so
    // accept machine-precision-equivalent tokens. Treat the retained grid as
    // an ordered subsequence of the full grid rather than requiring unique
    // support points: duplicate z0() evaluation rows are legal repeated
    // function evaluations in both the paper object and the R reference path.
    full_z0_canon = full_z0
    keep_z0_canon = keep_z0

    keep_idx = J(qq_keep, 1, .)
    j = 1
    for (i = 1; i <= qq_full & j <= qq_keep; i++) {
        // Match on the z0 scale itself. A unit-scale floor would let a
        // materially different near-zero keep token hijack a full-grid point
        // even though the retained evaluation row is not actually present.
        match_scale = max((abs(full_z0_canon[i]), abs(keep_z0_canon[j])))
        match_tol = 2 * epsilon(1) * match_scale
        if (abs(full_z0_canon[i] - keep_z0_canon[j]) <= match_tol) {
            keep_idx[j] = i
            j++
        }
    }
    if (j <= qq_keep) {
        errprintf("_hddid_restrict_fold_z0_grid(): keep_z0_list must be an ordered subset of full_z0_list\n")
        _error(3498)
    }

    zbpred = st_matrix(zbpred_name)
    if (rows(zbpred) != qq_full) {
        errprintf("_hddid_restrict_fold_z0_grid(): z0 basis has %g rows; expected full grid width %g\n",
            rows(zbpred), qq_full)
        _error(3498)
    }
    q_zb = cols(zbpred)
    if (q_zb < 1) {
        errprintf("_hddid_restrict_fold_z0_grid(): z0 basis must have at least one sieve column; got %g x %g\n",
            rows(zbpred), cols(zbpred))
        _error(3498)
    }
    if (hasmissing(zbpred)) {
        errprintf("_hddid_restrict_fold_z0_grid(): z0 basis must be finite before restriction; found missing/nonfinite values\n")
        _error(3498)
    }

    for (k = 1; k <= K; k++) {
        k_str = strofreal(k)
        gdebias_k = st_matrix("__hddid_fold_gdebias_" + k_str)
        if (rows(gdebias_k) != 1 | cols(gdebias_k) != qq_full) {
            errprintf("_hddid_restrict_fold_z0_grid(): fold %g gdebias has shape %g x %g; expected 1 x %g\n",
                k, rows(gdebias_k), cols(gdebias_k), qq_full)
            _error(3498)
        }
        if (hasmissing(gdebias_k)) {
            errprintf("_hddid_restrict_fold_z0_grid(): fold %g gdebias must be finite before restriction; found missing/nonfinite values\n",
                k)
            _error(3498)
        }

        nan_fallback = st_numscalar("__hddid_fold_nanfb_" + k_str)
        stdg_k = st_matrix("__hddid_fold_stdg_" + k_str)
        if (nan_fallback != 0 & nan_fallback != 1) {
            errprintf("_hddid_restrict_fold_z0_grid(): fold %g nan_fallback must be 0 or 1; got %g\n",
                k, nan_fallback)
            _error(3498)
        }
        if (nan_fallback == 1) {
            if (rows(stdg_k) != qq_full | cols(stdg_k) != qq_full) {
                errprintf("_hddid_restrict_fold_z0_grid(): fold %g stdg has shape %g x %g; expected %g x %g when nan_fallback=1\n",
                    k, rows(stdg_k), cols(stdg_k), qq_full, qq_full)
                _error(3498)
            }
            _hddid_assert_nanfb_stdg_carrier(
                "_hddid_restrict_fold_z0_grid(): fold " + strofreal(k) + " stdg",
                stdg_k)
            if (hasmissing(diagonal(stdg_k)')) {
                errprintf("_hddid_restrict_fold_z0_grid(): fold %g stdg diagonal must be finite when nan_fallback=1\n",
                    k)
                _error(3498)
            }
            if (min(diagonal(stdg_k)) < 0) {
                errprintf("_hddid_restrict_fold_z0_grid(): fold %g stdg diagonal must be nonnegative when nan_fallback=1; min diagonal entry = %g\n",
                    k, min(diagonal(stdg_k)))
                _error(3498)
            }
        }
        else {
            if (rows(stdg_k) != 1 | cols(stdg_k) != qq_full) {
                errprintf("_hddid_restrict_fold_z0_grid(): fold %g stdg has shape %g x %g; expected 1 x %g when nan_fallback=0\n",
                    k, rows(stdg_k), cols(stdg_k), qq_full)
                _error(3498)
            }
            if (hasmissing(stdg_k)) {
                errprintf("_hddid_restrict_fold_z0_grid(): fold %g stdg must be finite before restriction; found missing/nonfinite values\n",
                    k)
                _error(3498)
            }
            if (min(stdg_k) < 0) {
                errprintf("_hddid_restrict_fold_z0_grid(): fold %g stdg must be nonnegative before restriction; min entry = %g\n",
                    k, min(stdg_k))
                _error(3498)
            }
        }
        Vf_k = st_matrix("__hddid_fold_Vf_" + k_str)
        if ((rows(Vf_k) > 0 | cols(Vf_k) > 0) &
            (rows(Vf_k) != q_zb | cols(Vf_k) != q_zb)) {
            errprintf("_hddid_restrict_fold_z0_grid(): fold %g Vf has shape %g x %g; expected %g x %g to match cols(z0 basis)\n",
                k, rows(Vf_k), cols(Vf_k), q_zb, q_zb)
            _error(3498)
        }
        if (rows(Vf_k) > 0 | cols(Vf_k) > 0) {
            if (hasmissing(Vf_k)) {
                errprintf("_hddid_restrict_fold_z0_grid(): fold %g Vf must be finite before restriction; found missing/nonfinite values\n",
                    k)
                _error(3498)
            }
            _hddid_assert_symmetric_finite(
                "_hddid_restrict_fold_z0_grid(): fold " + strofreal(k) + " Vf",
                Vf_k)
        }
    }

    // Apply the retained-grid restriction only after every fold object has
    // passed validation so an error never leaves the z0 basis and fold payloads
    // out of sync on different grid widths.
    st_matrix(zbpred_name, zbpred[keep_idx, .])
    for (k = 1; k <= K; k++) {
        k_str = strofreal(k)
        gdebias_k = st_matrix("__hddid_fold_gdebias_" + k_str)
        st_matrix("__hddid_fold_gdebias_" + k_str, gdebias_k[., keep_idx])

        nan_fallback = st_numscalar("__hddid_fold_nanfb_" + k_str)
        stdg_k = st_matrix("__hddid_fold_stdg_" + k_str)
        if (nan_fallback == 1) {
            st_matrix("__hddid_fold_stdg_" + k_str, stdg_k[keep_idx, keep_idx])
        }
        else {
            st_matrix("__hddid_fold_stdg_" + k_str, stdg_k[., keep_idx])
        }
    }
}

string scalar _hddid_z0_colname(real scalar z0_val, real scalar idx)
{
    string scalar raw, suffix
    real scalar max_raw

    raw = strlower(strtrim(strofreal(z0_val, "%21.15g")))
    raw = subinstr(raw, " ", "", .)
    raw = subinstr(raw, "-", "m", .)
    raw = subinstr(raw, ".", "p", .)
    raw = subinstr(raw, "+", "", .)
    if (substr(raw, 1, 1) == "p") {
        raw = "0" + raw
    }
    else if (substr(raw, 1, 2) == "mp") {
        raw = "m0" + substr(raw, 2, .)
    }

    suffix = "_i" + strofreal(idx, "%9.0g")
    max_raw = 32 - strlen("z0v") - strlen(suffix)
    if (strlen(raw) > max_raw) {
        raw = substr(raw, 1, max_raw)
    }

    return("z0v" + raw + suffix)
}

void _hddid_store_z0_colstripe(string scalar z0_numlist, string scalar local_name)
{
    real rowvector z0_vals
    string rowvector out
    real scalar j

    z0_vals = strtoreal(tokens(z0_numlist))
    if (cols(z0_vals) == 0) {
        errprintf("_hddid_store_z0_colstripe(): z0 grid must contain at least one finite evaluation point\n")
        _error(3498)
    }
    if (hasmissing(z0_vals)) {
        errprintf("_hddid_store_z0_colstripe(): z0 grid must be finite; found missing/nonfinite value(s)\n")
        _error(3498)
    }
    out = J(1, cols(z0_vals), "")
    for (j = 1; j <= cols(z0_vals); j++) {
        out[j] = _hddid_z0_colname(z0_vals[j], j)
    }

    st_local(local_name, invtokens(out))
}

// Helpers used by the cross-fitting pipeline.

struct _hddid_result scalar _hddid_aggregate_folds(
    struct _hddid_fold_result vector fold_results,
    real scalar K, real scalar alpha,
    | real matrix zbasispredict, real scalar nboot, real scalar seed,
      real scalar use_active_seed_stream)
{
    struct _hddid_result scalar result
    real scalar k, n_fold_results, p, qq, z_crit, q, have_bootstrap_inputs, total_valid, wk
    real scalar tc_scale, tc_tol, sf_scale_k, sf_tol_k, vf_scale_k, vf_tol_k, i, j
    real scalar active_count, sf_scale_agg, sf_tol_agg, vf_scale_agg, vf_tol_agg
    real rowvector stdg_sq_sum, stdg_k, stdg_implied_k, stdg_implied_agg, bootstrap_seed
    real rowvector stdg_acc_scale, stdg_term
    real rowvector tc_ref
    real matrix V_sum, Vf_agg, implied_cov_k, implied_cov_agg
    real colvector implied_diag_k, implied_diag_agg, active_idx

    if (K < 2 | K != trunc(K) | K >= .) {
        errprintf("_hddid_aggregate_folds(): K must be an integer >= 2; got %g\n",
            K)
        _error(3498)
    }
    if (alpha <= 0 | alpha >= 1 | alpha >= .) {
        errprintf("_hddid_aggregate_folds(): alpha must lie strictly in (0,1); got %g\n",
            alpha)
        _error(3498)
    }
    if (args() == 4) {
        errprintf("_hddid_aggregate_folds(): bootstrap recomputation requires both zbasispredict and nboot; got zbasispredict only\n")
        _error(3498)
    }

    n_fold_results = length(fold_results)
    if (n_fold_results != K) {
        errprintf("_hddid_aggregate_folds(): fold_results has length %g; expected exactly K = %g fold records\n",
            n_fold_results, K)
        _error(3498)
    }

    p = cols(fold_results[1].xdebias)
    qq = cols(fold_results[1].gdebias)
    total_valid = 0
    for (k = 1; k <= K; k++) {
        if (fold_results[k].n_valid < 1 |
            fold_results[k].n_valid != trunc(fold_results[k].n_valid) |
            fold_results[k].n_valid >= .) {
            errprintf("_hddid_aggregate_folds(): fold %g n_valid must be a finite positive integer; got %g\n",
                k, fold_results[k].n_valid)
            _error(3498)
        }
        total_valid = total_valid + fold_results[k].n_valid
    }
    if (total_valid < 1 | total_valid != trunc(total_valid) | total_valid >= .) {
        errprintf("_hddid_aggregate_folds(): total_valid must be a finite positive integer, got %g\n",
            total_valid)
        _error(3498)
    }
    for (k = 1; k <= K; k++) {
        if (fold_results[k].n_valid < 1 |
            fold_results[k].n_valid != trunc(fold_results[k].n_valid) |
            fold_results[k].n_valid >= .) {
            errprintf("_hddid_aggregate_folds(): fold %g n_valid must be a finite positive integer; got %g\n",
                k, fold_results[k].n_valid)
            _error(3498)
        }
        if (rows(fold_results[k].xdebias) != 1) {
            errprintf("_hddid_aggregate_folds(): fold %g xdebias has shape %g x %g; expected 1 x %g\n",
                k, rows(fold_results[k].xdebias), cols(fold_results[k].xdebias), p)
            _error(3498)
        }
        if (cols(fold_results[k].xdebias) != p) {
            errprintf("_hddid_aggregate_folds(): fold %g xdebias has %g columns; expected %g\n",
                k, cols(fold_results[k].xdebias), p)
            _error(3498)
        }
        if (hasmissing(fold_results[k].xdebias)) {
            errprintf("_hddid_aggregate_folds(): fold %g xdebias must be finite; found missing/nonfinite values\n",
                k)
            _error(3498)
        }
        if (rows(fold_results[k].vcovx) != p | cols(fold_results[k].vcovx) != p) {
            errprintf("_hddid_aggregate_folds(): fold %g vcovx has shape %gx%g; expected %gx%g\n",
                k, rows(fold_results[k].vcovx), cols(fold_results[k].vcovx), p, p)
            _error(3498)
        }
        _hddid_assert_symmetric_psd(
            "_hddid_aggregate_folds(): fold " + strofreal(k) + " vcovx",
            fold_results[k].vcovx)
        if (rows(fold_results[k].stdx) != 1 | cols(fold_results[k].stdx) != p) {
            errprintf("_hddid_aggregate_folds(): fold %g stdx has shape %g x %g; expected 1 x %g\n",
                k, rows(fold_results[k].stdx), cols(fold_results[k].stdx), p)
            _error(3498)
        }
        if (hasmissing(fold_results[k].stdx)) {
            errprintf("_hddid_aggregate_folds(): fold %g stdx must be finite; found missing/nonfinite values\n",
                k)
            _error(3498)
        }
        if (min(fold_results[k].stdx) < 0) {
            errprintf("_hddid_aggregate_folds(): fold %g stdx must be nonnegative; min entry = %g\n",
                k, min(fold_results[k].stdx))
            _error(3498)
        }
        _hddid_assert_vcovx_stdx(
            "_hddid_aggregate_folds(): fold " + strofreal(k) + " vcovx/stdx",
            fold_results[k].vcovx, fold_results[k].stdx)
        if (rows(fold_results[k].gdebias) != 1) {
            errprintf("_hddid_aggregate_folds(): fold %g gdebias has shape %g x %g; expected 1 x %g\n",
                k, rows(fold_results[k].gdebias), cols(fold_results[k].gdebias), qq)
            _error(3498)
        }
        if (cols(fold_results[k].gdebias) != qq) {
            errprintf("_hddid_aggregate_folds(): fold %g gdebias has %g columns; expected %g\n",
                k, cols(fold_results[k].gdebias), qq)
            _error(3498)
        }
        if (hasmissing(fold_results[k].gdebias)) {
            errprintf("_hddid_aggregate_folds(): fold %g gdebias must be finite; found missing/nonfinite values\n",
                k)
            _error(3498)
        }
        if (fold_results[k].nan_fallback != 0 & fold_results[k].nan_fallback != 1) {
            errprintf("_hddid_aggregate_folds(): fold %g nan_fallback must be 0 or 1; got %g\n",
                k, fold_results[k].nan_fallback)
            _error(3498)
        }
        if (fold_results[k].nan_fallback == 1) {
            if (rows(fold_results[k].stdg) != qq | cols(fold_results[k].stdg) != qq) {
                errprintf("_hddid_aggregate_folds(): fold %g stdg has shape %g x %g; expected %g x %g when nan_fallback=1\n",
                    k, rows(fold_results[k].stdg), cols(fold_results[k].stdg), qq, qq)
                _error(3498)
            }
            _hddid_assert_nanfb_stdg_carrier(
                "_hddid_aggregate_folds(): fold " + strofreal(k) + " stdg",
                fold_results[k].stdg)
            if (hasmissing(diagonal(fold_results[k].stdg)')) {
                errprintf("_hddid_aggregate_folds(): fold %g stdg diagonal must be finite when nan_fallback=1\n",
                    k)
                _error(3498)
            }
        }
        else {
            if (rows(fold_results[k].stdg) != 1 | cols(fold_results[k].stdg) != qq) {
                errprintf("_hddid_aggregate_folds(): fold %g stdg has shape %g x %g; expected 1 x %g when nan_fallback=0\n",
                    k, rows(fold_results[k].stdg), cols(fold_results[k].stdg), qq)
                _error(3498)
            }
            if (hasmissing(fold_results[k].stdg)) {
                errprintf("_hddid_aggregate_folds(): fold %g stdg must be finite; found missing/nonfinite values\n",
                    k)
                _error(3498)
            }
        }
    }
    
    // Aggregate across folds using n_valid weights.
    result.xdebias = J(1, p, 0)
    V_sum = J(p, p, 0)
    for (k = 1; k <= K; k++) {
        wk = fold_results[k].n_valid / total_valid
        result.xdebias = result.xdebias + wk * fold_results[k].xdebias
        V_sum = V_sum + (wk^2) * fold_results[k].vcovx
    }
    result.V = V_sum
    _hddid_assert_symmetric_psd("_hddid_aggregate_folds(): aggregated V", result.V)
    result.stdx = sqrt(diagonal(result.V))'
    
    // Nonparametric component: allow a diagonal-only fallback from matrix-shaped stdg.
    result.gdebias = J(1, qq, 0)
    stdg_sq_sum = J(1, qq, 0)
    stdg_acc_scale = J(1, qq, 0)
    for (k = 1; k <= K; k++) {
        wk = fold_results[k].n_valid / total_valid
        result.gdebias = result.gdebias + wk * fold_results[k].gdebias
        if (fold_results[k].nan_fallback == 1) {
            stdg_k = diagonal(fold_results[k].stdg)'
        } else {
            stdg_k = fold_results[k].stdg
        }
        if (hasmissing(stdg_k)) {
            errprintf("_hddid_aggregate_folds(): fold %g pointwise stdg must be finite after diagonal extraction\n",
                k)
            _error(3498)
        }
        if (min(stdg_k) < 0) {
            errprintf("_hddid_aggregate_folds(): fold %g stdg must be nonnegative; min entry = %g\n",
                k, min(stdg_k))
            _error(3498)
        }
        stdg_term = wk * stdg_k
        if (hasmissing(stdg_term)) {
            errprintf("_hddid_aggregate_folds(): weighted fold %g stdg term must be finite before square-sum aggregation\n",
                k)
            _error(3498)
        }
        for (j = 1; j <= qq; j++) {
            if (stdg_term[j] <= 0) {
                continue
            }
            if (stdg_acc_scale[j] <= 0) {
                stdg_acc_scale[j] = stdg_term[j]
                stdg_sq_sum[j] = 1
            }
            else if (stdg_term[j] > stdg_acc_scale[j]) {
                stdg_sq_sum[j] = stdg_sq_sum[j] * ///
                    (stdg_acc_scale[j] / stdg_term[j])^2 + 1
                stdg_acc_scale[j] = stdg_term[j]
            }
            else {
                stdg_sq_sum[j] = stdg_sq_sum[j] + ///
                    (stdg_term[j] / stdg_acc_scale[j])^2
            }
        }
    }
    if (hasmissing(result.gdebias)) {
        errprintf("_hddid_aggregate_folds(): aggregated gdebias must be finite after n_valid weighting; fold outputs overflowed or became nonfinite\n")
        _error(3498)
    }
    result.stdg = stdg_acc_scale :* sqrt(stdg_sq_sum)
    if (hasmissing(result.stdg)) {
        errprintf("_hddid_aggregate_folds(): aggregated stdg must be finite after the paper/R square-sum formula; weighted fold stdg overflowed or became nonfinite\n")
        _error(3498)
    }
    
    // Uniform interval critical values (tc): once zbasispredict and nboot are
    // supplied, seed remains optional because _hddid_bootstrap_tc() already
    // accepts a missing seed to continue from the caller's RNG state.
    have_bootstrap_inputs = (args() >= 5)
    if (have_bootstrap_inputs & args() < 6) {
        seed = .
    }
    if (have_bootstrap_inputs & args() < 7) {
        use_active_seed_stream = 0
    }
    if (have_bootstrap_inputs) {
        if (use_active_seed_stream != 0 & use_active_seed_stream != 1) {
            errprintf("_hddid_aggregate_folds(): use_active_seed_stream must be 0 or 1 when supplied; got %g\n",
                use_active_seed_stream)
            _error(3498)
        }
        bootstrap_seed = (use_active_seed_stream == 1 ? . : seed)
    }
    if (have_bootstrap_inputs) {
        if (rows(zbasispredict) != qq) {
            errprintf("_hddid_aggregate_folds(): zbasispredict has %g evaluation rows; expected qq = %g to match fold gdebias/stdg\n",
                rows(zbasispredict), qq)
            _error(3498)
        }
        q = cols(zbasispredict)
        Vf_agg = J(q, q, 0)
        for (k = 1; k <= K; k++) {
            if (rows(fold_results[k].Vf) != q | cols(fold_results[k].Vf) != q) {
                errprintf("_hddid_aggregate_folds(): fold %g Vf has shape %g x %g; expected %g x %g when bootstrap inputs are supplied\n",
                    k, rows(fold_results[k].Vf), cols(fold_results[k].Vf), q, q)
                _error(3498)
            }
            _hddid_assert_symmetric_finite(
                "_hddid_aggregate_folds(): fold " + strofreal(k) + " Vf",
                fold_results[k].Vf)
            if (fold_results[k].nan_fallback == 1) {
                stdg_k = diagonal(fold_results[k].stdg)'
            }
            else {
                stdg_k = fold_results[k].stdg
            }
            implied_cov_k = zbasispredict * fold_results[k].Vf * zbasispredict'
            vf_scale_k = max(abs(fold_results[k].Vf))
            if (vf_scale_k <= 0 | vf_scale_k >= .) {
                vf_scale_k = 1
            }
            vf_tol_k = 1e-10 * vf_scale_k
            implied_diag_k = diagonal(implied_cov_k)
            for (j = 1; j <= rows(implied_diag_k); j++) {
                // Propagate the fold-level Vf PSD tolerance through the
                // quadratic form psi(z)'Vf psi(z). A matrix-level implied_cov
                // tolerance can become too strict once large evaluation rows
                // magnify an eigendrift that the fold-level Vf contract
                // already accepted as numerical noise.
                sf_tol_k = vf_tol_k * quadcross(zbasispredict[j,.]', zbasispredict[j,.]')
                if (implied_diag_k[j] < 0 & implied_diag_k[j] >= -sf_tol_k) {
                    implied_diag_k[j] = 0
                }
            }
            stdg_implied_k = sqrt(implied_diag_k)' / sqrt(fold_results[k].n_valid)
            if (hasmissing(stdg_implied_k)) {
                errprintf("_hddid_aggregate_folds(): fold %g implied pointwise stdg from Vf/zbasispredict must be finite\n",
                    k)
                _error(3498)
            }
            for (j = 1; j <= cols(stdg_k); j++) {
                // Enforce consistency on each evaluation row's own
                // studentization scale. A large-SE row must not relax the
                // contract for a tiny but same-order row in the same fold.
                sf_scale_k = max((stdg_k[j], stdg_implied_k[j]))
                sf_tol_k = 1e-6 * sf_scale_k
                // stdg_k and stdg_implied_k are both standard errors. Use the
                // standard-error scale for tolerance, and treat only exact
                // zero-variance rows as degenerate.
                if ((stdg_k[j] == 0 & stdg_implied_k[j] > 0) | ///
                    (stdg_k[j] > 0 & stdg_implied_k[j] == 0)) {
                    errprintf("_hddid_aggregate_folds(): fold %g stdg has zero/nonzero pattern inconsistent with fold Vf at evaluation row %g\n",
                        k, j)
                    errprintf("_hddid_aggregate_folds(): fold %g provided stdg=%g, Vf-implied stdg=%g, tolerance=%g\n",
                        k, stdg_k[j], stdg_implied_k[j], sf_tol_k)
                    _error(3498)
                }
                if (max((stdg_k[j], stdg_implied_k[j])) > 0 & ///
                    abs(stdg_k[j] - stdg_implied_k[j]) > sf_tol_k) {
                    errprintf("_hddid_aggregate_folds(): fold %g stdg magnitude must match the fold Vf-implied pointwise SE at evaluation row %g\n",
                        k, j)
                    errprintf("_hddid_aggregate_folds(): fold %g provided stdg=%g, Vf-implied stdg=%g, tolerance=%g\n",
                        k, stdg_k[j], stdg_implied_k[j], sf_tol_k)
                    _error(3498)
                }
            }
            wk = fold_results[k].n_valid / total_valid
            Vf_agg = Vf_agg + (wk^2 / fold_results[k].n_valid) * fold_results[k].Vf
        }

        implied_cov_agg = zbasispredict * Vf_agg * zbasispredict'
        vf_scale_agg = max(abs(Vf_agg))
        if (vf_scale_agg <= 0 | vf_scale_agg >= .) {
            vf_scale_agg = 1
        }
        vf_tol_agg = 1e-10 * vf_scale_agg
        implied_diag_agg = diagonal(implied_cov_agg)
        for (j = 1; j <= rows(implied_diag_agg); j++) {
            sf_tol_agg = vf_tol_agg * quadcross(zbasispredict[j,.]', zbasispredict[j,.]')
            if (implied_diag_agg[j] < 0 & implied_diag_agg[j] >= -sf_tol_agg) {
                implied_diag_agg[j] = 0
            }
        }
        stdg_implied_agg = sqrt(implied_diag_agg)'
        if (hasmissing(stdg_implied_agg)) {
            errprintf("_hddid_aggregate_folds(): aggregate implied pointwise stdg from Vf/zbasispredict must be finite\n")
            _error(3498)
        }
        for (j = 1; j <= cols(result.stdg); j++) {
            sf_scale_agg = max((result.stdg[j], stdg_implied_agg[j]))
            sf_tol_agg = 1e-6 * sf_scale_agg
            if ((result.stdg[j] == 0 & stdg_implied_agg[j] > 0) | ///
                (result.stdg[j] > 0 & stdg_implied_agg[j] == 0)) {
                errprintf("_hddid_aggregate_folds(): aggregate stdg has zero/nonzero pattern inconsistent with aggregate Vf at evaluation row %g\n",
                    j)
                errprintf("_hddid_aggregate_folds(): aggregate provided stdg=%g, Vf-implied stdg=%g, tolerance=%g\n",
                    result.stdg[j], stdg_implied_agg[j], sf_tol_agg)
                _error(3498)
            }
            if (max((result.stdg[j], stdg_implied_agg[j])) > 0 & ///
                abs(result.stdg[j] - stdg_implied_agg[j]) > sf_tol_agg) {
                errprintf("_hddid_aggregate_folds(): aggregate stdg magnitude must match the aggregate Vf-implied pointwise SE at evaluation row %g\n",
                    j)
                errprintf("_hddid_aggregate_folds(): aggregate provided stdg=%g, Vf-implied stdg=%g, tolerance=%g\n",
                    result.stdg[j], stdg_implied_agg[j], sf_tol_agg)
                _error(3498)
            }
        }
    }

    if (have_bootstrap_inputs) {
        active_idx = selectindex(result.stdg :> 0)
        active_count = length(active_idx)
        if (active_count == 0) {
            // A fully degenerate nonparametric block already has
            // CIuniform = gdebias because stdg == 0 rowwise, so preserve the
            // constant-fold shortcut instead of forcing a 0/0 bootstrap law.
            result.tc = (0, 0)
        }
        else {
            // Zero-variance evaluation rows contribute nothing to the sup
            // envelope because their CIuniform entries are already pinned at
            // gdebias. Calibrate tc on the positive-SE rows only.
            result.tc = _hddid_bootstrap_tc(
                Vf_agg,
                zbasispredict[active_idx, .],
                result.stdg[active_idx],
                0, 1, alpha, nboot, bootstrap_seed)
        }
    }
    else {
        tc_ref = fold_results[1].tc
        if (rows(tc_ref) != 1 | cols(tc_ref) != 2) {
            errprintf("_hddid_aggregate_folds(): fallback tc in fold 1 has shape %g x %g; expected 1 x 2\n",
                rows(tc_ref), cols(tc_ref))
            _error(3498)
        }
        if (hasmissing(tc_ref)) {
            errprintf("_hddid_aggregate_folds(): fallback tc in fold 1 must be finite when bootstrap inputs are absent\n")
            _error(3498)
        }
        if (tc_ref[1, 1] > tc_ref[1, 2]) {
            errprintf("_hddid_aggregate_folds(): fallback tc in fold 1 must satisfy lower <= upper; got (%g, %g)\n",
                tc_ref[1, 1], tc_ref[1, 2])
            _error(3498)
        }
        for (k = 2; k <= K; k++) {
            if (rows(fold_results[k].tc) != 1 | cols(fold_results[k].tc) != 2) {
                errprintf("_hddid_aggregate_folds(): fallback tc in fold %g has shape %g x %g; expected 1 x 2\n",
                    k, rows(fold_results[k].tc), cols(fold_results[k].tc))
                    _error(3498)
            }
            if (hasmissing(fold_results[k].tc)) {
                errprintf("_hddid_aggregate_folds(): fallback tc in fold %g must be finite when bootstrap inputs are absent\n",
                    k)
                _error(3498)
            }
            if (fold_results[k].tc[1, 1] > fold_results[k].tc[1, 2]) {
                errprintf("_hddid_aggregate_folds(): fallback tc in fold %g must satisfy lower <= upper; got (%g, %g)\n",
                    k, fold_results[k].tc[1, 1], fold_results[k].tc[1, 2])
                _error(3498)
            }
            // Fallback tc is the same lower/upper multiplier object that will
            // be published on the aggregate stdg scale, so compare it on its
            // own magnitude rather than under a unit-scale absolute floor.
            tc_scale = max((max(abs(tc_ref)), max(abs(fold_results[k].tc))))
            if (tc_scale <= 0 | tc_scale >= .) {
                tc_scale = 1
            }
            tc_tol = 1e-12 * tc_scale
            if (max(abs(fold_results[k].tc :- tc_ref)) > tc_tol) {
                errprintf("_hddid_aggregate_folds(): fallback tc must agree across folds when bootstrap inputs are absent\n")
                errprintf("_hddid_aggregate_folds(): fold 1 tc=(%g, %g), fold %g tc=(%g, %g)\n",
                    tc_ref[1, 1], tc_ref[1, 2], k,
                    fold_results[k].tc[1, 1], fold_results[k].tc[1, 2])
                _error(3498)
            }
        }
        result.tc = tc_ref
    }
    
    // Pointwise CI for beta and g(z0).
    z_crit = invnormal(1 - alpha / 2)
    result.CIpoint = (result.xdebias - z_crit * result.stdx,
                      result.gdebias - z_crit * result.stdg) \
                     (result.xdebias + z_crit * result.stdx,
                      result.gdebias + z_crit * result.stdg)
    if (hasmissing(result.CIpoint)) {
        errprintf("_hddid_aggregate_folds(): CIpoint must be finite after combining debiased estimates with aggregate standard errors\n")
        _error(3498)
    }
    
    // Uniform CI band for g(z0) only.
    result.CIuniform = (result.gdebias + result.tc[1] * result.stdg) \
                       (result.gdebias + result.tc[2] * result.stdg)
    if (hasmissing(result.CIuniform)) {
        errprintf("_hddid_aggregate_folds(): CIuniform must be finite after combining aggregate gdebias/stdg/tc\n")
        _error(3498)
    }
    
    return(result)
}

// _hddid_trim_propensity(pi_hat, lo, hi) returns an n x 1 0/1 indicator
// for observations with propensity scores in [lo, hi].

real colvector _hddid_trim_propensity(real matrix pi_hat_in,
    real scalar lo, real scalar hi)
{
    real colvector pi_hat, pi_finite, valid

    if (rows(pi_hat_in) > 1 & cols(pi_hat_in) > 1) {
        errprintf("_hddid_trim_propensity(): pi_hat must be a vector, got %gx%g matrix\n",
            rows(pi_hat_in), cols(pi_hat_in))
        _error(3498)
    }
    pi_hat = vec(pi_hat_in)

    // Overlap trimming operates on a numeric propensity nuisance. Missing
    // pi_hat is undefined first-stage input, not a legal edge probability.
    if (lo >= hi | lo <= 0 | hi >= 1) {
        errprintf("_hddid_trim_propensity(): require 0 < lo < hi < 1, got lo=%g, hi=%g\n", lo, hi)
        _error(3498)
    }
    if (rows(pi_hat) == 0) {
        errprintf("_hddid_trim_propensity(): empty input\n")
        _error(3200)
    }
    if (hasmissing(pi_hat)) {
        errprintf("_hddid_trim_propensity(): pi_hat contains missing values\n")
        _error(3351)
    }
    pi_finite = select(pi_hat, pi_hat :< .)
    if (rows(pi_finite) > 0 & (min(pi_finite) < 0 | max(pi_finite) > 1)) {
        errprintf("_hddid_trim_propensity(): pi_hat must lie within [0,1]; found range [%g, %g]\n",
            min(pi_finite), max(pi_finite))
        _error(3498)
    }

    valid = ((pi_hat :>= lo) :& (pi_hat :<= hi))

    return(valid)
}

real colvector _hddid_dr_score(
    real matrix dy_in, real matrix treat_in,
    real matrix pi_hat_in, real matrix phi1_hat_in,
    real matrix phi0_hat_in)
{
    real colvector dy, treat, pi_hat, phi1_hat, phi0_hat
    real colvector rho, denom, score
    real scalar n

    if ((rows(dy_in) > 1 & cols(dy_in) > 1) |
        (rows(treat_in) > 1 & cols(treat_in) > 1) |
        (rows(pi_hat_in) > 1 & cols(pi_hat_in) > 1) |
        (rows(phi1_hat_in) > 1 & cols(phi1_hat_in) > 1) |
        (rows(phi0_hat_in) > 1 & cols(phi0_hat_in) > 1)) {
        errprintf("_hddid_dr_score(): all inputs must be vectors\n")
        _error(3498)
    }

    dy = vec(dy_in)
    treat = vec(treat_in)
    pi_hat = vec(pi_hat_in)
    phi1_hat = vec(phi1_hat_in)
    phi0_hat = vec(phi0_hat_in)

    // Basic input contract checks.
    n = rows(dy)
    if (n == 0) {
        errprintf("_hddid_dr_score(): empty input\n")
        _error(3200)
    }
    if (rows(treat) != n | rows(pi_hat) != n |
        rows(phi1_hat) != n |
        rows(phi0_hat) != n) {
        errprintf(
            "_hddid_dr_score(): " +
            "input vectors have different lengths " +
            "(dy=%g, treat=%g, pi_hat=%g, " +
            "phi1_hat=%g, phi0_hat=%g)\n",
            n, rows(treat), rows(pi_hat),
            rows(phi1_hat), rows(phi0_hat))
        _error(3498)
    }

    if (hasmissing(dy) | hasmissing(treat) |
        hasmissing(pi_hat) |
        hasmissing(phi1_hat) |
        hasmissing(phi0_hat)) {
        errprintf(
            "_hddid_dr_score(): " +
            "input vectors contain missing values\n")
        _error(3351)
    }

    if (min(treat) < 0 | max(treat) > 1 |
        any(treat :!= trunc(treat))) {
        errprintf(
            "_hddid_dr_score(): " +
            "treat must be a 0/1 indicator; found range [%g, %g]\n",
            min(treat), max(treat))
        _error(3498)
    }

    if (min(pi_hat) <= 0 | max(pi_hat) >= 1) {
        errprintf(
            "_hddid_dr_score(): " +
            "retained-sample pi_hat must lie strictly in (0,1)\n")
        errprintf(
            "_hddid_dr_score(): " +
            "The command-level retained overlap window for this implementation is [0.01, 0.99], but the helper's mathematical domain is 0 < pi_hat < 1; found range [%g, %g]\n",
            min(pi_hat), max(pi_hat))
        errprintf(
            "_hddid_dr_score(): " +
            "The command-level overlap trim step handles the implementation's [0.01, 0.99] retention policy before this helper is called\n")
        _error(3498)
    }

    denom = pi_hat :* (1 :- pi_hat)

    if (min(denom) < 1e-10) {
        errprintf(
            "{bf:hddid} warning: propensity denominator pi*(1-pi) is near zero (min=%g)\n",
            min(denom))
    }

    rho = (treat :- pi_hat) :/ denom
    if (hasmissing(rho)) {
        errprintf(
            "_hddid_dr_score(): " +
            "computed AIPW weights contain missing/nonfinite values\n")
        _error(3351)
    }

    score = rho :* (dy :- (1 :- pi_hat) :* phi1_hat
                       :- pi_hat :* phi0_hat)
    if (hasmissing(score)) {
        errprintf(
            "_hddid_dr_score(): " +
            "computed AIPW score contains missing/nonfinite values\n")
        _error(3351)
    }

    return(score)
}

real rowvector _hddid_sieve_basis_diagnostics(real matrix zbasis_full)
{
    real matrix ZtZ, ZtZ_inv, Z_scaled
    real rowvector z_scale
    real scalar q_plus_1, n_rows, singular_dirs, rank_val, cond_val, j
    real scalar intercept_level, intercept_scale, intercept_tol, intercept_gap

    n_rows = rows(zbasis_full)
    q_plus_1 = cols(zbasis_full)

    if (n_rows == 0 | q_plus_1 == 0) {
        errprintf("_hddid_sieve_basis_diagnostics(): empty sieve basis matrix\n")
        _error(3200)
    }
    if (hasmissing(zbasis_full)) {
        errprintf("_hddid_sieve_basis_diagnostics(): sieve basis contains missing values\n")
        _error(3351)
    }

    intercept_level = zbasis_full[1, 1]
    intercept_scale = max(abs(zbasis_full[., 1]))
    if (intercept_scale <= 0 | intercept_scale >= .) {
        errprintf("_hddid_sieve_basis_diagnostics(): first column must be a finite nonzero constant intercept carrier\n")
        _error(3498)
    }
    intercept_tol = 1e-12 * intercept_scale
    intercept_gap = max(abs(zbasis_full[., 1] :- intercept_level))
    if (intercept_gap > intercept_tol | intercept_level == 0 | intercept_level >= .) {
        errprintf("_hddid_sieve_basis_diagnostics(): first column must be a finite nonzero constant intercept carrier\n")
        errprintf("_hddid_sieve_basis_diagnostics(): max |z_intercept - c| = %g exceeded tolerance=%g, c=%g\n",
            intercept_gap, intercept_tol, intercept_level)
        _error(3498)
    }

    // Rank and condition diagnostics depend on the column space of the sieve
    // basis, not on arbitrary finite units. Mirror compute_tildex() by
    // normalizing the intercept carrier separately and rescaling the remaining
    // columns before forming Z'Z so diagnostics stay aligned with the actual
    // projection helper.
    Z_scaled = zbasis_full
    Z_scaled[., 1] = zbasis_full[., 1] / intercept_level
    z_scale = J(1, q_plus_1, 1)
    for (j = 2; j <= q_plus_1; j++) {
        z_scale[j] = max(abs(zbasis_full[., j]))
        if (z_scale[j] <= 0 | z_scale[j] >= .) {
            z_scale[j] = 1
        }
        Z_scaled[., j] = zbasis_full[., j] / z_scale[j]
    }

    ZtZ = cross(Z_scaled, Z_scaled)
    if (hasmissing(ZtZ)) {
        errprintf("_hddid_sieve_basis_diagnostics(): sieve Gram matrix must be finite; Z'Z overflowed or became nonfinite\n")
        errprintf("_hddid_sieve_basis_diagnostics(): rescale z()/q() before requesting sieve diagnostics\n")
        _error(3498)
    }
    ZtZ_inv = invsym(ZtZ)
    singular_dirs = diag0cnt(ZtZ_inv)
    cond_val = cond(ZtZ)

    // The paper/R projection contract only requires a usable inverse for Z'Z.
    // Record the condition number for diagnostics, but do not down-rank a
    // finite invertible Gram matrix solely because cond(Z'Z) is large.
    if (cond_val >= .) {
        singular_dirs = max((singular_dirs, 1))
    }
    rank_val = q_plus_1 - singular_dirs

    return((rank_val, q_plus_1, n_rows, singular_dirs, cond_val))
}

// _hddid_compute_tildex(X, zbasis_full) returns the projection residual
// X - Z (Z'Z)^{-1} Z'X, where zbasis_full contains a nonzero constant
// intercept carrier in column 1.

real matrix _hddid_compute_tildex(real matrix X, real matrix zbasis_full)
{
    real matrix ZtZ, proj_moments, coef, tildex, fit_scaled
    real matrix X_scaled, Z_scaled
    real rowvector x_scale, z_scale
    real scalar cond_val, proj_scale, solve_gap, solve_tol, j
    real scalar intercept_level, intercept_scale, intercept_tol, intercept_gap

    if (rows(X) != rows(zbasis_full)) {
        errprintf("_hddid_compute_tildex(): X and zbasis_full row count mismatch (X=%g rows, zbasis_full=%g rows)\n",
            rows(X), rows(zbasis_full))
        _error(3200)
    }

    if (hasmissing(X)) {
        errprintf("_hddid_compute_tildex(): X contains missing values\n")
        _error(3351)
    }
    if (hasmissing(zbasis_full)) {
        errprintf("_hddid_compute_tildex(): zbasis_full contains missing values\n")
        _error(3351)
    }
    if (cols(zbasis_full) < 1) {
        errprintf("_hddid_compute_tildex(): zbasis_full must contain at least one column for the intercept basis\n")
        _error(3498)
    }

    intercept_level = zbasis_full[1, 1]
    intercept_scale = max(abs(zbasis_full[., 1]))
    if (intercept_scale <= 0 | intercept_scale >= .) {
        errprintf("_hddid_compute_tildex(): first column of zbasis_full must be a finite nonzero constant intercept carrier\n")
        _error(3498)
    }
    intercept_tol = 1e-12 * intercept_scale
    intercept_gap = max(abs(zbasis_full[., 1] :- intercept_level))
    if (intercept_gap > intercept_tol | intercept_level == 0 | intercept_level >= .) {
        errprintf("_hddid_compute_tildex(): first column of zbasis_full must be a finite nonzero constant intercept carrier\n")
        errprintf("_hddid_compute_tildex(): max |z_intercept - c| = %g exceeded tolerance=%g, c=%g\n",
            intercept_gap, intercept_tol, intercept_level)
        _error(3498)
    }

    if (rows(X) < cols(zbasis_full)) {
        errprintf("_hddid_compute_tildex(): n=%g < sieve basis columns q+1=%g, Z'Z is singular\n",
            rows(X), cols(zbasis_full))
        errprintf("_hddid_compute_tildex(): reduce q or provide a richer Z support before projection\n")
        _error(3498)
    }

    // The paper's projection residual depends on the column space of Z, not on
    // the raw measurement scale of each finite column. Rescale X and the
    // non-intercept sieve columns before forming Z'Z and Z'X so finite designs
    // do not spuriously overflow in the moment products.
    X_scaled = X
    x_scale = J(1, cols(X), 1)
    for (j = 1; j <= cols(X); j++) {
        x_scale[j] = max(abs(X[., j]))
        if (x_scale[j] <= 0 | x_scale[j] >= .) {
            x_scale[j] = 1
        }
        X_scaled[., j] = X[., j] / x_scale[j]
    }

    Z_scaled = zbasis_full
    Z_scaled[., 1] = zbasis_full[., 1] / intercept_level
    z_scale = J(1, cols(zbasis_full), 1)
    for (j = 2; j <= cols(zbasis_full); j++) {
        z_scale[j] = max(abs(zbasis_full[., j]))
        if (z_scale[j] <= 0 | z_scale[j] >= .) {
            z_scale[j] = 1
        }
        Z_scaled[., j] = zbasis_full[., j] / z_scale[j]
    }

    ZtZ = cross(Z_scaled, Z_scaled)
    if (hasmissing(ZtZ)) {
        errprintf("_hddid_compute_tildex(): sieve Gram matrix must be finite; Z'Z overflowed or became nonfinite\n")
        errprintf("_hddid_compute_tildex(): rescale z()/q() before projecting onto the sieve span\n")
        _error(3498)
    }

    cond_val = cond(ZtZ)
    if (cond_val >= .) {
        errprintf("_hddid_compute_tildex(): sieve Gram matrix Z'Z is singular, projection is undefined\n")
        errprintf("_hddid_compute_tildex(): reduce q or check Z for perfect collinearity\n")
        _error(3498)
    }

    proj_moments = cross(Z_scaled, X_scaled)
    if (hasmissing(proj_moments)) {
        errprintf("_hddid_compute_tildex(): Z'X must remain finite; projection moments overflowed or became nonfinite\n")
        errprintf("_hddid_compute_tildex(): rescale x()/z() or reduce q before projecting onto the sieve span\n")
        _error(3498)
    }

    // Solve the least-squares projection in the design space directly. This
    // avoids squaring the sieve condition number through an explicit Z'Z
    // inverse while still allowing the direct normal-equation residual below
    // to decide whether the returned projection is numerically usable.
    coef = qrsolve(Z_scaled, X_scaled)
    if (hasmissing(coef)) {
        errprintf("_hddid_compute_tildex(): projection coefficients must be finite; solve(Z'Z, Z'X) produced missing/nonfinite values\n")
        errprintf("_hddid_compute_tildex(): the sieve projection is numerically unstable at the current scale\n")
        _error(3498)
    }
    // A finite generalized solve is still unusable if it cannot reproduce the
    // scaled normal equations to numerical tolerance. In that case the
    // resulting "residual" need not be approximately orthogonal to the sieve
    // span and can inject large spurious signal back into beta debiasing.
    // This is a residualization contract for the current scaled problem, so
    // compare on the right-hand side's own scale. A unit floor would let a
    // same-order error pass whenever Z'X is tiny but nonzero, even though the
    // returned tildex is no longer approximately orthogonal to the sieve span.
    proj_scale = max(abs(proj_moments))
    if (proj_scale <= 0 | proj_scale >= .) {
        proj_scale = 1
    }
    solve_gap = max(abs(ZtZ * coef - proj_moments))
    solve_tol = 1e-9 * proj_scale * cols(Z_scaled)
    if (solve_gap > solve_tol) {
        errprintf("_hddid_compute_tildex(): projection solve is numerically unstable; max |Z'Z*coef - Z'X|=%g exceeded tolerance=%g\n",
            solve_gap, solve_tol)
        errprintf("_hddid_compute_tildex(): the sieve Gram matrix is too ill-conditioned for a reliable projection at the current fold scale\n")
        _error(3498)
    }

    fit_scaled = Z_scaled * coef
    tildex = X_scaled - fit_scaled
    tildex = tildex :* (J(rows(X), 1, 1) * x_scale)
    if (hasmissing(tildex)) {
        errprintf("_hddid_compute_tildex(): projected X residuals must be finite; computed tildex contains missing/nonfinite values\n")
        errprintf("_hddid_compute_tildex(): rescale x()/z() or reduce q before projecting onto the sieve span\n")
        _error(3498)
    }

    return(tildex)
}

string scalar _hddid_absorbed_xvars(real matrix tildex, real matrix X,
    string scalar xvarlist, | real scalar tol)
{
    real rowvector absmax, xabsmax, absorb_tol
    string rowvector xvars, absorbed

    if (args() < 4) {
        tol = 1024 * epsilon(1)
    }
    if (tol <= 0 | tol >= .) {
        errprintf("_hddid_absorbed_xvars(): tol must be a finite positive scalar; got %g\n",
            tol)
        _error(3498)
    }
    if (rows(tildex) != rows(X) | cols(tildex) != cols(X)) {
        errprintf("_hddid_absorbed_xvars(): tildex has shape %g x %g but X has shape %g x %g\n",
            rows(tildex), cols(tildex), rows(X), cols(X))
        _error(3498)
    }
    if (hasmissing(tildex)) {
        errprintf("_hddid_absorbed_xvars(): tildex must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(X)) {
        errprintf("_hddid_absorbed_xvars(): X must be finite; found missing/nonfinite values\n")
        _error(3498)
    }

    xvars = tokens(xvarlist)
    if (cols(xvars) != cols(X)) {
        errprintf("_hddid_absorbed_xvars(): xvarlist has %g names; expected %g to match cols(X)\n",
            cols(xvars), cols(X))
        _error(3498)
    }

    absmax = colmax(abs(tildex))
    xabsmax = colmax(abs(X))
    absorb_tol = tol :* xabsmax
    // Exact sieve aliases often survive the projection step only as
    // machine-epsilon residue relative to the raw X column scale itself. Do
    // not impose a unit floor here: a global rescaling of X should not turn a
    // tiny but still positive-variance tildex column into an "absorbed" one.
    absorbed = select(xvars, absmax :<= absorb_tol)
    if (cols(absorbed) == 0) {
        return("")
    }
    return(invtokens(absorbed))
}

real matrix _hddid_single_x_precision(real matrix tildex)
{
    real scalar n, sigma_scaled, precision
    real scalar scale, inv_scale
    real colvector tildex_scaled

    n = rows(tildex)
    if (n < 1 | cols(tildex) != 1) {
        errprintf("_hddid_single_x_precision(): tildex must be n x 1 with n >= 1; got %g x %g\n",
            n, cols(tildex))
        _error(3200)
    }
    if (hasmissing(tildex)) {
        errprintf("_hddid_single_x_precision(): tildex must be finite; found missing/nonfinite values\n")
        _error(3351)
    }

    // The p=1 shortcut targets Sigma_tildeX^{-1} with
    // Sigma_tildeX = n^{-1} sum_i tildeX_i^2 from the paper's debiasing step.
    // The helper is called on an already-materialized retained tildex object,
    // so the scalar contract is just a finite positive empirical second
    // moment. Rescale before the quadratic form so a finite moment does not
    // overflow just because the raw squares are accumulated first.
    scale = max(abs(tildex))
    if (scale <= 0 | scale >= .) {
        errprintf("_hddid_single_x_precision(): scalar covariance must be strictly positive; got 0\n")
        _error(3498)
    }
    tildex_scaled = tildex :/ scale
    sigma_scaled = quadcross(tildex_scaled, tildex_scaled) / n

    if (sigma_scaled <= 0 | sigma_scaled >= .) {
        errprintf("_hddid_single_x_precision(): scaled scalar covariance must be strictly positive; got %g\n",
            sigma_scaled)
        _error(3498)
    }

    inv_scale = 1 / scale
    // Multiply by 1/sigma_scaled before the second 1/scale so a
    // representable positive subnormal inverse is not flushed to zero by
    // rounding (1/scale)^2 first.
    precision = ((1 / sigma_scaled) * inv_scale) / scale
    if (precision <= 0 | precision >= .) {
        errprintf("_hddid_single_x_precision(): scalar precision 1/sigma must be finite; scaled sigma=%g, scale=%g\n",
            sigma_scaled, scale)
        _error(3498)
    }

    return(precision)
}

real scalar _hddid_beta_influence_entry(
    real scalar adjy_i,
    real rowvector tildex_row,
    real matrix covinv,
    real scalar j)
{
    real scalar p, k, max_log_term, scaled_sum, out_log, log_term
    real scalar term_val, direct_sum, direct_comp, direct_next
    real scalar keep_n, finite_term_n, map_core, map_term, score_term
    real scalar score_piece, rescue_tol, map_ok, score_ok
    real scalar top_gap_tol, top_scaled_sum
    real colvector term_logs, term_signs, keep_idx, term_vals, scaled_terms
    real colvector top_scaled_terms
    real colvector active_logs, active_signs, top_idx
    real rowvector score_row

    p = cols(tildex_row)
    if (adjy_i == 0) {
        return(0)
    }

    score_row = adjy_i * tildex_row
    term_logs = J(p, 1, .)
    term_signs = J(p, 1, 0)
    term_vals = J(p, 1, .)
    for (k = 1; k <= p; k++) {
        if (tildex_row[k] == 0 | covinv[k,j] == 0) {
            continue
        }
        if (score_row[k] < . & ///
            !(score_row[k] == 0 & adjy_i != 0 & tildex_row[k] != 0)) {
            // When epsilon_i * tildeX_ik itself is representable, sum the
            // paper/R score-grouped terms first. This avoids publishing a
            // fake huge remainder that only comes from rounding each triple
            // product on a different path before cancellation.
            score_piece = score_row[k] * covinv[k,j]
            if (score_piece >= . | ///
                (score_piece == 0 & score_row[k] != 0 & covinv[k,j] != 0)) {
                score_piece = covinv[k,j] * score_row[k]
            }
            if (score_piece < . & ///
                !(score_piece == 0 & score_row[k] != 0 & covinv[k,j] != 0)) {
                term_vals[k] = score_piece
            }
            term_logs[k] = ln(abs(score_row[k])) + ln(abs(covinv[k,j]))
            term_signs[k] = sign(score_row[k]) * sign(covinv[k,j])
            continue
        }
        term_val = adjy_i * (tildex_row[k] * covinv[k,j])
        if (term_val >= . | ///
            (term_val == 0 & adjy_i != 0 & tildex_row[k] != 0 & covinv[k,j] != 0)) {
            term_val = (adjy_i * covinv[k,j]) * tildex_row[k]
        }
        if (term_val >= . | ///
            (term_val == 0 & adjy_i != 0 & tildex_row[k] != 0 & covinv[k,j] != 0)) {
            term_val = (adjy_i * tildex_row[k]) * covinv[k,j]
        }
        if (term_val < . & ///
            !(term_val == 0 & adjy_i != 0 & tildex_row[k] != 0 & covinv[k,j] != 0)) {
            term_vals[k] = term_val
        }
        term_logs[k] = ln(abs(adjy_i)) + ln(abs(tildex_row[k])) + ///
            ln(abs(covinv[k,j]))
        term_signs[k] = sign(adjy_i) * sign(tildex_row[k]) * ///
            sign(covinv[k,j])
    }

    keep_idx = (term_signs :!= 0)
    keep_n = sum(keep_idx)
    if (keep_n == 0) {
        return(0)
    }

    finite_term_n = sum((term_vals :< .) :& keep_idx)
    if (finite_term_n == keep_n) {
        // When every individual beta-score term is itself representable, sum
        // them with Neumaier compensation before falling back to the broader
        // log-scale path. This preserves a finite tiny residual when huge
        // opposite-sign terms cancel exactly in floating point.
        direct_sum = 0
        direct_comp = 0
        for (k = 1; k <= p; k++) {
            if (keep_idx[k] == 0) {
                continue
            }
            direct_next = direct_sum + term_vals[k]
            if (direct_next >= .) {
                direct_sum = .
                break
            }
            if (abs(direct_sum) >= abs(term_vals[k])) {
                direct_comp = direct_comp + ///
                    ((direct_sum - direct_next) + term_vals[k])
            }
            else {
                direct_comp = direct_comp + ///
                    ((term_vals[k] - direct_next) + direct_sum)
            }
            if (direct_comp >= .) {
                direct_sum = .
                break
            }
            direct_sum = direct_next
        }
        if (direct_sum < .) {
            direct_sum = direct_sum + direct_comp
            if (direct_sum < .) {
                return(direct_sum)
            }
        }
    }

    // Sum the signed adjy_i * tildex_ik * covinv_kj terms on a log scale so
    // exact cancellations survive even when one associative grouping leaves a
    // tiny spurious remainder in machine arithmetic.
    active_logs = select(term_logs, keep_idx)
    active_signs = select(term_signs, keep_idx)
    while (rows(active_logs) > 0) {
        max_log_term = max(active_logs)
        top_gap_tol = 64 * 2.220446049250313e-16 * ///
            max((1, abs(max_log_term)))
        top_idx = abs(active_logs :- max_log_term) :<= top_gap_tol
        top_scaled_terms = select(active_signs, top_idx) :* ///
            exp(select(active_logs, top_idx) :- max_log_term)
        top_scaled_sum = 0
        direct_comp = 0
        for (k = 1; k <= rows(top_scaled_terms); k++) {
            direct_next = top_scaled_sum + top_scaled_terms[k]
            if (abs(top_scaled_sum) >= abs(top_scaled_terms[k])) {
                direct_comp = direct_comp + ///
                    ((top_scaled_sum - direct_next) + top_scaled_terms[k])
            }
            else {
                direct_comp = direct_comp + ///
                    ((top_scaled_terms[k] - direct_next) + top_scaled_sum)
            }
            top_scaled_sum = direct_next
        }
        top_scaled_sum = top_scaled_sum + direct_comp
        if (top_scaled_sum == 0) {
            if (sum(top_idx) == rows(active_logs)) {
                break
            }
            active_logs = select(active_logs, !top_idx)
            active_signs = select(active_signs, !top_idx)
            continue
        }
        break
    }
    scaled_terms = active_signs :* exp(active_logs :- max_log_term)
    scaled_sum = 0
    direct_comp = 0
    for (k = 1; k <= rows(scaled_terms); k++) {
        direct_next = scaled_sum + scaled_terms[k]
        if (abs(scaled_sum) >= abs(scaled_terms[k])) {
            direct_comp = direct_comp + ///
                ((scaled_sum - direct_next) + scaled_terms[k])
        }
        else {
            direct_comp = direct_comp + ///
                ((scaled_terms[k] - direct_next) + scaled_sum)
        }
        scaled_sum = direct_next
    }
    scaled_sum = scaled_sum + direct_comp
    if (scaled_sum == 0) {
        // If some termwise products overflowed or underflowed to zero, a
        // zero log-scale sum can still be a false cancellation artifact. The
        // paper/R contract is the associative rowwise map adjy_i *
        // (tildex_i * covinv[,j]), so retry that coordinate-level
        // contraction before publishing an exact zero.
        if (finite_term_n < keep_n) {
            map_core = tildex_row * covinv[,j]
            map_term = adjy_i * map_core
            if (map_term < . & ///
                !(map_term == 0 & adjy_i != 0 & map_core != 0)) {
                return(map_term)
            }

            score_row = adjy_i * tildex_row
            score_term = score_row * covinv[,j]
            if (score_term < . & ///
                !(score_term == 0 & adjy_i != 0 & max(abs(score_row)) > 0 & ///
                max(abs(covinv[,j])) > 0)) {
                return(score_term)
            }
        }
        return(0)
    }

    out_log = max_log_term + ln(abs(scaled_sum))
    log_term = sign(scaled_sum) * exp(out_log)
    if (finite_term_n < keep_n) {
        map_core = tildex_row * covinv[,j]
        map_term = adjy_i * map_core
        score_row = adjy_i * tildex_row
        score_term = score_row * covinv[,j]
        map_ok = (map_term < . & ///
            !(map_term == 0 & adjy_i != 0 & map_core != 0))
        score_ok = (score_term < . & ///
            !(score_term == 0 & adjy_i != 0 & max(abs(score_row)) > 0 & ///
            max(abs(covinv[,j])) > 0))
        rescue_tol = 1e-12 * max((1, abs(log_term)))
        if (map_ok) {
            rescue_tol = max((rescue_tol, 1e-12 * abs(map_term)))
        }
        if (score_ok) {
            rescue_tol = max((rescue_tol, 1e-12 * abs(score_term)))
        }

        if (score_ok & !map_ok & abs(score_term) > 0 & ///
            (log_term >= . | abs(log_term - score_term) > rescue_tol)) {
            return(score_term)
        }
        if (map_ok & !score_ok & abs(map_term) > 0 & ///
            (log_term >= . | abs(log_term - map_term) > rescue_tol)) {
            return(map_term)
        }
        if (map_ok & score_ok & max((abs(map_term), abs(score_term))) > 0 & ///
            abs(score_term - map_term) <= rescue_tol & ///
            (log_term >= . | abs(log_term - score_term) > rescue_tol)) {
            return(score_term)
        }
    }
    return(log_term)
}

real rowvector _hddid_stable_beta_row(
    real scalar adjy_i,
    real rowvector tildex_row,
    real matrix covinv)
{
    real scalar p, j
    real rowvector beta_row

    p = cols(tildex_row)
    beta_row = J(1, p, .)
    for (j = 1; j <= p; j++) {
        beta_row[j] = _hddid_beta_influence_entry(adjy_i, tildex_row, ///
            covinv, j)
    }
    return(beta_row)
}

// Debias the parametric component (beta) and estimate its fold-level variance.

struct _hddid_beta_result scalar _hddid_debias_beta(
    real matrix tildex, real matrix covinv,
    real matrix adjy_in, real matrix epsilon_in,
    real matrix betahat_p, real scalar n)
{
    struct _hddid_beta_result scalar result
    real matrix beta_if, Vx
    real rowvector beta_row_map, beta_row_score, beta_row_stable, score_row
    real rowvector betahat_row
    real colvector adjy, epsilon
    real scalar p, actual_n, i, j
    real scalar epsilon_alias_gap, epsilon_alias_scale, epsilon_alias_tol
    real scalar beta_coord_tol

    p = cols(tildex)
    actual_n = rows(tildex)
    if (n < 1 | n != trunc(n) | n >= .) {
        errprintf("_hddid_debias_beta(): n must be a finite integer >= 1; got %g\n",
            n)
        _error(3498)
    }
    if (n != actual_n) {
        errprintf("_hddid_debias_beta(): n=%g disagrees with rows(tildex) = %g\n",
            n, actual_n)
        _error(3498)
    }
    if (p < 1) {
        errprintf("_hddid_debias_beta(): tildex must have p >= 1 columns; got p = %g\n",
            p)
        _error(3498)
    }
    if (rows(betahat_p) != 1) {
        errprintf("_hddid_debias_beta(): betahat_p must be a 1 x p rowvector; got %g x %g\n",
            rows(betahat_p), cols(betahat_p))
        _error(3498)
    }
    if (cols(betahat_p) != p) {
        errprintf("_hddid_debias_beta(): betahat_p has %g columns; expected p = cols(tildex) = %g\n",
            cols(betahat_p), p)
        _error(3498)
    }
    if (hasmissing(betahat_p)) {
        errprintf("_hddid_debias_beta(): betahat_p must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    betahat_row = betahat_p
    if (hasmissing(tildex)) {
        errprintf("_hddid_debias_beta(): tildex must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (rows(covinv) != p | cols(covinv) != p) {
        errprintf("_hddid_debias_beta(): covinv must be a %g x %g matrix to match cols(tildex)\n",
            p, p)
        errprintf("_hddid_debias_beta(): rows(covinv)=%g, cols(covinv)=%g\n",
            rows(covinv), cols(covinv))
        _error(3498)
    }
    if (hasmissing(covinv)) {
        errprintf("_hddid_debias_beta(): covinv must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (p == 1 & covinv[1,1] <= 0) {
        errprintf("_hddid_debias_beta(): scalar covinv must be strictly positive when p=1; got %g\n",
            covinv[1,1])
        errprintf("_hddid_debias_beta(): with one residualized regressor, Sigma_tildeX^{-1} = 1 / E_n[tildeX_i^2] must be positive\n")
        _error(3498)
    }
    // For p>1, the paper/R beta step uses the supplied retained-fold operator
    // only as a right-multiplier in tildex * covinv and in the resulting
    // variance sandwich. Once prepare_fold has accepted a finite conformable
    // operator, do not re-impose an original-scale covinv^{-1}
    // reconstruction gate here; highly anisotropic but exact retained-fold
    // operators can be perfectly usable in x-space even when 1/s_min(covinv)
    // overflows. Actual usability is enforced below by the rowwise beta score
    // construction and the final finite-result checks.
    if (cols(adjy_in) != 1) {
        errprintf("_hddid_debias_beta(): adjy must be an n x 1 column vector; got %g x %g\n",
            rows(adjy_in), cols(adjy_in))
        _error(3498)
    }
    adjy = adjy_in
    if (rows(adjy) != actual_n) {
        errprintf("_hddid_debias_beta(): adjy has %g rows; expected rows(tildex) = %g\n",
            rows(adjy), actual_n)
        _error(3498)
    }
    if (hasmissing(adjy)) {
        errprintf("_hddid_debias_beta(): adjy must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (cols(epsilon_in) != 1) {
        errprintf("_hddid_debias_beta(): epsilon must be an n x 1 column vector; got %g x %g\n",
            rows(epsilon_in), cols(epsilon_in))
        _error(3498)
    }
    epsilon = epsilon_in
    if (rows(epsilon) != rows(adjy)) {
        errprintf("_hddid_debias_beta(): epsilon has %g rows; expected rows(adjy) = %g\n",
            rows(epsilon), rows(adjy))
        _error(3498)
    }
    if (hasmissing(epsilon)) {
        errprintf("_hddid_debias_beta(): epsilon must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    epsilon_alias_gap = max(abs(epsilon :- adjy))
    // epsilon is only a legacy alias for adjy, so compare on the residual
    // object's own scale. A unit-scale floor would let a same-order mismatch
    // pass whenever both aliases are tiny but materially different.
    epsilon_alias_scale = max((max(abs(adjy)), max(abs(epsilon))))
    if (epsilon_alias_scale <= 0 | epsilon_alias_scale >= .) {
        epsilon_alias_scale = 1
    }
    epsilon_alias_tol = 1e-12 * epsilon_alias_scale
    if (epsilon_alias_gap > epsilon_alias_tol) {
        errprintf("_hddid_debias_beta(): epsilon is a legacy alias and must match adjy within numerical tolerance\n")
        errprintf("_hddid_debias_beta(): max |epsilon-adjy|=%g exceeded tolerance=%g\n",
            epsilon_alias_gap, epsilon_alias_tol)
        _error(3498)
    }

    // The paper/R beta contract is the exact rowwise score
    // epsilon_i * tildeX_i * Sigma_tildeX^{-1}. Compute each coordinate from
    // the signed product terms themselves on a log scale so overflow- and
    // underflow-prone associative groupings do not leave stale nonzero
    // coordinates after exact cancellation. Keep the older map-first versus
    // score-first fallback only for the rare case where the direct scaled
    // contraction still cannot publish a fully finite row.
    beta_if = J(actual_n, p, 0)
    for (i = 1; i <= actual_n; i++) {
        beta_row_stable = _hddid_stable_beta_row(adjy[i], tildex[i,.], covinv)
        if (!hasmissing(beta_row_stable)) {
            beta_if[i,.] = beta_row_stable
            continue
        }

        beta_row_map = adjy[i] * (tildex[i,.] * covinv)
        score_row = adjy[i] * tildex[i,.]
        if (!hasmissing(score_row)) {
            beta_row_score = score_row * covinv
        }
        else {
            beta_row_score = J(1, p, .)
        }

        if (!hasmissing(beta_row_score) & ///
            (hasmissing(beta_row_map) | ///
            (max(abs(beta_row_map)) == 0 & max(abs(beta_row_score)) > 0))) {
            beta_if[i,.] = beta_row_score
        }
        else if (!hasmissing(beta_row_map)) {
            beta_if[i,.] = beta_row_map
            if (!hasmissing(beta_row_score)) {
                for (j = 1; j <= p; j++) {
                    beta_coord_tol = max((abs(beta_row_map[j]), ///
                        abs(beta_row_score[j])))
                    if (beta_coord_tol <= 0 | beta_coord_tol >= .) {
                        beta_coord_tol = 0
                    }
                    else {
                        beta_coord_tol = 1e-12 * beta_coord_tol
                    }
                    if (abs(beta_row_map[j] - beta_row_score[j]) > beta_coord_tol & ///
                        abs(beta_row_map[j]) < abs(beta_row_score[j])) {
                        beta_if[i,j] = beta_row_score[j]
                    }
                }
            }
        }
        else if (!hasmissing(beta_row_score)) {
            beta_if[i,.] = beta_row_score
        }
        else {
            errprintf("_hddid_debias_beta(): row %g produced no finite associative beta influence contribution\n",
                i)
            errprintf("_hddid_debias_beta(): both adjy_i * (tildeX_i * covinv) and (adjy_i * tildeX_i) * covinv were nonfinite\n")
            _error(3498)
        }
    }

    result.xdebias = betahat_row + colsum(beta_if) / n
    if (hasmissing(result.xdebias)) {
        errprintf("_hddid_debias_beta(): computed xdebias must be finite; found missing/nonfinite values\n")
        _error(3498)
    }

    // Variance uses the same stabilized rowwise beta influence object as the
    // one-step update, so overflow-protected map-first rows and underflow-
    // rescued score-first rows share one contract.
    Vx = cross(beta_if, beta_if) / n                  // p x p
    if (hasmissing(Vx)) {
        errprintf("_hddid_debias_beta(): computed fold variance must be finite; found missing/nonfinite values\n")
        _error(3498)
    }

    // Cov(beta_debias) = V_beta / n for this evaluation fold.
    result.vcovx = Vx / n
    if (hasmissing(result.vcovx)) {
        errprintf("_hddid_debias_beta(): computed vcovx must be finite; found missing/nonfinite values\n")
        _error(3498)
    }

    result.stdx = sqrt(diagonal(result.vcovx))'      // 1 x p
    if (hasmissing(result.stdx)) {
        errprintf("_hddid_debias_beta(): computed stdx must be finite; found missing/nonfinite values\n")
        _error(3498)
    }

    return(result)
}

// Debias the nonparametric component (gamma / g(z0)) and estimate its variance.

struct _hddid_gamma_result scalar _hddid_debias_gamma(
    real matrix xsample, real matrix zbasis_full,
    real matrix MM, real matrix adjy_in,
    real matrix gammahat, real matrix zbasispredict,
    real matrix epsilon_in, real scalar n, real scalar p, real scalar q)
{
    struct _hddid_gamma_result scalar result
    real matrix Sigf, Sigmaf_hat, Sigfinv, Of, Vf, temp, gamma_map, Sigmaf_I
    real matrix zbasis_work, MM_work, Dinv
    real matrix Sigmaf_u, Sigmaf_vt, Vf_z, Vf_x, Vf_u
    real matrix eps_zbasis, eps_xsample, eps_xsample_alt, eps_SigfT, eps_Sigf_if, eps_Sigf_if_alt, z_if, z_if_alt, x_if, x_if_alt
    real colvector basis_scale, biasf, biasf_core, gammahat_col, adjy, epsilon, vf_eval, vf_eval_clip, Sigmaf_sval
    real rowvector Sf
    real scalar actual_n, epsilon_alias_scale, epsilon_alias_tol, epsilon_alias_gap
    real scalar Sigmaf_scale, Sigmaf_tol, Sigmaf_inv_gap, Sigmaf_inv_tol
    real scalar z_if_scale, z_if_alt_scale, z_if_gap
    real scalar eps_xsample_scale, eps_xsample_alt_scale, eps_xsample_gap
    real scalar x_if_scale, x_if_alt_scale, x_if_gap
    real scalar eps_Sigf_if_scale, eps_Sigf_if_alt_scale, eps_Sigf_if_gap
    real scalar vf_scale, vf_rel_tol, vf_abs_tol, vf_tol
    real scalar use_residualized_fallback, j, temp_diag, temp_diag_scale
    real scalar temp_row_scale, temp_tol_diag

    actual_n = rows(xsample)
    if (n < 1 | n != trunc(n) | n >= .) {
        errprintf("_hddid_debias_gamma(): n must be a finite integer >= 1; got %g\n",
            n)
        _error(3498)
    }
    if (q < 1 | q != trunc(q) | q >= .) {
        errprintf("_hddid_debias_gamma(): q must be a finite integer >= 1; got %g\n",
            q)
        _error(3498)
    }
    if (cols(gammahat) != 1) {
        errprintf("_hddid_debias_gamma(): gammahat must be a q x 1 column vector; got %g x %g\n",
            rows(gammahat), cols(gammahat))
        _error(3498)
    }
    if (rows(zbasispredict) < 1) {
        errprintf("_hddid_debias_gamma(): zbasispredict must contain at least one evaluation row; got %g x %g\n",
            rows(zbasispredict), cols(zbasispredict))
        _error(3498)
    }
    if (cols(zbasis_full) != q | rows(MM) != q | rows(gammahat) != q | cols(zbasispredict) != q) {
        errprintf("_hddid_debias_gamma(): q=%g disagrees with sieve-shaped inputs\n", q)
        errprintf("_hddid_debias_gamma(): cols(zbasis_full)=%g, rows(MM)=%g, rows(gammahat)=%g, cols(zbasispredict)=%g\n",
            cols(zbasis_full), rows(MM), rows(gammahat), cols(zbasispredict))
        _error(3498)
    }
    if (cols(xsample) != p | cols(MM) != p) {
        errprintf("_hddid_debias_gamma(): p=%g disagrees with X/M dimensions\n", p)
        errprintf("_hddid_debias_gamma(): cols(xsample)=%g, cols(MM)=%g\n",
            cols(xsample), cols(MM))
        _error(3498)
    }
    if (cols(adjy_in) != 1) {
        errprintf("_hddid_debias_gamma(): adjy must be an n x 1 column vector; got %g x %g\n",
            rows(adjy_in), cols(adjy_in))
        _error(3498)
    }
    if (cols(epsilon_in) != 1) {
        errprintf("_hddid_debias_gamma(): epsilon must be an n x 1 column vector; got %g x %g\n",
            rows(epsilon_in), cols(epsilon_in))
        _error(3498)
    }
    adjy = adjy_in
    epsilon = epsilon_in
    if (rows(zbasis_full) != actual_n | rows(adjy) != actual_n | rows(epsilon) != actual_n) {
        errprintf("_hddid_debias_gamma(): fold inputs must share rows(xsample) = %g\n",
            actual_n)
        errprintf("_hddid_debias_gamma(): rows(zbasis_full)=%g, rows(adjy)=%g, rows(epsilon)=%g\n",
            rows(zbasis_full), rows(adjy), rows(epsilon))
        _error(3498)
    }
    if (n != actual_n) {
        errprintf("_hddid_debias_gamma(): n=%g disagrees with rows(xsample) = %g\n",
            n, actual_n)
        _error(3498)
    }
    if (hasmissing(MM)) {
        errprintf("_hddid_debias_gamma(): MM must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(xsample)) {
        errprintf("_hddid_debias_gamma(): xsample must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(zbasis_full)) {
        errprintf("_hddid_debias_gamma(): zbasis_full must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(adjy)) {
        errprintf("_hddid_debias_gamma(): adjy must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(gammahat)) {
        errprintf("_hddid_debias_gamma(): gammahat must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(zbasispredict)) {
        errprintf("_hddid_debias_gamma(): zbasispredict must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(epsilon)) {
        errprintf("_hddid_debias_gamma(): epsilon must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    epsilon_alias_gap = max(abs(epsilon :- adjy))
    // epsilon is only a legacy alias for adjy, so compare on the residual
    // object's own scale. A unit-scale floor would let a same-order mismatch
    // pass whenever both aliases are tiny but materially different.
    epsilon_alias_scale = max((max(abs(adjy)), max(abs(epsilon))))
    if (epsilon_alias_scale <= 0 | epsilon_alias_scale >= .) {
        epsilon_alias_scale = 1
    }
    epsilon_alias_tol = 1e-12 * epsilon_alias_scale
    if (epsilon_alias_gap > epsilon_alias_tol) {
        errprintf("_hddid_debias_gamma(): epsilon is a legacy alias and must match adjy within numerical tolerance\n")
        errprintf("_hddid_debias_gamma(): max |epsilon-adjy|=%g exceeded tolerance=%g\n",
            epsilon_alias_gap, epsilon_alias_tol)
        _error(3498)
    }
    gammahat_col = gammahat

    // Pure diagonal rescalings of the retained sieve basis leave the paper's
    // g(z) and Vf objects unchanged, but the raw Sigma_f = Sigf * psi matrix
    // and the mapped score products can overflow or underflow before those
    // operator cancellations occur. Normalize each retained sieve coordinate by
    // its own shared basis/MM scale, then reinsert D^{-1} only where the
    // paper's algebra actually requires it.
    basis_scale = J(q, 1, 1)
    for (j = 1; j <= q; j++) {
        basis_scale[j] = max((max(abs(zbasis_full[,j])), max(abs(MM[j,.]))))
        if (basis_scale[j] <= 0 | basis_scale[j] >= .) {
            basis_scale[j] = 1
        }
    }
    Dinv = diag(1 :/ basis_scale)
    zbasis_work = zbasis_full * Dinv
    MM_work = Dinv * MM

    // Sigf = (psi_full - xsample * MM')' -> q x n matrix
    Sigf = (zbasis_work - xsample * MM_work')'
    
    // Must use luinv(), NOT invsym()
    // Sigf*zbasis_noint is generally asymmetric (Lasso sparse estimation)
    Sigmaf_hat = Sigf * zbasis_work
    Sigmaf_scale = max(abs(Sigmaf_hat))
    if (Sigmaf_scale >= .) {
        errprintf("_hddid_debias_gamma(): estimated Sigma_f must be finite; max |Sigma_f| = %g\n",
            Sigmaf_scale)
        errprintf("_hddid_debias_gamma(): Theorem 3 requires a usable fold-level Sigma_f before inversion and Vf estimation\n")
        _error(3498)
    }
    // A tiny raw Sigma_f alone is not a valid fail-close signal. The paper/R
    // contract is the actual Sigma_f^{-1} score map and the resulting
    // gdebias/Vf/stdg objects, so rely on the inverse-map and finite-result
    // checks below rather than a pre-inversion machine-zero heuristic.
    svd(Sigmaf_hat, Sigmaf_u, Sigmaf_sval, Sigmaf_vt)
    // A near-null smallest singular value relative to the matrix's own scale is
    // only fatal when it also destroys the actual Sigma_f^{-1} map. Pure
    // coordinate rescalings in a retained sieve space can overflow cond() or
    // inflate the singular-value spread without changing the debiased object
    // itself. So singularity must be established from the actual inverse map,
    // not from cond() alone.
    Sigmaf_tol = 1e-10 * max(Sigmaf_sval)
    // The paper/R path only requires a usable Sigma_f^{-1}; a pure rescaling
    // of the sieve basis rescales Sigma_f without changing gdebias/stdg, so do
    // not fail solely on a scalar sign diagnostic or singular-value spread if
    // an accurate inverse map still exists for this retained fold.
    Sigfinv = luinv(Sigmaf_hat)
    if (hasmissing(Sigfinv)) {
        // luinv() can spuriously fail on pure coordinate rescalings even when
        // the SVD still shows a finite inverse map. Reconstruct that map and
        // let the explicit inverse-gap check below decide whether the fold is
        // genuinely singular or merely badly scaled.
        if (min(Sigmaf_sval) > 0 & !hasmissing(Sigmaf_sval)) {
            Sigfinv = Sigmaf_vt' * diag(1 :/ Sigmaf_sval) * Sigmaf_u'
        }
    }
    if (hasmissing(Sigfinv)) {
        if (min(Sigmaf_sval) <= Sigmaf_tol & !hasmissing(Sigmaf_sval)) {
            errprintf("_hddid_debias_gamma(): estimated Sigma_f must be numerically invertible; min singular value = %g, tolerance = %g\n",
                min(Sigmaf_sval), Sigmaf_tol)
            errprintf("_hddid_debias_gamma(): luinv()/SVD reconstruction could not form a finite inverse map for this singular fold\n")
            errprintf("_hddid_debias_gamma(): Theorem 3 requires a stably invertible fold-level Sigma_f before gamma debiasing and Vf estimation\n")
            _error(3498)
        }
        errprintf("_hddid_debias_gamma(): estimated Sigma_f inverse must be finite; luinv()/SVD inverse reconstruction failed\n")
        errprintf("_hddid_debias_gamma(): nonparametric debiasing cannot proceed safely in this fold\n")
        _error(3498)
    }
    Sigmaf_I = I(rows(Sigmaf_hat))
    Sigmaf_inv_gap = max((max(abs(Sigmaf_hat * Sigfinv - Sigmaf_I)),
        max(abs(Sigfinv * Sigmaf_hat - Sigmaf_I))))
    Sigmaf_inv_tol = 1e-7
    if (min(Sigmaf_sval) <= Sigmaf_tol & Sigmaf_inv_gap > Sigmaf_inv_tol) {
        errprintf("_hddid_debias_gamma(): estimated Sigma_f must be numerically invertible; min singular value = %g, tolerance = %g\n",
            min(Sigmaf_sval), Sigmaf_tol)
        errprintf("_hddid_debias_gamma(): luinv() inverse accuracy gap = %g exceeded tolerance = %g\n",
            Sigmaf_inv_gap, Sigmaf_inv_tol)
        errprintf("_hddid_debias_gamma(): Theorem 3 requires a stably invertible fold-level Sigma_f before gamma debiasing and Vf estimation\n")
        _error(3498)
    }

    // Debiasing uses the same adjy object as the parametric component.
    biasf_core = Sigfinv * Sigf * adjy        // q x 1 in scaled basis coords
    biasf = Dinv * biasf_core                 // map back to original coords
    result.gammabar = gammahat_col - biasf                      // q x 1 in original coords
    result.gdebias = (zbasispredict * result.gammabar)'         // 1 x qq
    if (hasmissing(result.gdebias)) {
        errprintf("_hddid_debias_gamma(): computed gdebias must be finite; found missing/nonfinite values\n")
        _error(3498)
    }

    // Match the paper's sample analogue for Omega_f and the R reference path:
    // E_n[e_i^2 psi_i psi_i'] - M E_n[e_i^2 X_i X_i'] M'. Accumulate the
    // sandwich after applying the Sigma_f^{-1} map so a tiny but finite
    // inverse can downscale extreme e_i * psi_i or e_i * X_i products before
    // the quadratic form is formed.
    gamma_map = Dinv * Sigfinv * n
    // Row scaling by adjy distributes over the mapped q-dimensional score
    // directions. Apply the shrink maps before adjy so raw adjy:*X or
    // adjy:*psi products do not overflow into Mata missings that cross()
    // would then silently drop from the Omega_f quadratic forms. For the
    // x-side term, however, the inner map M' * A' can itself underflow to
    // zero before the large X rows restore scale, even though the
    // mathematically equivalent regrouping (X*M')*A' stays finite. As on the
    // z-side and fallback paths, compare both finite groupings and rescue the
    // regrouped/R-style score object whenever the map-first path has either
    // materially drifted or clearly collapsed at machine precision.
    eps_zbasis = zbasis_work * gamma_map'
    eps_xsample = xsample * (MM_work' * gamma_map')
    eps_xsample_alt = (xsample * MM_work') * gamma_map'
    eps_xsample_scale = max(abs(eps_xsample))
    eps_xsample_alt_scale = max(abs(eps_xsample_alt))
    eps_xsample_gap = max(abs(eps_xsample - eps_xsample_alt))
    eps_xsample_tol_scale = max((epsilon(1), eps_xsample_scale, ///
        eps_xsample_alt_scale))
    if (hasmissing(eps_xsample) & !hasmissing(eps_xsample_alt)) {
        eps_xsample = eps_xsample_alt
    }
    else if (!hasmissing(eps_xsample) & !hasmissing(eps_xsample_alt)) {
        if (eps_xsample_gap > 1e-12 * eps_xsample_tol_scale | ///
            (eps_xsample_scale <= 1e-12 * eps_xsample_tol_scale & ///
            eps_xsample_alt_scale > eps_xsample_scale)) {
            eps_xsample = eps_xsample_alt
        }
    }
    z_if = adjy :* eps_zbasis
    z_if_alt = (adjy :* zbasis_work) * gamma_map'
    z_if_scale = max(abs(z_if))
    z_if_alt_scale = max(abs(z_if_alt))
    z_if_gap = max(abs(z_if - z_if_alt))
    z_if_tol_scale = max((epsilon(1), z_if_scale, z_if_alt_scale))
    if (hasmissing(z_if) & !hasmissing(z_if_alt)) {
        z_if = z_if_alt
    }
    else if (!hasmissing(z_if) & !hasmissing(z_if_alt)) {
        if (z_if_gap > 1e-12 * z_if_tol_scale | ///
            (z_if_scale <= 1e-12 * z_if_tol_scale & ///
            z_if_alt_scale > z_if_scale)) {
            z_if = z_if_alt
        }
    }
    x_if = adjy :* eps_xsample
    x_if_alt = ((adjy :* xsample) * MM_work') * gamma_map'
    x_if_scale = max(abs(x_if))
    x_if_alt_scale = max(abs(x_if_alt))
    x_if_gap = max(abs(x_if - x_if_alt))
    x_if_tol_scale = max((epsilon(1), x_if_scale, x_if_alt_scale))
    if (hasmissing(x_if) & !hasmissing(x_if_alt)) {
        x_if = x_if_alt
    }
    else if (!hasmissing(x_if) & !hasmissing(x_if_alt)) {
        // The paper/R contract is written on the row-scaled x-side score
        // object (e_i X_i) M' Sigma_f^{-1}, so judge material drift on that
        // actual score scale instead of the pre-adjy mapped carrier.
        if (x_if_gap > 1e-12 * x_if_tol_scale | ///
            (x_if_scale <= 1e-12 * x_if_tol_scale & ///
            x_if_alt_scale > x_if_scale)) {
            x_if = x_if_alt
        }
    }
    
    // Vf = A * Omega_f * A' with A = Sigma_f^{-1} * n. The paper
    // (Section 4) defines Omega_f = E_n[e^2 psi psi'] - M E_n[e^2 XX'] M'
    // (the decomposed form), which the R reference also uses as its primary
    // path. Under conditional homoskedasticity both forms coincide; under
    // heteroskedasticity the decomposed form matches the stated theorem.
    Vf = (cross(z_if, z_if) - cross(x_if, x_if)) / n
    if (hasmissing(Vf)) {
        errprintf("_hddid_debias_gamma(): computed Vf must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    // The population object is symmetric PSD, but the plug-in sample analogue
    // only needs to keep the requested pointwise psi(z)'Vf psi(z) quantities
    // well-defined. Symmetrize the matrix before checking those rowwise
    // quadratic forms. Use Vf's own scale, but also keep a tiny absolute
    // machine floor so a fold whose theoretical Vf collapses to zero does not
    // fail closed on a roundoff-sized negative value such as -O(eps()^2).
    Vf = 0.5 * (Vf + Vf')
    vf_scale = max(abs(Vf))
    vf_rel_tol = 1e-10 * vf_scale
    vf_abs_tol = 16 * epsilon(1)^2
    vf_tol = max((vf_rel_tol, vf_abs_tol))
    Sf = J(1, rows(zbasispredict), 0)
    for (j = 1; j <= rows(zbasispredict); j++) {
        temp = zbasispredict[j,.]
        temp_row_scale = max(abs(temp))
        if (temp_row_scale > 0 & temp_row_scale < .) {
            temp = temp / temp_row_scale
            temp_diag = (temp * Vf * temp')
            temp_diag_scale = abs(temp) * abs(Vf) * abs(temp)'
            temp_tol_diag = max((vf_abs_tol, 1e-10 * temp_diag_scale))
            if (temp_diag < 0 & temp_diag >= -temp_tol_diag) {
                temp_diag = 0
            }
            if (temp_diag < 0 | temp_diag >= .) {
                Sf[j] = .
            }
            else {
                Sf[j] = temp_row_scale * sqrt(temp_diag) / sqrt(n)
            }
        }
    }
    use_residualized_fallback = hasmissing(Sf)
    if (use_residualized_fallback) {
        // Match the hddid-r safeguard: when the requested pointwise variance
        // becomes undefined under the paper-formula Vf, replace it with the
        // residualized-score covariance built from Sigf itself. As on the
        // main z-side path, compare the two finite regroupings and rescue the
        // R-style score object whenever the map-first fallback path has
        // materially drifted, not only when it has collapsed to zero scale.
        eps_Sigf_if = adjy :* (Sigf' * gamma_map')
        eps_SigfT = adjy :* Sigf'
        eps_Sigf_if_alt = eps_SigfT * gamma_map'
        eps_Sigf_if_scale = max(abs(eps_Sigf_if))
        eps_Sigf_if_alt_scale = max(abs(eps_Sigf_if_alt))
        eps_Sigf_if_gap = max(abs(eps_Sigf_if - eps_Sigf_if_alt))
        eps_Sigf_if_tol_scale = max((epsilon(1), eps_Sigf_if_scale, ///
            eps_Sigf_if_alt_scale))
        if (hasmissing(eps_Sigf_if) & !hasmissing(eps_Sigf_if_alt)) {
            eps_Sigf_if = eps_Sigf_if_alt
        }
        else if (!hasmissing(eps_Sigf_if) & !hasmissing(eps_Sigf_if_alt)) {
            if (eps_Sigf_if_gap > 1e-12 * eps_Sigf_if_tol_scale | ///
                (eps_Sigf_if_scale <= 1e-12 * eps_Sigf_if_tol_scale & ///
                eps_Sigf_if_alt_scale > eps_Sigf_if_scale)) {
                eps_Sigf_if = eps_Sigf_if_alt
            }
        }
        Vf = cross(eps_Sigf_if, eps_Sigf_if) / n
        if (hasmissing(Vf)) {
            errprintf("_hddid_debias_gamma(): residualized-Sigf fallback Vf must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        Vf = 0.5 * (Vf + Vf')
        vf_scale = max(abs(Vf))
        vf_rel_tol = 1e-10 * vf_scale
        vf_abs_tol = 16 * epsilon(1)^2
        vf_tol = max((vf_rel_tol, vf_abs_tol))
        vf_eval = symeigenvalues(Vf)
        if (min(vf_eval) < -vf_tol) {
            errprintf("_hddid_debias_gamma(): residualized-Sigf fallback Vf must be positive semidefinite; min eigenvalue = %g, tolerance = %g\n",
                min(vf_eval), vf_tol)
            _error(3498)
        }
        // Recompute the active pointwise SEs on the fallback carrier.
        Sf = J(1, rows(zbasispredict), 0)
        for (j = 1; j <= rows(zbasispredict); j++) {
            temp = zbasispredict[j,.]
            temp_row_scale = max(abs(temp))
            if (temp_row_scale > 0 & temp_row_scale < .) {
                temp = temp / temp_row_scale
                temp_diag = (temp * Vf * temp')
                temp_diag_scale = abs(temp) * abs(Vf) * abs(temp)'
                temp_tol_diag = max((vf_abs_tol, 1e-10 * temp_diag_scale))
                if (temp_diag < 0 & temp_diag >= -temp_tol_diag) {
                    temp_diag = 0
                }
                if (temp_diag < 0 | temp_diag >= .) {
                    Sf[j] = .
                }
                else {
                    Sf[j] = temp_row_scale * sqrt(temp_diag) / sqrt(n)
                }
            }
        }
    }
    if (hasmissing(Sf)) {
        errprintf("_hddid_debias_gamma(): computed stdg remained undefined after the active Vf contract; negative pointwise variance survived tolerance clipping\n")
        _error(3498)
    }
    result.nan_fallback = use_residualized_fallback
    if (use_residualized_fallback) {
        result.stdg = J(rows(zbasispredict), rows(zbasispredict), .)
        for (j = 1; j <= rows(zbasispredict); j++) {
            result.stdg[j,j] = Sf[j]
        }
    }
    else {
        result.stdg = Sf
    }
    result.Vf = Vf
    
    return(result)
}

// Helper: R-style "matrix(..., byrow=TRUE)" recycling.

real matrix _hddid_matrix_byrow(real rowvector vec,
    real scalar nrow, real scalar ncol)
{
    real matrix result
    real scalar total, vec_len, i, r, c

    if (cols(vec) < 1) {
        errprintf("_hddid_matrix_byrow(): vec must contain at least one element\n")
        _error(3498)
    }
    if (nrow < 0 | nrow != trunc(nrow) | nrow >= .) {
        errprintf("_hddid_matrix_byrow(): nrow must be a finite nonnegative integer, got %g\n",
            nrow)
        _error(3498)
    }
    if (ncol < 0 | ncol != trunc(ncol) | ncol >= .) {
        errprintf("_hddid_matrix_byrow(): ncol must be a finite nonnegative integer, got %g\n",
            ncol)
        _error(3498)
    }
    
    total = nrow * ncol
    vec_len = cols(vec)
    result = J(nrow, ncol, .)
    
    for (i = 1; i <= total; i++) {
        r = ceil(i / ncol)
        c = mod(i - 1, ncol) + 1
        result[r, c] = vec[mod(i - 1, vec_len) + 1]
    }
    
    return(result)
}

real scalar _hddid_quantile_type7_sorted(real colvector sorted_vals, real scalar prob)
{
    real scalar n, h, j, g

    n = rows(sorted_vals)
    if (n < 1) {
        errprintf("_hddid_quantile_type7_sorted(): sorted_vals must contain at least one finite draw\n")
        _error(3498)
    }
    if (prob < 0 | prob > 1 | prob >= .) {
        errprintf("_hddid_quantile_type7_sorted(): prob must lie in [0,1], got %g\n",
            prob)
        _error(3498)
    }
    if (hasmissing(sorted_vals)) {
        errprintf("_hddid_quantile_type7_sorted(): sorted_vals must be finite; found missing/nonfinite draw(s)\n")
        _error(3498)
    }
    if (n > 1 && any(sorted_vals[|2 \ n|] :< sorted_vals[|1 \ n - 1|])) {
        errprintf("_hddid_quantile_type7_sorted(): sorted_vals must be weakly increasing\n")
        _error(3498)
    }
    if (n == 1) {
        return(sorted_vals[1])
    }

    h = 1 + (n - 1) * prob
    j = floor(h)
    g = h - j

    // R's type-7 rule interpolates whenever 1 < h < n. For n >= 2 and
    // prob in (0,1), h is always at least 1, so only truly out-of-range
    // lower indices should clamp to the first order statistic.
    if (j < 1) {
        return(sorted_vals[1])
    }
    if (j >= n) {
        return(sorted_vals[n])
    }

    return((1 - g) * sorted_vals[j] + g * sorted_vals[j + 1])
}

// Bootstrap critical values for the uniform confidence band.

real rowvector _hddid_bootstrap_tc(
    real matrix Vf, real matrix zbasispredict,
    real matrix Sf, real scalar nan_fallback, real scalar n,
    real scalar alpha, real scalar nboot, real scalar seed)
{
    real matrix U, Vt, Vf_sqrt, bootrand, sfs, tboot, implied_cov, Vf_sym
    real colvector vf_eval, implied_diag, row_sorted
    real rowvector tc, sf_diag, sf_point, sf_implied, q_pair
    real rowvector vf_eval_sym
    real scalar qq, q, i, j, seeded_draw
    real scalar vf_scale, vf_tol, sf_scale, sf_tol
    transmorphic scalar rngstate_before
    
    qq = rows(zbasispredict)
    q = cols(zbasispredict)
    if (qq < 1 | q < 1) {
        errprintf("_hddid_bootstrap_tc(): zbasispredict must have at least one evaluation row and one sieve column; got %g x %g\n",
            qq, q)
        _error(3498)
    }
    if (n < 1 | n != trunc(n) | n >= .) {
        errprintf("_hddid_bootstrap_tc(): n must be a finite integer >= 1, got %g\n",
            n)
        _error(3498)
    }
    if (nboot < 2 | nboot != trunc(nboot) | nboot >= .) {
        errprintf("_hddid_bootstrap_tc(): nboot must be an integer >= 2, got %g\n",
            nboot)
        _error(3498)
    }
    if (alpha <= 0 | alpha >= 1 | alpha >= .) {
        errprintf("_hddid_bootstrap_tc(): alpha must lie strictly in (0,1), got %g\n",
            alpha)
        _error(3498)
    }
    if (seed < .) {
        if (seed != trunc(seed) | seed < -1 | seed > 2147483647) {
            errprintf("_hddid_bootstrap_tc(): seed must be an integer in [0, 2147483647], -1, or missing; got %g\n",
                seed)
            _error(3498)
        }
    }
    if (rows(Vf) != q | cols(Vf) != q) {
        errprintf("_hddid_bootstrap_tc(): Vf must be %g x %g to match cols(zbasispredict); got %g x %g\n",
            q, q, rows(Vf), cols(Vf))
        _error(3498)
    }
    if (hasmissing(zbasispredict)) {
        errprintf("_hddid_bootstrap_tc(): zbasispredict must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(Vf)) {
        errprintf("_hddid_bootstrap_tc(): Vf must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    // Use Vf's own scale so tiny covariance objects still fail closed when
    // asymmetry is same-order relative to the variance matrix itself.
    vf_scale = max(abs(Vf))
    if (vf_scale <= 0 | vf_scale >= .) {
        vf_scale = 1
    }
    vf_tol = 1e-10 * vf_scale
    if (max(abs(Vf :- Vf')) > vf_tol) {
        errprintf("_hddid_bootstrap_tc(): Vf must be symmetric within tolerance %g; max |Vf-Vf'| = %g\n",
            vf_tol, max(abs(Vf :- Vf')))
        _error(3498)
    }
    
    // Step 1: build the bootstrap carrier from the accepted symmetric finite
    // object itself. Match the hddid-r path and use singular values so the
    // bootstrap can proceed on pointwise-finite indefinite Vf carriers.
    Vf_sym = 0.5 :* (Vf + Vf')
    svd(Vf_sym, U, vf_eval_sym, Vt)
    Vf_sqrt = U * diag(sqrt(vf_eval_sym)) * Vt
    
    // Step 2: Construct sfs broadcast matrix
    if (nan_fallback == 0) {
        // Normal path: Sf is 1 x qq, replicate to nboot x qq
        if (rows(Sf) != 1 | cols(Sf) != qq) {
            errprintf("_hddid_bootstrap_tc(): Sf must be 1 x qq with qq=%g when nan_fallback=0; got %g x %g\n",
                qq, rows(Sf), cols(Sf))
            _error(3498)
        }
        sf_point = Sf
    }
    else if (nan_fallback == 1) {
        // Fallback path still needs pointwise standard errors only. The
        // producer writes pointwise SEs on the diagonal and leaves
        // off-diagonals missing, so any finite off-diagonal payload means the
        // caller handed us malformed carrier metadata.
        if (rows(Sf) != qq | cols(Sf) != qq) {
            errprintf("_hddid_bootstrap_tc(): Sf must be qq x qq with qq=%g when nan_fallback=1; got %g x %g\n",
                qq, rows(Sf), cols(Sf))
            _error(3498)
        }
        _hddid_assert_nanfb_stdg_carrier("_hddid_bootstrap_tc(): nan_fallback Sf", Sf)
        sf_diag = diagonal(Sf)'
        sf_point = sf_diag
    }
    else {
        errprintf("_hddid_bootstrap_tc(): nan_fallback must be 0 or 1, got %g\n",
            nan_fallback)
        _error(3498)
    }
    if (hasmissing(sf_point)) {
        errprintf("_hddid_bootstrap_tc(): Sf must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (min(sf_point) < 0) {
        errprintf("_hddid_bootstrap_tc(): Sf must be nonnegative; min entry = %g\n",
            min(sf_point))
        _error(3498)
    }

    implied_cov = zbasispredict * Vf * zbasispredict'
    implied_diag = diagonal(implied_cov)
    for (i = 1; i <= rows(implied_diag); i++) {
        // Propagate the accepted Vf PSD tolerance to each evaluation row's
        // quadratic form psi(z)'Vf psi(z). A matrix-level implied covariance
        // tolerance can become spuriously strict when large basis rows magnify
        // an eigendrift that the helper already accepted in Vf itself.
        sf_tol = vf_tol * quadcross(zbasispredict[i,.]', zbasispredict[i,.]')
        if (implied_diag[i] < 0 & implied_diag[i] >= -sf_tol) {
            implied_diag[i] = 0
        }
    }
    sf_implied = sqrt(implied_diag)' / sqrt(n)
    if (hasmissing(sf_implied)) {
        errprintf("_hddid_bootstrap_tc(): implied pointwise SEs from Vf and zbasispredict must be finite\n")
        _error(3498)
    }
    for (i = 1; i <= qq; i++) {
        // Enforce consistency on each row's own pointwise scale. A large
        // variance row cannot justify accepting a same-order mismatch at a
        // tiny evaluation row.
        sf_scale = max((sf_point[i], sf_implied[i]))
        sf_tol = 1e-6 * sf_scale
        // Studentization is only defined when the pointwise SE is strictly
        // positive. A strictly positive but tiny SE still defines a valid
        // normalized process, whereas an exact zero row would otherwise turn
        // the R path's 0/0 into an invented finite tc here.
        if ((sf_point[i] == 0 & sf_implied[i] > 0) | ///
            (sf_point[i] > 0 & sf_implied[i] == 0)) {
            errprintf("_hddid_bootstrap_tc(): Sf has zero/nonzero pattern inconsistent with Vf and zbasispredict at evaluation row %g\n",
                i)
            errprintf("_hddid_bootstrap_tc(): provided Sf=%g, implied pointwise SE=%g, tolerance=%g\n",
                sf_point[i], sf_implied[i], 0)
            _error(3498)
        }
        if (sf_point[i] == 0 & sf_implied[i] == 0) {
            errprintf("_hddid_bootstrap_tc(): exact zero pointwise SE at evaluation row %g makes the studentized bootstrap law undefined\n",
                i)
            errprintf("_hddid_bootstrap_tc(): Section 4 studentizes by sigma_z, and hddid-r leaves this 0/0 path outside the finite tc contract\n")
            _error(3498)
        }
        if (max((sf_point[i], sf_implied[i])) > 0 & ///
            abs(sf_point[i] - sf_implied[i]) > sf_tol) {
            errprintf("_hddid_bootstrap_tc(): Sf magnitude must match the Vf-implied pointwise SE at evaluation row %g\n",
                i)
            errprintf("_hddid_bootstrap_tc(): provided Sf=%g, implied pointwise SE=%g, tolerance=%g\n",
                sf_point[i], sf_implied[i], sf_tol)
            _error(3498)
        }
    }
    sfs = J(nboot, 1, 1) * sf_point

    // Step 3: A direct helper call with an explicit seed must always reseed
    // locally and then restore the caller's ambient RNG state. Command-level
    // seeded-stream continuation is handled by higher-level callers passing a
    // missing seed down to this helper instead of relying on stale globals.
    seeded_draw = (seed >= 0 & seed < .)
    if (seeded_draw) {
        rngstate_before = rseed()
        rseed(seed)
    }

    // Step 4: Generate random matrix
    bootrand = rnormal(q, nboot, 0, 1)
    if (seeded_draw) {
        rseed(rngstate_before)
    }
    
    // Step 5: Bootstrap statistic
    // tboot = zbasispredict * Vf_sqrt * bootrand / sqrt(n)  -> qq x nboot
    tboot = (zbasispredict * Vf_sqrt * bootrand) / sqrt(n)
    for (i = 1; i <= qq; i++) {
        tboot[i,.] = tboot[i,.] :/ sfs'[i,.]
    }
    
    // Match the R reference implementation's current finite-grid interval
    // object: take type-7 lower/upper quantiles rowwise over the studentized
    // bootstrap draws and then aggregate them as the envelope pair
    // (min_j lower_j, max_j upper_j).
    tc = (., .)
    for (i = 1; i <= qq; i++) {
        row_sorted = sort(tboot[i,.]', 1)
        q_pair = ( ///
            _hddid_quantile_type7_sorted(row_sorted, alpha / 2), ///
            _hddid_quantile_type7_sorted(row_sorted, 1 - alpha / 2))
        if (i == 1) {
            tc = q_pair
        }
        else {
            tc[1, 1] = min((tc[1, 1], q_pair[1, 1]))
            tc[1, 2] = max((tc[1, 2], q_pair[1, 2]))
        }
    }

    return(tc)
}

// ============================================================
// fold_results初始化辅助函数
// ============================================================
// 使用Stata矩阵空间存储折结果（而非Mata external struct），
// 因为cvlasso/lasso2会清除所有Mata状态（函数+结构体+external变量）。
// Stata矩阵在cvlasso执行后仍然存在。
//
// 存储方案：每折k的结果存入以下Stata矩阵：
//   __hddid_fold_xdebias_k  (1×p)
//   __hddid_fold_stdx_k     (1×p)
//   __hddid_fold_vcovx_k    (p×p)
//   __hddid_fold_gdebias_k  (1×qq)
//   __hddid_fold_stdg_k     (1×qq 或 qq×qq)
//   __hddid_fold_Vf_k       (q×q)
//   __hddid_fold_n_valid_k  (1×1 scalar)
//   __hddid_fold_nanfb_k    (1×1)
//   __hddid_fold_tc_k       (1×2)

void _hddid_init_folds(real scalar K)
{
    real scalar i
    string scalar k_str
    if (K < 2 | K != trunc(K) | K >= .) {
        errprintf("_hddid_init_folds(): K must be an integer >= 2, got %g\n", K)
        _error(3498)
    }
    // 初始化每折的tc为(.,.)
    for (i = 1; i <= K; i++) {
        k_str = strofreal(i)
        st_matrix("__hddid_fold_Vf_" + k_str, J(0, 0, .))
        st_numscalar("__hddid_fold_n_valid_" + k_str, .)
        st_matrix("__hddid_fold_tc_" + k_str, (., .))
        st_numscalar("__hddid_fold_nanfb_" + k_str, 0)
    }
}

// --- fold_results存储辅助函数 ---
// 将单折结果存入Stata矩阵空间（survive cvlasso）
void _hddid_store_fold(real scalar k,
    real matrix xdebias, real matrix stdx, real matrix vcovx,
    real matrix gdebias, real matrix stdg,
    real scalar nan_fallback, real rowvector tc,
    | real matrix Vf, real scalar n_valid)
{
    string scalar k_str
    real scalar p, qq
    real scalar tc_scale, tc_tol, i, j

    if (k < 1 | k != trunc(k) | k >= .) {
        errprintf("_hddid_store_fold(): k must be a positive integer fold index; got %g\n",
            k)
        _error(3498)
    }

    if (rows(stdx) != 1) {
        errprintf("_hddid_store_fold(): stdx must be a 1 x p rowvector; got %g x %g\n",
            rows(stdx), cols(stdx))
        _error(3498)
    }

    p = cols(stdx)
    if (rows(xdebias) != 1 | cols(xdebias) != p) {
        errprintf("_hddid_store_fold(): xdebias must be a 1 x %g rowvector; got %g x %g\n",
            p, rows(xdebias), cols(xdebias))
        _error(3498)
    }
    if (hasmissing(xdebias)) {
        errprintf("_hddid_store_fold(): xdebias must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (hasmissing(stdx)) {
        errprintf("_hddid_store_fold(): stdx must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (min(stdx) < 0) {
        errprintf("_hddid_store_fold(): stdx must be nonnegative; min entry = %g\n",
            min(stdx))
        _error(3498)
    }
    if (rows(vcovx) != p | cols(vcovx) != p) {
        errprintf("_hddid_store_fold(): vcovx must be a p x p matrix with p=%g; got %g x %g\n",
            p, rows(vcovx), cols(vcovx))
        _error(3498)
    }
    _hddid_assert_symmetric_psd("_hddid_store_fold(): vcovx", vcovx)
    _hddid_assert_vcovx_stdx(
        "_hddid_store_fold(): vcovx/stdx",
        vcovx, stdx)

    // tc stores the finite bootstrap critical-value envelope from the current
    // _hddid_bootstrap_tc() contract, or a missing placeholder (., .) for
    // intermediate non-last folds.
    if (rows(tc) != 1 | cols(tc) != 2) {
        errprintf("_hddid_store_fold(): tc must be a 1 x 2 rowvector; got %g x %g\n",
            rows(tc), cols(tc))
        _error(3498)
    }
    if (hasmissing(tc)) {
        if (any(tc :< .)) {
            errprintf("_hddid_store_fold(): tc must be fully missing (placeholder) or fully finite; got partial missing values\n")
            _error(3498)
        }
    }
    else {
        if (tc[1, 1] > tc[1, 2]) {
            errprintf("_hddid_store_fold(): tc must satisfy lower <= upper; got (%g, %g)\n",
                tc[1, 1], tc[1, 2])
            _error(3498)
        }
    }

    if (rows(gdebias) != 1) {
        errprintf("_hddid_store_fold(): gdebias must be a 1 x qq rowvector; got %g x %g\n",
            rows(gdebias), cols(gdebias))
        _error(3498)
    }
    qq = cols(gdebias)
    if (hasmissing(gdebias)) {
        errprintf("_hddid_store_fold(): gdebias must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    if (nan_fallback != 0 & nan_fallback != 1) {
        errprintf("_hddid_store_fold(): nan_fallback must be 0 or 1; got %g\n",
            nan_fallback)
        _error(3498)
    }
    if (nan_fallback == 1) {
        if (rows(stdg) != qq | cols(stdg) != qq) {
            errprintf("_hddid_store_fold(): stdg must be %g x %g when nan_fallback=1; got %g x %g\n",
                qq, qq, rows(stdg), cols(stdg))
            _error(3498)
        }
        _hddid_assert_nanfb_stdg_carrier("_hddid_store_fold(): stdg", stdg)
    }
    else {
        if (rows(stdg) != 1 | cols(stdg) != qq) {
            errprintf("_hddid_store_fold(): stdg must be 1 x %g when nan_fallback=0; got %g x %g\n",
                qq, rows(stdg), cols(stdg))
            _error(3498)
        }
        if (hasmissing(stdg)) {
            errprintf("_hddid_store_fold(): stdg must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
    }
    if (nan_fallback == 1) {
        if (hasmissing(diagonal(stdg)')) {
            errprintf("_hddid_store_fold(): stdg diagonal must be finite when nan_fallback=1\n")
            _error(3498)
        }
        if (min(diagonal(stdg)) < 0) {
            errprintf("_hddid_store_fold(): stdg diagonal must be nonnegative when nan_fallback=1; min diagonal entry = %g\n",
                min(diagonal(stdg)))
            _error(3498)
        }
    }
    else if (min(stdg) < 0) {
        errprintf("_hddid_store_fold(): stdg must be nonnegative; min entry = %g\n",
            min(stdg))
        _error(3498)
    }

    if (args() >= 9) {
        // Vf lives in sieve space, not on the z0 evaluation grid. It should
        // therefore be square, while gdebias/stdg stay qq-wide on the grid.
        if ((rows(Vf) > 0 | cols(Vf) > 0) &
            (rows(Vf) != cols(Vf))) {
            errprintf("_hddid_store_fold(): Vf must be square in sieve space; got %g x %g\n",
                rows(Vf), cols(Vf))
            _error(3498)
        }
        if (rows(Vf) > 0 | cols(Vf) > 0) {
            _hddid_assert_symmetric_finite("_hddid_store_fold(): Vf", Vf)
        }
    }

    if (args() >= 10) {
        if (n_valid < 1 | n_valid != trunc(n_valid) | n_valid >= .) {
            errprintf("_hddid_store_fold(): n_valid must be a positive integer sample size; got %g\n",
                n_valid)
            _error(3498)
        }
    }
    k_str = strofreal(k)
    st_matrix("__hddid_fold_xdebias_" + k_str, xdebias)
    st_matrix("__hddid_fold_stdx_" + k_str, stdx)
    st_matrix("__hddid_fold_vcovx_" + k_str, vcovx)
    st_matrix("__hddid_fold_gdebias_" + k_str, gdebias)
    st_matrix("__hddid_fold_stdg_" + k_str, stdg)
    if (args() >= 9) {
        st_matrix("__hddid_fold_Vf_" + k_str, Vf)
    }
    else {
        st_matrix("__hddid_fold_Vf_" + k_str, J(0, 0, .))
    }
    if (args() >= 10) {
        st_numscalar("__hddid_fold_n_valid_" + k_str, n_valid)
    }
    else {
        st_numscalar("__hddid_fold_n_valid_" + k_str, .)
    }
    st_numscalar("__hddid_fold_nanfb_" + k_str, nan_fallback)
    st_matrix("__hddid_fold_tc_" + k_str, tc)
}

// --- K折汇总辅助函数 ---
// 从Stata矩阵空间读取折结果，重建struct vector，调用_hddid_aggregate_folds
// 结果通过_hddid_post_results存入Stata矩阵空間
void _hddid_run_aggregate(real scalar K, real scalar alpha,
    | string scalar zbpred_name, real scalar nboot, real scalar seed,
      real scalar use_active_seed_stream)
{
    struct _hddid_fold_result vector fold_results
    struct _hddid_result scalar final_result
    real scalar k
    string scalar k_str
    real matrix zbasispredict

    // Clear any previous final-state payload before attempting a new aggregate.
    st_matrix("__hddid_final_xdebias", J(0, 0, .))
    st_matrix("__hddid_final_gdebias", J(0, 0, .))
    st_matrix("__hddid_final_stdx", J(0, 0, .))
    st_matrix("__hddid_final_V", J(0, 0, .))
    st_matrix("__hddid_final_stdg", J(0, 0, .))
    st_matrix("__hddid_final_tc", J(0, 0, .))
    st_matrix("__hddid_final_CIpoint", J(0, 0, .))
    st_matrix("__hddid_final_CIuniform", J(0, 0, .))
    st_matrix("__hddid_final_alpha", J(0, 0, .))

    if (K < 2 | K != trunc(K) | K >= .) {
        errprintf("_hddid_run_aggregate(): K must be an integer >= 2; got %g\n",
            K)
        _error(3498)
    }

    fold_results = _hddid_fold_result(K)
    for (k = 1; k <= K; k++) {
        k_str = strofreal(k)
        fold_results[k].xdebias = st_matrix("__hddid_fold_xdebias_" + k_str)
        fold_results[k].stdx = st_matrix("__hddid_fold_stdx_" + k_str)
        fold_results[k].vcovx = st_matrix("__hddid_fold_vcovx_" + k_str)
        fold_results[k].gdebias = st_matrix("__hddid_fold_gdebias_" + k_str)
        fold_results[k].stdg = st_matrix("__hddid_fold_stdg_" + k_str)
        fold_results[k].Vf = st_matrix("__hddid_fold_Vf_" + k_str)
        fold_results[k].n_valid = st_numscalar("__hddid_fold_n_valid_" + k_str)
        fold_results[k].nan_fallback = st_numscalar("__hddid_fold_nanfb_" + k_str)
        fold_results[k].tc = st_matrix("__hddid_fold_tc_" + k_str)
        // [AUDIT TRACE] Print fold-level xdebias for debugging
        printf("[AUDIT] Fold %g: n_valid=%g, xdebias[1]=%9.6f\n",
            k, fold_results[k].n_valid, fold_results[k].xdebias[1])
    }

    if (args() >= 4) {
        zbasispredict = st_matrix(zbpred_name)
        if (args() >= 6) {
            final_result = _hddid_aggregate_folds(
                fold_results, K, alpha, zbasispredict, nboot, seed,
                use_active_seed_stream)
        }
        else if (args() >= 5) {
            final_result = _hddid_aggregate_folds(
                fold_results, K, alpha, zbasispredict, nboot, seed)
        }
        else {
            final_result = _hddid_aggregate_folds(
                fold_results, K, alpha, zbasispredict, nboot)
        }
    }
    else {
        final_result = _hddid_aggregate_folds(fold_results, K, alpha)
    }

    // Store final result to Stata matrix space
    st_matrix("__hddid_final_xdebias", final_result.xdebias)
    st_matrix("__hddid_final_gdebias", final_result.gdebias)
    st_matrix("__hddid_final_stdx", final_result.stdx)
    st_matrix("__hddid_final_V", final_result.V)
    st_matrix("__hddid_final_stdg", final_result.stdg)
    st_matrix("__hddid_final_tc", final_result.tc)
    st_matrix("__hddid_final_CIpoint", final_result.CIpoint)
    st_matrix("__hddid_final_CIuniform", final_result.CIuniform)
    st_matrix("__hddid_final_alpha", (alpha))
}

// --- ereturn結果抽出辅助函数 [Story E4-07] ---
// Stata矩阵空間(__hddid_final_*)から結果をereturn用tempnameへ転送
// _hddid_run_aggregate()が事前にStata矩阵空間へ格納済み
void _hddid_post_results(string scalar b_name, string scalar V_name,
    string scalar xdebias_name, string scalar gdebias_name,
    string scalar stdx_name, string scalar stdg_name,
    string scalar tc_name, string scalar CIpoint_name,
    string scalar CIuniform_name, | real scalar qq_expected)
{
    // Read from Stata matrix space (populated by _hddid_run_aggregate)
    // instead of external struct (which gets destroyed by cvlasso)
    real matrix V_val
    real matrix gdebias_val, stdg_val, CIpoint_val, CIuniform_val, alpha_val
    real rowvector xdebias_val, stdx_val, tc_val
    real matrix ciuniform_oracle, cipoint_oracle
    real scalar qq, v_sym_gap
    real scalar ciuniform_gap, ciuniform_scale, ciuniform_tol
    real scalar ci_point_gap, ci_point_scale, ci_point_tol, z_crit
    real scalar has_param_block, has_nonparam_block
    real scalar tc_sym_gap, tc_sym_scale, tc_sym_tol
    real scalar stdg_absmax, stdg_scale, zero_stdg_tol, tc_scale, tc_tol
    real scalar j
    xdebias_val = st_matrix("__hddid_final_xdebias")
    stdx_val = st_matrix("__hddid_final_stdx")
    V_val = st_matrix("__hddid_final_V")
    gdebias_val = st_matrix("__hddid_final_gdebias")
    stdg_val = st_matrix("__hddid_final_stdg")
    tc_val = st_matrix("__hddid_final_tc")
    CIpoint_val = st_matrix("__hddid_final_CIpoint")
    CIuniform_val = st_matrix("__hddid_final_CIuniform")
    alpha_val = st_matrix("__hddid_final_alpha")

    if (args() < 10) {
        qq_expected = cols(gdebias_val)
    }
    else {
        if (qq_expected < 1 | qq_expected != trunc(qq_expected) | qq_expected >= .) {
            errprintf("_hddid_post_results(): expected z0-grid width qq must be a positive integer, got %g\n",
                qq_expected)
            _error(3498)
        }
    }

    if (rows(xdebias_val) == 0 & cols(xdebias_val) == 0 &
        rows(stdx_val) == 0 & cols(stdx_val) == 0 &
        rows(V_val) == 0 & cols(V_val) == 0 &
        rows(gdebias_val) == 0 & cols(gdebias_val) == 0 &
        rows(stdg_val) == 0 & cols(stdg_val) == 0 &
        rows(tc_val) == 0 & cols(tc_val) == 0 &
        rows(CIpoint_val) == 0 & cols(CIpoint_val) == 0 &
        rows(CIuniform_val) == 0 & cols(CIuniform_val) == 0) {
        errprintf("_hddid_post_results(): missing final aggregate state; expected __hddid_final_* matrices from _hddid_run_aggregate()\n")
        _error(3498)
    }
    if (rows(alpha_val) > 0 | cols(alpha_val) > 0) {
        if (rows(alpha_val) != 1 | cols(alpha_val) != 1) {
            errprintf("_hddid_post_results(): final alpha must be a 1 x 1 scalar; got %g x %g\n",
                rows(alpha_val), cols(alpha_val))
            _error(3498)
        }
        if (hasmissing(alpha_val)) {
            errprintf("_hddid_post_results(): final alpha must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        if (alpha_val[1, 1] <= 0 | alpha_val[1, 1] >= 1) {
            errprintf("_hddid_post_results(): final alpha must lie in (0,1); got %g\n",
                alpha_val[1, 1])
            _error(3498)
        }
    }

    if (rows(tc_val) > 0 | cols(tc_val) > 0) {
        if (rows(tc_val) != 1 | cols(tc_val) != 2) {
            errprintf("_hddid_post_results(): final tc must be 1 x 2; got %g x %g\n",
                rows(tc_val), cols(tc_val))
            _error(3498)
        }
        if (hasmissing(tc_val)) {
            errprintf("_hddid_post_results(): final tc must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        if (tc_val[1, 1] > tc_val[1, 2]) {
            errprintf("_hddid_post_results(): final tc must satisfy lower <= upper; got (%g, %g)\n",
                tc_val[1, 1], tc_val[1, 2])
            _error(3498)
        }
    }

    has_param_block = (rows(xdebias_val) > 0 | cols(xdebias_val) > 0 |
        rows(stdx_val) > 0 | cols(stdx_val) > 0 |
        rows(V_val) > 0 | cols(V_val) > 0)
    has_nonparam_block = (rows(gdebias_val) > 0 | cols(gdebias_val) > 0 |
        rows(stdg_val) > 0 | cols(stdg_val) > 0 |
        rows(CIpoint_val) > 0 | cols(CIpoint_val) > 0 |
        rows(CIuniform_val) > 0 | cols(CIuniform_val) > 0)
    if (has_nonparam_block & !has_param_block) {
        errprintf("_hddid_post_results(): final parametric block (xdebias/stdx/V) is required when publishing HDDID result objects\n")
        _error(3498)
    }

    if (rows(xdebias_val) > 0 | cols(xdebias_val) > 0 | rows(stdx_val) > 0 | cols(stdx_val) > 0 |
        rows(V_val) > 0 | cols(V_val) > 0) {
        if (rows(xdebias_val) != 1) {
            errprintf("_hddid_post_results(): final xdebias must be a 1 x p rowvector; got %g x %g\n",
                rows(xdebias_val), cols(xdebias_val))
            _error(3498)
        }
        if (rows(stdx_val) != 1) {
            errprintf("_hddid_post_results(): final stdx must be a 1 x p rowvector; got %g x %g\n",
                rows(stdx_val), cols(stdx_val))
            _error(3498)
        }
        if (rows(V_val) != cols(V_val)) {
            errprintf("_hddid_post_results(): final V must be square; got %g x %g\n",
                rows(V_val), cols(V_val))
            _error(3498)
        }
        if (cols(xdebias_val) != cols(V_val)) {
            errprintf("_hddid_post_results(): final xdebias has %g columns but V is %g x %g\n",
                cols(xdebias_val), rows(V_val), cols(V_val))
            _error(3498)
        }
        if (cols(stdx_val) != cols(xdebias_val)) {
            errprintf("_hddid_post_results(): final stdx has %g columns; expected parameter width p = %g\n",
                cols(stdx_val), cols(xdebias_val))
            _error(3498)
        }
        if (hasmissing(xdebias_val)) {
            errprintf("_hddid_post_results(): final xdebias must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        if (hasmissing(stdx_val)) {
            errprintf("_hddid_post_results(): final stdx must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        if (hasmissing(V_val)) {
            errprintf("_hddid_post_results(): final V must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        _hddid_assert_symmetric_psd("_hddid_post_results(): final V", V_val)
        if (min(stdx_val) < 0) {
            errprintf("_hddid_post_results(): final stdx must be nonnegative; min entry = %g\n",
                min(stdx_val))
            _error(3498)
        }
        _hddid_assert_vcovx_stdx(
            "_hddid_post_results(): final V/stdx",
            V_val, stdx_val)
    }

    if (rows(gdebias_val) > 0 | cols(gdebias_val) > 0 | rows(stdg_val) > 0 | cols(stdg_val) > 0 |
        rows(CIpoint_val) > 0 | cols(CIpoint_val) > 0 | rows(CIuniform_val) > 0 | cols(CIuniform_val) > 0) {
        if (rows(gdebias_val) != 1) {
            errprintf("_hddid_post_results(): final gdebias must be a 1 x qq rowvector; got %g x %g\n",
                rows(gdebias_val), cols(gdebias_val))
            _error(3498)
        }
        qq = qq_expected
        if (cols(gdebias_val) != qq) {
            errprintf("_hddid_post_results(): final gdebias has %g columns; expected shared z0-grid width qq = %g\n",
                cols(gdebias_val), qq)
            _error(3498)
        }
        if (hasmissing(gdebias_val)) {
            errprintf("_hddid_post_results(): final gdebias must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        if (rows(stdg_val) != 1) {
            errprintf("_hddid_post_results(): final stdg must be a 1 x qq rowvector; got %g x %g\n",
                rows(stdg_val), cols(stdg_val))
            _error(3498)
        }
        if (cols(stdg_val) != qq) {
            errprintf("_hddid_post_results(): final stdg has %g columns but gdebias has %g; expected shared z0-grid width\n",
                cols(stdg_val), qq)
            _error(3498)
        }
        if (hasmissing(stdg_val)) {
            errprintf("_hddid_post_results(): final stdg must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        if (min(stdg_val) < 0) {
            errprintf("_hddid_post_results(): final stdg must be nonnegative; min entry = %g\n",
                min(stdg_val))
            _error(3498)
        }
        if ((rows(CIuniform_val) > 0 | cols(CIuniform_val) > 0) &
            rows(tc_val) == 0 & cols(tc_val) == 0) {
            errprintf("_hddid_post_results(): final tc is required when CIuniform is present\n")
            _error(3498)
        }
        if (rows(CIuniform_val) != 2) {
            errprintf("_hddid_post_results(): final CIuniform must be 2 x qq; got %g x %g\n",
                rows(CIuniform_val), cols(CIuniform_val))
            _error(3498)
        }
        if (cols(CIuniform_val) != qq) {
            errprintf("_hddid_post_results(): final CIuniform has %g columns but gdebias has %g; expected shared z0-grid width\n",
                cols(CIuniform_val), qq)
            _error(3498)
        }
        if (hasmissing(CIuniform_val)) {
            errprintf("_hddid_post_results(): final CIuniform must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        stdg_absmax = max(abs(stdg_val))
        stdg_scale = max((1, stdg_absmax))
        zero_stdg_tol = 1e-12 * stdg_scale
        tc_scale = max((1, max(abs(tc_val))))
        tc_tol = 1e-12 * tc_scale
        if (stdg_absmax <= zero_stdg_tol & rows(tc_val) == 1 & cols(tc_val) == 2) {
            if (abs(tc_val[1,1]) > tc_tol | abs(tc_val[1,2]) > tc_tol) {
                errprintf("_hddid_post_results(): final tc must equal (0, 0) when final stdg is identically zero\n")
                errprintf("_hddid_post_results(): on the zero-SE shortcut, the published CIuniform object already collapses exactly to gdebias, so any nonzero tc is stale or impossible bootstrap provenance\n")
                _error(3498)
            }
        }
        else if (rows(tc_val) == 1 & cols(tc_val) == 2) {
            if (abs(tc_val[1,1]) <= tc_tol & abs(tc_val[1,2]) <= tc_tol) {
                errprintf("_hddid_post_results(): final tc must not equal (0, 0) when final stdg is not identically zero\n")
                errprintf("_hddid_post_results(): with nonzero published stdg, tc = (0, 0) would collapse final CIuniform back to gdebias instead of preserving distinct bootstrap provenance\n")
                _error(3498)
            }
        }
        for (j = 1; j <= qq; j++) {
            if (stdg_val[1, j] == 0) {
                if (CIuniform_val[1, j] != gdebias_val[1, j] | ///
                    CIuniform_val[2, j] != gdebias_val[1, j]) {
                    errprintf("_hddid_post_results(): zero-SE CIuniform rows must collapse exactly to gdebias; column %g drifts to (%g, %g) around %g\n",
                        j, CIuniform_val[1, j], CIuniform_val[2, j], gdebias_val[1, j])
                    _error(3498)
                }
            }
        }
        if (rows(tc_val) == 1 & cols(tc_val) == 2 & !hasmissing(gdebias_val) & !hasmissing(stdg_val)) {
            ciuniform_oracle = (gdebias_val :+ tc_val[1] * stdg_val) \
                (gdebias_val :+ tc_val[2] * stdg_val)
            ciuniform_gap = max(abs(CIuniform_val :- ciuniform_oracle))
            // CIuniform is an estimand-scale interval object. Compare it on
            // the band's own scale so tiny but materially wrong endpoints do
            // not hide under a unit-scale tolerance floor.
            ciuniform_scale = max((max(abs(CIuniform_val)), max(abs(ciuniform_oracle))))
            if (ciuniform_scale <= 0 | ciuniform_scale >= .) {
                ciuniform_scale = 1
            }
            ciuniform_tol = 1e-12 * ciuniform_scale
            if (ciuniform_gap > ciuniform_tol) {
                errprintf("_hddid_post_results(): final CIuniform is inconsistent with gdebias/stdg/tc; max gap = %g\n",
                    ciuniform_gap)
                _error(3498)
            }
        }
        if (rows(CIpoint_val) != 2) {
            errprintf("_hddid_post_results(): final CIpoint must be 2 x (p + qq); got %g x %g\n",
                rows(CIpoint_val), cols(CIpoint_val))
            _error(3498)
        }
        if (cols(CIpoint_val) != cols(xdebias_val) + qq) {
            errprintf("_hddid_post_results(): final CIpoint has %g columns; expected p + qq = %g + %g = %g\n",
                cols(CIpoint_val), cols(xdebias_val), qq, cols(xdebias_val) + qq)
            _error(3498)
        }
        if (hasmissing(CIpoint_val)) {
            errprintf("_hddid_post_results(): final CIpoint must be finite; found missing/nonfinite values\n")
            _error(3498)
        }
        if (rows(alpha_val) == 0 & cols(alpha_val) == 0) {
            errprintf("_hddid_post_results(): final alpha is required when CIpoint is present\n")
            _error(3498)
        }
        if (rows(alpha_val) == 1 & cols(alpha_val) == 1 &
            !hasmissing(CIpoint_val) & !hasmissing(xdebias_val) &
            !hasmissing(stdx_val) & !hasmissing(gdebias_val) &
            !hasmissing(stdg_val)) {
            z_crit = invnormal(1 - alpha_val[1, 1] / 2)
            cipoint_oracle = (xdebias_val :- z_crit * stdx_val,
                              gdebias_val :- z_crit * stdg_val) \
                             (xdebias_val :+ z_crit * stdx_val,
                              gdebias_val :+ z_crit * stdg_val)
            ci_point_gap = max(abs(CIpoint_val :- cipoint_oracle))
            // CIpoint is likewise an estimand-scale interval object, so use
            // the interval's own magnitude for consistency tolerance.
            ci_point_scale = max((max(abs(CIpoint_val)), max(abs(cipoint_oracle))))
            if (ci_point_scale <= 0 | ci_point_scale >= .) {
                ci_point_scale = 1
            }
            ci_point_tol = 1e-12 * ci_point_scale
            if (ci_point_gap > ci_point_tol) {
                errprintf("_hddid_post_results(): final CIpoint is inconsistent with xdebias/stdx/gdebias/stdg/alpha; max gap = %g\n",
                    ci_point_gap)
                _error(3498)
            }
        }
    }

    st_matrix(b_name, xdebias_val)
    st_matrix(V_name, V_val)
    st_matrix(xdebias_name, xdebias_val)
    st_matrix(gdebias_name, gdebias_val)
    st_matrix(stdx_name, stdx_val)
    st_matrix(stdg_name, stdg_val)
    st_matrix(tc_name, tc_val)
    st_matrix(CIpoint_name, CIpoint_val)
    st_matrix(CIuniform_name, CIuniform_val)
}

// ============================================================
// 折内去偏+Bootstrap+存储 wrapper [Bug fix: mata {} interpreted块不支持struct]
// interpreted mata { } 块中无法声明struct变量或访问struct成员，
// 因此将debias_beta → debias_gamma → bootstrap → store_fold
// 的完整流程封装为compiled函数。
// 从hddid.ado的mata { }块改为调用此函数。
// ============================================================

void _hddid_stage2_prepare(
    string scalar b_stage2_name,
    string scalar newy_var,
    string scalar w_varlist,
    string scalar eval_touse,
    real scalar p,
    real scalar q,
    string scalar betahat_name,
    string scalar gammahat_q_name,
    string scalar gammahat_full_name,
    string scalar adjy_name,
    string scalar a0_name)
{
    real matrix b_full, wsample
    string matrix b_colstripe
    string rowvector b_names, b_names_raw, expected_names
    real rowvector betahat_p, gammahat_q, betahat_full
    real rowvector reorder_idx
    real scalar a0, expected_cols, j, h, matched_count, match_pos, any_named_stripes
    real colvector gammahat_full, newy_vec, adjy

    // Clear any prior payload on the caller-provided output names before
    // validation so a fail-close path cannot leak stale stage-2 objects.
    stata("capture matrix drop " + betahat_name)
    stata("capture matrix drop " + gammahat_q_name)
    stata("capture matrix drop " + gammahat_full_name)
    stata("capture matrix drop " + adjy_name)
    stata("capture scalar drop " + a0_name)

    b_full = st_matrix(b_stage2_name)
    expected_cols = p + q + 1
    if (rows(b_full) != 1) {
        errprintf("_hddid_stage2_prepare(): b_stage2 has %g rows; expected exactly 1\n",
            rows(b_full))
        _error(3498)
    }
    if (cols(b_full) != expected_cols) {
        errprintf("_hddid_stage2_prepare(): b_stage2 has %g columns; expected exactly %g\n",
            cols(b_full), expected_cols)
        _error(3498)
    }
    if (hasmissing(b_full)) {
        errprintf("_hddid_stage2_prepare(): b_stage2 must be finite; found missing/nonfinite values\n")
        _error(3498)
    }
    b_colstripe = st_matrixcolstripe(b_stage2_name)
    expected_names = tokens(w_varlist)
    expected_names = expected_names, "_cons"
    if (rows(b_colstripe) != expected_cols | cols(b_colstripe) < 2) {
        errprintf("_hddid_stage2_prepare(): b_stage2 must carry column stripes for w_varlist and _cons; positional splitting is ambiguous\n")
        _error(3498)
    }
    b_names_raw = b_colstripe[, 2]'
    b_names = b_names_raw
    any_named_stripes = 0
    for (h = 1; h <= cols(b_names); h++) {
        b_names[h] = strtrim(b_names[h])
        if (b_names[h] != "") {
            any_named_stripes = 1
        }
        if (strlen(b_names[h]) > 2 && substr(b_names[h], 1, 2) == "o.") {
            b_names[h] = substr(b_names[h], 3, .)
        }
    }
    if (!any_named_stripes) {
        errprintf("_hddid_stage2_prepare(): b_stage2 column stripes must identify w_varlist and _cons; blank stripes are ambiguous\n")
        _error(3498)
    }
    reorder_idx = J(1, expected_cols, .)
    matched_count = 0
    for (j = 1; j <= expected_cols; j++) {
        match_pos = 0
        for (h = 1; h <= cols(b_names); h++) {
            if (b_names[h] == expected_names[j]) {
                if (match_pos != 0) {
                    errprintf("_hddid_stage2_prepare(): b_stage2 column stripe %s appears multiple times\n",
                        expected_names[j])
                    _error(3498)
                }
                match_pos = h
            }
        }
        if (match_pos != 0) {
            reorder_idx[j] = match_pos
            matched_count = matched_count + 1
        }
    }
    if (matched_count != expected_cols) {
        errprintf("_hddid_stage2_prepare(): b_stage2 column stripes must cover w_varlist and _cons exactly\n")
        errprintf("_hddid_stage2_prepare(): expected order =")
        for (j = 1; j <= expected_cols; j++) {
            errprintf(" %s", expected_names[j])
        }
        errprintf("\n")
        errprintf("_hddid_stage2_prepare(): observed stripes =")
        for (j = 1; j <= expected_cols; j++) {
            errprintf(" %s", b_names_raw[j])
        }
        errprintf("\n")
        _error(3498)
    }
    b_full = b_full[1, reorder_idx]
    betahat_p = b_full[1, 1..p]
    gammahat_q = b_full[1, (p + 1)..(p + q)]
    a0 = b_full[1, p + q + 1]
    betahat_full = b_full[1, 1..(p + q)]

    newy_vec = st_data(., newy_var, eval_touse)
    if (rows(newy_vec) == 0) {
        errprintf("_hddid_stage2_prepare(): empty evaluation sample\n")
        _error(3200)
    }
    if (hasmissing(newy_vec)) {
        errprintf("_hddid_stage2_prepare(): newy fold sample contains missing/nonfinite values\n")
        _error(3351)
    }
    wsample = st_data(., tokens(w_varlist), eval_touse)
    if (rows(wsample) == 0) {
        errprintf("_hddid_stage2_prepare(): empty stage-2 design matrix\n")
        _error(3200)
    }
    if (hasmissing(wsample)) {
        errprintf("_hddid_stage2_prepare(): stage-2 design matrix contains missing/nonfinite values\n")
        _error(3351)
    }
    if (cols(wsample) != p + q) {
        errprintf("_hddid_stage2_prepare(): stage-2 design matrix has %g columns; expected exactly p + q = %g + %g = %g\n",
            cols(wsample), p, q, p + q)
        _error(3498)
    }
    adjy = newy_vec - wsample * betahat_full' :- a0
    if (hasmissing(adjy)) {
        errprintf("_hddid_stage2_prepare(): computed adjy must be finite; found missing/nonfinite values\n")
        _error(3351)
    }
    gammahat_full = (a0 \ gammahat_q')

    st_matrix(betahat_name, betahat_p)
    st_matrix(gammahat_q_name, gammahat_q)
    st_matrix(gammahat_full_name, gammahat_full)
    st_matrix(adjy_name, adjy)
    st_numscalar(a0_name, a0)
}

void _hddid_store_constant_fold(
    real scalar fold_k, real scalar p, real scalar qq,
    real scalar q_sieve, real scalar n_valid,
    real scalar score_level)
{
    real matrix xdebias, stdx, vcovx, gdebias, stdg, Vf
    real rowvector tc_k

    xdebias = J(1, p, 0)
    stdx = J(1, p, 0)
    vcovx = J(p, p, 0)
    if (score_level >= .) {
        errprintf("_hddid_store_constant_fold(): score_level must be finite; got missing/nonfinite input\n")
        _error(3498)
    }
    // A constant retained DR response is absorbed by the separate stage-2
    // intercept a0. The published nonparametric block is f(z0), so the
    // non-constant sieve coordinates stay exactly zero in this shortcut.
    gdebias = J(1, qq, 0)
    stdg = J(1, qq, 0)
    Vf = J(q_sieve, q_sieve, 0)
    tc_k = (0, 0)

    _hddid_store_fold(fold_k,
        xdebias, stdx, vcovx,
        gdebias, stdg,
        0, tc_k, Vf, n_valid)

    st_matrix("__hddid_xdebias_k", xdebias)
    st_matrix("__hddid_stdx_k", stdx)
    st_matrix("__hddid_vcovx_k", vcovx)
    st_matrix("__hddid_gdebias_k", gdebias)
    st_matrix("__hddid_stdg_k", stdg)
    st_numscalar("__hddid_nan_fallback_k", 0)
    st_matrix("__hddid_tc_k", tc_k)
}

void _hddid_fold_debias_store(
    string scalar covinv_name, string scalar tildex_name,
    string scalar zbf_varlist, string scalar x_varlist,
    string scalar eval_touse, string scalar MM_name,
    string scalar zbpred_name, string scalar betahat_name,
    string scalar gammahat_full_name, string scalar adjy_name,
    real scalar fold_k, real scalar K_total,
    real scalar n_valid, real scalar p, real scalar q,
    real scalar alpha, real scalar nboot, real scalar seed_val)
{
    struct _hddid_beta_result scalar beta_res
    struct _hddid_gamma_result scalar gamma_res
    real colvector adjy, epsilon
    real matrix betahat_p, covinv, gammahat_full
    real matrix tildex, zbasis_full, xsample, MM, zbpred
    real matrix gammahat_q, MM_q, zbpred_q, Vf_full
    real rowvector tc_k
    real colvector gammabar_full
    real scalar a0_fold
    real scalar actual_n, q_gamma

    if (fold_k != trunc(fold_k) | fold_k >= .) {
        errprintf("_hddid_fold_debias_store(): fold_k must be a finite integer; got %g\n",
            fold_k)
        _error(3498)
    }
    if (K_total < 2 | K_total != trunc(K_total) | K_total >= .) {
        errprintf("_hddid_fold_debias_store(): K_total must be an integer >= 2; got %g\n",
            K_total)
        _error(3498)
    }
    if (fold_k < 1 | fold_k > K_total) {
        errprintf("_hddid_fold_debias_store(): fold_k must lie in 1..K_total; got fold_k=%g, K_total=%g\n",
            fold_k, K_total)
        _error(3498)
    }

    // --- Step 1: load fold-specific inputs and validate sample-size contract ---
    covinv = st_matrix(covinv_name)
    tildex = st_matrix(tildex_name)
    betahat_p = st_matrix(betahat_name)
    adjy = st_matrix(adjy_name)
    zbasis_full = st_data(., tokens(zbf_varlist), eval_touse)
    xsample = st_data(., tokens(x_varlist), eval_touse)
    MM = st_matrix(MM_name)
    zbpred = st_matrix(zbpred_name)
    gammahat_full = st_matrix(gammahat_full_name)
    actual_n = rows(zbasis_full)

    if (n_valid != actual_n) {
        errprintf("_hddid_fold_debias_store(): n_valid=%g but eval_touse selects %g rows\n",
            n_valid, actual_n)
        _error(3498)
    }
    if (rows(tildex) != actual_n | rows(adjy) != actual_n | rows(xsample) != actual_n) {
        errprintf("_hddid_fold_debias_store(): fold inputs disagree on evaluation sample size\n")
        errprintf("_hddid_fold_debias_store(): rows(tildex)=%g, rows(adjy)=%g, rows(xsample)=%g, eval rows=%g\n",
            rows(tildex), rows(adjy), rows(xsample), actual_n)
        _error(3498)
    }

    // --- Step 2: debias_beta ---
    epsilon = adjy

    beta_res = _hddid_debias_beta(
        tildex, covinv, adjy, epsilon, betahat_p, n_valid)

    // [AUDIT TRACE] Detailed fold diagnostics
    {
        real matrix _dbg_Sig, _dbg_Om
        real rowvector _dbg_rs, _dbg_corr
        _dbg_Sig = cross(tildex, tildex) / n_valid
        _dbg_Om = luinv(_dbg_Sig)
        _dbg_rs = (tildex' * adjy)' / n_valid
        _dbg_corr = _dbg_rs * _dbg_Om
        printf("[AUDIT-DETAIL] Fold %g: betahat_p[1]=%9.6f, adjy_sd=%9.4f\n",
            fold_k, betahat_p[1], sqrt(variance(adjy)))
        printf("[AUDIT-DETAIL] Fold %g: raw_score[1]=%9.6f, analytic_corr[1]=%9.6f\n",
            fold_k, _dbg_rs[1], _dbg_corr[1])
        printf("[AUDIT-DETAIL] Fold %g: analytic_xd[1]=%9.6f, actual_xd[1]=%9.6f\n",
            fold_k, betahat_p[1] + _dbg_corr[1], beta_res.xdebias[1])
        printf("[AUDIT-DETAIL] Fold %g: covinv[1,1]=%9.6f, analytic_Om[1,1]=%9.6f\n",
            fold_k, covinv[1,1], _dbg_Om[1,1])
        printf("[AUDIT-DETAIL] Fold %g: |psi'*tx/n|_max=%g, |1'*tx/n|_max=%g\n",
            fold_k,
            max(abs(cross(zbasis_full[|1,2 \ actual_n,q|], tildex) / n_valid)),
            max(abs(colsum(tildex) / n_valid)))
    }

    // --- Step 3: debias_gamma ---
    // The paper's Section 4 gamma/V_f objects and the R reference debias only
    // the non-constant sieve block. a0 is estimated separately in stage 2 and
    // must not be folded back into gdebias/stdg by treating the intercept as a
    // debiased gamma coordinate.
    if (cols(zbasis_full) != q | rows(MM) != q | rows(gammahat_full) != q | cols(zbpred) != q) {
        errprintf("_hddid_fold_debias_store(): gamma-block inputs disagree with full sieve width q=%g\n", q)
        errprintf("_hddid_fold_debias_store(): cols(zbasis_full)=%g, rows(MM)=%g, rows(gammahat_full)=%g, cols(zbpred)=%g\n",
            cols(zbasis_full), rows(MM), rows(gammahat_full), cols(zbpred))
        _error(3498)
    }

    q_gamma = q - 1
    if (q_gamma <= 0) {
        gamma_res = _hddid_gamma_result()
        gamma_res.gdebias = J(1, rows(zbpred), 0)
        gamma_res.stdg = J(1, rows(zbpred), 0)
        gamma_res.Vf = J(q, q, 0)
        gamma_res.nan_fallback = 0
        gamma_res.gammabar = J(0, 1, 0)
    }
    else {
        gammahat_q = gammahat_full[|2,1 \ q,1|]
        MM_q = MM[|2,1 \ q,cols(MM)|]
        zbpred_q = zbpred[|1,2 \ rows(zbpred),q|]

        gamma_res = _hddid_debias_gamma(
            xsample, zbasis_full[|1,2 \ actual_n,q|], MM_q, adjy,
            gammahat_q, zbpred_q, epsilon, n_valid, p, q_gamma)

        Vf_full = J(q, q, 0)
        Vf_full[|2,2 \ q,q|] = gamma_res.Vf
        gamma_res.Vf = Vf_full
    }

    // --- Step 4: Defer bootstrap tc to the aggregate stage ---
    // The published CIuniform/tc object is defined from the aggregated Vf
    // across folds. A discarded fold-specific bootstrap here would only advance
    // the ambient RNG stream when seed() is omitted.
    tc_k = (., .)

    // --- Step 4b: Build full gammabar (a0; gammabar_q) for predict ---
    a0_fold = gammahat_full[1]
    if (q_gamma > 0) {
        gammabar_full = (a0_fold \ gamma_res.gammabar)
    }
    else {
        gammabar_full = (a0_fold)
    }

    // --- Step 5: Store results to Stata matrix space ---
    st_matrix("__hddid_xdebias_k", beta_res.xdebias)
    st_matrix("__hddid_stdx_k", beta_res.stdx)
    st_matrix("__hddid_vcovx_k", beta_res.vcovx)
    st_matrix("__hddid_gdebias_k", gamma_res.gdebias)
    st_matrix("__hddid_stdg_k", gamma_res.stdg)
    st_numscalar("__hddid_nan_fallback_k", gamma_res.nan_fallback)
    st_matrix("__hddid_tc_k", tc_k)
    st_matrix("__hddid_gammabar_k", gammabar_full')
    st_numscalar("__hddid_a0_k", a0_fold)

    // --- Step 6: Store into external fold_results ---
    _hddid_store_fold(fold_k,
        beta_res.xdebias, beta_res.stdx, beta_res.vcovx,
        gamma_res.gdebias, gamma_res.stdg,
        gamma_res.nan_fallback, tc_k,
        gamma_res.Vf, n_valid)
}

// Aggregate gammabar and a0 across folds for predict support.
// This must be a compiled function because interpreted mata: { } blocks
// inside ado-file programs cannot contain nested for/if blocks.
void _hddid_aggregate_gammabar(real scalar K)
{
    real scalar _agg_total, _agg_wk, _agg_k
    real rowvector _agg_gammabar
    real scalar _agg_a0

    _agg_total = 0
    for (_agg_k = 1; _agg_k <= K; _agg_k++) {
        _agg_total = _agg_total + st_numscalar("__hddid_fold_n_valid_" + strofreal(_agg_k))
    }
    _agg_gammabar = J(1, 0, 0)
    _agg_a0 = 0
    for (_agg_k = 1; _agg_k <= K; _agg_k++) {
        _agg_wk = st_numscalar("__hddid_fold_n_valid_" + strofreal(_agg_k)) / _agg_total
        if (_agg_k == 1) {
            _agg_gammabar = _agg_wk * st_matrix("__hddid_gammabar_" + strofreal(_agg_k))
        }
        else {
            _agg_gammabar = _agg_gammabar + _agg_wk * st_matrix("__hddid_gammabar_" + strofreal(_agg_k))
        }
        _agg_a0 = _agg_a0 + _agg_wk * st_numscalar("__hddid_a0_" + strofreal(_agg_k))
    }
    st_matrix("__hddid_final_gammabar", _agg_gammabar)
    st_numscalar("__hddid_final_a0", _agg_a0)
}

end
