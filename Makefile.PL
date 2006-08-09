use ExtUtils::MakeMaker;

# get all the sub-directories where we want to look for modules
my @subdirs;
for ( `find . -type d` ) {
    chomp;
    s(^\./?)();
    next unless ( $_ );
    next if ( m(CVS) );
    next if ( $_ eq 't' or m(^t/) );
    next if ( $_ eq 'blib' or m(^blib/) );
    push @subdirs, $_;
}

# get all the test to run for 'make test'
#open(F, "<t/tests_in_order") or die "cannot open t/tests_in_order: $!";
#my $tests;
#for (<F>) {
#    chomp;
#    $tests .= join(' ', grep{ m(\.t$) } glob("t/$_"), '' );
#}
#close(F);

# write the Makefile
WriteMakefile (
    'NAME'      => 'ALL_GSC_STUFF',
#    'test'      => {TESTS => 't/[0-9][0-9]-*/[0-9][0-9]*.t'},
#    'test'      => {TESTS => q{ `cat t/tests_in_order` } },
#    'test'      => { TESTS => $tests },
    'NORECURS'  => 1,
    'PMLIBDIRS' => \@subdirs,
);
