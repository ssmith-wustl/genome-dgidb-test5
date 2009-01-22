package Genome::Model::Command::Build::AmpliconAssembly;

use strict;
use warnings;

use Genome;

use Genome::Model::Command::Build::AmpliconAssembly::VerifyInstrumentData;
use Genome::Model::Command::Build::AmpliconAssembly::Assemble;
use Genome::Model::Command::Build::AmpliconAssembly::Collate;
use Genome::Model::Command::Build::AmpliconAssembly::Orient;
#use Genome::Model::Command::Build::AmpliconAssembly::QualityHistogram;
use Genome::Model::Command::Build::AmpliconAssembly::PostProcess;
use Genome::Model::Command::Build::AmpliconAssembly::PostProcess::Composition;
use Genome::Model::Command::Build::AmpliconAssembly::PostProcess::Reference;
use Genome::Model::Command::Build::AmpliconAssembly::CleanUp;
;
class Genome::Model::Command::Build::AmpliconAssembly {
    is => 'Genome::Model::Command::Build',
};

#< Helps >#
sub help_brief {
    return
}

sub help_synopsis {
    return;
}

sub help_detail {
    return;
}


1;

#$HeadURL$
#$Id$
