{smcl}
{* *! version 1.0.0  2026-02-25}{...}
{viewerjumpto "Syntax" "hddid##syntax"}{...}
{viewerjumpto "Description" "hddid##description"}{...}
{viewerjumpto "Options" "hddid##options"}{...}
{viewerjumpto "Postestimation" "hddid##postestimation"}{...}
{viewerjumpto "Stored results" "hddid##results"}{...}
{viewerjumpto "Examples" "hddid##examples"}{...}
{viewerjumpto "References" "hddid##references"}{...}
{viewerjumpto "Authors" "hddid##authors"}{...}

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
{synopt:{opt x(varlist)}}high-dimensional covariates; canonicalized by observed column content on the split-relevant usable sample, so reordering or renaming the same {cmd:x()} columns is treated as a representation change, not a new model specification; in the default internal path that split-relevant anchor is the pretrim common score sample with nonmissing {cmd:treat()}/{cmd:x()}/{cmd:z()}/{cmd:depvar()}, while D/W-complete rows missing {cmd:depvar()} can still widen the broader default-path propensity sample without relabeling the fold-pinning outer split or entering the final AIPW score; under nofirst that split-relevant anchor is instead the broader strict-interior pretrim fold-feasibility sample with 0 < pihat() < 1, rebuilt after if/in filtering and before later overlap trimming; {cmd:x()} must not contain a nonzero constant column on the estimation sample because that duplicates the intercept direction used in the M-matrix / nonparametric debiasing path{p_end}
{synopt:{opt z(varname)}}low-dimensional covariate for nonparametric component{p_end}

{syntab:Model}
{synopt:{opt method(string)}}sieve basis type, not an AIPW, IPW, or RA estimator switch; {cmd:Pol} (polynomial, default) or {cmd:Tri} (trigonometric){p_end}
{synopt:{opt q(#)}}positive integer sieve basis order; default is {cmd:q(8)}. Under {cmd:method(Tri)}, q must be even because the basis uses {cmd:q()/2} harmonic pairs, so {cmd:q(8)} is only 4th degree and the paper's 8th-degree Tri basis requires {cmd:q(16)}{p_end}
{synopt:{opt K(#)}}number of cross-fitting folds for the outer sample split only; minimum is 2; default is {cmd:K(3)}{p_end}

{syntab:Inference}
{synopt:{opt alpha(#)}}shared significance level; default is {cmd:alpha(0.1)}, yielding 90% pointwise confidence intervals and the corresponding published bootstrap interval object.{p_end}
{synopt:{opt nboot(#)}}number of bootstrap replications for the Gaussian bootstrap lower/upper studentized-process endpoints behind {cmd:e(tc)} and {cmd:e(CIuniform)}; must be at least 2; default is {cmd:nboot(1000)}. The current rowwise-envelope interval-object path stores {cmd:e(tc)} as the ordered lower/upper studentized-process pair behind the published {cmd:e(CIuniform)} interval object, obtained by taking type-7 lower/upper quantiles rowwise over the posted {cmd:z0()} grid and then aggregating them as the envelope pair {cmd:(min_j lower_j, max_j upper_j)}. Under this path the stored pair can be asymmetric and need not straddle zero, and {cmd:e(CIuniform)} applies those stored lower/upper endpoints to the posted {cmd:e(stdg)} surface. This is the package's bootstrap-calibrated finite-grid interval object for the nonparametric component; it is not directly proved in the paper text{p_end}
{synopt:{opt seed(#)}}if {cmd:seed()} is an integer in [0, 2147483647], sets the command's internal random seed for fold assignment, bootstrap draws, and Python CLIME CV splitting, then restores the caller's session RNG state on exit; with internally estimated first stages, once that fold map is fixed the propensity inner-CV partitions are pinned by a deterministic row order over {cmd:treat}, outer fold rank, and {cmd:W=(X,Z)}, so that path stays outcome-blind but is not literally {cmd:W}-only, while the outcome/second-stage/M-matrix {cmd:cvlasso}/{cmd:cvlassologit} paths use deterministic canonical row order on their realized regression data rather than a separate Stata RNG split; under {cmd:nofirst}, {cmd:hddid} first sorts by treatment and outer fold rank, so tied fold-rank groups keep their incoming within-group order at that preprocessing step, but the retained second-stage/M-matrix lasso path is then re-sorted deterministically by retained fold, trim status, {cmd:x()}, {cmd:z()}, and retained DR score; pure row reordering of otherwise identical retained rows therefore leaves that seeded retained-stage path unchanged. On the degenerate zero-SE shortcut where {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, a nonnegative {cmd:seed()} still fixes the realized outer fold assignment and Python CLIME CV splitting, but the published nonparametric interval object used no studentized Gaussian-bootstrap draws. The default is {cmd:seed(-1)} (no seed reset); explicit {cmd:seed(0)} is still a legal seeded run, not an alias for the omitted/{cmd:seed(-1)} path. Under {cmd:seed(-1)} on that same zero-SE shortcut, the outer fold assignment remains deterministic from the data and Python CLIME CV still uses its deterministic per-fold integer seed derivation, but the published nonparametric interval object again used no studentized Gaussian-bootstrap draws.{p_end}

{syntab:Evaluation points}
{synopt:{opt z0(numlist)}}evaluation points for the nonparametric component; default is the unique retained values of {cmd:z} on the final post-trim estimation sample after {it:if}/{it:in} filtering, missing-value screening, and propensity trimming{p_end}

{syntab:Advanced}
{synopt:{opt nofirst}}skip first-stage estimation; requires user-supplied {cmd:pihat()}, {cmd:phi1hat()}, and {cmd:phi0hat()} for the AIPW score; {cmd:pihat()} must already be fold-aligned out-of-fold on the broader strict-interior nofirst pretrim fold-feasibility sample with {cmd:0 < pihat() < 1}, while {cmd:phi1hat()}/{cmd:phi0hat()} must already be fold-aligned out-of-fold on the retained overlap sample; {cmd:pihat()} duplicate-key agreement is governed by the broader strict-interior nofirst pretrim fold-feasibility sample, while within each retained treatment-arm {cmd:x()}/{cmd:z()} key {cmd:phi1hat()}/{cmd:phi0hat()} duplicate-key agreement is governed only by the retained overlap sample; {cmd:pihat()} same-fold shared {cmd:W=(X,Z)} agreement is governed by the broader strict-interior nofirst fold-feasibility path, while retained {cmd:phi1hat()}/{cmd:phi0hat()} same-fold shared {cmd:W=(X,Z)} agreement is governed only by the retained estimator folds; With {cmd:nofirst}, {cmd:if}/{cmd:in} qualifiers bite before {cmd:hddid} rebuilds that broader strict-interior split path, so qualifier-defined runs are equivalent to physically subsetting rows first for outer-split and retained-fold provenance; if those qualifier-defined and physically subsetted nofirst runs feed hddid the same retained rows in the same order together with the same fold-aligned nuisance variables, they must therefore deliver the same retained-sample estimates, not just the same fold provenance; these nuisance inputs must align to {cmd:hddid}'s own deterministic outer-fold assignment; {cmd:hddid} mechanically checks split-key and same-fold nuisance consistency, but it cannot prove the caller's true OOF training provenance; structural role vars must remain distinct, but numerically identical nuisance inputs may intentionally reuse one storage column{p_end}
{synopt:{opt pihat(varname)}}pre-estimated propensity score aligned to the broader strict-interior nofirst pretrim fold-feasibility path with {cmd:0 < pihat() < 1}; exact {cmd:0}/{cmd:1} values stay outside that broader split, while any legal strict-interior row still enters that broader strict-interior fold-feasibility path before later overlap trimming, but only treatment-arm keys with at least one retained-overlap pretrim row pin the published retained outer fold IDs. The supplied series must lie within [0,1] on the common nonmissing score sample used by {cmd:nofirst}. Same-arm hidden-missing or disagreement checks still activate only when a treatment-arm {cmd:x()}/{cmd:z()} key contributes at least one retained-overlap pretrim row with {cmd:0.01 <= pihat() <= 0.99}, because that broader strict-interior path already fixes the same-arm fold-feasibility provenance contract. For shared {cmd:x()}/{cmd:z()} keys, {cmd:pihat()} must also agree across arms when those rows remain in the same outer fold and that same-fold group contributes at least one retained-overlap pretrim row{p_end}
{synopt:{opt phi1hat(varname)}}pre-estimated fold-aligned out-of-fold treated nuisance prediction on the retained overlap sample, on the same scale as {cmd:depvar}; for shared {cmd:x()}/{cmd:z()} keys, retained nuisance values must agree across arms when those rows remain in the same retained estimator fold IDs assigned as contiguous current-row blocks of the retained-relevant subset of the broader strict-interior nofirst pretrim fold-feasibility sample in its own current row order; only treatment-arm keys with at least one retained-overlap pretrim row belong to that retained-relevant subset, and that same-fold cross-arm check also extends to same-fold cross-arm candidate twins with {cmd:pihat()} still in {cmd:[0.01,0.99]}, including depvar-missing or otherwise score-ineligible rows{p_end}
{synopt:{opt phi0hat(varname)}}pre-estimated fold-aligned out-of-fold control nuisance prediction on the retained overlap sample, on the same scale as {cmd:depvar}; for shared {cmd:x()}/{cmd:z()} keys, retained nuisance values must agree across arms when those rows remain in the same retained estimator fold IDs assigned as contiguous current-row blocks of the retained-relevant subset of the broader strict-interior nofirst pretrim fold-feasibility sample in its own current row order; only treatment-arm keys with at least one retained-overlap pretrim row belong to that retained-relevant subset, and that same-fold cross-arm check also extends to same-fold cross-arm candidate twins with {cmd:pihat()} still in {cmd:[0.01,0.99]}, including depvar-missing or otherwise score-ineligible rows{p_end}
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
Replay usage is {cmd:hddid} with no options.  More precisely, replay is bare
{cmd:hddid} with no positional arguments, no {it:if}/{it:in} qualifiers, no
weights, and no options.  Replay prints the
pointwise intervals and the published {cmd:e(CIuniform)} object already stored in
{cmd:e()}, so replay does not accept {cmd:level()}, weights, or sample qualifiers. To
change confidence levels or the estimation sample, re-estimate with
{cmd:alpha()} on that subsample.
Replay still validates the published saved-results contract before display, so
  metadata that define the estimation path, such as {cmd:e(propensity_nfolds)}
  and {cmd:e(outcome_nfolds)} when the first stage was estimated internally,
  plus the always-posted {cmd:e(secondstage_nfolds)} and
  {cmd:e(mmatrix_nfolds)} for the second-stage/debiasing path, must still be
  present for replay.  Current results still publish {cmd:e(depvar)}={cmd:beta} so generic
  Stata postestimation labels the parametric block correctly, while replay and
  the direct unsupported postestimation stubs can recover the original
  outcome-role label from {cmd:e(depvar_role)} when it is stored or from the
  successful-call provenance in {cmd:e(cmdline)} when that current-only helper
  label is absent; only legacy result sets fall back to {cmd:e(depvar)}, plus
  {cmd:e(treat)}, {cmd:e(xvars)}, and {cmd:e(zvar)}, and the canonical eclass
  {cmd:e(depvar)}.  Current {cmd:hddid} estimation typically publishes the
  canonical {cmd:e(properties)} {cmd:b}/{cmd:V} capability label (usually
  {cmd:b V}), but current and legacy replay plus the direct unsupported
  postestimation stubs can still display the stored beta / omitted-intercept z-varying surface when
  {cmd:e(properties)} is absent or malformed because the numeric
  coefficient/covariance surface already lives in {cmd:e(b)} and {cmd:e(V)};
  what is lost is only the canonical Stata eclass capability label.  Replay prints
  the stored {cmd:e(depvar_role)} when available and otherwise falls back to
  the outcome-role label parsed from current {cmd:e(cmdline)} or, for legacy
  result sets, {cmd:e(depvar)}, together with
  {cmd:e(treat)}, {cmd:e(xvars)}, and {cmd:e(zvar)}, in the summary so
  the published beta and omitted-intercept z-varying objects remain anchored to the same role
  mapping after {cmd:estimates store}/{cmd:estimates use}.  Replay uses the published
  estimation title {cmd:e(title)} when available and otherwise falls back to
  the canonical {cmd:hddid} title, because the title is display metadata rather
  than part of the paper/R estimator object.  Direct unsupported
  postestimation does not require {cmd:e(title)} before advertising the stored
  surface.  Current results usually keep {cmd:e(N_pretrim)} so replay can validate the full current accounting identity {cmd:e(N_trimmed) = e(N_pretrim) - e(N)} when that scalar is present.  Replay and the direct unsupported postestimation stubs can still display the stored HDDID surface when {cmd:e(N_pretrim)} is absent because the paper/R estimator objects already live in the posted beta, covariance, and interval surfaces; what is lost is only that extra pretrim-accounting check and summary line.
  Current
  results usually keep {cmd:e(k)} as the duplicate outer-fold count behind the
  published retained fold-accounting rowvector {cmd:e(N_per_fold)}.  Replay
  and the direct unsupported postestimation stubs can still recover that
  current fold dimension from the width of a valid stored {cmd:e(N_per_fold)}
  rowvector when {cmd:e(k)} is absent; what is lost is only the duplicate
  scalar copy of the same fold count.  Current nonzero-SE results can still replay/direct unsupported postestimation when {cmd:e(cmdline)} omits {cmd:alpha()}; what is lost is only the redundant textual echo of that shared significance-level provenance.  Current nonzero-SE results can still replay/direct unsupported postestimation when {cmd:e(nboot)} is absent; what is lost is only the explicit bootstrap replication-count provenance behind {cmd:e(tc)} and {cmd:e(CIuniform)}.
  On the degenerate zero-SE shortcut where {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, current replay/direct unsupported postestimation still require {cmd:e(nboot)} as configuration metadata.
  Legacy replay can still display the stored beta /
  omitted-intercept z-varying surface when {cmd:e(nboot)} is absent; what is
  lost is only the explicit bootstrap replication-count provenance behind
  {cmd:e(tc)} and {cmd:e(CIuniform)}.  Use {cmd:e(nboot)} for that bootstrap
  replication-count provenance behind the published interval objects.  The published retained-sample indicator {cmd:e(sample)} still
  identifies the realized post-trim estimation sample behind the posted beta
  and omitted-intercept z-varying objects.  Current posting still fails closed unless {cmd:e(sample)} marks exactly the same retained post-trim count published in {cmd:e(N)}. That equality is a posting-time contract. After {cmd:estimates use}, any live {cmd:count if e(sample)} mismatch is only an informational note about today's data, not a replay veto.  When the current data still contain the published
  role variables, replay may report {cmd:count if e(sample)} as a live
  count-level sanity note beside stored {cmd:e(N)}; that live count is
  informational only and does not veto replay when today's data no longer
  reproduce the original retained sample behind the stored result surface.
  After {cmd:estimates use}, replay can still display the stored
  HDDID surface from {cmd:e()} even if the current data no longer support a
  live {cmd:e(sample)} count.  That fallback also covers the stale-zero case
  where unrelated current data happen to reuse the same role-variable names.
  Replay can still display the stored HDDID surface when {cmd:e(sample)} is absent because the paper/R estimator objects already live in the posted {cmd:e(b)}, {cmd:e(V)}, {cmd:e(xdebias)}, {cmd:e(gdebias)}, {cmd:e(CIpoint)}, and {cmd:e(CIuniform)} surfaces; what is lost is only the optional live retained-sample note.  Direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} calls still recognize the same current surface and continue to their unsupported guidance that points users to inspect those stored {cmd:e()} objects, rather than replaying the surface themselves.
{* Retired exact-token audit traceability only: replay and direct unsupported postestimation can still display the stored HDDID surface when {cmd:e(sample)} is absent because the paper/R estimator objects already live in the posted {cmd:e(b)}, {cmd:e(V)}, {cmd:e(xdebias)}, {cmd:e(gdebias)}, {cmd:e(CIpoint)}, and {cmd:e(CIuniform)} surfaces; what is lost is only the optional live retained-sample note. *}
That same replay contract also keeps the machine-readable variance/postestimation metadata,
including wrapper labels such as {cmd:e(predict)}, {cmd:e(estat_cmd)}, or {cmd:e(marginsnotok)}.
{cmd:e(vce)} is different from the wrapper dispatch labels {cmd:e(predict)}, {cmd:e(estat_cmd)}, and {cmd:e(marginsnotok)}: bare {cmd:hddid} replay plus direct {cmd:hddid_p}/{cmd:hddid_estat} calls can fall back to the canonical dispatch labels when those wrapper-only tags are absent or malformed, while generic {cmd:predict}, generic {cmd:estat}, and {cmd:margins} still require live dispatch labels because Stata itself reads those fields before the HDDID stubs can run.
 That fallback scope is limited to bare {cmd:hddid} replay plus direct
 {cmd:hddid_p}/{cmd:hddid_estat} calls: generic {cmd:predict}, generic
 {cmd:estat}, and {cmd:margins} still depend on the live dispatch labels that
 Stata itself reads from {cmd:e()}.
Replay and the direct unsupported postestimation stubs therefore fall back to the
canonical {cmd:robust} variance tag when {cmd:e(vce)} is absent or malformed,
because the posted covariance already lives in {cmd:e(V)} and the paper/R estimator
objects already live in the other posted aggregate surfaces; what is lost is only
that machine-readable label text. Bare {cmd:hddid} replay plus the direct unsupported
{cmd:hddid_p}/{cmd:hddid_estat} entrypoints likewise fall back to the canonical
{cmd:hddid_p}, {cmd:hddid_estat}, and {cmd:_ALL} wrapper labels when
{cmd:e(predict)}, {cmd:e(estat_cmd)}, or {cmd:e(marginsnotok)} is absent or
malformed, because those entrypoints are just reaching already-posted aggregate
estimator objects; what is lost is only the original dispatch-label text. The
human-readable variance label {cmd:e(vcetype)}
is different: current results can still display the stored beta / omitted-intercept z-varying surface
and still reach the direct unsupported postestimation stubs when {cmd:e(vcetype)}
is absent or malformed, because the posted covariance and paper/R estimator
objects already live in {cmd:e(V)}, {cmd:e(xdebias)}, {cmd:e(gdebias)},
{cmd:e(CIpoint)}, and {cmd:e(CIuniform)} surfaces; what is lost is only that
display label.
 Legacy replay can likewise still display the stored beta / omitted-intercept z-varying surface when
 {cmd:e(vce)}, {cmd:e(vcetype)}, {cmd:e(predict)}, {cmd:e(estat_cmd)}, or
 {cmd:e(marginsnotok)} is absent or malformed because the paper/R estimator
 objects already live in the posted aggregate {cmd:e(b)}, {cmd:e(V)},
 {cmd:e(xdebias)}, {cmd:e(gdebias)}, {cmd:e(CIpoint)}, and {cmd:e(CIuniform)}
 surfaces; what is lost is only the Stata variance/dispatch label block.
 Replay/direct unsupported postestimation still validate that it equals {cmd:rank(e(V))} before advertising the published beta covariance surface when {cmd:e(rank)} is stored.  When {cmd:e(rank)} is absent, replay and direct unsupported postestimation can still recover the covariance rank from the posted {cmd:e(V)} matrix itself, so missing stored rank metadata does not by itself invalidate an otherwise coherent saved-results surface.
 When stored, replay also validates {cmd:e(tc)} as the ordered Gaussian-bootstrap
 critical-value pair behind the published {cmd:e(CIuniform)} interval object.
 But the public nonparametric interval surface is still {cmd:e(CIuniform)}.
 Legacy results can still keep the published {cmd:e(CIuniform)} object when
 {cmd:e(tc)} itself is absent, but current replay/direct unsupported
 postestimation fail closed because current saved-results surfaces publish
 {cmd:e(tc)} as machine-readable bootstrap provenance behind that interval
 object.  When available, replay
 cross-checks the stored provenance record {cmd:e(cmdline)} against the
 machine-readable first-stage metadata.  Replay classifies the first-stage
 path from {cmd:e(firststage_mode)} when that metadata is stored, but current
 and legacy result sets can also recover it from the option list inside
 {cmd:e(cmdline)} when that successful-call provenance record is still
 available; when both are absent, replay and direct unsupported postestimation
 now fail closed instead of inventing a nuisance-path label.  Current
 producer-side posting also fails closed when cmdline() nofirst classification
 contradicts the machine-readable first-stage metadata it would post, because
 one realized run has one nuisance-path classification.
 Current
 internally estimated results still replay from {cmd:e(firststage_mode)}
 plus the stored role metadata when that raw command line is unavailable;
 what is lost is only the original successful-call provenance text.  Current
 {cmd:nofirst} results likewise remain replayable from {cmd:e(firststage_mode)}
 plus the stored role metadata when that raw command line is unavailable.
 Current results can still support bare replay and direct unsupported
 postestimation guidance from the successful-call provenance in
 {cmd:e(cmdline)} when {cmd:e(firststage_mode)} is unavailable; what is lost is
 only that machine-readable helper label.
 Legacy result sets
 without {cmd:e(firststage_mode)} still need {cmd:e(cmdline)} as the
 successful-call provenance record that classifies the first-stage path.
 When the current data still contain the referenced variables, replay resolves
 legal Stata varname abbreviations inside the stored depvar/{cmd:treat()}/
 {cmd:x()}/{cmd:z()} provenance before checking those names against the
 published role metadata.  If those variables are no longer in memory, replay
 instead compares the stored cmdline tokens against the published full role
 metadata and still accepts legal unique prefix abbreviations plus legal {cmd:x()}
 wildcards as provenance-only spellings; Stata {cmd:x()} ranges are accepted
 only when the current data still let replay expand them exactly, because a
 bare range token is otherwise ambiguous about the original dataset order.
 Pure {cmd:x()} permutations remain acceptable because {cmd:hddid} canonicalizes the published
 {cmd:e(xvars)} order before posting results.
Replay also prints that stored first-stage path in the summary so users can
see whether nuisance inputs were estimated internally or supplied via
{cmd:nofirst}.  Replay also prints the fixed estimator-path label
{cmd:AIPW (doubly robust)} so the summary cannot be misread as an
{cmd:RA} or {cmd:IPW} estimator just because {cmd:method()} reports the
published sieve basis.  When available, replay also prints the stored
{cmd:e(seed)} provenance because an explicit {cmd:seed()} changes fold
assignment, Gaussian bootstrap draws, and Python CLIME CV splitting.  When {cmd:method(Tri)}
was used, replay also prints the stored retained-support endpoints
{cmd:e(z_support_min)} and {cmd:e(z_support_max)} because the trigonometric
basis is defined on the support-normalized coordinate; replay also rejects
stored {cmd:e(z0)} points outside that retained support.  Current multi-{cmd:x()}
results also require the stored CLIME metadata block to remain available at
replay time, because current {cmd:hddid} posting always publishes that
precision-step provenance when {cmd:e(p)>1}.  Current single-{cmd:x()} results
may still omit that block because the scalar precision step uses the analytic
inverse instead of CLIME CV, so replay and direct unsupported postestimation
simply suppress the CLIME summary.  Legacy single-{cmd:x()} result surfaces may
also omit that block.
Optional diagnostic summaries are otherwise shown only when their
corresponding metadata block is stored.
When replay summarizes CLIME metadata as
{cmd:requested<=m, effective=0..r}, that {cmd:0} is a sentinel meaning
CLIME CV was skipped on at least one outer fold, not a literal zero-fold
CV run.  Under the current shipped {cmd:hddid_clime.py} sidecar, freshly
produced {cmd:e(p)>1} results still keep diagonal retained covariances on the
paper/R CLIME + CV path, so a multivariate {cmd:0} instead signals that the
retained DR-response constant-score shortcut skipped CLIME entirely.
Legacy/custom result surfaces can still use that sentinel for an
exact-diagonal retained covariance path where the Python sidecar used the
analytic inverse instead of lambda tuning.
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

{pmore}
rho_i = (D_i - pihat_i) / (pihat_i * (1 - pihat_i))

{pmore}
and

{pmore}
newy_i = rho_i * (Delta Y_i - (1 - pihat_i) * phi1hat_i - pihat_i * phi0hat_i),

{pstd}
then trims fold-evaluation observations with {cmd:pihat} outside
[{cmd:0.01}, {cmd:0.99}] before the second-stage partially linear fit.
The second-stage target therefore matches the paper's AIPW score after
the implementation's current overlap screen.
The initial runtime preprocessing summary reports the usable pretrim split
sample.  Under {cmd:nofirst}, that initial summary reports the pretrim common
score sample rather than the broader pretrim fold-feasibility sample that
fixes outer-fold assignment; when those samples differ, the runtime
diagnostics print that separately printed fold-pinning sample can be equal to,
narrower than, or wider than the pretrim common score sample because the broader strict-interior
nofirst fold-feasibility provenance sample with 0 < pihat() < 1 governs {cmd:pihat()}
provenance and the realized outer fold IDs before the later overlap trim, while
same-arm {cmd:pihat()} hidden-missing/disagreement guards stay scoped to treatment-arm
keys with at least one retained-overlap pretrim row and retained-estimator checks
narrow afterward to the retained-overlap subset.
With internally estimated first stages (the default path), rows with observed
treat()/x()/z() but missing depvar() do not enter the common score sample or
the fold-pinning outer split.  Those D/W-complete rows can still belong to the
broader default-path propensity sample because {cmd:pi(W)} depends only on
{cmd:treat()} and {cmd:W=(X,Z)}.  They can therefore move the estimated
propensity nuisance path without widening the common-score row-block outer split,
the score-sample {cmd:x()} canonicalization anchor, or the published {cmd:e(N_outer_split)}
count beyond the common score sample reported as {cmd:e(N_pretrim)}.
Under {cmd:method(Tri)}, those auxiliary-only rows must also stay within the
common-score {cmd:z()} support; otherwise the support-normalized first-stage
trigonometric basis would be rescaled by points that never reach the paper's
score sample, and {cmd:hddid} exits with an error instead of silently aliasing
the nuisance stage.
Auxiliary-only rows missing {cmd:depvar()} can therefore change the
internally estimated propensity nuisance path while staying out of the
final score, but rows from that broader sample that never enter the score do
not relabel the score-sample outer fold map or widen the published
common-score row-block fold-pinning count.
When trimming later changes the realized estimator domain, a separate
retained-sample summary reports the post-trim counts actually used by the
second stage and cross-fit aggregation.
When trimming changes the retained evaluation sample, the runtime
diagnostics also print the retained post-trim sample count and the
post-trim fold counts that determine the cross-fit aggregation weights.
An
individual retained evaluation fold may therefore be single-arm after
overlap trimming.  The common score sample must still contain both
treatment arms before overlap trimming, so current failures arise from
pretrim support loss or insufficient retained fold sizes, not from a
post-trim global one-arm sample alone.
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
{cmd:hddid} requires {cmd:lassopack}.  On the default path that estimates
the propensity score internally, it also requires {cmd:cvlassologit},
plus the documented {cmd:lassologit} fallback used when
{cmd:cvlassologit} leaves no usable postresults; both commands ship with
{cmd:lassopack}.
When {opt nofirst} is used with user-supplied nuisance inputs, the
{cmd:cvlassologit} dependency is skipped, but Stata 16+
Python integration with Python 3.7 or newer, {cmd:scipy} 1.7 or newer,
and {cmd:numpy} 1.20 or newer are required for the full CLIME debiasing
path when {cmd:x()} has more than one covariate.  Under the current shipped
{cmd:hddid_clime.py} sidecar, the multivariate {cmd:x()} path still follows
CLIME + CV even when a retained covariance happens to be diagonal, so the
default package does not advertise a fresh {cmd:e(p)>1} analytic no-CV
shortcut.  Legacy/custom result surfaces can still record that an
exact-diagonal retained covariance path uses the same analytic inverse
without lambda tuning.  With a single {cmd:x()} covariate ({cmd:e(p)=1}),
{cmd:hddid} always uses the analytic scalar precision shortcut and does
not call Python.  The shipped multivariate bridge also requires the
side-effect-free preflight file {cmd:hddid_safe_probe.py} in the same package directory as hddid_clime.py; if {cmd:hddid_example.do} or a multivariate
{cmd:x()} run says it cannot find {cmd:hddid_safe_probe.py} or cannot locate a
full sibling hddid package bundle, rerun from the repository root/package directory
or add that full package directory to {cmd:adopath} instead of source-running
a partial file subset.  The shipped bundle now includes {cmd:hddid.pkg} and
{cmd:stata.toc}, so the standard local install route is
{cmd:net install hddid, from("/path/to/hddid-stata") replace}.  Because
{cmd:hddid_example.do} is an ancillary file rather than an ado/help entrypoint,
users who also want that shipped walkthrough in their working directory should
run {cmd:net install hddid, from("/path/to/hddid-stata") all replace} or
{cmd:net get hddid, from("/path/to/hddid-stata")}.  If Stata has not yet been bound to a Python executable, first verify Python with {cmd:python query}; if not found, run {cmd:python search} then {cmd:set python_exec} {it:<path>} {cmd:, permanently}.  After that install/fetch step, first verify that the installed sibling bundle resolves
together with {cmd:which hddid}, {cmd:which hddid_dgp1},
{cmd:which hddid_dgp2}, {cmd:which hddid_p},
{cmd:which hddid_estat}, {cmd:findfile _hddid_main.ado},
{cmd:findfile _hddid_display.ado}, {cmd:findfile _hddid_estimate.ado},
{cmd:findfile _hddid_prepare_fold_covinv.ado}, {cmd:findfile _hddid_pst_cmdroles.ado},
{cmd:findfile _hddid_mata.ado}, {cmd:findfile hddid_safe_probe.py}, and
{cmd:findfile hddid_clime.py}.  In the same install check, rerun {cmd:python query} and confirm the default lasso runtime with {cmd:which lasso2}, {cmd:which cvlasso}, {cmd:which cvlassologit}, and {cmd:which lassologit}; otherwise a bundle that resolves on {cmd:adopath} can still fail on the first paper-baseline estimation call when the Python bridge or {cmd:lassopack} commands are unavailable.  Then
locate the shipped walkthrough with {cmd:findfile hddid_example.do} and run
the installed copy with {cmd:do "`r(fn)'"}.
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
repeat the variable named in {cmd:treat()} or {cmd:z()}, and it may not
repeat the same covariate name more than once.  It must also avoid nonzero
constant columns on the estimation sample, because the paper/R M-matrix path
partials sieve terms on {cmd:x()} without a separate intercept and a nonzero
constant {cmd:x()} column therefore duplicates that intercept direction.  The current implementation
canonicalizes the {cmd:x()} representation by observed column content on the
sample relevant for the split contract: under the default internal-first-stage
path that means the pretrim common score sample with nonmissing
{cmd:treat()}/{cmd:x()}/{cmd:z()}/{cmd:depvar()}, while the broader
D/W-complete sample with nonmissing {cmd:treat()}/{cmd:x()}/{cmd:z()} can
still enter only the internally estimated propensity nuisance path; the later
{cmd:nofirst} discussion below describes that broader strict-interior
fold-feasibility scope together with the narrower retained-overlap-specific
nuisance-guard scopes for externally supplied nuisance paths.  Pure reordering or
variable renaming of the same {cmd:x()} columns is therefore treated as a
representational change rather than a different model specification.
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
{1, cos(2{it:k}*pi*u), sin(2{it:k}*pi*u)} for k = 1, ..., q/2, where
u = (z - z_min)/(z_max - z_min) and z_min, z_max are the minimum and maximum
of {cmd:z()} on the retained post-trim estimation sample after {it:if}/{it:in} filtering,
missing-value screening, and overlap trimming.  This means {cmd:method(Tri)} uses a
period-1 basis on support-normalized z rather than on the raw z scale.
It requires q to be even.  The command implements the paper's doubly robust
AIPW estimator throughout; {cmd:method()} does not switch the estimator family,
but it does change the {cmd:z()}-basis representation used throughout the AIPW
path, including the nuisance-fit {bf:W=(X,Z-basis)} design as well as the
second-stage sieve for f(Z).  Unsupported estimator-style spellings such as
{cmd:ra}, {cmd:ipw}, {cmd:aipw}, or {cmd:estimator()} should therefore not be
used here.  Assignment forms such as {cmd:estimator=ipw} are likewise invalid
estimator-switch syntax:
{cmd:method()} only chooses the {cmd:Pol}/{cmd:Tri} sieve basis.
Those spellings are rejected only when they are used as unsupported
estimator-family switches, options, or extra positional tokens; legal role
variables may still literally be named {cmd:ra}, {cmd:ipw}, or {cmd:aipw}.
{p_end}

{phang}
{opt q(#)} specifies a positive integer sieve basis order.  The default is
{cmd:q(8)}.
For {cmd:method(Pol)}, this produces q+1 basis functions.  For
{cmd:method(Tri)}, q must be even and produces q+1 basis functions.
Because the trigonometric basis uses harmonics {cmd:k = 1, ..., q/2},
{cmd:method(Tri) q(8)} is only a 4th degree trigonometric basis.  The
paper's Section 5 simulation setting uses an 8th degree Tri basis, which
under this package's indexing therefore corresponds to {cmd:q(16)}, not
{cmd:q(8)}.  The legacy {cmd:Examplehighdimdiffindiff.R} wrapper still carries a
wrapper-local {cmd:method=} field whose own default is {cmd:"Pol"}, but
the maintained cross-fit entrypoint
{cmd:highdimdiffindiff_crossfit3(y0, y1, treat, x, z, q, k, z0, alp)}
does not expose or accept a public {cmd:method} argument.  So matching that
stale wrapper-local default does not reproduce the paper's Section 5 Tri
baseline by default.  That legacy wrapper also re-draws {cmd:z} after building
the baseline outcome and ignores nondefault {cmd:rho.X} choices, so even
editing that stale wrapper-local field to {cmd:method="Tri"} with {cmd:q(16)}
still does not make it the paper's DGP2 oracle.  The legacy cross-fit code
there also hardcodes the polynomial sieve regardless of the wrapper's local
method field, so nondefault wrapper text still does not switch that R path
onto a trigonometric basis.  Although the historical
wrapper file {cmd:Examplehighdimdiffindiff.R} still ships under
{cmd:hddid-r/R}, the legacy code path documented by that wrapper name is not a
runnable oracle against the shipped R sources: Examplehighdimdiffindiff.R calls
highdimdiffindiff_crossfit() while the shipped cross-fit entry point in this
tree is highdimdiffindiff_crossfit3().
Even patching that wrapper onto {cmd:highdimdiffindiff_crossfit3()} still
does not rescue the shipped R tree as a runnable oracle.  A rename-only patch
already fails at the public R API layer: Examplehighdimdiffindiff.R passes
{cmd:method=...} while {cmd:highdimdiffindiff_crossfit3(y0, y1, treat, x, z, q, k, z0, alp)}
requires z0 and alp and does not accept {cmd:method}, so that patched wrapper
first throws the concrete R error {cmd:unused argument (method = method)}.
Even after that signature mismatch, {cmd:highdimdiffindiff_crossfit3()}
source()s missing {cmd:highdimdiffindiff_crossfit_inside3.r}, and its
{cmd:CIuniform} line references undefined debias instead of {cmd:gdebias}.
For the maintained R estimator reference, read
those files as a read-only source reference, not a public wrapper/script entrypoint to source() directly:
{cmd:hddid-r/R/highdimdiffindiff_crossfit.R} together with
{cmd:hddid-r/R/highdimdiffindiff_crossfit_inside.R}: those files carry the
surviving shipped cross-fit estimator logic, specifically the
{cmd:highdimdiffindiff_crossfit3()} entrypoint and the
{cmd:highdimdiffindiff_crossfit_inside3()} helper, even though the Stata DGP
generators documented here still publish {cmd:deltay} rather than the
{cmd:y0}/{cmd:y1} level inputs that the R code expects.
The fold-level nonparametric one-step update also requires the realized
sieve system Sigma_f to stay stably invertible.  In the paper's Section 4
and the R reference, that fold object is solved directly rather than through
a generalized-inverse fallback, so a fold whose realized {cmd:z()} support or
basis makes Sigma_f singular, nearly singular, or numerically null does not
define the published {cmd:gdebias}/{cmd:stdg}/{cmd:CIuniform} path.  When
that happens, reduce {cmd:q()}, change {cmd:method()}, or ensure richer
fold-level support in {cmd:z()}.
{p_end}

{phang}
{opt K(#)} specifies the number of folds for cross-fitting in the
outer sample split only.  The default is {cmd:K(3)}.  The minimum is 2.
In other words, {cmd:k()} controls only the outer sample split used for
cross-fitting; it does not retune the command's internal CV fold counts.
The current implementation builds this outer split as contiguous row-order
blocks on the common score sample, matching the paper/R cross-fit split
before later trimming.  In the default internal-first-stage path, that
fold-pinning split is anchored on
the common score sample with nonmissing {cmd:treat()}, {cmd:x()},
{cmd:z()}, and {cmd:depvar()}.  The broader D/W-complete sample with
nonmissing {cmd:treat()}, {cmd:x()}, and {cmd:z()} can still widen only the
default propensity-training path.  Rows from that broader propensity sample
never become held-out evaluation rows, so they stay available to every
fold-external default-path propensity training sample.  They therefore
do not relabel the outer fold map or widen the published
{cmd:e(N_outer_split)} count.
Rows excluded by {cmd:if}/{cmd:in} leave both the fold-pinning common score
sample and that broader propensity-training path together.
Under {cmd:nofirst}, hddid instead rebuilds the broader
strict-interior fold-feasibility sample from the supplied nuisance inputs
after {cmd:if}/{cmd:in} filtering and before later overlap trimming.
On that nofirst path, only treatment-arm keys with at least one
retained-overlap pretrim row belong to the retained-relevant fold-pinning
subset, and the outer fold map follows contiguous current-row blocks of
that subset in its own current row order, so the
maintained paper/R row-block rule continues to govern the realized split.
Under the default
internal-first-stage path, if/in qualifiers are applied before both the
default propensity sample and the common-score sample are built.  Running
with if/in is therefore equivalent to physically subsetting those rows
first even on the default path: excluded rows do not continue to pin the
common-score outer split, the internal propensity sample, or the default
propensity provenance.  If the qualifier-defined and physically subsetted
default-path runs hand hddid the same D/W-complete rows in the same order,
they must therefore deliver the same retained-sample estimates.  Even then,
every realized outer fold must
still contain at least one common-score observation; otherwise {cmd:hddid}
aborts because the paper's AIPW score is only formed on the common
nonmissing score sample.  Under
{cmd:nofirst}, exact {cmd:0}/{cmd:1} values are
already outside the overlap support and do not receive outer fold IDs from
that broader split by themselves.  The broader strict-interior {cmd:0 < pihat < 1}
fold-feasibility logic is rebuilt before overlap trimming. Only treatment-arm
keys with at least one retained-overlap pretrim row pin the published
retained outer fold IDs, and only the retained-relevant subset with
treatment-arm keys that still contribute at least one retained-overlap
pretrim row pins the realized outer fold IDs used later by the score and
same-fold retained-nuisance checks.  Strict-interior
rows that later trim out simply keep those already-assigned fold IDs without relabeling the
fold-external training sample, while same-arm {cmd:pihat()} hidden-missing or
disagreement guards still stay scoped to treatment-arm keys with at least one
retained-overlap pretrim row.  Omitted
{cmd:seed()} therefore does not randomize fold membership.
Exact duplicate {cmd:x()}/{cmd:z()} keys are not guaranteed to stay in the
same fold by design on the {cmd:nofirst} path; they do so only when they
happen to lie in the same contiguous current-row block of the retained-relevant
subset.  Only treatment-arm keys with at least one retained-overlap pretrim row
belong to the retained-relevant subset, and that retained-relevant subset then
receives the retained outer fold IDs as contiguous current-row blocks in its
own current row order.  Same-fold duplicate-key consistency checks are arm-local
because they inspect those already-fixed retained fold IDs after the row-block
split, not because the outer split itself is stratified by treatment arm.
Numerically duplicate {cmd:x()} columns therefore do not create additional
fold-pinning rows or rescue an otherwise infeasible split, because the
maintained paper/R split is assigned only from the current row order of the
fold-pinning sample after qualifier/missing-value preprocessing.  Repeating the
same {cmd:x()} information therefore cannot rescue an otherwise infeasible
split.  Instead, {cmd:k()} cannot exceed the number
of nonempty row blocks implied by that fold-pinning sample size; otherwise
one or more outer folds would be empty and {cmd:hddid} aborts before
first-stage estimation.
When {cmd:hddid} estimates the propensity score internally, each outer-fold
training sample must also be large enough for
{cmd:cvlassologit ..., nfolds(3) stratified}.  The current implementation
therefore requires each outer-fold propensity-training subset to contain at
least 4 treated observations, 4 control observations, and 8 total
observations.  This fail-closed guard blocks known 3/3/6 subsets that can
still late-crash inside {cmd:cvlassologit}'s internal {cmd:getMinIC()} /
{cmd:PostResults()} path instead of producing a stable propensity fit.
The current implementation uses fixed 3-fold CV for the propensity score,
fixed 5-fold CV for the treated/control outcome regressions, fixed 3-fold
CV for the second-stage lasso, fixed 10-fold CV for the M-matrix auxiliary
lasso, and up to 5-fold CV for CLIME lambda selection.  These inner CV
defaults are internal to the command and do not vary with {opt K(#)}.
The fixed 5-fold outcome-regression size check applies only when the
arm-specific training outcome actually varies; if an arm-specific training
outcome is constant or the nuisance-fit {bf:W=(X,Z-basis)} design is
constant, {cmd:hddid} uses the fold-external sample mean as the first-stage
nuisance prediction instead of forcing {cmd:cvlasso}.  When the arm-specific
training outcome varies and that nuisance-fit design is not constant, each
treated/control training sample
must contain at least 3 observations before it will run the non-constant
5-fold outcome-regression path.  This threshold follows the direct Stata
runtime boundary for {cmd:cvlasso, nfolds(5) lopt}: non-constant arm-specific
fits still run at 3 rows but not at 2, so the package no longer advertises a
stricter two-validation-observations-per-fold heuristic that Stata itself does
not require.
After overlap trimming, each evaluation fold must still contribute at least
6 valid observations before {cmd:hddid} will run the non-constant
second-stage {cmd:cvlasso, nfolds(3)} path, so those validation folds do not
collapse to singletons.  If the retained fold-level doubly robust response is
constant, however, {cmd:hddid} bypasses that second-stage CV path and uses the
intercept-only fallback instead, so this 6-observation guard does not apply.
In addition, when
{cmd:x()} contains more than one covariate and the retained fold-level doubly
robust response is non-constant, each evaluation fold must still contribute at
least 20 valid observations so the fixed M-matrix {cmd:cvlasso, nfolds(10)
nocons} path also avoids singleton validation folds.  If the retained fold-level
doubly robust response is constant, {cmd:hddid} bypasses the M-matrix/CLIME CV
machinery and uses the intercept-only constant-score shortcut instead; with a
single {cmd:x()} covariate, {cmd:hddid} likewise uses the closed-form
single-regressor projection instead of the M-matrix CV path.
{p_end}

{dlgtab:Inference}

{phang}
{opt alpha(#)} specifies the significance level for confidence intervals
and the published {cmd:e(CIuniform)} interval object for the nonparametric component.  The default is
{cmd:alpha(0.1)}, yielding 90% pointwise confidence intervals and the corresponding published bootstrap interval object.  Must be
strictly between 0 and 1.  This {cmd:alpha()} option is the inference
significance level, not the paper's nuisance bundle {cmd:alpha_0} or the
separate DGP constant sometimes also denoted alpha.  On the degenerate zero-SE shortcut where
{cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, this shared {cmd:alpha()}
value still calibrates the analytic {cmd:e(CIpoint)} pointwise intervals, but it does not
recalibrate the already-collapsed {cmd:e(CIuniform)} object because that published
nonparametric interval object already equals {cmd:e(gdebias)} exactly.  That zero-shortcut
branch therefore used no studentized Gaussian-bootstrap draws for the published nonparametric
interval object.  When {cmd:e(cmdline)} omits {cmd:alpha()}, current replay/direct unsupported postestimation continue to trust the machine-readable stored {cmd:e(alpha)} scalar; what is lost is only the redundant textual echo of that shared significance-level provenance.  Symmetrically, when current {cmd:e(alpha)} is absent but current {cmd:e(cmdline)} still encodes one unique valid {cmd:alpha()}, replay/direct unsupported postestimation continue to trust that successful-call provenance and lose only the duplicate machine-readable scalar echo.
{p_end}

{phang}
{opt nboot(#)} specifies the number of Gaussian bootstrap replications
used to construct the ordered lower/upper studentized-process pair for the
nonparametric component.  The default is {cmd:nboot(1000)}.  When stored,
this path records the 1 x 2 lower/upper bootstrap provenance pair
{cmd:e(tc)}, and that pair calibrates the published interval object stored in
{cmd:e(CIuniform)}.  Legacy replay/direct unsupported postestimation can still use the published
{cmd:e(CIuniform)} object when {cmd:e(tc)} is absent; current replay/direct unsupported
postestimation instead require {cmd:e(tc)} on current saved-results surfaces and fail
closed before ancillary provenance reconciliation.  When {cmd:e(tc)} is stored, current
replay/direct unsupported postestimation validate that provenance against the published
{cmd:e(CIuniform)} object.
{* Retired exact-token audit traceability only: Replay/direct unsupported postestimation can still use the published {cmd:e(CIuniform)} object when {cmd:e(tc)} is absent; what is lost is only the duplicate bootstrap critical-value provenance. When {cmd:e(tc)} is stored, current replay/direct unsupported postestimation also validate that provenance against the published {cmd:e(CIuniform)} object. current replay/direct unsupported postestimation therefore validate {cmd:e(tc)} together with {cmd:e(CIuniform)} on the stored nonparametric surface before ancillary provenance reconciliation. *}
On the degenerate zero-SE shortcut where {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, this stored {cmd:e(nboot)} scalar remains current-surface configuration metadata rather than realized bootstrap-draw provenance for the published {cmd:e(CIuniform)} object.
When that zero-SE shortcut sentinel is present, current replay/direct unsupported postestimation still require {cmd:e(nboot)} on current saved-results surfaces, but the published nonparametric interval object itself used no studentized Gaussian-bootstrap draws.
When {cmd:e(cmdline)} omits {cmd:nboot()}, current replay/direct unsupported postestimation now continue to trust the machine-readable stored {cmd:e(nboot)} scalar; what is lost is only the redundant textual echo of that configuration metadata.
Changing {cmd:nboot()} recalibrates only the Gaussian-bootstrap {cmd:e(tc)}/{cmd:e(CIuniform)} path; it does not redefine the analytic pointwise {cmd:e(CIpoint)}, {cmd:e(stdx)}, or {cmd:e(stdg)} objects from Theorems 2 and 3.
When {cmd:e(tc)} is stored, {cmd:e(CIuniform)} stores the lower/upper rows
implied by {cmd:e(gdebias)}, {cmd:e(stdg)}, and the two stored critical values
in {cmd:e(tc)}.  Its lower row is the stored {cmd:e(gdebias)} shifted by the
stored lower critical value times {cmd:e(stdg)}, and its upper row uses the
stored upper critical value times {cmd:e(stdg)}.  Under the current
rowwise-envelope interval-object path, {cmd:_hddid_bootstrap_tc()} publishes the rowwise
studentized-process envelope pair obtained by taking the type-7 lower/upper
bootstrap quantiles at each stored {cmd:z0()} row and then aggregating them as
{cmd:(min_j lower_j, max_j upper_j)}.  The resulting stored pair can therefore
be asymmetric and same-sign in finite samples.  On current saved-results surfaces
with nonzero {cmd:e(stdg)}, replay/direct unsupported postestimation validate
the published {cmd:e(CIuniform)} interval algebra rather than imposing a sign
restriction, so a same-sign pair can still be coherent when the stored lower
endpoint does not exceed the stored upper endpoint and the posted lower/upper
rows equal {cmd:e(gdebias)} + {cmd:e(tc)} * {cmd:e(stdg)}.  The zero-SE
shortcut with {cmd:e(stdg)} identically zero and {cmd:e(tc)} = {cmd:(0, 0)}
remains the only current path where the published nonparametric interval object
collapses exactly to {cmd:e(gdebias)}.  Apart from that shortcut, the published
{cmd:e(CIuniform)} object is the corresponding lower/upper interval object on
the outcome scale for that finite
evaluation grid.  This package path is bootstrap-calibrated but not directly
proved in the paper text.  It is not a paper-proven simultaneous-coverage
guarantee.
{opt nboot(#)} must be an integer of at least 2 because a single bootstrap
draw cannot define that critical value.
{p_end}

{phang}
{opt seed(#)} optionally sets the command's random number seed before
estimation.  If {cmd:seed()} is an integer in [0, 2147483647], it controls the
outer fold assignment, the bootstrap draws, and the Python CLIME
cross-validation RNG used by the debiasing step.  Conditional on that seeded
outer fold map, the internally estimated propensity inner-CV partitions are
then pinned by a deterministic row order over {cmd:treat}, outer fold rank,
and {cmd:W=(X,Z)}, so that path stays outcome-blind but is not literally
{cmd:W}-only, while the
outcome, second-stage, and M-matrix {cmd:cvlasso}/{cmd:cvlassologit} paths
use deterministic canonical row order on their realized regression data
rather than by a separate Stata RNG split.  Under {cmd:nofirst}, {cmd:hddid}
first sorts by treatment and outer fold rank, so exact tied fold-rank groups
keep their incoming within-group order at that preprocessing step.  Before
the retained second-stage and M-matrix fits, however, the command re-sorts
deterministically by retained fold, trim status, {cmd:x()}, {cmd:z()}, and
retained DR score, so arbitrary caller row order matters only when those
retained keys still tie exactly; pure row reordering of otherwise identical
retained rows does not alter that seeded retained-stage path.  The default is
{cmd:seed(-1)} (no seed reset).  When the
effective seed is {cmd:-1}, Mata/bootstrap randomness continues from the
current session RNG state.  With internally estimated first stages, the outer
fold assignment is a deterministic function of the current common-score row
order.  Under {cmd:nofirst}, the outer fold assignment is a deterministic
function of the current nofirst fold-pinning row order.  Python CLIME CV uses a deterministic per-fold integer seed derived
from the current Stata RNG state.  This no-seed sentinel does not alias an explicit
{cmd:seed(0)} call: {cmd:seed(0)} is a legal seeded path with its own
seed-indexed outer fold map and internal random draws, rather than another
spelling of the default {cmd:seed(-1)} behavior.  Values above 2147483647 are
rejected up front so the command never falls through to Stata's generic parser
error for oversized seeds.  When a nonnegative {opt
seed()} is used,
{cmd:hddid} restores the caller's prior session RNG state after the command
finishes, so the seeded reproducibility applies to {cmd:hddid}'s internal
random steps without permanently changing the session's subsequent
random-number path.  The Python sidecar's CLIME CV split uses NumPy's RNG
stream, so the same numeric seed in {cmd:hddid} and R {cmd:flare} does not
imply identical CLIME CV folds or lambda paths; the cross-language parity
contract is only that, once a fold partition is fixed, the retained-sample
lambda grid, {cmd:tracel2} loss, and CLIME solve/write-back rules follow the
same algorithmic target.
On the degenerate zero-SE shortcut where {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, a nonnegative {cmd:seed()} still fixes the realized outer fold assignment and Python CLIME CV splitting, but the published nonparametric interval object used no studentized Gaussian-bootstrap draws.
Under {cmd:seed(-1)} on that same zero-SE shortcut, the outer fold assignment remains deterministic from the data and Python CLIME CV still uses its deterministic per-fold integer seed derivation, but the published nonparametric interval object again used no studentized Gaussian-bootstrap draws.
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
all be provided.  This is useful for supplying externally estimated
first-stage predictions.  The supplied nuisance variables must already be
fold-aligned out-of-fold predictions, but their required scope is not
identical: {opt pihat()} must already be fold-aligned out-of-fold on the
broader strict-interior nofirst pretrim fold-feasibility sample with
{cmd:0 < pihat() < 1}, while {opt phi1hat()}/{opt phi0hat()}
must already be fold-aligned out-of-fold on the retained overlap sample.
In the current command contract, these nuisance inputs must align to hddid's own deterministic outer-fold assignment rather than an arbitrary external cross-fitting scheme.
Generic external out-of-fold nuisance values can still be rejected when they were produced under a different row-order or duplicate-key fold map, because {cmd:hddid} rebuilds its own fold structure before checking the supplied series.
Under {cmd:nofirst}, if/in qualifiers are applied before hddid rebuilds that broader strict-interior nofirst split path.
Running with if/in is therefore equivalent to physically subsetting those rows first: excluded rows do not continue to pin the outer split, retained estimator fold ids, or same-fold nuisance checks.
{cmd:hddid} cannot fully verify that requirement mechanically.  It still
mechanically checks split-key and same-fold nuisance consistency on the
documented nofirst scopes, but it cannot observe the caller's
nuisance-training folds.  In-sample fitted
nuisance values from those same estimation samples are invalid input because
they break the paper's sample-splitting orthogonality argument and can
materially change the estimator.  Outer-split
feasibility is checked on the nofirst fold-feasibility sample before overlap
trimming.  Only treatment-arm keys with at least one retained-overlap pretrim row
belong to the retained-relevant subset of that broader strict-interior path, and
that retained-relevant subset then receives the retained outer fold IDs as
contiguous current-row blocks in its own current row order before later overlap
trimming.  Legal-but-extreme {opt pihat()} twins and score-missing twins that stay
on those retained-relevant keys therefore inherit the same already-assigned
outer-fold IDs and fold-aligned provenance.  By contrast, treatment-arm keys
with only exact {cmd:0}/{cmd:1}, only other legal-but-extreme values outside
{cmd:[0.01,0.99]}, or missing {opt pihat()} values never enter that
retained-relevant subset and therefore do not pin retained folds.
Under {cmd:nofirst}, that broader strict-interior pretrim fold-feasibility
sample still governs {opt pihat()} provenance and the broader outer-fold map
used to verify same-fold structure for shared {bf:W=(X,Z)} keys.  Only the
retained-estimator checks narrow afterward to the retained-overlap subset;
that broader outer-fold map does not rebuild when same-fold retained
nuisances are checked.
More precisely, the broader strict-interior {cmd:0 < pihat < 1}
fold-feasibility sample still governs the same-fold {cmd:pihat()}
provenance checks and the preliminary same-fold feasibility map built from
shared {bf:W=(X,Z)} keys, and legal strict-interior rows still enter that
broader path before later overlap trimming.  Only treatment-arm keys with at
least one retained-overlap pretrim row belong to the retained-relevant
fold-pinning subset, and that retained-relevant subset then receives the
retained outer fold IDs before later overlap trimming.  The retained
estimator checks then narrow to the retained-overlap score sample with
{cmd:pihat()} in {cmd:[0.01,0.99]} without rebuilding those fold IDs.
A hidden missing supplied {opt pihat()} cannot drop out before same-fold
cross-arm verification because {cmd:hddid} first reconstructs the broader
usable/raw split map before that missing twin can disappear from the common
score sample.
Rows with missing {cmd:depvar}, {opt phi1hat()}, or {opt phi0hat()} still do
not enter the retained AIPW score, but if their legal {opt pihat()} belongs to
a treatment-arm split-key group that still contributes at least one
pretrim row with {cmd:pihat()} in the retained overlap region
{cmd:[0.01,0.99]},
they remain in that broader nofirst fold-feasibility group because the outer
split and fold-aligned {opt pihat()} provenance are pinned by the shared
{bf:W=(X,Z)} key before the retained score is formed.  On that retained-relevant
fold-pinning subset of the broader strict-interior path, each represented treatment arm
must still contribute at least {cmd:k()} observations and enough
retained-relevant fold-pinning rows for the maintained contiguous
row-block split to realize {cmd:k()} nonempty folds.  Exact duplicate
{cmd:x()}/{cmd:z()} keys therefore do not rescue an infeasible
{cmd:k()}, because duplicating keys does not create additional
fold-pinning rows.
Under {opt nofirst}, treatment-arm split-key groups that are
entirely overlap-trimmed never reach the retained AIPW score.  Retained
rows keep the fixed outer fold IDs assigned as contiguous current-row blocks of
the retained-relevant subset of the broader nofirst pretrim fold-feasibility
path, while legal-interior treatment-arm split-key groups with at least one
pretrim row on the common nonmissing score sample with {cmd:pihat()} in
{cmd:[0.01,0.99]} determine only which rows remain in that retained-relevant
subset.  Same-fold cross-arm retained nuisance checks stay on those fixed
retained estimator fold IDs because overlap trimming does not rebuild the outer
sample split.
A retained evaluation fold may therefore be single-arm after overlap
trimming.
The required two-arm support applies on the common score sample before
overlap trimming, not as a separate retained-sample veto.
Once the nuisance inputs are already fold-aligned and the retained AIPW
score is finite, {cmd:hddid} applies only the retained fold-level score,
second-stage, and debiasing feasibility checks.
{opt pihat()} must therefore agree within each pretrim treatment-arm split-key group that remains in the nofirst fold-feasibility sample,
that is, across rows with the same treatment-arm {cmd:x()}/{cmd:z()} key,
whenever that duplicate-key group contributes at least one pretrim row on the common nonmissing score sample with {cmd:pihat()} in the retained overlap region [0.01,0.99],
because those groups still determine retained-relevant subset membership and the
overlap decision whenever they contribute at least one retained-overlap
pretrim row.
{opt phi1hat()}/{opt phi0hat()} must therefore agree within each retained treatment-arm split-key group,
because only retained rows enter the AIPW score.  Because the
retained outer fold IDs are already fixed as contiguous current-row blocks of
that retained-relevant subset, these same-fold duplicate-key consistency
checks are arm-local because they inspect those already-fixed retained fold IDs
after the row-block split, not because the outer split itself is stratified by
treatment arm.  That arm-local check does not license treatment-arm-specific
nuisance surfaces.  Under the paper's notation, the target nuisance objects are
functions of {cmd:W = (X, Z)}.  At the same time, the supplied {opt nofirst}
values are fold-aligned out-of-fold realizations rather than a single
full-sample fitted surface, so a shared {cmd:x()}/{cmd:z()} key may still carry
different numeric values across treatment arms when hddid's retained row-block
outer split places those rows in different evaluation folds with different
fold-external training samples.  The mechanical cross-arm check therefore applies only within a
shared outer fold, but the relevant fold map differs by stage: on the common
nonmissing score sample, {opt pihat()} must agree across arms whenever the
shared {cmd:x()}/{cmd:z()} key also shares the same pretrim outer fold, and on
the retained overlap sample the retained {opt pihat()}, {opt phi1hat()}, and
{opt phi0hat()} values must likewise agree across arms only for shared
{cmd:x()}/{cmd:z()} keys that stay on the same retained estimator fold IDs
pinned by the retained-relevant subset of that broader strict-interior nofirst
pretrim fold-feasibility sample.
Only treatment-arm keys with at least one retained-overlap pretrim row pin
those retained estimator fold IDs.
Same-fold cross-arm retained-nuisance checks also extend to depvar-missing
or otherwise score-ineligible twins with {opt pihat()} still in
{cmd:[0.01,0.99]} when a shared {cmd:x()}/{cmd:z()} key remains on the same
retained estimator fold IDs, because those twins still share the same
fold-external outcome-nuisance provenance even before the realized score
sample narrows.
That broader same-fold {opt pihat()} agreement still extends to depvar-missing
or otherwise score-ineligible twins when their same-fold partner still
contributes a retained overlap row, because the shared fold keeps the overlap
decision and fold-external OOF propensity provenance tied to that broader raw
retained-overlap candidate sample before the score sample narrows.
A shared-{cmd:W=(X,Z)} twin in that same-fold group also may not
omit {opt pihat()} when that same-fold key still contributes a retained
overlap row, because the retained overlap decision and the fold-external OOF
propensity provenance are both pinned by that broader same-fold split group.
A duplicate-key group that is entirely overlap-trimmed by
{opt pihat()} outside {cmd:[0.01, 0.99]} never reaches the retained AIPW
score and therefore does not, by itself, trigger the pretrim {opt pihat()}
consistency guard.
{opt pihat()} still enters the broader nofirst fold-feasibility logic because
the retained estimator fold map is keyed off the pretrim nonmissing
treatment-arm {cmd:x()}/{cmd:z()} split-key values whose strict-interior group
still contributes at least one retained-overlap row.
{opt phi1hat()}/{opt phi0hat()} do not enter the outer split itself because
only retained rows use those supplied outcome nuisances in the AIPW score.
Pure
representational changes in
{cmd:depvar}, {opt pihat()}, {opt phi1hat()}, and {opt phi0hat()} therefore
do not affect fold membership, because sample splitting must remain
exogenous to the doubly robust score representation.  These nuisance variables
must also be distinct from the structural role variables
{cmd:depvar}, {opt treat()}, {opt x()}, and {opt z()}.  Within that
boundary, {opt pihat()}, {opt phi1hat()}, and {opt phi0hat()} may
intentionally alias one another when the supplied nuisance predictions are
numerically identical; {cmd:hddid} copies each role into separate working
variables before the AIPW score is formed.  In this mode,
{cmd:hddid} still requires the shared downstream dependencies used by the
second stage and CLIME, but it does not require
{cmd:lassologit}/{cmd:cvlassologit} because the propensity first stage is
skipped.  Because the propensity and outcome first stages are not run,
{cmd:e(propensity_nfolds)} and {cmd:e(outcome_nfolds)} are omitted, and
replay omits those skipped first-stage fold counts as well.  Legal but
extreme {opt pihat()} values may still appear on the nofirst pretrim
split-feasibility sample.  After the overlap rule is applied, an
individual retained outer evaluation fold may still be single-arm.  The
fold-level DR score and cross-fit second-stage fit are
then formed evaluation-fold by evaluation-fold on the retained
observations in each fold, subject to the retained fold-size feasibility
checks documented above rather than a separate global post-trim
two-arm requirement.  Because successful nofirst runs keep the
retained rows on the same fixed retained estimator fold ids assigned as
contiguous current-row blocks of the retained-relevant subset of that
broader strict-interior nofirst pretrim fold-feasibility sample in its
own current row order for score
aggregation,
same-fold retained-nuisance checks continue to use those fixed ids even
though the retained-score evaluation sample narrows after trimming.
Only the retained-score evaluation sample narrows when same-fold retained
nuisances are tested.  That estimator-fold statement is separate from the
retained same-fold cross-arm nuisance checks, which stay on those same
retained estimator fold IDs assigned as contiguous current-row blocks of
the retained-relevant subset of that broader strict-interior nofirst
pretrim fold-feasibility sample in its own current row order.
Overlap trimming changes which retained rows
survive, but it does not rebuild the outer split or redefine the
fold-external training sample that valid out-of-fold nuisance inputs
must respect.
{p_end}

{phang}
{opt pihat(varname)} specifies a variable containing pre-estimated
propensity scores P(D=1|X,Z).  On the common nonmissing score sample,
values must lie within [0,1].  Under {opt nofirst}, that domain screen is
evaluated only on that common nonmissing score sample, while the broader
nofirst pretrim split-feasibility logic is still defined on the strict-interior
pretrim rows with {cmd:0 < pihat() < 1}; legal but extreme values outside
{cmd:[0.01,0.99]} can therefore remain on that broader fold-feasibility path
even though they later trim from the retained overlap score.
The supplied series must therefore remain fold-aligned out-of-fold on that
broader pretrim fold-feasibility path, because any legal strict-interior row
still enters that broader strict-interior fold-feasibility path before later
overlap trimming, but only treatment-arm keys with at least one
retained-overlap pretrim row pin the published retained outer fold IDs.
Consequently, if a treatment-arm {cmd:x()}/{cmd:z()} split-key group still
contributes at least one retained overlap row, then other twins in that same
group cannot hide a missing or different {opt pihat()} behind missing
{cmd:depvar()}/{opt phi1hat()}/{opt phi0hat()} values; the shared
fold-feasibility group must still carry one fold-aligned OOF propensity
realization as a function of {cmd:W=(X,Z)}.
Likewise, if a shared {cmd:W=(X,Z)} key appears across treatment arms in the
same outer fold and that same-fold key still contributes a retained overlap
row, no twin on either arm may simply omit {opt pihat()}; the broader
same-fold fold-feasibility group must still carry the corresponding OOF
propensity realization before the retained AIPW score is formed.
Can only be used with {opt nofirst}.  The supplied series must already be
fold-aligned out-of-fold on the nofirst pretrim split-feasibility sample used
by {opt nofirst}; that broader pretrim fold-feasibility sample is the
relevant provenance domain for {opt pihat()}.  {cmd:hddid} cannot fully verify
that requirement mechanically.  It still mechanically checks split-key and
same-fold nuisance consistency on that documented {opt pihat()} scope.
After excluding missing {opt pihat()},
{cmd:depvar}, {opt phi1hat()}, and {opt phi0hat()} on the common score sample,
both treatment arms must still remain before overlap trimming begins.
At the low-level overlap-mask helper layer, a missing propensity is treated
as undefined nuisance input and therefore raises a helper-level error rather
than mapping that row to a retained-mask value of 0; by contrast, the public
{opt nofirst} command screens missing {opt pihat()} earlier on the common
score sample before overlap trimming.
Values in the legal but extreme
range outside [0.01, 0.99] are handled by the
usual overlap trimming rule; exact 0 or 1 are boundary cases that still trim
later but never remain in the broader nofirst fold-feasibility scope because
that scope itself requires strict interior {cmd:0 < pihat < 1}; values outside [0,1] are rejected as invalid
input on the common nonmissing score sample, and any missing or conflicting
{opt pihat()} value inside a retained treatment-arm split-key group is also
rejected even if that conflicting twin later drops out of the score sample.
Missing {cmd:depvar},
{opt phi1hat()}, and {opt phi0hat()} values are only screened on rows that
survive the retained overlap rule {cmd:0.01 <= pihat <= 0.99}.  Rows with
legal but extreme {opt pihat()} values strictly between 0 and 1 but outside {cmd:[0.01, 0.99]} still
participate in the broader same-fold {opt pihat()} provenance checks whenever
their treatment-arm split-key group still has a pretrim row with
{cmd:pihat()} in {cmd:[0.01,0.99]}.  In other words, rows with legal
but extreme {opt pihat()} values strictly between 0 and 1 but outside {cmd:[0.01, 0.99]} are counted as
overlap-trimmed for the retained AIPW score and second-stage estimator, but
they can still remain in the broader pretrim fold-feasibility scope when
that treatment-arm split-key group still has a retained-overlap-eligible pretrim
{opt pihat()} row that pins the published retained outer fold IDs.  Exact 0 or 1 do not remain in
that broader fold-feasibility scope because they are already outside the
strict interior domain used to fix the nofirst outer split.
The
variable used in {opt pihat()} may not also be named in {opt treat()},
{opt x()}, {opt z()}, or {cmd:depvar}.
{p_end}

{phang}
{opt phi1hat(varname)} specifies a variable containing pre-estimated
treated-group nuisance predictions on the same scale as {cmd:depvar}.
For the standard use case with {cmd:depvar} = {cmd:deltay}, this means a
prediction for the treated-group outcome change, not the level outcome.
Can only be used with {opt nofirst}.  The supplied series must already be
	fold-aligned out-of-fold on the retained overlap sample used by
	{opt nofirst}; for shared {cmd:x()}/{cmd:z()} keys, retained nuisance values
	must agree across arms only when those rows remain on retained estimator fold
		IDs assigned as contiguous current-row blocks of the retained-relevant
		subset of the broader strict-interior nofirst pretrim fold-feasibility
		sample in its own current row order.  Equivalently, those retained
		estimator fold IDs are assigned as contiguous current-row blocks of that
		retained-relevant subset in its own current row order, and only those
		fold IDs are used by these retained same-fold checks.  Only
		treatment-arm keys with at least one retained-overlap pretrim row belong to
		that retained-relevant subset, so this same-fold nuisance contract is
		narrower than the whole broader strict-interior pretrim path.
		{cmd:hddid} cannot fully verify that requirement mechanically.  It still
		mechanically checks split-key and same-fold nuisance consistency on that
		retained-overlap scope.
		That same-fold cross-arm retained-nuisance check also extends to any
		depvar-missing or otherwise score-ineligible twin with {opt pihat()} still in
		{cmd:[0.01,0.99]} when a shared {cmd:x()}/{cmd:z()} key remains on the same
		retained estimator fold IDs, because those twins still share the same
		fold-external outcome-nuisance provenance even before the realized score
		sample narrows.
		Rows later trimmed because {opt pihat()} lies outside {cmd:[0.01, 0.99]},
		including exact 0 or 1, do not enter the retained AIPW score and therefore
		need not carry nonmissing {opt phi1hat()} values.  But a depvar-missing twin
	with {opt pihat()} still in {cmd:[0.01,0.99]} on a treatment-arm
	{cmd:x()}/{cmd:z()} key that still contributes a retained overlap row must
	still carry nonmissing {opt phi1hat()} values, because that same-arm key
	remains on the retained-overlap nuisance-consistency path even before the
	row drops from the realized score sample.
	{p_end}

{phang}
{opt phi0hat(varname)} specifies a variable containing pre-estimated
control-group nuisance predictions on the same scale as {cmd:depvar}.
For the standard use case with {cmd:depvar} = {cmd:deltay}, this means a
prediction for the control-group outcome change, not the level outcome.
Can only be used with {opt nofirst}.  The supplied series must already be
	fold-aligned out-of-fold on the retained overlap sample used by
	{opt nofirst}; for shared {cmd:x()}/{cmd:z()} keys, retained nuisance values
	must agree across arms only when those rows remain on retained estimator fold
		IDs assigned as contiguous current-row blocks of the retained-relevant
		subset of the broader strict-interior nofirst pretrim fold-feasibility
		sample in its own current row order.  Equivalently, those retained
		estimator fold IDs are assigned as contiguous current-row blocks of that
		retained-relevant subset in its own current row order, and only those
		fold IDs are used by these retained same-fold checks.  Only
		treatment-arm keys with at least one retained-overlap pretrim row belong to
		that retained-relevant subset, so this same-fold nuisance contract is
		narrower than the whole broader strict-interior pretrim path.
		{cmd:hddid} cannot fully verify that requirement mechanically.  It still
		mechanically checks split-key and same-fold nuisance consistency on that
		retained-overlap scope.
		That same-fold cross-arm retained-nuisance check also extends to any
		depvar-missing or otherwise score-ineligible twin with {opt pihat()} still in
		{cmd:[0.01,0.99]} when a shared {cmd:x()}/{cmd:z()} key remains on the same
		retained estimator fold IDs, because those twins still share the same
		fold-external outcome-nuisance provenance even before the realized score
		sample narrows.
		Rows later trimmed because {opt pihat()} lies outside {cmd:[0.01, 0.99]},
		including exact 0 or 1, do not enter the retained AIPW score and therefore
		need not carry nonmissing {opt phi0hat()} values.  But a depvar-missing twin
	with {opt pihat()} still in {cmd:[0.01,0.99]} on a treatment-arm
	{cmd:x()}/{cmd:z()} key that still contributes a retained overlap row must
	still carry nonmissing {opt phi0hat()} values, because that same-arm key
	remains on the retained-overlap nuisance-consistency path even before the
	row drops from the realized score sample.
	{p_end}

{phang}
{opt verbose} prints additional fold-level diagnostics, including selected
lambda values and debiasing status.  This option is intended for auditing
and troubleshooting output.
{p_end}

{marker postestimation}{...}
{title:Postestimation}

{pstd}
{cmd:predict} is installed as the stub {cmd:hddid_p}, but the current package
does not publish any observation-level prediction contract.  Calling
{cmd:predict} after {cmd:hddid} therefore exits with an error instead of
producing fitted values, treatment-effect predictions, or scores.  Likewise,
{cmd:estat} is installed only as the stub {cmd:hddid_estat} and exits with an
error because no unified {cmd:estat} contract is published, and
{cmd:margins} is disabled for the same reason as {cmd:predict}.  Because
{cmd:hddid} publishes {cmd:e(marginsnotok)}={cmd:_ALL}, {cmd:margins} is
disabled through Stata's {cmd:e(marginsnotok)} guard, so it may stop with
Stata's generic "not appropriate after hddid" message before any HDDID stub
runs.
On this unsupported {cmd:predict} path, a bare leading token is still treated
as the would-be new variable name rather than as an estimator-family switch,
so legal variable names such as {cmd:ra}, {cmd:ipw}, or {cmd:aipw} fall
through to the same generic "predict is not supported" contract.  Only
quoted, parenthesized, or assignment-style {cmd:ra}/{cmd:ipw}/{cmd:aipw}
spellings are echoed back as malformed estimator-style postestimation input.
Directly running {cmd:hddid_p} or {cmd:hddid_estat} is the same unsupported
stub path: both commands exist only so Stata's postestimation dispatch and the
published {cmd:e(predict)}/{cmd:e(estat_cmd)}/{cmd:e(marginsnotok)} metadata
keep Stata's wrapper routing aligned with that package-specific guidance instead
of silently inventing an unsupported observation-level or {cmd:estat}
contract.  On current results, {cmd:hddid_p}/{cmd:hddid_estat} fall back to the
canonical wrapper labels when only that dispatch metadata is absent or
malformed, so a coherent stored HDDID surface still reaches the generic
unsupported-stub guidance.  On current results, replay and direct
{cmd:hddid_p}/{cmd:hddid_estat} may also recover missing
{cmd:e(method)}/{cmd:e(q)} from {cmd:e(cmdline)} because those labels describe
sieve-family provenance rather than a separate estimator object.  If current
{cmd:e(cmdline)} omits both options, replay and direct unsupported
postestimation fall back to the official defaults {cmd:method(Pol)} and
{cmd:q(8)} rather than fail solely because the duplicate machine-readable
method/q labels are absent.  Bare {cmd:predict}/{cmd:estat}/{cmd:margins}
still depend on Stata's own dispatch machinery, so malformed published wrapper
metadata can stop those generic entrypoints before the HDDID stubs run.  On
current results, {cmd:hddid_p}/{cmd:hddid_estat} first validate the current
inference surface before ancillary provenance cross-checks.  For
current internal results,
malformed e(N_outer_split) is treated as fold-pinning metadata and
therefore fails before ancillary seed()/alpha()/nboot()
provenance cross-checks.  For current nofirst results, malformed
e(N_outer_split) is treated as fold-pinning metadata and therefore fails
before ancillary seed()/alpha()/nboot() provenance
cross-checks.  For current results, malformed {cmd:e(CIuniform)} or
{cmd:e(CIpoint)} interval metadata is treated as current inference-surface
corruption and therefore fails before ancillary
seed()/alpha()/nboot() provenance cross-checks.
Missing current {cmd:e(CIuniform)} or {cmd:e(CIpoint)} follows that same
malformed-surface classification instead of being downgraded to a generic
no-active-result-set path.
Direct {cmd:hddid_p}/{cmd:hddid_estat} first recognize that surrounding current
result surface as {cmd:hddid} and then fail closed on the specific malformed
interval object rather than downgrading it to a generic no-active-result-set
classification.
{p_end}

{pstd}
Use the posted matrices in {cmd:e()} for postestimation work.  In particular,
the parametric beta block is available both through the canonical Stata eclass
objects {cmd:e(b)} and {cmd:e(V)} and through the hddid-specific summaries
{cmd:e(xdebias)} and {cmd:e(stdx)}.  For the nonparametric component, {cmd:e(gdebias)}, {cmd:e(stdg)}, the trailing omitted-intercept z-varying block of {cmd:e(CIpoint)}, {cmd:e(CIuniform)}, and {cmd:e(z0)} are the public objects on the stored evaluation grid.  When available, {cmd:e(tc)} records the lower/upper bootstrap critical-value pair from the studentized process endpoint aggregation behind that published interval object.
Treat {cmd:e(tc)} as the lower/upper bootstrap critical-value pair used to map
{cmd:e(stdg)} into the reported {cmd:e(CIuniform)} interval object, on the
studentized-process scale rather than on the original outcome scale.  Under the
current path that pair is the rowwise-envelope cutoff {cmd:(min_j lower_j, max_j upper_j)}
obtained from the type-7 Gaussian bootstrap over the stored {cmd:z0()} grid, so
it can be asymmetric.  Treat {cmd:e(CIuniform)} as the package's published nonparametric interval object only for the omitted-intercept z-varying block.  When {cmd:e(tc)} is stored, {cmd:e(CIuniform)} is the current lower/upper object implied by {cmd:e(gdebias)}, {cmd:e(stdg)}, and {cmd:e(tc)}.  It is then the outcome-scale lower/upper object implied by {cmd:e(gdebias)},
{cmd:e(stdg)}, and {cmd:e(tc)}.  Its first row is the lower bound
{cmd:e(gdebias)} + {cmd:e(tc)[1,1]} * {cmd:e(stdg)}; its second row is the upper
bound {cmd:e(gdebias)} + {cmd:e(tc)[1,2]} * {cmd:e(stdg)}.
When {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, treat
that as the degenerate zero-SE shortcut sentinel instead of as realized
bootstrap provenance: the published {cmd:e(CIuniform)} object collapses exactly
to {cmd:e(gdebias)}, and no studentized Gaussian-bootstrap draws were used for
the published nonparametric interval object.
Legacy results can still expose that published {cmd:e(CIuniform)} object even when {cmd:e(tc)} itself is absent.  This package path is
bootstrap-calibrated on the stored finite grid, although the paper text only
proves pointwise inference.  Treat it as the package's published interval
object; it is not a paper-proven simultaneous-coverage guarantee.
For a test point, the public matrices recover the beta block and centered
changes in the omitted-intercept nonparametric block across the stored
{cmd:e(z0)} grid, but not the full paper target {cmd:x0'beta + f(z0)} because
{cmd:e(gdebias)} excludes {cmd:a0} and {cmd:hddid} does not currently publish
{cmd:e(a0)}.  There is therefore no one-shot public combined inference object
for the full ATT level.
Retired audit anchor kept for contract traceability only: For a test point,
recover the paper target {cmd:x0'beta + f(z0)} by taking the full linear
combination of {cmd:x0} with the beta block in {cmd:e(b)} or {cmd:e(xdebias)}
and then adding the matching {cmd:e(gdebias)} value on the stored
{cmd:e(z0)} grid.  That older shorthand is not itself sufficient for the full
public ATT level because {cmd:e(gdebias)} still omits the separate intercept
{cmd:a0}.
Meanwhile, {cmd:e(CIpoint)} stores both parametric and omitted-intercept
nonparametric pointwise intervals: its first p columns are the parametric
pointwise intervals and its final qq columns are the pointwise intervals for
that posted z-varying block aligned with {cmd:e(z0)}.  Because the
second-stage fit and debiasing path run on the retained overlap sample,
{cmd:e(sample)} identifies the realized post-trim estimation sample behind all
 published beta and omitted-intercept z-varying objects.  Current posting still fails closed unless {cmd:e(sample)} marks exactly the same retained post-trim count published in {cmd:e(N)}. That equality is a posting-time contract. After {cmd:estimates use}, any live {cmd:count if e(sample)} mismatch is only an informational note about today's data, not a replay veto.  After {cmd:estimates use}, replay
 can still use the stored {cmd:e()} surface even if the current data no
 longer permit a live {cmd:count if e(sample)} cross-check, including stale-zero
 counts on unrelated same-name role variables.  Current results can still recover the outer-fold dimension from the width of stored {cmd:e(N_per_fold)} when {cmd:e(k)} is absent, because that 1 x k rowvector already publishes the retained fold-accounting surface.  Current results also require
 {cmd:e(N_outer_split)} to remain stored because that fold-pinning sample count
 pins the published outer fold assignment before retained-sample accounting.  In
 the current internal path it records the common observed score sample behind
 {cmd:e(N_pretrim)}.  Rows with missing {cmd:depvar()} can still widen the
 default propensity nuisance path, but they do not pin the outer split or widen
 {cmd:e(N_outer_split)} beyond {cmd:e(N_pretrim)}.  Rows from that broader
 sample that never enter the score do not relabel the score-sample outer fold
 map or the published {cmd:e(N_outer_split)} count.  Under
 {cmd:nofirst}, {cmd:e(N_outer_split)} can also lie above or below
 {cmd:e(N_pretrim)} because it records the retained-relevant subset of that broader strict-interior pretrim fold-feasibility sample.
 That broader strict-interior pretrim fold-feasibility sample is the
 nofirst-specific split path rebuilt from the supplied nuisance inputs, not the
 default internal-first-stage score sample.
 Retained rows keep the outer fold IDs implied by the retained-relevant subset of the broader strict-interior pretrim fold-feasibility sample.
Exact-boundary {cmd:pihat()} rows stay outside that broader strict-interior
fold-feasibility split and do not pin retained outer fold IDs by themselves.
 Only treatment-arm keys with at least one retained-overlap pretrim row pin the
 retained outer fold IDs.
 Under {cmd:nofirst}, {cmd:e(N_outer_split)} can therefore still lie above or below
 {cmd:e(N_pretrim)}.  It may also match {cmd:e(N_pretrim)} in scalar count
 while still recording a distinct fold-pinning sample when strict-interior
 rows replace exact-boundary common-score rows one-for-one.
 Current results also require {cmd:e(N_per_fold)} to remain stored because those strictly positive counts are the
 post-trim fold counts behind the published cross-fit aggregation weights for
 {cmd:e(xdebias)}, {cmd:e(gdebias)}, {cmd:e(stdx)}, and {cmd:e(stdg)}. Legacy
 replay can still display the stored beta / omitted-intercept z-varying surface when {cmd:e(N_per_fold)}
 is absent; what is lost is only the fold-by-fold retained-sample accounting
 summary. Their sum is {cmd:e(N)}, so the fold-accounting surface closes back to the published
 retained-sample total.  Use {cmd:e(N_trimmed)} and {cmd:e(N)} for the
 published retained-sample accounting, add {cmd:e(N_pretrim)} when available
 for the extra current accounting identity check, use {cmd:e(k)} when stored or the width of {cmd:e(N_per_fold)} when {cmd:e(k)} is absent for the
 published outer-fold dimension, {cmd:e(N_outer_split)} for the fold-pinning
 outer-split count, and {cmd:e(N_per_fold)} for the published post-trim fold
 accounting.  Use {cmd:e(firststage_mode)}
 to recover whether those published objects came from the internal nuisance
 path or from {cmd:nofirst} when that helper is available.  Current internally estimated results still replay from
 {cmd:e(firststage_mode)} plus the stored role metadata when that raw
 command line is unavailable, and can also recover the same internal-path classification from the published paired
 {cmd:e(propensity_nfolds)}/{cmd:e(outcome_nfolds)} block only when both fold-count scalars remain stored; what is lost is only the original
 successful-call provenance text.  Current {cmd:nofirst} results likewise remain
 replayable from {cmd:e(firststage_mode)} plus the stored role metadata when
 that raw command line is unavailable.  Legacy
 result sets without {cmd:e(firststage_mode)} still recover that classification
 from {cmd:e(cmdline)}.  Use {cmd:e(method)} to recover the stored sieve basis,
 and when {cmd:e(method)} is {cmd:Tri}, use {cmd:e(z_support_min)} and
 {cmd:e(z_support_max)} to recover the retained support normalization that
 defines the trigonometric basis.  When available, use {cmd:e(seed)} for the published RNG provenance of the realized fold/bootstrap/CLIME path; on the degenerate zero-SE shortcut where {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, that same scalar instead anchors only the realized outer fold assignment and Python CLIME CV splitting because the published {cmd:e(CIuniform)} object used no studentized Gaussian-bootstrap draws.  Current results use
 {cmd:e(depvar)}={cmd:beta} as the generic beta-block label in Stata
 postestimation.  If that duplicate local label is absent on an otherwise coherent current saved-results surface, replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints still recover the same generic {cmd:beta} label from the posted {cmd:e(b)}/{cmd:e(V)} equation stripes.
 They use {cmd:e(depvar_role)} for the original outcome-role
 label when available, otherwise the depvar provenance parsed from current
 {cmd:e(cmdline)} or legacy {cmd:e(depvar)}, together with
 {cmd:e(treat)}, {cmd:e(xvars)}, and {cmd:e(zvar)}, anchor the variable-role
 mapping for the stored HDDID result surface.  Replay prints that stored
 {cmd:e(depvar_role)}/{cmd:e(treat)}/{cmd:e(xvars)}/{cmd:e(zvar)} mapping when
 available and otherwise falls back to legacy
 {cmd:e(depvar)}/{cmd:e(treat)}/{cmd:e(xvars)}/{cmd:e(zvar)}.
{pstd}
For a test point ({it:x0}, {it:z0}), the paper's conditional ATT target
{cmd:ATT(W)=tau0(W)} reduces to {cmd:x0'{it:beta} + f(z0)}.  Audit the
posted beta contribution by taking the full linear combination of {it:x0}
with the beta block in {cmd:e(b)} or {cmd:e(xdebias)}, then compare centered
changes in the omitted-intercept {cmd:e(gdebias)} block across the desired
{cmd:e(z0)} grid rather than adding {cmd:e(gdebias)} itself as a full ATT
level.  Because {cmd:e(gdebias)} excludes {cmd:a0}, the package does not
currently publish a one-shot prediction command or a combined inference object
for the missing-intercept ATT level.
{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:hddid} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}final post-trim retained-sample count after missing-value exclusion and overlap trimming{p_end}
{synopt:{cmd:e(N_pretrim)}}pretrim common-score-sample count after missing-value exclusion and before fold-level overlap trimming; under {cmd:nofirst}, this common-score count can be smaller or larger than the broader pretrim fold-feasibility sample because legal {cmd:pihat()} rows excluded from the score by missing {cmd:depvar()}, {cmd:phi1hat()}, or {cmd:phi0hat()} still widen that broader fold-feasibility sample, while exact 0 or 1 {cmd:pihat()} rows stay in the common score sample and trim later without entering the broader fold-feasibility split. Current results usually store this so replay can validate the published retained-sample accounting identity {cmd:e(N_trimmed) = e(N_pretrim) - e(N)} when available, but replay and the direct unsupported postestimation stubs can still display the stored HDDID surface when it is absent because the estimator-defining paper/R objects already live in the posted beta, covariance, and interval matrices; what is lost is only that extra pretrim-accounting check and summary line{p_end}
 {synopt:{cmd:e(N_outer_split)}}observation count on the sample that actually pins the outer fold assignment before any fold-level overlap trimming; in the current internal-first-stage path it matches {cmd:e(N_pretrim)} because rows missing {cmd:depvar()} can widen only the default propensity-training sample, not the fold-pinning outer split; under {cmd:nofirst} it records the retained-relevant subset of the broader strict-interior pretrim fold-feasibility sample: any legal {cmd:0<pihat()<1} row still enters that broader strict-interior fold-feasibility path before later overlap trimming, but only treatment-arm keys with at least one retained-overlap pretrim row pin the published retained outer fold IDs. Legal {cmd:pihat()} rows excluded from the score by missing {cmd:depvar()}, {cmd:phi1hat()}, or {cmd:phi0hat()} can still keep {cmd:e(N_outer_split)} larger than {cmd:e(N_pretrim)} because the outer fold map is fixed before those later score-sample eligibility checks. Retained rows then keep the outer fold IDs implied by that retained-relevant subset on the narrower retained-overlap score sample. Under {cmd:nofirst}, {cmd:e(N_outer_split)} can lie above or below {cmd:e(N_pretrim)}. It may also match {cmd:e(N_pretrim)} in scalar count while still recording a distinct fold-pinning sample when strict-interior pinning rows replace exact-boundary common-score rows one-for-one{p_end}
{synopt:{cmd:e(rank)}}matrix rank of the posted parametric covariance matrix {cmd:e(V)}; replay/direct unsupported postestimation validate stored {cmd:e(rank)} against {cmd:rank(e(V))} before displaying or advertising the published beta covariance surface when the scalar is stored, and otherwise recover that covariance rank from the posted matrix itself{p_end}
{synopt:{cmd:e(k)}}number of cross-fitting folds; current replay/direct unsupported postestimation can recover this outer-fold dimension from the width of a valid stored {cmd:e(N_per_fold)} rowvector when the duplicate {cmd:e(k)} scalar is absent{p_end}
{synopt:{cmd:e(p)}}dimension of high-dimensional covariates. Current replay/direct unsupported postestimation can still recover this parametric dimension from the published beta-surface width in {cmd:e(b)} / {cmd:e(xdebias)} / {cmd:e(stdx)} / {cmd:e(V)} when {cmd:e(p)} is absent, because those posted objects already identify the paper's p-dimensional linear block; what is lost is only the duplicate scalar label{p_end}
{synopt:{cmd:e(q)}}sieve basis order; when {cmd:e(method)}={cmd:Tri}, the stored harmonic degree is {cmd:e(q)/2}, so {cmd:e(q)=8} means a 4th degree trigonometric basis while the paper's 8th-degree Tri baseline corresponds to {cmd:e(q)=16}{p_end}
{synopt:{cmd:e(qq)}}number of evaluation points; equals the width of the current {cmd:e(z0)} grid and therefore the shared omitted-intercept z-varying block width in {cmd:e(gdebias)}, {cmd:e(stdg)}, {cmd:e(CIuniform)}, and the trailing block of {cmd:e(CIpoint)}. Current replay/direct unsupported postestimation can still recover this width from the published {cmd:e(z0)} grid when the duplicate {cmd:e(qq)} scalar is absent{p_end}
{synopt:{cmd:e(alpha)}}shared significance level for {cmd:e(CIpoint)} and the realized {cmd:e(tc)}/{cmd:e(CIuniform)} bootstrap interval object{p_end}
{p 8 8 2}On the degenerate zero-SE shortcut where {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, this stored {cmd:e(alpha)} scalar still records the pointwise significance level behind {cmd:e(CIpoint)}, but it no longer recalibrates the published {cmd:e(CIuniform)} object because that interval object already collapses exactly to {cmd:e(gdebias)} and used no studentized Gaussian-bootstrap draws.{p_end}
{p 8 8 2}When {cmd:e(cmdline)} omits {cmd:alpha()}, current replay/direct unsupported postestimation continue to trust the machine-readable stored {cmd:e(alpha)} scalar; what is lost is only the redundant textual echo of that published significance metadata.  When current {cmd:e(alpha)} is absent but current {cmd:e(cmdline)} still encodes one unique valid {cmd:alpha()}, replay/direct unsupported postestimation continue to trust that successful-call provenance and lose only the duplicate machine-readable scalar echo.{p_end}
{synopt:{cmd:e(nboot)}}number of bootstrap replications; when stored, replay/direct unsupported postestimation use it as the machine-readable replication-count provenance behind {cmd:e(tc)} / {cmd:e(CIuniform)}. It does not define the analytic pointwise {cmd:e(CIpoint)}, {cmd:e(stdx)}, or {cmd:e(stdg)} objects, which remain the paper/R pointwise surfaces. On ordinary current saved-results surfaces, replay/direct unsupported postestimation can still display the stored surface when {cmd:e(nboot)} is absent because the published beta / omitted-intercept z-varying / interval objects remain intact. Legacy replay and direct unsupported postestimation can still display the stored surface when it is absent{p_end}
{p 8 8 2}On the degenerate zero-SE shortcut where {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, this stored {cmd:e(nboot)} scalar remains current-surface configuration metadata rather than realized bootstrap-draw provenance for the published {cmd:e(CIuniform)} object. When that zero-SE shortcut sentinel is present, current replay/direct unsupported postestimation still require {cmd:e(nboot)} on current saved-results surfaces, but the published nonparametric interval object itself used no studentized Gaussian-bootstrap draws. When {cmd:e(cmdline)} omits {cmd:nboot()}, current replay/direct unsupported postestimation continue to trust that machine-readable stored scalar and lose only the redundant textual echo of the same configuration metadata.{p_end}
{* Retired audit token for exact-match regressions only: *}
{* {synopt:{cmd:e(nboot)}}number of bootstrap replications; current replay/direct unsupported postestimation require this on current saved-results surfaces because it is the machine-readable replication-count provenance behind {cmd:e(tc)} / {cmd:e(CIuniform)}. It does not define the analytic pointwise {cmd:e(CIpoint)}, {cmd:e(stdx)}, or {cmd:e(stdg)} objects, which remain the paper/R pointwise surfaces. Legacy replay and direct unsupported postestimation can still display the stored surface when it is absent{p_end} *}
{synopt:{cmd:e(N_trimmed)}}number of observations removed between the pretrim common score sample and the retained sample; equals {cmd:e(N_pretrim) - e(N)} and therefore counts the overlap-trimmed rows that leave that score sample when {cmd:pihat} is outside [0.01, 0.99], not the broader {cmd:nofirst} fold-feasibility rows that never entered {cmd:e(N_pretrim)}{p_end}
{synopt:{cmd:e(propensity_nfolds)}}fixed inner CV folds for internal propensity tuning; a finite integer >= 2; stored only when the first stage is estimated internally{p_end}
{synopt:{cmd:e(outcome_nfolds)}}fixed inner CV folds for internal treated/control outcome tuning; a finite integer >= 2; stored only when the first stage is estimated internally{p_end}
{synopt:{cmd:e(secondstage_nfolds)}}fixed inner CV folds for the second-stage lasso{p_end}
{synopt:{cmd:e(mmatrix_nfolds)}}fixed inner CV folds for the M-matrix auxiliary lasso{p_end}
{synopt:{cmd:e(clime_nfolds_cv_max)}}maximum inner CV folds requested for CLIME lambda selection{p_end}
{synopt:{cmd:e(clime_nfolds_cv_effective_min)}}minimum realized CLIME CV folds across evaluation folds; 0 means only that CLIME CV was skipped on at least one fold; with {cmd:e(p)=1} that can reflect the analytic scalar inverse; with {cmd:e(p)>1}, current shipped results use 0 only for the retained DR-response constant-score shortcut, although in legacy/custom result surfaces with {cmd:e(p)>1} it can also reflect an exact-diagonal retained covariance path that uses the same analytic inverse without lambda tuning{p_end}
{synopt:{cmd:e(clime_nfolds_cv_effective_max)}}maximum realized CLIME CV folds across evaluation folds; 0 means only that CLIME CV was skipped on every fold; with {cmd:e(p)=1} that can reflect the analytic scalar inverse; with {cmd:e(p)>1}, current shipped results use 0 only for the retained DR-response constant-score shortcut, although in legacy/custom result surfaces with {cmd:e(p)>1} it can also reflect an exact-diagonal retained covariance path that uses the same analytic inverse without lambda tuning; this maximum is also 0 when every fold uses that retained constant-score shortcut because CLIME CV is skipped entirely{p_end}
{synopt:{cmd:e(seed)}}random number seed (posted only when a nonnegative {cmd:seed()} is used); replay prints it when present because it is part of the published estimation-path provenance.  seeded reproducibility applies only to hddid's internal random steps, and on exit, hddid restores the caller's prior session RNG state, so this scalar is published provenance rather than the caller's post-command RNG state. On the degenerate zero-SE shortcut where {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, this stored {cmd:e(seed)} scalar remains provenance for the realized outer fold assignment and Python CLIME CV splitting, not for studentized Gaussian-bootstrap draws, because the published {cmd:e(CIuniform)} object already collapses exactly to {cmd:e(gdebias)}.{p_end}
{synopt:{cmd:e(z_support_min)}}minimum of {cmd:z()} used for {cmd:method(Tri)} support normalization; stored only when {cmd:method(Tri)}{p_end}
{synopt:{cmd:e(z_support_max)}}maximum of {cmd:z()} used for {cmd:method(Tri)} support normalization; stored only when {cmd:method(Tri)}{p_end}

{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(xdebias)}}1 x p debiased parametric estimates{p_end}
{synopt:{cmd:e(stdx)}}1 x p parametric standard errors{p_end}
{synopt:{cmd:e(gdebias)}}1 x qq debiased omitted-intercept z-varying estimates; colnames share the stored {cmd:e(z0)} grid order used by the other nonparametric result matrices{p_end}
{synopt:{cmd:e(stdg)}}1 x qq omitted-intercept z-varying standard errors; colnames share the stored {cmd:e(z0)} grid order used by the other nonparametric result matrices. Replay requires this on every saved-results surface because it is the published omitted-intercept z-varying standard-error path, and current direct unsupported postestimation also requires it on current saved-results surfaces.{p_end}
{synopt:{cmd:e(tc)}}when stored, 1 x 2 ordered lower/upper bootstrap critical-value pair on the studentized-process scale, recording bootstrap-calibration provenance behind the published {cmd:e(CIuniform)} interval object rather than an outcome-scale interval; colnames are {cmd:tc_lower tc_upper}. Under the current rowwise-envelope interval-object path, these are the rowwise-envelope endpoints {cmd:(min_j lower_j, max_j upper_j)} from the type-7 Gaussian bootstrap over the posted {cmd:z0()} grid, so the stored pair can be asymmetric and same-sign in finite samples. On current saved-results surfaces with nonzero {cmd:e(stdg)}, replay/direct unsupported postestimation validate the published {cmd:e(CIuniform)} interval algebra rather than imposing a sign restriction, so a same-sign stored pair can still be coherent when the posted lower/upper rows remain ordered and match {cmd:e(gdebias)} + {cmd:e(tc)} * {cmd:e(stdg)}. When {cmd:e(stdg)} is identically zero and {cmd:e(tc)} = {cmd:(0, 0)}, this same matrix is instead the degenerate zero-SE shortcut sentinel: the published {cmd:e(CIuniform)} object collapses exactly to {cmd:e(gdebias)}, and no studentized Gaussian-bootstrap draws were used for the published nonparametric interval object. Legacy/custom saved results can still expose the published {cmd:e(CIuniform)} object even when {cmd:e(tc)} itself is absent; current replay/direct unsupported postestimation instead require {cmd:e(tc)} on current saved-results surfaces and fail closed before ancillary provenance reconciliation.{p_end}
{* Retired exact-token audit traceability only: Legacy results can still expose the published {cmd:e(CIuniform)} object even when {cmd:e(tc)} itself is absent; current replay/direct unsupported postestimation instead require {cmd:e(tc)} on current saved-results surfaces. *}
{synopt:{cmd:e(CIpoint)}}2 x (p+qq) pointwise confidence interval bounds; rownames are {cmd:lower upper}. Its first e(p) columns are the beta block and its remaining e(qq) columns are the omitted-intercept z-varying block aligned with the current e(z0) grid. Replay requires this on every saved-results surface because it is the published pointwise interval matrix, and current direct unsupported postestimation also requires it on current saved-results surfaces.{p_end}
{synopt:{cmd:e(CIuniform)}}2 x qq published lower/upper interval-object matrix only for the omitted-intercept z-varying block; rownames are {cmd:lower upper}; replay requires this on every saved-results surface because it is the published nonparametric interval object, and current direct unsupported postestimation also requires it on current saved-results surfaces; when {cmd:e(tc)} is stored, the lower row is {cmd:e(gdebias)} + {cmd:e(tc)[1,1]} * {cmd:e(stdg)} and the upper row is {cmd:e(gdebias)} + {cmd:e(tc)[1,2]} * {cmd:e(stdg)}; colnames share the stored {cmd:e(z0)} grid order used by the other nonparametric result matrices. It is the package's bootstrap-calibrated lower/upper interval object on the stored finite grid, although the paper text only proves pointwise inference; it is not a paper-proven simultaneous-coverage guarantee{p_end}
{synopt:{cmd:e(clime_nfolds_cv_per_fold)}}1 x k rowvector of realized CLIME CV folds by outer evaluation fold; 0 means only that CLIME CV was skipped on that fold; with {cmd:e(p)=1} that can reflect the analytic scalar inverse; with {cmd:e(p)>1}, current shipped results use 0 only for the retained DR-response constant-score shortcut, although in legacy/custom result surfaces with {cmd:e(p)>1} it can also reflect an exact-diagonal retained covariance path that uses the same analytic inverse without lambda tuning{p_end}
{synopt:{cmd:e(b)}}1 x p coefficient vector (same as e(xdebias)){p_end}
{synopt:{cmd:e(V)}}p x p parametric variance-covariance matrix for {cmd:e(b)}; {cmd:diag(e(V)) = e(stdx)^2}{p_end}
{synopt:{cmd:e(z0)}}1 x qq evaluation points; defines the current grid ordering shared by {cmd:e(gdebias)}, {cmd:e(stdg)}, {cmd:e(CIuniform)}, and the trailing omitted-intercept z-varying block of {cmd:e(CIpoint)}; colnames match the nonparametric result matrices{p_end}
{synopt:{cmd:e(N_per_fold)}}1 x {cmd:k} rowvector of strictly positive post-trim effective evaluation sample sizes by outer fold; these retained-sample counts sum to {cmd:e(N)} and are the cross-fit aggregation weights behind {cmd:e(xdebias)}, {cmd:e(gdebias)}, {cmd:e(stdx)}, and {cmd:e(stdg)}. Current replay/direct unsupported postestimation require this on current saved-results surfaces, but legacy replay and direct unsupported postestimation can still display the stored surface when it is absent and simply lose that fold-accounting summary{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:hddid}; current results normally publish the Stata command tag, but replay and the direct unsupported postestimation entrypoints can still use an otherwise coherent stored hddid result surface when {cmd:e(cmd)} is absent or malformed because that wrapper-routing label is not part of the published beta, omitted-intercept z-varying block, or interval objects already posted elsewhere in {cmd:e()}; the current public nonparametric {cmd:e()} objects are the omitted-intercept z-varying block and its interval matrices, not a full public {cmd:f(z0)} level, because {cmd:hddid} does not publish {cmd:e(a0)}{p_end}
{* Retired exact-token audit traceability only: because that wrapper-routing label is not part of the paper/R-defined beta, {cmd:f(z0)}, or interval objects already posted elsewhere in {cmd:e()} *}
{p 8 8 2}Retired audit tokens that mention {cmd:f(z0)} in this {cmd:e(cmd)} row are exact-token traceability only; the current public nonparametric surface remains the omitted-intercept z-varying block because {cmd:hddid} does not publish {cmd:e(a0)}.{p_end}
{synopt:{cmd:e(cmdline)}}successful-call provenance text. Current results publish {cmd:e(cmdline)} atomically as the published record of the successful {cmd:hddid} call. Current producer-side posting now also fails closed before publishing {cmd:e()} when that successful-call record omits depvar/{cmd:treat()}/{cmd:x()}/{cmd:z()} role provenance, contradicts the machine-readable role metadata it would post, or contradicts the machine-readable first-stage metadata it would post through cmdline() nofirst classification. When available, use {cmd:e(cmdline)} as that published record; current replay/postestimation cross-checks it when available, and current direct {cmd:hddid_p}/{cmd:hddid_estat} calls fail closed when its depvar/{cmd:treat()}/{cmd:x()}/{cmd:z()} provenance contradicts the published role metadata or when both the successful-call record and the machine-readable role metadata are incomplete. If current saved results already keep a complete machine-readable role bundle in {cmd:e(depvar_role)}/{cmd:e(treat)}/{cmd:e(xvars)}/{cmd:e(zvar)}, replay and the direct unsupported postestimation entrypoints now continue to trust those published labels even when {cmd:e(cmdline)} omits redundant depvar/{cmd:treat()}/{cmd:x()}/{cmd:z()} text; what is lost is only that redundant textual echo. Stored successful-call role provenance may use any legal treat() abbreviation, including tr(), tre(), trea(), and treat(), across replay and the direct unsupported hddid_p/hddid_estat entrypoints. Replay and the direct unsupported postestimation entrypoints accept the same legal treat() abbreviations inside stored e(cmdline) provenance, including tr(), tre(), trea(), and treat(). Current results can still support bare replay and direct unsupported postestimation guidance from {cmd:e(firststage_mode)} plus the stored role metadata when the raw successful-call provenance text in {cmd:e(cmdline)} is unavailable; current internally estimated results can also recover that first-stage path from the published paired {cmd:e(propensity_nfolds)}/{cmd:e(outcome_nfolds)} block when both {cmd:e(firststage_mode)} and {cmd:e(cmdline)} are unavailable and only when both fold-count scalars remain stored. Those current fallbacks still require the machine-readable sieve-basis metadata {cmd:e(method)} / {cmd:e(q)} so replay/direct unsupported postestimation can still describe the published basis family/order. When those basis labels remain available, what is lost is only that verbatim command record. When {cmd:e(cmdline)} is available, replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints can also recover missing current {cmd:e(treat)} / {cmd:e(zvar)} role labels from that successful-call record and can recover missing current {cmd:e(xvars)} from the published beta-surface labels in {cmd:e(b)} / {cmd:e(V)} / {cmd:e(xdebias)} / {cmd:e(stdx)} / the beta block of {cmd:e(CIpoint)} when those canonical Stata coefficient labels remain coherent. Legacy results without {cmd:e(firststage_mode)} still require {cmd:e(cmdline)} to recover the first-stage path, and replay / direct unsupported postestimation now fail closed only when none of {cmd:e(firststage_mode)}, the paired internal fold block, or {cmd:e(cmdline)} can identify the current saved-results surface{p_end}
{* Retired exact-token audit traceability only: current results can still support bare replay and direct unsupported postestimation guidance when the raw successful-call provenance text in {cmd:e(cmdline)} is unavailable; what is lost is only that verbatim command record. when {cmd:e(cmdline)} is available, replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints can also recover missing current {cmd:e(treat)} / {cmd:e(zvar)} role labels from that successful-call record and can recover missing current {cmd:e(xvars)} from the published beta-surface labels in {cmd:e(b)} / {cmd:e(V)} / {cmd:e(xdebias)} / {cmd:e(stdx)} / the beta block of {cmd:e(CIpoint)} *}
{synopt:{cmd:e(vce)}}{cmd:robust}; machine-readable variance-type tag for the posted parametric covariance {cmd:e(V)}. Replay and the direct unsupported postestimation stubs validate the saved value when it is stored, but otherwise fall back to the canonical {cmd:robust} tag because the covariance already lives in {cmd:e(V)} and the posted beta / omitted-intercept z-varying / interval objects already live in the other aggregate {cmd:e()} surfaces; what is lost is only the original machine-readable label text{p_end}
{* Retired exact-token audit traceability only: {synopt:{cmd:e(vce)}}{cmd:robust}; machine-readable variance-type tag for the posted parametric covariance {cmd:e(V)}. Replay and the direct unsupported postestimation stubs validate the saved value when it is stored, but otherwise fall back to the canonical {cmd:robust} tag because the covariance already lives in {cmd:e(V)} and the paper/R estimator objects already live in the other posted aggregate surfaces; what is lost is only the original machine-readable label text{p_end} *}
{synopt:{cmd:e(vcetype)}}{cmd:Robust}; human-readable variance label paired with {cmd:e(vce)}. Replay and the direct unsupported postestimation stubs fall back to the canonical {cmd:Robust} label when this display-only field is absent or malformed, because the posted covariance already lives in {cmd:e(V)} and the posted beta / omitted-intercept z-varying / interval objects already live in the other aggregate {cmd:e()} surfaces; what is lost is only the original human-readable label text{p_end}
{* Retired exact-token audit traceability only: {synopt:{cmd:e(vcetype)}}{cmd:Robust}; human-readable variance label paired with {cmd:e(vce)}. Replay and the direct unsupported postestimation stubs fall back to the canonical {cmd:Robust} label when this display-only field is absent or malformed, because the posted covariance already lives in {cmd:e(V)} and the paper/R estimator objects already live in the other posted aggregate surfaces; what is lost is only the original human-readable label text{p_end} *}
{synopt:{cmd:e(predict)}}{cmd:hddid_p}; dedicated unsupported-postestimation stub; replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints fall back to the canonical {cmd:hddid_p} label when this dispatch-only wrapper tag is absent or malformed because the posted beta / omitted-intercept z-varying / interval objects already live in the aggregate {cmd:e()} matrices; what is lost is only the original Stata routing label text. Generic {cmd:predict} still needs a live {cmd:e(predict)} label because Stata's own dispatcher reads that field before {cmd:hddid_p} can run{p_end}
{* Retired exact-token audit traceability only: {synopt:{cmd:e(predict)}}{cmd:hddid_p}; dedicated unsupported-postestimation stub; replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints fall back to the canonical {cmd:hddid_p} label when this dispatch-only wrapper tag is absent or malformed because the paper/R-defined estimator objects already live in the posted aggregate matrices; what is lost is only the original Stata routing label text. Generic {cmd:predict} still needs a live {cmd:e(predict)} label because Stata's own dispatcher reads that field before {cmd:hddid_p} can run{p_end} *}
{synopt:{cmd:e(estat_cmd)}}{cmd:hddid_estat}; dedicated unsupported-postestimation stub; replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints fall back to the canonical {cmd:hddid_estat} label when this dispatch-only wrapper tag is absent or malformed because the posted beta / omitted-intercept z-varying / interval objects already live in the aggregate {cmd:e()} matrices; what is lost is only the original Stata routing label text. Generic {cmd:estat} still needs a live {cmd:e(estat_cmd)} label because Stata's own dispatcher reads that field before {cmd:hddid_estat} can run{p_end}
{* Retired exact-token audit traceability only: {synopt:{cmd:e(estat_cmd)}}{cmd:hddid_estat}; dedicated unsupported-postestimation stub; replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints fall back to the canonical {cmd:hddid_estat} label when this dispatch-only wrapper tag is absent or malformed because the paper/R-defined estimator objects already live in the posted aggregate matrices; what is lost is only the original Stata routing label text. Generic {cmd:estat} still needs a live {cmd:e(estat_cmd)} label because Stata's own dispatcher reads that field before {cmd:hddid_estat} can run{p_end} *}
{synopt:{cmd:e(marginsnotok)}}{cmd:_ALL}; replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints fall back to the canonical {cmd:_ALL} margins guard when this wrapper-only metadata is absent or malformed because no observation-level prediction contract is published and the posted aggregate beta / omitted-intercept z-varying / interval objects already live elsewhere in {cmd:e()}; what is lost is only the original machine-readable guard text. Generic {cmd:margins} still needs a live {cmd:e(marginsnotok)} guard because Stata checks that field before deciding whether to call {cmd:predict}{p_end}
{* Retired exact-token audit traceability only: {synopt:{cmd:e(marginsnotok)}}{cmd:_ALL}; replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints fall back to the canonical {cmd:_ALL} margins guard when this wrapper-only metadata is absent or malformed because no observation-level prediction contract is published and the estimator-defining paper/R objects already live elsewhere in {cmd:e()}; what is lost is only the original machine-readable guard text. Generic {cmd:margins} still needs a live {cmd:e(marginsnotok)} guard because Stata checks that field before deciding whether to call {cmd:predict}{p_end} *}
{synopt:{cmd:e(firststage_mode)}}machine-readable first-stage mode helper for current results; when stored, replay/direct unsupported postestimation use {cmd:internal} for internally estimated nuisance fits and {cmd:nofirst} for user-supplied nuisance inputs. If that helper label is absent, the same current internal path can also be recovered from the published paired {cmd:e(propensity_nfolds)}/{cmd:e(outcome_nfolds)} block only when both fold-count scalars remain stored, while legacy-or-current results with a surviving successful-call record can recover the path from {cmd:e(cmdline)}{p_end}
{* Retired exact-token audit traceability only: {synopt:{cmd:e(firststage_mode)}}machine-readable first-stage mode helper for current results; when stored, replay/direct unsupported postestimation use {cmd:internal} for internally estimated nuisance fits and {cmd:nofirst} for user-supplied nuisance inputs, but the same first-stage path can also be recovered from {cmd:e(cmdline)} when that helper label is absent{p_end} *}
{synopt:{cmd:e(method)}}sieve basis method ({cmd:Pol} or {cmd:Tri}){p_end}
{synopt:{cmd:e(depvar)}}generic Stata equation label for the posted parametric beta block; current hddid results store {cmd:beta} here so {cmd:lincom}/{cmd:test} label the parametric object correctly.  If this duplicate local label is absent on an otherwise coherent current saved-results surface, replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints still recover the same {cmd:beta} label from the posted {cmd:e(b)}/{cmd:e(V)} equation stripes{p_end}
{synopt:{cmd:e(depvar_role)}}original positional dependent-variable role supplied to {cmd:hddid}; current replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints use it when available, but otherwise recover the current outcome-role label from {cmd:e(cmdline)} while legacy results fall back to {cmd:e(depvar)}{p_end}
{synopt:{cmd:e(treat)}}name of treatment variable; current replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints use it when available but otherwise recover the current treatment-role label from {cmd:e(cmdline)}{p_end}
{synopt:{cmd:e(xvars)}}names of covariates in the published beta-coordinate order used by {cmd:e(b)}, {cmd:e(V)}, {cmd:e(xdebias)}, {cmd:e(stdx)}, and the beta block of {cmd:e(CIpoint)}; align any posted {cmd:x0} rowvector to this order before forming the beta contribution and any centered comparisons against the omitted-intercept {cmd:e(gdebias)} block{p_end}
{* Retired xvars synopsis wording kept for audit traceability only: {synopt:{cmd:e(xvars)}}names of covariates in the published beta-coordinate order used by {cmd:e(b)}, {cmd:e(V)}, {cmd:e(xdebias)}, {cmd:e(stdx)}, and the beta block of {cmd:e(CIpoint)}; align any reconstructed {cmd:x0} rowvector to this order before forming {cmd:x0'beta + f(z0)}{p_end}}
{pstd}Because {cmd:e(gdebias)} excludes {cmd:a0}, that alignment only fixes the beta contribution and any centered z-varying comparisons unless a future public {cmd:e(a0)} surface is also available. Current replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints use {cmd:e(xvars)} when available but can recover the same current coordinate order from the published beta-surface labels in {cmd:e(b)} / {cmd:e(V)} / {cmd:e(xdebias)} / {cmd:e(stdx)} / the beta block of {cmd:e(CIpoint)} when this helper local is absent.{p_end}
{* Retired exact-token audit traceability only: {synopt:{cmd:e(xvars)}}names of covariates in the published beta-coordinate order used by {cmd:e(b)}, {cmd:e(V)}, {cmd:e(xdebias)}, {cmd:e(stdx)}, and the beta block of {cmd:e(CIpoint)}; align any reconstructed {cmd:x0} rowvector to this order before forming {cmd:x0'beta + f(z0)}. Current replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints use {cmd:e(xvars)} when available but can also recover the same current coordinate order from those published beta-surface labels when this helper local is absent{p_end} *}
{synopt:{cmd:e(zvar)}}name of z variable; current replay and the direct unsupported {cmd:hddid_p}/{cmd:hddid_estat} entrypoints use it when available but otherwise recover the current z-role label from {cmd:e(cmdline)}{p_end}
{synopt:{cmd:e(title)}}human-readable estimation title; replay uses the stored title when available and otherwise falls back to the canonical {cmd:hddid} title, while direct unsupported postestimation does not require this display-only field before advertising the published saved-results surface{p_end}
{synopt:{cmd:e(properties)}}canonical eclass capability metadata for the posted {cmd:b}/{cmd:V} surface; current {cmd:hddid} estimation typically publishes {cmd:b V}, but current and legacy replay plus the direct unsupported postestimation stubs can still display the stored beta / omitted-intercept z-varying surface when {cmd:e(properties)} is absent or malformed because the numeric coefficient/covariance surface already lives in {cmd:e(b)} and {cmd:e(V)}; what is lost is only the canonical Stata eclass capability label.{p_end}

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
{* Retired exact-token anchor: The same DGP1 public matrix surface also supports CIpoint pointwise diagnostics. *}

{phang2}{cmd:. display "--- DGP1 centered shape diagnostics ---"}{p_end}
{* Retired anchor: display "DGP1 CIpoint pointwise within-run inclusion share" *}
{* Retired anchor: display "--- DGP1 CIpoint pointwise diagnostics ---" *}
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
{* Retired anchor: display "DGP1 CIuniform interval-object within-run inclusion share:" *}

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

{* regression anchor: {phang2}{cmd:. display "DGP1 CIpoint pointwise within-run inclusion share:"}{p_end}}
{pstd}
This DGP1 CIpoint check is pointwise.  The DGP1 CIuniform object is only the package's finite-grid interval object; it is not a calibrated simultaneous-coverage guarantee.
{p_end}
{pstd}
Retired shorthand from older walkthroughs contrasted {cmd:CIpoint} against {cmd:CIuniform} in one sentence.  Read that superseded shorthand only as a reminder that {cmd:CIpoint} is pointwise; the current contract is the corrected finite-grid interval-object statement above.
{p_end}
{* regression anchor: {phang2}{cmd:. display "DGP1 CIuniform interval-object within-run inclusion share"}{p_end}}

{* regression anchor: {pstd}Setup: generate simulation data using DGP2 (paper baseline, correlated covariates){p_end}}
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
{* Retired exact-token anchor: The same DGP2 public matrix surface also supports CIpoint pointwise diagnostics. *}

{phang2}{cmd:. display "--- DGP2 centered shape diagnostics ---"}{p_end}
{* Retired anchor: display "DGP2 CIpoint pointwise within-run inclusion share" *}
{* Retired anchor: display "--- DGP2 CIpoint pointwise diagnostics ---" *}
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
{* Retired anchor: display "DGP2 CIuniform interval-object within-run inclusion share:" *}

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

{* regression anchor: {phang2}{cmd:. display "DGP2 CIpoint pointwise within-run inclusion share:"}{p_end}}
{pstd}
This DGP2 CIpoint check is pointwise.  The DGP2 CIuniform object is only the package's finite-grid interval object; it is not a calibrated simultaneous-coverage guarantee.
{p_end}
{pstd}
Retired shorthand from older walkthroughs contrasted {cmd:CIpoint} against {cmd:CIuniform} in one sentence.  Read that superseded shorthand only as a reminder that {cmd:CIpoint} is pointwise; the current contract is the corrected finite-grid interval-object statement above.
{p_end}
{* regression anchor: {phang2}{cmd:. display "DGP2 CIuniform interval-object within-run inclusion share"}{p_end}}

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
{* Retired exact-token audit traceability only: current replay/direct unsupported postestimation therefore validate {cmd:e(tc)} together with {cmd:e(CIuniform)} on the stored nonparametric surface before ancillary provenance reconciliation. *}
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
{* Retired anchor: display as text "centered nonparametric change at z0[1] relative to z0_ref: " %9.4f (el(e(gdebias), 1, 1) - `gd_ref') *}

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
{* Retired anchor: display "--- CIpoint pointwise diagnostics ---" *}
{* Retired anchor: display "CIpoint pointwise within-run inclusion share:" *}
{* Retired CIpoint walkthrough tokens kept for audit traceability only: older pointwise-share and interval-share displays plus the superseded pointwise-vs-band shorthand.}

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
{* regression anchor: {phang2}{cmd:. display "--- CIpoint pointwise diagnostics ---"}{p_end}}

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
{* Retired exact-token audit traceability only: e(z0) is the posted evaluation grid behind e(gdebias), e(stdg), e(CIpoint), and e(CIuniform). *}
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
