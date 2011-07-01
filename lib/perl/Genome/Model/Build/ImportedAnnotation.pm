package Genome::Model::Build::ImportedAnnotation;

use strict;
use warnings;
use Carp;

use Genome;
use Sys::Hostname;
use File::Find;
use File::stat;
use File::Spec;

class Genome::Model::Build::ImportedAnnotation {
    is => 'Genome::Model::Build',
    has => [
        version => { 
            via => 'inputs',
            is => 'Text',
            to => 'value_id', 
            where => [ name => 'version', value_class_name => 'UR::Value'], 
            is_mutable => 1 
        },
        annotation_data_source_directory => {
            via => 'inputs',
            is => 'Text',
            to => 'value_id',
            where => [ name => 'annotation_data_source_directory', value_class_name => 'UR::Value' ],
            is_mutable => 1 
        },
        species_name => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'species_name', value_class_name => 'UR::Value' ],
            is_mutable => 1,
        },
        name => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'build_name', value_class_name => 'UR::Value' ],
            doc => "human meaningful name of this build",
            is_mutable => 1,
            is_many => 0,
        },
        calculated_name => {
            calculate_from => ['model_name','version'],
            calculate => q{ return "$model_name/$version"; },
        },
        reference_sequence_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'reference_sequence', value_class_name => 'Genome::Model::Build::ImportedReferenceSequence' ],
            is_many => 0,
            is_optional => 1, # TODO: make this non-optional when all data is updated
            is_mutable => 1,
            doc => 'id of the reference sequence build associated with this annotation model',
        },
        reference_sequence => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            id_by => 'reference_sequence_id',
        },
    ],
    has_optional => [
        tier_file_directory => {
            is => 'Path',
            calculate_from => ['data_directory'],
            calculate => q{return "$data_directory/annotation_data/tiering_bed_files";},
        },
        tier1_bed => {
            is => 'Path',
            calculate_from => ['tier_file_directory'],
            calculate => q{return "$tier_file_directory/tier1.bed";},
        },
        tier2_bed => {
            is => 'Path',
            calculate_from => ['tier_file_directory'],
            calculate => q{return "$tier_file_directory/tier2.bed";},
        },
        tier3_bed => {
            is => 'Path',
            calculate_from => ['tier_file_directory'],
            calculate => q{return "$tier_file_directory/tier3.bed";},
        },
        tier4_bed => {
            is => 'Path',
            calculate_from => ['tier_file_directory'],
            calculate => q{return "$tier_file_directory/tier4.bed";},
        },
        ucsc_conservation_directory => {
            is => 'Path',
            calculate_from => ['data_directory'],
            calculate => q{return "$data_directory/annotation_data/ucsc_conservation";},
        }
    ],
};

sub _select_build_from_model_input { undef; }

sub validate_for_start_methods {
    my $self = shift;
    my @methods = $self->SUPER::validate_for_start_methods;
    push @methods, 'check_reference_sequence';
    return @methods;
}

sub check_reference_sequence {
    my $self = shift;
    my @tags;

    # TODO: when having the reference_sequence parameter becomes mandatory, change all of this
    # to just generate an error if it is not defined or doesn't match the model instead.
    if (!defined $self->reference_sequence) {
        push @tags, UR::Object::Tag->create(
            type => 'warning',
            properties => ['reference_sequence'],
            desc => "ImportedAnnotation has no reference_sequence, this will soon be an error",
        );
    } elsif (defined $self->model->reference_sequence and $self->model->reference_sequence->id != $self->reference_sequence->model->id) {
        push @tags, UR::Object::Tag->create(
            type => 'error',
            properties => ['reference_sequence'],
            desc => "reference_sequence " . $self->reference_sequence->__display_name__ . " is not a build of model " .
                $self->model->reference_sequence->__display_name__ . " as expected."
        );
    }

    return @tags;
}

sub create {
    my $self = shift;
    my $build = $self->SUPER::create(@_);

    # Let's store the name as an input instead of relying on calculated properties
    $build->name($build->calculated_name) if $build;

    return $build;
}

# Checks to see if this build is compatible with the given imported reference sequence build (species and version match)
sub is_compatible_with_reference_sequence_build {
    # rsb: reference sequence build
    my ($self, $rsb) = @_;
    return if !defined $self->status || $self->status ne "Succeeded";

    return $rsb->is_compatible_with($self->reference_sequence) if defined $self->reference_sequence;

    my $version = $self->version;
    $version =~ s/^[^_]*_([0-9]+).*/$1/;
    return ($rsb->model->subject->species_name eq $self->model->subject->species_name) &&
        ($rsb->version eq $version);
}

# returns default location
sub determine_data_directory {
    my ($self) = @_;
    my @directories;
    my @composite_builds = $self->from_builds;
    if (@composite_builds) {
        for (@composite_builds) { 
            my @data_dirs = $_->determine_data_directory();
            return unless @data_dirs;
            push @directories, @data_dirs;
        }
    }
    else {
        if (-d $self->_annotation_data_directory) { 
            push @directories, $self->_annotation_data_directory;
        }
        else {
            $self->error_message("Could not find annotation data in " .
                $self->_annotation_data_directory);
            return;
        }
    }
    return @directories;
}

sub determine_merged_data_directory{
    my $self = shift;
    if (-d $self->_annotation_data_directory) { 
        return $self->_annotation_data_directory;
    }
    else {
        $self->error_message("Could not find annotation data in " .
                $self->_annotation_data_directory);
        return;
    }
}

# Returns transcript iterator object using default location
sub transcript_iterator{
    my $self = shift;
    my %p = @_;

    my $chrom_name = $p{chrom_name};

    my @composite_builds = $self->from_builds;
    if (@composite_builds){
        my @iterators = map {$_->transcript_iterator(chrom_name => $chrom_name)} @composite_builds;
        my %cached_transcripts;
        for (my $i = 0; $i < @iterators; $i++) {
            my $next = $iterators[$i]->next;
            $cached_transcripts{$i} = $next if defined $next;
        }

        my $iterator = sub {
            my $index;
            my $lowest;
            for (my $i = 0; $i < @iterators; $i++) {
                next unless exists $cached_transcripts{$i} and $cached_transcripts{$i} ne '';
                unless ($lowest){
                    $lowest = $cached_transcripts{$i};
                    $index = $i;
                }
                if ($self->transcript_cmp($cached_transcripts{$i}, $lowest) < 0) {
                    $index = $i;
                    $lowest = $cached_transcripts{$index};
                }
            }
            unless (defined $index){
                #here we have exhausted both iterators
                return undef;
            }
            my $next_cache =  $iterators[$index]->next();
            $next_cache ||= '';
            $cached_transcripts{$index} = $next_cache;
            return $lowest;
        };

        bless $iterator, "Genome::Model::ImportedAnnotation::Iterator";
        return $iterator;
    }else{
        # Since this is not a composite build, don't have to worry about multiple results from determine data directory
        my ($data_dir) = $self->determine_data_directory();
        unless (defined $data_dir) {
            $self->error_message("Could not determine data directory for transcript iterator");
            return;
        }

        if ($chrom_name){
            return Genome::Transcript->create_iterator(where => [data_directory => $data_dir, chrom_name => $chrom_name]);
        }
        else {
            return Genome::Transcript->create_iterator(where => [data_directory => $data_dir]);
        }
    }
}

# Compare 2 transcripts by chromosome, start position, and transcript id
sub transcript_cmp {
    my $self = shift;
    my ($cached_transcript, $lowest) = @_;

    # Return the result of the chromosome comparison unless its a tie
    unless (($cached_transcript->chrom_name cmp $lowest->chrom_name) == 0) {
        return ($cached_transcript->chrom_name cmp $lowest->chrom_name);
    }

    # Return the result of the start position comparison unless its a tie
    unless (($cached_transcript->transcript_start <=> $lowest->transcript_start) == 0) {
        return ($cached_transcript->transcript_start <=> $lowest->transcript_start);
    }

    # Return the transcript id comparison result as a final tiebreaker
    return ($cached_transcript->transcript_id <=> $lowest->transcript_id);
}

# Location of annotation data in build directory
sub _annotation_data_directory{
    my $self = shift;
    return $self->data_directory . "/annotation_data";
}

sub _resolve_annotation_file_name {
    my $self = shift;
    my $file_type = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    unless (defined($reference_sequence_id)) {
        unless ($self->reference_sequence_id) {
            die('There is no reference sequence build associated with imported annotation build: '. $self->id);
        }
        $reference_sequence_id = $self->reference_sequence_id;
    }
    my $file_name = $self->_annotation_data_directory .'/'. $reference_sequence_id .'-'. $file_type .'.'. $suffix;
    return $file_name;
}

sub annotation_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to annotation_file method in '.  __PACKAGE__);
    }

    my $file_name = $self->_resolve_annotation_file_name('all_sequences',$suffix,$reference_sequence_id);
    if (-f $file_name) {
        return $file_name;
    }
    # TODO: Once we have perl5.12.1 or perl5.10.1 working, this command can be removed and replaced with in-line code to generate the file
    my %params = (
        anno_db => $self->model_name,
        version => $self->version,
        output_file => $file_name,
        reference_build_id => $reference_sequence_id,
        # TODO: Can this be determined by the default in G:M:T:Picard?
        picard_version => '1.36',
        species => $self->species_name,
        output_format => $suffix,
    );
    my $dump = Genome::Model::Tools::Annotate::ReferenceGenome->create(%params);
    unless ($dump) {
        die('Failed to create command for generating the annotation file with params: '. Data::Dumper::Dumper(%params));
    }
    unless ($dump->execute) {
        die('Failed to execute command for generating the annotation file with params: '. Data::Dumper::Dumper(%params));
    }
    unless (-f $file_name) {
        die('Failed to find annotation file: '. $file_name);
    }
}

sub rRNA_MT_pseudogene_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_MT_pseudogene_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA_MT_pseudogene',$suffix,$reference_sequence_id);
    if (-f $file_name) {
        return $file_name;
    }
    #TODO: Need a method or tool to generate the rRNA_MT_pseudogene file on the fly
    #Or just generate the rRNA, MT, and pseudogene files below and merge...
    return;
}

sub rRNA_MT_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_MT_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA_MT',$suffix,$reference_sequence_id);
    if (-f $file_name) {
        return $file_name;
    }
    #TODO: Need a method or tool to generate the rRNA_MT file on the fly
    #Or just generate the rRNA and MT files below and merge...
    return;
}

sub rRNA_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA',$suffix,$reference_sequence_id);
    if (-f $file_name) {
        return $file_name;
    }
    #TODO: Need a method or tool to generate the rRNA file on the fly
    return;
}

sub MT_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA',$suffix,$reference_sequence_id);
    if (-f $file_name) {
        return $file_name;
    }
    #TODO: Need a method or tool to generate the rRNA file on the fly
    return;
}

sub pseudogene_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    unless ($suffix) {
        die('Must provide file suffix as parameter to pseudogene_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('pseudogene',$suffix,$reference_sequence_id);
    if (-f $file_name) {
        return $file_name;
    }
    #TODO: Need a method or tool to generate the pseudogene file on the fly
    return;
}

sub tiering_bed_files_by_version {
    my $self = shift;
    my $version = shift;
    unless(defined($version)){
        die $self->error_message("You must specify a version if you wish to obtain tiering_bed_files by version!");
    }
    return $self->data_directory."/annotation_data/tiering_bed_files_v".$version;
}

package Genome::Model::ImportedAnnotation::Iterator;
our @ISA = ('UR::Object::Iterator');

sub next {
    my $self = shift;
    return $self->();
}

1;
