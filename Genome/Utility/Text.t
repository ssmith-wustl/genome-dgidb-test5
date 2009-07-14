#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More 'no_plan';

use_ok('Genome::Utility::Text');

# camel case
my $string = 'genome model de novo assembly';
my $camel_case = 'GenomeModelDeNovoAssembly';
is(Genome::Utility::Text::string_to_camel_case($string), $camel_case, 'string to camel case');
is(Genome::Utility::Text::camel_case_to_string($camel_case), $string, 'camel case to string');

# class/module
my $class = 'Genome::Model::DeNovoAssembly';
my $module = 'Genome/Model/DeNovoAssembly.pm';
is(Genome::Utility::Text::class_to_module($class), $module, 'class to module');
is(Genome::Utility::Text::module_to_class($module), $class, 'module to class');

# params
my $param_string = '-aa fasta -b1b -1 qual --c22 phred phrap  -ddd -11 -eee -f -g22g text -1111 --h 44';
my $params = {
    aa => 'fasta', b1b => '-1 qual', c22 => 'phred phrap ', ddd => -11, eee => 1, f => 1, g22g => 'text -1111', h => 44,
};
my %hash = Genome::Utility::Text::param_string_to_hash($param_string);
is_deeply(\%hash, $params, 'params string to hash');
for my $invalid_string ( undef, 'a' ) {
    my %hash =  Genome::Utility::Text::param_string_to_hash($invalid_string);
    ok(!%hash, 'Failed param string ('.(defined $invalid_string ? $invalid_string : 'undef').") to hash as expected:\n$@");
}

exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

