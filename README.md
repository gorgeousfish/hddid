# hddid

**Doubly Robust Semiparametric Difference-in-Differences with High-Dimensional Data for Stata**

[![Stata 16+](https://img.shields.io/badge/Stata-16%2B-blue.svg)](https://www.stata.com/)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)
[![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-green.svg)]()

![hddid](image/image.png)

## Overview

`hddid` implements the **doubly robust semiparametric difference-in-differences estimator** proposed by Ning, Peng, and Tao (2024) for settings with high-dimensional covariates. The estimator targets the conditional average treatment effect on the treated (CATT) under a partially linear model:

$$E[Y^1(1) - Y^0(1) \mid X, Z, D=1] = X'\beta + f(Z)$$

where $\beta$ is a $p$-dimensional parametric component (possibly $p > n$) and $f(\cdot)$ is an unknown smooth function estimated nonparametrically via sieve approximation.

**Features**:

- Doubly robust estimation via AIPW score (consistent if either propensity or outcome model is correct)
- High-dimensional covariates ($p > n$) with Lasso penalization
- Flexible nonparametric component via polynomial (`Pol`) or trigonometric (`Tri`) sieve basis
- Debiased $\sqrt{n}$-inference for the parametric component $\beta$
- Pointwise and uniform confidence intervals for the nonparametric component $f(z)$
- Cross-fitting to avoid overfitting bias
- Postestimation: `predict` for fitted ATT surface (tau, xb, fz)
- Built-in DGP generators (`hddid_dgp1`, `hddid_dgp2`) for Monte Carlo simulation

## Requirements

- **Stata 16.0** or later
- **lassopack** (provides `lasso2`, `cvlasso`, `cvlassologit`)
- **Python 3.7+** with `numpy >= 1.20` and `scipy >= 1.7` — required only when `x()` has more than one covariate (the CLIME precision matrix step calls Python); with a single covariate, `hddid` uses an analytic scalar inverse and does not call Python

## Installation

### Step 1: Install dependencies

```stata
* Install lassopack from SSC
ssc install lassopack, replace
```

> **Python note:** When `x()` has more than one covariate, `hddid` calls Python for the CLIME precision matrix step. Stata 16+ auto-detects Python on most systems. To verify, run `python query`; if Python is not found, run `python search` to list available installations, then `set python_exec <path>, permanently` to bind one. See `help python` for details.

### Step 2: Install hddid

```stata
net install hddid, from("https://raw.githubusercontent.com/gorgeousfish/hddid/main") replace
```

### Step 3: Download example datasets

The bundled empirical datasets are ancillary files. Download them to your working directory once:

```stata
net get hddid, from("https://raw.githubusercontent.com/gorgeousfish/hddid/main") replace
```

This downloads `nsw_dw.dta` and `minwage_state.dta` to your current directory.

### Step 4: Verify installation

```stata
which hddid
which hddid_dgp1
which hddid_dgp2
help hddid
```

## Quick Start

After running `net get hddid` (Step 3 above), load the datasets with:

```stata
use nsw_dw, clear         // LaLonde-Dehejia-Wahba NSW job training
use minwage_state, clear  // Fair Minimum Wage Act state panel
```

### Example 1: Job Training and Earnings (LaLonde-Dehejia-Wahba, 1999)

This example uses the NSW (National Supported Work) job training experiment. The outcome change is the difference in real earnings from 1975 (pre-treatment) to 1978 (post-treatment). The key nonparametric variable `re74` captures heterogeneity by prior earnings, whose effect on the treatment-earnings relationship is left unrestricted. This is the canonical benchmark dataset for doubly robust estimators.

**Data:** `nsw_dw.dta` — 445 individuals (185 treated, 260 control)

```stata
use nsw_dw, clear

* deltay = re78 - re75 (change in real earnings, USD)
* x()    = age educ black hisp married nodegree (demographic covariates)
* z()    = re74 (1974 baseline earnings: nonparametric heterogeneity by prior income)

* Estimate: treatment effect of NSW training, heterogeneous by baseline earnings
* No Python needed (p=6 uses scalar CLIME path)
set seed 42
hddid deltay, treat(treat) x(age educ black hisp married nodegree) z(re74) ///
    method(Pol) q(4) k(3) z0(0 2000 5000 10000) nboot(500) alpha(0.1)

* Debiased estimates: beta for each demographic covariate
matrix list e(xdebias), format(%9.2f)
matrix list e(stdx),    format(%9.2f)

* Nonparametric ATT component at z0 evaluation points
* f(re74): how treatment effect varies with 1974 baseline earnings
matrix list e(gdebias), format(%9.2f)
matrix list e(z0),      format(%9.2f)
matrix list e(CIpoint), format(%9.2f)

* Predict full ATT surface: tau(X,Z) = X'beta + f(Z)
predict double tau_hat
summarize tau_hat
```

### Example 2: Fair Minimum Wage Act and State Unemployment (Ning, Peng & Tao, 2020)

This example replicates the empirical application in the original paper (Ning, Peng & Tao 2020). The Fair Minimum Wage Act of 2007 raised the federal minimum wage in three steps (2007–2009). Treated states are those where the federal increase was binding (state minimum wage ≤ $5.15 before the Act). The outcome is the change in state unemployment rate. The nonparametric variable `prior_unem` allows the unemployment response to differ flexibly by a state's pre-crisis labor market slack — tighter labor markets may respond differently to wage floors.

**Data:** `minwage_state.dta` — 50 U.S. states (17 treated, 33 control)

```stata
use minwage_state, clear

* deltay     = change in unemployment rate (post 2007-09 avg minus pre 2005-06 avg)
* x()        = gdp_pc_2006 mfg_share union_rate educ_ba poverty_rate teen_share south
* z()        = prior_unem (2004 unemployment rate: nonparametric labor-market heterogeneity)
* treat      = 1 if federal minimum wage increase was binding in 2007

set seed 42
hddid deltay, treat(treat) ///
    x(gdp_pc_2006 mfg_share union_rate educ_ba poverty_rate teen_share south) ///
    z(prior_unem) ///
    method(Pol) q(4) k(2) ///
    z0(3.5 4.5 5.5 6.5) nboot(500) alpha(0.1)

* Debiased beta: effect of each state covariate on treatment heterogeneity
matrix list e(xdebias), format(%9.4f)
matrix list e(stdx),    format(%9.4f)

* Nonparametric component: how wage-floor effect varies with baseline unemployment
* f(prior_unem): unemployment response at z0 = 3.5, 4.5, 5.5, 6.5
matrix list e(gdebias), format(%9.4f)
matrix list e(CIpoint), format(%9.4f)
```

## Postestimation

After estimation, `hddid` supports `predict` for fitted values:

```stata
* Default: tau = X'beta + f(Z) (full ATT prediction)
predict tau_hat

* Linear component only: xb = X'beta_debias
predict xb_hat, xb

* Nonparametric component only: fz = a0 + psi(z)'gamma
predict fz_hat, fz

* Verify decomposition: tau = xb + fz
summarize tau_hat xb_hat fz_hat
```

Replay the stored estimation table:

```stata
* Bare hddid re-displays the last estimation results
hddid
```

## Monte Carlo Validation

The built-in DGP generators reproduce the simulation designs from the paper (Section 5). Use these to verify estimation accuracy against known true values before applying `hddid` to your own data.

### DGP1: Basic validation (p=1, no Python required)

```stata
* Homoscedastic, independent X; true beta_1 = 1.0, true f(z) = exp(z)
hddid_dgp1, n(300) p(1) seed(12345) clear

hddid deltay, treat(treat) x(x1) z(z) ///
    method(Pol) q(4) k(2) seed(42) z0(-1 0 1) nboot(500) alpha(0.1)

* Check: e(xdebias) should be close to 1.0
matrix list e(xdebias), format(%9.4f)
```

### DGP2: Heteroscedastic correlated-X design (requires Python for p > 1)

```stata
* AR(1)-correlated covariates, heteroscedastic baseline; true beta_1 = 1.0
hddid_dgp2, n(500) p(1) seed(54321) rho(0.5) clear

hddid deltay, treat(treat) x(x1) z(z) ///
    method(Pol) q(8) k(3) seed(42) z0(-1 0 1) nboot(500) alpha(0.05)

matrix list e(xdebias), format(%9.4f)
```

### Paper-baseline: p=50, trigonometric basis (requires Python, ~5 min)

```stata
* Section 5 design: true beta_j = 1/j for j=1..15, 0 for j>15
hddid_dgp1, n(500) p(50) seed(12345) clear
unab x_vars : x*

hddid deltay, treat(treat) x(`x_vars') z(z) ///
    method(Tri) q(16) k(3) seed(42) z0(-1 -0.5 0 0.5 1) ///
    nboot(1000) alpha(0.1)

matrix list e(xdebias), format(%9.4f)
matrix list e(CIpoint), format(%9.4f)
matrix list e(CIuniform), format(%9.4f)
```

## Commands

| Command | Description |
|---------|-------------|
| `hddid` | Main estimation command |
| `hddid_dgp1` | Generate DGP1 simulation data (homoscedastic, independent X) |
| `hddid_dgp2` | Generate DGP2 simulation data (heteroscedastic, correlated X) |

## Syntax

```
hddid depvar [if] [in], treat(varname) x(varlist) z(varname) [options]
```

The dependent variable `depvar` should be the outcome change $\Delta Y = Y(1) - Y(0)$, not a level outcome.

### Main Options

| Option | Description | Default |
|--------|-------------|---------|
| `treat(varname)` | Binary treatment indicator (0/1) | Required |
| `x(varlist)` | High-dimensional covariates | Required |
| `z(varname)` | Low-dimensional covariate for nonparametric component | Required |
| `method(string)` | Sieve basis: `Pol` (polynomial) or `Tri` (trigonometric) | `Pol` |
| `q(#)` | Sieve basis order; under `Tri`, the harmonic degree is `q/2`, so `q(8)` yields a 4th-degree trigonometric basis | 8 |
| `k(#)` | Number of cross-fitting folds (minimum 2) | 3 |
| `alpha(#)` | Significance level for confidence intervals | 0.1 |
| `nboot(#)` | Number of Gaussian bootstrap replications (minimum 2) | 1000 |
| `seed(#)` | Random seed for fold assignment, bootstrap, and CLIME CV | -1 (no seed) |
| `z0(numlist)` | Evaluation points for the nonparametric component | Unique retained z values |
| `nofirst` | Skip first-stage estimation; requires `pihat()`, `phi1hat()`, `phi0hat()` | — |
| `verbose` | Print fold-level diagnostics | — |

### Postestimation

After `hddid`, the following `predict` options are available:

| Command | Description |
|---------|-------------|
| `predict newvar` | Default: full ATT prediction $\hat\tau = X'\hat\beta^d + \hat{f}(Z)$ |
| `predict newvar, xb` | Linear component $X'\hat\beta^d$ only |
| `predict newvar, fz` | Nonparametric component $\hat{f}(Z)$ only |

### DGP Generator Syntax

```
hddid_dgp1, n(#) p(#) [seed(#) clear]
hddid_dgp2, n(#) p(#) [seed(#) rho(#) clear]
```

| Option | Description | Default |
|--------|-------------|---------|
| `n(#)` | Number of observations | Required |
| `p(#)` | Number of high-dimensional covariates | Required |
| `seed(#)` | Random seed for data generation | -1 (no seed) |
| `rho(#)` | AR(1) correlation parameter (DGP2 only; requires $-1 < \rho < 1$ when $p > 1$) | 0.5 |
| `clear` | Replace existing dataset in memory | — |

## Stored Results

`hddid` stores the following in `e()`:

### Scalars

| Result | Description |
|--------|-------------|
| `e(N)` | Final post-trim retained sample size |
| `e(N_pretrim)` | Pretrim common-score sample count |
| `e(N_trimmed)` | Number of observations trimmed |
| `e(k)` | Number of cross-fitting folds |
| `e(p)` | Dimension of high-dimensional covariates |
| `e(q)` | Sieve basis order |
| `e(qq)` | Number of evaluation points |
| `e(alpha)` | Significance level |
| `e(nboot)` | Number of bootstrap replications |
| `e(seed)` | Random seed (when specified) |

### Matrices

| Result | Description |
|--------|-------------|
| `e(b)` | 1 × p debiased parametric coefficient vector (same as `e(xdebias)`) |
| `e(V)` | p × p parametric variance-covariance matrix |
| `e(xdebias)` | 1 × p debiased parametric estimates |
| `e(stdx)` | 1 × p parametric standard errors |
| `e(gdebias)` | 1 × qq debiased nonparametric estimates (omitted-intercept z-varying block) |
| `e(stdg)` | 1 × qq nonparametric standard errors |
| `e(tc)` | 1 × 2 bootstrap critical-value pair (lower, upper) |
| `e(CIpoint)` | 2 × (p+qq) pointwise confidence interval bounds |
| `e(CIuniform)` | 2 × qq uniform confidence interval bounds for nonparametric component |
| `e(z0)` | 1 × qq evaluation points |
| `e(N_per_fold)` | 1 × k post-trim sample sizes by fold |

### Macros

| Result | Description |
|--------|-------------|
| `e(cmd)` | `hddid` |
| `e(method)` | Sieve basis method (`Pol` or `Tri`) |
| `e(depvar_role)` | Original dependent variable name |
| `e(treat)` | Treatment variable name |
| `e(xvars)` | Covariate names in published beta-coordinate order |
| `e(zvar)` | Z variable name |

### Functions

| Result | Description |
|--------|-------------|
| `e(sample)` | Final post-trim estimation sample indicator |

For a complete list, see `help hddid`.

## Methodology

### Estimation Procedure

The estimation procedure consists of six steps:

1. **K-fold cross-fitting**: Split data into K folds; for each held-out fold, estimate nuisance functions on the remaining folds
2. **First-stage nuisance estimation**: Propensity score $\hat\pi(W)$ via `cvlassologit`; outcome regressions $\hat\Phi_1(W)$, $\hat\Phi_0(W)$ via `cvlasso`
3. **DR score construction**: Form the doubly robust score with propensity trimming at $[0.01, 0.99]$:
$$\hat{S}_i = \hat\rho_i \left(\Delta Y_i - (1-\hat\pi_i)\hat\Phi_1(W_i) - \hat\pi_i \hat\Phi_0(W_i)\right), \quad \hat\rho_i = \frac{D_i - \hat\pi_i}{\hat\pi_i(1-\hat\pi_i)}$$
4. **Second-stage Lasso**: Regress $\hat{S}_i$ on $(X, \psi(Z))$ with Lasso penalty on $X$ only (sieve terms unpenalized)
5. **Debiased inference for $\beta$**: Correct Lasso bias via the CLIME precision matrix estimate $\hat\Omega$:
$$\hat{\beta}^d = \hat{\beta} + \frac{1}{n}\sum_{i=1}^n \hat{\eta}_i \tilde{X}_i' \hat{\Omega}$$
where $\tilde{X} = X - \Pi_{X|Z}$ is the sieve projection residual
6. **Debiased inference for $f(z)$**: One-step update via the M-matrix, with Gaussian bootstrap for uniform confidence bands

### Doubly Robust Score

Under the conditional parallel trends assumption and full support, the CATT is identified via the doubly robust estimand:

$$\tau_0(W) = E\left[\rho_0 \left(\Delta Y - (1 - \pi(W))\Phi_1(W) - \pi(W)\Phi_0(W)\right) \mid W\right]$$

This estimand remains consistent when either the propensity score or the outcome regressions are correctly specified.

### Partially Linear Model

The CATT is modeled as:

$$\tau_0(X, Z) = X'\beta_0 + f_0(Z)$$

where $X \in \mathbb{R}^p$ is high-dimensional (possibly $p > n$) and $f_0: \mathcal{Z} \to \mathbb{R}$ is approximated by a sieve basis $\psi^{k_n}(Z)'\gamma$.

### Inference

- **Parametric component**: The debiased estimator $\hat\beta^d$ achieves $\sqrt{n}$-normality. Pointwise confidence intervals use the normal approximation.
- **Nonparametric component**: Pointwise normality at each evaluation point $z_0$. Uniform confidence bands are constructed via Gaussian bootstrap critical values.

## References

Ning, Y., Peng, S., & Tao, J. (2024). Doubly robust semiparametric difference-in-differences estimators with high-dimensional data. *Review of Economics and Statistics*, 106(4), 1063–1080.

## Authors

**Stata Implementation:**

- **Xuanyu Cai**, City University of Macau
  Email: [xuanyuCAI@outlook.com](mailto:xuanyuCAI@outlook.com)
- **Wenli Xu**, City University of Macau
  Email: [wlxu@cityu.edu.mo](mailto:wlxu@cityu.edu.mo)

**Methodology:**

- **Yang Ning**, Cornell University
- **Sida Peng**, Microsoft Research
- **Jing Tao**, University of Washington

## License

AGPL-3.0. See [LICENSE](LICENSE) for details.

## Citation

If you use this package in your research, please cite both the methodology paper and the Stata implementation:

**APA Format:**

> Cai, X., & Xu, W. (2025). *hddid: Stata module for doubly robust semiparametric difference-in-differences estimation with high-dimensional data* (Version 1.0.0) [Computer software]. GitHub. https://github.com/gorgeousfish/hddid
>
> Ning, Y., Peng, S., & Tao, J. (2024). Doubly robust semiparametric difference-in-differences estimators with high-dimensional data. *Review of Economics and Statistics*, 106(4), 1063–1080.

**BibTeX:**

```bibtex
@software{hddid2025stata,
  title={hddid: Stata module for doubly robust semiparametric difference-in-differences estimation with high-dimensional data},
  author={Xuanyu Cai and Wenli Xu},
  year={2025},
  version={1.0.0},
  url={https://github.com/gorgeousfish/hddid}
}

@article{ning2024doubly,
  title={Doubly robust semiparametric difference-in-differences estimators with high-dimensional data},
  author={Ning, Yang and Peng, Sida and Tao, Jing},
  journal={Review of Economics and Statistics},
  volume={106},
  number={4},
  pages={1063--1080},
  year={2024}
}
```

## See Also

- Original R package by Ning, Peng, and Tao: https://github.com/psdsam/HDdiffindiff
- Paper: Ning, Y., Peng, S., & Tao, J. (2024). *Review of Economics and Statistics*, 106(4), 1063–1080. https://arxiv.org/abs/2009.03151
