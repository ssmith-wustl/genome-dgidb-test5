package Genome::Model::Build::ReferenceSequence;
use strict;
use warnings;
use Genome;

require Carp;
use Regexp::Common;
use POSIX;

class Genome::Model::Build::ReferenceSequence {
    is => 'Genome::Model::Build',
    has => [
        # these come from the model, and do not change (and compose its name)
        prefix => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'prefix', value_class_name => 'UR::Value' ],
            doc => 'The source of the sequence (such as NCBI).  May not contain spaces.',
            is_mutable => 1,
            is_many => 0,
            is_optional => 1,
        },
        species_name => {
            via => 'model',
            to => 'subject_name',
        },
        desc => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'desc', value_class_name => 'UR::Value' ],
            doc => 'The source of the sequence (such as NCBI).  May not contain spaces.',
            is_mutable => 1,
            is_many => 0,
            is_optional => 1,
        },      

        # these change with each version
        version => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'version', value_class_name => 'UR::Value' ],
            doc => 'Identifies the version of the reference sequence.  This string may not contain spaces.',
            is_mutable => 1,
            is_many => 0,
            is_optional => 1,
        },
        fasta_file => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'fasta_file', value_class_name => 'UR::Value' ],
            doc => "fully qualified fasta filename to copy to all_sequences.fa in the build's data_directory.",
            is_mutable => 1,
            is_many => 0,
        },
        assembly_name => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'assembly_name', value_class_name => 'UR::Value' ],
            doc => "publicly available URI to the sequence file for the fasta",
            is_mutable => 1,
            is_many => 0,
            is_optional => 1,
        },
        sequence_uri => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'sequence_uri', value_class_name => 'UR::Value' ],
            doc => "publicly available URI to the sequence file for the fasta",
            is_mutable => 1,
            is_many => 0,
            is_optional => 1,
        },
        generate_sequence_uri => {
            is => 'Boolean',
            is_transient => 1,
            is_optional => 1,
            default_value => 0,
        },

        header_version => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'header_version', value_class_name => 'UR::Value' ],
            doc => "header revision for the reference build (in case headers changed)",
            is_mutable => 1,
            is_many => 0,
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

        # calculated from other properties
        calculated_name => {
            calculate_from => ['model_name','version'],
            calculate => q{
                my $name = "$model_name-build";
                $name .= $version if defined $version;
                $name =~ s/\s/-/g;
                return $name;
            },
        },
        manifest_file_path => {
            is => 'Text',
            calculate_from => ['data_directory'],
            calculate => q(
                if($data_directory){
                    return join('/', $data_directory, 'manifest.tsv');
                }
            ),
        },   

        # optional to allow builds to indicate that they are derived from another build
        derived_from_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'derived_from', value_class_name => 'Genome::Model::Build::ReferenceSequence' ],
            doc => 'Identifies the parent build from which this one is derived, if any.',
            is_mutable => 1,
            is_many => 0,
            is_optional => 1,
        },
        derived_from => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            id_by => 'derived_from_id',
        },

        # optional to allow builds to indicate that are on the same coordinate system as another build, but
        # is not a direct derivation of it. derived from implies coordinates_from, so you don't need to use both.
        coordinates_from_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'coordinates_from', value_class_name => 'Genome::Model::Build::ReferenceSequence' ],
            doc => 'Used to indicate that this build is on the same coordinate system as another.',
            is_mutable => 1,
            is_many => 0,
            is_optional => 1,
        },
        coordinates_from => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            id_by => 'coordinates_from_id',
        },

        append_to_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'append_to', value_class_name => 'Genome::Model::Build::ReferenceSequence' ],
            doc => 'If specified, the created reference will be logically appended to the one specified by this parameter for aligners that support it.',
            is_mutable => 1,
            is_many => 1,
            is_optional => 1,
        },
        append_to => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            id_by => 'append_to_id',
        },
    ],
    doc => 'a specific version of a reference sequence, with cordinates suitable for annotation',
};

sub create {
    my $self = shift;
    my $build = $self->SUPER::create(@_);

    if ($build->generate_sequence_uri) {
        $build->sequence_uri($build->external_url);
    }

    if ($build->derived_from) {
        $build->coordinates_from($build->derived_from_root);
    }

    # Let's store the name as an input instead of relying on calculated properties
    $build->name($build->calculated_name);

    # set this for the assembly name as well if there is not one already.
    if (!$build->assembly_name) {
        $build->assembly_name($build->calculated_name);
    }

    $self->status_message("Created reference sequence build with assembly name " . $build->name);

    return $build;
}

sub __errors__ {
    my $self = shift;
    my @tags = $self->SUPER::__errors__();

    # this will die on circular links
    eval { my $coords = $self->derived_from_root(); };
    if ($@) {
        push @tags, UR::Object::Tag->create(
            type => 'error',
            properties => ['derived_from'],
            desc => $@);
    }

    #if (defined $self->derived_from and $self->derived_from->model->id != $self->model->id) {
    #    push @tags, UR::Object::Tag->create(
    #        type => 'error',
    #        properties => ['derived_from'],
    #        desc => "Reference sequence build " . $self->__display_name__ . " of model " . $self->model->__display_name__ .
    #            " is 'derived_from' build " . $self->derived_from->__display_name__ . " which is a build of a different model, ".
    #            $self->derived_from->model->__display_name__);
    #}

    if (defined $self->derived_from and $self->derived_from->id == $self->id) {
        push @tags, UR::Object::Tag->create(
            type => 'error',
            properties => ['derived_from'],
            desc => "A build cannot be explicitly derived from itself!");
    }
    return @tags;
}

sub get{
    my $self = shift;
    my @results = $self->SUPER::get(@_);
    return $self->SUPER::get(@_) if @results;

    my @caller = caller(1);
    if($caller[3] =~ m/Genome::Model::Build::ImportedReferenceSequence::get/){
        return;
    }else{
        return Genome::Model::Build::ImportedReferenceSequence->get(@_);
    }
}

sub is_derived_from {
    my ($self, $build, $seen) = @_;
    $seen = {} if !defined $seen;
    if (exists $seen->{$self->id}) {
        die "Circular link found in derived_from chain. Current build: " . $self->__display_name__ . ", derived from: " .
            $self->derived_from->__display_name__ . ", seen: " . join(',', keys %{$seen});
    }

    return 1 if $build->id == $self->id;
    return 0 if !defined $self->derived_from;

    # recurse
    $seen->{$self->id} = 1;
    return $self->derived_from->is_derived_from($build, $seen); 
}

sub derived_from_root {
    my ($self) = @_;
    my $from = $self;
    my %seen = ($self->id => 1);
    while (defined $from->derived_from) {
        $from = $from->derived_from;
        if (exists $seen{$from->id}) {
            die "Circular link found in derived_from chain while calculating 'derived_from_root'.".
                " Current build: " . $self->__display_name__ . ", derived from: " .
                $from->derived_from->__display_name__ . ", seen: " . join(',', keys %seen);
        }
        $seen{$from->id} = 1;
    }
    return $from;
}

# check compatibility with another reference sequence build
sub is_compatible_with {
    my ($self, $rsb) = @_;
    return if !defined $rsb;
    my $coords_from = $self->coordinates_from || $self;
    my $other_coords_from = $rsb->coordinates_from || $rsb;
    
    return $coords_from->id == $other_coords_from->id;
}

sub __display_name__ {
    my $self = shift;
    my $txt = $self->name . " (" . $self->id . ")";
    return $txt;
}

sub sequence_path {
    my $self = shift;
    my $format = shift || 'fasta';
    my $dir = $self->data_directory;
    my $path = $dir . '/' . 'all_sequences.' . $format;
    return $path if -e $path;
    Carp::confess("No $path found for build " . $self->__display_name__);
}

sub calculate_estimated_kb_usage {
    my $self = shift;
    for my $i ($self->inputs) {
        my $k = $i->name;
        my $v = $i->value_id;
        $self->status_message("INPUT: $k=$v\n");
    }

    my $fastaSize = -s $self->fasta_file;
    if(defined($fastaSize) && $fastaSize > 0)
    {
        $fastaSize = POSIX::ceil($fastaSize * 3 / 1024);
    }
    else
    {
        $fastaSize = $self->SUPER::calculate_estimated_kb_usage();
    }
    return $fastaSize;
}

sub sequence {
    my ($self, $chromosome, $start, $stop) = @_;

    my $f = IO::File->new();
    my $basesFileName = $self->get_bases_file($chromosome);
    if(!$f->open($basesFileName)) {
        $self->error_message("Failed to open bases file \"$basesFileName\".");
        return;
    }
    my $seq = undef;
    $f->seek($start - 1,0);
    $f->read($seq, $stop - $start + 1);

    return $seq;
}

sub get_bases_file {
    my $self = shift;
    my ($chromosome) = @_;

    my $bases_dir = join('/', $self->data_directory, 'bases');
    unless(-d $bases_dir) {
        #for backwards-compatibility--old builds stored the .bases files directly in the data directory
        #TODO remove this conditional once snapshots prior to this change are in use and the files have been moved
        #in all older I.R.S. builds
        $bases_dir = $self->data_directory;
    }

    # grab the dir here?
    my $bases_file = $bases_dir . "/" . $chromosome . ".bases";

    return $bases_file;
}

sub full_consensus_path {
    my ($self, $format) = @_;
    $format ||= 'bfa';
    my $file = $self->data_directory . '/all_sequences.'. $format;
    unless (-e $file){
        $file = $self->data_directory . '/ALL.'. $format;
        unless (-e $file){
            $self->error_message("Failed to find " . $self->data_directory . "/all_sequences.$format");
            return;
        }
    }
    # check local cache for file
    my $localfile = "/opt/fscache$file";
    return $localfile if (-e $localfile);
    return $file;
}

#This is for samtools faidx output that can be used as ref_list for
#SamToBam convertion
sub full_consensus_sam_index_path {
    my $self        = shift;
    my $sam_version = shift;

    my $data_dir = $self->data_directory;
    my $fa_file  = $self->full_consensus_path('fa');
    my $idx_file = $fa_file.'.fai';

    unless (-e $idx_file) {
        my $sam_path = Genome::Model::Tools::Sam->path_for_samtools_version($sam_version);
        my $cmd      = $sam_path.' faidx '.$fa_file;
        
        my $lock = Genome::Sys->lock_resource(
            resource_lock => $data_dir.'/lock_for_faidx',
            max_try       => 2,
        );
        unless ($lock) {
            $self->error_message("Failed to lock resource: $data_dir");
            return;
        }

        my $rv = Genome::Sys->shellcmd(
            cmd => $cmd,
            input_files  => [$fa_file],
            output_files => [$idx_file],
        );
        
        unless (Genome::Sys->unlock_resource(resource_lock => $lock)) {
            $self->error_message("Failed to unlock resource: $lock");
            return;
        }
        unless ($rv == 1) {
            $self->error_message("Failed to run samtools faidx on fasta: $fa_file");
            return;
        }
    }
    return $idx_file if -e $idx_file;
    return;
}
        
sub description {
    my $self = shift;
    my $path = $self->data_directory . '/description';
    unless (-e $path) {
        return 'all';
    }
    my $fh = IO::File->new($path);
    my $desc = $fh->getline;
    chomp $desc;
    return $desc;
}

sub external_url {
    my $self = shift;
    my $url = 'https://genome.wustl.edu/view/genome/model/build/reference-sequence/consensus.fasta?id=' . $self->id;
    $url .= "/".$self->name."/all_sequences.bam";
    return $url;
}

sub get_sequence_dictionary {
    my $self = shift;
    my $file_type = shift;
    my $species = shift;
    my $picard_version = shift;

    my $picard_path = Genome::Model::Tools::Picard->path_for_picard_version($picard_version);

    my $seqdict_dir_path = $self->data_directory.'/seqdict';
    my $path = "$seqdict_dir_path/seqdict.$file_type";
    if (-s "/opt/fscache/" . $path) {
       return "/opt/fscache/" . $path; 
    } elsif (-s $path) {
        return $path;
    } else {

        #lock seqdict dir here
        my $lock = Genome::Sys->lock_resource(
            resource_lock => $seqdict_dir_path."/lock_for_seqdict-$file_type",
            max_try       => 2,
        );

        # if it couldn't get the lock after 2 tries, pop a message and keep trying as much as it takes
        unless ($lock) {
            $self->status_message("Couldn't get a lock after 2 tries, waiting some more...");
            $lock = Genome::Sys->lock_resource(resource_lock => $seqdict_dir_path."/lock_for_seqdict-$file_type");
            unless($lock) {
                $self->error_message("Failed to lock resource: $seqdict_dir_path");
                return;
            }
        }

        $self->status_message("Failed to find sequence dictionary file at $path.  Generating one now...");
        my $seqdict_dir = $self->data_directory."/seqdict/";
        my $cd_rv =  Genome::Sys->create_directory($seqdict_dir);
        if ($cd_rv ne $seqdict_dir) {
            $self->error_message("Failed to to create sequence dictionary directory for $path. Quiting");
            return;
        }
        #my $picard_path = "/gsc/scripts/lib/java/samtools/picard-tools-1.04/";
        my $uri = $self->sequence_uri;
        if (!$uri) {
            $self->warning_message("No sequence URI defined on this model!  Using generated default: " . $self->external_url);
            $uri = $self->external_url;
        }
        my $ref_seq = $self->full_consensus_path('fa'); 
        my $assembly_name = $self->assembly_name;
    
        # fall back to the build name if the assembly name came up short.
        if (!$assembly_name) {
            $assembly_name = $self->name;
        }
        
        my $create_seq_dict_cmd = "java -Xmx4g -XX:MaxPermSize=256m -cp $picard_path/CreateSequenceDictionary.jar net.sf.picard.sam.CreateSequenceDictionary R='$ref_seq' O='$path' URI='$uri' species='$species' genome_assembly='$assembly_name' TRUNCATE_NAMES_AT_WHITESPACE=true";        

        my $csd_rv = Genome::Sys->shellcmd(cmd=>$create_seq_dict_cmd);

        unless (Genome::Sys->unlock_resource(resource_lock => $lock)) {
            $self->error_message("Failed to unlock resource: $lock");
            return;
        }

        if ($csd_rv ne 1) {
            $self->error_message("Failed to to create sequence dictionary for $path. Quiting");
            return;
        } 
        
        return $path;    

    }

    return;
}

sub get_by_name {
    my ($class, $name) = @_;

    unless ( $name ) {
        Carp::confess('No build name given to get imported reference sequence build');
    }

    # This method is not adequate as spaces are substitued in the model anme and version
    #  when creating the build name. But we'll try.
    my ($model_name, $build_version) = $name =~ /^(.+)-build(.*?)$/;
    if ( not defined $model_name ) {
        $class->status_message("Could not parse out model name and build version from build name: $name");
        return;
    }

    $class->status_message("Getting imported reference sequence builds for model ($model_name) and version ($build_version)");

    my $model = Genome::Model::ImportedReferenceSequence->get(name => $model_name);
    if ( not $model ) {
        # ok - model name may have spaces that were sub'd for dashes
        $class->status_message("No imported reference sequence model with name: $model_name");
        return;
    }

    $class->status_message("Getting builds for imported reference sequence model: ".$model->__display_name__);

    my @builds = $model->builds;
    if ( not @builds ) {
        Carp::confess("No builds for imported reference sequence model: ".$model->__display_name__);
    }

    unless($build_version) {
        my @builds_without_version;
        for my $build (@builds) {
            next if defined $build->version;

            push @builds_without_version, $build;
        }

        unless (scalar @builds_without_version > 0) {
            Carp::confess("No builds found with no version for imported reference sequence model: ".$model->__display_name__);
        }
        if ( @builds_without_version > 1 ) {
            Carp::confess("Multiple builds with no version found for model: ".$model->__display_name__);
        }

        return $builds_without_version[0];
    } else {
        my @builds_with_version;
        for my $build ( @builds ) {
            my $version = $build->version;
            if ( not defined $version or $version ne $build_version ) {
                next;
            }
            push @builds_with_version, $build;
        }
        if ( not @builds_with_version ) {
            Carp::confess("No builds found with version $build_version for imported reference sequence model: ".$model->__display_name__);
        }
        elsif ( @builds_with_version > 1 ) {
            Carp::confess("Multiple builds with version $build_version found for model: ".$model->__display_name__);
        }

        return $builds_with_version[0];
    }
}

1;
