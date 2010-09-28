package GAP::Command::RepeatMasker;

use strict;
use warnings;

use GAP;
use Genome::Utility::FileSystem;
use Carp 'confess';
use Bio::SeqIO;
use Bio::Tools::Run::RepeatMasker;

class GAP::Command::RepeatMasker {
    is => 'GAP::Command',
    has => [
        fasta_file => { 
            is  => 'Path',
            is_input => 1,
            doc => 'Fasta file to be masked',
        },
        masked_fasta => { 
            is => 'Path',
            is_input => 1,
            is_output => 1,
            doc => 'Masked sequence is placed in this file (fasta format)' 
        },
    ],
    has_optional => [
        repeat_library => {
            is => 'Path',
            is_input => 1,
            doc => 'Repeat library to pass to RepeatMasker', 
        },
	    species	=> {
            is  => 'Text',
            is_input => 1,
            doc => 'Species name',
		},
    ], 
};

sub help_brief {
    "RepeatMask the contents of the input file and write the result to the output file";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {
    my $self = shift;
    unless (-e $self->fasta_file and -s $self->fasta_file) {
        confess "File does not exist or has no size at " . $self->fasta_file;
    }
    
    unless (defined $self->repeat_library or defined $self->species) {
        confess "Either repeat library or species must be defined!";
    }
    elsif (defined $self->repeat_library and defined $self->species) {
        $self->warning_message("Both repeat library and species are specified, choosing repeat library!");
    }

    if ($self->fasta_file =~ /\.bz2$/) {
        my $unzipped_file = Genome::Utility::FileSystem->bunzip($self->fasta_file);
        confess "Could not unzip fasta file at " . $self->fasta_file unless defined $unzipped_file;
        $self->fasta_file($unzipped_file);
    }
    
    if (-e $self->masked_fasta) {
        $self->warning_message("Removing existing file at " . $self->masked_fasta);
        unlink $self->masked_fasta;
    }
   
    my $input_fasta = Bio::SeqIO->new(
        -file => $self->fasta_file,
        -format => 'Fasta',
    );

    my $masked_fasta = Bio::SeqIO->new(
        -file => '>' . $self->masked_fasta,
        -format => 'Fasta',
    );

    # FIXME I (bdericks) had to patch this bioperl module to not fail if there is no repetitive sequence
    # in a sequence we pass in. This patch either needs to be submitted to BioPerl or a new wrapper for 
    # RepeatMasker be made for in house. I don't like relying on patched version of bioperl that aren't
    # tracked in any repo...
    my $masker;
    if (defined $self->repeat_library) {
    	$masker = Bio::Tools::Run::RepeatMasker->new(lib => $self->repeat_library);
    }
    elsif (defined $self->species) {
    	$masker = Bio::Tools::Run::RepeatMasker->new(species => $self->species);
    } 
    
    while (my $seq = $input_fasta->next_seq()) {
        $masker->run($seq);
        my $masked_seq = $masker->masked_seq();     
        next unless defined $masked_seq;
        $masked_fasta->write_seq($masked_seq);
    }   

    return 1;
}

1;
