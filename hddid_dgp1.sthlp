{smcl}
{* *! version 1.0.0  2026-03-12}{...}
{viewerjumpto "Syntax" "hddid_dgp1##syntax"}{...}
{viewerjumpto "Description" "hddid_dgp1##description"}{...}
{viewerjumpto "Options" "hddid_dgp1##options"}{...}
{viewerjumpto "Generated variables" "hddid_dgp1##generated"}{...}
{viewerjumpto "Notes" "hddid_dgp1##notes"}{...}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{cmd:hddid_dgp1} {hline 2}}Generate DGP1 data for {cmd:hddid}{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:hddid_dgp1}{cmd:,}
{opt n(#)}
{opt p(#)}
[{opt seed(#)} {opt clear}]

{marker description}{...}
{title:Description}

{pstd}
{cmd:hddid_dgp1} generates the package's DGP1 simulation dataset used for
testing and examples.  The design follows the homoskedastic, independent-X
data-generating process used in Section 5 of the HDDID paper, with the shipped
generator truncating the paper's nonzero coefficient sequences when the user
requests fewer than 10 or 15 covariates.
{p_end}

{pstd}
The command generates a newly simulated sample containing high-dimensional
covariates, one scalar {cmd:z}, a binary treatment indicator, and the outcome
change variable {cmd:deltay}.  If memory already contains an existing dataset,
including a 0-observation dataset with variables already defined, you must
specify {opt clear} to replace it.  A metadata-only empty surface (for example
dataset characteristics or value labels with no variables and no observations)
does not require {opt clear}.
{p_end}

{pstd}
More specifically, {cmd:hddid_dgp1} draws {cmd:x1}-{cmd:xp} and {cmd:z}
independently from standard normal distributions, sets

{pmore}
P(T=1|X) = 1 - (1 + exp(X'theta_0))^-1

{pstd}
with theta_0i = 1/i for i <= 10 and 0 otherwise, and then constructs

{pmore}
the no-anticipation base period uses one shared base-period potential outcome draw per unit: a single baseline draw Y^0(i,0) = Y^1(i,0) ~ N(0,1) is realized for each unit, and the observed base-period outcome is that same shared baseline, denoted Y(i,0) in the paper's compact notation. In the shipped implementation, both post-period treatment states add their own increments to that same baseline,

{pmore}
Y^1(i,1) = Y(i,0) + X'beta^1 + exp(z) + eps1,

{pmore}
Y^0(i,1) = Y(i,0) + X'beta^0 + eps0,

{pstd}
where beta^1_i = 2/i and beta^0_i = 1/i for i <= 15 and 0 otherwise, with
independent standard normal {cmd:eps0} and {cmd:eps1}.  The generated public
outcome is the realized post-minus-base change stored in {cmd:deltay}; it is
not the post-period treatment-state contrast {cmd:Y^1(i,1) - Y^0(i,1)}.
Running hddid on this generated deltay sample means the returned parametric
block targets the ATT-surface contrast beta_j = beta^1_j - beta^0_j = 1/j on
that support, and the returned nonparametric block is the public omitted-intercept z-varying block
aligned to the posted evaluation grid, not either raw treated- or control-outcome slope sequence by
itself. Because {cmd:hddid} does not currently publish {cmd:e(a0)}, that public block is not the
full paper level {cmd:f(z0) = exp(z0)}. Public truth checks should therefore compare centered differences on the posted evaluation grid
rather than uncentered levels. The full heterogeneous ATT at a test point still contains the separate stage-2 intercept a0.
The full heterogeneous ATT at a test point still remains {cmd:x0'beta + f(z0)} rather than {cmd:f(z0)} alone or the public omitted-intercept block by itself,
so the generated DGP1 oracle for {cmd:hddid} is the combined partially linear ATT surface rather
than the public nonparametric block by itself.
{p_end}

{pstd}
For the shipped generator, the paper's coefficient sequences are truncated to
the requested covariate width.  When {cmd:p() < 10}, only the theta_0 entries
through i = p are used in the propensity score.  When {cmd:p() < 15},
beta^1_i = 2/i and beta^0_i = 1/i only through i = p, so small-{cmd:p()}
calls are a lower-dimensional truncation of the paper's DGP1 rather than the
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
room for 12 additional temporary variables at peak, so very large {cmd:p()}
values can be rejected by Stata's {cmd:maxvar} limit before generation starts.
Relative to the paper's DGP1, {cmd:p()<10} truncates the propensity-score
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
{opt clear} permits {cmd:hddid_dgp1} to replace an existing dataset already in
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
{synopt:{cmd:x1} ... {cmd:xp}}independent standard normal covariates{p_end}
{synopt:{cmd:z}}standard normal nonparametric covariate{p_end}
{synopt:{cmd:treat}}Bernoulli treatment indicator drawn from the DGP propensity score{p_end}
{synopt:{cmd:deltay}}post-minus-base outcome change{p_end}
{synoptline}

{marker notes}{...}
{title:Notes}

{phang}
If memory already contains an existing dataset, including a 0-observation
dataset with variables already defined, {cmd:hddid_dgp1} requires
{opt clear} before it replaces that dataset.  A metadata-only empty surface
with no variables and no observations does not require {opt clear}.
{p_end}

{phang}
If {cmd:hddid_dgp1} fails after generation starts, the command restores the
caller dataset instead of leaving behind a partially built replacement.
{p_end}

{phang}
When {opt seed()} is supplied with an integer in {cmd:[0, 2147483647]},
{cmd:hddid_dgp1} restores the caller's RNG state on exit, so the explicit
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
A shipped DGP1/Tri walkthrough: generate with
{cmd:hddid_dgp1, n(500) p(50) seed(12345) clear}, then run
{cmd:hddid deltay, treat(treat) x(`x_vars') z(z) method("Tri") q(16) z0(-1 -0.5 0 0.5 1) K(3) alpha(0.1) nboot(1000) seed(42)}.
Under {cmd:method(Tri)}, keep {cmd:z0()} inside the retained z support.
{p_end}

{phang}
The generator is self-contained and callable via absolute-path source-run.
Only {cmd:x1}-{cmd:xp}, {cmd:z}, {cmd:treat}, and {cmd:deltay} are kept;
internal intermediates are dropped.
{p_end}

{phang}
The generation path is also constrained by Stata's variable-capacity limit.
Before clearing memory, {cmd:hddid_dgp1} checks whether the requested
{cmd:p()} plus its temporary working variables fit under the current
{cmd:maxvar} setting, and it exits with an error if that budget is infeasible.
{p_end}
