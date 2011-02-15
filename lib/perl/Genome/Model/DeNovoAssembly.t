#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::DeNovoAssembly::Test;
use Test::More 'no_plan';

use_ok('Genome::Model::DeNovoAssembly');

my $model = Genome::Model::DeNovoAssembly::Test->model_for_soap;
ok($model, 'mock model');
is($model->center_name, 'WUGC', 'center name');
is($model->default_model_name, 'Escherichia coli TEST De Novo Assembly Soap Test', 'default model name');

my %tissue_descs_and_name_parts = (
    '20l_p' => undef,
    'u87' => undef,
    'zo3_G_DNA_Attached gingivae' => 'Attached Gingivae',
    'lung, nos' => 'Lung Nos',
    'mock community' => 'Mock Community',
);
for my $tissue_desc ( keys %tissue_descs_and_name_parts ) {
    my $name_part = $model->_get_name_part_from_tissue_desc($tissue_desc);
    is($name_part, $tissue_descs_and_name_parts{$tissue_desc}, 'tissue desc converted to name part');
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

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/MetagenomicComposition16s.t $
#$Id: MetagenomicComposition16s.t 56090 2010-03-03 23:57:25Z ebelter $

