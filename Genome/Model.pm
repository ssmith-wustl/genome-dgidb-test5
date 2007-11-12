package Genome::Model;

use strict;
use warnings;

use above "Genome";
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;
use File::Path;
use File::Basename;

#UR::Object::Class->define(
class Genome::Model (
    class_name => 'Genome::Model',
    english_name => 'genome model',
    table_name => 'GENOME_MODEL',
    id_by => [
        id => { is => 'INT', len => 11 },
    ],
    has => [
        dna_type                => { is => 'VARCHAR', len => 64 },
        genotyper_name          => { is => 'VARCHAR', len => 255 },
        genotyper_params        => { is => 'VARCHAR', len => 255, is_optional => 1 },
        indel_finder_name       => { is => 'VARCHAR', len => 255, is_optional => 1 },
        indel_finder_params     => { is => 'VARCHAR', len => 255, is_optional => 1 },
        name                    => { is => 'VARCHAR', len => 255 },
        prior                   => { is => 'VARCHAR', len => 255, is_optional => 1 },
        read_aligner_name       => { is => 'VARCHAR', len => 255 },
        read_aligner_params     => { is => 'VARCHAR', len => 255, is_optional => 1 },
        read_calibrator_name    => { is => 'VARCHAR', len => 255, is_optional => 1 },
        read_calibrator_params  => { is => 'VARCHAR', len => 255, is_optional => 1 },
        reference_sequence_name => { is => 'VARCHAR', len => 255 },
        sample_name             => { is => 'VARCHAR', len => 255 },
        alignment_distribution_threshold => { is => 'VARCHAR', len => 255 },
    ],
    unique_constraints => [
        { properties => [qw/id/], sql => 'PRIMARY' },
    ],
    schema_name => 'Main',
    data_source => 'Genome::DataSource::Main',
);

sub base_parent_directory {
    "/gscmnt/sata114/info/medseq"
}

sub data_parent_directory {
    my $self = shift;
    return $self->base_parent_directory . "/model_data"
}

sub data_directory {
    my $self = shift;
    my $name = $self->name;
    
    return $self->data_parent_directory . '/' . $self->sample_name . "_" . $name;
}

sub pretty_print_text {
    my $self = shift;
    
    my @out;
    for my $prop (grep {$_ ne "name"} $self->property_names) {
        if (defined $self->$prop) {
            push @out, [
                Term::ANSIColor::colored($prop, 'red'),
                Term::ANSIColor::colored($self->$prop, "cyan")
            ]
        }
    }
    
    Genome::Model::EqualColumnWidthTableizer->new->convert_table_to_equal_column_widths_in_place( \@out );

    my $out;
    $out .= Term::ANSIColor::colored(sprintf("Model: %s (ID %s)", $self ->name, $self->id), 'bold magenta') . "\n\n";
    $out .= Term::ANSIColor::colored("Configured Properties:", 'red'). "\n";    
    $out .= join("\n", map { " @$_ " } @out);
    $out .= "\n\n";
    return $out;
}

sub sample_path{
    my $self = shift;
    
    return $self->data_parent_directory . $self->sample_name;
}


sub reference_sequence_path {
    my $self = shift;
    return sprintf('%s/reference_sequences/%s', $self->base_parent_directory,
						$self->reference_sequence_name)
}

sub lock_resource {
    my($self,%args) = @_;
    my $ret;
    my $resource_id = $self->data_directory . "/" . $args{'resource_id'} . ".lock";
    my $block_sleep = $args{block_sleep} || 10;
    my $max_try = $args{max_try} || 7200;

    while(! ($ret = mkdir $resource_id)) {
        return undef unless $max_try--;
        sleep $block_sleep;
    }

    eval "END { rmdir \$resource_id;}";

    return 1;
}

sub unlock_resource {
    my ($self, %args) = @_;
    
    my $resource_id = $self->data_directory . "/" . $args{'resource_id'} . ".lock";
    rmdir $resource_id;
}

sub get_subreference_paths {
    my $self = shift;
    my %p = @_;
    
    my $ext = $p{reference_extension};
    
    return glob(sprintf("%s/*.%s",
                        $self->reference_sequence_path,
                        $ext));
    
}

sub get_subreference_names {
    my $self = shift;
    my %p = @_;
    
    my $ext = $p{reference_extension};

    my @paths = $self->get_subreference_paths(reference_extension=>$ext);
    
    my @basenames = map {basename($_)} @paths;
    for (@basenames) {
        s/\.$ext$//;
    }
    
    return @basenames;    
}

sub resolve_accumulated_alignments_filename {
    my $self = shift;
    
    my %p = @_;
    my $refseq = $p{ref_seq_id};
    
    my $model_data_directory = $self->data_directory;
    
    my @subsequences = grep {$_ ne "all_sequences" } $self->get_subreference_names(reference_extension=>'bfa');
    
    if (@subsequences && !$refseq) {
        $self->error_message("there are multiple subsequences available, but you did not specify a refseq");
        return;
    } elsif (!@subsequences) {
        return $model_data_directory . "/alignments.submap/all_sequences.map";
    } else {
        return $model_data_directory . "/alignments.submap/" . $refseq . ".map";   
    }
}




1;
