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
    my $squashed = shift;

    unless (defined($reference_sequence_id)) {
        unless ($self->reference_sequence_id) {
            die('There is no reference sequence build associated with imported annotation build: '. $self->id);
        }
        $reference_sequence_id = $self->reference_sequence_id;
    }
    if ($squashed) {
        $file_type .= '-squashed';
    }
    my $file_name = $self->_rna_annotation_directory .'/'. $reference_sequence_id .'-'. $file_type .'.'. $suffix;
    return $file_name;
}

sub _rna_annotation_directory {
    my $self = shift;
    return $self->_annotation_data_directory . '/rna_annotation';
}

sub generate_transcript_info_file {
    my $self = shift;
    my $reference_sequence_id = shift;

    my $file_name = $self->_resolve_annotation_file_name('transcript_info','tsv',$reference_sequence_id);
    unless (-e $file_name) {
        my $version = $self->version;
        $version =~ s/(_v\d+)$//;
        my $species_name = $self->species_name;
        if ($species_name eq 'human') {
            $species_name = 'homo_sapiens';
        }
        my %params = (
            reference_build_id => $reference_sequence_id,
            transcript_info_file => $file_name,
            species => $species_name,
            use_version => $version,
        );
        my $transcript_info = Genome::Model::Tools::Ensembl::TranscriptInfo->create(%params);
        unless ($transcript_info) {
            die('Failed to load transcript info gmt command with params: '. Data::Dumper::Dumper(%params));
        }
        unless ($transcript_info->execute) {
            die('Failed to execute gmt command: '. $transcript_info->command_name);
        }
        unless (-e $file_name) {
            die('The gmt command ran but the file does not exist: '. $file_name);
        }
    }
    unless (-s $file_name){
        die('The transcript_info file exists, but has no size: ' . $file_name);
    }
    return $file_name;
}

sub transcript_info_file {
    my $self = shift;
    my $reference_sequence_id = shift;
    my $file_name = $self->_resolve_annotation_file_name('transcript_info','tsv',$reference_sequence_id);
    if (-s $file_name){
        return $file_name;
    }
    return undef;
}

sub transcript_info_reader {
    my $self = shift;
    my $reference_sequence_id = shift;

    my $transcript_info_file = $self->transcript_info_file($reference_sequence_id);
    my $transcript_info_reader = Genome::Utility::IO::SeparatedValueReader->create(
        separator => "\t",
        input => $transcript_info_file,
    );
    unless ($transcript_info_reader) {
        die('Failed to load transcript info file: '. $transcript_info_file);
    }
    return $transcript_info_reader;
}

sub generate_annotation_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to annotation_file method in '.  __PACKAGE__);
    }

    my $file_name = $self->_resolve_annotation_file_name('all_sequences',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }
    if ($suffix eq 'gtf') {
        if ($squashed) {
            die('Support for squashed representations of GTF files is not supported!');
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
    } elsif ($suffix eq 'bed') {
        if ($squashed) {
            # Get the un-squashed BED file path
            my $bed_path = $self->annotation_file('bed',$reference_sequence_id,0);
            my $tmp_file = Genome::Sys->create_temp_file_path;
            unless (Genome::Model::Tools::BedTools::MergeBy->execute(
                input_file => $bed_path,
                output_file => $tmp_file,
            )) {
                $self->error_message('Failed to squash the annotation by gene: '. $bed_path);
            }
            # Remove the long names created by MergeBy and replace with gene and 'squashed' as the transcript name 
            $self->remove_long_squashed_bed_names($tmp_file,$file_name);
        } else {
            #This is not just a gtf file converted to bed, but rather limited to only exon feature types to remove CDS redundancy
            my $gtf_path = $self->annotation_file('gtf',$reference_sequence_id);
            $self->_convert_gtf_to_bed($gtf_path,$file_name);
        }
    }
    unless (-f $file_name) {
        die('Failed to find annotation file: '. $file_name);
    }
    unless (-s $file_name){
        die('Annotation file exists but has no size: ' . $file_name);
    }
    return $file_name;
}

sub remove_long_squashed_bed_names {
    my $self = shift;
    # Input file
    my $tmp_file = shift;
    # Output file
    my $file_name = shift;

    my @headers = qw/chr start end name/;
    my $reader = Genome::Utility::IO::SeparatedValueReader->create(
        input => $tmp_file,
        separator => "\t",
        headers => \@headers,
    );
    my $writer = Genome::Utility::IO::SeparatedValueWriter->create(
        output => $file_name,
        separator => "\t",
        headers => $reader->headers,
        print_headers => 0,
    );
    while (my $data = $reader->next) {
        my $names = $data->{name};
        my @names = split(';',$names);
        my $name = $names[0];
        my ($gene) = split(':',$name);
        $data->{name} = $gene .':squashed:exon:na:na';
        $writer->write_one($data);
    }
    return 1;
}

sub annotation_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to annotation_file method in '.  __PACKAGE__);
    }

    my $file_name = $self->_resolve_annotation_file_name('all_sequences',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }
    return undef;
}

sub generate_RNA_annotation_files {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless(-e $self->_rna_annotation_directory){
        Genome::Sys->create_directory($self->_rna_annotation_directory);
    }
    
    unless ($self->transcript_info_file($reference_sequence_id)) {
        my $status = $self->generate_transcript_info_file($reference_sequence_id);
        unless ($status) {
            warn('Failed to generate transcript_info_file for '. $self->id .' and reference '. $reference_sequence_id);
        }
    }
    my @types = qw/annotation rRNA rRNA_protein MT pseudogene rRNA_MT rRNA_MT_pseudogene/;
    for my $type (@types) {
        my $accessor_method = $type .'_file';
        my $generate_method = 'generate_'. $type .'_file';
        unless ($self->$accessor_method($suffix,$reference_sequence_id,$squashed)) {
            my $status = $self->$generate_method($suffix,$reference_sequence_id,$squashed);
            unless ($status) {
                warn('Failed to generate '. $generate_method .' for '. $self->id .' and reference '. $reference_sequence_id);
            }
        }
    }
    return 1;
}


sub generate_rRNA_MT_pseudogene_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_MT_pseudogene_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA_MT_pseudogene',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }

    my $rRNA_file = $self->rRNA_file($suffix,$reference_sequence_id,$squashed);
    my $MT_file = $self->MT_file($suffix,$reference_sequence_id,$squashed);
    my $pseudo_file = $self->pseudogene_file($suffix,$reference_sequence_id,$squashed);

    my @input_files = ($rRNA_file,$MT_file,$pseudo_file);
    if ($suffix eq 'gtf') {
        if ($squashed) {
            die('Support for squashed representations of GTF files is not supported!');
        }
        unless (Genome::Model::Tools::Gtf::Cat->execute(
            input_files => \@input_files,
            output_file => $file_name,
            remove_originals => 0,
        )) {
            die('Failed to merge GTF files: '. Data::Dumper::Dumper(@input_files));
        }
    } elsif ($suffix eq 'bed') {
        if ($squashed) {
            # Get the un-squashed BED file path
            my $bed_path = $self->rRNA_MT_file('bed',$reference_sequence_id,0);
            my $tmp_file = Genome::Sys->create_temp_file_path;
            unless (Genome::Model::Tools::BedTools::MergeBy->execute(
                input_file => $bed_path,
                output_file => $tmp_file,
            )) {
                $self->error_message('Failed to squash the annotation by gene: '. $bed_path);
            }
            # Remove the long names created by MergeBy and replace with gene and 'squashed' as the transcript name 
            $self->remove_long_squashed_bed_names($tmp_file,$file_name);
        } else {
            #This is not just a gtf file converted to bed, but rather limited to only exon feature types to remove CDS redundancy
            my $gtf_path = $self->rRNA_MT_file('gtf',$reference_sequence_id,0);
            $self->_convert_gtf_to_bed($gtf_path,$file_name);
        }
    }

    unless (Genome::Model::Tools::BedTools::Sort->execute(
        input_file => $file_name,
    )) {
        die('Failed to sort file: '. $file_name);
    }
    unless (-s $file_name){
        die('rRNA_MT_pseudogene file exists but has no size: ' . $file_name);
    }
    return $file_name;
}

sub rRNA_MT_pseudogene_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;
    
    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_MT_pseudogene_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA_MT_pseudogene',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }
    return undef;
}

sub generate_rRNA_MT_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;
    
    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_MT_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA_MT',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }

    my $rRNA_file = $self->rRNA_file($suffix,$reference_sequence_id,$squashed);
    my $MT_file = $self->MT_file($suffix,$reference_sequence_id,$squashed);

    my @input_files = ($rRNA_file,$MT_file);
    if ($suffix eq 'gtf') {
        if ($squashed) {
            die('Support for squashed representations of GTF files is not supported!');
        }
        unless (Genome::Model::Tools::Gtf::Cat->execute(
            input_files => \@input_files,
            output_file => $file_name,
            remove_originals => 0,
        )) {
            die('Failed to merge GTF files: '. Data::Dumper::Dumper(@input_files));
        }
    } elsif ($suffix eq 'bed') {
        if ($squashed) {
            # Get the un-squashed BED file path
            my $bed_path = $self->rRNA_MT_file('bed',$reference_sequence_id,0);
            my $tmp_file = Genome::Sys->create_temp_file_path;
            unless (Genome::Model::Tools::BedTools::MergeBy->execute(
                input_file => $bed_path,
                output_file => $tmp_file,
            )) {
                $self->error_message('Failed to squash the annotation by gene: '. $bed_path);
            }
            # Remove the long names created by MergeBy and replace with gene and 'squashed' as the transcript name 
            $self->remove_long_squashed_bed_names($tmp_file,$file_name);
        } else {
            #This is not just a gtf file converted to bed, but rather limited to only exon feature types to remove CDS redundancy
            my $gtf_path = $self->rRNA_MT_file('gtf',$reference_sequence_id,0);
            $self->_convert_gtf_to_bed($gtf_path,$file_name);
        }
    }

    unless (Genome::Model::Tools::BedTools::Sort->execute(
        input_file => $file_name,
    )) {
        die('Failed to sort file: '. $file_name);
    }
    unless (-s $file_name){
        die('rRNA_MT file exists but has no size: ' . $file_name);
    }
    return $file_name;
}

sub rRNA_MT_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;
    
    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_MT_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA_MT',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }
    return undef;
}

sub generate_rRNA_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_coding_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA',$suffix,$reference_sequence_id,$squashed);

    # Make sure the files do not already exist
    if (-s $file_name) {
        die('Annotation file '. $file_name .' already exists!');
    }

    #Generate the requested file type
    if ($suffix eq 'gtf') {
        if ($squashed) {
            die('Support for squashed representations of GTF files is not supported!');
        }

        my $transcript_info_reader = $self->transcript_info_reader($reference_sequence_id);
        my %rRNA;
        while (my $transcript_data = $transcript_info_reader->next) {
            if ( ($transcript_data->{gene_biotype} =~ /^rRNA/) ||
                     ($transcript_data->{transcript_biotype} =~ /^rRNA/)) {
                $rRNA{$transcript_data->{ensembl_transcript_id}} = $transcript_data;
            }
        }
        my @rRNA_ids = keys %rRNA;
        my $annotation_file = $self->annotation_file($suffix,$reference_sequence_id);
        unless (Genome::Model::Tools::Gtf::Limit->execute(
            input_gtf_file => $annotation_file,
            output_gtf_file => $file_name,
            ids => \@rRNA_ids,
            id_type => 'transcript_id',
        )) {
            die('Failed to execute GTF limit tool for coding rRNA!');
        }
    } elsif ($suffix eq 'bed') {
        if ($squashed) {
            # Get the un-squashed BED file path
            my $bed_path = $self->rRNA_file('bed',$reference_sequence_id,0);
            my $tmp_file = Genome::Sys->create_temp_file_path;
            unless (Genome::Model::Tools::BedTools::MergeBy->execute(
                input_file => $bed_path,
                output_file => $tmp_file,
            )) {
                $self->error_message('Failed to squash the annotation by gene: '. $bed_path);
            }
            # Remove the long names created by MergeBy and replace with gene and 'squashed' as the transcript name 
            $self->remove_long_squashed_bed_names($tmp_file,$file_name);
        } else {
            #This is not just a gtf file converted to bed, but rather limited to only exon feature types to remove CDS redundancy
            my $gtf_path = $self->rRNA_file('gtf',$reference_sequence_id,0);
            $self->_convert_gtf_to_bed($gtf_path,$file_name);
        }
    }
    unless (Genome::Model::Tools::BedTools::Sort->execute(
        input_file => $file_name,
    )) {
        die('Failed to sort file: '. $file_name);
    }
    unless (-s $file_name){
        die('rRNA file exists but has no size: ' . $file_name);
    }
    return $file_name;
}


sub rRNA_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }
    return undef;
}

sub generate_rRNA_protein_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_coding_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA_protein',$suffix,$reference_sequence_id,$squashed);

    # Make sure the files do not already exist
    if (-s $file_name) {
        die('Annotation file '. $file_name .' already exists!');
    }

    #Generate the requested file type
    if ($suffix eq 'gtf') {
        if ($squashed) {
            die('Support for squashed representations of GTF files is not supported!');
        }
        # Load a list of ribosomal gene names and ids
        # This is a manually curated list
        my $ribosomal_file = $self->_annotation_data_directory .'/RibosomalGeneNames.txt';
        unless (-e $ribosomal_file) {
            die('This is the last step requiring automation.  You must provide a list of gene_names(column1) and ensembl_gene_ids(column2) in this location (see Genome::Model::Event::Build::ImportedAnnotation::CopyRibosomalGeneNames): '. $ribosomal_file);
        }
        my %ribo_names;
        my %ribo_ids;
        open (RIBO, $ribosomal_file) || die "\n\nCould not load ribosomal gene ids: $ribosomal_file\n\n";
        while(<RIBO>){
            chomp($_);
            my @line=split("\t", $_);
            $ribo_names{$line[0]}=1;
            $ribo_ids{$line[1]}=1;
        }
        close(RIBO);

        my $transcript_info_reader = $self->transcript_info_reader($reference_sequence_id);
        my %rRNA_protein;
        while (my $transcript_data = $transcript_info_reader->next) {
            if ( ($transcript_data->{gene_biotype} =~ /rRNA/) ||
                     ($transcript_data->{transcript_biotype} =~ /rRNA/)) {
                next;
            } elsif ( ($ribo_names{$transcript_data->{gene_name}}) ||
                          ($ribo_ids{$transcript_data->{ensembl_gene_id}}) ) {
                $rRNA_protein{$transcript_data->{ensembl_transcript_id}} = $transcript_data;
            }
        }
        my @protein_ids = keys %rRNA_protein;
        my $annotation_file = $self->annotation_file($suffix,$reference_sequence_id);
        unless (Genome::Model::Tools::Gtf::Limit->execute(
            input_gtf_file => $annotation_file,
            output_gtf_file => $file_name,
            ids => \@protein_ids,
            id_type => 'transcript_id',
        )) {
            die('Failed to execute GTF limit tool for rRNA_protein!');
        }
    } elsif ($suffix eq 'bed') {
        if ($squashed) {
            # Get the un-squashed BED file path
            my $bed_path = $self->rRNA_protein_file('bed',$reference_sequence_id,0);
            my $tmp_file = Genome::Sys->create_temp_file_path;
            unless (Genome::Model::Tools::BedTools::MergeBy->execute(
                input_file => $bed_path,
                output_file => $tmp_file,
            )) {
                $self->error_message('Failed to squash the annotation by gene: '. $bed_path);
            }
            # Remove the long names created by MergeBy and replace with gene and 'squashed' as the transcript name 
            $self->remove_long_squashed_bed_names($tmp_file,$file_name);
        } else {
            #This is not just a gtf file converted to bed, but rather limited to only exon feature types to remove CDS redundancy
            my $gtf_path = $self->rRNA_protein_file('gtf',$reference_sequence_id,0);
            $self->_convert_gtf_to_bed($gtf_path,$file_name);
        }
    }
    unless (Genome::Model::Tools::BedTools::Sort->execute(
        input_file => $file_name,
    )) {
        die('Failed to sort file: '. $file_name);
    }
    unless (-s $file_name){
        die('rRNA_protein file exists but has no size: ' . $file_name);
    }
    return $file_name;
}

sub rRNA_protein_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to rRNA_protein_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('rRNA_protein',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }
    return undef;
}

sub generate_MT_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to MT_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('MT',$suffix,$reference_sequence_id,$squashed);
    if (-f $file_name) {
        return $file_name;
    }
    if ($suffix eq 'gtf') {
        if ($squashed) {
            die('Support for squashed representations of GTF files is not supported!');
        }
        my $transcript_info_reader = $self->transcript_info_reader($reference_sequence_id);
        my %MT_transcripts;
        while (my $transcript_data = $transcript_info_reader->next) {
            if ( ($transcript_data->{gene_biotype} =~ /MT/i) ||
                     ($transcript_data->{transcript_biotype} =~ /MT/i) ||
                         ($transcript_data->{seq_region_name} =~ /^MT$/i)  ) {
                $MT_transcripts{$transcript_data->{ensembl_transcript_id}} = $transcript_data;
            }
        }
        my @ids = keys %MT_transcripts;
        my $annotation_file = $self->annotation_file($suffix,$reference_sequence_id);
        my $limit = Genome::Model::Tools::Gtf::Limit->create(
            input_gtf_file => $annotation_file,
            output_gtf_file => $file_name,
            ids => \@ids,
            id_type => 'transcript_id',
        );
        unless ($limit) {
            die('Failed to create GTF limit tool!');
        }
        unless ($limit->execute) {
            die('Failed to execute GTF limit tool!');
        }
    } elsif ($suffix eq 'bed') {
        if ($squashed) {
            # Get the un-squashed BED file path
            my $bed_path = $self->MT_file('bed',$reference_sequence_id,0);
            my $tmp_file = Genome::Sys->create_temp_file_path;
            unless (Genome::Model::Tools::BedTools::MergeBy->execute(
                input_file => $bed_path,
                output_file => $tmp_file,
            )) {
                $self->error_message('Failed to squash the annotation by gene: '. $bed_path);
            }
            # Remove the long names created by MergeBy and replace with gene and 'squashed' as the transcript name 
            $self->remove_long_squashed_bed_names($tmp_file,$file_name);
        } else {
            #This is not just a gtf file converted to bed, but rather limited to only exon feature types to remove CDS redundancy
            my $gtf_path = $self->MT_file('gtf',$reference_sequence_id,0);
            $self->_convert_gtf_to_bed($gtf_path,$file_name);
        }
    }

    unless (Genome::Model::Tools::BedTools::Sort->execute(
        input_file => $file_name,
    )) {
        die('Failed to sort file: '. $file_name);
    }
    unless (-s $file_name){
        die('MT file exists but has no size: ' . $file_name);
    }
    return $file_name;
}

sub MT_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to MT_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('MT',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }
    return undef;
}

sub generate_pseudogene_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to pseudogene_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('pseudogene',$suffix,$reference_sequence_id,$squashed);
    if (-f $file_name) {
        return $file_name;
    }

    if ($suffix eq 'gtf') {
        if ($squashed) {
            die('Support for squashed representations of GTF files is not supported!');
        }
        my $transcript_info_reader = $self->transcript_info_reader($reference_sequence_id);
        my %pseudo_transcripts;
        while (my $transcript_data = $transcript_info_reader->next) {
            if ( ($transcript_data->{gene_biotype} =~ /pseudogene/) ||
                     ($transcript_data->{transcript_biotype} =~ /pseudogene/)  ) {
                $pseudo_transcripts{$transcript_data->{ensembl_transcript_id}} = $transcript_data;
            }
        }
        my @ids = keys %pseudo_transcripts;
        my $annotation_file = $self->annotation_file($suffix,$reference_sequence_id);
        my $limit = Genome::Model::Tools::Gtf::Limit->create(
            input_gtf_file => $annotation_file,
            output_gtf_file => $file_name,
            ids => \@ids,
            id_type => 'transcript_id',
        );
        unless ($limit) {
            die('Failed to create GTF limit tool!');
        }
        unless ($limit->execute) {
            die('Failed to execute GTF limit tool!');
        }
    } elsif ($suffix eq 'bed') {
        if ($squashed) {
            # Get the un-squashed BED file path
            my $bed_path = $self->pseudogene_file('bed',$reference_sequence_id,0);
            my $tmp_file = Genome::Sys->create_temp_file_path;
            unless (Genome::Model::Tools::BedTools::MergeBy->execute(
                input_file => $bed_path,
                output_file => $tmp_file,
            )) {
                $self->error_message('Failed to squash the annotation by gene: '. $bed_path);
            }
            # Remove the long names created by MergeBy and replace with gene and 'squashed' as the transcript name 
            $self->remove_long_squashed_bed_names($tmp_file,$file_name);
        } else {
            #This is not just a gtf file converted to bed, but rather limited to only exon feature types to remove CDS redundancy
            my $gtf_path = $self->pseudogene_file('gtf',$reference_sequence_id,0);
            $self->_convert_gtf_to_bed($gtf_path,$file_name);
        }
    }

    unless (Genome::Model::Tools::BedTools::Sort->execute(
        input_file => $file_name,
    )) {
        die('Failed to sort file: '. $file_name);
    }
    unless (-s $file_name){
        die('pseudogene file exists but has no size: ' . $file_name);
    }
    return $file_name;
}

sub pseudogene_file {
    my $self = shift;
    my $suffix = shift;
    my $reference_sequence_id = shift;
    my $squashed = shift;

    unless ($suffix) {
        die('Must provide file suffix as parameter to pseudogene_file method in '.  __PACKAGE__);
    }
    my $file_name = $self->_resolve_annotation_file_name('pseudogene',$suffix,$reference_sequence_id,$squashed);
    if (-s $file_name) {
        return $file_name;
    }
    return undef;
}

sub _convert_gtf_to_bed {
    my $self = shift;
    my $gtf_path = shift;
    my $bed_path = shift;

    my $exon_only_tmp_file = Genome::Sys->create_temp_file_path;
    unless (Genome::Model::Tools::Gtf::Limit->execute(
        input_gtf_file => $gtf_path,
        output_gtf_file => $exon_only_tmp_file,
        feature_type => 'exon',
    )) {
        $self->error_message('Failed to generate an exon only GTF version of: '. $gtf_path);
        die($self->error_message);
    }
    unless (Genome::Model::Tools::RefCov::GtfToBed->execute(
        bed_file => $bed_path,
        gff_file => $exon_only_tmp_file,
    )) {
        $self->error_message('Failed to generate a BED format file: '. $bed_path);
        die($self->error_message);
    }
    return 1;
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
