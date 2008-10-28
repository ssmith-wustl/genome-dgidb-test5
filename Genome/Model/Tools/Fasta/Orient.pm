package Genome::Model::Tools::Fasta::Orient;

use strict;
use warnings;

use Genome;

require Alignment::SequenceMatch::Blast::BioHspUtil;
require Bio::SearchIO;
require Bio::Seq;
require Bio::SeqIO;
use Data::Dumper;
require File::Copy;
require File::Temp;
require Genome::Model::Tools::WuBlast::Blastn;
require Genome::Model::Tools::WuBlast::Xdformat::Create;
require IO::File;

class Genome::Model::Tools::Fasta::Orient {
    is  => 'Genome::Model::Tools::Fasta',
    has_many => [	 
    sense_sequences => {
        is => 'String',
        is_optional => 1,
        doc => 'Sense sequences (comma separated if from comand line)',
    },		 
    anti_sense_sequences => {
        is => 'String',
        is_optional => 1,
        doc => 'Anti-Sense sequences (comma separated if from comand line)',
    },		 
    ],
};

sub help_brief {
    return 'Orients FASTA (and Quality) files by given sense and anti-sense sequences';
}

sub help_detail { 
    return <<EOS 
    Orients a fasta.
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->sense_sequences or $self->anti_sense_sequences ) {
        $self->error_message("Need sense or anti-sense sequences to query");
        return;
    }
    
    return $self;
}

sub execute {
    my $self = shift;

    # Temp dir and files
    my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);
    my $database = sprintf('%s/blast_db', $tmp_dir);
    my $query_file = sprintf('%s/query_file.fasta', $tmp_dir);

    # Create blast db
    my $xdformat = Genome::Model::Tools::WuBlast::Xdformat::Create->create(
        database => $database,
        overwrite_db => 1,
        fasta_files => [ $self->fasta_file ],
    )
        or return;
    $xdformat->execute
        or return;

    # Create query file from sequences
    my $query_bioseq_io = $self->get_fasta_writer($query_file)
        or return;
    my $arbitrary_id = 0;
    for my $sense_type (qw/ sense anti_sense /) {
        my $sense_seq_method = sprintf('%s_sequences', $sense_type);
        for my $sense_seq ( $self->$sense_seq_method ) {
            my $bioseq = Bio::Seq->new(
                '-id' => sprintf('%s_%d', $sense_type, ++$arbitrary_id),
                '-seq' => $sense_seq,
            )
                or return;
            $query_bioseq_io->write_seq($bioseq)
                or return;
        }
    }

    # Blast
    my $blastn = Genome::Model::Tools::WuBlast::Blastn->create(
        database => $database,
        query_files => [ $query_file ], 
        M => 1, # these params optimized for sort sequences.
        N => -3,
        Q => 3,
        R => 1,
        V => 100000,
        B => 100000,
    )
        or return;
    $blastn->execute
        or return;

    # Parse blast, store results
    my $search_io = Bio::SearchIO->new(
        '-file' => $blastn->output_file,
        '-format' => 'blast',
    );
    my %needs_complementing;
    while ( my $result = $search_io->next_result ) {
        while( my $hit = $result->next_hit ) {
            while ( my $hsp = $hit->next_hsp ){
                my $query = $hsp->query;
                my $needs_complementing = 0;
                if ( $query->seq_id =~ m#^sense# ) {
                    # If this hit is on the - strand, it needs to complemeted
                    $needs_complementing = 1 if $query->strand == -1;
                }
                else { #anti sense
                    # If this hit is on the + strand, it needs to complemeted
                    $needs_complementing = 1 if $query->strand == 1;
                }
                #my $subject_id = $hsp->subject->seq_id;
                # TODO Verify?
                # if ( exists $needs_complementing{$subject_id}
                #        and $needs_complementing{$subject_id} != $needs_complementing ) {
                #    $self->error_message();
                #}
                $needs_complementing{ $hsp->subject->seq_id } = $needs_complementing;
                last;
            }
        }
    }

    $self->_write_oriented_fasta_file(\%needs_complementing);
    $self->_write_oriented_qual_file(\%needs_complementing) if $self->have_qual_file;

    return 1;
}

sub _write_oriented_fasta_file {
    my ($self, $needs_complementing) = @_;

    # Open fasta reading 
    my $bioseq_in = $self->get_fasta_reader( $self->fasta_file )
        or return;
    # Open fasta writing 
    my $oriented_fasta = $self->fasta_file_with_new_extension('oriented');
    unlink $oriented_fasta if -e $oriented_fasta;
    my $bioseq_out = $self->get_fasta_writer($oriented_fasta)
        or return;

    while ( my $bioseq = $bioseq_in->next_seq ) { 
        if ( $needs_complementing->{ $bioseq->id } ) {
            my $seq = $bioseq->seq;
            $seq = reverse $seq;
            $seq =~ tr/actgACTG/tgacTGAC/;

            $bioseq_out->write_seq(
                Bio::Seq->new(
                    '-id' => $bioseq->id,
                    '-desc' => $bioseq->desc,
                    '-seq' => $seq,
                )
            );
        }
        else {
            $bioseq_out->write_seq($bioseq);
        }
    }

    return 1;
}

sub _write_oriented_qual_file {
    my ($self, $needs_complementing) = @_;

    # Open qual reading 
    my $bioseq_in = $self->get_qual_reader( $self->qual_file )
        or return;
    # Open qual reading 
    my $oriented_qual = $self->qual_file_with_new_extension('oriented');
    unlink $oriented_qual if -e $oriented_qual;
    my $bioseq_out = $self->get_qual_writer($oriented_qual)
        or return;

    while ( my $bioseq = $bioseq_in->next_seq ) { 
        if ( $needs_complementing->{ $bioseq->id } ) {
            $bioseq_out->write_seq(
                Bio::Seq::PrimaryQual->new(
                    '-id' => $bioseq->id,
                    '-desc' => $bioseq->desc,
                    '-qual' => [ reverse @{$bioseq->qual} ],
                )
            );
        }
        else {
            $bioseq_out->write_seq($bioseq);
        }
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
