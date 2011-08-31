#############################################
### Functions for testing significance of ###
### per-gene categorized mutation rates   ###
#############################################

# Fetch command line arguments
input_file = as.character(commandArgs()[4]);
output_file = as.character(commandArgs()[5]);
run_type = as.character(commandArgs()[6]);
processors = as.numeric(commandArgs()[7]);

# See if we have the necessary packages installed to run in parallel
is.installed <- function( mypkg ) is.element( mypkg, installed.packages()[,1] )
parallel = FALSE
if( is.installed( 'doMC' )) {
  if( is.installed( 'foreach' )) {
    if( processors > 1 ) {
      parallel = TRUE
    }
  }
}

gethist <- function( xmax, n, p, ptype = "positive_log" ) {
  dbinom( 0:xmax, n, p ) -> ps
  ps = ps[ps > 0]
  lastp = 1 - sum( ps )
  if( lastp > 0 ) ps = c( ps, lastp )
  if( ptype == "positive_log" ) ps = -log( ps )
  ps
}

binit <- function( x, hmax, bin, dropbin = T ) {
  bs = as.integer( x / bin )
  bs[bs > hmax/bin] = hmax / bin
  bs[is.na( bs )] = hmax / bin
  tapply( exp(-x), as.factor( bs ), sum ) -> bs
  bs = bs[bs>0]
  bs = -log( bs )
  if( dropbin ) bs = as.numeric( bs )
  bs
}

convolute_b <- function( a, b ) {
  tt = NULL
  for( j in b ) tt = c( tt, ( a + j ))
  tt
}

mut_class_test <- function( x, xmax = 100, hmax = 25, bin = 0.001 ) {
  x = as.data.frame( x )
  colnames( x ) = c( "n", "x", "e" )
  x$p = NA
  x$lh0 = NA
  x$lh1 = NA
  hists = NULL
  for( i in 1:nrow(x) ) {
    x$p[i] = binom.test( x$x[i], x$n[i], x$e[i], alternative = "greater" )$p.value
    x$lh0[i] = dbinom( x$x[i], x$n[i], x$e[i], log = T )
    x$lh1[i] = dbinom( x$x[i], x$n[i], x$x[i] / x$n[i], log = T )
    ni = x$n[i]; ei = x$e[i]
    gethist( xmax, ni, ei, ptype = "positive_log" ) -> bi
    binit( bi, hmax, bin ) -> bi
    if( i == 1 ) hist0 = bi
    if( i > 1 & i < nrow(x) ) { hist0 = convolute_b( hist0, bi ); binit( hist0, hmax, bin ) -> hist0 }
    if( i == nrow(x)) hist0 = convolute_b( hist0, bi )
  }

  # Fisher combined p-value
  q = ( -2 ) * sum( log( x$p ))
  df = 2 * length( x$p )
  p.fisher = 1 - pchisq( q, df )

  # Likelihood ratio test
  q = 2 * ( sum( x$lh1 ) - sum( x$lh0 ))
  df = sum( x$lh1 != 0 )
  if( df > 0 ) p.lr = 1 - pchisq( q, df )
  if( df == 0 ) p.lr = 1

  # Convolution test
  tx = sum( x[,"x"] )
  tn = sum( x[,"n"] )
  ( bx = -sum( x[,"lh0"] ))
  ( p.convol = sum( exp( -hist0[hist0>=bx] )))
  ( qc = sum( exp( -hist0 )))

  if( tx == 0 ) { p.fisher = 1; p.lr = 1; p.convol = 1 }
  # Return results
  rst = list( hists = hist0, x = cbind( x, tn, tx, p.fisher, p.lr, p.convol, qc ))
  rst
}

dotest <- function( idx, mut, zgenes ) {
  step = round( length( zgenes ) / processors )
  start = step * ( idx - 1 ) + 1
  stop = step * idx
  if( idx == processors ) { stop = length( zgenes ) }
  tt = NULL
  for( Gene in zgenes[start:stop] ) {
    mutgi = mut[mut$Gene==Gene,]
    mut_class_test( mutgi[,3:5], hmax = 25, bin = 0.001 ) -> z
    tt = rbind( tt, cbind( Gene, unique( z$x[,(9:11)] )))
  }
  return( tt )
}

combineresults <- function( a, b ) {
  return( rbind( a, b ))
}

smg_test <- function( gene_mr_file, pval_file ) {
  read.delim( gene_mr_file ) -> mut
  colnames( mut ) = c( "Gene", "Class", "Bases_Covered", "Non_Syn_Mutations", "BMR" )
  mut$BMR = as.numeric( as.character( mut$BMR ))

  # Select the rows with BMR data
  mut = mut[( mut$BMR > 0 ) & ( !is.na( mut$BMR )) & ( mut$Bases>0 ),]
  tt = NULL

  # Run in parallel if we have the needed packages, or fall back to the old way
  if( parallel ) {
    library( 'doMC' )
    library( 'foreach' )
    registerDoMC()
    cat( "parallel backend installed - splitting across", processors, "cores\n" )

    options( cores = processors )
    mcoptions <- list( preschedule = TRUE )
    zgenes = unique( as.character( mut$Gene ))
    tt = foreach( idx = 1:processors, .combine="combineresults", .options.multicore = mcoptions ) %dopar% {
      dotest( idx, mut, zgenes )
    }

    write.table( tt, file = pval_file, quote = FALSE, row.names = F, sep = "\t" )
  }
  else {
    for( Gene in unique( as.character( mut$Gene ))) {
      mutgi = mut[mut$Gene==Gene,]
      mut_class_test( mutgi[,3:5], hmax = 25, bin = 0.001 ) -> z
      tt = rbind( tt, cbind( Gene, unique( z$x[,(9:11)] )))
    }
    write.table( tt, file = pval_file, quote = FALSE, row.names = F, sep = "\t" )
  }
}

smg_fdr <- function( pval_file, fdr_file ) {
  read.table( pval_file, header = T, sep = "\t" ) -> x

  #Calculate FDR measure and write FDR output
  p.adjust( x[,2], method="BH" ) -> fdr.fisher
  p.adjust( x[,3], method="BH" ) -> fdr.lr
  p.adjust( x[,4], method="BH" ) -> fdr.convol
  x = cbind( x, fdr.fisher, fdr.lr, fdr.convol )
  #Rank SMGs starting with lowest convolution test FDR, and then by Likelihood Ratio FDR
  x = x[order( fdr.convol, fdr.lr ),];
  write.table( x, file = fdr_file, quote = FALSE, row.names = F, sep = "\t" )
}

# Figure out which function needs to be invoked and call it
if( run_type == "smg_test" )
  smg_test( input_file, output_file )
if( run_type == "calc_fdr" )
  smg_fdr( input_file, output_file )
