{smcl}
{* *! version 1.0.0 05Dec2013}{...}
{cmd:help adjcatlogit}{right: ({browse "http://www.stata-journal.com/article.html?article=st0367":SJ14-4: st0367})}
{hline}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :{bf:adjcatlogit} {hline 2}}Adjacent-category logistic regression for ordered response data{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}{cmdab:adjcatlogit} {depvar} [{indepvars}] {ifin} [{cmd:,}
{it:options}]

{synoptset 20}{...}
{synopthdr}
{synoptline}
{synopt:{opt level(#)}}set confidence level; default is {cmd:level(95)}{p_end}
{synopt:{opt or}}report odds ratios{p_end}
{synopt:{opt listconstraints}}list the constraints used by {help mlogit} to fit the model{p_end}
{synoptline}
INCLUDE help fvvarlist


{marker description}{...}
{title:Description}

{pstd}{cmd:adjcatlogit} fits adjacent-category logistic regression models of ordinal variable 
{depvar} on the independent variables {indepvars}.  The actual values taken on by the dependent
variable are irrelevant, except that larger values are assumed to correspond to "higher" 
outcomes.

{pstd}See {helpb ologit}, {helpb ccrlogit}, and {helpb ucrlogit} for related estimation commands.


{marker options}{...}
{title:Options for adjcatlogit}

{phang}
{opt level(#)} specifies the confidence level, as a percentage, for the
confidence interval. The default is {cmd:level(95)} or as set by {cmd:set level}.

{phang}
{opt or} reports the estimated coefficients transformed to odds ratios,
that is, exp(b) rather than b.  Standard errors and confidence intervals
are similarly transformed.  This option affects how results are
displayed, not how they are estimated.  {opt or} may be specified at
estimation or when replaying previously estimated results.

{phang}
{opt listconstraints} requests that a list of the {help constraint:constraints} used by {helpb mlogit} to fit the model be
displayed (see {help adjcatlogit##remarks it:Remarks} below).


{title:Syntax for predict}

{p 8 16 2}{cmdab:predict} {{newvar}|{it:newvarlist}} {ifin} [{cmd:,}
{it:options}]

{synoptset 20}{...}
{synopthdr}
{synoptline}
{synopt:{opt pr}}calculate predicted probabilities; default{p_end}
{synopt:{opt xb}}calculate linear prediction{p_end}
{synopt:{opt outcome(outcome)}}specify the outcome for which the predicted
probabilities are to be  
calculated{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}
If you do not specify {cmd:outcome()}, {cmd:pr} (with one new variable
specified) assumes {cmd:outcome(#1)}.{p_end}
{p 4 6 2}
You specify one or c new variables with {cmd:pr}, where c is the number
of outcomes.{p_end}
{p 4 6 2}
You specify one new variable with {cmd:xb}.{p_end}


{title:Options for predict}

{phang}
{opt pr} calculates the predicted probabilities. This is the default. If you do
not also specify the {opt outcome()} option, you specify one or c new
variables, where c is the number of categories of the dependent
variable.  If you specify one new variable (and no {opt outcome()}
option), {cmd:outcome(#1)} is assumed.  If you specify the {opt outcome()} option, you must specify one new variable.

{phang}
{opt xb} calculates the linear prediction.  You specify one new variable
(and no {opt outcome()} option).  The contributions of the estimated
constants are ignored in the calculations.

{phang}
{opt outcome(outcome)} specifies the outcome for which the predicted
probabilities are to be calculated.  {opt outcome()} should contain
either one value of the dependent variable or one of {opt #1}, {opt #2}, {it:...} with {opt #1} meaning the first category of the dependent
variable, {opt #2} meaning the second category, etc.


{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:adjcatlogit} fits the adjacent category model
using constrained multinomial logistic regression ({helpb mlogit}), where
the lowest category of the dependent variable is used as the reference
category.  The {helpb constraint:constraint free} command is used to
select free (unused) constraint numbers.  The constraints are not dropped
after estimation, so the number of free constraints is reduced each time
an adjacent category model is estimated.  The maximum number of
constraints in Stata is 1,999, which is sufficient for a large number of
estimations with {cmd:adjcatlogit}.  If there are not enough free
constraints, {cmd:adjcatlogit} will exit and give the error {cmd:no free constraints}.  If that happens, {helpb constraint:constraint drop} can be used to increase the number of free constraints.


{marker examples}{...}
{title:Examples}

{pstd}Set up with the low birthweight dataset{p_end}
{phang2}{cmd: . webuse lbw}

{pstd}Generate a four-level ordinal variable based on the continuous birthweight variable{p_end}
{phang2}{cmd: . generate bwt4 = .}{p_end}
{phang2}{cmd: . replace bwt4 = 1 if bwt > 3500}{p_end}
{phang2}{cmd: . replace bwt4 = 2 if bwt <= 3500 & bwt > 3000}{p_end}
{phang2}{cmd: . replace bwt4 = 3 if bwt <= 3000 & bwt > 2500}{p_end}
{phang2}{cmd: . replace bwt4 = 4 if bwt <= 2500}

{pstd}Fit an adjacent-category logistic regression model{p_end}
{phang2}{cmd: . adjcatlogit bwt4 age lwt smoke##race}

{pstd}Report odds ratios instead of estimated coefficients{p_end}
{phang2}{cmd: . adjcatlogit, or}

{pstd}Calculate predicted probabilities{p_end}
{phang2}{cmd: . predict p1-p4}


{marker storedresults}{...}
{title:Stored results}

{pstd}
{cmd:adjcatlogit} stores the following in {cmd:e()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:e(N)}}number of observations{p_end}
{synopt:{cmd:e(k_cat)}}number of categories{p_end}
{synopt:{cmd:e(k_exp)}}number of auxiliary parameters{p_end}
{synopt:{cmd:e(df_m)}}model degrees of freedom{p_end}
{synopt:{cmd:e(df_0)}}degrees of freedom, constant-only model{p_end}
{synopt:{cmd:e(r2_p)}}pseudo-R-squared{p_end}
{synopt:{cmd:e(ll)}}log likelihood{p_end}
{synopt:{cmd:e(ll_0)}}log likelihood, constant-only model{p_end}
{synopt:{cmd:e(chi2)}}chi-squared{p_end}
{synopt:{cmd:e(p)}}significance{p_end}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:e(cmd)}}{cmd:adjcatlogit}{p_end}
{synopt:{cmd:e(cmdline)}}command as typed{p_end}
{synopt:{cmd:e(constraints)}}list of constraints{p_end}
{synopt:{cmd:e(depvar)}}name of dependent variable{p_end}
{synopt:{cmd:e(title)}}title in estimation output{p_end}
{synopt:{cmd:e(chi2type)}}{cmd:Wald} or {cmd:LR}; type of model chi-squared test{p_end}
{synopt:{cmd:e(properties)}}{cmd:b V}{p_end}
{synopt:{cmd:e(predict)}}program used to implement {cmd:predict}{p_end}


{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Matrices}{p_end}
{synopt:{cmd:e(b)}}coefficient vector{p_end}
{synopt:{cmd:e(cat)}}category values{p_end}
{synopt:{cmd:e(V)}}variance-covariance matrix of the estimators{p_end}


{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Functions}{p_end}
{synopt:{cmd:e(sample)}}marks estimation sample{p_end}
{p2colreset}{...}


{marker author}{...}
{title:Author}

{pstd}Morten W. Fagerland{p_end}
{pstd}Oslo Centre for Biostatistics and Epidemiology{p_end}
{pstd}Research Support Services{p_end}
{pstd}Oslo University Hospital{p_end}
{pstd}Oslo, Norway{p_end}
{pstd}morten.fagerland@medisin.uio.no


{marker also_see}{...}
{title:Also see}

{p 4 14 2}Article:  {it:Stata Journal}, volume 14, number 4: {browse "http://www.stata-journal.com/article.html?article=st0367":st0367}
{p_end}
