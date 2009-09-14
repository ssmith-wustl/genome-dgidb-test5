package Genome::ProcessingProfile::ViromeScreen;

use strict;
use warnings;

use Genome;

my %PROPERTIES = (
    sequencing_platform => {
	doc => 'Sequencing platform used to generate the data',
	valid_values => [qw/ 454 /], #SO FAR WORK WITH 454 ONLY
    },
);

class Genome::ProcessingProfile::ViromeScreen {
    is => 'Genome::ProcessingProfile',
    has => [
	map {
	    $_ => {
		via => 'params',
		to => 'value',
		where => [ name => $_ ],
		is_optional => (
		    ( exists $PROPERTIES{$_}->{is_optional} )
		    ? $PROPERTIES{$_}->{is_optional}
		    : 0
		    ),
			is_mutable => 1,
			doc => (
			    ( exists $PROPERTIES{$_}->{valid_valiues} )
			    ? sprintf('%s Valid values: %s.', $PROPERTIES{$_}->{doc}, join(', ', @{$PROPERTIES{$_}->{valid_values}}))
			    : $PROPERTIES{$_}->{doc}
			),
	    },
	} keys %PROPERTIES
    ],    
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;
    return $self;
}

sub stages {
    return (qw/
               screen
               verify_successful_completion
    /);
}

sub screen_objects {
    return 1;
}

sub params_for_class {
    return keys %PROPERTIES;
}

sub screen_job_classes {
    return (qw/
               Genome::Model::Command::Build::ViromeScreen::PrepareInstrumentData
               Genome::Model::Command::Build::ViromeScreen::Screen
            /);
}

1;
