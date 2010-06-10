package Genome::Model::ReferenceSequence::Command::GenerateBitmask; 

class Genome::Model::ReferenceSequence::Command::GenerateBitmask {
    is => 'Genome::Command::OO',
    has_input => [
        refseq => { 
            is => 'Genome::Model::Build::ImportedReferenceSequence', # we're going to remove "Imported" soon
            id_by => 'refseq_id',
            shell_args_position => 1, 
            doc => 'the reference build, specified by name (like NCBI-human-build36)'
        },         
        bases => {
            is => 'Text',
            shell_args_position => 2, 
            doc => 'the list of bases to use, i.e. AT GC, etc.'
        },
    ],
    doc => 'generate a set of bitmask data for a given specific reference sequence'
};

sub help_synopsis {
    my $class = shift;
    return <<EOS;
genome model reference-sequence generate-bitmask NCBI-human-build36 AT

genome model reference-sequence generate-bitmask -r NCBI-human-build36 -b AT 

genome model reference-sequence generate-bitmask MYMODELNAME-buildMYBUILDVERSION CG

EOS
}

sub help_detail {

    my $class = shift;
    return <<'EOS';
Creates a bitmask file for a given reference sequence and stores it with the data for that reference.
EOS
}

sub execute {
    my $self = shift;
    my $refseq = $self->refseq;
    my $bases = $self->bases;

    $self->status_message("building bitmask files for $bases on refseq " . $refseq->__display_name__ . "...");

    my $data_directory = $refseq->data_directory;
    my $fasta_path = $refseq->sequence_path('fasta');
   
    my $filename = 'all_sequneces.' . join('', sort split(//,lc($bases))) . '_bitmask';

    my $final_path = $data_directory . '/' . $filename;
    if (-e $final_path) {
        $self->error_message("$final_path already exists!");
        return;
    }
    $self->status_message("final file will be at $final_path.\n");
    
    # work in tmp
    my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
    my $temp_path = $temp_dir . '/' . $filename;

    # replace this with something which does the actual work
    # print "running on refseq " . $refseq->__display_name__ 
    #    . " with data directory " . $data_directory
    #    . " and fasta file " . $fasta_path
    #    . " for bases $bases"
    #    . " at $temp_path\n";

    # copy the results to real disk after completion
    Genome::Utility::FileSystem->copy_file($temp_path,$final_path);

    $self->status_message("resizing the build disk allocation...");
    $refseq->reallocate();

    $self->status_message("complete.");
    return 1;
}

1;
