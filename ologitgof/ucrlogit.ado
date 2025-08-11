/* Unconstrained contination-ratio logistic regression model */
program ucrlogit, eclass properties(or swml mi)
	version 13

	if !replay() {
		syntax varlist(min=1 numeric fv) [if] [in] [, level(cilevel) or]

		marksample touse

		local cmdline "ucrlogit `0'"				/* Command as typed */
		local title "Unconstrained continuation-ratio logistic regression"
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
		
		/* ------------------------------------------------------------------------- */
		/* Fit unconstrained continuation-ratio model via c-1 binary logistic models */
		/* ------------------------------------------------------------------------- */

		/* Fit a constant-only model (to get the log likelihood) */
		local ll_0 = 0								/* Log likelihood */
		local df_0 = 0								/* Degrees of freedom */
		forvalues i = 2/`c' {
			local j = word("`catlist'", `i')
			tempvar Y`j'
			quietly {
				gen `Y`j'' = .
				replace `Y`j'' = 1 if `depvar' == `j'
				replace `Y`j'' = 0 if `depvar' < `j' & `depvar' ~= .
				logit `Y`j'' if `touse', level(`level')
			}
			local ll_0 = `ll_0' + e(ll)
			local df_0 = `df_0' + e(df_m)
		}		

		/* Fit the full model */
		local nobs = 0								/* Number of observations */
		local ll = 0								/* Log likelihood */
		local df_m = 0								/* Model degrees of freedom */
		forvalues i = 2/`c' {
			local j = word("`catlist'", `i')
			quietly logit `Y`j'' `indepvars' if `touse', level(`level')
			local nobs = max(`nobs', e(N))
			local ll = `ll' + e(ll)
			local df_m = `df_m' + e(df_m)
			tempname b`j' V`j'
			matrix `b`j'' = e(b)
			matrix `V`j'' = e(V)
			local V`j'names = ""
			local names: rownames `V`j''
			foreach name in `names' {
				local V`j'names = "`V`j'names'`j':`name' "
			}
		}

		/* Calculate the likelihood ratio test and pseudo R2 */
		local chi2 = -2*(`ll_0' - `ll')
		local df = `df_m' - `df_0'
		local p = chiprob(`df', `chi2')
		local r2_p = 1 - `ll'/`ll_0'
		
		/* Create the beta vector (b) and covariance matrix (V) */
		/* Mind the row and column headers */
		tempname b V
		local numcoeffs = colsof(`b`j'')	/* Number of coefficients per logit */
		matrix `b' = J(1, `numcoeffs'*(`c'-1), 0)
		matrix `V' = J(`numcoeffs'*(`c'-1), `numcoeffs'*(`c'-1), 0)
		local coeffnames = ""
		forvalues i = 2/`c' {
			local j = word("`catlist'", `i')
			matrix `b'[1, (`i'-2)*`numcoeffs' + 1] = `b`j''
			matrix `V'[(`i'-2)*`numcoeffs' + 1, (`i'-2)*`numcoeffs' + 1] = `V`j''
			local coeffnames = "`coeffnames'`V`j'names' "
		}
		matrix rownames `V' = `coeffnames'
		matrix colnames `V' = `coeffnames'
		matrix colnames `b' = `coeffnames'
		
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
		ereturn local predict ucrlogit_p
		ereturn matrix cat = `cat'
		ereturn local cmd "ucrlogit"
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

	if "`e(cmd)'" ~= "ucrlogit" error 301
	if "`or'" ~= "" local `or' "Odds Ratio"
	
	/* Report results including a regression table */
	disp _newline "`title'" _continue
	disp _col(56) "Number of obs = " %7.0g `nobs'
	disp _col(56) "LR chi2(" %2.0f `df' ")   = " %7.2f `chi2'
	disp _col(56) "Prob < chi2   = " %7.4f `p'
	disp "Log likelihood = " %10.5f `ll' _continue
	disp _col(56) "Pseudo R2     = " %7.4f `r2_p' _newline
	ereturn display, eform(`or') noemptycells level(`level')

	/* Display a description of the logits */
	forvalues i = 2/`c' {
		local j = word("`catlist'", `i')
		disp "Logit `j' compares `depvar'==`j' with `depvar' < `j'"
	}
	
end
