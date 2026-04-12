{smcl}
{* *! version 1.0.0  2026-03-12}{...}
{viewerjumpto "Syntax" "hddid_dgp2##syntax"}{...}
{viewerjumpto "Description" "hddid_dgp2##description"}{...}
{viewerjumpto "Options" "hddid_dgp2##options"}{...}
{viewerjumpto "Generated variables" "hddid_dgp2##generated"}{...}
{viewerjumpto "Notes" "hddid_dgp2##notes"}{...}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:hddid_dgp2} {hline 2}}Generate DGP2 data for {cmd:hddid}{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:hddid_dgp2}{cmd:,}
{opt n(#)}
{opt p(#)}
[{opt seed(#)} {opt rho(#)} {opt clear}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:hddid_dgp2} generates the package's DGP2 simulation dataset used for
testing and examples.  The design follows the heteroskedastic, correlated-X
data-generating process used in Section 5 of the HDDID paper.
{p_end}

{pstd}
Compared with {cmd:hddid_dgp1}, DGP2 uses AR(1)-style correlation across the
high-dimensional covariates and the paper's multiplicative baseline outcome
construction {cmd:Y(i,0) = eps_tilde * (z + x1) / sqrt(2)}.
{p_end}

{pstd}
If memory already contains an existing dataset, including a 0-observation
dataset with variables already defined, you must specify {opt clear} before
{cmd:hddid_dgp2} replaces it.  A metadata-only empty surface (for example
dataset characteristics or value labels with no variables and no observations)
does not require {opt clear}.
{p_end}

{pstd}
The shipped command carries its correlated-X draw path internally, so an
absolute-path {cmd:run "/path/to/hddid_dgp2.ado"} remains callable even when
the caller's {cmd:c(pwd)} or unrelated package globals point elsewhere.
The public command does not reload any discoverable sibling helper file during
generation; instead it uses an inline drawnorm-based correlated-X path and the
embedded Section 5 generator is authoritative for the user-facing DGP2
contract.
{p_end}

{pstd}
More specifically, {cmd:hddid_dgp2} draws X ~ N(0, Sigma) with
Sigma_jk = rho^|j-k|, draws {cmd:z} and {cmd:eps_tilde} from standard normal
distributions, sets the same logistic treatment assignment rule as DGP1, and
constructs the observed base-period outcome {cmd:Y(i,0)}

{pmore}
Y(i,0) = eps_tilde * (z + x1) / sqrt(2).

{pstd}
Under the shipped no-anticipation implementation, that is the same observed
baseline draw used by both post-period treatment states before their
state-specific increments are added.
{p_end}

{pstd}
It then uses the same beta^1_i = 2/i, beta^0_i = 1/i for i <= 15,
{cmd:exp(z)} nonparametric component, and independent standard normal
post-period shocks {cmd:eps0} and {cmd:eps1} as in the paper's DGP2.
The generated public outcome is the realized post-minus-base change stored in
{cmd:deltay}; it is not the post-period treatment-state contrast
{cmd:Y^1(i,1) - Y^0(i,1)}.  Running hddid on this generated deltay sample
means the returned parametric block targets the ATT-surface contrast
beta_j = beta^1_j - beta^0_j = 1/j on that support, and the returned nonparametric block is the public omitted-intercept z-varying block
aligned to the posted evaluation grid, not either raw treated- or control-outcome slope sequence by itself. Because {cmd:hddid} does not currently publish {cmd:e(a0)}, that public block is not the full paper
level {cmd:f(z0) = exp(z0)}. Public truth checks should therefore compare centered differences on the posted evaluation grid rather than uncentered levels. The full heterogeneous ATT at a test point still contains the separate stage-2 intercept a0.
This public DGP2 surface is therefore not a full ATT-level oracle at a test point: it exposes the beta-side truth and the centered omitted-intercept z-varying shape on the posted {cmd:z0()} grid, not the full level {cmd:x0'beta + f(z0)}.
{p_end}

{pstd}
For the shipped generator, the paper's coefficient sequences are truncated to
the requested covariate width.  When {cmd:p() < 10}, only the theta_0 entries
through i = p are used in the propensity score.  When {cmd:p() < 15},
beta^1_i = 2/i and beta^0_i = 1/i only through i = p, so small-{cmd:p()}
calls are a lower-dimensional truncation of the paper's DGP2 rather than the
full Section 5 design.
{p_end}

{marker options}{...}
{title:Options}

{phang}
{opt n(#)} specifies the number of observations to generate. {cmd:n()} must be
an integer greater than or equal to 1.
That lower bound is only the data-generation contract.  The degenerate
{cmd:n(1)} case is still a generator-valid toy draw.  It is not a downstream {cmd:hddid} estimation run.  A downstream
{cmd:hddid} run still needs both treatment arms represented on the usable
score / fold-pinning sample and at least {cmd:K} observations in each represented arm.  The maintained paper/R split then assigns the outer map as contiguous current-row blocks on the fold-pinning sample, so {cmd:K()} cannot exceed the number of nonempty row blocks implied by that sample size.  In plain terms, very small {cmd:n()} values are generator probes rather than estimation-ready examples because one observation cannot supply the treated/control overlap and cross-fitting structure.
{p_end}

{phang}
{opt p(#)} specifies the number of high-dimensional covariates to generate.
{cmd:p()} must be an integer greater than or equal to 1.  The command creates
variables {cmd:x1} through {cmd:xp}.  The current implementation also needs
room for 13 additional temporary variables at peak, so very large {cmd:p()}
values can be rejected by Stata's {cmd:maxvar} limit before generation starts.
Relative to the paper's DGP2, {cmd:p()<10} truncates the propensity-score
theta_0 sequence and {cmd:p()<15} truncates the nonzero beta^1/beta^0
sequence.
{p_end}

{phang}
{opt seed(#)} sets the Stata random-number seed before generation. If omitted,
the command does not reset the seed and instead continues from the caller's
current Stata session RNG state. {cmd:seed()} accepts integers in
{cmd:[0, 2147483647]} or {cmd:-1} (default, no seed reset).
{p_end}

{phang}
{opt rho(#)} specifies the AR(1)-style correlation parameter used in the
covariate covariance matrix.  The default is {cmd:rho(0.5)}.  It must
satisfy {cmd:-1 < rho < 1} when {cmd:p()>1}, because the implied Toeplitz
covariance is positive definite only on that open interval: exact
{cmd:rho()} = {cmd:-1} or {cmd:1} is a singular boundary case when
{cmd:p()>1}, and values beyond that boundary are not valid covariances; the
public DGP2 command rejects those boundary values instead of passing a
singular covariance into {cmd:drawnorm}.  When {cmd:p(1)}, the covariance
collapses to the 1 x 1 matrix {cmd:[1]} because Sigma_11 = rho^0 = 1 for any
finite {cmd:rho}, so the one-covariate DGP2 path accepts any finite
{opt rho()} value instead of rejecting an otherwise equivalent draw.
{p_end}

{phang}
{opt clear} permits {cmd:hddid_dgp2} to replace an existing dataset already in
memory, including a 0-observation dataset with variables already defined.
Without {opt clear}, the command refuses to overwrite caller data whenever the
current data surface still has variables or observations.  A metadata-only
empty surface (dataset characteristics or value labels with no variables and
no observations) is treated as empty and therefore does not need {opt clear}.
{p_end}

{marker generated}{...}
{title:Generated Variables}

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{cmd:x1} ... {cmd:xp}}double-precision correlated Gaussian covariates{p_end}
{synopt:{cmd:z}}standard normal nonparametric covariate{p_end}
{synopt:{cmd:treat}}Bernoulli treatment indicator drawn from the DGP propensity score{p_end}
{synopt:{cmd:deltay}}post-minus-base outcome change{p_end}
{synoptline}

{marker notes}{...}
{title:Notes}

{phang}
If memory already contains an existing dataset, including a 0-observation
dataset with variables already defined, {cmd:hddid_dgp2} requires
{opt clear} before it replaces that dataset.  A metadata-only empty surface
with no variables and no observations does not require {opt clear}.
{p_end}

{phang}
If {cmd:hddid_dgp2} fails after generation starts, the command restores the
caller dataset instead of leaving behind a partially built replacement.
{p_end}

{phang}
When {opt seed()} is supplied with an integer in {cmd:[0, 2147483647]},
{cmd:hddid_dgp2} restores the caller's RNG state on exit, so the explicit
seed only controls the generated DGP sample itself.  The explicit sentinel
{cmd:seed(-1)} is the same no-reset path as omitting {opt seed()}: the
command does not reset the RNG before generation and therefore advances the
caller RNG stream in the usual way after a successful draw.  If generation
fails after stochastic work has started, even the omitted-seed / {cmd:seed(-1)}
path restores the caller RNG state before returning the error because no new
DGP sample was published.
{p_end}

{phang}
For the current package version, users should treat {cmd:deltay} as the
dependent variable passed to {cmd:hddid}.
{p_end}

{phang}
A shipped DGP2/Tri walkthrough handoff is: generate the sample with {cmd:hddid_dgp2, n(500) p(50) seed(54321) rho(0.5) clear}, rebuild the public covariate list with {cmd:unab x_vars : x*}, and then run {cmd:hddid deltay, treat(treat) x(`x_vars') z(z)} with {cmd:method("Tri") q(16)} plus the shipped five-point audit grid {cmd:z0(-1 -0.5 0 0.5 1)}, {cmd:K(3)}, the shipped 90% inference level {cmd:alpha(0.1)}, the shipped bootstrap count {cmd:nboot(1000)}, and the shipped estimator-side reproducibility seed {cmd:seed(42)}.  That is the positive user-facing pairing behind the shipped walkthrough when users want the package's shipped DGP2/Tri walkthrough rather than only a generator draw, and it keeps the reported finite-grid nonparametric surface pinned to the same public audit points used in the example/help truth checks on the package-default public AR(1) path {cmd:rho(0.5)} rather than a paper-fixed rho value.  The shipped five-point {cmd:z0(-1 -0.5 0 0.5 1)} list is this package audit grid rather than a paper-fixed evaluation set.  Use that shipped five-point grid only when the realized retained {cmd:z} support contains all five audit points; otherwise choose an in-support {cmd:z0()} list or omit {cmd:z0()} so {cmd:hddid} uses the retained support points directly.
Under {cmd:method(Tri)}, keep that explicit {cmd:z0()} grid inside the current retained {cmd:z} support.
if any requested {cmd:z0()} point leaves that retained support, {cmd:hddid} fails closed instead of extrapolating the support-normalized Tri basis.
That retained-support guard is a package-specific Stata Tri rule: this walkthrough uses a caller-supplied/package audit grid rather than a paper-fixed evaluation set, and the maintained R cross-fit sources here do not expose an executable {cmd:method(Tri)} fail-close interface.
{p_end}

{phang}
Following the paper, the post-period shocks {cmd:eps0} and {cmd:eps1} are both
standard normal.  The distinctive DGP2 feature is the multiplicative baseline
term, which makes the observed base-period level outcome heteroskedastic before
differencing.
{p_end}

{phang}
The public DGP2 command is self-contained enough to remain callable after an
absolute-path source-run even when the working directory is elsewhere, because
the shipped ado builds the covariance matrix inline and uses an internal
{cmd:drawnorm} call instead of reloading any helper-side generator.  The
shipped ado's embedded Section 5 path remains authoritative for the public
DGP2 command.
{p_end}

{phang}
Only the public variables {cmd:x1}-{cmd:xp}, {cmd:z}, {cmd:treat}, and
{cmd:deltay} are kept.  The observed base-period outcome draw and other
internal intermediates used to generate the paper's DGP are dropped before
return.
The shipped Stata DGP is therefore not a drop-in input to the {cmd:hddid-r}
crossfit API, which is written for {cmd:y0}/{cmd:y1} level outcomes rather
than the already-differenced {cmd:deltay} surface.
{p_end}

{phang}
Cross-language validation note: this shipped DGP2 generator follows the paper's
Section 5 construction and the package's paper oracle tests.  Do not treat the
historical R wrapper name {cmd:Examplehighdimdiffindiff.R} as the DGP2 oracle:
that wrapper file still ships under {cmd:hddid-r/R}, but the legacy code path
documented by that name is not a runnable oracle against the shipped R
sources.  That old wrapper called {cmd:highdimdiffindiff_crossfit()} while the
shipped cross-fit entry point here is {cmd:highdimdiffindiff_crossfit3()}.  Even
patching that wrapper onto {cmd:highdimdiffindiff_crossfit3()} still does not
rescue the shipped R tree as runnable oracle code.  A rename-only patch already
fails at the public R API layer: {cmd:Examplehighdimdiffindiff.R} passes
{cmd:method=...} while {cmd:highdimdiffindiff_crossfit3(y0, y1, treat, x, z, q, k, z0, alp)}
requires z0 and alp and does not accept {cmd:method}, so that patched wrapper
first throws the concrete R error {cmd:unused argument (method = method)}.  Even
after that signature mismatch, {cmd:highdimdiffindiff_crossfit3()} source()s
missing {cmd:highdimdiffindiff_crossfit_inside3.r}, and its {cmd:CIuniform} line
references undefined debias instead of {cmd:gdebias}.  That file
re-draws z after building the baseline outcome, so the observed {cmd:z}
in the wrapper no longer matches the same paper DGP2 covariate used in both
the baseline term and {cmd:exp(z)}.  The wrapper also defaults to
{cmd:method="Pol"} even though the paper's Section 5 simulations use an 8th
degree trigonometric ({cmd:Tri}) basis.  More fundamentally, the legacy
cross-fit code hardcodes the polynomial sieve regardless of the method
argument, so wrapper {cmd:method="Tri"} does not actually switch that path
onto a trigonometric basis.  The wrapper's own roxygen also documents
{cmd:q} as {cmd:q/2}, but the shipped cross-fit code passes {cmd:q} directly
into {cmd:sieve.Pol(..., q)} on that hardcoded polynomial path, so even the
wrapper's nominal basis-order description drifts from its executable code. In
plain terms, the legacy wrapper documents q as q/2 but the shipped cross-fit
code passes q directly into sieve.Pol(..., q).
Under this package's {cmd:q()} indexing,
{cmd:q(8)} yields a 4th degree trigonometric basis, so matching the paper's
8th degree Tri basis would require {cmd:q(16)} rather than {cmd:q(8)}.
It also exposes a {cmd:rho.X} argument but still hardcodes the
correlated-{cmd:X} covariance as {cmd:0.5^|j-k|}, so the wrapper ignores
nondefault DGP2 correlation choices.  It also hardcodes the theta_0/omega0
setup loops as {cmd:1:10} rather than truncating them at {cmd:p()}, so small-
{cmd:p()} calls such as {cmd:p()<10} can extend those vectors beyond the
simulated {cmd:X} width and eventually fail with {cmd:non-conformable
arguments} instead of reproducing the paper's truncated DGP2.
For the maintained R estimator reference, inspect
those files as a read-only source reference, not a public wrapper/script entrypoint to source() directly:
{cmd:hddid-r/R/highdimdiffindiff_crossfit.R} together with
{cmd:hddid-r/R/highdimdiffindiff_crossfit_inside.R}: those files carry the
surviving shipped estimator logic, specifically the
{cmd:highdimdiffindiff_crossfit3()} entrypoint and the
{cmd:highdimdiffindiff_crossfit_inside3()} helper, even though the public Stata
DGP generators here publish {cmd:deltay} rather than the {cmd:y0}/{cmd:y1}
level outcomes that the R cross-fit code expects.
{p_end}

{phang}
To reproduce this shipped DGP2/Tri walkthrough on the generated sample, pass {cmd:deltay} to {cmd:hddid},
rebuild the generated public {cmd:x*} varlist with {cmd:unab x_vars : x*}, pass {cmd:x(`x_vars')} with {cmd:z(z)} and {cmd:treat(treat)},
and keep the DGP2 generator on its package-default public AR(1) path {cmd:rho(0.5)} rather than a paper-fixed rho value together with the shipped estimator settings {cmd:method("Tri")}, {cmd:q(16)}, {cmd:z0(-1 -0.5 0 0.5 1)}, {cmd:K(3)}, {cmd:alpha(0.1)}, {cmd:nboot(1000)}, and {cmd:seed(42)}.
Those settings are the positive public counterpart to the legacy-wrapper caveat above: they keep the
shipped DGP2 data on the same trigonometric-basis / 3-fold cross-fit contract exercised by the package's
shipped DGP2/Tri walkthrough on the same shipped public evaluation grid and the same fold/bootstrap/CLIME RNG path used by the example/help truth checks.  The shipped five-point {cmd:z0(-1 -0.5 0 0.5 1)} list is this package audit grid rather than a paper-fixed evaluation set.
Under {cmd:method(Tri)}, keep that explicit {cmd:z0()} grid inside the current retained {cmd:z} support.
if any requested {cmd:z0()} point leaves that retained support, {cmd:hddid} fails closed instead of extrapolating the support-normalized Tri basis.
That retained-support guard is a package-specific Stata Tri rule: this walkthrough uses a caller-supplied/package audit grid rather than a paper-fixed evaluation set, and the maintained R cross-fit sources here do not expose an executable {cmd:method(Tri)} fail-close interface.
The maintained R cross-fit sources remain a read-only polynomial reference here: they do not accept method(Tri) and still hardcode sieve.Pol(..., q), so they are a source reference for the surviving score path rather than executable Tri-basis parity.
{p_end}

{phang}
The generation path is also constrained by Stata's variable-capacity limit.
Before clearing memory, {cmd:hddid_dgp2} checks whether the requested
{cmd:p()} plus its temporary working variables fit under the current
{cmd:maxvar} setting, and it exits with an error if that budget is infeasible.
{p_end}
