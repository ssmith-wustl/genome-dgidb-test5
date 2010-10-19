package Genome::FeatureList::Command::Create;

use strict;
use warnings;

use Genome;


class Genome::FeatureList::Command::Create {
    is => 'Genome::Command::Base',
    has_input => [
        name => { is => 'Text', doc => 'The name of the feature-list' },
        format => { is => 'Text', doc => 'Indicates whether the file follows the BED spec.', valid_values => Genome::FeatureList->__meta__->property('format')->valid_values },
    ],
    has_optional_input => [
        source => { is => 'Text', len => 64, doc => 'Provenance of this feature list. (e.g. Agilent)', },
        reference => { is => 'Genome::Model::Build::ImportedReferenceSequence', doc => 'reference sequence build for which the features apply' },
        subject => { is => 'Genome::Model::Build', doc => 'subject to which the features are relevant' },
        file_id => { is => 'Integer', doc => 'ID of the file storage for the BED file in LIMS (must supply this or file_name)' },
        file_path => { is => 'Text', doc => 'Path to the BED file on the file system (will be copied into an allocation) (must supply this or file_id)' },
        content_type => { is => 'Text', doc => 'the kind of information in the BED file' },
    ],
};

sub help_brief {
    "Create a new feature-list.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
 gmt feature-list create --name example-region --format true-BED --source WUGC
EOS
}

sub help_detail {                           
    return <<EOS 
Create a new feature-list.
EOS
}

sub execute {
    my $self = shift;

    unless($self->file_id or $self->file_path) {
        $self->error_message('Missing required parameter: must supply either file_id or file_path.');
        return;
    }

    if($self->file_id and $self->file_path) {
        $self->error_message('Conflicting parameters: must not supply both file_id and file_path.');
        return;
    }

    my %create_params = (
        name => $self->name,
        format => $self->format,
    );

    for my $property (qw(source reference subject content_type)) {
        my $value = $self->$property;
        $create_params{$property} = $value if $value; 
    }

    if($self->file_id) {
        my $temp_file = Genome::FeatureList->_resolve_lims_bed_file_for_file_id($self->file_id, $self->file_id);
        my $content_hash = Genome::Utility::FileSystem->md5sum($temp_file);
        $create_params{file_id} = $self->file_id;
        $create_params{file_content_hash} = $content_hash;
    } else {
        my $content_hash = Genome::Utility::FileSystem->md5sum($self->file_path);
        $create_params{file_path} = $self->file_path;
        $create_params{file_content_hash} = $content_hash;
    }

    my $feature_list = Genome::FeatureList->create( %create_params );

    unless($feature_list) {
        $self->error_message('Failed to create feature-list.');
        return;
    }

    return $feature_list;
}

1;
