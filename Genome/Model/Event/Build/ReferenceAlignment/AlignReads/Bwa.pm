package Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Bwa;
use strict;
use warnings;
use Genome;

class Genome::Model::Event::Build::ReferenceAlignment::AlignReads::Bwa {
    is => ['Genome::Model::Event::Build::ReferenceAlignment::AlignReads'],
};

sub bsub_rusage {
    return "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>10000] span[hosts=1] rusage[tmp=90000, mem=10000]' -M 10000000 -n 4";
}

1;

