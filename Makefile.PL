#!perl

use strict;
use warnings;
use inc::Module::Install;
use Path::Class ();

name            'GSCApp',
abstract        'this is my abstract';
author          'me';
version         '0.01';
license         'perl';
build_requires  'Test::More'    => '0.62';

# could use this to point to custom installation
# tool, like gsc-scripts or it's successor
#install_script  'foo';

# build explicit list of modules that should be involved
# since this directory is used by projects other than
# App/GSC/GSCApp
my %pm;
for my $d ( map { Path::Class::dir($_) } qw(App GSC GSCApp) ) {
    $d->recurse(
        callback => sub {
            return if ( $_[0]->is_dir );
            return if ( $_[0]->basename !~ /\.pm$/ );
            $pm{"$_[0]"} = '$(INST_LIBDIR)/' . "$_[0]";
        }
    );
}

my $tests = 'App/t/*.t GSC/t/*.t GSCApp/t/*.t';

makemaker_args(
    PM   => \%pm,
    test => { TESTS => $tests },
);

postamble( << "EOS" );

smoke : tests.yml
	\$(PERL) util/testgraph.pl > smoke.html

tests.yml : all
	\$(PERLRUNINST) util/lsf_harness.pl $tests

EOS

WriteAll;

