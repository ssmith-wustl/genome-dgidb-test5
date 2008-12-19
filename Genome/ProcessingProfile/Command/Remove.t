#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper;
use Test::More tests => 13;

BEGIN {
    use_ok('Genome::ProcessingProfile::Command::Remove');
}

# GOOD
# Create a pp to test
my $pp = Genome::ProcessingProfile::Test->create(
    name => 'test for renaming',
    colour => 'read',
    shape => 'square',
);
ok($pp, "Created processing profile to test");
die unless $pp; # can't proceed

my $new_name = 'eddie awesome pp for mgc';
my $remover = Genome::ProcessingProfile::Command::Remove->create(
    processing_profile_id => $pp->id,
);
ok($remover, 'Created the remover');
isa_ok($remover, 'Genome::ProcessingProfile::Command::Remove');
ok($remover->execute, 'Executed the remover');

#< BAD >#
# invalid id - sanity check that we have a _verify_processing_profile method before executing
my $bad1 = Genome::ProcessingProfile::Command::Remove->create(
    processing_profile_id => -1,
);
ok($bad1, 'Created the remover w/ invalid id');
isa_ok($bad1, 'Genome::ProcessingProfile::Command::Remove');
ok(!$bad1->execute, 'Execute failed as expected');

# try to remove a pp that has models
# Create a pp to test
my $pp_w_model = Genome::ProcessingProfile::MetaGenomicComposition->create(
    name => 'test meta genomic composition',
    sequencing_platform => 'sanger',
    assembler => 'phredphrap',
    sequencing_center => 'gsc',
    assembly_size => 1300,
);
ok($pp_w_model, "Created processing profile to add to a model");
die unless $pp_w_model; # can't proceed

# Create a model to test
my $model = Genome::Model::MetaGenomicComposition->create(
    name => 'test meta genomic composition',
    subject_name => 'dna',
    subject_type => 'dna_resource_item_name',
    processing_profile_id => $pp_w_model->id,
);
ok($model, "Created model w/ above pp");
die unless $model; # can't proceed

my $bad2 = Genome::ProcessingProfile::Command::Remove->create(
    processing_profile_id => $pp_w_model->id,
);
ok($bad2, 'Created the remover w/ a processing profile that has a model');
isa_ok($bad2, 'Genome::ProcessingProfile::Command::Remove');
ok(!$bad2->execute, 'Could not execute the bad remover w/o name');

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

