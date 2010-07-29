package Genome::Model::Build::ReferencePlaceholder;

#REVIEW fdu
#short: Obsolete subreference-related methods can be removed. 
#Long: It will be replaced with a real model once we have one in place for all reference sequences used. Also see comments below


use strict;
use warnings;

use Genome;
use File::Basename;

# This class is an OO-representation of the reference used for reference alignments.
# It will be replaced with a real model once we have one in place for all reference sequences used.
# For now reference alignment models just make this upon first call to the accessor.

class Genome::Model::Build::ReferencePlaceholder {
    id_by => [
        name            => {    is => 'Text' },
    ],
    has => [
        sample_type     => {
                                is => 'Text',
                                is_optional => 1,
                                default_value => 'dna'
        },
        data_directory  => {    is => 'Text' },
        external_url    => {    is => 'Text',
                                is_optional => 1,
                                default_value => 'ftp://genome.wustl.edu/pub/reference/',
        },
    ],
    doc => 'Temporary object representing the reference used in reference alignment models.  To be replaced with a real model build.',
};

sub get {
    my $class = shift;
    my $bx = $class->get_boolexpr_for_params(@_);
    my %p = $bx->params_list;
    unless ($p{id} || $p{name}) {
        die __PACKAGE__ . ' can only be gotten by name!';
    }
    my $obj = $class->SUPER::get($bx);
    return $obj;
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    my $sequence_item = Genome::Reference->get(description => $self->name);
    if ($sequence_item) {
        my $db = $sequence_item->bfa_directory;
        if ($db) {
            $self->data_directory($db);
            return $self;
        } else {
            $self->delete;
            die('Failed to find bfa directory for genome reference '. $self->name);
        }
    }

    my $path = join('/',Genome::Config::reference_sequence_directory(),$self->name);
    #my $dna_type = $self->sample_type;
    #if $dna_type contains spaces, replace them with underscores
    #if ( $dna_type =~ m/\s/ ) {
    #    $dna_type =~ tr/ /_/;
    #}
    
    #my $dna_path = $path .'.'. $dna_type;
    #if (-d $dna_path || -l $dna_path) {
    #    $path = $dna_path;
    #}
    $self->data_directory($path);

    return $self;
}

sub full_consensus_path {
    my ($self,$format) = @_;
    $format ||= 'bfa';
    my $file = $self->data_directory . '/all_sequences.'. $format;
    if ( -e $file){
        return $file;
    }
    $file = $self->data_directory . '/ALL.'. $format;
    if ( -e $file){
        return $file;
    }
    $self->error_message("Failed to find all_sequences.$format");
    return;
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
        
sub subreference_paths {
    my $self = shift;
    my %p = @_;

    my $ext = $p{reference_extension};

    return glob(sprintf("%s/*.%s",
                        $self->data_directory,
                        $ext));
}

sub subreference_names {
    my $self = shift;
    my %p = @_;

    my $ext = $p{reference_extension} || 'fasta';

    my @paths = $self->subreference_paths(reference_extension=>$ext);

    my @basenames = map {basename($_)} @paths;
    for (@basenames) {
        s/\.$ext$//;
    }

    return @basenames;
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
        
        my $create_seq_dict_cmd = "java -Xmx4g -XX:MaxPermSize=256m -cp $picard_path/CreateSequenceDictionary.jar net.sf.picard.sam.CreateSequenceDictionary R=$ref_seq O=$path URI=$uri species=\"$species\" genome_assembly=$name TRUNCATE_NAMES_AT_WHITESPACE=true";        

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
