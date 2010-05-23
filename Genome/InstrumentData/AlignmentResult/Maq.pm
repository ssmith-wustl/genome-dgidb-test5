package Genome::InstrumentData::AlignmentResult::Maq;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::AlignmentResult::Maq {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'maq' },
    ],
};

sub required_arch_os { 
    'x86_64' 
}

sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[tmp=50000:mem=12000]' -M 1610612736";
}

sub extra_metrics {
    'contaminated_read_count'
}

1;
