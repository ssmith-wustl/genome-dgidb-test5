package Genome::Model::Build::ImportedReferenceSequence;
#:adukes This module is used solely for importing annotation and generating sequence for genbank exons.  It needs to be expanded/combined with other reference sequence logic ( refalign models )
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
            where => [ name => 'fasta_file', value_class_name => 'UR::Value'],
            doc => 'fully qualified fasta filename (eg /foo/bar/input.fasta)'
        },
    ],
    has_optional => [
        version => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'version', value_class_name => 'UR::Value'],
            doc => 'Identifies the version of the reference sequence.  This string may not contain spaces.'
        },
    ]
};

sub resolve_data_directory {
    my $self = shift @_;
    # Make allocation unless the user wants to put the data in specific place and manage it himself
    if(defined($self->data_directory))
    {
        my $outDir = $self->data_directory;
        if(!-d $outDir)
        {
            make_path($outDir);
            if(!-d $outDir)
            {
                $self->error_message("\"$outDir\" does not exist and could not be created.");
                die $self->error_message;
            }
        }
    }
    else
    {
        my $subDir = $self->model->name;
        if(defined($self->version))
        {
            $subDir .= '-v' . $self->version;
        }
        $subDir .= '-' . $self->build_id;
        my $allocationPath = 'reference_sequences/' . $subDir;
        my $fastaSize = -s $self->fasta_file;
        if(defined($fastaSize) && $fastaSize > 0)
        {
            $fastaSize = POSIX::ceil($fastaSize / 1024);
        }
        else
        {
            # The fasta file couldn't be statted, and if it is really not accessible, the build will fail during execution.
            # For now, guess that the fasta file is 1GiB.
            $fastaSize = 1048576;
        }
        # Space required is estimated to be three times the size of the reference sequence fasta
        my $allocation = Genome::Disk::Allocation->allocate('allocation_path' => $allocationPath,
                                                            'disk_group_name' => 'info_apipe_ref',
                                                            'kilobytes_requested' => (3 * $fastaSize),
                                                            'owner_class_name' => 'Genome::Model::Build::ImportedReferenceSequence',
                                                            'owner_id' => $self->build_id);
        # Note: Genome::Disk::Allocation->allocate does error checking and will cause the calling program to exit with an
        # error allocation fails, so it has succeeded if execution reaches this point
        $self->data_directory($allocation->absolute_path);
    }
    return $self->data_directory;
}

sub sequence {
    my $self = shift;
    my ($file, $start, $stop) = @_;

    my $f = IO::File->new();
    $f->open($file);
    my $seq = undef;
    $f->seek($start -1,0);
    $f->read($seq, $stop - $start + 1);
    $f->close();

    return $seq;
}

sub get_bases_file {
    my $self = shift;
    my ($chromosome) = @_;


    # grab the dir here?
    my $bases_file = $self->data_directory()."/".$chromosome.".bases";

    $self->version = 'test';

    return $bases_file;
}

1;
