package Genome::Model::Tools::ListReferenceSequences;

use strict;
use warnings;

use Genome;            

class Genome::Model::Tools::ListReferenceSequences {
    is => 'Command',
    has => [ ],
};

sub help_brief {
    'A lister of Reference Sequence builds.'
}

sub execute {
    my $self = shift;
    
        my @build = Genome::Model::Build->get(subclass_name => 'Genome::Model::Build::ImportedReferenceSequence');

        printf "\n%-15s  %-50s %-15s %-100s \n", 'Build ID', 'Model Name','Version', 'Data Directory';
        print "===========================================================================================================================================\n";
        for (@build) {
            my $version;
            if(defined($_->version)){ 
                $version = $_->version;
            } else {
                $version = '';
            }
            printf "%-15s  %-50s %-15s %-100s \n", $_->id, $_->model->name, $version, $_->data_directory;
        }    
        if(scalar(@build)==0){
            print " Warning: No Imported Reference Sequence Builds were found...\n";
        }
        print "\n";
}

1;

