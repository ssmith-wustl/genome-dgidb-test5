package Genome::Model::Build::ImportedReferenceSequence;
use strict;
use warnings;

use Genome;
use POSIX;

class Genome::Model::Build::ImportedReferenceSequence {
    is => 'Genome::Model::Build',
    has => [
        species_name => {
            via => 'model',
            to => 'species_name',
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
        name => {
            calculate_from => ['model_name','version'],
            calculate => q{
                my $name = "$model_name-build";
                $name .= $version if defined $version;
                $name =~ s/\s/-/g;
                return $name;
            },
        }
    ],
    has_optional => [
        version => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'version', value_class_name => 'UR::Value' ],
            doc => 'Identifies the version of the reference sequence.  This string may not contain spaces.',
            is_mutable => 1,
            is_many => 0,
        },
        prefix => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'prefix', value_class_name => 'UR::Value' ],
            doc => 'The source of the sequence (such as NCBI).  May not contain spaces.',
            is_mutable => 1,
            is_many => 0,
        }        
    ]
};

sub from_cmdline {
    my $class = shift;
    my $text = shift;

    my $build;
    if ( my ($model_name,$build_version) = ($text =~ /^(.+)-build(.+?)$/) ) {
        my $model = Genome::Model->get(name => $model_name);
        unless ($model) {
            $class->error_message("No model found for name $model_name...");
            return;
        }

        my @builds = $model->builds;
        unless (@builds) {
            $class->error_message("No builds found for model $model_name");
            return;
        };

        no warnings;
        @builds = grep { $_->version eq $build_version } @builds;
        unless (@builds) {
            $class->error_message("No build found with version $build_version on model " . $model->__display_name__);
            return;
        }

        if (@builds > 1) {
            $class->warning_message("Multiple builds found with version $build_version on model " . $model->__display_name__ . '. Using #' . $builds[0]->id);
        }

        $build = $builds[0];
    }

    # Next, try loading a model with the given name and, if it only has one build, assume that's the one.
    unless ($build) {
        my @models = Genome::Model->get(type_name => 'imported reference sequence', name => $text);

        if(scalar(@models) eq 1) {
            my @builds = $models[0]->builds;
            
            if(scalar(@builds) eq 1) {
                $build = $builds[0];
            } elsif(scalar(@builds) > 1) {
                $class->error_message(
                    'Found multiple possible reference sequence builds for model matching name: ' .
                    join(', ', map($_->name, @builds))
                );
                return;
            }
        } elsif(scalar(@models) > 1) {
            $class->error_message(
                'Found multiple possible reference sequence models matching name: ' .
                join(', ', map($_->__display_name__, @models))
            );
        }
    }

    # failing that, try to match anything we have (should this be moved into the above method?)
    unless ($build) {
        # This is not the most efficient thing as it instantiates all imported reference sequences to query the name of each;
        # Genome::Model::Build::ImportedReferenceSequence->name should perhaps be cached if it remains calculated
        my @builds = Genome::Model::Build::ImportedReferenceSequence->get(type_name => 'imported reference sequence', name => $text);
        if(scalar(@builds) eq 1) {
            $build = $builds[0];
        } elsif( scalar(@builds > 1) ) {
            $class->error_message(
                'Found multiple possible reference sequence builds matching name: ' .
                join(', ', map($_->name, @builds))
            );
            return;
        }
    }

    # fall back to the default
    unless($build) {
        eval { #from_cmdline can crash when it tries to use a string in a numeric field
            my @builds = $class->SUPER::from_cmdline($text);
            if (@builds > 1) {
                $class->error_message("Multiple builds found for cmdline string: $text");
                return;
            }

            if(scalar(@builds) eq 1) {
                $build = $builds[0];
            }
        };

    }

    return $build;
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
        
        my $lock = Genome::Utility::FileSystem->lock_resource(
            resource_lock => $data_dir.'/lock_for_faidx',
            max_try       => 2,
        );
        unless ($lock) {
            $self->error_message("Failed to lock resource: $data_dir");
            return;
        }

        my $rv = Genome::Utility::FileSystem->shellcmd(
            cmd => $cmd,
            input_files  => [$fa_file],
            output_files => [$idx_file],
        );
        
        unless (Genome::Utility::FileSystem->unlock_resource(resource_lock => $lock)) {
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
        my $lock = Genome::Utility::FileSystem->lock_resource(
            resource_lock => $seqdict_dir_path."/lock_for_seqdict-$file_type",
            max_try       => 2,
        );

        # if it couldn't get the lock after 2 tries, pop a message and keep trying as much as it takes
        unless ($lock) {
            $self->status_message("Couldn't get a lock after 2 tries, waiting some more...");
            $lock = Genome::Utility::FileSystem->lock_resource(resource_lock => $seqdict_dir_path."/lock_for_seqdict-$file_type");
            unless($lock) {
                $self->error_message("Failed to lock resource: $seqdict_dir_path");
                return;
            }
        }

        $self->status_message("Failed to find sequence dictionary file at $path.  Generating one now...");
        my $seqdict_dir = $self->data_directory."/seqdict/";
        my $cd_rv =  Genome::Utility::FileSystem->create_directory($seqdict_dir);
        if ($cd_rv ne $seqdict_dir) {
            $self->error_message("Failed to to create sequence dictionary directory for $path. Quiting");
            return;
        }
        #my $picard_path = "/gsc/scripts/lib/java/samtools/picard-tools-1.04/";
        my $uri = $self->external_url."/".$self->name."/all_sequences.bam";
        my $ref_seq = $self->full_consensus_path('fa'); 
        my $name = $self->name;
        
        my $create_seq_dict_cmd = "java -Xmx4g -XX:MaxPermSize=256m -cp $picard_path/CreateSequenceDictionary.jar net.sf.picard.sam.CreateSequenceDictionary R='$ref_seq' O='$path' URI='$uri' species='$species' genome_assembly='$name' TRUNCATE_NAMES_AT_WHITESPACE=true";        

        my $csd_rv = Genome::Utility::FileSystem->shellcmd(cmd=>$create_seq_dict_cmd);

        unless (Genome::Utility::FileSystem->unlock_resource(resource_lock => $lock)) {
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

1;
