package Genome::Sample::Command::Attribute::Import;

use strict;
use warnings;

use Genome;

class Genome::Sample::Command::Attribute::Import {
    is => 'Genome::Command::Base',
    has => [
        file => {
            is => 'FilePath',
            doc => 'A delimited file of two or more columns.',
        },
        nomenclature => {
            is => 'Text',
            doc => 'The source of the information',
            default_value => 'WUGC',
        },
    ],
    has_optional => [
        delimiter => {
            is => 'Text',
            doc => 'The separator for the columns of each row (defaults to a tab).',
            default_value => "\t",
        },
        prefix => {
            is => 'Text',
            doc => 'Some text to prepend to the idenitifiers in the first column',
        },
    ]
};

sub help_brief {
    "Add attributes to a sample en masse.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
 genome sample attribute import
EOS
}

sub help_detail {                           
    return <<EOS 
Add a set of attributes to many samples at once.  The first column should be an identifier for the sample or individual.
(If an individual is provided all samples for that individual will be updated.)  The optional --prefix parameter will be
prepended to each identifier in this column before looking for a matching object.  Looking by name or id is currently supported

The remaining columns should be the values of the attributes to update.  The first row is treated as a header containing
the names of the attributes to be added.  (The header for the identifer column is ignored.)
EOS
}

sub execute {
    my $self = shift;

    my $attribute_file = $self->file;
    unless(Genome::Utility::FileSystem->check_for_path_existence($attribute_file)) {
        $self->error_message('File ' . $attribute_file . ' could not be found.');
        return;
    }

    my $attribute_fh = Genome::Utility::FileSystem->open_file_for_reading($attribute_file);
    unless($attribute_fh) {
        $self->error_message('Failed to open attribute file ' . $attribute_file . ' for reading.');
        return;
    }

    my $delimiter = $self->delimiter;
    unless(defined $delimiter and $delimiter ne '') {
        $self->error_message('Cannot use empty or null delimiter.');
        return;
    }

    my $header_line = <$attribute_fh>;
    chomp $header_line;
    my ($id_header, @names) = split($delimiter, $header_line);

    unless(scalar @names) {
        $self->error_message('No attribute names specified.');
        return;
    }

    my $nomenclature = $self->nomenclature;

    while( my $line = <$attribute_fh>) {
        chomp $line;
        my ($id, @values) = split($delimiter, $line);

        unless(scalar @values eq scalar @names) {
            $self->error_message('Number of values does not match number of attribute names found! Line:' . "\n" . $line);
            die $self->error_message;
        }

        my @samples = $self->_resolve_samples($id);
        unless(@samples) {
            die $self->error_message;
        }

        for my $sample (@samples) {
            for my $i (0..$#names) {
                my $attribute_add_command = Genome::Sample::Command::Attribute::Add->create(
                    sample => $sample,
                    name => $names[$i],
                    value => $values[$i],
                    nomenclature => $nomenclature,
                );
                unless($attribute_add_command->execute) {
                    $self->error_message('Failed to add attribute' . $names[$i] . ' for ' . $id);
                    die $self->error_message;
                }
            }
        }
    }

    return 1;
}

sub _resolve_samples {
    my $self = shift;
    my $identifier = shift;

    if($self->prefix) {
        $identifier = $self->prefix . $identifier;
    }

    my $sample_by_name = Genome::Sample->get(name => $identifier);
    return $sample_by_name if $sample_by_name;

    my $individual_by_name = Genome::Individual->get(name => $identifier);
    return $individual_by_name->samples if $individual_by_name;

    my $sample_by_id;
    eval { #can fail if datatypes mismatch
        $sample_by_id = Genome::Sample->get($identifier);
    };
    return $sample_by_id if $sample_by_id;

    my $individual_by_id;
    eval {
        $individual_by_id = Genome::Individual->get($identifier);
    };
    return $individual_by_id->samples if $individual_by_id;

    $self->error_message('Could not identify a Sample or Individual for identifier ' . $identifier);
    return;
}

1;
