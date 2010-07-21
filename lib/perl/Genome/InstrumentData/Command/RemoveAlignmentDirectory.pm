package Genome::InstrumentData::Command::RemoveAlignmentDirectory;

# ehvatum TODO: delete this file after a few weeks

#REVIEW fdu 11/20/2009
#1. Duplicate codes to get/set reference_build. Just pass
#reference_name to G::I::Alignment->create and let it to handle
#2. It is missing trimmer_name/version/params properties to handle
#trimmer options

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::RemoveAlignmentDirectory {
    is => 'Genome::InstrumentData::Command',
#   has => [
#       aligner_name => {
#           is => 'Text',
#           doc => 'The name of the aligner used to create alignment data',
#       },
#       reference_name => {
#           is => 'Text',
#           doc => 'The name of the reference sequence to which instrument data was aligned',
#       },
#   ],
#   has_optional => [
#       _alignment      => {
#           is => 'Genome::InstrumentData::Alignment'
#       },
#       reference_build => {
#           is => 'Genome::Model::Build::ReferencePlaceholder',
#           id_by => 'reference_name',
#       },
#       aligner_version => {
#           is => 'Text',
#           doc => 'The version of the aligner used to create alignment data',
#       },
#       aligner_params  => {
#           is => 'Text',
#           doc => 'any additional params for the aligner in a single string'
#       },
#   ],
#   doc => 'delete alignment data from the system',
};

sub create {
    shift->error_message(__PACKAGE__ . ' is thought to be dead code and has been commented out in preparation for deletion.  Email ehvatum@genome.wustl.edu if you want it back.');
    return;
}

#sub create {
#    my $class = shift;
#
#    my $self = $class->SUPER::create(@_);
#    return unless $self;
#
#    unless ($self->reference_build) {
#        unless ($self->reference_name) {
#            $self->error_message('No way to resolve reference build without reference_name or refrence_build');
#            return;
#        }
#        my $ref_build = Genome::Model::Build::ReferencePlaceholder->get($self->reference_name);
#        unless ($ref_build) {
#            $ref_build = Genome::Model::Build::ReferencePlaceholder->create(
#                                                                            name => $self->reference_name,
#                                                                            sample_type => $self->instrument_data->sample_type,
#                                                                        );
#        }
#        $self->reference_build($ref_build);
#    }
#
#    unless ($self->_alignment) {
#        my %create_params = (
#                             instrument_data => $self->instrument_data,
#                             reference_build => $self->reference_build,
#                             aligner_name => $self->aligner_name,
#                         );
#        if ($self->aligner_version) {
#            $create_params{'aligner_version'} = $self->aligner_version;
#        }
#        if ($self->aligner_params) {
#            $create_params{'aligner_params'} = $self->aligner_params;
#        }
#        my $alignment = Genome::InstrumentData::Alignment->create(%create_params);
#        unless ($alignment) {
#            $self->error_message('Failed to create an alignment with params: '. Data::Dumper::Dumper(%create_params));
#            return;
#        }
#        $self->_alignment($alignment);
#    }
#    return $self;
#}
#
#sub execute {
#    my $self = shift;
#
#    unless ($self->_alignment->remove_alignment_directory) {
#        $self->error_message('Failed to remove alignment directory '. $self->_alignment->alignment_directory);
#        return;
#    }
#    return 1;
#}

1;
