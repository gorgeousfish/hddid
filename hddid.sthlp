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
{synopt:{opt stage1penalty(string)}}Stage-1 lasso penalty mode for {cmd:pi(W)}, {cmd:Phi1(W)}, {cmd:Phi0(W)}: {cmd:full} (default; penalize all of W=(X,psi(Z))) or {cmd:partial} (notpen psi(Z), partially-linear-consistent with Stage-2){p_end}
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
(6) Gaussian bootstrap for the paper-Theorem 5.2 sup-quantile critical value
{it:c*} = q_{1-alpha}(max_z |T_z*|) and construction of the published
{cmd:e(CIuniform)} = {cmd:e(gdebias)} +/- {it:c*} {cmd:* e(stdg)} as the
canonical uniform band; the legacy rowwise-envelope band is retained as
{cmd:e(CIuniform_env)} for backward-compatible inspection.
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
{cmd:e(gdebias)} is the debiased nonparametric estimate on the {cmd:e(z0)}
grid excluding the separate stage-2 intercept, and the nonparametric columns of
{cmd:e(CIpoint)}/{cmd:e(CIuniform)} follow that same centered block.  The
stage-2 intercept is published separately as the scalar {cmd:e(a0)}, so the
full level is {cmd:f(z0) = e(a0) + e(gdebias)} on the posted grid.  The full
heterogeneous ATT at a test point is {cmd:x0'e(b) + e(a0) + f(z0)}.  For
observation-level values on the current sample, use {cmd:predict}
(see {help hddid##postestimation:Postestimation}).
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
{cmd:nboot(1000)}, minimum 2.  Changing {cmd:nboot()} recalibrates the
sup-quantile {cmd:e(tc)}/{cmd:e(CIuniform)} pair (paper Theorem 5.2) and
the legacy rowwise-envelope {cmd:e(tc_env)}/{cmd:e(CIuniform_env)} pair on
the same studentized draws; it does not affect the analytic pointwise
{cmd:e(CIpoint)}, {cmd:e(stdx)}, or {cmd:e(stdg)} objects.
The sup-quantile {cmd:e(CIuniform)} band gives family-wise coverage at the
nominal {cmd:1 - alpha} level on the posted finite {cmd:e(z0)} grid; the
rowwise-envelope {cmd:e(CIuniform_env)} variant is generally tighter but
undercovers jointly when the studentized process exhibits cross-{it:z}
correlation.
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
{opt stage1penalty(string)} chooses the L1 penalty mode for the Stage-1
nuisance lassos that fit the propensity score {cmd:pi(W) = P(D=1|W)} and
the conditional outcome means {cmd:Phi1(W) = E[deltaY|W,D=1]} and
{cmd:Phi0(W) = E[deltaY|W,D=0]}, where {cmd:W = (X, psi(Z))} stacks the
high-dimensional covariates with the low-dimensional sieve basis columns.
{p_end}

{pmore}
{cmd:full} (default; matches the R reference {it:HDdiffindiff}) penalizes
every column of {cmd:W}, treating {cmd:psi(Z)} the same as {cmd:X}.  This
is conservative when the true {cmd:Phi_d(W)} need not be partially linear.
{p_end}

{pmore}
{cmd:partial} leaves the {cmd:psi(Z)} columns unpenalized via {cmd:notpen()},
matching the partially-linear-consistent Stage-2 lasso (which already
publishes the sieve coefficients under {cmd:notpen()}).  Use this mode when
you believe the partially linear structure of {cmd:tau(X,Z) = X'beta + f(Z)}
extends to the AIPW nuisance functions {cmd:Phi_d(W)}, so that the low-
dimensional {cmd:psi(Z)} block should not be shrunk away by CV.
{p_end}

{pmore}
The chosen mode is recorded in {cmd:e(stage1penalty)} when {cmd:e(firststage_mode)}
is {cmd:internal}.  Under {cmd:nofirst}, Stage-1 lassos are skipped entirely,
so {cmd:stage1penalty()} has no effect and is not recorded.
{p_end}

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
After {cmd:hddid}, {cmd:predict} is supported for observation-level
predictions of the fitted CATT surface.  {cmd:estat} and {cmd:margins} are
not supported.
{p_end}

{p 8 16 2}
{cmd:predict} {it:newvar} [{it:if}] [{it:in}] [{cmd:,} {it:statistic}]

{synoptset 16 tabbed}{...}
{synopthdr:statistic}
{synoptline}
{synopt:{opt tau}}full CATT, {cmd:X'}{it:beta}{cmd: + f(Z)}; the default{p_end}
{synopt:{opt xb}}parametric component {cmd:X'}{it:beta}{cmd: }(debiased coefficients in {cmd:e(b)}){p_end}
{synopt:{opt fz}}nonparametric component {cmd:f(Z) = e(a0) + psi(Z)'e(gammabar)_q}, with {it:psi}(.) the stored sieve basis{p_end}
{synoptline}

{pstd}
Only one of {opt tau}, {opt xb}, or {opt fz} may be specified.  Under
{cmd:method(Tri)}, {cmd:predict} reuses the stored
{cmd:e(z_support_min)}/{cmd:e(z_support_max)} support normalization; requested
Z values outside that interval are not automatically flagged, so use
{cmd:predict} only on rows whose Z lies within the estimation support.
{cmd:predict} requires the estimation to have posted {cmd:e(gammabar)} and
{cmd:e(a0)}; results stored by older builds that did not post these objects
cannot service {opt fz} or {opt tau} and must be re-estimated.
{p_end}

{pstd}
Key postestimation objects:
{p_end}

{p2colset 8 32 34 2}{...}
{p2col:Parametric:}{cmd:e(b)}, {cmd:e(V)}, {cmd:e(xdebias)}, {cmd:e(stdx)}{p_end}
{p2col:Nonparametric:}{cmd:e(gdebias)}, {cmd:e(stdg)}, {cmd:e(z0)}, {cmd:e(a0)}, {cmd:e(gammabar)}{p_end}
{p2col:Intervals:}{cmd:e(CIpoint)}, {cmd:e(CIuniform)} (sup), {cmd:e(CIuniform_env)} (envelope), {cmd:e(tc)} (sup), {cmd:e(tc_env)} (envelope){p_end}
{p2colreset}{...}

{pstd}
{cmd:e(CIpoint)} has {cmd:e(p)+e(qq)} columns: the first {cmd:e(p)} columns
are pointwise CIs for the beta block; the remaining {cmd:e(qq)} columns are
pointwise CIs for the centered (intercept-omitted) nonparametric block on
{cmd:e(z0)}.  {cmd:e(CIuniform)} is the paper-Theorem 5.2 sup-quantile
Gaussian-bootstrap band for the same centered nonparametric block, with
family-wise coverage at the nominal {cmd:1 - alpha} level on the posted
finite {cmd:e(z0)} grid.  The legacy rowwise-envelope variant is retained
as {cmd:e(CIuniform_env)} for backward-compatible inspection but is not a
paper-proven simultaneous-coverage band.  For full {cmd:f(z0)} level
comparisons, combine with {cmd:e(a0)}.
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
{synopt:{cmd:e(a0)}}stage-2 intercept (weighted across folds); full level is {cmd:f(z0) = e(a0) + e(gdebias)}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(xdebias)}}1 x p debiased parametric estimates{p_end}
{synopt:{cmd:e(stdx)}}1 x p parametric standard errors{p_end}
{synopt:{cmd:e(gdebias)}}1 x qq debiased nonparametric estimates{p_end}
{synopt:{cmd:e(stdg)}}1 x qq nonparametric standard errors{p_end}
{synopt:{cmd:e(tc)}}1 x 2 sup-quantile bootstrap critical-value pair (-c*, +c*) (paper Theorem 5.2){p_end}
{synopt:{cmd:e(tc_env)}}1 x 2 rowwise-envelope bootstrap critical-value pair (lower, upper) (legacy){p_end}
{synopt:{cmd:e(CIpoint)}}2 x (p+qq) pointwise CI bounds (lower; upper){p_end}
{synopt:{cmd:e(CIuniform)}}2 x qq sup-quantile uniform interval bounds (lower; upper); paper Theorem 5.2 family-wise band{p_end}
{synopt:{cmd:e(CIuniform_env)}}2 x qq rowwise-envelope uniform interval bounds (lower; upper); legacy backward-compatibility band{p_end}
{synopt:{cmd:e(clime_nfolds_cv_per_fold)}}1 x k realized CLIME CV folds per fold{p_end}
{synopt:{cmd:e(stage1_lambda_ratio)}}1 x k diagnostic ratio {it:lambda_CV / sqrt(log(p+q)/n_train)} for the Stage-1 propensity-score lasso (paper Assumption 8); missing for the constant-W intercept-only path and the {cmd:nofirst} mode{p_end}
{synopt:{cmd:e(stage2_lambda_ratio)}}1 x k diagnostic ratio {it:lambda_CV / sqrt(log(p+q)/n_valid)} for the Stage-2 lasso (paper Assumption 9 + Eq (3.1)); missing for the constant-DR-response shortcut fold{p_end}
{synopt:{cmd:e(b)}}1 x p coefficient vector (same as e(xdebias)){p_end}
{synopt:{cmd:e(V)}}p x p parametric variance-covariance matrix for {cmd:e(b)}; {cmd:diag(e(V)) = e(stdx)^2}{p_end}
{synopt:{cmd:e(z0)}}1 x qq evaluation points{p_end}
{synopt:{cmd:e(N_per_fold)}}1 x k post-trim fold sample sizes{p_end}
{synopt:{cmd:e(gammabar)}}1 x (q+1) debiased sieve coefficients; first entry is {cmd:e(a0)} and remaining entries are the debiased non-constant basis coefficients used by {cmd:predict, fz}{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:hddid}{p_end}
{synopt:{cmd:e(cmdline)}}full command line{p_end}
{synopt:{cmd:e(vce)}}{cmd:robust}{p_end}
{synopt:{cmd:e(vcetype)}}{cmd:Robust}{p_end}
{synopt:{cmd:e(predict)}}{cmd:hddid_p}{p_end}
{synopt:{cmd:e(estat_cmd)}}{cmd:hddid_estat} (unsupported){p_end}
{synopt:{cmd:e(marginsnotok)}}{cmd:_ALL}{p_end}
{synopt:{cmd:e(firststage_mode)}}{cmd:internal} or {cmd:nofirst}{p_end}
{synopt:{cmd:e(stage1penalty)}}Stage-1 lasso penalty mode: {cmd:full} or {cmd:partial} (only when {cmd:e(firststage_mode)} is {cmd:internal}){p_end}
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
Prerequisites: {cmd:lassopack} for {cmd:lasso2}/{cmd:cvlasso}/{cmd:cvlassologit}.
When {cmd:x()} has more than one covariate, Stata 16+ Python integration
({cmd:numpy>=1.20}, {cmd:scipy>=1.7}) is also required for the CLIME debiasing
path; a single-covariate run uses the analytic scalar shortcut and does not
call Python.  Run {cmd:python query} to check the active interpreter.  The
bundled {cmd:hddid_example.do} walkthrough can be located with
{cmd:findfile hddid_example.do}.
{p_end}

{dlgtab:Basic estimation with DGP1 (independent X, homoskedastic)}

{phang2}{cmd:. hddid_dgp1, n(500) p(50) seed(12345) clear}{p_end}
{phang2}{cmd:. unab x_vars : x*}{p_end}
{phang2}{cmd:. hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(16) ///}{p_end}
{phang2}{cmd:.     z0(-1 -0.5 0 0.5 1) K(3) alpha(0.1) nboot(1000) seed(42)}{p_end}

{pstd}
DGP1 independently draws {cmd:x1}-{cmd:xp} and {cmd:z} as standard normal.
The ATT-surface parametric truth is {cmd:beta_j = 1/j} for {cmd:j <= 15}
(and 0 afterward), and the nonparametric truth is {cmd:f(z) = exp(z)}.  The
{cmd:q(16)} {cmd:method(Tri)} call implements the paper's 8th-degree
trigonometric baseline under the package's {cmd:q()/2} harmonic indexing.
{p_end}

{pstd}
For DGP1 generators with {cmd:p() < 10} or {cmd:p() < 15}, the paper's
propensity and outcome coefficient sequences are truncated at the requested
covariate width; small-{cmd:p()} runs are lower-dimensional versions of the
paper design.  Under {cmd:method(Tri)}, every requested {cmd:z0()} point must
lie inside the retained {cmd:z} support; out-of-support points trigger an
error rather than silent periodic extrapolation.
{p_end}

{dlgtab:Access stored results}

{phang2}{cmd:. display "N = " e(N) ", p = " e(p) ", qq = " e(qq)}{p_end}
{phang2}{cmd:. matrix list e(xdebias), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(stdx),    format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(z0),      format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(gdebias), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(CIpoint), format(%9.4f)}{p_end}
{phang2}{cmd:. matrix list e(CIuniform), format(%9.4f)}{p_end}
{phang2}{cmd:. display "a0 = " e(a0)}{p_end}
{phang2}{cmd:. matrix list e(gammabar), format(%9.4f)}{p_end}

{pstd}
The first {cmd:e(p)} columns of {cmd:e(CIpoint)} are beta-block pointwise
CIs in {cmd:e(xvars)} order; the trailing {cmd:e(qq)} columns are the
centered nonparametric CIs on {cmd:e(z0)}.  The full level at posted
evaluation points is {cmd:e(a0) + e(gdebias)}.
{p_end}

{dlgtab:Truth checks on DGP1}

{pstd}
Parametric block: the first coordinate truth is {cmd:beta_1 = 1}.
{p_end}

{phang2}{cmd:. local beta1 = el(e(xdebias), 1, 1)}{p_end}
{phang2}{cmd:. local se1   = el(e(stdx),    1, 1)}{p_end}
{phang2}{cmd:. local tstat = (`beta1' - 1) / `se1'}{p_end}
{phang2}{cmd:. display "beta_1 = " %9.4f `beta1' ", SE = " %9.4f `se1' ", t(H0:beta_1=1) = " %6.3f `tstat'}{p_end}

{pstd}
Nonparametric block: the level truth is {cmd:f(z) = exp(z)}.  Compare
{cmd:e(a0) + e(gdebias)} with {cmd:exp(e(z0))} directly:
{p_end}

{phang2}{cmd:. local qq = colsof(e(z0))}{p_end}
{phang2}{cmd:. forvalues j = 1/`qq' {c -(}}{p_end}
{phang2}{cmd:.     local z0_j = el(e(z0), 1, `j')}{p_end}
{phang2}{cmd:.     local fhat_j = e(a0) + el(e(gdebias), 1, `j')}{p_end}
{phang2}{cmd:.     local ftrue_j = exp(`z0_j')}{p_end}
{phang2}{cmd:.     display "z0 = " %6.2f `z0_j' "  f_hat = " %8.4f `fhat_j' "  exp(z0) = " %8.4f `ftrue_j'}{p_end}
{phang2}{cmd:. {c )-}}{p_end}

{pstd}
{cmd:e(CIuniform)} is the paper-Theorem 5.2 sup-quantile band for the
centered nonparametric block on the finite {cmd:e(z0)} grid, providing
family-wise coverage at the nominal {cmd:1 - alpha} level on that grid;
the legacy rowwise-envelope variant remains available as
{cmd:e(CIuniform_env)} but is generally too tight under cross-{it:z}
dependence in the studentized process.
{p_end}

{dlgtab:Postestimation predict}

{pstd}
After {cmd:hddid}, {cmd:predict} produces observation-level fitted values for
the CATT surface.  The decomposition {cmd:tau = xb + fz} lets you audit each
component separately.
{p_end}

{phang2}{cmd:. predict double tau_hat}{p_end}
{phang2}{cmd:. predict double xb_hat, xb}{p_end}
{phang2}{cmd:. predict double fz_hat, fz}{p_end}
{phang2}{cmd:. summarize tau_hat xb_hat fz_hat}{p_end}
{phang2}{cmd:. generate double check = tau_hat - xb_hat - fz_hat}{p_end}
{phang2}{cmd:. summarize check}{p_end}

{pstd}
Under {cmd:method(Tri)}, {cmd:predict} reuses the stored support
normalization; restrict prediction to rows whose Z lies inside
{cmd:[e(z_support_min), e(z_support_max)]} to avoid periodic extrapolation.
{p_end}

{dlgtab:DGP2 (correlated X, heteroskedastic baseline)}

{phang2}{cmd:. hddid_dgp2, n(500) p(50) seed(54321) rho(0.5) clear}{p_end}
{phang2}{cmd:. unab x_vars : x*}{p_end}
{phang2}{cmd:. hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(16) ///}{p_end}
{phang2}{cmd:.     z0(-1 -0.5 0 0.5 1) K(3) alpha(0.1) nboot(1000) seed(42)}{p_end}

{pstd}
DGP2 keeps the same ATT-surface beta truth ({cmd:beta_j = 1/j for j <= 15})
and the same {cmd:f(z) = exp(z)}.  Only the X-law and baseline construction
differ: {cmd:X ~ N(0, Sigma)} with {cmd:Sigma_jk = rho^|j-k|}, and the
baseline outcome is multiplicative, {cmd:Y(i,0) = eps_tilde * (z + x1)/sqrt(2)}.
With {cmd:p(1)} the AR(1) covariance collapses to the 1 x 1 matrix {cmd:[1]},
so any finite {cmd:rho()} generates the same draw.
{p_end}

{dlgtab:Basis-family comparison at matched q}

{phang2}{cmd:. hddid_dgp1, n(500) p(50) seed(12345) clear}{p_end}
{phang2}{cmd:. unab x_vars : x*}{p_end}
{phang2}{cmd:. hddid deltay, treat(treat) x(`x_vars') z(z) method("Pol") q(8) K(3) seed(42)}{p_end}
{phang2}{cmd:. local pol_b1 = el(e(xdebias), 1, 1)}{p_end}
{phang2}{cmd:. local pol_se = el(e(stdx),    1, 1)}{p_end}
{phang2}{cmd:. hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(8) K(3) seed(42)}{p_end}
{phang2}{cmd:. local tri_b1 = el(e(xdebias), 1, 1)}{p_end}
{phang2}{cmd:. local tri_se = el(e(stdx),    1, 1)}{p_end}
{phang2}{cmd:. display "Pol q(8) : beta_1 = " %7.4f `pol_b1' " (SE " %6.4f `pol_se' ")"}{p_end}
{phang2}{cmd:. display "Tri q(8) : beta_1 = " %7.4f `tri_b1' " (SE " %6.4f `tri_se' ")"}{p_end}

{pstd}
Same-{cmd:q()} comparison is a functional-family demo, not a matched-degree
comparison: under {cmd:method(Tri)}, {cmd:q(8)} is only a 4th-degree
trigonometric basis because the harmonic index runs {cmd:1, ..., q/2}.  To
match an 8th-degree trigonometric baseline, use {cmd:q(16)}.
{p_end}

{dlgtab:Common diagnostics}

{pstd}
Post-trim fold weights and trimming rate:
{p_end}

{phang2}{cmd:. matrix list e(N_per_fold)}{p_end}
{phang2}{cmd:. local raw_n = e(N) + e(N_trimmed)}{p_end}
{phang2}{cmd:. display "Trimmed " e(N_trimmed) " of " `raw_n' " (" %4.1f 100*e(N_trimmed)/`raw_n' "%)"}{p_end}

{pstd}
High trimming rates (>10%) may indicate propensity model issues.  Under
{cmd:nofirst}, overlap trimming is applied to the supplied {cmd:pihat()}
values; the broader strict-interior sample is used for fold assignment and
the narrower retained sample is used for second-stage estimation.
{p_end}

{pstd}
RNG provenance: when {cmd:seed()} is a nonnegative integer, {cmd:e(seed)} is
posted and the caller's prior session RNG state is restored on exit.  The
explicit sentinel {cmd:seed(-1)} (or omission) does not reset the RNG and
therefore leaves {cmd:e(seed)} unposted.
{p_end}

{pstd}
Lambda ratio diagnostics: paper Assumption 8 (Stage-1 propensity-score
lasso) and Assumption 9 (Stage-2 lasso) require the regularization parameter
to scale as {it:lambda} ~ {cmd:sqrt(log(p+q)/n_fold)}.  The published
diagnostics
{p_end}

{phang2}{cmd:. matrix list e(stage1_lambda_ratio)}{p_end}
{phang2}{cmd:. matrix list e(stage2_lambda_ratio)}{p_end}

{pstd}
report the realized {cmd:lambda_CV / sqrt(log(p+q)/n_fold)} per outer fold.
A ratio in the order of unity (roughly {cmd:[0.1, 10]}) is consistent with
the paper rate; very small values indicate under-shrinkage from a flat CV
curve, and very large values indicate over-shrinkage typical of small or
contaminated training samples.  Missing entries flag folds where no
penalized lasso was fit -- the constant-W intercept-only path for Stage-1,
the constant-DR-response shortcut for Stage-2, or the {cmd:nofirst} mode.
The diagnostics are informational only; they do not alter the estimator.
{p_end}

{pstd}
Uniform confidence band choice: {cmd:e(CIuniform)} is the paper-Theorem 5.2
sup-quantile band built from the symmetric critical value {it:c*} =
{cmd:q_{1-alpha}(max_z |T_z*|)}, which delivers family-wise coverage at the
nominal {cmd:1 - alpha} level on the posted {cmd:e(z0)} grid.  The legacy
rowwise-envelope band {cmd:e(CIuniform_env)} = {cmd:[min_z q_{alpha/2}(T_z),
max_z q_{1-alpha/2}(T_z)] * e(stdg)} guarantees pointwise coverage at every
{it:z} but does not have the family-wise guarantee.  Use the published
{cmd:e(CIuniform)} for paper-faithful simultaneous inference and consult
{cmd:e(CIuniform_env)} only for diagnostic comparison.
{p_end}

{dlgtab:Input errors}

{phang2}{cmd:. capture noisily hddid deltay, x(`x_vars') z(z)}{p_end}
{phang2}{cmd:. display "rc = " _rc " (missing treat(): expected 198)"}{p_end}

{phang2}{cmd:. capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(7)}{p_end}
{phang2}{cmd:. display "rc = " _rc " (odd q with method(Tri): expected 198)"}{p_end}

{phang2}{cmd:. capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) nofirst}{p_end}
{phang2}{cmd:. display "rc = " _rc " (nofirst without pihat/phi1hat/phi0hat: expected 198)"}{p_end}

{phang2}{cmd:. capture noisily hddid deltay, treat(treat) x(`x_vars') z(z) aipw}{p_end}
{phang2}{cmd:. display "rc = " _rc " (estimator-family switches are not accepted: expected 198)"}{p_end}

{pstd}
{cmd:method()} only selects the sieve basis family; {cmd:hddid} always
implements the paper's AIPW doubly robust estimator, so {cmd:ra}, {cmd:ipw},
{cmd:aipw}, or {cmd:estimator()} tokens are rejected.
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
