#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
use Test::MockObject;
use Test::MockModule;
use Sub::Override;
use File::Temp;

plan tests => 4;

# This tests both the case when there are compatible reads, but no new ones to add,
# and when there are no reads at all.  Since that determination is made in the model,
# not AddGoldSnp, by the model returning someting in $model->available_read_sets

    my $tmp_file = new File::Temp(UNLINK => 1, SUFFIX => '.gold');

    my $model = Genome::Model->get(2661729970);#Test::MockObject->new();
    ok ($model, "model creation worked");

    my $add_gold_snp = Genome::Model::Command::AddGoldSnp->create( model => $model,
                                                                   file_name => $tmp_file->filename);
    ok($add_gold_snp, 'Created an AddGoldSnp command for a model');
    my $worked = $add_gold_snp->execute();
    ok ($worked, "gold snp added correctly");
    $add_gold_snp->model->gold_snp_path($add_gold_snp->file_name);
    ok ($model->gold_snp_path,"setting gold snp worked");


