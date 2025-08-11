/* Constrained continuation-ratio logistic regression model */
program ccrlogit, eclass properties(or swml mi)
	version 13

	if !replay() {
		syntax varlist(min=1 numeric fv) [if] [in] [, level(cilevel) or]

		marksample touse

		local cmdline "ccrlogit `0'"				/* Command as typed */
		local title "Constrained continuation-ratio logistic regression"
		tokenize `varlist'
		local depvar `1' 							/* Dependent variable */
		macro shift
		local indepvars `*'							/* Independent variables */
		quietly levelsof `depvar' if `touse', local(catlist)	/* List of category values */
		local c = wordcount("`catlist'")			/* Number of category values */
		
		/* Matrix of category values */
		tempname cat
		matrix `cat' = J(1, `c', 0)
		tokenize `catlist'
		forvalues i = 1/`c' {
			matrix `cat'[1, `i'] = `$_`i''
		}

		/* Dirty trick to get the number of observations */
		/* (before the datafile is expanded below) */
		quietly ologit `depvar' `indepvars' if `touse', iterate(1)
		local nobs = e(N)
		
		/* Recode the dependent variable to get the correct model */
		tempvar newdepvar
		quietly gen `newdepvar' = .
		tempname value newcat
		matrix `newcat' = J(1, `c', 0)
		forvalues i = 1/`c' {
			scalar `value' = `cat'[1, `c'] + `cat'[1, 1] - `cat'[1, `i']
			quietly replace `newdepvar' = `value' if `depvar' == `cat'[1, `i']
			matrix `newcat'[1, `c' + 1 - `i'] = `value'
		}
		
		/* Create number of rows per observation equal to the response level. */
		/* (Assume that the response measures the number of attempts to pass  */
		/*  a test. Each row reports the results (Y=0,1) for one test.)       */
		preserve
		tempvar id testnum Y
		quietly {
			gen `id' = _n if `touse'
			expand `c'
			bysort `id': gen `testnum' = _n if `touse'
			drop if `newdepvar' < `newcat'[1, `testnum']
			by `id': gen `Y' = (`newdepvar' == `newcat'[1, `testnum']) if `touse'
		}
				
		/* Create binary indicator variables for the response */
		local cminus1 = `c' - 1
		local yvars = ""
		forvalues i = `cminus1'(-1)1 {
			tempvar y`i'
			quietly gen `y`i'' = (`testnum' == `i') if `touse'
			local yvars = "`yvars' `y`i''"
		}
				
		/* Fit a constant-only model (to get the log likelihood) */
		quietly glm `Y' `yvars' if `testnum' ~= `c' & `touse', /*
			*/ family(binomial 1) link(logit) nocons

		local ll_0 = e(ll)		/* Log likelihood */
		local df_0 = e(df_m)	/* Degrees of freedom */
		
		/* Fit the full model */
		quietly glm `Y' `indepvars' `yvars' if `testnum' ~= `c' & `touse', /*
			*/ family(binomial 1) link(logit) nocons
		
		local ll = e(ll)		/* Log likelihood */
		local df_m = e(df_m)	/* Model degrees of freedom */

		/* Calculate the likelihood ratio test and pseudo R2 */
		local chi2 = -2*(`ll_0' - `ll')
		local df = `df_m' - `df_0'
		local p = chiprob(`df', `chi2')
		local r2_p = 1 - `ll'/`ll_0'

		/* Create the beta vector (b) and covariance matrix (V) */
		tempname b V
		matrix `b' = e(b)
		matrix `V' = e(V)
		local numcoeffs = colsof(`b')
		local colnames: colnames `b'
		local i = 0
		local coeffnames = ""
		foreach name in `colnames' {
			local i = `i' + 1
			if `i' <= `numcoeffs'-`c'+1 local coeffnames = "`coeffnames' `depvar':`name'"
		}
		forvalues i = 1/`cminus1' {
			local coeffnames = "`coeffnames' _anc:cons`i'"
		}
		matrix colnames `b' = `coeffnames'
		matrix colnames `V' = `coeffnames'
		matrix rownames `V' = `coeffnames'
		
		/* Post the beta vector and covariance matrix */
		ereturn post `b' `V', obs(`nobs') depname(`depvar') esample(`touse')

		/* Save additional results in e() */
		ereturn scalar k_cat = `c'
		ereturn scalar k_exp = `c' - 1		/* Number of ancillary parameters */
		ereturn scalar ll = `ll'
		ereturn scalar ll_0 = `ll_0'
		ereturn scalar df_m = `df_m'
		ereturn scalar df_0 = `df_0'
		ereturn scalar chi2 = `chi2'
		ereturn scalar p = `p'
		ereturn scalar r2_p = `r2_p'
		ereturn local cmdline `cmdline'
		ereturn local title `title'
		ereturn local chi2type "LR"
		ereturn local predict ccrlogit_p
		ereturn matrix cat = `cat'
		ereturn local cmd "ccrlogit"
	}

	/* Replay */
	else {
		syntax [, level(cilevel) or]

		/* Need these for the reporting below */
		local depvar = e(depvar)
		local nobs = e(N)
		local touse = e(sample)
		local c = e(k_cat)
		local ll = e(ll)
		local df = e(df_m) - e(df_0)
		local chi2 = e(chi2)
		local p = e(p)
		local r2_p = e(r2_p)
		local title = e(title)
		quietly levelsof `depvar' if e(sample), local(catlist)
	}

	if "`e(cmd)'" ~= "ccrlogit" error 301
	if "`or'" ~= "" local `or' "Odds Ratio"
	
	/* Report results including a regression table */
	disp _newline "`title'" _continue
	disp _col(56) "Number of obs = " %7.0g `nobs'
	disp _col(56) "LR chi2(" %2.0f `df' ")   = " %7.2f `chi2'
	disp _col(56) "Prob < chi2   = " %7.4f `p'
	disp "Log likelihood = " %10.5f `ll' _continue
	disp _col(56) "Pseudo R2     = " %7.4f `r2_p' _newline
	ereturn display, eform(`or') noemptycells level(`level')

end
