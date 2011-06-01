#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More 'no_plan';

use_ok('Genome::Utility::Text') or die;

# camel case
my $string                  = 'genome model reference alignment 454x titanium';
my $capitalized_string      = 'Genome Model Reference Alignment 454x Titanium';
my $camel_case              = 'GenomeModelReferenceAlignment454xTitanium';
is(Genome::Utility::Text::string_to_camel_case($string), $camel_case, 'string_to_camel_case');
ok(!Genome::Utility::Text::string_to_camel_case(undef), 'string_to_camel_case failed w/o string');
is(Genome::Utility::Text::camel_case_to_string($camel_case), $string, 'camel_case_to_string');
ok(!Genome::Utility::Text::camel_case_to_string(undef), 'camel_case_to_string failed w/o camel case');
is(Genome::Utility::Text::camel_case_to_capitalized_words($camel_case), $capitalized_string, 'camel_case_to_capitalized_words');
ok(!Genome::Utility::Text::camel_case_to_capitalized_words(undef), 'camel_case_to_capitalized_words failed w/o camel case');

# class/module
my $class  = 'Genome::Model::DeNovoAssembly';
my $module = 'Genome/Model/DeNovoAssembly.pm';
is(Genome::Utility::Text::class_to_module($class), $module, 'class_to_module');
ok(!Genome::Utility::Text::class_to_module(undef), 'class_to_module failed w/o class');
is(Genome::Utility::Text::module_to_class($module), $class, 'module_to_class');
ok(!Genome::Utility::Text::module_to_class(undef), 'module_to_class failed w/o module');

# params
my $param_string = '-aa fasta -b1b -1 qual --c22 phred phrap  -ddd -11 -eee -f -g22g text -1111 --h_h 44 --i-i -5 -j-----j -5 -6 hello     -k    -l_l-l g  a   p   ';
my $params = {
    aa => 'fasta', b1b => '-1 qual', c22 => 'phred phrap', ddd => -11, eee => 1, f => 1, g22g => 'text -1111', h_h => 44, 'i-i' => -5, 'j-----j' => '-5 -6 hello', k => 1, 'l_l-l' => 'g  a   p', };
my %hash = Genome::Utility::Text::param_string_to_hash($param_string);
is_deeply(\%hash, $params, 'params string to hash');
print Dumper(\%hash);
for my $invalid_string ( undef, 'a' ) {
    my %hash =  Genome::Utility::Text::param_string_to_hash($invalid_string);
    ok(!%hash, 'Failed param string ('.(defined $invalid_string ? $invalid_string : 'undef').") to hash as expected:\n$@");
}

# san file sys
my $fs_string  = 'new!@sample%for^^new(#|)model_assembly';
my $san_string = 'new__sample_for__new____model_assembly';
is(Genome::Utility::Text::sanitize_string_for_filesystem($fs_string), $san_string, 'sanitize string for filesystem');
ok(!Genome::Utility::Text::sanitize_string_for_filesystem(undef), 'failed as expected - sanitize string for filesystem w/o string');

# capitalize words
my $uncap_string1 = 'goOd Morning vietnam!';
my $uncap_string2 = 'goOd Morning-vietnam!';
my $cap_string   = 'GoOd Morning Vietnam!';
is(Genome::Utility::Text::capitalize_words($uncap_string1), $cap_string, 'capitalize words');
is(Genome::Utility::Text::capitalize_words($uncap_string2, '-'), $cap_string, 'capitalize words');
ok(!eval{Genome::Utility::Text::capitalize_words(undef)}, 'failed as expected - capitalize w/o string words');

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

