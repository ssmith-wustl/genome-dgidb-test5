package Genome::Model::Tools::Far::Base;

use strict;
use warnings;

use Genome;

my $FAR_DEFAULT     = '1.84';
my $DEFAULT_THREADS = 4;
my $DEFAULT_END     = 'any';

class Genome::Model::Tools::Far::Base {
	is          => 'Command::V2',
	is_abstract => 1,
	has         => [
		threads => {
			is            => 'Text',
			doc           => 'Number of threads to use',
			is_optional   => 1,
			default_value => $DEFAULT_THREADS,
		},
		trim_end => {
			is          => 'Text',
			doc         => 'Decides on which end adapter removal is performed',
			is_optional => 1,
			default_value => $DEFAULT_END,
		},
	],
};
