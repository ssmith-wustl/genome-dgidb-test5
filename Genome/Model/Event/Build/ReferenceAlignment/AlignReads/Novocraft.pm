package Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Novocraft;
use strict;
use warnings;
use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Novocraft {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::AlignReads'],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[tmp=90000:mem=8000]' -M 8000000 -n 4";
}

1;
