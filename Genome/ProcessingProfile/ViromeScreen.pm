package Genome::ProcessingProfile::ViromeScreen;

#:eclark 11/16/2009 Code review.

# Short term: There should be a better way to define the class than %HAS.  Also this processing profile exists to wrap a workflow, a more direct reference would be better.
# Long term: See Genome::ProcessingProfile notes.

use strict;
use warnings;

use Genome;
use Data::Dumper;

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
			    ( exists $PROPERTIES{$_}->{valid_values} )
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

    my $class_object = $self->get_class_object;

    for my $property_name ( keys %PROPERTIES ) {
        next if $class_object->{has}->{$property_name}->{is_optional} && !$self->$property_name;
        next unless exists $PROPERTIES{$property_name}->{valid_values};
        unless ( $self->$property_name &&
                 (grep { $self->$property_name eq $_ } @{$PROPERTIES{$property_name}->{valid_values}}) ) {
            $self->error_message(
                sprintf(
                        'Invalid value (%s) for %s.  Valid values: %s',
                        $self->$property_name || '',
                        $property_name,
                        join(', ', @{$PROPERTIES{$property_name}->{valid_values}}),
                )
	    );
            $self->delete;
            return;
        }
    }

    return $self;
}

sub stages {
    return (qw/ screen verify_successful_completion /);
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
