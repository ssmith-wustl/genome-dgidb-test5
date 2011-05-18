package Genome::ProcessingProfile::MetagenomicComposition16s;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::MetagenomicComposition16s {
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
        # About
        amplicon_size => {
            is => 'Integer',
            doc => 'Minimum amplicon size.  If an amplicon is less than this length, it will not be used.',
        },
        sequencing_center => {
            is => 'Text',
            doc => 'Place from whence the reads have come.',
            valid_values => [qw/ gsc broad /],
        },
        sequencing_platform => {
            is => 'Text',
            doc => 'Platform (machine) from whence the reads where created.',
            valid_values => [qw/ sanger 454 solexa /],
        },
        exclude_contaminated_amplicons => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'When getting amplicons, exclude those that have a contaminated read(s). Only for "gsc" generated reads. Default is to include all amplicons.',
        },
        only_use_latest_iteration_of_reads => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'When getting reads for amplicons, only use the most recent iteration for each primer. Currently, only for "gsc" sanger reads. Default is to include all reads for each amplicon.',
        },
        #< Assembler >#
        assembler => {
            is => 'Text',
            is_optional => 1,
            doc => 'Assembler name for assembling the reads.',
            valid_values => [qw/ phred_phrap /],
        },
        assembler_params => {
            is => 'Text',
            is_optional => 1,
            doc => 'A string of parameters to pass to the assembler',
            is_optional => 1,
        },
        #< Classifier >#
        classifier => {
            is => 'Text',
            is_optional => 1,
            doc => 'Classifier name for classifing the amplicons.',
            default_value => 'rdp2-1', 
            valid_values => [qw/ rdp2-1 rdp2-2 kroyer /],
            #valid_values => [qw/ rdp kroyer /],
        },
        classifier_version => {
            is => 'Text',
            is_optional => 1,
            doc => 'The version of the classifier to use.',
            is_optional => 1,
        },
        classifier_params => {
            is => 'Text',
            is_optional => 1,
            doc => 'A string of parameters to pass to the classifier.',
            is_optional => 1,
        },
    ],
};

#< Create >#
sub create {
    my $class = shift;
    
    my $self = $class->SUPER::create(@_)
        or return;

    # Validate params
    for my $type (qw/ assembler classifier /) { 
        my $method = $type.'_params_as_hash';
        $self->$method; # dies if error
    }
    
    # Validate classifier version
    # TODO
    
    return $self;
}

#< BUILDING >#
sub stages {
    return (qw/ one /);
}

sub one_job_classes {
    my $self = shift;

    my @subclasses;

    my $sequencing_platform_cc = Genome::Utility::Text::string_to_camel_case(
        $self->sequencing_platform
    );

    # Prepare
    push @subclasses, 'PrepareInstrumentData';

    # Classify, Orient, Reports and Clean Up work w/ all mc16s builds
    push @subclasses, (qw/ Classify Orient Reports CleanUp /);

    return map { 'Genome::Model::Event::Build::MetagenomicComposition16s::'.$_ } @subclasses;
}

sub one_objects {
    return 1;
}

#< Hashify >#
sub _operation_params_as_hash {
    my ($self, $operation) = @_;

    my $method = $operation.'_params';
    my $params_string = $self->$method;
    return unless $params_string; # ok 

    my %params = Genome::Utility::Text::param_string_to_hash($params_string);
    unless ( %params ) { # not ok
        die $self->error_message("Malformed $operation params: $params_string");
    }

    return %params;
}

sub assembler_params_as_hash {
    return $_[0]->_operation_params_as_hash('assembler');
}

sub classifier_params_as_hash {
    return $_[0]->_operation_params_as_hash('classifier');
}

1;

