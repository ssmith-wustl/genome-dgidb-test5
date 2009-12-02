package Genome::ProcessingProfile::ViromeScreen;

#:eclark 11/16/2009 Code review.

# Short term: There should be a better way to define the class than %HAS.  Also this processing profile exists to wrap a workflow, a more direct reference would be better.
# Long term: See Genome::ProcessingProfile notes.

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::ProcessingProfile::ViromeScreen {
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
        sequencing_platform => {
    	    doc => 'Sequencing platform used to generate the data',
	        valid_values => [qw/ 454 /], #SO FAR WORK WITH 454 ONLY
        },
    ],    
};

sub stages {
    return (qw/ screen verify_successful_completion /);
}

sub screen_objects {
    return 1;
}

sub screen_job_classes {
    return (qw/
               Genome::Model::Command::Build::ViromeScreen::PrepareInstrumentData
               Genome::Model::Command::Build::ViromeScreen::Screen
            /);
}

1;
