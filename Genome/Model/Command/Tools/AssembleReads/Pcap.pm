
package Genome::Model::Command::Tools::AssembleReads::Pcap;

use strict;
use warnings;

use above "Genome";                         

class Genome::Model::Command::Tools::AssembleReads::Pcap {
    is => 'Command',                       
    has => [                                
        project_name     => { type => 'String',      doc => "organism prefix with _ASSEMBLY" },
    ], 
};



sub help_brief {
    "launch pcap assembler"		    
}

sub help_synopsis {                         
    return <<EOS
genome-model tools assemble-reads pcap --project_name EA_ASSEMBLY
EOS
}

sub help_detail {                           
    return <<EOS 
This launches pcap assembler
EOS
}


sub validate_params {
    my $self = shift;
    return unless $self->SUPER::validate_params(@_);
    # ..do real checks here
    return 1;
}

sub execute {
    my $self = shift;
    print "Running example command:\n" 
        . "project name is " . (defined $self->project_name ? $self->project_name : '<not defined>')
        . "\n";     
    return 1;
}

1;

