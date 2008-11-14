package Genome::Model::Command::Build::AbstractBaseTest;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::AbstractBaseTest {
    is => 'Genome::Model::Command::Build',
};

sub stages {
    my @stages = qw/
                    stage1
                    stage2
                   /;
    return @stages;
}

sub stage1_objects {
    my $self = shift;
    my $model = $self->model;
    my @read_sets = $model->read_sets;
    return @read_sets;
}

sub stage2_objects {
    my $self = shift;
    my $model = $self->model;
    my @ref_seqs = $model->ref_seqs;
    return @ref_seqs;
}

sub stage1_job_classes {
    return (
            'Genome::Model::Command::Build::AbstractBaseTest::StageOneJobOne',
            'Genome::Model::Command::Build::AbstractBaseTest::StageOneJobTwo',
            'Genome::Model::Command::Build::AbstractBaseTest::StageOneJobThree',
        );
}

sub stage2_job_classes {
    return (
            'Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobOne',
            'Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobTwo',
        );
}

sub _get_sub_command_class_name{
  return __PACKAGE__;
}


package Genome::Model::Command::Build::AbstractBaseTest::StageOneJobOne;

class Genome::Model::Command::Build::AbstractBaseTest::StageOneJobOne {
    is => 'Genome::Model::EventWithReadSet',
};

sub verify_succesful_completion {
    return 1;
}

package Genome::Model::Command::Build::AbstractBaseTest::StageOneJobTwo;

class Genome::Model::Command::Build::AbstractBaseTest::StageOneJobTwo {
    is => 'Genome::Model::EventWithReadSet',
};

sub verify_succesful_completion {
    return 0;
}

package Genome::Model::Command::Build::AbstractBaseTest::StageOneJobThree;

class Genome::Model::Command::Build::AbstractBaseTest::StageOneJobThree {
    is => 'Genome::Model::EventWithReadSet',
};

package Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobOne;

class Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobOne {
    is => 'Genome::Model::EventWithRefSeq',
};

package Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobTwo;

class Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobTwo {
    is => 'Genome::Model::EventWithRefSeq',
};


1;
