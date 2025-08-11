/* predict for ucrlogit */
program ucrlogit_p
	version 13

	syntax newvarlist(numeric min=1) [if] [in] [, pr xb outcome(string)]
	marksample touse, novarlist

	if "`e(cmd)'" ~= "ucrlogit" {
		error 301
	}
	if "`pr'" ~= "" & "`xb'" ~= "" {
		disp in red "only one of xb or pr is allowed"
		exit 198
	}
	if "`pr'" == "" & "`xb'" == "" { 
		local pr "pr"
		disp "(option pr assumed; predicted probability)"
	}

	/* Need some information from the estimation command */
	tempname cat beta
	local depvar = e(depvar)		/* Dependent variable */
	local c = e(k_cat)				/* Number of categories */
	matrix `cat' = e(cat)			/* Category values */
	matrix `beta' = e(b)			/* The coefficient vector */
	
	/* Check number of newvarlist vs outcome option and */
	/* the number of categories from the estimation */
	local numnewvar = wordcount("`varlist'")
	if "`outcome'" ~= "" & `numnewvar' ~= 1 {
		disp in red "option `pr'`xb' with outcome() requires that you specify 1 new variable"
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
	forvalues j = 1/`c' {
		tempname xb_`j'
		if `j' == 1 {
			quietly gen `xb_1' = 0 if `touse'
		}
		else { 
			local eqnum = `j' - 1
			matrix score `xb_`j'' = `beta' if `touse', equation(#`eqnum')
		}
	}

	/* Generate the linear predictor(s) to newvarlist if the xb option is specified */
	if "`xb'" ~= "" {
		tokenize `varlist'
		forvalues j = 1/`c' {
			local y = `cat'[1,`j']
			if "`outcome'" == "" | "`outcome'" == "#`j'" | "`outcome'" == "`y'" {
				quietly gen `1' = `xb_`j''
				label variable `1' "Linear prediction, `depvar'==`y' vs `depvar' < `y'"
				macro shift
			}
		}
		exit
	}

	/* Calculate the predicted probabilities */
	/* Assign them to temporary variables at this time */
	forvalues j = `c'(-1)1 {
		tempvar p`j'
		if `j' == `c' {
			quietly gen `p`j'' = exp(`xb_`j'')/(1 + exp(`xb_`j'')) if `touse'
		}
		else {
			local jplus1 = `j' + 1
			tempvar gamma_`jplus1'
			quietly gen `gamma_`jplus1'' = 0 if `touse'
			forvalues k = `jplus1'/`c' {
				quietly replace `gamma_`jplus1'' = `gamma_`jplus1'' + `p`k'' if `touse'
			}
			quietly replace `gamma_`jplus1'' = 1 - `gamma_`jplus1''
			if `j' == 1 {
				quietly gen `p`j'' = `gamma_`jplus1'' if `touse'
			}
			else {
				quietly gen `p`j'' = `gamma_`jplus1''*exp(`xb_`j'')/(1 + exp(`xb_`j'')) if `touse'
			}
		}
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
