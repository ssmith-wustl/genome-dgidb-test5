package Genome::Model::Command::Build::ReferenceAlignment::AcceptReads::BlatPlusCrossmatch;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;
use File::Temp;

class Genome::Model::Command::Build::ReferenceAlignment::AcceptReads::BlatPlusCrossmatch {
    is => [
           'Genome::Model::Command::Build::ReferenceAlignment::AcceptReads',
       ],
};

sub help_brief {
    "Not sure what criteria will be used here";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads accept-reads blat-plus-crossmatch --model-id 5 --read-set-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub should_bsub {1;}

sub execute {
    my $self = shift;

    my $model = $self->model;

    $DB::single = $DB::stopper;

    # for now everything passes until criteria are determined
    $self->add_metric(name => 'read set pass fail', value => 'pass');

    return 1;
}


1;

