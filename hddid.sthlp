{smcl}
{viewerjumpto "Syntax" "hddid##syntax"}{...}
{viewerjumpto "Description" "hddid##description"}{...}
{viewerjumpto "Options" "hddid##options"}{...}
{viewerjumpto "Postestimation" "hddid##postestimation"}{...}
{viewerjumpto "Stored results" "hddid##results"}{...}
{viewerjumpto "Examples" "hddid##examples"}{...}
{viewerjumpto "References" "hddid##references"}{...}
{viewerjumpto "Authors" "hddid##authors"}{...}

{title:Title}

{p2colset 5 18 20 2}{...}
{p2col:{cmd:hddid} {hline 2}}High-dimensional doubly robust semiparametric
difference-in-differences estimator{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:hddid}
{depvar} [{it:if}] [{it:in}]
{cmd:,}
{cmdab:treat:(}{varname}{cmd:)}
{cmdab:x:(}{varlist}{cmd:)}
{cmdab:z:(}{varname}{cmd:)}
[{it:options}]

{synoptset 28 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt treat(varname)}}binary treatment indicator{p_end}
{synopt:{opt x(varlist)}}high-dimensional covariates; must not contain a nonzero constant column{p_end}
{synopt:{opt z(varname)}}low-dimensional covariate for nonparametric component{p_end}

{syntab:Model}
{synopt:{opt method(string)}}sieve basis: {cmd:Pol} (polynomial, default) or {cmd:Tri} (trigonometric){p_end}
{synopt:{opt q(#)}}sieve basis order; default {cmd:q(8)}; under {cmd:Tri}, q must be even{p_end}
{synopt:{opt K(#)}}outer cross-fitting folds; minimum 2; default {cmd:K(3)}{p_end}

{syntab:Inference}
{synopt:{opt alpha(#)}}significance level; default {cmd:alpha(0.1)} (90% CIs){p_end}
{synopt:{opt nboot(#)}}Gaussian bootstrap replications; minimum 2; default {cmd:nboot(1000)}{p_end}
{synopt:{opt seed(#)}}RNG seed for fold assignment, bootstrap, and CLIME CV; default {cmd:seed(-1)} (no reset); caller RNG restored on exit{p_end}

{syntab:Evaluation points}
{synopt:{opt z0(numlist)}}evaluation points for f(Z); default is unique retained values of {cmd:z}{p_end}

{syntab:Advanced}
{synopt:{opt nofirst}}skip first-stage estimation; requires {cmd:pihat()}, {cmd:phi1hat()}, {cmd:phi0hat()}{p_end}
{synopt:{opt pihat(varname)}}pre-estimated propensity score; values in [0,1]; requires {cmd:nofirst}{p_end}
{synopt:{opt phi1hat(varname)}}pre-estimated treated-group nuisance prediction; requires {cmd:nofirst}{p_end}
{synopt:{opt phi0hat(varname)}}pre-estimated control-group nuisance prediction; requires {cmd:nofirst}{p_end}
{synopt:{opt verbose}}print fold-level diagnostic output{p_end}
{synoptline}

{marker description}{...}
{title:Description}

{pstd}
{cmd:hddid} implements the doubly robust semiparametric
difference-in-differences estimator proposed by
{help hddid##NPT2024:Ning, Peng, and Tao (2024)} for settings with
high-dimensional covariates.  The estimator targets the conditional average
treatment effect on the treated (CATT) under a partially linear model:
E[Y^1(1) - Y^0(1) | X, Z, D=1] = X'{it:beta} + f(Z), where {it:beta} is a
p-dimensional parametric component and f(.) is an unknown smooth function
estimated nonparametrically via sieve approximation.  The reported estimand is
therefore the retained-overlap version of that paper target after the
command's overlap trimming rule.
{p_end}

{pstd}
The paper's identifying sampling scheme is repeated cross-sections rather than
a generic panel-DiD workflow.  The estimator is therefore used under the
paper's conditional parallel trends and full support assumptions after
conditioning on {cmd:W=(X,Z)}.
{p_end}

{pstd}
Replay usage: bare {cmd:hddid} with no arguments, no {it:if}/{it:in}
qualifiers, no weights, and no options prints the stored results.  Replay
does not accept {cmd:level()}, weights, or sample qualifiers.  To change
confidence levels, re-estimate with {cmd:alpha()}.
{p_end}

{pstd}
Replay validates the stored saved-results contract before display and prints
the first-stage path (internal or {cmd:nofirst}), the estimator label
{cmd:AIPW (doubly robust)}, the seed provenance when available, and
{cmd:method(Tri)} support endpoints when applicable.  After
{cmd:estimates store}/{cmd:estimates use}, replay can still display the stored
HDDID surface even if the current data no longer match the original sample.
{p_end}

{pstd}
The dependent variable {cmd:depvar} should be the outcome change
{it:Delta Y} used by the DiD score construction, not a level outcome.
In the typical two-period workflow this means a variable such as
{cmd:deltay = y1 - y0}.
{p_end}

{pstd}
The role variables {cmd:depvar}, {opt treat()}, {opt x()}, and {opt z()}
are intended to be mutually distinct.  In particular, the treatment
indicator should not be reused as {opt z()}, {cmd:depvar} should not also be
used as {opt treat()} or {opt z()}, and {cmd:depvar} should not appear inside
{opt x()}. Variables reserved for {opt treat()} or {opt z()} should not also
appear inside {opt x()}. Variables inside {opt x()} must also be unique.
Under {opt nofirst}, the nuisance-input variables named in {opt pihat()},
{opt phi1hat()}, and {opt phi0hat()} must likewise be distinct from
{cmd:depvar}, {opt treat()}, {opt x()}, and {opt z()}.  They must also be
numerically well defined for their separate nuisance roles.  Within that
boundary, {opt pihat()}, {opt phi1hat()}, and {opt phi0hat()} may alias one
another when the supplied nuisance predictions are numerically identical
because {cmd:hddid} copies each role into separate working variables before
estimation.
In addition, on every retained evaluation fold the
columns named in {opt x()} must remain distinct from the full sieve basis used
for {it:f(z)}; if an {opt x()} column is exactly absorbed by that basis (for
example, {cmd:x2 = z} under {cmd:method(Pol)} with {cmd:q(1)}), {cmd:hddid}
stops with an identification error instead of publishing a non-unique
parametric/nonparametric decomposition.
{p_end}

{pstd}
The estimation procedure consists of six steps:
(1) K-fold cross-fitting with Lasso first-stage estimation of the propensity
score ({cmd:cvlassologit}) and outcome regressions ({cmd:cvlasso}), with a
fold-external sample-mean fallback when an arm-specific training outcome is
constant or the arm-specific nuisance-fit {bf:W=(X,Z-basis)} design is
constant;
(2) construction of doubly robust scores using the cross-fitted nuisance
estimates;
(3) penalized second-stage Lasso regression of the DR scores on covariates
and sieve basis functions, where sieve basis terms are left unpenalized;
(4) CLIME-based debiasing of the parametric component {it:beta};
(5) Lasso estimation of the M-matrix and debiasing of the nonparametric
component f(.);
(6) Gaussian bootstrap for the lower/upper studentized-process endpoint pair and construction of
the published {cmd:e(CIuniform)} nonparametric interval object.
{p_end}

{pstd}
For each evaluation fold, the command forms the doubly robust score
{p_end}

{pmore}
rho_i = (D_i - pihat_i) / (pihat_i * (1 - pihat_i))
{p_end}

{pmore}
newy_i = rho_i * (Delta Y_i - (1 - pihat_i) * phi1hat_i - pihat_i * phi0hat_i)
{p_end}

{pstd}
then trims observations with {cmd:pihat} outside [{cmd:0.01}, {cmd:0.99}]
before the second-stage partially linear fit.  The common score sample must
contain both treatment arms before overlap trimming.
{p_end}

{pstd}
The published nonparametric surface is the omitted-intercept z-varying block.
In particular, {cmd:e(gdebias)} excludes the separate stage-2 intercept {cmd:a0},
and the nonparametric columns of {cmd:e(CIpoint)} and {cmd:e(CIuniform)}
follow that same omitted-intercept block on the posted {cmd:e(z0)} grid.
{cmd:hddid} does not currently publish {cmd:e(a0)}, so those public objects
should not be treated as the full level {cmd:f(z0)} surface or combined with
{cmd:e(b)} to claim a full ATT level.
{p_end}

{pstd}
{cmd:hddid} requires {cmd:lassopack} ({cmd:lasso2}, {cmd:cvlasso},
{cmd:cvlassologit}).  When {cmd:x()} has more than one covariate, Stata 16+
Python integration with {cmd:numpy>=1.20} and {cmd:scipy>=1.7} is also
required for the CLIME debiasing path.  With a single {cmd:x()} covariate,
the analytic scalar precision shortcut is used and Python is not needed.
{p_end}

{pstd}
Install with {cmd:net install hddid, from("/path/to/hddid-main") replace}.
To also get the shipped walkthrough: {cmd:net get hddid, from("/path/to/hddid-main")},
then run {cmd:findfile hddid_example.do} followed by {cmd:do "`r(fn)'"}.
Verify installation with {cmd:which hddid} and {cmd:python query}.
{p_end}

{pstd}
The current implementation is also subject to Stata variable and matrix
capacity limits.  In particular, {cmd:hddid} allocates additional temporary
variables for fold bookkeeping and sieve bases, and the CLIME / {cmd:z0()}
paths must fit inside Stata's matrix-dimension limit.  Very large choices of
{cmd:x()}, {cmd:q()}, sample size per fold, or the number of evaluation
points can therefore be rejected before estimation starts.
{p_end}

{marker options}{...}
{title:Options}

{dlgtab:Required}

{phang}
{opt treat(varname)} specifies the binary treatment indicator variable.
It must take values 0 (control) and 1 (treated).
{p_end}

{phang}
{opt x(varlist)} specifies the high-dimensional covariates X.  The dimension
p may exceed the sample size n.  These variables enter the parametric
component X'{it:beta} of the CATT model.  The {cmd:x()} varlist must not
repeat {cmd:treat()} or {cmd:z()}, must not repeat the same covariate, and
must not contain a nonzero constant column on the estimation sample.
{p_end}

{phang}
{opt z(varname)} specifies the low-dimensional continuous covariate Z for
the nonparametric component f(Z).  Only one variable is supported in the
current version.  The {cmd:z()} variable must be distinct from the variable
named in {cmd:treat()}, and it must not also appear inside {cmd:x()}.
{p_end}

{dlgtab:Model}

{phang}
{opt method(string)} specifies the type of sieve basis functions used to
approximate f(Z).  {cmd:Pol} (the default) uses a polynomial basis
{1, z, z^2, ..., z^q}.  {cmd:Tri} uses a trigonometric polynomial basis
with harmonics k = 1, ..., q/2 on support-normalized z.  Under {cmd:Tri},
q must be even.  The command always uses the AIPW doubly robust estimator;
{cmd:method()} only chooses the sieve basis, not the estimator family.
{p_end}

{phang}
{opt q(#)} specifies the sieve basis order.  Default is {cmd:q(8)}.
For {cmd:method(Pol)}, this produces q+1 basis functions.  For
{cmd:method(Tri)}, q must be even and produces q+1 basis functions.
Because the Tri basis uses harmonics k = 1, ..., q/2,
{cmd:q(8)} is only a 4th degree trigonometric basis.  The paper's 8th-degree
Tri baseline corresponds to {cmd:q(16)}.  If the fold-level sieve system is
singular, reduce {cmd:q()}, change {cmd:method()}, or ensure richer
fold-level support in {cmd:z()}.
{p_end}

{phang}
{opt K(#)} specifies the number of outer cross-fitting folds.  Default is
{cmd:K(3)}, minimum 2.  This controls only the outer sample split; internal
CV fold counts for propensity (3), outcome (5), second-stage (3), M-matrix
(10), and CLIME (up to 5) are fixed internally.
The outer split uses contiguous row-order blocks on the common score sample,
matching the paper/R cross-fit split.  Each outer fold must contain at least
one common-score observation from each treatment arm.
{p_end}

{dlgtab:Inference}

{phang}
{opt alpha(#)} specifies the significance level for confidence intervals
and the published {cmd:e(CIuniform)} interval object.  Default is
{cmd:alpha(0.1)}, yielding 90% pointwise CIs.  Must be strictly between 0
and 1.
{p_end}

{phang}
{opt nboot(#)} specifies the number of Gaussian bootstrap replications
used to construct {cmd:e(tc)} and {cmd:e(CIuniform)}.  Default is
{cmd:nboot(1000)}, minimum 2.  Changing {cmd:nboot()} recalibrates only the
bootstrap {cmd:e(tc)}/{cmd:e(CIuniform)} path; it does not affect the analytic
pointwise {cmd:e(CIpoint)}, {cmd:e(stdx)}, or {cmd:e(stdg)} objects.
The {cmd:e(CIuniform)} interval is bootstrap-calibrated on a finite grid but
is not a paper-proven simultaneous-coverage guarantee.
{p_end}

{phang}
{opt seed(#)} optionally sets the command's random number seed before
estimation.  If {cmd:seed()} is an integer in [0, 2147483647], it controls the
outer fold assignment, the bootstrap draws, and the Python CLIME CV splitting.
Default is {cmd:seed(-1)} (no seed reset).  {cmd:seed(0)} is a legal seeded
run, not an alias for {cmd:seed(-1)}.  When a nonnegative seed is used,
{cmd:hddid} restores the caller's prior session RNG state on exit.
{p_end}

{dlgtab:Evaluation points}

{phang}
{opt z0(numlist)} specifies the evaluation points at which the
nonparametric function f(Z) is estimated.  If omitted, the current
implementation uses the unique retained values of {cmd:z} on the final
post-trim estimation sample after {it:if}/{it:in} filtering,
missing-value screening, and overlap trimming.  In other words, omitted
{cmd:z0()} follows the realized support that reaches the second-stage
estimation path, not additional {cmd:z()} values present only in rows
later removed from {cmd:e(sample)}.  Under {cmd:method(Tri)}, the same
retained support normalization used for {cmd:z()} is also applied to
{cmd:z0()} before constructing the trigonometric basis, and explicitly
supplied {cmd:z0()} points must lie inside that retained support so the
command does not silently alias periodic extrapolation points.  Because the
posted nonparametric results are defined only on this evaluation grid, a
very large {cmd:z0()} list may hit Stata's matrix-dimension limit.
{p_end}

{phang}
When {cmd:method(Tri)} is used, {cmd:z()} must vary on the estimation sample.
If the retained {cmd:z()} support collapses to a single value after
{it:if}/{it:in} filtering, missing-value screening, and any overlap trimming
on the retained post-trim estimation sample, the support-normalized
trigonometric basis is undefined and the command exits with an error.
{p_end}

{dlgtab:Advanced}

{phang}
{opt nofirst} skips the first-stage estimation of nuisance functions.
When specified, {opt pihat()}, {opt phi1hat()}, and {opt phi0hat()} must
all be provided.  The supplied nuisance variables must be fold-aligned
out-of-fold predictions on {cmd:hddid}'s own deterministic outer-fold
assignment.  {opt pihat()} must be fold-aligned on the broader
strict-interior pretrim fold-feasibility sample with
{cmd:0 < pihat() < 1}; {opt phi1hat()}/{opt phi0hat()} must be
fold-aligned on the retained overlap sample.  {cmd:hddid} mechanically
checks split-key and same-fold nuisance consistency but cannot verify the
caller's true out-of-fold training provenance.  In-sample fitted values
are invalid input.  Under {cmd:nofirst}, {cmd:if}/{cmd:in} qualifiers
are applied before {cmd:hddid} rebuilds the fold structure.
{p_end}

{phang}
{opt pihat(varname)} specifies pre-estimated propensity scores P(D=1|X,Z).
Values must lie in [0,1] on the common nonmissing score sample.  Observations
with pihat outside [0.01, 0.99] are overlap-trimmed.  Requires {opt nofirst}.
{p_end}

{phang}
{opt phi1hat(varname)} specifies pre-estimated treated-group nuisance
predictions on the same scale as {cmd:depvar}.  Must be fold-aligned
out-of-fold on the retained overlap sample.  Requires {opt nofirst}.
{p_end}

{phang}
{opt phi0hat(varname)} specifies pre-estimated control-group nuisance
predictions on the same scale as {cmd:depvar}.  Must be fold-aligned
out-of-fold on the retained overlap sample.  Requires {opt nofirst}.
{p_end}

{phang}
{opt verbose} prints additional fold-level diagnostics, including selected
lambda values and debiasing status.
{p_end}

{marker postestimation}{...}
{title:Postestimation}

{pstd}
{cmd:predict}, {cmd:estat}, and {cmd:margins} are not supported after
{cmd:hddid}.  The paper publishes aggregate beta and nonparametric objects,
not observation-level predictions.  Use the posted {cmd:e()} matrices directly.
{p_end}

{pstd}
Key postestimation objects:
{p_end}

{p2colset 8 32 34 2}{...}
{p2col:Parametric:}{cmd:e(b)}, {cmd:e(V)}, {cmd:e(xdebias)}, {cmd:e(stdx)}{p_end}
{p2col:Nonparametric:}{cmd:e(gdebias)}, {cmd:e(stdg)}, {cmd:e(z0)}{p_end}
{p2col:Intervals:}{cmd:e(CIpoint)}, {cmd:e(CIuniform)}, {cmd:e(tc)}{p_end}
{p2colreset}{...}

{pstd}
{cmd:e(CIpoint)} first p columns are the beta pointwise CI; remaining qq
columns are the omitted-intercept z-varying pointwise CI.
{cmd:e(CIuniform)} is the bootstrap-calibrated interval object for the
nonparametric component (not a paper-proven simultaneous coverage guarantee).
Because {cmd:hddid} does not publish {cmd:e(a0)}, the public nonparametric
objects support centered comparisons only, not full ATT levels.
{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:hddid} stores the following in {cmd:e()}:

{synoptset 30 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}post-trim retained sample count{p_end}
{synopt:{cmd:e(N_pretrim)}}pretrim common-score sample count{p_end}
{synopt:{cmd:e(N_outer_split)}}fold-pinning sample count{p_end}
{synopt:{cmd:e(rank)}}rank of {cmd:e(V)}{p_end}
{synopt:{cmd:e(k)}}number of cross-fitting folds{p_end}
{synopt:{cmd:e(p)}}dimension of covariates{p_end}
{synopt:{cmd:e(q)}}sieve basis order{p_end}
{synopt:{cmd:e(qq)}}number of evaluation points = width of {cmd:e(z0)}{p_end}
{synopt:{cmd:e(alpha)}}significance level{p_end}
{synopt:{cmd:e(nboot)}}bootstrap replications{p_end}
{synopt:{cmd:e(N_trimmed)}}number of overlap-trimmed observations = {cmd:e(N_pretrim) - e(N)}{p_end}
{synopt:{cmd:e(propensity_nfolds)}}propensity inner CV folds (internal only){p_end}
{synopt:{cmd:e(outcome_nfolds)}}outcome inner CV folds (internal only){p_end}
{synopt:{cmd:e(secondstage_nfolds)}}second-stage inner CV folds{p_end}
{synopt:{cmd:e(mmatrix_nfolds)}}M-matrix inner CV folds{p_end}
{synopt:{cmd:e(clime_nfolds_cv_max)}}max CLIME CV folds requested{p_end}
{synopt:{cmd:e(clime_nfolds_cv_effective_min)}}min realized CLIME CV folds; 0 = skipped{p_end}
{synopt:{cmd:e(clime_nfolds_cv_effective_max)}}max realized CLIME CV folds; 0 = skipped{p_end}
{synopt:{cmd:e(seed)}}RNG seed (only when nonneg seed used){p_end}
{synopt:{cmd:e(z_support_min)}}min of z for Tri normalization{p_end}
{synopt:{cmd:e(z_support_max)}}max of z for Tri normalization{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(xdebias)}}1 x p debiased parametric estimates{p_end}
{synopt:{cmd:e(stdx)}}1 x p parametric standard errors{p_end}
{synopt:{cmd:e(gdebias)}}1 x qq debiased nonparametric estimates{p_end}
{synopt:{cmd:e(stdg)}}1 x qq nonparametric standard errors{p_end}
{synopt:{cmd:e(tc)}}1 x 2 bootstrap critical-value pair (lower, upper){p_end}
{synopt:{cmd:e(CIpoint)}}2 x (p+qq) pointwise CI bounds (lower; upper){p_end}
{synopt:{cmd:e(CIuniform)}}2 x qq uniform interval bounds (lower; upper){p_end}
{synopt:{cmd:e(clime_nfolds_cv_per_fold)}}1 x k realized CLIME CV folds per fold{p_end}
{synopt:{cmd:e(b)}}1 x p coefficient vector (same as e(xdebias)){p_end}
{synopt:{cmd:e(V)}}p x p parametric variance-covariance matrix for {cmd:e(b)}; {cmd:diag(e(V)) = e(stdx)^2}{p_end}
{synopt:{cmd:e(z0)}}1 x qq evaluation points{p_end}
{synopt:{cmd:e(N_per_fold)}}1 x k post-trim fold sample sizes{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:hddid}{p_end}
{synopt:{cmd:e(cmdline)}}full command line{p_end}
{synopt:{cmd:e(vce)}}{cmd:robust}{p_end}
{synopt:{cmd:e(vcetype)}}{cmd:Robust}{p_end}
{synopt:{cmd:e(predict)}}{cmd:hddid_p} (unsupported stub){p_end}
{synopt:{cmd:e(estat_cmd)}}{cmd:hddid_estat} (unsupported stub){p_end}
{synopt:{cmd:e(marginsnotok)}}{cmd:_ALL}{p_end}
{synopt:{cmd:e(firststage_mode)}}{cmd:internal} or {cmd:nofirst}{p_end}
{synopt:{cmd:e(method)}}sieve basis method ({cmd:Pol} or {cmd:Tri}){p_end}
{synopt:{cmd:e(depvar)}}generic beta-block label ({cmd:beta}){p_end}
{synopt:{cmd:e(depvar_role)}}original dependent variable name{p_end}
{synopt:{cmd:e(treat)}}treatment variable name{p_end}
{synopt:{cmd:e(xvars)}}covariate names in published coordinate order{p_end}
{synopt:{cmd:e(zvar)}}z variable name{p_end}
{synopt:{cmd:e(title)}}estimation title{p_end}
{synopt:{cmd:e(properties)}}{cmd:b V}{p_end}

{p2col 5 20 24 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}final post-trim estimation sample used by the second-stage/debiasing path{p_end}
{synoptline}

{marker examples}{...}
{title:Examples}

{pstd}
Before running the multi-{cmd:x()} examples below, first verify Python with {cmd:python query} if needed; if not found, run {cmd:python search} then {cmd:set python_exec} {it:<path>} {cmd:, permanently}, verify Stata 16+
Python integration with {cmd:python query}, and ensure {cmd:numpy>=1.20}
and {cmd:scipy>=1.7} are installed.  The default examples below also use the
internally estimated first-stage path, so they require {cmd:lassopack}'s
default lasso commands ({cmd:lasso2}/{cmd:cvlasso}/{cmd:cvlassologit}) before
the estimation commands will run, plus the documented {cmd:lassologit}
fallback used when the propensity path must recover predictions after
{cmd:cvlassologit} leaves no usable postresults.  For a fuller
prerequisite checklist, see the header comments in the shipped
{cmd:hddid_example.do}.  Users who installed the package via local net
install and want that bundled walkthrough script in their working directory
should use {cmd:net install hddid, from("/path/to/hddid-stata") all replace}
or {cmd:net get hddid, from("/path/to/hddid-stata")}; they can then recover that same installed walkthrough with
{cmd:findfile hddid_example.do} and then run it via {cmd:do "`r(fn)'"}.
{p_end}

{pstd}
The public DGP examples here keep only {cmd:deltay}, so they are not
drop-in inputs to the {cmd:hddid-r} {cmd:y0}/{cmd:y1} crossfit API.
Use them as the Stata package's paper-aligned simulation surface for
{cmd:hddid}, not as level-outcome inputs for the legacy R wrapper.
{p_end}

{pstd}Setup: generate simulation data using DGP1 (homoscedastic, independent covariates){p_end}

{pstd}
In the shipped Stata DGP1 implementation, the paper's time-0 notation is
realized as one shared baseline draw per unit before {cmd:deltay} is formed.
{p_end}

{pstd}
For this DGP1 block, the raw outcome coefficients are
{cmd:beta^1_j = 2/j} and {cmd:beta^0_j = 1/j} for {cmd:j <= 15}, but the
parametric target reported by {cmd:hddid} is the ATT-surface contrast
{cmd:beta_j = beta^1_j - beta^0_j = 1/j} on that support (and 0 afterward).
If you shrink this public example to {cmd:p()<10} or {cmd:p()<15}, the
shipped generator truncates the paper's nonzero {cmd:theta_0} and
{cmd:beta^1}/{cmd:beta^0} sequences at {cmd:p()} rather than holding the full
10/15-support oracle fixed.  This DGP1 block is not a legacy
{cmd:Examplehighdimdiffindiff.R} wrapper shortcut: that wrapper instead
switches onto correlated {cmd:X}, the DGP2-style heteroskedastic baseline,
and a stale wrapper-local {cmd:method=} field whose default is {cmd:"Pol"}.
More fundamentally, that old wrapper still points at an interface shape the
maintained cross-fit entrypoint no longer exposes: the shipped
{cmd:highdimdiffindiff_crossfit3(...)} API does not accept a public
{cmd:method} argument, and the surviving cross-fit code hardcodes the
polynomial sieve while passing {cmd:q} directly into {cmd:sieve.Pol(..., q)}.
So even wrapper-local {cmd:method="Tri"} text plus {cmd:q(16)} there is still
not the paper's Tri-basis DGP1 oracle.  For the
maintained R estimator reference behind this DGP1 surface, read
{cmd:hddid-r/R/highdimdiffindiff_crossfit.R} together with
{cmd:hddid-r/R/highdimdiffindiff_crossfit_inside.R} and treat
{cmd:highdimdiffindiff_crossfit3()}/{cmd:highdimdiffindiff_crossfit_inside3()}
there as the surviving read-only entry symbols rather than a public
wrapper/script entrypoint to source() directly.
If you shrink this DGP call to {cmd:n(1)}, that singleton draw is only a sanity probe: the generator still runs, but {cmd:hddid} immediately fails because the common-score sample loses one treatment arm before overlap trimming.
{p_end}

{phang2}{cmd:. hddid_dgp1, n(500) p(50) seed(12345) clear}{p_end}

{pstd}
The DGP seed {cmd:seed(12345)} above fixes only the generated sample itself.
{cmd:hddid_dgp1} restores the caller RNG state on exit, so that generator seed does not replace the estimator-side {cmd:seed(42)} below for the
realized fold / bootstrap / CLIME path on that sample.
{p_end}

{pstd}
The DGP generators accept {cmd:n()} as small as 1 because generation and
estimation are separate contracts.  A downstream {cmd:hddid} run still needs
both treatment arms represented on the usable score / fold-pinning sample,
at least {cmd:K} observations in each represented arm, and enough
fold-pinning rows for the maintained contiguous row-block split to
realize {cmd:K} nonempty folds, so tiny {cmd:n()} draws are generator
probes rather than
estimation-ready examples.
{p_end}

{pstd}
The public DGP1 generator behind this walkthrough is also self-contained
enough to remain callable after an absolute-path source-run even when the
working directory is elsewhere, because {cmd:hddid_dgp1.ado} realizes the
Section 5 generator with internal {cmd:rnormal()} draws for the independent
{cmd:x()} block and the scalar {cmd:z()} path instead of reloading any
helper-side generator.  That embedded Section 5 path remains authoritative
for this public DGP1 block.
{p_end}

{pstd}Build the covariate list dynamically from the generated public x* variables so the public example still matches whichever documented p() width you generated{p_end}

{phang2}{cmd:. unab x_vars : x*}{p_end}

{pstd}
This shipped DGP1/Tri walkthrough uses the paper's 8th-degree Tri basis under the package's {cmd:q()/2}
indexing, with an explicit symmetric {cmd:z0()} grid so the reported
nonparametric surface stays pinned at named evaluation points across runs
instead of inheriting the realized sample's retained unique {cmd:z()} values.
That shipped five-point list is a caller-supplied/package-audit choice rather than a paper-fixed evaluation set.  Use that shipped five-point {cmd:z0(-1 -0.5 0 0.5 1)} grid only when it lies inside the current retained {cmd:z} support; otherwise choose an in-support {cmd:z0()} list or omit {cmd:z0()} so {cmd:hddid} uses the retained support points directly.
Under {cmd:method(Tri)}, keep that explicit {cmd:z0()} grid inside the current retained {cmd:z} support.
if any requested {cmd:z0()} point leaves that retained support, {cmd:hddid} fails closed instead of extrapolating the support-normalized Tri basis.
That retained-support guard is a package-specific Stata Tri rule: this walkthrough uses a caller-supplied/package-audit choice rather than a paper-fixed evaluation set, and the maintained R cross-fit sources here do not expose an executable {cmd:method(Tri)} fail-close interface.
{p_end}

{phang2}{cmd:. hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(16) z0(-1 -0.5 0 0.5 1) K(3) alpha(0.1) nboot(1000) seed(42)}{p_end}

{pstd}
This keeps the public omitted-intercept block on the shipped DGP1/Tri walkthrough surface.
On this explicit DGP1 walkthrough {cmd:z0()} grid, the public
{cmd:e(gdebias)} surface is the omitted-intercept z-varying block.  Use it for
centered shape diagnostics, for example by comparing
{cmd:e(gdebias)[j] - e(gdebias)[1]} with {cmd:exp(z0_j) - exp(z0_ref)}, rather
than by comparing raw levels to {cmd:exp(z0)}.
{p_end}

{pstd}
The shipped Part 1 DGP1 walkthrough also prints the full explicit posted {cmd:e(z0)} grid before those truth checks, so users can verify the finite evaluation points behind the centered {cmd:exp(z0_j) - exp(z0_ref)} comparisons.
{p_end}

{phang2}{cmd:. display "--- DGP1 posted z0() grid ---"}{p_end}
{phang2}{cmd:. matrix list e(z0), format(%9.4f)}{p_end}

{pstd}
The same DGP1 public matrix surface is also enough to run the beta-side
paper truth check directly.  DGP1 is the simplest paper baseline, so the public
ATT-surface beta truth still has {cmd:beta_1 = 1}.  For the nonparametric block,
this walkthrough now uses centered shape diagnostics because the posted public
surface omits {cmd:a0}.
{p_end}

{phang2}{cmd:. local beta1 = el(e(xdebias), 1, 1)}{p_end}
{phang2}{cmd:. local se1 = el(e(stdx), 1, 1)}{p_end}
{phang2}{cmd:. local tstat = (`beta1' - 1) / `se1'}{p_end}
{phang2}{cmd:. display "--- DGP1 hypothesis test: beta_1 = 1 ---"}{p_end}
{phang2}{cmd:. display "  beta_1 estimate: " %9.4f `beta1'}{p_end}
{phang2}{cmd:. display "  SE:              " %9.4f `se1'}{p_end}
{phang2}{cmd:. display "  t-stat (H0: beta_1=1): " %6.3f `tstat'}{p_end}
{phang2}{cmd:. display "  p-value (two-sided):   " %6.4f 2*normal(-abs(`tstat'))}{p_end}

{pstd}
The same DGP1 public matrix surface also supports CIpoint pointwise
diagnostics.  The first CIpoint column still gives the beta-side truth check,
while the nonparametric columns start after the first {cmd:e(p)} entries and
apply to the posted omitted-intercept block rather than to the full level
{cmd:f(z0)} surface.  Use the first beta column for the paper truth check and
then anchor the omitted-intercept block at one posted {cmd:z0()} point before
comparing centered changes only.
{p_end}

{phang2}{cmd:. display "--- DGP1 centered shape diagnostics ---"}{p_end}
{phang2}{cmd:. local beta1_ci_lo = el(e(CIpoint), 1, 1)}{p_end}
{phang2}{cmd:. local beta1_ci_hi = el(e(CIpoint), 2, 1)}{p_end}
{phang2}{cmd:. display "DGP1 beta_1 CIpoint contains 1: " cond(1 >= `beta1_ci_lo' & 1 <= `beta1_ci_hi', "yes", "no") "  [" %9.4f `beta1_ci_lo' ", " %9.4f `beta1_ci_hi' "]"}{p_end}
{phang2}{cmd:. local qq = colsof(e(z0))}{p_end}
{phang2}{cmd:. local z0_ref = el(e(z0), 1, 1)}{p_end}
{phang2}{cmd:. local gd_ref = el(e(gdebias), 1, 1)}{p_end}
{phang2}{cmd:. local max_shape_gap = 0}{p_end}
{phang2}{cmd:. forvalues j = 1/`qq' {c -(}}{p_end}
{phang2}{cmd:.     local z0_j = el(e(z0), 1, `j')}{p_end}
{phang2}{cmd:.     local centered_hat_j = el(e(gdebias), 1, `j') - `gd_ref'}{p_end}
{phang2}{cmd:.     local centered_true_j = exp(`z0_j') - exp(`z0_ref')}{p_end}
{phang2}{cmd:.     local shape_gap_j = abs(`centered_hat_j' - `centered_true_j')}{p_end}
{phang2}{cmd:.     if `shape_gap_j' > `max_shape_gap' {c -(}}{p_end}
{phang2}{cmd:.         local max_shape_gap = `shape_gap_j'}{p_end}
{phang2}{cmd:.     {c )-}}{p_end}
{phang2}{cmd:. {c )-}}{p_end}
{phang2}{cmd:. display "DGP1 centered shape diagnostics anchor at z0_ref = " %9.4f `z0_ref'}{p_end}
{phang2}{cmd:. display "Because gdebias excludes the separate stage-2 intercept a0, compare centered differences only."}{p_end}
{phang2}{cmd:. display "Max |(gdebias-gdebias_ref) - (exp(z0)-exp(z0_ref))| = " %9.4f `max_shape_gap'}{p_end}
{phang2}{cmd:. display "This DGP1 CIpoint check is pointwise. The DGP1 CIuniform object is only the package's finite-grid interval object; it is not a calibrated simultaneous-coverage guarantee."}{p_end}
{phang2}{cmd:. display "CIpoint/CIuniform remain interval objects for the omitted-intercept block, so this walkthrough does not compare them to exp(z0) levels."}{p_end}

{pstd}
The DGP1 CIuniform object is still only a descriptive finite-grid interval
object, not a calibrated simultaneous-coverage guarantee.  Because the posted
public nonparametric surface omits {cmd:a0}, the walkthrough no longer compares
that interval object directly with level truth {cmd:exp(z0)}.
{p_end}

{pstd}
Retired command tokens kept for audit traceability only:
older DGP1 pointwise-share and interval-share displays,
plus the superseded pointwise-vs-band shorthand.
{p_end}

{pstd}
Retired exact-token anchor for audit traceability only: legacy DGP1 CIpoint-versus-CIuniform contrast sentence retired from the public wording.
{p_end}

{pstd}
This DGP1 CIpoint check is pointwise.  The DGP1 CIuniform object is only the package's finite-grid interval object; it is not a calibrated simultaneous-coverage guarantee.
{p_end}
{pstd}
Retired shorthand from older walkthroughs contrasted {cmd:CIpoint} against {cmd:CIuniform} in one sentence.  Read that superseded shorthand only as a reminder that {cmd:CIpoint} is pointwise; the current contract is the corrected finite-grid interval-object statement above.
{p_end}

{pstd}Setup: generate simulation data using DGP2 (paper baseline, correlated covariates, heteroskedastic baseline){p_end}

{phang2}{cmd:. hddid_dgp2, n(500) p(50) seed(54321) rho(0.5) clear}{p_end}

{pstd}
The DGP seed {cmd:seed(54321)} above again fixes only the generated sample
itself. {cmd:hddid_dgp2} restores the caller RNG state on exit, so it does not replace the estimator-side {cmd:seed(42)} below for the same finite-grid
fold / bootstrap / CLIME path on that DGP2 sample.
{p_end}

{pstd}
The DGP generators accept {cmd:n()} as small as 1 because generation and
estimation are separate contracts.  A downstream {cmd:hddid} run still needs
both treatment arms represented on the usable score / fold-pinning sample,
at least {cmd:K} observations in each represented arm, and enough
fold-pinning rows for the maintained contiguous row-block split to
realize {cmd:K} nonempty folds, so tiny {cmd:n()} draws are generator
probes rather than
estimation-ready examples.
{p_end}

{pstd}
This DGP2 call pins one concrete public AR(1) path with explicit
{cmd:rho(0.5)}.  The paper leaves rho generic through {cmd:Sigma_jk = rho^|j-k|}, so {cmd:rho(0.5)} here is a shipped public example choice rather than a paper-fixed value.  It is the public help counterpart to the shipped DGP2 example
in {cmd:hddid_example.do}, not a legacy {cmd:Examplehighdimdiffindiff.R}
wrapper shortcut: that wrapper re-draws z after the baseline outcome,
publishes {cmd:rho.X} while hardcoding the correlated-{cmd:X} covariance at
{cmd:0.5^|j-k|}, and still carries a stale wrapper-local {cmd:method=} field
whose default is {cmd:"Pol"}.  More fundamentally, that old wrapper targets an
API the maintained cross-fit entrypoint no longer exposes: the shipped
{cmd:highdimdiffindiff_crossfit3(...)} path does not accept a public
{cmd:method} argument, and the surviving cross-fit code still passes {cmd:q}
directly into {cmd:sieve.Pol(..., q)}.  So wrapper-local
{cmd:method="Tri"} {cmd:q(16)} text there is still not this shipped DGP2/Tri walkthrough surface.  If you shrink this public DGP2 example to {cmd:p(1)}, the
AR(1) covariance collapses to {cmd:[1]}, so any finite {cmd:rho()} value then
generates the same one-covariate draw; {cmd:rho()} only changes the public
DGP2 surface once {cmd:p()>1}; for {cmd:p()>1}, the exact boundaries
{cmd:rho(-1)} and {cmd:rho(1)} are singular AR(1) limits rather than legal
public draws, so this walkthrough keeps the interior shipped public example path
{cmd:rho(0.5)}.  As with DGP1, shrinking this DGP call to
{cmd:n(1)} leaves only a singleton draw, and that singleton draw is only a
sanity probe because {cmd:hddid} then fails once the common-score sample
loses one treatment arm before overlap trimming.
For the maintained R estimator reference, inspect
{cmd:hddid-r/R/highdimdiffindiff_crossfit.R} together with
{cmd:hddid-r/R/highdimdiffindiff_crossfit_inside.R}: those files carry the
surviving shipped estimator logic, specifically
{cmd:highdimdiffindiff_crossfit3()} and
{cmd:highdimdiffindiff_crossfit_inside3()}, even though the public Stata DGP
generators here publish {cmd:deltay} rather than the {cmd:y0}/{cmd:y1} level
outcomes that the R cross-fit code expects.
{p_end}

{pstd}
It also keeps the paper's multiplicative heteroskedastic baseline
{cmd:Y(i,0) = eps_tilde * (z + x1) / sqrt(2)}, so this DGP2 example differs
from the DGP1 example by both correlated {cmd:X} and the baseline-outcome
construction.  Under the shipped no-anticipation implementation, that same
observed baseline draw is shared by both post-period treatment states before
their state-specific increments are added.  DGP2 nevertheless keeps the same
raw outcome coefficients as DGP1, namely {cmd:beta^1_j = 2/j} and
{cmd:beta^0_j = 1/j} for {cmd:j <= 15}, so the design change here is the
correlated-{cmd:X} draw plus the heteroskedastic baseline rather than a
different coefficient sequence.  The parametric block returned by {cmd:hddid}
therefore still targets the ATT-surface contrast
{cmd:beta_j = beta^1_j - beta^0_j = 1/j} on that support, not the raw treated
or control outcome slope by itself.  As with DGP1, changing this example to
{cmd:p()<10} or {cmd:p()<15} truncates the paper's nonzero {cmd:theta_0} and
{cmd:beta^1}/{cmd:beta^0} sequences at {cmd:p()}, so small-{cmd:p()} runs are
a lower-dimensional truncation of the paper surface rather than the same
oracle with hidden omitted coordinates.
{p_end}

{pstd}
Rebuild the covariate list for this DGP2 sample dynamically from the generated public x* variables before estimation if you run
this block on its own, so the public example still matches whichever documented p() width you generated.
{p_end}

{pstd}
The public DGP2 generator behind this walkthrough is also self-contained enough to remain callable after an
absolute-path source-run even when the working directory is elsewhere, because
{cmd:hddid_dgp2.ado} builds the covariance matrix inline and uses an internal {cmd:drawnorm} call instead of reloading any helper-side generator.  That embedded Section 5 path remains authoritative for this public DGP2 block.
{p_end}

{phang2}{cmd:. unab x_vars : x*}{p_end}

{pstd}
This shipped DGP2/Tri walkthrough uses the paper's 8th-degree Tri basis together with the
same explicit {cmd:z0()} grid, so the posted omitted-intercept z-varying block stays aligned to the same public audit points
used for centered shape diagnostics rather than a direct level comparison with the shipped DGP1 walkthrough above.
Use that shipped five-point {cmd:z0(-1 -0.5 0 0.5 1)} grid only when it lies inside the current retained {cmd:z} support; otherwise choose an in-support {cmd:z0()} list or omit {cmd:z0()} so {cmd:hddid} uses the retained support points directly.  That shipped five-point list is a caller-supplied/package-audit choice rather than a paper-fixed evaluation set.
Under {cmd:method(Tri)}, keep that explicit {cmd:z0()} grid inside the current retained {cmd:z} support.
if any requested {cmd:z0()} point leaves that retained support, {cmd:hddid} fails closed instead of extrapolating the support-normalized Tri basis.
That retained-support guard is a package-specific Stata Tri rule: this walkthrough uses a caller-supplied/package-audit choice rather than a paper-fixed evaluation set, and the maintained R cross-fit sources here do not expose an executable {cmd:method(Tri)} fail-close interface.
{p_end}

{phang2}{cmd:. hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(16) z0(-1 -0.5 0 0.5 1) K(3) alpha(0.1) nboot(1000) seed(42)}{p_end}

{pstd}
The returned {cmd:e(xdebias)} block is also directly comparable with DGP1:
because DGP2 keeps the same ATT-surface contrast, the concrete parametric
truth here is still {cmd:beta_j = 1/j for j <= 15} (and 0 afterward), with the
design change coming from correlated {cmd:X} plus the heteroskedastic
baseline rather than a different beta target.
{p_end}

{pstd}
On this explicit DGP2 walkthrough {cmd:z0()} grid, the public
{cmd:e(gdebias)} surface is again the omitted-intercept z-varying block.  Use
it for centered shape diagnostics, for example by comparing
{cmd:e(gdebias)[j] - e(gdebias)[1]} with {cmd:exp(z0_j) - exp(z0_ref)}, rather
than by comparing raw levels to {cmd:exp(z0)}. Because {cmd:e(a0)} is not public, this walkthrough does not expose a full ATT-level oracle at {cmd:z0()}.
{p_end}

{pstd}
The shipped Part 2 DGP2 walkthrough also prints the full explicit posted {cmd:e(z0)} grid before those truth checks, so users can verify the finite evaluation points behind the same centered {cmd:exp(z0_j) - exp(z0_ref)} comparisons.
{p_end}

{phang2}{cmd:. display "--- DGP2 posted z0() grid ---"}{p_end}
{phang2}{cmd:. matrix list e(z0), format(%9.4f)}{p_end}

{pstd}
The same DGP2 public matrix surface is also enough to run the beta-side
paper truth check directly.  DGP2 changes the correlated-{cmd:X} law and the
baseline-outcome variance, but the ATT-surface beta truth still has
{cmd:beta_1 = 1}.  For the nonparametric block, this walkthrough again uses
centered shape diagnostics because the posted public surface omits {cmd:a0}.
{p_end}

{phang2}{cmd:. local beta1 = el(e(xdebias), 1, 1)}{p_end}
{phang2}{cmd:. local se1 = el(e(stdx), 1, 1)}{p_end}
{phang2}{cmd:. local tstat = (`beta1' - 1) / `se1'}{p_end}
{phang2}{cmd:. display "--- DGP2 hypothesis test: beta_1 = 1 ---"}{p_end}
{phang2}{cmd:. display "  beta_1 estimate: " %9.4f `beta1'}{p_end}
{phang2}{cmd:. display "  SE:             " %9.4f `se1'}{p_end}
{phang2}{cmd:. display "  t-stat (H0: beta_1=1): " %6.3f `tstat'}{p_end}
{phang2}{cmd:. display "  p-value (two-sided):  " %6.4f 2*normal(-abs(`tstat'))}{p_end}

{pstd}
The same DGP2 public matrix surface also supports CIpoint pointwise
diagnostics.  The first CIpoint column still gives the beta-side truth check,
while the nonparametric columns start after the first {cmd:e(p)} entries and
apply to the posted omitted-intercept block rather than to the full level
{cmd:f(z0)} surface.  Use the first beta column for the paper truth check and
then anchor the omitted-intercept block at one posted {cmd:z0()} point before
comparing centered changes only.
{p_end}

{phang2}{cmd:. display "--- DGP2 centered shape diagnostics ---"}{p_end}
{phang2}{cmd:. local beta1_ci_lo = el(e(CIpoint), 1, 1)}{p_end}
{phang2}{cmd:. local beta1_ci_hi = el(e(CIpoint), 2, 1)}{p_end}
{phang2}{cmd:. display "DGP2 beta_1 CIpoint contains 1: " cond(1 >= `beta1_ci_lo' & 1 <= `beta1_ci_hi', "yes", "no") "  [" %9.4f `beta1_ci_lo' ", " %9.4f `beta1_ci_hi' "]"}{p_end}
{phang2}{cmd:. local qq = colsof(e(z0))}{p_end}
{phang2}{cmd:. local z0_ref = el(e(z0), 1, 1)}{p_end}
{phang2}{cmd:. local gd_ref = el(e(gdebias), 1, 1)}{p_end}
{phang2}{cmd:. local max_shape_gap = 0}{p_end}
{phang2}{cmd:. forvalues j = 1/`qq' {c -(}}{p_end}
{phang2}{cmd:.     local z0_j = el(e(z0), 1, `j')}{p_end}
{phang2}{cmd:.     local centered_hat_j = el(e(gdebias), 1, `j') - `gd_ref'}{p_end}
{phang2}{cmd:.     local centered_true_j = exp(`z0_j') - exp(`z0_ref')}{p_end}
{phang2}{cmd:.     local shape_gap_j = abs(`centered_hat_j' - `centered_true_j')}{p_end}
{phang2}{cmd:.     if `shape_gap_j' > `max_shape_gap' {c -(}}{p_end}
{phang2}{cmd:.         local max_shape_gap = `shape_gap_j'}{p_end}
{phang2}{cmd:.     {c )-}}{p_end}
{phang2}{cmd:. {c )-}}{p_end}
{phang2}{cmd:. display "DGP2 centered shape diagnostics anchor at z0_ref = " %9.4f `z0_ref'}{p_end}
{phang2}{cmd:. display "Because gdebias excludes the separate stage-2 intercept a0, compare centered differences only."}{p_end}
{phang2}{cmd:. display "Max |(gdebias-gdebias_ref) - (exp(z0)-exp(z0_ref))| = " %9.4f `max_shape_gap'}{p_end}
{phang2}{cmd:. display "This DGP2 CIpoint check is pointwise. The DGP2 CIuniform object is only the package's finite-grid interval object; it is not a calibrated simultaneous-coverage guarantee."}{p_end}
{phang2}{cmd:. display "CIpoint/CIuniform remain interval objects for the omitted-intercept block, so this walkthrough does not compare them to exp(z0) levels."}{p_end}

{pstd}
The DGP2 CIuniform object is still only a descriptive finite-grid interval
object, not a calibrated simultaneous-coverage guarantee.  Because the posted
public nonparametric surface omits {cmd:a0}, the walkthrough no longer compares
that interval object directly with level truth {cmd:exp(z0)}.
{p_end}

{pstd}
Retired command tokens kept for audit traceability only:
older DGP2 pointwise-share and interval-share displays,
plus the superseded pointwise-vs-band shorthand.
{p_end}

{pstd}
Retired exact-token anchor for audit traceability only: legacy DGP2 CIpoint-versus-CIuniform contrast sentence retired from the public wording.
{p_end}

{pstd}
This DGP2 CIpoint check is pointwise.  The DGP2 CIuniform object is only the package's finite-grid interval object; it is not a calibrated simultaneous-coverage guarantee.
{p_end}
{pstd}
Retired shorthand from older walkthroughs contrasted {cmd:CIpoint} against {cmd:CIuniform} in one sentence.  Read that superseded shorthand only as a reminder that {cmd:CIpoint} is pointwise; the current contract is the corrected finite-grid interval-object statement above.
{p_end}

{pstd}Estimation with same-input-q basis comparison{p_end}

{pstd}
This comparison is the public help counterpart to Part 3 of the shipped
{cmd:hddid_example.do}.  It is not the paper's Section 5 baseline; instead it
keeps a same-input-q demo rather than a matched-degree basis comparison: with
{cmd:q(8)}, {cmd:Pol} q(8) still means an 8th-degree polynomial basis, while
{cmd:Tri} q(8) is only a 4th degree trigonometric basis under the package's
{cmd:q()/2} indexing.  That is why the paper's 8th-degree Tri baseline still
requires {cmd:q(16)} rather than this shipped Part 3 {cmd:q(8)} demo.
{p_end}

{pstd}
Keep the same explicit {cmd:seed(42)} in both runs so the realized outer folds,
bootstrap draws, and CLIME CV splits stay aligned; then the remaining
design change is the {cmd:Pol} versus {cmd:Tri} basis family itself.
{p_end}

{pstd}
Because these Part 3 runs omit {cmd:z0()}, the {cmd:Pol} and {cmd:Tri} demos
need not post {cmd:gdebias}/{cmd:CIuniform} on the same default retained-sample
{cmd:z} grid.  For an apples-to-apples nonparametric comparison across basis
families, rerun both commands with the same explicit {cmd:z0()} list.
{p_end}

{pstd}
To match the shipped Part 3 surface in {cmd:hddid_example.do}, first reload the
same DGP1 sample used in Part 1; otherwise running this block immediately
after the DGP2 section would change both the DGP and the sieve basis family.
{p_end}

{phang2}{cmd:. hddid_dgp1, n(500) p(50) seed(12345) clear}{p_end}

{pstd}
That reload {cmd:seed(12345)} only recreates the Part 1 DGP1 sample itself.
{cmd:hddid_dgp1} restores the caller RNG state on exit, so that generator seed
still does not carry into the two {cmd:hddid} calls below.  Keep the explicit
estimator-side {cmd:seed(42)} in both runs when reproducing the same-input-q
fold / bootstrap / CLIME comparison on this reloaded sample.
{p_end}

{pstd}
Rebuild the covariate list for this refreshed DGP1 sample dynamically from the generated public x* variables before estimation if
you run this block on its own, so the public example still matches whichever documented p() width you generated.
{p_end}

{phang2}{cmd:. unab x_vars : x*}{p_end}

{phang2}{cmd:. hddid deltay, treat(treat) x(`x_vars') z(z) method("Pol") q(8) K(3) alpha(0.1) nboot(1000) seed(42)}{p_end}
{phang2}{cmd:. local pol_x1 = el(e(xdebias), 1, 1)}{p_end}
{phang2}{cmd:. local pol_se1 = el(e(stdx), 1, 1)}{p_end}
{phang2}{cmd:. hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(8) K(3) alpha(0.1) nboot(1000) seed(42)}{p_end}
{phang2}{cmd:. local tri_x1 = el(e(xdebias), 1, 1)}{p_end}
{phang2}{cmd:. local tri_se1 = el(e(stdx), 1, 1)}{p_end}

{pstd}
Because the second call overwrites {cmd:e()}, cache the {cmd:Pol} beta result
before running the {cmd:Tri} call if you want a direct same-sample comparison.
The simplest public check is the first ATT-surface coefficient because the
paper truth remains {cmd:beta_1 = 1}.
{p_end}

{phang2}{cmd:. display "--- x1 estimate comparison (true value = 1.0) ---"}{p_end}
{phang2}{cmd:. display "  Pol: " %9.4f `pol_x1' " (SE = " %7.4f `pol_se1' ")"}{p_end}
{phang2}{cmd:. display "  Tri: " %9.4f `tri_x1' " (SE = " %7.4f `tri_se1' ")"}{p_end}
{phang2}{cmd:. display "  True: " %9.4f 1.0}{p_end}

{pstd}Access stored results{p_end}

{pstd}
The stored-result displays below therefore report the {cmd:e()} results from
the immediately preceding Part 3 Tri {cmd:q(8)} run, not from the earlier
paper-baseline Tri {cmd:q(16)} examples or from the preceding same-input
Pol {cmd:q(8)} comparison call.
{p_end}

{pstd}
Because that same-input Tri {cmd:q(8)} run omits {cmd:z0()}, the current
{cmd:e(z0)} grid and the aligned {cmd:gdebias}/{cmd:e(stdg)}/{cmd:e(CIuniform)} results and the trailing omitted-intercept {cmd:e(CIpoint)} block now
come from the retained sample's default {cmd:z} support rather than the
earlier explicit {cmd:z0(-1 -0.5 0 0.5 1)} paper-baseline grid.  Read
{cmd:e(method)} together with {cmd:e(z_support_min)}/{cmd:e(z_support_max)} to
recover the active trigonometric support normalization, and use {cmd:e(seed)}
when present to anchor the realized fold/bootstrap/CLIME RNG path behind that
stored-result surface.  Read {cmd:e(q)} together with {cmd:e(method)} as well:
under the package's Tri {cmd:q()/2} harmonic indexing, the active Tri {cmd:q(8)} surface therefore means a 4th degree trigonometric basis rather than the earlier paper-baseline 8th-degree Tri {cmd:q(16)} surface.
Because the active Part 4 surface comes from the same-input Tri {cmd:q(8)} run, {cmd:e(q)} here is still the raw sieve-order index rather than the harmonic degree: it prints {cmd:8} even though the active trigonometric basis is only 4th degree.
Read {cmd:e(qq)} as the public {cmd:qq = length(z0)} contract as well: {cmd:e(qq)} is the width of the current {cmd:e(z0)} grid shared by the active {cmd:e(gdebias)}/{cmd:e(stdg)}/{cmd:e(CIuniform)} nonparametric surface and the trailing omitted-intercept z-varying block of {cmd:e(CIpoint)}.  The same active Part 4 width cue also keeps the shorter {cmd:e(gdebias)}/{cmd:e(CIuniform)} surface wording, plus the trailing omitted-intercept {cmd:e(CIpoint)} block wording, discoverable elsewhere in this walkthrough.
When {cmd:seed()} is omitted or {cmd:seed(-1)} is used, {cmd:e(seed)} is intentionally absent because the realized fold/bootstrap/CLIME path is not indexed by one published seed scalar.  On the same degenerate zero-SE shortcut, that omission still leaves the realized outer fold assignment deterministic from the data and Python CLIME CV tied to its deterministic per-fold integer seeds, while the published nonparametric interval object again used no studentized Gaussian-bootstrap draws.  In that omitted-seed
path, with internally estimated first stages, the realized outer fold map is
a deterministic function of the current common-score row order.  Under
{cmd:nofirst}, the realized outer fold map is a deterministic function of the
current nofirst fold-pinning row order.
{p_end}

{pstd}
The saved-results walkthrough below still works when current {cmd:e(method)},
{cmd:e(q)}, or {cmd:e(alpha)} are absent because it falls back to current
{cmd:e(cmdline)} provenance or, when that provenance text also omits those
options, the official default {cmd:Pol} basis, default {cmd:q(8)}, and default
{cmd:alpha(0.1)} contract.
{p_end}

{phang2}{cmd:. local cmdline = lower(strtrim(`"`e(cmdline)'"'))}{p_end}
{phang2}{cmd:. local method = strproper(strlower(strtrim(`"`e(method)'"')))}{p_end}
{phang2}{cmd:. if `"`method'"' == "" \{}{p_end}
{phang2}{cmd:.     if regexm(`"`cmdline'"', "(^|[ ,])method[(][ ]*([^)]*)[ ]*[)]") local method = strproper(strtrim(regexs(2)))}{p_end}
{phang2}{cmd:.     else local method "Pol"}{p_end}
{phang2}{cmd:. \}}{p_end}
{phang2}{cmd:. capture confirm scalar e(q)}{p_end}
{phang2}{cmd:. if _rc == 0 local q = e(q)}{p_end}
{phang2}{cmd:. else if regexm(`"`cmdline'"', "(^|[ ,])q[(][ ]*([^)]*)[ ]*[)]") local q = real(strtrim(regexs(2)))}{p_end}
{phang2}{cmd:. else local q = 8}{p_end}
{phang2}{cmd:. capture confirm scalar e(alpha)}{p_end}
{phang2}{cmd:. if _rc == 0 local alpha = e(alpha)}{p_end}
{phang2}{cmd:. else if regexm(`"`cmdline'"', "(^|[ ,])alpha[(][ ]*([^)]*)[ ]*[)]") local alpha = real(strtrim(regexs(2)))}{p_end}
{phang2}{cmd:. else local alpha = 0.1}{p_end}
{phang2}{cmd:. display "Sample size: " e(N)}{p_end}
{phang2}{cmd:. display "Fold-count rowvector width: " colsof(e(N_per_fold))}{p_end}
{phang2}{cmd:. display "X dimension: " colsof(e(b))}{p_end}
{phang2}{cmd:. display "Sieve method: " `"`method'"'}{p_end}
{phang2}{cmd:. display "Sieve order q: " `q'}{p_end}
{phang2}{cmd:. if `"`method'"' == "Tri" display "Tri harmonic degree: " `q'/2}{p_end}
{phang2}{cmd:. display "Evaluation points / e(z0) width: " colsof(e(z0))}{p_end}
{phang2}{cmd:. display "Significance level: " `alpha'}{p_end}
{phang2}{cmd:. capture confirm scalar e(nboot)}{p_end}
{phang2}{cmd:. if _rc == 0 \{}{p_end}
{phang2}{cmd:.     display "Bootstrap reps: " e(nboot)}{p_end}
{phang2}{cmd:. \}}{p_end}
{phang2}{cmd:. else \{}{p_end}
{phang2}{cmd:.     display as text "Bootstrap reps: <absent; ordinary current surfaces may omit e(nboot) because the posted e(tc)/e(CIuniform) object already carries the interval contract>"}{p_end}
{phang2}{cmd:. \}}{p_end}
{phang2}{cmd:. capture confirm scalar e(seed)}{p_end}
{phang2}{cmd:. if _rc == 0 \{}{p_end}
{phang2}{cmd:.     display "RNG provenance seed: " e(seed)}{p_end}
{phang2}{cmd:. \}}{p_end}
{phang2}{cmd:. else \{}{p_end}
{phang2}{cmd:.     display as text "RNG provenance seed: <absent; omitted seed()/seed(-1) follows caller session RNG state>"}{p_end}
{phang2}{cmd:. \}}{p_end}
{pstd}
This guard is existence-based: explicit {cmd:seed(0)} still stores {cmd:e(seed)} = 0, so it must print {cmd:0} rather than fall into the omitted-seed branch.
{p_end}
{phang2}{cmd:. display "Tri support min: " e(z_support_min)}{p_end}
{phang2}{cmd:. display "Tri support max: " e(z_support_max)}{p_end}
{phang2}{cmd:. display "Pretrim common-score sample: " e(N_pretrim)}{p_end}
{phang2}{cmd:. display "Trimmed observations: " e(N_trimmed)}{p_end}
{phang2}{cmd:. display "Fold-pinning outer split: " e(N_outer_split)}{p_end}
{phang2}{cmd:. display "Propensity CV folds: " e(propensity_nfolds)}{p_end}
{phang2}{cmd:. display "Outcome CV folds: " e(outcome_nfolds)}{p_end}
{phang2}{cmd:. display "Second-stage CV folds: " e(secondstage_nfolds)}{p_end}
{phang2}{cmd:. display "M-matrix CV folds: " e(mmatrix_nfolds)}{p_end}
{phang2}{cmd:. display "CLIME requested max CV folds: " e(clime_nfolds_cv_max)}{p_end}
{phang2}{cmd:. display "CLIME realized min CV folds: " e(clime_nfolds_cv_effective_min)}{p_end}
{phang2}{cmd:. display "CLIME realized max CV folds: " e(clime_nfolds_cv_effective_max)}{p_end}

{pstd}
Those scalar displays recover the active cross-fit dimension, the beta versus
{cmd:e(z0)} block sizes, the realized sieve order, the confidence-level /
bootstrap calibration behind the stored matrix surface, and the tuning provenance
for the internal propensity/outcome/second-stage/M-matrix CV steps plus the
requested-versus-realized CLIME CV fold bounds.
They also tell you how to interpret a missing {cmd:e(seed)}: on the
omitted-seed / {cmd:seed(-1)} path, the bootstrap draws follow the caller's
session RNG state.  With internally estimated first stages, the realized
outer fold map stays pinned by the current common-score row order.  Under
{cmd:nofirst}, the realized outer fold map stays pinned by the
current nofirst fold-pinning row order.
{p_end}

{phang2}{cmd:. matrix list e(xdebias), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(stdx), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(b), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(V), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(z0), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(gdebias), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(stdg), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(CIpoint), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(tc), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(CIuniform), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(N_per_fold)}{p_end}
{phang2}{cmd:. matrix list e(clime_nfolds_cv_per_fold)}{p_end}

{pstd}
For the active result surface, use {cmd:e(N_trimmed)}, {cmd:e(N)}, and
{cmd:e(N_outer_split)}. When {cmd:e(N_pretrim)} is available, use it too:
it adds the extra current accounting identity
check {cmd:e(N_trimmed) = e(N_pretrim) - e(N)}; {cmd:e(N_outer_split)}
records the sample that actually pins the outer fold assignment and can differ.
Under {cmd:nofirst}, that fold-pinning sample records the retained-relevant
subset of the broader strict-interior pretrim fold-feasibility sample.
That broader strict-interior pretrim fold-feasibility sample is the
nofirst-specific split path rebuilt from the supplied nuisance inputs, not the
default internal-first-stage score sample.
Any legal {cmd:0<pihat()<1} row still enters that broader strict-interior
fold-feasibility path before later overlap trimming, but only treatment-arm
keys with at least one retained-overlap pretrim row pin the published retained
outer fold IDs.
Retained rows then keep those already-assigned outer fold IDs on the narrower
retained-overlap score sample.
Under {cmd:nofirst}, that fold-pinning sample can still differ by membership
even when {cmd:e(N_outer_split)=e(N_pretrim)} in scalar count, because
strict-interior rows can replace exact-boundary common-score rows one-for-one.
Exact-boundary {cmd:pihat()} rows stay outside that broader strict-interior
fold-feasibility split and do not pin retained outer fold IDs by themselves.
Only treatment-arm keys with at least one retained-overlap pretrim row pin the
retained outer fold IDs.
The per-fold post-trim weights live in {cmd:e(N_per_fold)}, and their
 sum is {cmd:e(N)}.  The realized CLIME CV folds live in
{cmd:e(clime_nfolds_cv_per_fold)}; that retained-fold rowvector shows how much
inner-CV work each outer fold actually used, and a 0 means only that CLIME CV
was skipped on that fold.
{p_end}

{pstd}
For the active parametric block, {cmd:e(b)} is the canonical Stata coefficient
vector and matches {cmd:e(xdebias)}, while {cmd:e(V)} is the canonical
parametric covariance matrix.  On that same active result surface,
{cmd:diag(e(V)) = e(stdx)^2}.
{p_end}

{pstd}
For the active result surface, {cmd:e(CIpoint)} is the published pointwise
interval matrix: its first {cmd:e(p)} columns are the beta block and its
remaining {cmd:e(qq)} columns are the omitted-intercept z-varying block aligned with the
current {cmd:e(z0)} grid.  The published nonparametric interval object
{cmd:e(CIuniform)} stays aligned on that same current {cmd:e(z0)} grid.  Because {cmd:hddid}
does not currently publish {cmd:e(a0)}, that trailing {cmd:e(CIpoint)} block supports only centered comparisons rather than either a full ATT level or a raw {cmd:f(z0)} level.  The
same left-to-right {cmd:e(z0)} order used by {cmd:e(gdebias)}, {cmd:e(stdg)},
{cmd:e(CIuniform)}, and the trailing omitted-intercept z-varying block in {cmd:e(CIpoint)}
therefore tells you which stored evaluation point each nonparametric column
represents.  On current saved-results surfaces, replay/direct unsupported
postestimation can still use the published {cmd:e(CIuniform)} object only on
legacy/custom saved-result surfaces when {cmd:e(tc)} is absent.  Current
replay/direct unsupported postestimation instead require the bundled
{cmd:e(gdebias)}, {cmd:e(stdg)}, {cmd:e(CIuniform)}, {cmd:e(tc)}, and
{cmd:e(CIpoint)} objects on current saved-results surfaces and fail closed
before ancillary provenance reconciliation.  When {cmd:e(tc)} is stored,
current replay/direct unsupported postestimation validate that provenance
against the published
{cmd:e(CIuniform)} object before ancillary
{cmd:seed()}/{cmd:alpha()}/{cmd:nboot()} cmdline reconciliation.
The
lower row of {cmd:e(CIuniform)} is {cmd:e(gdebias)} + {cmd:e(tc)[1,1]} *
{cmd:e(stdg)} and the upper row is {cmd:e(gdebias)} + {cmd:e(tc)[1,2]} *
{cmd:e(stdg)} when {cmd:e(tc)} is stored.
{p_end}

{pstd}
The shipped Part 4 walkthrough in {cmd:hddid_example.do} now uses those
stored results for two public diagnostics: a simple t-statistic for the known
paper DGP1 value {cmd:beta_1 = 1}, and a centered-shape diagnostic that anchors
the omitted-intercept {cmd:e(gdebias)} block at one posted {cmd:z0()} point
before comparing it with {cmd:exp(z0_j) - exp(z0_ref)}.
{p_end}

{pstd}
That same stored-result surface is enough to audit the public beta block and
centered changes in the omitted-intercept nonparametric block, but it is not
enough to reconstruct the full paper target {cmd:ATT(W)=tau0(W)} at a posted test point, namely {cmd:x0'{it:beta} + f(z0)}, because
{cmd:e(gdebias)} excludes {cmd:a0} and {cmd:hddid} does not currently publish
{cmd:e(a0)}.  For a test point, recover the paper target x0'beta + f(z0) only
after separately restoring that missing intercept term.  hddid does not
currently publish a one-shot combined inference object for that sum.  There is
therefore no public combined inference object for that sum. Retired wording
kept for audit traceability only: there is still no combined inference object
for that sum.
Retired traceability note only: older walkthroughs sometimes wrote the missing-a0 sum as a one-shot ATT level, but that shorthand is not a valid public reconstruction because {cmd:e(gdebias)} omits {cmd:a0}.
{p_end}

{phang2}{cmd:. display "--- Separate beta contribution from centered z-varying change ---"}{p_end}
{phang2}{cmd:. display as text "Published beta coordinate order e(xvars): `e(xvars)'"}{p_end}
{pstd}Build any posted {cmd:x0} rowvector in that published {cmd:e(xvars)} order before using the beta block, and read the public nonparametric piece only as centered omitted-intercept variation rather than adding {cmd:e(gdebias)} itself as a full ATT level. Retired audit tokens still refer to the published {cmd:e(xvars)} order even though the full ATT level needs the missing {cmd:a0}. {p_end}
{phang2}{cmd:. matrix x0 = J(1, colsof(e(b)), 0)}{p_end}
{phang2}{cmd:. matrix x0[1, 1] = 1}{p_end}
{phang2}{cmd:. matrix att_beta = x0 * e(b)'}{p_end}
{phang2}{cmd:. local z0_ref = el(e(z0), 1, 1)}{p_end}
{phang2}{cmd:. local gd_ref = el(e(gdebias), 1, 1)}{p_end}
{phang2}{cmd:. display as text "Public ATT note: hddid does not currently publish e(a0), so the posted public objects do not identify the full ATT level at z0."}{p_end}
{phang2}{cmd:. display as text "beta-only contribution at x0: " %9.4f el(att_beta, 1, 1)}{p_end}
{phang2}{cmd:. display as text "Centered omitted-intercept anchor at z0_ref (equals 0 by construction): " %9.4f (el(e(gdebias), 1, 1) - `gd_ref')}{p_end}

{pstd}
The same public matrix surface is enough to audit the posted beta-side
pointwise intervals directly.  Theorem 2 gives separate pointwise
{cmd:(1-alpha)} intervals for the beta block, while the package's public
nonparametric columns apply to the omitted-intercept block.  CIpoint
pointwise diagnostics therefore read the first beta column directly, while the
nonparametric public block is only suitable for centered-shape diagnostics
because it omits {cmd:a0}.  The published {cmd:CIuniform} object remains only
the package's finite-grid interval object and is not a calibrated
simultaneous-coverage guarantee.
{p_end}

{phang2}{cmd:. display "--- Centered shape diagnostics ---"}{p_end}
{phang2}{cmd:. local beta1_ci_lo = el(e(CIpoint), 1, 1)}{p_end}
{phang2}{cmd:. local beta1_ci_hi = el(e(CIpoint), 2, 1)}{p_end}
{phang2}{cmd:. display "  beta_1 CIpoint contains 1: " cond(1 >= `beta1_ci_lo' & 1 <= `beta1_ci_hi', "yes", "no") "  [" %9.4f `beta1_ci_lo' ", " %9.4f `beta1_ci_hi' "]"}{p_end}
{phang2}{cmd:. local qq = colsof(e(z0))}{p_end}
{phang2}{cmd:. local z0_ref = el(e(z0), 1, 1)}{p_end}
{phang2}{cmd:. local gd_ref = el(e(gdebias), 1, 1)}{p_end}
{phang2}{cmd:. local max_shape_gap = 0}{p_end}
{phang2}{cmd:. forvalues j = 1/`qq' {c -(}}{p_end}
{phang2}{cmd:.     local z0_j = el(e(z0), 1, `j')}{p_end}
{phang2}{cmd:.     local centered_hat_j = el(e(gdebias), 1, `j') - `gd_ref'}{p_end}
{phang2}{cmd:.     local centered_true_j = exp(`z0_j') - exp(`z0_ref')}{p_end}
{phang2}{cmd:.     local shape_gap_j = abs(`centered_hat_j' - `centered_true_j')}{p_end}
{phang2}{cmd:.     if `shape_gap_j' > `max_shape_gap' {c -(}}{p_end}
{phang2}{cmd:.         local max_shape_gap = `shape_gap_j'}{p_end}
{phang2}{cmd:.     {c )-}}{p_end}
{phang2}{cmd:. {c )-}}{p_end}
{phang2}{cmd:. display "Centered shape diagnostics anchor at z0_ref = " %9.4f `z0_ref'}{p_end}
{phang2}{cmd:. display "Because gdebias excludes the separate stage-2 intercept a0, compare centered differences only."}{p_end}
{phang2}{cmd:. display "Max |(gdebias-gdebias_ref) - (exp(z0)-exp(z0_ref))| = " %9.4f `max_shape_gap'}{p_end}
{phang2}{cmd:. display "Those CIpoint checks are pointwise. The published {cmd:CIuniform} object remains only the package's finite-grid interval object and is not a calibrated simultaneous-coverage guarantee."}{p_end}
{phang2}{cmd:. display "CIpoint/CIuniform remain interval objects for the omitted-intercept block, so this walkthrough does not compare them to exp(z0) levels."}{p_end}

{phang2}{cmd:. local beta1 = el(e(xdebias), 1, 1)}{p_end}
{phang2}{cmd:. local se1 = el(e(stdx), 1, 1)}{p_end}
{phang2}{cmd:. local tstat = (`beta1' - 1) / `se1'}{p_end}
{phang2}{cmd:. display "--- Hypothesis test: beta_1 = 1 ---"}{p_end}
{phang2}{cmd:. display "  beta_1 estimate: " %9.4f `beta1'}{p_end}
{phang2}{cmd:. display "  SE:             " %9.4f `se1'}{p_end}
{phang2}{cmd:. display "  t-stat (H0: beta_1=1): " %6.3f `tstat'}{p_end}
{phang2}{cmd:. display "  p-value (two-sided):  " %6.4f 2*normal(-abs(`tstat'))}{p_end}

{pstd}
That CIuniform object is only a descriptive finite-grid interval object; it
is not a calibrated simultaneous-coverage guarantee.  Because the posted public
nonparametric surface omits {cmd:a0}, the walkthrough no longer compares that
interval object directly with level truth {cmd:exp(z0)}.
{p_end}

{pstd}
Retired shorthand from older walkthroughs contrasted {cmd:CIpoint} against {cmd:CIuniform} in one sentence.  Read that superseded shorthand only as a reminder that {cmd:CIpoint} is pointwise; the current contract is the corrected finite-grid interval-object statement above.
{p_end}
{pstd}
Those CIpoint checks are pointwise.  The published {cmd:CIuniform} object remains only the package's finite-grid interval object and is not a calibrated simultaneous-coverage guarantee.
{p_end}

{pstd}
Retired help shorthand also contrasted {cmd:CIpoint} against the published {cmd:CIuniform} object in one sentence.  Read that superseded shorthand the same way: {cmd:CIpoint} is pointwise, while the current {cmd:CIuniform} contract remains only the package's finite-grid interval object.
{p_end}

{pstd}
The shipped {cmd:hddid_example.do} also closes a public Part 5 surface called
{bf:Common errors and diagnostics}.  Those failures are part of the user-facing
contract rather than private debugging notes, because they are the shortest
routes back onto the paper/R path when a run stops before posting results.
{p_end}

{pstd}
Bundle/runtime preflight for the public multivariate path: if
{cmd:hddid_example.do} or a multivariate {cmd:x()} run says it cannot find
{cmd:hddid_safe_probe.py} or cannot locate a full sibling bundle, Stata is not
pointing at the complete package directory.  The shipped recovery path is to
rerun from the repository root/package directory or add that full package
directory to {cmd:adopath} so {cmd:hddid_safe_probe.py}, {cmd:hddid_clime.py},
and the ado sidecars stay together.  After a local net install, users who also
need the shipped ancillary walkthrough should first run {cmd:net install hddid,
from("/path/to/hddid-stata") all replace} or
{cmd:net get hddid, from("/path/to/hddid-stata")}.  Then the positive
verification probe is {cmd:which hddid}, {cmd:which hddid_dgp1},
{cmd:which hddid_dgp2}, {cmd:which hddid_p},
{cmd:which hddid_estat}, {cmd:findfile _hddid_main.ado},
{cmd:findfile _hddid_display.ado}, {cmd:findfile _hddid_estimate.ado},
{cmd:findfile _hddid_prepare_fold_covinv.ado}, {cmd:findfile _hddid_pst_cmdroles.ado},
{cmd:findfile _hddid_mata.ado}, {cmd:findfile hddid_safe_probe.py}, and
{cmd:findfile hddid_clime.py} before rerunning {cmd:findfile hddid_example.do}
followed by {cmd:do "`r(fn)'"}.
{p_end}

{pstd}
Matrix-capacity preflight: if a large q()/z0() request hits a
matrix-dimension failure, first try {cmd:set matsize 10000}.  But the
active hard frontier is the larger of the q+1 sieve width and
{cmd:qq = length(z0)}, capped by {cmd:c(max_matdim)} when available, so
raising {cmd:matsize} alone cannot push a run beyond that
matrix-capacity / edition cap.
{p_end}

{pstd}
The same public Part 5 walkthrough also shows the shortest contract-failure
checks:
{p_end}

{phang2}{cmd:. display "--- Error demo: missing required option ---"}{p_end}
{phang2}{cmd:. capture noisily hddid deltay, x(`x_vars') z(z)}{p_end}
{phang2}{cmd:. display "Return code: " _rc " (expected: 198)"}{p_end}

{phang2}{cmd:. display "--- Error demo: odd q with Tri basis ---"}{p_end}
{phang2}{cmd:. capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(7)}{p_end}
{phang2}{cmd:. display "Return code: " _rc " (expected: 198)"}{p_end}

{phang2}{cmd:. display "--- Error demo: unsupported estimator-style switch ---"}{p_end}
{phang2}{cmd:. capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) aipw}{p_end}
{phang2}{cmd:. display "Return code: " _rc " (expected: 198)"}{p_end}
{phang2}{cmd:. capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) estimator=ipw}{p_end}
{phang2}{cmd:. display "Return code: " _rc " (expected: 198)"}{p_end}

{pstd}
The paper and the R reference both fix the estimator path at AIPW.  Here
{cmd:method()} only chooses the sieve basis family, so {cmd:ra}, {cmd:ipw},
{cmd:aipw}, or {cmd:estimator(...)} spellings are public contract errors rather
than alternative estimator modes.  Matching the legacy R wrapper default
{cmd:method("Pol")} still does not reproduce the paper's Tri baseline, so
those spellings are not a route to a different paper-aligned estimator path.
{p_end}

{phang2}{cmd:. display "--- Error demo: nofirst without pihat/phi1hat/phi0hat ---"}{p_end}
{phang2}{cmd:. capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) nofirst}{p_end}
{phang2}{cmd:. display "Return code: " _rc " (expected: 198)"}{p_end}

{pstd}
That {cmd:nofirst} failure path is algorithmic, not cosmetic: by the paper's
orthogonality logic, {cmd:pihat()}, {cmd:phi1hat()}, and {cmd:phi0hat()} must
already be fold-aligned out-of-fold nuisance inputs on the command's own
outer-fold structure before the second-stage AIPW score can be formed.
{p_end}

{phang2}{cmd:. display "--- Error demo: unsupported postestimation entrypoints ---"}{p_end}
{phang2}{cmd:. capture noisily predict, xb}{p_end}
{phang2}{cmd:. display "predict rc: " _rc " (unsupported observation-level contract)"}{p_end}
{phang2}{cmd:. capture noisily hddid_estat summarize}{p_end}
{phang2}{cmd:. display "hddid_estat summarize rc: " _rc " (unsupported estat contract)"}{p_end}
{phang2}{cmd:. capture noisily margins}{p_end}
{phang2}{cmd:. display "margins rc: " _rc " (disabled because no prediction contract is published)"}{p_end}
{phang2}{cmd:. display "Use bare replay plus the stored e() objects instead"}{p_end}
{phang2}{cmd:. display "for aggregate beta / omitted-intercept z-varying output: ereturn list | matrix list e(b) | matrix list e(z0) | matrix list e(gdebias) | matrix list e(stdg) | matrix list e(tc) | matrix list e(CIpoint) | matrix list e(CIuniform)"}{p_end}
{phang2}{cmd:. display "matrix list e(xdebias) | matrix list e(stdx) | matrix list e(V)"}{p_end}
{phang2}{cmd:. display as text "Published beta coordinate order e(xvars): `e(xvars)'"}{p_end}
{phang2}{cmd:. display "e(xvars) is the published beta coordinate order behind e(b) and the beta block of e(CIpoint)."}{p_end}
{phang2}{cmd:. display "e(b) is the canonical Stata coefficient vector and matches e(xdebias)."}{p_end}
{phang2}{cmd:. display "e(V) is the canonical parametric covariance surface, with diag(e(V)) = e(stdx)^2 on the active result surface."}{p_end}
{phang2}{cmd:. display "e(z0) is the posted evaluation grid behind e(gdebias), e(stdg), e(CIuniform), and the trailing omitted-intercept z-varying block of e(CIpoint)."}{p_end}
{phang2}{cmd:. display "e(method) identifies the stored sieve basis."}{p_end}
{phang2}{cmd:. display "When e(method)=Tri, inspect e(z_support_min) and e(z_support_max) before reading the omitted-intercept z-varying block on e(z0)."}{p_end}
{phang2}{cmd:. display "e(CIpoint) uses its first e(p) columns for the beta block in {cmd:e(xvars)} order."}{p_end}
{phang2}{cmd:. display "Its remaining e(qq) columns are the omitted-intercept z-varying block aligned with {cmd:e(z0)}."}{p_end}
{phang2}{cmd:. display "The same stored nonparametric surface also carries the published {cmd:e(CIuniform)} object and {cmd:e(stdg)} on that current {cmd:e(z0)} grid."}{p_end}
{phang2}{cmd:. display "{cmd:e(tc)} is only the stored lower/upper bootstrap critical-value pair behind that published {cmd:e(CIuniform)} interval object."}{p_end}
{phang2}{cmd:. display "e(gdebias) is the stored omitted-intercept z-varying point-estimate surface; e(stdg) is the nonparametric standard-error surface; e(tc) is the bootstrap critical-value pair behind the published e(CIuniform) interval object."}{p_end}
{phang2}{cmd:. display "because hddid does not currently publish e(a0), use centered comparisons rather than treating the public omitted-intercept block as either a full ATT level or a raw f(z0) level."}{p_end}
{pstd}In that same recovery block, {cmd:e(b)} is the canonical Stata coefficient vector and matches {cmd:e(xdebias)}.  {cmd:e(gdebias)} is the stored omitted-intercept z-varying point-estimate surface; because {cmd:hddid} does not currently publish {cmd:e(a0)}, use centered comparisons rather than treating that public block as either a full ATT level or a raw {cmd:f(z0)} level.{p_end}

{pstd}
Those unsupported postestimation entrypoints are deliberate rather than a
broken install: the paper and the shipped R reference publish aggregate
{cmd:beta} plus omitted-intercept z-varying objects, not observation-level prediction, {cmd:estat},
or {cmd:margins} contracts.  Use bare replay plus the stored {cmd:e()}
objects instead when you need the published aggregate surface.  In that
same recovery block, {cmd:e(xvars)} is the published beta-coordinate order
behind {cmd:e(b)} and the beta block of {cmd:e(CIpoint)}.  In that
stored-results block, {cmd:e(z0)} is the posted evaluation grid behind
{cmd:e(gdebias)}, {cmd:e(stdg)}, {cmd:e(CIuniform)}, and the trailing
omitted-intercept z-varying block of {cmd:e(CIpoint)}.  {cmd:e(tc)} is instead the stored lower/upper
bootstrap critical-value pair behind that published {cmd:e(CIuniform)}
interval object.  {cmd:e(method)} identifies the stored sieve basis.  When {cmd:e(method)}={cmd:Tri}, inspect {cmd:e(z_support_min)} and {cmd:e(z_support_max)} before reading the omitted-intercept z-varying block on {cmd:e(z0)}.  There, {cmd:e(CIpoint)} uses its first {cmd:e(p)} columns
for the beta block in {cmd:e(xvars)} order and its remaining {cmd:e(qq)}
columns for the omitted-intercept z-varying block aligned with {cmd:e(z0)}.
The same recovery block should also show the beta-side
aggregate surfaces {cmd:e(xdebias)}, {cmd:e(stdx)}, and {cmd:e(V)}:
{cmd:e(b)} is the canonical Stata coefficient vector and matches
{cmd:e(xdebias)}, while {cmd:diag(e(V)) = e(stdx)^2} on the active result
surface.  {cmd:e(gdebias)} is only the public omitted-intercept z-varying
point-estimate surface, {cmd:e(stdg)} is the public nonparametric
standard-error surface, and {cmd:e(tc)} is the stored lower/upper
bootstrap critical-value pair behind the published {cmd:e(CIuniform)}
interval object.  Because {cmd:hddid} does not currently publish
{cmd:e(a0)}, use {cmd:e(gdebias)} only for centered comparisons rather than
as either a full ATT level or a raw {cmd:f(z0)} level.  {cmd:e(CIpoint)} and {cmd:e(CIuniform)}
remain the pointwise and published interval objects.
{p_end}

{pstd}
After a successful public run, the same Part 5 walkthrough also shows the
shortest stored-results diagnostics for retained fold weights and overlap
trimming:
{p_end}

{phang2}{cmd:. display "--- Diagnostic: post-trim per-fold effective sample sizes ---"}{p_end}
{phang2}{cmd:. matrix list e(N_per_fold)}{p_end}

{pstd}
Those positive per-fold counts are the post-trim aggregation weights behind the
published cross-fit surfaces.  If any fold is very small, consider reducing K
before reading too much into the current finite-sample output.
{p_end}

{phang2}{cmd:. display "--- Diagnostic: trimming rate ---"}{p_end}
{phang2}{cmd:. local raw_n = e(N) + e(N_trimmed)}{p_end}
{phang2}{cmd:. display "Total trimmed: " e(N_trimmed) " out of " `raw_n' " (" %4.1f 100*e(N_trimmed)/`raw_n' "% )"}{p_end}

{pstd}
High trimming rate (>10%) may indicate propensity score model issues rather
than a benign reporting detail, because the paper/R AIPW score is only formed
on the retained overlap sample.
{p_end}

{pstd}
When {cmd:seed()} is omitted, rerunning the same command on the same retained
sample keeps the same outer fold assignment.  Supplying {cmd:seed()} instead
fixes the command's seed-indexed outer fold map, bootstrap draws, and the
Python CLIME CV split, while still restoring the caller's pre-existing RNG
state on exit.  Once that outer fold map is fixed, the Stata
{cmd:cvlasso}/{cmd:cvlassologit} inner CV partitions follow deterministic
row order rather than a separate random split.  With internally estimated
first stages, {cmd:hddid} keeps the propensity path on a deterministic row
order over {cmd:treat}, outer fold rank, and {cmd:W=(X,Z)}, so that path
stays outcome-blind but is not literally {cmd:W}-only, and canonicalizes the outcome/second-stage/
M-matrix row order on their realized regression data; under {cmd:nofirst},
{cmd:hddid} first keeps the current within-group order inside tied fold-rank
groups after the treatment-plus-fold-rank preprocessing sort, but before the
retained second-stage and M-matrix fits it re-sorts deterministically by
retained fold, trim status, {cmd:x()}, {cmd:z()}, and retained DR score.
In particular,
explicit {cmd:seed(0)} is a seeded run, not an alias for the omitted-{cmd:seed()}
/ {cmd:seed(-1)} sentinel path.
{p_end}

{marker references}{...}
{title:References}

{marker NPT2024}{...}
{phang}
Ning, Y., S. Peng, and J. Tao. 2024. Doubly robust semiparametric
difference-in-differences estimators with high-dimensional data.
{it:Review of Economics and Statistics} 106(4): 1063-1080.
{p_end}

{phang}
Abadie, A. 2005. Semiparametric difference-in-differences estimators.
{it:Review of Economic Studies} 72(1): 1-19.
{p_end}

{phang}
Ahrens, A., C. B. Hansen, and M. E. Schaffer. 2020. lassopack: Model
selection and prediction with regularized regression in Stata.
{it:Stata Journal} 20(1): 176-235.
{p_end}

{marker authors}{...}
{title:Authors}

{pstd}
HDDID Development Team
{p_end}
