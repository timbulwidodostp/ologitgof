/* predict for adjcatlogit */
program adjcatlogit_p
	version 13

	syntax newvarlist(numeric min=1) [if] [in] [, pr xb outcome(string)]
	marksample touse, novarlist

	if "`e(cmd)'" ~= "adjcatlogit" {
		error 301
	}
	if "`pr'" ~= "" & "`xb'" ~= "" {
		disp in red "only one of xb or pr is allowed"
		exit 198
	}
	if "`xb'" ~= "" & "`outcome'" ~= "" {
		disp in red "option outcome() cannot be specified with option xb"
		exit 198
	}
	if "`pr'" == "" & "`xb'" == "" { 
		local pr "pr"
		disp "(option pr assumed; predicted probability)"
	}

	/* Need some information from the estimation command */
	tempname cat beta
	local depvar = e(depvar)			/* Dependent variable */
	local c = e(k_cat)					/* Number of categories */
	matrix `cat' = e(cat)				/* Category values */
	matrix `beta' = e(b)				/* The coefficient vector */
	local numcoeffs = colsof(`beta')	/* Number of coefficients */
	
	/* Check number of newvarlist vs outcome option and */
	/* the number of categories from the estimation */
	local numnewvar = wordcount("`varlist'")
	if "`outcome'" ~= "" & `numnewvar' ~= 1 {
		disp in red "option pr with outcome() requires that you specify 1 new variable"
		error 103
	}
	else if "`xb'" ~= "" & `numnewvar' ~= 1 {
		disp in red "option xb requires that you specify 1 new variable"
		error 103
	}
	else if "`outcome'" == "" & `numnewvar' == 1 {
		local outcome "#1"
	}
	else if "`outcome'" == "" & `numnewvar' ~= `c' {
		disp in red "`depvar' has `c' outcomes and so you must specify `c' " _continue
		disp in red "new variables, or you can use the "
		disp in red "outcome() option and specify variables one at a time"
		if `numnewvar' < `c' error 102
		if `numnewvar' > `c' error 103
	}
	
	/* Calculate linear predictor (x*beta) */
	tempname xbeta
	matrix score `xbeta' = `beta' if `touse', forcezero

	/* Generate the linear predictor to newvarlist if the xb option is specified */
	if "`xb'" ~= "" {
		quietly gen `varlist' = `xbeta'
		label variable `varlist' "Linear prediction (constants excluded)"
		exit
	}

	/* Calculate the predicted probabilities */
	/* Assign them to temporary variables at this time */
	local cminus1 = `c' - 1
	forvalues j = 1/`cminus1' {
		tempvar g_`j' theta_`j'
		quietly gen `g_`j'' = `xbeta' + `beta'[1, `numcoeffs' - `c' + 1 +`j'] if `touse'
	}
	tempvar theta
	quietly gen `theta' = 0 if `touse'
	forvalues j = 1/`cminus1' {
		tempvar theta_`j'
		quietly gen `theta_`j'' = 1 if `touse'
		forvalues k = 1/`j' {
			quietly replace `theta_`j'' = `theta_`j''*exp(`g_`k'') if `touse'
		}
		quietly replace `theta' = `theta' + `theta_`j'' if `touse'
	}
	tempvar p1
	quietly gen `p1' = 1/(1 + `theta') if `touse'
	forvalues j = 2/`c' {
		local jminus1 = `j' - 1
		tempvar p`j'
		quietly gen `p`j'' = `theta_`jminus1''/(1 + `theta') if `touse'
	}
	
	/* Generate the predicted probabilities to newvarlist */
	tokenize `varlist'
	forvalues j = 1/`c' {
		local y = `cat'[1,`j']
		if "`outcome'" == "" | "`outcome'" == "#`j'" | "`outcome'" == "`y'" {
			quietly gen `1' = `p`j''
			label variable `1' "Pr(`depvar'==`y')"
			macro shift
		}
	}

end
