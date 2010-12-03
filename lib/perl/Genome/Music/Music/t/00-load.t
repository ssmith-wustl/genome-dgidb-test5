#!perl -T

use Test::More tests => 7;

BEGIN {
	use_ok( 'Music' );
	use_ok( 'Music::SMG' );
	use_ok( 'Music::Proximity' );
	use_ok( 'Music::CosmicOmim' );
	use_ok( 'Music::Pathway' );
	use_ok( 'Music::MutationRelation' );
	use_ok( 'Music::Correlation' );
}

diag( "Testing Music $Music::VERSION, Perl $], $^X" );
