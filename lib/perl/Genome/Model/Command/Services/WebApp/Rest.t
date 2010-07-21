#!/gsc/bin/perl

use strict;
use warnings;
use Test::More;
plan tests => 13;

use above 'Genome';

my $restapp = require Genome::Model::Command::Services::WebApp->base_dir . '/Rest.psgi';

ok( $restapp, 'loaded Rest.psgi' );

## I don't want to type these over and over
my $url_to_type = \&Genome::Model::Command::Services::WebApp::Rest::url_to_type;
my $type_to_url = \&Genome::Model::Command::Services::WebApp::Rest::type_to_url;

ok( $url_to_type, 'found url_to_type' );
ok( $type_to_url, 'found type_to_url' );

my @ct = qw{
  genome/instrument-data  Genome::InstrumentData
  genome                  Genome
  genome/foo-bar/baz      Genome::FooBar::Baz
  funky-town              FunkyTown
  funky-town/oklahoma     FunkyTown::Oklahoma
};

#print $url_to_type->('genome/model/build-status') . "\n";

for ( my $i = 0 ; $i + 1 < @ct ; $i += 2 ) {
    is( $url_to_type->( $ct[$i] ), $ct[ $i + 1 ], 'url_to_type ' . $ct[$i] );
    is( $type_to_url->( $ct[ $i + 1 ] ),
        $ct[$i], 'type_to_url ' . $ct[ $i + 1 ] );
}

