{smcl}
{* *! version 1.0.0 8Oct2013}{...}
{cmd:help ologitgof}{right: ({browse "http://www.stata-journal.com/article.html?article=st0491":SJ17-3: st0491})}
{hline}

{title:Title}

{p2colset 5 18 20 2}{...}
{p2col :{cmd:ologitgof} {hline 2}}Goodness-of-fit tests for ordinal logistic
regression{p_end}
{p2colreset}{...}


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:ologitgof} [{varlist}] {ifin} [{cmd:,} {it:options}]

{synoptset 20}{...}
{synopthdr}
{synoptline}
{synopt:{opt group(#)}}group the observations using {it:#} quantiles; default is {cmd:group(10)}{p_end}
{synopt:{opt all}}execute test for all observations in the dataset{p_end}
{synopt:{opt outsample}}adjust degrees of freedom for samples outside estimation sample{p_end}
{synopt:{opth osvar(newvar)}}generate {it:newvar} containing the ordinal score {p_end}
{synopt:{opt groupvar(newvar)}}generate {it:newvar} containing a group identifier {p_end}
{synopt:{opt patternvar(newvar)}}generate {it:newvar} containing a covariate pattern identifier {p_end}
{synopt:{opt tableHL}}display table of observed and expected frequencies for the Hosmer-Lemeshow (HL) test{p_end}
{synopt:{opt tablePR}}display table of observed and expected frequencies for the Pulkstenis-Robinson (PR) tests{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:ologitgof} is a postestimation command that calculates four
goodness-of-fit tests: the ordinal HL test (Fagerland and
Hosmer 2013, 2016), the PR tests (Pulkstenis and Robinson 2004), and the
Lipsitz test (Lipsitz, Fitzmaurice, and Molenberghs 1996).  The command can be
used after proportional odds logistic regression ({helpb ologit}),
adjacent-category logistic regression ({helpb adjcatlogit}), or constrained
continuation-ratio logistic regression ({helpb ccrlogit}). The PR tests will
be calculated only if the categorical covariates from the estimation command
are specified in {it:varlist}.


{marker options}{...}
{title:Options}

{phang}
{opt group(#)} specifies the number of quantiles to be used to group the 
observations (HL and Lipsitz tests). The default is {cmd:group(10)}.

{phang}
{opt all} requests that the goodness-of-fit test be computed for all
observations in the dataset, ignoring any {helpb if} or {helpb in} qualifier
specified with the estimation command.

{phang}
{opt outsample} adjusts the degrees of freedom for the chi-squared reference 
distribution for samples outside the estimation sample (HL test).

{phang}
{opth osvar(newvar)} generates {it:newvar} containing the ordinal score.

{phang}
{opt groupvar(newvar)} generates {it:newvar} containing a group identifier.

{phang}
{opt patternvar(newvar)} generates {it:newvar} containing a covariate pattern identifier.

{phang}
{opt tableHL} displays a contingency table for the HL test, where the
groups form the rows and the columns consist of the cutoff values of the
ordinal score, observed and estimated frequencies, and totals for each
group.

{phang}
{opt tablePR} displays a contingency table for the PR tests, where the
covariate patterns form the rows and the columns consist of the observed
and estimated frequencies and totals for each pattern.


{marker examples}{...}
{title:Examples}

{pstd}
Setup, using the low birthweight dataset{p_end}
{phang2}{cmd:. webuse lbw}

{pstd}
Generate a four-level ordinal variable based on the continuous birthweight
variable{p_end}
{phang2}{cmd:. generate bwt4 = .}{p_end}
{phang2}{cmd:. replace bwt4 = 1 if bwt > 3500}{p_end}
{phang2}{cmd:. replace bwt4 = 2 if bwt <= 3500 & bwt > 3000}{p_end}
{phang2}{cmd:. replace bwt4 = 3 if bwt <= 3000 & bwt > 2500}{p_end}
{phang2}{cmd:. replace bwt4 = 4 if bwt <= 2500}

{pstd}
Fit a proportional odds logistic regression model{p_end}
{phang2}
{cmd:. ologit bwt4 smoke lwt i.race ptl}

{pstd}
Perform the goodness-of-fit tests{p_end}
{phang2}
{cmd:. ologitgof smoke race, tableHL tablePR}

{pstd}
Fit an adjacent-category logistic regression model (requires {cmd:adjcatlogit}
being installed){p_end}
{phang2}{cmd:. adjcatlogit bwt4 smoke lwt i.race ptl}

{pstd}
Perform the goodness-of-fit tests{p_end}
{phang2}
{cmd:. ologitgof smoke race, tableHL tablePR}

{pstd}
Fit a constrained continuation-ratio logistic regression model (requires
{cmd:ccrlogit} being installed){p_end}
{phang2}
{cmd:. ccrlogit bwt4 smoke lwt i.race ptl}

{pstd}
Perform the goodness-of-fit tests{p_end}
{phang2}
{cmd:. ologitgof smoke race, tableHL tablePR}


{marker savedresults}{...}
{title:Stored results}

{pstd}
{cmd:ologitgof} stores the following in {cmd:r()}:

{synoptset 18 tabbed}{...}
{p2col 5 15 19 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations{p_end}
{synopt:{cmd:r(k_cat)}}number of categories{p_end}
{synopt:{cmd:r(g)}}number of groups{p_end}
{synopt:{cmd:r(numpatterns)}}number of covariate patterns{p_end}
{synopt:{cmd:r(chi2_HL)}}chi-squared statistic; HL test{p_end}
{synopt:{cmd:r(df_HL)}}degrees of freedom; HL test{p_end}
{synopt:{cmd:r(P_HL)}}probability > chi-squared; HL test{p_end}
{synopt:{cmd:r(chi2_PR)}}chi-squared statistic; PR test{p_end}
{synopt:{cmd:r(D2)}}deviance statistic; PR test{p_end}
{synopt:{cmd:r(df_PR)}}degrees of freedom; PR tests{p_end}
{synopt:{cmd:r(P_chi2)}}probability > chi-squared; PR test{p_end}
{synopt:{cmd:r(P_D2)}}probability > chi-squared; PR test{p_end}
{synopt:{cmd:r(chi2_L)}}chi-squared statistic; Lipsitz test{p_end}
{synopt:{cmd:r(df_L)}}degrees of freedom; Lipsitz test{p_end}
{synopt:{cmd:r(P_L)}}probability > chi-squared; Lipsitz test{p_end}

{p2col 5 15 19 2: Macros}{p_end}
{synopt:{cmd:r(cmd)}}{cmd:ologitgof}{p_end}
{synopt:{cmd:r(cmdline)}}command as typed{p_end}
{synopt:{cmd:r(title)}}title in estimation output{p_end}
{synopt:{cmd:r(ecmd)}}{cmd:ologit}, {cmd:adjcatlogit}, or {cmd:ccrlogit}; estimation command{p_end}

{p2col 5 15 19 2: Matrices}{p_end}
{synopt:{cmd:r(cat)}}category values{p_end}
{synopt:{cmd:r(HLtable)}}entire HL contingency table{p_end}
{synopt:{cmd:r(HLtableOE)}}observed and estimated frequencies from the HL 
contingency table{p_end}
{synopt:{cmd:r(PRtable)}}observed and estimated frequencies from the PR 
contingency table{p_end}


{marker references}{...}
{title:References}

{phang}
Fagerland, M. W., and D. W. Hosmer. 2013. A goodness-of-fit test for the
proportional odds regression model. {it:Statistics in Medicine} 32: 2235-2249.

{phang}
------. 2016. Tests for goodness of fit in ordinal logistic
regression models. {it:Journal of Statistical Computation and Simulation}
86: 3398-3418.

{phang}
Lipsitz, S. R., G. M. Fitzmaurice, and G. Molenberghs. 1996. Goodness-of-fit
tests for ordinal response regression models. {it:Applied Statistics} 45:
175-190.

{phang}
Pulkstenis, E., and T. J. Robinson. 2004. Goodness-of-fit tests for ordinal
response regression models. {it:Statistics in Medicine} 23: 999-1014.


{marker authors}{...}
{title:Authors}

{pstd}Morten W. Fagerland{p_end}
{pstd}Oslo Centre for Biostatistics and Epidemiology{p_end}
{pstd}Research Support Services{p_end}
{pstd}Oslo University Hospital{p_end}
{pstd}Oslo, Norway{p_end}
{pstd}morten.fagerland@medisin.uio.no

{pstd}
David W. Hosmer{break}
Department of Mathematics and Statistics{break}
University of Vermont{break}
Burlington, VT


{title:Also see}

{p 4 14 2}Article:  {it:Stata Journal}, volume 17, number 3: {browse "http://www.stata-journal.com/article.html?article=st0491":st0491}{p_end}

{p 7 14 2}Help:  {manhelp ologit R}, {helpb adjcatlogit}, {helpb ccrlogit},
{helpb mlogitgof} (if installed){p_end}
