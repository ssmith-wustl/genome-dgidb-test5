package PAP::Command::UploadResult;

use strict;
use warnings;

use Workflow;

class PAP::Command::UploadResult {
    is  => ['PAP::Command'],
    has => [
        biosql_namespace => { is => 'SCALAR', doc => 'biosql namespace'           },
        bio_seq_features => { is => 'ARRAY', doc  => 'array of Bio::Seq::Feature' },
    ],
};

operation PAP::Command::UploadResult {
    input  => [ 'bio_seq_features', 'biosql_namespace' ],
    output => [ ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Store input gene predictions in the BioSQL schema using the specified namespace";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    
    my $self = shift;
    
    
    foreach my $ref (@{$self->bio_seq_features()}) {
        foreach my $feature (@{$ref}) {
            ## Store Feature
        }
    }
    
    return 1;
    
}


1;
