#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More 'no_plan';

use_ok('Genome::Utility::Text');
my $string = 'genome model de novo assembly';
my $camel_case = 'GenomeModelDeNovoAssembly';
is(Genome::Utility::Text::string_to_camel_case($string), $camel_case, 'string to camel case');
is(Genome::Utility::Text::camel_case_to_string($camel_case), $string, 'camel case to string');
my $class = 'Genome::Model::DeNovoAssembly';
my $module = 'Genome/Model/DeNovoAssembly.pm';
is(Genome::Utility::Text::class_to_module($class), $module, 'class to module');
is(Genome::Utility::Text::module_to_class($module), $class, 'module to class');

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

