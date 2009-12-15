package Genome::ProcessingProfile::ViromeScreen;

use strict;
use warnings;

use Genome;

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
    return (qw/ screen /);
}

sub screen_objects {
    return 1;
}

sub screen_job_classes {
    return (qw/
               Genome::Model::Event::Build::ViromeScreen::PrepareInstrumentData
               Genome::Model::Event::Build::ViromeScreen::Screen
            /);
}

1;
