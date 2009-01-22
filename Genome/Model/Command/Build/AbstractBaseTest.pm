package Genome::Model::Command::Build::AbstractBaseTest;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::AbstractBaseTest {
    is => 'Genome::Model::Command::Build',
};

package Genome::Model::Command::Build::AbstractBaseTest::StageOneJobOne;

class Genome::Model::Command::Build::AbstractBaseTest::StageOneJobOne {
    is => 'Genome::Model::EventWithReadSet',
};

sub verify_successful_completion {
    return 1;
}

package Genome::Model::Command::Build::AbstractBaseTest::StageOneJobTwo;

class Genome::Model::Command::Build::AbstractBaseTest::StageOneJobTwo {
    is => 'Genome::Model::EventWithReadSet',
};

sub verify_successful_completion {
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
